#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'optparse'
require_relative 'validate-workspace-manifest'

class FeatureGraphQueryError < StandardError; end

class FeatureGraphQuery
  def initialize(manifest)
    @manifest = manifest
    @repos = manifest.fetch('repos', [])
    @features = manifest.fetch('features', [])
    @repo_by_id = @repos.each_with_object({}) { |repo, memo| memo[repo['id']] = repo if repo.is_a?(Hash) && repo['id'].is_a?(String) }
  end

  def feature_view(feature_id)
    feature = @features.find { |item| item['feature_id'] == feature_id }
    raise FeatureGraphQueryError, "Feature not found: #{feature_id}" unless feature

    tasks = normalized_tasks(feature)
    {
      api_version: 1,
      view: 'feature',
      workspace_id: @manifest['workspace_id'],
      feature_id: feature_id,
      title: feature['title'],
      description: feature['description'],
      rollup: build_rollup(tasks),
      by_repo: build_repo_rollups(tasks),
      tasks: tasks
    }
  end

  def repo_view(repo_id, feature_id: nil)
    raise FeatureGraphQueryError, "Repository not found: #{repo_id}" unless @repo_by_id.key?(repo_id)

    tasks = if feature_id
              feature = @features.find { |item| item['feature_id'] == feature_id }
              raise FeatureGraphQueryError, "Feature not found: #{feature_id}" unless feature

              normalized_tasks(feature).select { |task| task['repo_id'] == repo_id }
            else
              @features.flat_map { |feature| normalized_tasks(feature) }.select { |task| task['repo_id'] == repo_id }
            end

    {
      api_version: 1,
      view: 'repo',
      workspace_id: @manifest['workspace_id'],
      repo_id: repo_id,
      feature_id: feature_id,
      rollup: build_rollup(tasks),
      tasks: tasks
    }
  end

  private

  def normalized_tasks(feature)
    tasks = feature.fetch('tasks', [])
    tasks.map do |task|
      {
        'id' => task['id'],
        'feature_id' => task['feature_id'],
        'repo_id' => task['repo_id'],
        'title' => task['title'],
        'description' => task['description'],
        'status' => task['status'],
        'parent_ids' => task.fetch('parent_ids', []),
        'child_ids' => task.fetch('child_ids', []),
        'blocked_by_ids' => task.fetch('blocked_by_ids', [])
      }
    end
  end

  def build_repo_rollups(tasks)
    grouped = tasks.group_by { |task| task['repo_id'] }
    grouped.keys.sort.map do |repo_id|
      {
        repo_id: repo_id,
        rollup: build_rollup(grouped[repo_id])
      }
    end
  end

  def build_rollup(tasks)
    counts = Hash.new(0)
    task_by_id = tasks.each_with_object({}) { |task, memo| memo[task['id']] = task }
    blockers = []

    tasks.each do |task|
      status = task['status']
      counts[status] += 1 if status

      if status == 'blocked'
        blockers << { task_id: task['id'], reason: 'status_blocked' }
      end

      task.fetch('blocked_by_ids', []).each do |blocking_id|
        blocking_task = task_by_id[blocking_id]
        next unless blocking_task
        next if %w[done cancelled].include?(blocking_task['status'])

        blockers << { task_id: task['id'], reason: 'waiting_on_task', blocking_task_id: blocking_id }
      end
    end

    total = tasks.length
    done = counts['done']
    in_progress = counts['in_progress']
    blocked_count = counts['blocked']
    completion_pct = total.zero? ? 0.0 : ((done.to_f / total) * 100).round(2)

    {
      total_tasks: total,
      done_tasks: done,
      progress_pct: completion_pct,
      status_counts: WORK_ITEM_STATUSES.each_with_object({}) { |status, memo| memo[status] = counts[status] },
      blocking: {
        blocked: blockers.any? || blocked_count.positive?,
        blocker_count: blockers.length,
        blockers: blockers
      },
      overall_status: compute_overall_status(total, done, in_progress, blocked_count, blockers.any?)
    }
  end

  def compute_overall_status(total, done, in_progress, blocked_count, has_blockers)
    return 'empty' if total.zero?
    return 'blocked' if has_blockers || blocked_count.positive?
    return 'complete' if done == total
    return 'in_progress' if in_progress.positive? || done.positive?

    'not_started'
  end
end

def parse_options(argv)
  options = { format: 'json' }
  parser = OptionParser.new do |opts|
    opts.banner = 'Usage: scripts/query-workspace-feature-graph.rb <manifest-path> (--feature-id ID | --repo-id ID) [--view feature|repo] [--format json]'
    opts.on('--view VIEW', 'View to render: feature or repo') { |value| options[:view] = value }
    opts.on('--feature-id ID', 'Feature id to query') { |value| options[:feature_id] = value }
    opts.on('--repo-id ID', 'Repo id to query') { |value| options[:repo_id] = value }
    opts.on('--format FORMAT', 'Output format (json only currently)') { |value| options[:format] = value }
    opts.on('-h', '--help', 'Show this help') do
      puts opts
      exit 0
    end
  end

  remaining = parser.parse(argv)
  raise FeatureGraphQueryError, parser.to_s if remaining.empty?

  options[:manifest_path] = remaining.first
  options[:view] ||= options[:repo_id] ? 'repo' : 'feature'
  options
end

def validate_query_options!(options)
  raise FeatureGraphQueryError, "Unsupported format '#{options[:format]}'. Only 'json' is supported." unless options[:format] == 'json'
  raise FeatureGraphQueryError, "Unsupported view '#{options[:view]}'. Use 'feature' or 'repo'." unless %w[feature repo].include?(options[:view])

  case options[:view]
  when 'feature'
    raise FeatureGraphQueryError, '--feature-id is required for feature view' unless options[:feature_id]
  when 'repo'
    raise FeatureGraphQueryError, '--repo-id is required for repo view' unless options[:repo_id]
  end
end

def load_and_validate_manifest!(manifest_path)
  schema = load_schema
  manifest_data = load_manifest(manifest_path)
  schema_guardrails!(schema)

  schema_errors = SimpleJsonSchemaValidator.new(schema).validate(manifest_data)
  custom_validator = ManifestValidator.new(manifest_data)
  custom_valid = custom_validator.validate

  return manifest_data if schema_errors.empty? && custom_valid

  errors = schema_errors + custom_validator.errors
  raise FeatureGraphQueryError, "Manifest validation failed for #{manifest_path}:\n  - #{errors.join("\n  - ")}"
end

def run_query_cli(argv)
  options = parse_options(argv)
  validate_query_options!(options)
  manifest_data = load_and_validate_manifest!(options[:manifest_path])
  query = FeatureGraphQuery.new(manifest_data)

  result = if options[:view] == 'feature'
             query.feature_view(options[:feature_id])
           else
             query.repo_view(options[:repo_id], feature_id: options[:feature_id])
           end

  puts JSON.pretty_generate(result)
  0
rescue OptionParser::ParseError, FeatureGraphQueryError, ValidationError => e
  warn e.message
  1
end

exit(run_query_cli(ARGV)) if $PROGRAM_NAME == __FILE__
