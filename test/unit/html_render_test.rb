require 'test_helper'

describe 'Experimental' do

  it 'renders full stories' do
    json = File.read(File.expand_path('./test/unit/sample.json'))
    d = RichText::Delta.new(JSON.parse(json))
    # d = RichText::Delta.new([
    #   { insert: 'a man ' },
    #   { insert: 'a plan', attributes: { italic: true } },
    #   { insert: ' ' },
    #   { insert: 'panama', attributes: { bold: true } },
    #   { insert: "\n" },
    # ])

    #puts RichText::HTML.render(d)
  end

end