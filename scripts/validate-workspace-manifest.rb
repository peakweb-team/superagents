#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'pathname'
require 'psych'

SCHEMA_PATH = Pathname.new(__dir__).join('../docs/schemas/superagents.workspace.schema.json').expand_path
REPO_ID_REGEX = /\A[a-z0-9][a-z0-9_-]*\z/
KNOWN_TOP_LEVEL_KEYS = %w[schema_version workspace_id description repos features].freeze
KNOWN_REPO_KEYS = %w[id path remote default_branch role language runtime build_system issue_backend ownership policy_refs].freeze
KNOWN_ISSUE_BACKEND_KEYS = %w[type repo project_id tracker mapping].freeze
KNOWN_OWNERSHIP_KEYS = %w[team owners].freeze
ISSUE_BACKEND_TYPES = %w[repo_issues github_project external_tracker none].freeze
WORK_ITEM_ID_REGEX = /\A[a-z0-9][a-z0-9_-]*\z/
KNOWN_FEATURE_KEYS = %w[feature_id title description integration tasks].freeze
KNOWN_TASK_KEYS = %w[id feature_id repo_id title description integration status parent_ids child_ids blocked_by_ids].freeze
KNOWN_FEATURE_INTEGRATION_KEYS = %w[github].freeze
KNOWN_TASK_INTEGRATION_KEYS = %w[github].freeze
KNOWN_GITHUB_FEATURE_KEYS = %w[project child_issue_links sync].freeze
KNOWN_GITHUB_TASK_KEYS = %w[issue pull_requests project_items sync].freeze
KNOWN_GITHUB_ISSUE_KEYS = %w[repo number node_id url].freeze
KNOWN_GITHUB_PR_KEYS = %w[repo number url].freeze
KNOWN_GITHUB_PROJECT_LINK_KEYS = %w[project_id item_id url].freeze
KNOWN_GITHUB_CHILD_ISSUE_LINK_KEYS = %w[task_id repo issue_number url].freeze
KNOWN_GITHUB_SYNC_KEYS = %w[status retry_count last_error last_attempt_at dedupe_key].freeze
WORK_ITEM_STATUSES = %w[todo in_progress blocked done cancelled].freeze
GITHUB_SYNC_STATUSES = %w[pending synced partial error].freeze

class ValidationError < StandardError; end

