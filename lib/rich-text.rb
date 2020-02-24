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

  c.html_formats = {
    bold:           { type: :inline, tag: 'strong' },
    br:             { type: :inline, tag: 'br' },
    bullet:         { type: :block,  tag: 'li', parent: 'ul' },
    div:            { type: :block,  tag: 'div' },
    fifthheader:    { type: :block,  tag: 'h5' },
    firstheader:    { type: :block,  tag: 'h1' },
    fourthheader:   { type: :block,  tag: 'h4' },
    hr:             { type: :inline, tag: 'hr' },
    id:             { type: :block,  apply: ->(el, op){ el[:id] = op.attributes[:id] } },
    image:          { type: :inline, tag: 'img', apply: ->(el, op){ el[:src] = op.value.dig(:image, :src) } },
    ins:            { type: :inline, tag: 'ins' },
    italic:         { type: :inline, tag: 'em' },
    link:           { type: :inline, tag: 'a', apply: ->(el, op){ el[:href] = op.attributes[:link] } },
    list:           { type: :block,  tag: 'li', parent: 'ol' },
    paragraph:      { type: :block,  tag: 'p' },
    position:       { type: :block,  apply: ->(el, op){
      classes = (el[:class] || '').split(' ')
      classes << op.attributes[:position]
      el[:class] = classes.uniq.join(' ')
      el
    }},
    secondheader:   { type: :block,  tag: 'h2' },
    small:          { type: :inline, tag: 'small' },
    strike:         { type: :inline, tag: 's' },
    subscript:      { type: :inline, tag: 'sub' },
    superscript:    { type: :inline, tag: 'sup' },
    thirdheader:    { type: :block,  tag: 'h3' },
  }
end
