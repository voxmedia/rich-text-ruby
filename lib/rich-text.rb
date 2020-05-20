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

  c.html_inline_formats ||= {
    bold:           { tag: 'strong' },
    br:             { tag: 'br' },
    hr:             { tag: 'hr', block_format: false },
    italic:         { tag: 'em' },
    link:           { tag: 'a', apply: ->(el, op, ctx){ el[:href] = op.attributes[:link] } },
    size:           { tag: 'span', apply: ->(el, op, ctx) { el[:style] = el[:style].to_s + "font-size: #{op.attributes[:size]};" } },
    color:          { tag: 'span', apply: ->(el, op, ctx) { el[:style] = el[:style].to_s + "color: #{op.attributes[:color]};" } },
    background:     { tag: 'span', apply: ->(el, op, ctx) { el[:style] = el[:style].to_s + "background: #{op.attributes[:background]};" } },
  }

  c.html_block_formats ||= {
    align:          { apply: ->(el, op, ctx) { el[:style] = "text-align: #{op.attributes[:align]}" } },
    firstheader:    { tag: 'h1' },
    secondheader:   { tag: 'h2' },
    thirdheader:    { tag: 'h3' },
    bullet:         { tag: 'li', parent: 'ul' },
    list:           { tag: 'li', parent: 'ol' },
    id:             { apply: ->(el, op, ctx){ el[:id] = op.attributes[:id] } }
  }

  c.html_default_block_format = 'p'
  c.safe_mode = true
end