# Minimal schema evaluator for the subset of JSON Schema keywords used by this repo contract.
class SimpleJsonSchemaValidator
  def initialize(root_schema)
    @root_schema = root_schema
  end

  def validate(data)
    validate_node(@root_schema, data, '$')
  end

  private

  def validate_node(schema, value, pointer)
    schema = resolve_ref_schema(schema)
    errors = []

    if schema.key?('allOf')
      schema['allOf'].each do |subschema|
        errors.concat(validate_node(subschema, value, pointer))
      end
    end

    if schema.key?('if')
      if matches_subschema?(schema['if'], value)
        errors.concat(validate_node(schema['then'], value, pointer)) if schema.key?('then')
      elsif schema.key?('else')
        errors.concat(validate_node(schema['else'], value, pointer))
      end
    end

    if schema.key?('oneOf')
      matches = schema['oneOf'].count { |subschema| matches_subschema?(subschema, value) }
      errors << "#{pointer}: must match exactly one of the oneOf schema branches" unless matches == 1
    end

    if schema.key?('anyOf')
      matches = schema['anyOf'].count { |subschema| matches_subschema?(subschema, value) }
      errors << "#{pointer}: must match at least one of the anyOf schema branches" if matches.zero?
    end

    if schema.key?('not') && matches_subschema?(schema['not'], value)
      errors << "#{pointer}: violates a forbidden schema condition"
    end

    if schema.key?('const') && value != schema['const']
      errors << "#{pointer}: must equal #{schema['const'].inspect}"
    end

    if schema.key?('enum') && !schema['enum'].include?(value)
      errors << "#{pointer}: must be one of #{schema['enum'].join(', ')}"
    end

    if schema.key?('type')
      unless type_matches?(schema['type'], value)
        errors << "#{pointer}: must be of type #{schema['type']}"
        return errors
      end
    end

    if value.is_a?(Hash)
      errors.concat(validate_object_schema(schema, value, pointer))
    elsif value.is_a?(Array)
      errors.concat(validate_array_schema(schema, value, pointer))
    elsif value.is_a?(String)
      errors.concat(validate_string_schema(schema, value, pointer))
    end

    errors
  end

  def validate_object_schema(schema, value, pointer)
    errors = []

    if schema.key?('required')
      schema['required'].each do |key|
        errors << "#{pointer}: missing required key '#{key}'" unless value.key?(key)
      end
    end

    if schema.key?('minProperties') && value.size < schema['minProperties']
      errors << "#{pointer}: must contain at least #{schema['minProperties']} properties"
    end

    properties = schema['properties'] || {}
    value.each do |key, nested_value|
      child_pointer = "#{pointer}.#{key}"
      if properties.key?(key)
        errors.concat(validate_node(properties[key], nested_value, child_pointer))
      elsif schema['additionalProperties'] == false
        errors << "#{child_pointer}: is not allowed by schema"
      elsif schema['additionalProperties'].is_a?(Hash)
        errors.concat(validate_node(schema['additionalProperties'], nested_value, child_pointer))
      end
    end

    errors
  end

  def validate_array_schema(schema, value, pointer)
    errors = []

    if schema.key?('minItems') && value.length < schema['minItems']
      errors << "#{pointer}: must contain at least #{schema['minItems']} items"
    end

    if schema.key?('items')
      value.each_with_index do |item, index|
        errors.concat(validate_node(schema['items'], item, "#{pointer}[#{index}]"))
      end
    end

    errors
  end

  def validate_string_schema(schema, value, pointer)
    errors = []

    if schema.key?('minLength') && value.length < schema['minLength']
      errors << "#{pointer}: must be at least #{schema['minLength']} characters"
    end

    if schema.key?('pattern')
      begin
        regex = Regexp.new(schema['pattern'])
        errors << "#{pointer}: must match #{schema['pattern']}" unless regex.match?(value)
      rescue RegexpError
        errors << "#{pointer}: invalid pattern in schema"
      end
    end

    errors
  end

  def matches_subschema?(schema, value)
    validate_node(schema, value, '$probe').empty?
  end

  def resolve_ref_schema(schema)
    return schema unless schema.is_a?(Hash)
    return schema unless schema.key?('$ref')

    resolve_ref(schema['$ref'])
  end

  def resolve_ref(ref)
    raise ValidationError, "Unsupported non-local schema reference: #{ref}" unless ref.start_with?('#/')

    pointer_parts = ref[2..].split('/').map { |part| part.gsub('~1', '/').gsub('~0', '~') }
    resolved = pointer_parts.reduce(@root_schema) do |memo, part|
      memo.is_a?(Hash) ? memo[part] : nil
    end

    raise ValidationError, "Unable to resolve schema reference: #{ref}" if resolved.nil?

    resolved
  end

  def type_matches?(type_name, value)
    case type_name
    when 'object' then value.is_a?(Hash)
    when 'array' then value.is_a?(Array)
    when 'string' then value.is_a?(String)
    when 'integer' then value.is_a?(Integer)
    when 'number' then value.is_a?(Numeric)
    when 'boolean' then value == true || value == false
    when 'null' then value.nil?
    else
      true
    end
  end
end

