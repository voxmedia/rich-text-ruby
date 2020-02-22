module RichText
  def self.config
    @config ||= Config.new
  end

  def self.configure
    yield config
  end
end

require 'rich-text/version'
require 'rich-text/config'
require 'rich-text/delta'
require 'rich-text/html'

RichText.configure do |c|
  c.safe_mode = true

  c.html_default_block_format = :paragraph

  c.html_block_formats = {
    br:             { tag: 'br', attrs: %w[id], inline: true },
    bullet:         { tag: 'li', attrs: %w[id], parent: 'ul' },
    fifthheader:    { tag: 'h5', attrs: %w[id] },
    firstheader:    { tag: 'h1', attrs: %w[id] },
    fourthheader:   { tag: 'h4', attrs: %w[id] },
    list:           { tag: 'li', attrs: %w[id], parent: 'ol' },
    paragraph:      { tag: 'p',  attrs: %w[id] },
    secondheader:   { tag: 'h2', attrs: %w[id] },
    thirdheader:    { tag: 'h3', attrs: %w[id] },
  }

  c.html_inline_formats = {
    bold:           { tag: 'strong' },
    italic:         { tag: 'em' },
    link:           { tag: 'a', value: 'href' },
    strike:         { tag: 'strike' },
  }

  c.html_object_formats = {
    image: {
      tag: 'img',
      build: ->(el, op) { el[:src] = op.value.dig(:image, :src); el }
    }
  }
end
