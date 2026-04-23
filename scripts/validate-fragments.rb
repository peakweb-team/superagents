#!/usr/bin/env ruby
# frozen_string_literal: true

require 'yaml'

ROOT_DIR = File.expand_path('..', __dir__)
FRAGMENTS_DIR = File.join(ROOT_DIR, 'skills', 'fragments')
ALLOWED_FRAGMENT_TYPES = %w[generic provider].freeze
ALLOWED_LAYERS = %w[task-intake project-management delivery orchestration runtime].freeze
REQUIRED_FIELDS = %w[
  schema_version
  id
  title
  fragment_type
  layer
  summary
  capabilities
  selection
  composition
].freeze

class FragmentValidator
  def initialize
    @errors = []
    @fragments = []
  end

  def run!
    fragment_files = Dir.glob(File.join(FRAGMENTS_DIR, '**', '*.md')).sort.reject do |path|
      File.basename(path) == 'README.md'
    end

    if fragment_files.empty?
      @errors << "No fragment files found under #{FRAGMENTS_DIR}."
      return finish
    end

    ids = {}

    fragment_files.each do |path|
      fragment = parse_fragment(path)
      next unless fragment

      validate_required_fields(fragment)
      validate_enums(fragment)
      validate_shape(fragment)

      id = fragment['id']
      if id.is_a?(String) && !id.strip.empty?
        if ids.key?(id)
          @errors << "#{rel(path)}: duplicate fragment id '#{id}' (already used by #{rel(ids[id])})"
        else
          ids[id] = path
        end
      end

      @fragments << fragment.merge('__path' => path)
    end

    validate_suggest_references(ids.keys)
    finish
  end

  private

  def parse_fragment(path)
    content = File.read(path)

    unless content.start_with?("---\n") || content.start_with?("---\r\n")
      @errors << "#{rel(path)}: missing YAML frontmatter start delimiter"
      return nil
    end

    lines = content.lines
    end_index = nil
    lines.each_with_index do |line, idx|
      next if idx.zero?
      if line.strip == '---'
        end_index = idx
        break
      end
    end

    unless end_index
      @errors << "#{rel(path)}: missing YAML frontmatter end delimiter"
      return nil
    end

    frontmatter = lines[1...end_index].join

    begin
      data = YAML.safe_load(frontmatter, permitted_classes: [], aliases: false)
    rescue Psych::SyntaxError => e
      @errors << "#{rel(path)}: invalid YAML frontmatter (#{e.message})"
      return nil
    end

    unless data.is_a?(Hash)
      @errors << "#{rel(path)}: frontmatter must parse to a mapping/object"
      return nil
    end

    data
  end

  def validate_required_fields(fragment)
    path = fragment.fetch('__path', nil)
    missing = REQUIRED_FIELDS.reject { |field| fragment.key?(field) }
    missing.each do |field|
      @errors << "#{rel(path)}: missing required field '#{field}'"
    end
  end

  def validate_enums(fragment)
    path = fragment.fetch('__path', nil)

    fragment_type = fragment['fragment_type']
    if fragment_type && !ALLOWED_FRAGMENT_TYPES.include?(fragment_type)
      @errors << "#{rel(path)}: fragment_type must be one of #{ALLOWED_FRAGMENT_TYPES.join(', ')}"
    end

    layer = fragment['layer']
    if layer && !ALLOWED_LAYERS.include?(layer)
      @errors << "#{rel(path)}: layer must be one of #{ALLOWED_LAYERS.join(', ')}"
    end
  end

  def validate_shape(fragment)
    path = fragment.fetch('__path', nil)

    capabilities = fragment['capabilities']
    unless capabilities.is_a?(Array) && capabilities.all? { |entry| entry.is_a?(String) && !entry.strip.empty? }
      @errors << "#{rel(path)}: capabilities must be an array of non-empty strings"
    end

    selection = fragment['selection']
    unless selection.is_a?(Hash)
      @errors << "#{rel(path)}: selection must be an object"
    end

    composition = fragment['composition']
    unless composition.is_a?(Hash)
      @errors << "#{rel(path)}: composition must be an object"
      return
    end

    suggests = composition['suggests']
    unless suggests.is_a?(Array) && suggests.all? { |entry| entry.is_a?(String) && !entry.strip.empty? }
      @errors << "#{rel(path)}: composition.suggests must be an array of non-empty fragment IDs"
    end
  end

  def validate_suggest_references(all_ids)
    id_set = all_ids.to_h { |id| [id, true] }

    @fragments.each do |fragment|
      path = fragment['__path']
      suggests = fragment.dig('composition', 'suggests')
      next unless suggests.is_a?(Array)

      suggests.each do |target_id|
        next if id_set[target_id]
        @errors << "#{rel(path)}: composition.suggests references unknown fragment id '#{target_id}'"
      end
    end
  end

  def rel(path)
    return '<unknown>' if path.nil?
    path.sub("#{ROOT_DIR}/", '')
  end

  def finish
    if @errors.empty?
      puts "Fragment contract validation passed for #{@fragments.length} fragment files."
      0
    else
      puts "Fragment contract validation failed with #{@errors.length} error(s):"
      @errors.each { |error| puts "- #{error}" }
      1
    end
  end
end

exit(FragmentValidator.new.run!)