class ManifestValidator
  def initialize(data)
    @data = data
    @errors = []
    @repos_by_id = {}
  end

  attr_reader :errors

  def validate
    validate_root
    errors.empty?
  end

  private

  def validate_root
    unless @data.is_a?(Hash)
      add_error('$', 'must be a YAML object')
      return
    end

    require_key(@data, '$', 'schema_version')
    require_key(@data, '$', 'workspace_id')
    require_key(@data, '$', 'repos')

    unknown_top_level = @data.keys - KNOWN_TOP_LEVEL_KEYS
    unknown_top_level.each do |key|
      add_error("$.#{key}", 'is not allowed by schema')
    end

    validate_schema_version(@data['schema_version'])
    validate_workspace_id(@data['workspace_id'])
    validate_description(@data['description']) if @data.key?('description')
    repo_ids = validate_repos(@data['repos'])
    validate_features(@data['features'], repo_ids) if @data.key?('features')
  end

  def validate_schema_version(value)
    add_error('$.schema_version', 'must be an integer') unless value.is_a?(Integer)
    add_error('$.schema_version', 'must equal 1 for this schema') unless value == 1
  end

  def validate_workspace_id(value)
    unless value.is_a?(String) && !value.strip.empty?
      add_error('$.workspace_id', 'must be a non-empty string')
      return
    end

    return if value.match?(REPO_ID_REGEX)

    add_error('$.workspace_id', 'must match ^[a-z0-9][a-z0-9_-]*$')
  end

  def validate_description(value)
    return if value.is_a?(String) && !value.strip.empty?

    add_error('$.description', 'must be a non-empty string when provided')
  end

  def validate_repos(repos)
    repo_id_set = {}

    unless repos.is_a?(Array)
      add_error('$.repos', 'must be an array')
      return repo_id_set
    end

    if repos.empty?
      add_error('$.repos', 'must contain at least one repository entry')
      return repo_id_set
    end

    repo_ids = {}
    repos.each_with_index do |repo, index|
      pointer = "$.repos[#{index}]"
      validate_repo(repo, pointer)

      next unless repo.is_a?(Hash) && repo['id'].is_a?(String)

      if repo_ids.key?(repo['id'])
        add_error("#{pointer}.id", "duplicates repository id '#{repo['id']}' used at $.repos[#{repo_ids[repo['id']]}].id")
      else
        repo_ids[repo['id']] = index
        repo_id_set[repo['id']] = true
        @repos_by_id[repo['id']] = repo
      end
    end

    repo_id_set
  end

  def validate_features(features, repo_ids)
    unless features.is_a?(Array)
      add_error('$.features', 'must be an array')
      return
    end

    if features.empty?
      add_error('$.features', 'must contain at least one feature when provided')
      return
    end

    feature_index_by_id = {}
    features.each_with_index do |feature, index|
      pointer = "$.features[#{index}]"
      feature_id = validate_feature(feature, pointer, repo_ids)
      next unless feature_id

      if feature_index_by_id.key?(feature_id)
        prior_pointer = "$.features[#{feature_index_by_id[feature_id]}].feature_id"
        add_error("#{pointer}.feature_id", "duplicates feature_id '#{feature_id}' used at #{prior_pointer}")
      else
        feature_index_by_id[feature_id] = index
      end
    end
  end

  def validate_feature(feature, pointer, repo_ids)
    unless feature.is_a?(Hash)
      add_error(pointer, 'must be an object')
      return nil
    end

    %w[feature_id title tasks].each do |key|
      require_key(feature, pointer, key)
    end

    unknown_feature_keys = feature.keys - KNOWN_FEATURE_KEYS
    unknown_feature_keys.each do |key|
      add_error("#{pointer}.#{key}", 'is not allowed by schema')
    end

    feature_id = feature['feature_id']
    validate_work_item_id(feature_id, "#{pointer}.feature_id", field_name: 'feature_id')
    validate_non_empty_string(feature['title'], "#{pointer}.title")
    validate_non_empty_string(feature['description'], "#{pointer}.description") if feature.key?('description')
    task_by_id = validate_feature_tasks(feature['tasks'], "#{pointer}.tasks", feature_id, repo_ids)
    validate_feature_integration(feature['integration'], "#{pointer}.integration", task_by_id) if feature.key?('integration')

    feature_id if feature_id.is_a?(String) && !feature_id.strip.empty?
  end

  def validate_feature_tasks(tasks, pointer, feature_id, repo_ids)
    unless tasks.is_a?(Array)
      add_error(pointer, 'must be an array')
      return {}
    end

    if tasks.empty?
      add_error(pointer, 'must contain at least one task')
      return {}
    end

    task_ids = {}
    task_by_id = {}
    tasks.each_with_index do |task, index|
      task_pointer = "#{pointer}[#{index}]"
      task_id = validate_feature_task(task, task_pointer, feature_id, repo_ids)
      next unless task_id

      if task_ids.key?(task_id)
        prior_pointer = "#{pointer}[#{task_ids[task_id]}].id"
        add_error("#{task_pointer}.id", "duplicates task id '#{task_id}' used at #{prior_pointer}")
      else
        task_ids[task_id] = index
        task_by_id[task_id] = task
      end
    end

    tasks.each_with_index do |task, index|
      next unless task.is_a?(Hash)

      task_pointer = "#{pointer}[#{index}]"
      validate_task_link_array(task['parent_ids'], "#{task_pointer}.parent_ids", task_ids, task['id']) if task.key?('parent_ids')
      validate_task_link_array(task['child_ids'], "#{task_pointer}.child_ids", task_ids, task['id']) if task.key?('child_ids')
      validate_task_link_array(task['blocked_by_ids'], "#{task_pointer}.blocked_by_ids", task_ids, task['id']) if task.key?('blocked_by_ids')
      validate_parent_child_consistency(task, task_pointer, tasks, task_ids)
    end

    task_by_id
  end

  def validate_feature_task(task, pointer, feature_id, repo_ids)
    unless task.is_a?(Hash)
      add_error(pointer, 'must be an object')
      return nil
    end

    %w[id feature_id repo_id title status].each do |key|
      require_key(task, pointer, key)
    end

    unknown_task_keys = task.keys - KNOWN_TASK_KEYS
    unknown_task_keys.each do |key|
      add_error("#{pointer}.#{key}", 'is not allowed by schema')
    end

    task_id = task['id']
    validate_work_item_id(task_id, "#{pointer}.id", field_name: 'id')
    validate_work_item_id(task['feature_id'], "#{pointer}.feature_id", field_name: 'feature_id')
    validate_work_item_id(task['repo_id'], "#{pointer}.repo_id", field_name: 'repo_id')
    validate_non_empty_string(task['title'], "#{pointer}.title")
    validate_non_empty_string(task['description'], "#{pointer}.description") if task.key?('description')
    validate_task_integration(task['integration'], "#{pointer}.integration", task) if task.key?('integration')
    validate_task_status(task['status'], "#{pointer}.status")

    if task['feature_id'].is_a?(String) && feature_id.is_a?(String) && task['feature_id'] != feature_id
      add_error("#{pointer}.feature_id", "must match parent feature_id '#{feature_id}'")
    end

    if task['repo_id'].is_a?(String) && !repo_ids.key?(task['repo_id'])
      add_error("#{pointer}.repo_id", "references unknown repo id '#{task['repo_id']}'")
    end

    task_id if task_id.is_a?(String) && !task_id.strip.empty?
  end

  def validate_feature_integration(integration, pointer, task_by_id)
    unless integration.is_a?(Hash)
      add_error(pointer, 'must be an object')
      return
    end

    unknown_keys = integration.keys - KNOWN_FEATURE_INTEGRATION_KEYS
    unknown_keys.each do |key|
      add_error("#{pointer}.#{key}", 'is not allowed by schema')
    end

    validate_feature_github_integration(integration['github'], "#{pointer}.github", task_by_id) if integration.key?('github')
    add_error(pointer, 'must include at least one integration mapping') if integration.empty?
  end

  def validate_feature_github_integration(github, pointer, task_by_id)
    unless github.is_a?(Hash)
      add_error(pointer, 'must be an object')
      return
    end

    unknown_keys = github.keys - KNOWN_GITHUB_FEATURE_KEYS
    unknown_keys.each do |key|
      add_error("#{pointer}.#{key}", 'is not allowed by schema')
    end

    validate_github_project_link(github['project'], "#{pointer}.project") if github.key?('project')
    validate_feature_child_issue_links(github['child_issue_links'], "#{pointer}.child_issue_links", task_by_id) if github.key?('child_issue_links')
    validate_github_sync(github['sync'], "#{pointer}.sync") if github.key?('sync')
    add_error(pointer, 'must include at least one github mapping field') if github.empty?
  end

  def validate_feature_child_issue_links(child_issue_links, pointer, task_by_id)
    unless child_issue_links.is_a?(Array)
      add_error(pointer, 'must be an array')
      return
    end

    child_issue_links.each_with_index do |link, index|
      link_pointer = "#{pointer}[#{index}]"
      unless link.is_a?(Hash)
        add_error(link_pointer, 'must be an object')
        next
      end

      %w[task_id repo issue_number].each do |key|
        require_key(link, link_pointer, key)
      end

      unknown_keys = link.keys - KNOWN_GITHUB_CHILD_ISSUE_LINK_KEYS
      unknown_keys.each do |key|
        add_error("#{link_pointer}.#{key}", 'is not allowed by schema')
      end

      validate_work_item_id(link['task_id'], "#{link_pointer}.task_id", field_name: 'task_id')
      validate_non_empty_string(link['repo'], "#{link_pointer}.repo")
      validate_positive_integer(link['issue_number'], "#{link_pointer}.issue_number")
      validate_non_empty_string(link['url'], "#{link_pointer}.url") if link.key?('url')

      next unless link['task_id'].is_a?(String)

      task = task_by_id[link['task_id']]
      unless task
        add_error("#{link_pointer}.task_id", "references unknown task id '#{link['task_id']}'")
        next
      end

      issue = task.dig('integration', 'github', 'issue')
      next unless issue.is_a?(Hash)

      if issue['repo'].is_a?(String) && issue['repo'] != link['repo']
        add_error("#{link_pointer}.repo", "must match task issue repo '#{issue['repo']}' for task '#{link['task_id']}'")
      end

      if issue['number'].is_a?(Integer) && issue['number'] != link['issue_number']
        add_error("#{link_pointer}.issue_number", "must match task issue number #{issue['number']} for task '#{link['task_id']}'")
      end
    end
  end

  def validate_task_integration(integration, pointer, task)
    unless integration.is_a?(Hash)
      add_error(pointer, 'must be an object')
      return
    end

    unknown_keys = integration.keys - KNOWN_TASK_INTEGRATION_KEYS
    unknown_keys.each do |key|
      add_error("#{pointer}.#{key}", 'is not allowed by schema')
    end

    validate_task_github_integration(integration['github'], "#{pointer}.github", task) if integration.key?('github')
    add_error(pointer, 'must include at least one integration mapping') if integration.empty?
  end

  def validate_task_github_integration(github, pointer, task)
    unless github.is_a?(Hash)
      add_error(pointer, 'must be an object')
      return
    end

    unknown_keys = github.keys - KNOWN_GITHUB_TASK_KEYS
    unknown_keys.each do |key|
      add_error("#{pointer}.#{key}", 'is not allowed by schema')
    end

    validate_github_issue_link(github['issue'], "#{pointer}.issue", task) if github.key?('issue')
    validate_github_pr_links(github['pull_requests'], "#{pointer}.pull_requests") if github.key?('pull_requests')
    validate_github_project_items(github['project_items'], "#{pointer}.project_items") if github.key?('project_items')
    validate_github_sync(github['sync'], "#{pointer}.sync") if github.key?('sync')
    add_error(pointer, 'must include at least one github mapping field') if github.empty?
  end

  def validate_github_issue_link(issue, pointer, task)
    unless issue.is_a?(Hash)
      add_error(pointer, 'must be an object')
      return
    end

    require_key(issue, pointer, 'repo')

    unknown_keys = issue.keys - KNOWN_GITHUB_ISSUE_KEYS
    unknown_keys.each do |key|
      add_error("#{pointer}.#{key}", 'is not allowed by schema')
    end

    validate_non_empty_string(issue['repo'], "#{pointer}.repo") if issue.key?('repo')
    validate_positive_integer(issue['number'], "#{pointer}.number") if issue.key?('number')
    validate_non_empty_string(issue['node_id'], "#{pointer}.node_id") if issue.key?('node_id')
    validate_non_empty_string(issue['url'], "#{pointer}.url") if issue.key?('url')

    return unless issue['repo'].is_a?(String) && task['repo_id'].is_a?(String)

    repo = @repos_by_id[task['repo_id']]
    return unless repo.is_a?(Hash) && repo.dig('issue_backend', 'type') == 'repo_issues'

    expected_repo = repo.dig('issue_backend', 'repo')
    return unless expected_repo.is_a?(String)
    return if expected_repo == issue['repo']

    add_error("#{pointer}.repo", "must match repo issue_backend.repo '#{expected_repo}' for repo_id '#{task['repo_id']}'")
  end

  def validate_github_pr_links(pull_requests, pointer)
    unless pull_requests.is_a?(Array)
      add_error(pointer, 'must be an array')
      return
    end

    pull_requests.each_with_index do |pull_request, index|
      pr_pointer = "#{pointer}[#{index}]"
      unless pull_request.is_a?(Hash)
        add_error(pr_pointer, 'must be an object')
        next
      end

      %w[repo number].each do |key|
        require_key(pull_request, pr_pointer, key)
      end

      unknown_keys = pull_request.keys - KNOWN_GITHUB_PR_KEYS
      unknown_keys.each do |key|
        add_error("#{pr_pointer}.#{key}", 'is not allowed by schema')
      end

      validate_non_empty_string(pull_request['repo'], "#{pr_pointer}.repo")
      validate_positive_integer(pull_request['number'], "#{pr_pointer}.number")
      validate_non_empty_string(pull_request['url'], "#{pr_pointer}.url") if pull_request.key?('url')
    end
  end

  def validate_github_project_items(project_items, pointer)
    unless project_items.is_a?(Array)
      add_error(pointer, 'must be an array')
      return
    end

    project_items.each_with_index do |item, index|
      validate_github_project_link(item, "#{pointer}[#{index}]")
    end
  end

  def validate_github_project_link(project, pointer)
    unless project.is_a?(Hash)
      add_error(pointer, 'must be an object')
      return
    end

    require_key(project, pointer, 'project_id')

    unknown_keys = project.keys - KNOWN_GITHUB_PROJECT_LINK_KEYS
    unknown_keys.each do |key|
      add_error("#{pointer}.#{key}", 'is not allowed by schema')
    end

    validate_non_empty_string(project['project_id'], "#{pointer}.project_id")
    validate_non_empty_string(project['item_id'], "#{pointer}.item_id") if project.key?('item_id')
    validate_non_empty_string(project['url'], "#{pointer}.url") if project.key?('url')
  end

  def validate_github_sync(sync, pointer)
    unless sync.is_a?(Hash)
      add_error(pointer, 'must be an object')
      return
    end

    unknown_keys = sync.keys - KNOWN_GITHUB_SYNC_KEYS
    unknown_keys.each do |key|
      add_error("#{pointer}.#{key}", 'is not allowed by schema')
    end

    if sync.key?('status')
      unless sync['status'].is_a?(String) && GITHUB_SYNC_STATUSES.include?(sync['status'])
        add_error("#{pointer}.status", "must be one of: #{GITHUB_SYNC_STATUSES.join(', ')}")
      end
    end

    validate_non_negative_integer(sync['retry_count'], "#{pointer}.retry_count") if sync.key?('retry_count')
    validate_non_empty_string(sync['last_error'], "#{pointer}.last_error") if sync.key?('last_error')
    validate_non_empty_string(sync['last_attempt_at'], "#{pointer}.last_attempt_at") if sync.key?('last_attempt_at')
    validate_non_empty_string(sync['dedupe_key'], "#{pointer}.dedupe_key") if sync.key?('dedupe_key')
  end

  def validate_task_status(status, pointer)
    unless status.is_a?(String) && WORK_ITEM_STATUSES.include?(status)
      add_error(pointer, "must be one of: #{WORK_ITEM_STATUSES.join(', ')}")
    end
  end

  def validate_task_link_array(value, pointer, known_task_ids, current_task_id)
    unless value.is_a?(Array)
      add_error(pointer, 'must be an array of task ids')
      return
    end

    value.each_with_index do |linked_id, index|
      link_pointer = "#{pointer}[#{index}]"
      validate_work_item_id(linked_id, link_pointer, field_name: 'task id')
      next unless linked_id.is_a?(String)

      add_error(link_pointer, "cannot reference itself '#{linked_id}'") if current_task_id.is_a?(String) && linked_id == current_task_id
      add_error(link_pointer, "references unknown task id '#{linked_id}'") unless known_task_ids.key?(linked_id)
    end
  end

  def validate_parent_child_consistency(task, pointer, tasks, known_task_ids)
    return unless task.is_a?(Hash)
    return unless task.key?('child_ids')

    child_ids = task['child_ids']
    return unless child_ids.is_a?(Array)

    child_ids.each do |child_id|
      next unless child_id.is_a?(String) && known_task_ids.key?(child_id)

      child_task = tasks[known_task_ids[child_id]]
      child_parent_ids = child_task['parent_ids']
      next if child_parent_ids.is_a?(Array) && child_parent_ids.include?(task['id'])

      add_error("#{pointer}.child_ids", "declares child '#{child_id}' but #{child_id} does not include '#{task['id']}' in parent_ids")
    end
  end

  def validate_work_item_id(value, pointer, field_name:)
    unless value.is_a?(String) && !value.strip.empty?
      add_error(pointer, "must be a non-empty string for #{field_name}")
      return
    end

    return if value.match?(WORK_ITEM_ID_REGEX)

    add_error(pointer, 'must match ^[a-z0-9][a-z0-9_-]*$')
  end

  def validate_repo(repo, pointer)
    unless repo.is_a?(Hash)
      add_error(pointer, 'must be an object')
      return
    end

    %w[id default_branch role build_system issue_backend].each do |key|
      require_key(repo, pointer, key)
    end

    unknown_repo_keys = repo.keys - KNOWN_REPO_KEYS
    unknown_repo_keys.each do |key|
      add_error("#{pointer}.#{key}", 'is not allowed by schema')
    end

    validate_repo_id(repo['id'], pointer)
    validate_repo_location(repo, pointer)
    validate_non_empty_string(repo['default_branch'], "#{pointer}.default_branch")
    validate_non_empty_string(repo['role'], "#{pointer}.role")
    validate_non_empty_string(repo['build_system'], "#{pointer}.build_system")
    validate_non_empty_string(repo['language'], "#{pointer}.language") if repo.key?('language')
    validate_non_empty_string(repo['runtime'], "#{pointer}.runtime") if repo.key?('runtime')
    validate_issue_backend(repo['issue_backend'], "#{pointer}.issue_backend")
    validate_ownership(repo['ownership'], "#{pointer}.ownership") if repo.key?('ownership')
    validate_policy_refs(repo['policy_refs'], "#{pointer}.policy_refs") if repo.key?('policy_refs')
  end

  def validate_repo_id(value, pointer)
    unless value.is_a?(String) && !value.strip.empty?
      add_error("#{pointer}.id", 'must be a non-empty string')
      return
    end

    return if value.match?(REPO_ID_REGEX)

    add_error("#{pointer}.id", 'must match ^[a-z0-9][a-z0-9_-]*$')
  end

  def validate_repo_location(repo, pointer)
    has_path = repo.key?('path')
    has_remote = repo.key?('remote')

    if has_path && has_remote
      add_error(pointer, "must define exactly one of 'path' or 'remote' (not both)")
      return
    end

    unless has_path || has_remote
      add_error(pointer, "must define exactly one of 'path' or 'remote'")
      return
    end

    validate_non_empty_string(repo['path'], "#{pointer}.path") if has_path
    validate_non_empty_string(repo['remote'], "#{pointer}.remote") if has_remote
  end

  def validate_issue_backend(backend, pointer)
    unless backend.is_a?(Hash)
      add_error(pointer, 'must be an object')
      return
    end

    require_key(backend, pointer, 'type')

    unknown_keys = backend.keys - KNOWN_ISSUE_BACKEND_KEYS
    unknown_keys.each do |key|
      add_error("#{pointer}.#{key}", 'is not allowed by schema')
    end

    type = backend['type']
    unless type.is_a?(String) && ISSUE_BACKEND_TYPES.include?(type)
      add_error("#{pointer}.type", "must be one of: #{ISSUE_BACKEND_TYPES.join(', ')}")
      return
    end

    allowed_keys = case type
                   when 'repo_issues' then %w[type repo]
                   when 'github_project' then %w[type project_id]
                   when 'external_tracker' then %w[type tracker mapping]
                   when 'none' then %w[type]
                   else KNOWN_ISSUE_BACKEND_KEYS
                   end

    incompatible_keys = backend.keys - allowed_keys
    incompatible_keys.each do |key|
      add_error("#{pointer}.#{key}", "is not allowed for type '#{type}'")
    end

    case type
    when 'repo_issues'
      require_non_empty_string(backend, pointer, 'repo')
    when 'github_project'
      require_non_empty_string(backend, pointer, 'project_id')
    when 'external_tracker'
      require_non_empty_string(backend, pointer, 'tracker')
      validate_mapping(backend['mapping'], "#{pointer}.mapping")
    end
  end

  def validate_mapping(mapping, pointer)
    unless mapping.is_a?(Hash)
      add_error(pointer, 'must be an object for external_tracker backends')
      return
    end

    if mapping.empty?
      add_error(pointer, 'must include at least one mapping entry')
      return
    end

    mapping.each do |key, value|
      add_error(pointer, "contains non-string key #{key.inspect}") unless key.is_a?(String)
      validate_non_empty_string(value, "#{pointer}.#{key}")
    end
  end

  def validate_ownership(ownership, pointer)
    unless ownership.is_a?(Hash)
      add_error(pointer, 'must be an object')
      return
    end

    unknown_keys = ownership.keys - KNOWN_OWNERSHIP_KEYS
    unknown_keys.each do |key|
      add_error("#{pointer}.#{key}", 'is not allowed by schema')
    end

    if ownership.key?('team')
      validate_non_empty_string(ownership['team'], "#{pointer}.team")
    end

    if ownership.key?('owners')
      owners = ownership['owners']
      unless owners.is_a?(Array)
        add_error("#{pointer}.owners", 'must be an array of owner identifiers')
        return
      end

      if owners.empty?
        add_error("#{pointer}.owners", 'must not be empty when provided')
        return
      end

      owners.each_with_index do |owner, index|
        validate_non_empty_string(owner, "#{pointer}.owners[#{index}]")
      end
    end
  end

  def validate_policy_refs(policy_refs, pointer)
    unless policy_refs.is_a?(Array)
      add_error(pointer, 'must be an array')
      return
    end

    policy_refs.each_with_index do |ref, index|
      validate_non_empty_string(ref, "#{pointer}[#{index}]")
    end
  end

  def validate_non_empty_string(value, pointer)
    add_error(pointer, 'must be a non-empty string') unless value.is_a?(String) && !value.strip.empty?
  end

  def validate_positive_integer(value, pointer)
    add_error(pointer, 'must be a positive integer') unless value.is_a?(Integer) && value.positive?
  end

  def validate_non_negative_integer(value, pointer)
    add_error(pointer, 'must be an integer greater than or equal to 0') unless value.is_a?(Integer) && value >= 0
  end

  def require_non_empty_string(hash, pointer, key)
    require_key(hash, pointer, key)
    validate_non_empty_string(hash[key], "#{pointer}.#{key}") if hash.key?(key)
  end

  def require_key(hash, pointer, key)
    add_error(pointer, "missing required key '#{key}'") unless hash.key?(key)
  end

  def add_error(pointer, message)
    @errors << "#{pointer}: #{message}"
  end
