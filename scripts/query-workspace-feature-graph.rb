#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'optparse'
require 'set'
require_relative 'validate-workspace-manifest'

class FeatureGraphQueryError < StandardError; end

class FeatureGraphQuery
  TERMINAL_TASK_STATUSES = %w[done cancelled].freeze
  POLICY_PHASES = %w[preflight build test publish].freeze
  POLICY_DEFAULT_ID = 'policy://default/generic-v1'
  POLICY_PLUGIN_DEFINITIONS = [
    {
      id: 'policy://node/pnpm-v1',
      plugin: 'node_pnpm',
      matcher: lambda { |repo|
        repo.fetch('build_system', '').to_s.include?('pnpm') ||
          repo.fetch('runtime', '').to_s.start_with?('node')
      },
      phases: {
        preflight: 'pnpm install --frozen-lockfile',
        build: 'pnpm run build',
        test: 'pnpm run test',
        publish: 'pnpm run release'
      }
    },
    {
      id: 'policy://ruby/bundler-v1',
      plugin: 'ruby_bundler',
      matcher: lambda { |repo|
        repo.fetch('build_system', '').to_s.include?('bundler') ||
          repo.fetch('runtime', '').to_s.start_with?('ruby')
      },
      phases: {
        preflight: 'bundle install --jobs 4',
        build: 'bundle exec rake build',
        test: 'bundle exec rake test',
        publish: 'bundle exec rake release'
      }
    },
    {
      id: 'policy://terraform/plan-apply-gates',
      plugin: 'terraform_plan_apply',
      matcher: lambda { |repo|
        repo.fetch('build_system', '').to_s.include?('terraform') ||
          repo.fetch('runtime', '').to_s.include?('terraform')
      },
      phases: {
        preflight: 'terraform fmt -check && terraform validate',
        build: 'terraform plan -out=tfplan',
        test: 'terraform show -json tfplan',
        publish: 'terraform apply tfplan'
      }
    },
    {
      id: POLICY_DEFAULT_ID,
      plugin: 'generic',
      matcher: lambda { |_repo| true },
      phases: {
        preflight: 'echo "preflight"',
        build: 'echo "build"',
        test: 'echo "test"',
        publish: 'echo "publish"'
      }
    }
  ].freeze

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
    policy = build_policy_summary(tasks, features: [feature], repo_id: nil)

    {
      api_version: 1,
      view: 'feature',
      workspace_id: @manifest['workspace_id'],
      feature_id: feature_id,
      title: feature['title'],
      description: feature['description'],
      rollup: build_rollup(tasks, dependency_context_tasks: tasks),
      by_repo: build_repo_rollups(tasks),
      integration: build_feature_integration_view(feature, tasks),
      policy: policy,
      tasks: tasks
    }
  end

  def repo_view(repo_id, feature_id: nil)
    raise FeatureGraphQueryError, "Repository not found: #{repo_id}" unless @repo_by_id.key?(repo_id)

    context_tasks, tasks = if feature_id
                             feature = @features.find { |item| item['feature_id'] == feature_id }
                             raise FeatureGraphQueryError, "Feature not found: #{feature_id}" unless feature

                             all_feature_tasks = normalized_tasks(feature)
                             [all_feature_tasks, all_feature_tasks.select { |task| task['repo_id'] == repo_id }]
                           else
                             repo_tasks = @features.flat_map { |feature| normalized_tasks(feature) }.select { |task| task['repo_id'] == repo_id }
                             [repo_tasks, repo_tasks]
                           end

    features_for_policy = feature_id ? [@features.find { |item| item['feature_id'] == feature_id }] : @features
    policy = build_policy_summary(tasks, features: features_for_policy, repo_id: repo_id)

    {
      api_version: 1,
      view: 'repo',
      workspace_id: @manifest['workspace_id'],
      repo_id: repo_id,
      feature_id: feature_id,
      rollup: build_rollup(tasks, dependency_context_tasks: context_tasks),
      integration: build_repo_integration_view(repo_id, tasks),
      policy: policy,
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

  def execution_order_view(feature_id, repo_id: nil)
    feature = @features.find { |item| item['feature_id'] == feature_id }
    raise FeatureGraphQueryError, "Feature not found: #{feature_id}" unless feature
    raise FeatureGraphQueryError, "Repository not found: #{repo_id}" if repo_id && !@repo_by_id.key?(repo_id)

    all_tasks = normalized_tasks(feature)
    rollup = build_rollup(all_tasks, dependency_context_tasks: all_tasks)
    ordered = rollup[:execution_order]
    ordered = ordered.select { |row| row[:repo_id] == repo_id } if repo_id

    {
      api_version: 1,
      view: 'execution-order',
      workspace_id: @manifest['workspace_id'],
      feature_id: feature_id,
      repo_id: repo_id,
      execution_order: ordered,
      gate_status: rollup[:gate_status],
      dependency_graph: rollup[:dependency_graph]
    }
  end

  def gate_status_view(feature_id, repo_id: nil)
    feature = @features.find { |item| item['feature_id'] == feature_id }
    raise FeatureGraphQueryError, "Feature not found: #{feature_id}" unless feature
    raise FeatureGraphQueryError, "Repository not found: #{repo_id}" if repo_id && !@repo_by_id.key?(repo_id)

    all_tasks = normalized_tasks(feature)
    orchestration = build_orchestration(all_tasks, dependency_context_tasks: all_tasks)
    task_gates = orchestration[:task_gates]
    task_gates = task_gates.select { |row| row[:repo_id] == repo_id } if repo_id

    {
      api_version: 1,
      view: 'gate-status',
      workspace_id: @manifest['workspace_id'],
      feature_id: feature_id,
      repo_id: repo_id,
      gate_status: orchestration[:gate_status],
      dependency_graph: orchestration[:dependency_graph],
      tasks: task_gates
    }
  end

  def policy_view(feature_id: nil, repo_id: nil)
    if feature_id
      feature = @features.find { |item| item['feature_id'] == feature_id }
      raise FeatureGraphQueryError, "Feature not found: #{feature_id}" unless feature

      features = [feature]
    else
      features = @features
    end

    raise FeatureGraphQueryError, "Repository not found: #{repo_id}" if repo_id && !@repo_by_id.key?(repo_id)

    tasks = features.flat_map { |feature| normalized_tasks(feature) }
    tasks = tasks.select { |task| task['repo_id'] == repo_id } if repo_id
    summary = build_policy_summary(tasks, features: features, repo_id: repo_id)

    {
      api_version: 1,
      view: 'policy',
      workspace_id: @manifest['workspace_id'],
      feature_id: feature_id,
      repo_id: repo_id,
      policy_rollup: summary[:rollup],
      repos: summary[:repos]
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
        rollup: build_rollup(grouped[repo_id], dependency_context_tasks: tasks)
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

  def build_policy_summary(tasks, features:, repo_id:)
    repo_ids = tasks.map { |task| task['repo_id'] }.uniq.sort
    repo_ids &= [repo_id] if repo_id
    task_gate_index = build_task_gate_index(features)
    evaluations = repo_ids.map do |current_repo_id|
      repo_tasks = tasks.select { |task| task['repo_id'] == current_repo_id }
      evaluate_repo_policy(current_repo_id, repo_tasks, task_gate_index)
    end

    all_violations = evaluations.flat_map { |item| item[:violations] }
    {
      rollup: {
        total_repos: evaluations.length,
        total_tasks: tasks.length,
        repos_with_violations: evaluations.count { |item| item[:violations].any? },
        tasks_with_violations: all_violations.map { |item| item[:task_id] }.compact.uniq.length,
        violation_count: all_violations.length
      },
      repos: evaluations
    }
  end

  def build_task_gate_index(features)
    index = {}
    features.each do |feature|
      next unless feature.is_a?(Hash)

      tasks = normalized_tasks(feature)
      orchestration = build_orchestration(tasks, dependency_context_tasks: tasks)
      orchestration.fetch(:task_gates, []).each do |gate_row|
        key = task_key(
          'feature_id' => feature['feature_id'],
          'id' => gate_row[:task_id]
        )
        index[key] = gate_row
      end
    end
    index
  end

  def evaluate_repo_policy(repo_id, repo_tasks, task_gate_index)
    repo = @repo_by_id[repo_id] || {}
    resolution = resolve_policy_plugin(repo)
    task_rows = repo_tasks.sort_by { |task| [task['feature_id'].to_s, task['id'].to_s] }.map do |task|
      gate_row = task_gate_index[task_key(task)] || default_gate_row(task)
      evaluate_task_policy(task, gate_row, resolution)
    end
    violations = (resolution[:violations] + task_rows.flat_map { |row| row[:violations] }).sort_by do |violation|
      [violation[:scope].to_s, violation[:repo_id].to_s, violation[:feature_id].to_s, violation[:task_id].to_s, violation[:code].to_s]
    end

    {
      repo_id: repo_id,
      repo_runtime: repo['runtime'],
      repo_build_system: repo['build_system'],
      resolution: {
        strategy: resolution[:strategy],
        plugin_id: resolution[:plugin][:id],
        plugin: resolution[:plugin][:plugin],
        selected_policy_ref: resolution[:selected_policy_ref],
        requested_policy_refs: resolution[:requested_policy_refs],
        unresolved_policy_refs: resolution[:unresolved_policy_refs]
      },
      contract: {
        phases: POLICY_PHASES.map do |phase|
          {
            name: phase,
            command: resolution[:plugin][:phases][phase.to_sym],
            deterministic_order: POLICY_PHASES.index(phase) + 1
          }
        end
      },
      task_evaluations: task_rows.map do |row|
        {
          feature_id: row[:feature_id],
          task_id: row[:task_id],
          status: row[:status],
          gate_state: row[:gate_state],
          policy_state: row[:policy_state],
          ready_for_execution: row[:ready_for_execution],
          phases: row[:phases],
          violations: row[:violations]
        }
      end,
      violations: violations
    }
  end

  def resolve_policy_plugin(repo)
    plugins = policy_plugins_by_id
    requested_refs = Array(repo['policy_refs']).select { |ref| ref.is_a?(String) && !ref.strip.empty? }
    unresolved_refs = []
    selected_ref = nil
    selected_plugin = nil

    requested_refs.each do |ref|
      if plugins.key?(ref)
        selected_ref = ref
        selected_plugin = plugins[ref]
        break
      else
        unresolved_refs << ref
      end
    end

    strategy = 'explicit_ref'
    if selected_plugin.nil?
      selected_plugin = fallback_policy_plugin(repo)
      strategy = selected_plugin[:id] == POLICY_DEFAULT_ID ? 'default' : 'toolchain_fallback'
    end

    violations = unresolved_refs.map do |ref|
      {
        scope: 'repo',
        repo_id: repo['id'],
        feature_id: nil,
        task_id: nil,
        code: 'policy_ref_not_supported',
        message: "Policy reference '#{ref}' is not registered in runtime plugin catalog."
      }
    end

    {
      strategy: strategy,
      plugin: selected_plugin,
      selected_policy_ref: selected_ref,
      requested_policy_refs: requested_refs,
      unresolved_policy_refs: unresolved_refs,
      violations: violations
    }
  end

  def fallback_policy_plugin(repo)
    POLICY_PLUGIN_DEFINITIONS.reject { |item| item[:id] == POLICY_DEFAULT_ID }.sort_by { |item| item[:id] }.find { |item| item[:matcher].call(repo) } ||
      policy_plugins_by_id.fetch(POLICY_DEFAULT_ID)
  end

  def policy_plugins_by_id
    @policy_plugins_by_id ||= POLICY_PLUGIN_DEFINITIONS.each_with_object({}) { |plugin, memo| memo[plugin[:id]] = plugin }
  end

  def evaluate_task_policy(task, gate_row, resolution)
    status = task['status']
    gate_state = gate_row[:gate_state]
    phases = build_phase_states(status, resolution[:plugin])
    violations = []

    if %w[in_progress done].include?(status) && %w[blocked waiting_on_signal].include?(gate_state)
      violations << {
        scope: 'task',
        repo_id: task['repo_id'],
        feature_id: task['feature_id'],
        task_id: task['id'],
        code: 'task_executed_while_gate_unsatisfied',
        message: "Task '#{task['id']}' is #{status} while gate_state is '#{gate_state}'."
      }
    end

    if status == 'done' && !%w[satisfied running].include?(gate_state)
      violations << {
        scope: 'task',
        repo_id: task['repo_id'],
        feature_id: task['feature_id'],
        task_id: task['id'],
        code: 'done_task_without_satisfied_gate',
        message: "Task '#{task['id']}' is done but gate_state '#{gate_state}' is not terminal."
      }
    end

    policy_state = if violations.any?
                     'violation'
                   elsif status == 'done'
                     'satisfied'
                   elsif status == 'in_progress'
                     'running'
                   elsif %w[blocked waiting_on_signal].include?(gate_state)
                     'waiting'
                   elsif gate_state == 'ready'
                     'ready'
                   else
                     'pending'
                   end

    {
      feature_id: task['feature_id'],
      task_id: task['id'],
      status: status,
      gate_state: gate_state,
      ready_for_execution: gate_row[:ready_for_execution],
      policy_state: policy_state,
      phases: phases,
      violations: violations
    }
  end

  def build_phase_states(status, plugin)
    completed_phases = case status
                       when 'done'
                         POLICY_PHASES
                       when 'in_progress'
                         %w[preflight]
                       else
                         []
                       end

    active_phase = status == 'in_progress' ? 'build' : nil
    POLICY_PHASES.map do |phase|
      state = if status == 'cancelled'
                'skipped'
              elsif completed_phases.include?(phase)
                'satisfied'
              elsif active_phase == phase
                'running'
              else
                'pending'
              end

      {
        name: phase,
        command: plugin[:phases][phase.to_sym],
        state: state
      }
    end
  end

  def task_key(task)
    "#{task['feature_id']}:#{task['id']}"
  end

  def default_gate_row(task)
    {
      task_id: task['id'],
      repo_id: task['repo_id'],
      gate_state: 'unknown',
      ready_for_execution: false
    }
  end

  def expected_issue_repo(repo_id)
    repo = @repo_by_id[repo_id]
    return nil unless repo.is_a?(Hash)
    return nil unless repo.dig('issue_backend', 'type') == 'repo_issues'

    repo.dig('issue_backend', 'repo')
  end

  def build_rollup(tasks, dependency_context_tasks:)
    counts = Hash.new(0)
    orchestration = build_orchestration(tasks, dependency_context_tasks: dependency_context_tasks)
    blockers = orchestration[:gate_status][:blocking_tasks]

    tasks.each do |task|
      status = task['status']
      counts[status] += 1 if status
    end

    total = tasks.length
    done = counts['done']
    in_progress = counts['in_progress']
    blocked_count = counts['blocked']
    has_blockers = blockers.any? || blocked_count.positive?
    completion_pct = total.zero? ? 0.0 : ((done.to_f / total) * 100).round(2)

    {
      total_tasks: total,
      done_tasks: done,
      progress_pct: completion_pct,
      status_counts: WORK_ITEM_STATUSES.each_with_object({}) { |status, memo| memo[status] = counts[status] },
      blocking: {
        blocked: has_blockers,
        blocker_count: blockers.length,
        blockers: blockers
      },
      gate_status: orchestration[:gate_status],
      dependency_graph: orchestration[:dependency_graph],
      execution_order: orchestration[:execution_order],
      overall_status: compute_overall_status(total, done, in_progress, blocked_count, has_blockers)
    }
  end

  def build_orchestration(tasks, dependency_context_tasks:)
    task_by_id = dependency_context_tasks.each_with_object({}) { |task, memo| memo[task['id']] = task }
    relevant_task_ids = tasks.map { |task| task['id'] }.to_set
    dependency_ids_by_task = {}
    dependents_by_task = Hash.new { |memo, key| memo[key] = [] }
    indegree = {}

    tasks.sort_by { |task| task['id'] }.each do |task|
      deps = dependency_ids_for(task).select { |id| task_by_id.key?(id) }
      relevant_deps = deps.select { |id| relevant_task_ids.include?(id) }
      dependency_ids_by_task[task['id']] = deps
      indegree[task['id']] = relevant_deps.length
      relevant_deps.each { |dep| dependents_by_task[dep] << task['id'] }
    end

    dependents_by_task.each_value(&:sort!)
    queue = indegree.select { |_id, degree| degree.zero? }.keys.sort
    wave_by_task_id = {}
    processed_ids = {}
    execution_rows = []

    until queue.empty?
      task_id = queue.shift
      task = task_by_id[task_id]
      deps = dependency_ids_by_task.fetch(task_id, [])
      wave = deps.empty? ? 0 : deps.map { |id| wave_by_task_id[id] || 0 }.max + 1
      wave_by_task_id[task_id] = wave

      gate = evaluate_gate(task, deps, task_by_id)
      execution_rows << build_execution_row(
        task,
        gate: gate,
        sequence: execution_rows.length + 1,
        wave: wave,
        dependency_ids: deps
      )
      processed_ids[task_id] = true

      dependents_by_task.fetch(task_id, []).each do |dependent_id|
        indegree[dependent_id] -= 1
        queue << dependent_id if indegree[dependent_id].zero?
      end
      queue.sort!
    end

    cycle_task_ids = indegree.keys.reject { |id| processed_ids[id] }.sort
    cycle_task_ids.each do |task_id|
      task = task_by_id[task_id]
      deps = dependency_ids_by_task.fetch(task_id, [])
      gate = {
        gate_state: 'blocked',
        ready_for_execution: false,
        blockers: [{ task_id: task_id, reason: 'dependency_cycle', cycle_task_ids: cycle_task_ids }]
      }
      execution_rows << build_execution_row(
        task,
        gate: gate,
        sequence: execution_rows.length + 1,
        wave: nil,
        dependency_ids: deps
      )
    end

    {
      execution_order: execution_rows,
      task_gates: execution_rows,
      dependency_graph: {
        total_tasks: tasks.length,
        edge_count: dependency_ids_by_task.values.map(&:length).sum,
        has_cycles: cycle_task_ids.any?,
        cycle_task_ids: cycle_task_ids
      },
      gate_status: build_gate_status_rollup(execution_rows)
    }
  end

  def dependency_ids_for(task)
    (task.fetch('blocked_by_ids', []) + task.fetch('parent_ids', [])).uniq.sort
  end

  def evaluate_gate(task, dependency_ids, task_by_id)
    status = task['status']
    blockers = []

    unsatisfied_dependency_ids = dependency_ids.select do |dependency_id|
      dependency_task = task_by_id[dependency_id]
      dependency_task && !TERMINAL_TASK_STATUSES.include?(dependency_task['status'])
    end

    unsatisfied_dependency_ids.each do |dependency_id|
      blockers << {
        task_id: task['id'],
        reason: 'waiting_on_dependency',
        blocking_task_id: dependency_id,
        blocking_status: task_by_id.dig(dependency_id, 'status')
      }
    end

    if status == 'blocked'
      blockers << { task_id: task['id'], reason: 'status_blocked' }
      gate_state = 'blocked'
    elsif TERMINAL_TASK_STATUSES.include?(status)
      gate_state = 'satisfied'
    elsif !unsatisfied_dependency_ids.empty?
      gate_state = 'waiting_on_signal'
    elsif status == 'in_progress'
      gate_state = 'running'
    else
      gate_state = 'ready'
    end

    {
      gate_state: gate_state,
      ready_for_execution: gate_state == 'ready',
      blockers: blockers.sort_by { |entry| [entry[:reason].to_s, entry[:blocking_task_id].to_s] }
    }
  end

  def build_execution_row(task, gate:, sequence:, wave:, dependency_ids:)
    {
      sequence: sequence,
      wave: wave,
      task_id: task['id'],
      repo_id: task['repo_id'],
      status: task['status'],
      gate_state: gate[:gate_state],
      ready_for_execution: gate[:ready_for_execution],
      dependency_ids: dependency_ids,
      blockers: gate[:blockers]
    }
  end

  def build_gate_status_rollup(task_rows)
    gate_counts = Hash.new(0)
    blocker_rows = []

    task_rows.each do |row|
      gate_counts[row[:gate_state]] += 1 if row[:gate_state].is_a?(String)
      blocker_rows.concat(row[:blockers])
    end

    {
      total_tasks: task_rows.length,
      state_counts: {
        blocked: gate_counts['blocked'],
        ready: gate_counts['ready'],
        running: gate_counts['running'],
        waiting_on_signal: gate_counts['waiting_on_signal'],
        satisfied: gate_counts['satisfied']
      },
      ready_task_ids: task_rows.select { |row| row[:ready_for_execution] }.map { |row| row[:task_id] },
      blocking_tasks: blocker_rows
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
    opts.banner = 'Usage: scripts/query-workspace-feature-graph.rb <manifest-path> (--feature-id ID | --repo-id ID) [--view feature|repo|integration|execution-order|gate-status|policy] [--format json]'
    opts.on('--view VIEW', 'View to render: feature, repo, integration, execution-order, gate-status, or policy') { |value| options[:view] = value }
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
  allowed_views = %w[feature repo integration execution-order gate-status policy]
  raise FeatureGraphQueryError, "Unsupported view '#{options[:view]}'. Use #{allowed_views.join(', ')}." unless allowed_views.include?(options[:view])

  case options[:view]
  when 'feature'
    raise FeatureGraphQueryError, '--feature-id is required for feature view' unless options[:feature_id]
  when 'repo'
    raise FeatureGraphQueryError, '--repo-id is required for repo view' unless options[:repo_id]
  when 'policy'
    return if options[:feature_id] || options[:repo_id]

    raise FeatureGraphQueryError, '--feature-id or --repo-id is required for policy view'
  else
    raise FeatureGraphQueryError, "--feature-id is required for #{options[:view]} view" unless options[:feature_id]
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
           when 'execution-order'
             query.execution_order_view(options[:feature_id], repo_id: options[:repo_id])
           when 'gate-status'
             query.gate_status_view(options[:feature_id], repo_id: options[:repo_id])
           when 'policy'
             query.policy_view(feature_id: options[:feature_id], repo_id: options[:repo_id])
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
