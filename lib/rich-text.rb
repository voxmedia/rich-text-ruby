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
  c.html_default_block_tag = 'p'
  c.html_block_tags = {
    firstheader: 'h1',
    secondheader: 'h2',
    thirdheader: 'h3',
    list: ->(content, value) { %(<ol><li>#{value}</li></ol>) },
    bullet: ->(content, value) { %(<ul><li>#{value}</li></ul>) }
  }
  c.html_inline_tags = {
    bold: 'strong',
    italic: 'em',
    link: ->(content, value) { %(<a href="#{value}">#{content}</a>) }
  }
end
