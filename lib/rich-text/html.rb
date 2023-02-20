require 'delegate'
require 'singleton'
require 'nokogiri'

module RichText
  class HTML
    ConfigError = Class.new(StandardError)

    def self.render(delta, options={})
      new(options).render(delta).inner_html
    end

    attr_reader :doc

    def initialize(options={}, config=RichText.config)
      @default_block_format = options[:default_block_format] || config.html_default_block_format
      @inline_formats = config.html_inline_formats.merge(options[:inline_formats] || {})
      @block_formats = config.html_block_formats.merge(options[:block_formats] || {})
      @context = options[:context]

      @doc = Nokogiri::XML::Document.new
      @doc.encoding = 'UTF-8'
      @root = create_node(tag: 'main')
    end

    def render(delta)
      raise TypeError.new("cannot convert retain or delete ops to html") unless delta.insert_only?

      render_lines = []

      # loop through each delta line and group together inline separators.
      # a delta line ends at each newline character with indifference,
      # while a render line may choose to group some newlines (like "br" tags).
      delta.each_line do |line|
        next unless line.ops.any?

        if render_lines.any? && inline_tag?(render_lines.last.last)
          # merge inlined return into previous render line
          render_lines.last.push(*line.ops)
        else
          render_lines.push(line.ops.dup)
        end
      end

      render_lines.each { |ops| render_line(ops) }
      @root
    end

  private

    def inline_tag?(op)
      op.attributes.keys.find { |k| @inline_formats[k.to_sym]&.key?(:tag) }
    end

    # renders a single line of operations
    def render_line(ops)
      current_block_format = @default_block_format.to_sym
      new_block_format = current_block_format

      # Render all inline operations with defined formats
      # results in an array of element for the rendered line
      elements = ops.reduce([]) do |els, op|
        # String insert
        if op.value.is_a?(String)
          value = op.value.sub(/\n$/, '')
          if value.length > 0 || inline_tag?(op)
            new_block_format = @default_block_format.to_sym
            els << apply_formats(@inline_formats, value, op)
          end

        # Object insert
        elsif op.value.is_a?(Hash) && key = @inline_formats.keys.detect { |k| op.value.key?(k) }
          format = @inline_formats[key.to_sym]
          new_block_format = format[:block_format] if format.key?(:block_format)
          new_block_format = false if format[:omit_block]
          els << apply_format(format, op.value, op)
        end

        # Flush the element flow when switching block formats
        if new_block_format != current_block_format
          render_block(ops.last, els.take(els.length - 1), current_block_format)
          current_block_format = new_block_format
          els.last(1)
        else
          els
        end
      end

      # Render a block wrapper for the inlined elements
      # places the resulting block into the root document
      render_block(ops.last, elements, current_block_format)
    end

    # renders a block for a collection of elements based on a final operation
    def render_block(op, elements, default_block_format=@default_block_format)
      elements = elements.compact
      return unless elements.any?

      # manually build block attributes to normalize malformed structures
      # assure that only block attributes are allowed to format blocks
      block_attrs = op.attributes.slice(*@block_formats.keys)
      block_formats = @block_formats

      # direct insertions (like "hr" tags) omit block format entirely
      # install these elements directly into the root flow
      if !default_block_format
        # remove tag formats from from insertions without a block,
        # this assures that only custom (non-tag) formatters run on the element
        block_attrs = Hash[block_attrs.reject { |k, v| @block_formats[k.to_sym].key?(:tag) }]
        return elements.each do |el|
          el = apply_formats(@block_formats, el, op, attributes: block_attrs)
          @root.add_child(el)
        end
      end

      # assure that the block has a tag formatting attribute
      # use or build a format for the default format, when necessary
      unless block_attrs.detect { |k, v| block_formats[k.to_sym].key?(:tag) }
        # if the default isn't an official format, built a one-off definition for it
        unless block_formats.key?(default_block_format.to_sym)
          block_formats = block_formats.merge(default_block_format.to_sym => { tag: default_block_format.to_s })
        end

        # add a formatting attribute to apply the default block tag
        block_attrs[default_block_format.to_sym] = true
      end

      el = apply_formats(block_formats, elements, op, attributes: block_attrs)
      @root.add_child(el)
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
        format[:apply].call(content, op, @context)
      end

      if format[:parent]
        parent = if format[:parent].respond_to?(:call)
          format[:parent].call(op, @context)
        else
          format[:parent]
        end

        # build wrapper into a hierarchy of parents
        # ex: %w[table tbody tr] will build ancestors,
        # and/or merge into any trailing document structure that matches
        parents = [parent].flatten.each_with_object([]) do |tag, memo|
          scope = (memo.last || @root).children.last
          node = scope && scope.name == tag ? scope : create_node(tag: tag)
          memo.last.add_child(node) if memo.last && node.parent != memo.last
          memo << node
        end

        parents.last.add_child(content)
        content = parents.first
      end

      content
    end

    def create_node(format={}, content=nil, tag:nil, op:nil)
      tag ||= format[:tag]
      tag = 'span' if tag.respond_to?(:call)
      el = Nokogiri::XML::Node.new(tag, @doc)

      if content.is_a?(String)
        el.content = content
      elsif content.is_a?(Nokogiri::XML::Node)
        el.add_child(content)
      elsif content.is_a?(Array)
        content.each { |n| el.add_child(n) }
      end

      if format[:tag].respond_to?(:call) && op
        el = format[:tag].call(el, op, @context)
      end

      el
    end

  end
end
