require 'delegate'
require 'singleton'

module RichText
  # @todo Work in progress
  class HTML
    ConfigError = Class.new(StandardError)

    def self.render(delta, options={})
      new(RichText.config, options).render(delta)
    end

    def initialize(config, options)
      @default_block_tag = options[:html_default_block_tag] || config.html_default_block_tag
      @sibling_merge_tags = [options[:html_sibling_merge_tags], config.html_sibling_merge_tags].flatten.compact.uniq
      @block_tags = config.html_block_tags.merge(options[:html_block_tags] || {})
      @inline_tags = config.html_inline_tags.merge(options[:html_inline_tags] || {})
      @object_tags = config.html_object_tags.merge(options[:html_object_tags] || {})
    end

    def render(delta)
      raise TypeError.new("cannot convert retain or delete ops to html") unless delta.insert_only?
      html = delta.each_line.inject('') do |html, line|
        html << render_line(line)
      end
      normalize(html)
    end

    private

    def render_line(delta)
      # TODO: handle a delta without a trailing "\n"
      line = ''
      delta.slice(0, delta.length - 1).each_op do |op|
        if op.value.is_a?(String)
          line << apply_tags(@inline_tags, op.value, op.attributes)
        elsif op.value.is_a?(Hash) && key = @object_tags.keys.detect { |k| op.value.key?(k) }
          line << apply_tag(@object_tags[key], op.value[key], op.attributes)
        end
      end

      delta.slice(delta.length - 1, 1).each_op do |op|
        if op.attributes?
          line = apply_tags(@block_tags, line, op.attributes)
        else
          line = apply_tag(@default_block_tag, line, true)
        end
      end
      line
    end

    def apply_tags(tags, text, attributes)
      attributes.inject(text) do |content, (key, value)|
        apply_tag(tags[key.to_sym], content, value)
      end
    end

    def apply_tag(tag, content, value)
      if tag.respond_to?(:call)
        tag.call(content, value)
      elsif tag.is_a?(String)
        "<#{tag}>#{content}</#{tag}>"
      elsif content.is_a?(String)
        content
      else
        ''
      end
    end

    def normalize(html)
      # merge sibling tags
      @sibling_merge_tags.each { |tag| html.gsub!("</#{tag}><#{tag}>", "") }

      # standardize nesting order
      html
    end
  end
end
