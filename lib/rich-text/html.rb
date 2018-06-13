require 'delegate'
require 'singleton'

module RichText
  # @todo Work in progress
  class HTML
    ConfigError = Class.new(StandardError)

    attr_reader :config

    def self.render(delta, options)
      new(RichText.config).render(delta)
    end

    def initialize(config)
      @default_block_tag = config.html_default_block_tag
      @block_tags = config.html_block_tags
      @inline_tags = config.html_inline_tags
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
        line << apply_tags(@inline_tags, op.value, op.attributes)
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
        apply_tag(tags[key], content, value)
      end
    end

    def apply_tag(tag, content, value)
      if tag.respond_to?(:call)
        tag.call(content, value)
      elsif tag
        "<#{tag}>#{content}</#{tag}>"
      end
    end

    def normalize(html)
      # merge sibling tags
      # standardize nesting order
    end
  end
end
