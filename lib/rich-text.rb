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

  c.html_inline_formats = {
    bold:           { tag: 'strong' },
    br:             { tag: 'br' },
    hr:             { tag: 'hr', block_format: false },
    image:          { tag: 'img', block_format: :figure, apply: ->(el, op){ el[:src] = op.value.dig(:image, :src) } },
    ins:            { tag: 'ins' },
    italic:         { tag: 'em' },
    link:           { tag: 'a', apply: ->(el, op){ el[:href] = op.attributes[:link] } },
    small:          { tag: 'small' },
    strike:         { tag: 's' },
    subscript:      { tag: 'sub' },
    superscript:    { tag: 'sup' },
  }

  c.html_block_formats = {
    bullet:         { tag: 'li', parent: 'ul' },
    div:            { tag: 'div' },
    fifthheader:    { tag: 'h5' },
    figure:         { tag: 'figure' },
    firstheader:    { tag: 'h1' },
    fourthheader:   { tag: 'h4' },
    id:             { apply: ->(el, op){ el[:id] = op.attributes[:id] } },
    list:           { tag: 'li', parent: 'ol' },
    paragraph:      { tag: 'p' },
    position:       { apply: ->(el, op){
      classes = (el[:class] || '').split(' ')
      classes << op.attributes[:position]
      el[:class] = classes.uniq.join(' ')
      el
    }},
    secondheader:   { tag: 'h2' },
    sixthheader:    { tag: 'h6' },
    thirdheader:    { tag: 'h3' },
  }

  c.html_default_block_format = :paragraph
  c.safe_mode = true
end
