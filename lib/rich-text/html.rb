require 'delegate'
require 'singleton'
require 'nokogiri'

module RichText
  class HTML
    ConfigError = Class.new(StandardError)

    def self.render(delta, options={})
      new(options).render(delta)
    end

    def initialize(options)
      @default_block_format = options[:default_block_format] || RichText.config.html_default_block_format
      @block_formats = RichText.config.html_block_formats.merge(options[:block_formats] || {})
      @inline_formats = RichText.config.html_inline_formats.merge(options[:inline_formats] || {})
      @embed_formats = RichText.config.html_embed_formats.merge(options[:embed_formats] || {})
      @formats = @block_formats.merge(@inline_formats).merge(@embed_formats)
    end

    def render(delta)
      raise TypeError.new("cannot convert retain or delete ops to html") unless delta.insert_only?

      @doc = Nokogiri::XML::Document.new
      @doc.encoding = 'UTF-8'
      @root = create_tag('main')

      delta.each_line do |line|
        root << 'p'
        line.each_op do |op|
          el = doc.create_text_node(op.value)
          op.attributes.each do |key, value|
            next unless @inline_formats[key]
            tag, parent_tag, apply = *@formats[key].values_at(:tag, :parent_tag, :apply)
            el = el.wrap("<#{tag}></#{tag}>").parent if tag
            el = el.wrap("<#{parent_tag}></#{parent_tag}>").parent if parent_tag
            el = formats[key][:apply](el, op) if apply
          end

          if block_element?(el)
            @root << line
            @root << el
            line = @doc.create_element 'p'
          else
            line << el
          end
        end
      end

      # render_lines = []

      # # loop through each delta line and group together inline separators.
      # # a delta line ends at each newline character with indifference,
      # # while a render line may choose to group some newlines (like "br" tags).
      # delta.each_line do |line|
      #   next unless line.ops.any?

      #   if render_lines.any? && inline_tag?(render_lines.last.last)
      #     # merge inlined return into previous render line
      #     render_lines.last.push(*line.ops)
      #   else
      #     render_lines.push(line.ops.dup)
      #   end
      # end

      # render_lines.each { |ops| render_line(ops) }
      @root.inner_html
    end

  private

    def inline_tag?(op)
      op.attributes.keys.any? { |k| @inline_formats[k.to_sym]&.key?(:tag) }
    end

    # renders a single line of operations
    def render_line(ops)
      current_block_format = @default_block_format
      new_block_format = current_block_format

      # Render all inline operations with defined formats
      # results in an array of element for the rendered line
      elements = ops.reduce([]) do |els, op|
        # String insert
        if op.value.is_a?(String)
          value = op.value.chomp
          if value.length > 0 || inline_tag?(op)
            new_block_format = @default_block_format
            els << apply_formats(@inline_formats, value, op)
          end

        # Object insert
        elsif op.value.is_a?(Hash) && key = @inline_formats.keys.detect { |k| op.value.key?(k) }
          format = @inline_formats[key.to_sym]
          new_block_format = format[:block_format] if format.key?(:block_format)
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
      return unless elements.any?

      # manually build block attributes to normalize malformed structures
      block_attrs = op.attributes.slice(*@block_formats.keys)

      # direct insertions (like "hr" tags) omit block format entirely
      # install these elements directly into the document
      if !default_block_format
        # remove tag formats from these insertions so that they don't get wrapped
        block_attrs = Hash[block_attrs.reject { |k, v| @block_formats[k.to_sym].key?(:tag) }]
        return elements.each do |el|
          el = apply_formats(@block_formats, el, op, attributes: block_attrs)
          @root.add_child(el)
        end
      end

      # reject any inline formats, and assure a block tag format is defined
      unless block_attrs.detect { |k, v| @block_formats[k.to_sym].key?(:tag) }
        unless @block_formats.key?(default_block_format.to_sym)
          raise TypeError.new("block format #{default_block_format} is not defined")
        end
        block_attrs[default_block_format.to_sym] = true
      end

      el = apply_formats(@block_formats, elements, op, attributes: block_attrs)
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

    def create_node(format={}, content=nil, tag:nil, op:nil, attr_value:nil)
      el = Nokogiri::XML::Node.new(tag || format[:tag], @doc)

      if content.is_a?(String)
        el.content = content
      elsif content.is_a?(Nokogiri::XML::Node)
        el.add_child(content)
      elsif content.is_a?(Array)
        content.each { |n| el.add_child(n) }
      end

      el
    end

    def create_tag(name)
      create_node(tag: name)
    end

  end
end
