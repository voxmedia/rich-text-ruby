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
    bullet:         { tag: 'li', parent_tag: 'ul' },
    div:            { tag: 'div' },
    fifthheader:    { tag: 'h5' },
    figure:         { tag: 'figure' },
    firstheader:    { tag: 'h1' },
    fourthheader:   { tag: 'h4' },
    id:             { apply: ->(el, op){ el[:id] = op.attributes[:id] } },
    list:           { tag: 'li', parent_tag: 'ol' },
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

  c.html_embed_formats = {
    hr:             { tag: 'hr' },
    image:          {
      apply: ->(el, op) {
        img = el.document.create_element 'img'
        img[:src] = op.value.dig(:image, :src)
        img.wrap('<figure></figure>').parent
      }
    },
  }

  c.html_inline_formats = {
    bold:           { tag: 'strong' },
    br:             { tag: 'br' },
    ins:            { tag: 'ins' },
    italic:         { tag: 'em' },
    link:           { tag: 'a', apply: ->(el, op){ el[:href] = op.attributes[:link] } },
    small:          { tag: 'small' },
    strike:         { tag: 's' },
    subscript:      { tag: 'sub' },
    superscript:    { tag: 'sup' },
  }
end
