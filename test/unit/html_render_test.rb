require 'test_helper'

describe 'Experimental' do

  it 'renders full stories' do
    json = File.read(File.expand_path('./test/unit/sample.json'))
    #d = RichText::Delta.new(JSON.parse(json))
    d = RichText::Delta.new([
      { insert: 'a man ' },
      { insert: 'a plan', attributes: { italic: true } },
      { insert: ' ' },
      { insert: 'panama', attributes: { bold: true } },
      { insert: "\n" },
    ])

    puts RichText::HTML.render(d)
  end

  it 'renders ordered lists' do
    d = RichText::Delta.new([
      { insert: 'a man' },
      { insert: "\n", attributes: { list: true } },
      { insert: 'a plan' },
      { insert: "\n", attributes: { list: true } },
      { insert: 'panama' },
      { insert: "\n", attributes: { list: true } }
    ])
    puts RichText::HTML.render(d)
  end

  it 'renders whitelisted object insertions' do
    d = RichText::Delta.new([
      { insert: { image: { src: "https://placekitten.com/200/150" } } },
      { insert: "\n" }
    ])

    puts RichText::HTML.render(d)
    #assert_equal '<p><img src="https://placekitten.com/200/150"/></p>', RichText::HTML.render(d)
  end

  it 'renders multiple paragraph strings' do
    d = RichText::Delta.new([{
      "insert": "Five districts did not meet the 95 percent bar set by the state, "
    },
    {
      "attributes": { "br": true, id: "break" },
      "insert": "\n"
    },
    {
      "attributes": { "italic": true },
      "insert": "lowering their rating in some cases."
    },
    {
      "attributes": { id: "end" },
      "insert": "\n"
    }])
    # d = RichText::Delta.new([
    #   { insert: 'a man ' },
    #   { insert: 'a plan', attributes: { italic: true } },
    #   { insert: ' ' },
    #   { insert: 'panama', attributes: { bold: true } },
    #   { insert: "\n" },
    # ])

    puts RichText::HTML.render(d)
  end

end