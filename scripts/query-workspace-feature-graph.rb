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
      integration: build_feature_integration_view(feature, tasks),
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
      integration: build_repo_integration_view(repo_id, tasks),
      tasks: tasks
    }
  end

  def integration_view(feature_id, repo_id: nil)
    feature = @features.find { |item| item['feature_id'] == feature_id }
    raise FeatureGraphQueryError, "Feature not found: #{feature_id}" unless feature

    raise FeatureGraphQueryError, "Repository not found: #{repo_id}" if repo_id && !@repo_by_id.key?(repo_id)

    tasks = normalized_tasks(feature)
    tasks = tasks.select { |task| task['repo_id'] == repo_id } if repo_id

    {
      api_version: 1,
      view: 'integration',
      workspace_id: @manifest['workspace_id'],
      feature_id: feature_id,
      repo_id: repo_id,
      feature_mapping: feature['integration'],
      rollup: build_integration_rollup(tasks),
      by_repo: build_repo_integration_rollups(tasks),
      tasks: build_task_integration_rows(tasks)
    }
  end

  private

  def normalized_tasks(feature)
    tasks = feature.fetch('tasks', [])
    tasks.map do |task|
      payload = {
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
      payload['integration'] = task['integration'] if task.key?('integration')
      payload
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

  def build_feature_integration_view(feature, tasks)
    {
      mapping: feature['integration'],
      project_targets: build_project_targets(feature),
      rollup: build_integration_rollup(tasks)
    }
  end

  def build_repo_integration_view(repo_id, tasks)
    {
      repo_id: repo_id,
      issue_backend: @repo_by_id.dig(repo_id, 'issue_backend'),
      expected_issue_repo: expected_issue_repo(repo_id),
      rollup: build_integration_rollup(tasks),
      tasks: build_task_integration_rows(tasks)
    }
  end

  def build_repo_integration_rollups(tasks)
    grouped = tasks.group_by { |task| task['repo_id'] }
    grouped.keys.sort.map do |repo_id|
      build_repo_integration_view(repo_id, grouped[repo_id])
    end
  end

  def build_task_integration_rows(tasks)
    tasks.map do |task|
      {
        id: task['id'],
        repo_id: task['repo_id'],
        status: task['status'],
        expected_issue_repo: expected_issue_repo(task['repo_id']),
        mapping: task['integration']
      }
    end
  end

  def build_project_targets(feature)
    targets = []

    feature_project = feature.dig('integration', 'github', 'project')
    targets << feature_project if feature_project.is_a?(Hash)

    @repo_by_id.each_value do |repo|
      next unless repo.dig('issue_backend', 'type') == 'github_project'

      project_id = repo.dig('issue_backend', 'project_id')
      next unless project_id.is_a?(String)

      targets << { 'project_id' => project_id, 'source' => "repo:#{repo['id']}" }
    end

    targets.uniq { |target| target['project_id'] }
  end

  def build_integration_rollup(tasks)
    status_counts = Hash.new(0)
    issue_mapped_tasks = 0
    issue_numbered_tasks = 0
    pr_links = 0
    project_items = 0
    dedupe_keys = []
    retryable_failures = 0

    tasks.each do |task|
      github = task.dig('integration', 'github')
      next unless github.is_a?(Hash)

      issue = github['issue']
      if issue.is_a?(Hash)
        issue_mapped_tasks += 1 if issue['repo'].is_a?(String) && !issue['repo'].strip.empty?
        issue_numbered_tasks += 1 if issue['number'].is_a?(Integer)
      end

      pull_requests = github['pull_requests']
      pr_links += pull_requests.length if pull_requests.is_a?(Array)

      task_project_items = github['project_items']
      project_items += task_project_items.length if task_project_items.is_a?(Array)

      sync = github['sync']
      next unless sync.is_a?(Hash)

      status = sync['status']
      status_counts[status] += 1 if status.is_a?(String)

      dedupe_key = sync['dedupe_key']
      dedupe_keys << dedupe_key if dedupe_key.is_a?(String) && !dedupe_key.strip.empty?

      retry_count = sync['retry_count']
      retryable_failures += 1 if retry_count.is_a?(Integer) && retry_count.positive?
    end

    {
      total_tasks: tasks.length,
      mapped_issue_tasks: issue_mapped_tasks,
      mapped_issue_number_tasks: issue_numbered_tasks,
      pull_request_links: pr_links,
      project_item_links: project_items,
      sync: {
        status_counts: GITHUB_SYNC_STATUSES.each_with_object({}) { |status, memo| memo[status] = status_counts[status] },
        retryable_failures: retryable_failures,
        dedupe_keys: dedupe_keys.uniq
      }
    }
  end

  def expected_issue_repo(repo_id)
    repo = @repo_by_id[repo_id]
    return nil unless repo.is_a?(Hash)
    return nil unless repo.dig('issue_backend', 'type') == 'repo_issues'

    repo.dig('issue_backend', 'repo')
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
    opts.banner = 'Usage: scripts/query-workspace-feature-graph.rb <manifest-path> (--feature-id ID | --repo-id ID) [--view feature|repo|integration] [--format json]'
    opts.on('--view VIEW', 'View to render: feature, repo, or integration') { |value| options[:view] = value }
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
  raise FeatureGraphQueryError, "Unsupported view '#{options[:view]}'. Use 'feature', 'repo', or 'integration'." unless %w[feature repo integration].include?(options[:view])

  case options[:view]
  when 'feature'
    raise FeatureGraphQueryError, '--feature-id is required for feature view' unless options[:feature_id]
  when 'repo'
    raise FeatureGraphQueryError, '--repo-id is required for repo view' unless options[:repo_id]
  when 'integration'
    raise FeatureGraphQueryError, '--feature-id is required for integration view' unless options[:feature_id]
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

  result = case options[:view]
           when 'feature'
             query.feature_view(options[:feature_id])
           when 'repo'
             query.repo_view(options[:repo_id], feature_id: options[:feature_id])
           else
             query.integration_view(options[:feature_id], repo_id: options[:repo_id])
           end

  puts JSON.pretty_generate(result)
  0
rescue OptionParser::ParseError, FeatureGraphQueryError, ValidationError => e
  warn e.message
  1
end

exit(run_query_cli(ARGV)) if $PROGRAM_NAME == __FILE__
