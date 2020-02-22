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
      @block_formats = config.html_block_formats.merge(options[:block_formats] || {})
      @inline_formats = config.html_inline_formats.merge(options[:inline_formats] || {})
      @object_formats = config.html_object_formats.merge(options[:object_formats] || {})

      @doc = Nokogiri::XML::Document.new
      @doc.encoding = 'UTF-8'
      @root = create_tag('main')
    end

    def render(delta)
      raise TypeError.new("cannot convert retain or delete ops to html") unless delta.insert_only?

      line = nil
      flow = nil
      delta.each_line do |l|
        line = l
        next unless line.ops.any?

        # render a flow for each line
        # flow may carry across inline blocks, like BRs
        flow = render_inline(line, flow || [])
        flow = render_block(line, flow)
        next if flow.is_a?(Array)

        @root.add_child(flow)
        flow = nil
      end

      if flow.is_a?(Array)
        # force uncomitted flow into a block element
        # this would occur if the delta ends with an inlined block (br tag)
        @root.add_child(render_block(line, flow, force_block: true))
      end

      @root
    end

    def create_tag(name)
      create_node(tag: name)
    end

  private

    def create_node(format={}, content=nil, op: nil, tag:nil)
      el = Nokogiri::XML::Node.new(tag || format[:tag], @doc)

      if content.is_a?(String)
        el.content = content
      elsif content.is_a?(Nokogiri::XML::Node)
        el.add_child(content)
      elsif content.is_a?(Array)
        content.each { |n| el.add_child(n) }
      end

      if format[:attrs] && op
        op.attributes.slice(*format[:attrs]).each_pair { |k, v| el[k] = v }
      end

      if format[:build].respond_to?(:call) && op
        el = format[:build].call(el, op)
      end

      el
    end

    def render_inline(delta, flow)
      delta.each_op do |op|
        if op.value.is_a?(String)
          value = op.value.sub(/\n$/, '')
          flow << render_inline_tags(value, op) if value.length > 0
        elsif op.value.is_a?(Hash) && key = @object_formats.keys.detect { |k| op.value.key?(k) }
          flow << create_node(@object_formats[key], op: op)
        end
      end

      flow
    end

    def render_inline_tags(content, op)
      op.attributes.reduce(content) do |memo, (attr_name, attr_value)|
        if inline_format = @inline_formats[attr_name.to_sym]
          node = create_node(inline_format, memo)
          node[inline_format[:value]] = attr_value if inline_format[:value]
          node
        else
          memo
        end
      end
    end

    def render_block(delta, flow, force_block: false)
      op = delta.ops.last
      block_format = @block_formats[(@block_formats.keys & op.attributes.keys.map(&:to_sym)).first]

      # force a non-inline format when ending the delta
      if !block_format || (block_format[:inline] && force_block)
        block_format = @block_formats[@default_block_format.to_sym]
      end

      if block_format[:inline]
        # inline block elements add to flow and continue to next line
        flow << create_node(block_format, op: op)
        return flow
      end

      # otherwise, create a wrapper for the inline flow
      el = create_node(block_format, flow, op: op)

      if block_format[:parent]
        # build wrapper into a hierarchy of parents
        # ex: %w[table tbody tr] will build ancestors,
        # and/or merge into any trailing document structure that matches
        parents = [block_format[:parent]].flatten.each_with_object([]) do |tag, memo|
          scope = (memo.last || @root).children.last
          node = scope && scope.name == tag ? scope : create_tag(tag)
          memo.last.add_child(node) if memo.last && node.parent != memo.last
          memo << node
        end

        parents.last.add_child(el)
        el = parents.first
      end

      el
    end
  end
end
