require 'test_helper'

describe RichText::HTML do

  it 'renders basic paragraph string' do
    d = RichText::Delta.new([{ insert: "hello world\n" }])
    assert_equal '<p>hello world</p>', render_compact_html(d)
  end

  it 'renders multiple paragraph strings' do
    d = RichText::Delta.new([{ insert: "hello\n" }, { insert: "goodbye\n" }])
    assert_equal '<p>hello</p> <p>goodbye</p>', render_compact_html(d)
  end

  it 'renders basic inline bold and italic HTML formatting' do
    d = RichText::Delta.new([
      { insert: 'a man ' },
      { insert: 'a plan', attributes: { italic: true } },
      { insert: ' ' },
      { insert: 'panama', attributes: { bold: true } },
      { insert: "\n" },
    ])
    assert_equal '<p>a man <em>a plan</em> <strong>panama</strong></p>', render_compact_html(d)
  end

  it 'renders inline link formatting' do
    d = RichText::Delta.new([
      { insert: 'a man ' },
      { insert: 'a plan', attributes: { link: 'https://visitpanama.com' } },
      { insert: " panama\n" },
    ])
    assert_equal '<p>a man <a href="https://visitpanama.com">a plan</a> panama</p>', render_compact_html(d)
  end

  it 'renders multiple level of inline attribution' do
    d = RichText::Delta.new([
      { insert: 'a man ' },
      { insert: 'a plan', attributes: { bold: true, italic: true, link: 'https://visitpanama.com' } },
      { insert: "\n" },
    ])
    assert_equal '<p>a man <a href="https://visitpanama.com"><em><strong>a plan</strong></em></a></p>', render_compact_html(d)
  end

  it 'allows inline formatting options to override defaults' do
    d = RichText::Delta.new([
      { insert: 'a man ' },
      { insert: 'a plan', attributes: { bold: true } },
      { insert: "\n" },
    ])
    assert_equal '<p>a man <b>a plan</b></p>', render_compact_html(d, {
      inline_formats: {
        bold: { tag: 'b' }
      }
    })
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
    assert_equal '<ol> <li>a man</li> <li>a plan</li> <li>panama</li> </ol>', render_compact_html(d)
  end

  it 'renders unordered lists' do
    d = RichText::Delta.new([
      { insert: 'a man' },
      { insert: "\n", attributes: { bullet: true } },
      { insert: 'a plan' },
      { insert: "\n", attributes: { bullet: true } },
      { insert: 'panama' },
      { insert: "\n", attributes: { bullet: true } }
    ])
    assert_equal '<ul> <li>a man</li> <li>a plan</li> <li>panama</li> </ul>', render_compact_html(d)
  end

  it 'renders inline breaks' do
    d = RichText::Delta.new([
      { insert: 'a man' },
      { insert: "\n", attributes: { br: true } },
      { insert: 'a plan' },
      { insert: "\n", attributes: { br: true } },
      { insert: 'panama' },
      { insert: "\n" }
    ])
    assert_equal '<p>a man<br>a plan<br>panama</p>', render_compact_html(d)
  end

  it 'forgives inline breaks at the end of the delta' do
    d = RichText::Delta.new([
      { insert: 'a man' },
      { insert: "\n", attributes: { br: true } },
      { insert: 'a plan' },
      { insert: "\n", attributes: { br: true } },
      { insert: 'panama' },
      { insert: "\n", attributes: { br: true } }
    ])
    assert_equal '<p>a man<br>a plan<br>panama<br></p>', render_compact_html(d)
  end

  it 'renders whitelisted object insertions' do
    d = RichText::Delta.new([
      { insert: { image: { src: "https://placekitten.com/200/150" } } },
      { insert: "\n" }
    ])

    assert_equal '<p><img src="https://placekitten.com/200/150"></p>', render_compact_html(d)
  end

  it 'renders custom object insertions' do
    d = RichText::Delta.new([
      { insert: { oembed: { url: "https://www.youtube.com/watch?v=fd8tya7Gmv8" } } },
      { insert: "\n" }
    ])

    assert_equal '<p><iframe src="https://www.youtube.com/watch?v=fd8tya7Gmv8"></iframe></p>', render_compact_html(d, {
      object_formats: {
        oembed: {
          tag: 'iframe',
          build: ->(el, op) { el[:src] = op.value.dig(:oembed, :url); el }
        }
      }
    })
  end

  def render_compact_html(delta, options={})
    RichText::HTML.render(delta, options).gsub(/[[:space:]]+/, " ").strip
  end
end