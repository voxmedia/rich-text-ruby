require 'delegate'
require 'singleton'
require 'nokogiri'

module RichText
  # @todo Work in progress
  class HTML
    ConfigError = Class.new(StandardError)

    def self.render_xml(delta, options={})
      new(RichText.config, options).render(delta)
    end

    def self.render(delta, options={})
      render_xml(delta, options).inner_html
    end

    attr_reader :doc, :root

    def initialize(config, options)
      @default_block_format = options[:default_block_format] || config.html_default_block_format
      @formats = config.html_formats.merge(options[:formats] || {})
      @inline_formats = Hash[@formats.select { |k, v| !v.key?(:type) || v[:type] == :inline }]
      @block_formats = Hash[@formats.select { |k, v| v[:type] == :block }]

      @doc = Nokogiri::XML::Document.new
      @doc.encoding = 'UTF-8'
      @root = create_tag('main')
    end

    def render(delta)
      raise TypeError.new("cannot convert retain or delete ops to html") unless delta.insert_only?

      feeds = []
      delta.each_line do |line|
        next unless line.ops.any?

        # group lines separated by inline returns ("br" tags) together
        if feeds.any? && inline_tag?(feeds.last.last)
          feeds.last.push(*line.ops)
        else
          feeds.push(line.ops.dup)
        end
      end

      feeds.each { |feed| @root.add_child(render_line_feed(feed)) }
      @root
    end

    def create_tag(name)
      create_node(tag: name)
    end

  private

    def inline_tag?(op)
      op.attributes.keys.find { |k| @inline_formats[k.to_sym]&.key?(:tag) }
    end

    def create_node(format={}, content=nil, tag:nil, op:nil, attr_value:nil)
      el = Nokogiri::XML::Node.new(tag || format[:tag], @doc)

      if content.is_a?(String)
        el.content = content
      elsif content.is_a?(Nokogiri::XML::Node)
        el.add_child(content)
      elsif content.is_a?(Array)
        content.each { |n| el.add_child(n) }
      end

      if format[:build].respond_to?(:call) && op
        el = format[:build].call(el, op)
      end

      el
    end

    def render_line_feed(feed)
      content = feed.each_with_object([]) do |op, els|
        if op.value.is_a?(String)
          value = op.value.sub(/\n$/, '')
          els << apply_formats(@inline_formats, value, op) if value.length > 0 || inline_tag?(op)
        elsif op.value.is_a?(Hash) && key = @inline_formats.keys.detect { |k| op.value.key?(k) }
          els << apply_format(@inline_formats[key.to_sym], op.value, op)
        end
      end

      # manually build block attributes to course-correct malformed structure
      # reject any inline formats, and assure a block tag format is defined
      op = feed.last
      block_attrs = op.attributes.slice(*@block_formats.keys)
      unless block_attrs.detect { |k, v| @block_formats[k.to_sym].key?(:tag) }
        block_attrs[@default_block_format.to_sym] = true
      end

      apply_formats(@block_formats, content, op, attributes: block_attrs)
    end

    def apply_formats(formats, content, op, attributes:nil)
      attributes ||= op.attributes

      # order of operations for rendering formats
      # tag formats are applied first (sorted by priority)
      # other attribute formats follow (sorted by priority)
      ordered_formats = attributes.keys.map {|k| formats[k.to_sym] }.compact.sort do |a, b|
        a = [a.key?(:tag) ? 0 : 1, a[:priority] || Float::INFINITY]
        b = [b.key?(:tag) ? 0 : 1, b[:priority] || Float::INFINITY]
        a <=> b
      end

      # apply all ordered formats to the starting content
      ordered_formats.reduce(content) do |content, format|
        apply_format(format, content, op)
      end
    end

    def apply_format(format, content, op)
      if format[:tag]
        content = create_node(format, content, op: op)
      end

      if format[:apply] && format[:apply].respond_to?(:call)
        format[:apply].call(content, op)
      end

      if format[:parent]
        # build wrapper into a hierarchy of parents
        # ex: %w[table tbody tr] will build ancestors,
        # and/or merge into any trailing document structure that matches
        parents = [format[:parent]].flatten.each_with_object([]) do |tag, memo|
          scope = (memo.last || @root).children.last
          node = scope && scope.name == tag ? scope : create_tag(tag)
          memo.last.add_child(node) if memo.last && node.parent != memo.last
          memo << node
        end

        parents.last.add_child(content)
        content = parents.first
      end

      content
    end

  end
end