end

def load_schema
  raise ValidationError, "Schema file not found at #{SCHEMA_PATH}" unless SCHEMA_PATH.file?

  JSON.parse(SCHEMA_PATH.read)
rescue JSON::ParserError => e
  raise ValidationError, "Schema file is not valid JSON: #{e.message}"
end

def load_manifest(manifest_path)
  raise ValidationError, "Manifest file not found: #{manifest_path}" unless File.file?(manifest_path)

  raw = File.read(manifest_path)
  data = Psych.safe_load(raw, permitted_classes: [], permitted_symbols: [], aliases: false)
  return data
rescue Psych::SyntaxError => e
  raise ValidationError, "Manifest YAML parse error: #{e.message.lines.first.strip}"
end

def schema_guardrails!(schema)
  schema_version = schema.dig('properties', 'schema_version', 'const')
  unless schema_version == 1
    raise ValidationError, "Unsupported schema constant in #{SCHEMA_PATH}: expected schema_version const 1, found #{schema_version.inspect}"
  end
end

def validate_manifest(path)
  schema = load_schema
  manifest_data = load_manifest(path)
  schema_guardrails!(schema)

  schema_errors = SimpleJsonSchemaValidator.new(schema).validate(manifest_data)
  custom_validator = ManifestValidator.new(manifest_data)
  custom_valid = custom_validator.validate

  if schema_errors.empty? && custom_valid
    puts "Manifest is valid: #{path}"
    return 0
  end

  warn "Manifest validation failed for #{path}:"
  schema_errors.each { |error| warn "  - #{error}" }
  custom_validator.errors.each { |error| warn "  - #{error}" }
  1
rescue ValidationError => e
  warn "Manifest validation failed for #{path}: #{e.message}"
  1
end

def run_cli(argv)
  if argv.empty?
    warn 'Usage: scripts/validate-workspace-manifest.rb <manifest-path> [manifest-path...]'
    return 2
  end

  exit_code = 0
  argv.each do |manifest_path|
    result = validate_manifest(manifest_path)
    exit_code = 1 if result != 0
  end

  exit_code
end

exit(run_cli(ARGV)) if $PROGRAM_NAME == __FILE__
