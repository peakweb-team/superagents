#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'pathname'
require 'psych'

SCHEMA_PATH = Pathname.new(__dir__).join('../docs/schemas/superagents.workspace.schema.json').expand_path
REPO_ID_REGEX = /\A[a-z0-9][a-z0-9_-]*\z/
KNOWN_TOP_LEVEL_KEYS = %w[schema_version workspace_id description repos].freeze
KNOWN_REPO_KEYS = %w[id path remote default_branch role language runtime build_system issue_backend ownership policy_refs].freeze
KNOWN_ISSUE_BACKEND_KEYS = %w[type repo project_id tracker mapping].freeze
KNOWN_OWNERSHIP_KEYS = %w[team owners].freeze
ISSUE_BACKEND_TYPES = %w[repo_issues github_project external_tracker none].freeze

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
    validate_repos(@data['repos'])
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
    unless repos.is_a?(Array)
      add_error('$.repos', 'must be an array')
      return
    end

    if repos.empty?
      add_error('$.repos', 'must contain at least one repository entry')
      return
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
      end
    end
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

if ARGV.empty?
  warn 'Usage: scripts/validate-workspace-manifest.rb <manifest-path> [manifest-path...]'
  exit 2
end

exit_code = 0
ARGV.each do |manifest_path|
  result = validate_manifest(manifest_path)
  exit_code = 1 if result != 0
end

exit exit_code
