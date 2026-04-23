#!/usr/bin/env ruby
# frozen_string_literal: true

require 'set'
require 'uri'

ROOT_DIR = File.expand_path('..', __dir__)
SCANNED_GLOBS = [
  'README.md',
  'CONTRIBUTING.md',
  'CONTRIBUTING_zh-CN.md',
  'docs/**/*.md',
  'examples/**/*.md',
  'skills/fragments/**/*.md',
  'integrations/**/README.md'
].freeze

class DocLinkValidator
  INLINE_LINK = /\[[^\]]+\]\(([^)]+)\)/.freeze
  REFERENCE_DEF = /^\[[^\]]+\]:\s*(\S+)/.freeze

  def initialize
    @errors = []
    @anchor_cache = {}
  end

  def run!
    files = SCANNED_GLOBS.flat_map { |glob| Dir.glob(File.join(ROOT_DIR, glob)) }.uniq.sort
    markdown_files = files.select { |path| File.file?(path) && File.extname(path).downcase == '.md' }

    markdown_files.each do |file|
      content = read_text(file)
      validate_content_links(file, content)
    end

    if @errors.empty?
      puts "Doc link validation passed for #{markdown_files.length} markdown file(s)."
      0
    else
      puts "Doc link validation failed with #{@errors.length} error(s):"
      @errors.each { |line| puts "- #{line}" }
      1
    end
  end

  private

  def validate_content_links(file, content)
    links = []

    content.scan(INLINE_LINK) { |m| links << m[0] }
    content.each_line do |line|
      match = line.match(REFERENCE_DEF)
      links << match[1] if match
    end

    links.each do |raw_target|
      target = normalize_target(raw_target)
      next if target.nil? || target.empty?
      next if external_link?(target)

      if target.start_with?('#')
        validate_anchor_target(file, file, target[1..])
        next
      end

      path_part, anchor = split_target(target)
      target_path = File.expand_path(path_part, File.dirname(file))

      unless File.exist?(target_path)
        @errors << "#{rel(file)}: linked path does not exist -> #{target}"
        next
      end

      next unless anchor

      if File.directory?(target_path)
        @errors << "#{rel(file)}: anchor link points to directory -> #{target}"
        next
      end

      if File.extname(target_path).downcase != '.md'
        @errors << "#{rel(file)}: anchor link points to non-markdown file -> #{target}"
        next
      end

      validate_anchor_target(file, target_path, anchor)
    end
  end

  def normalize_target(raw_target)
    target = raw_target.strip
    target = target[1..-2] if target.start_with?('<') && target.end_with?('>')
    target = target.split(/\s+/, 2).first
    target
  end

  def external_link?(target)
    return true if target.start_with?('mailto:', 'tel:', 'data:')
    return true if target.match?(/\A[a-z][a-z0-9+.-]*:\/\//i)

    false
  end

  def split_target(target)
    if target.include?('#')
      path_part, anchor = target.split('#', 2)
      [path_part, decode_anchor(anchor)]
    else
      [target, nil]
    end
  end

  def validate_anchor_target(source_file, target_file, anchor)
    normalized_anchor = normalize_anchor(anchor)
    anchors = anchors_for(target_file)
    return if anchors.include?(normalized_anchor)

    @errors << "#{rel(source_file)}: missing anchor '#{anchor}' in #{rel(target_file)}"
  end

  def anchors_for(file)
    return @anchor_cache[file] if @anchor_cache.key?(file)

    slug_counts = Hash.new(0)
    anchors = Set.new

    read_text(file).each_line do |line|
      match = line.match(/^\s{0,3}\#{1,6}\s+(.+?)\s*#*\s*$/)
      next unless match

      base = normalize_anchor(match[1])
      next if base.empty?

      count = slug_counts[base]
      slug = count.zero? ? base : "#{base}-#{count}"
      slug_counts[base] += 1
      anchors << slug
    end

    @anchor_cache[file] = anchors
  end

  def decode_anchor(anchor)
    URI.decode_www_form_component(anchor)
  rescue StandardError
    anchor
  end

  def normalize_anchor(value)
    value
      .downcase
      .gsub(/<[^>]+>/, '')
      .gsub(/`+/, '')
      .gsub(/[^\p{Letter}\p{Number}\p{Mark}\s\-_]/u, '')
      .strip
      .gsub(/[\s_]+/, '-')
      .gsub(/-+/, '-')
      .gsub(/^-|-$/, '')
  end

  def rel(path)
    path.sub("#{ROOT_DIR}/", '')
  end

  def read_text(path)
    File.binread(path).force_encoding('UTF-8').encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
  end
end

exit(DocLinkValidator.new.run!)
