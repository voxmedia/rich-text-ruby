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

  it 'renders basic text with inline formats' do
    d = RichText::Delta.new([
      { insert: 'a man ' },
      { insert: 'a plan', attributes: { italic: true } },
      { insert: ' ' },
      { insert: 'panama', attributes: { bold: true } },
      { insert: "\n" },
    ])
    assert_equal '<p>a man <em>a plan</em> <strong>panama</strong></p>', render_compact_html(d)
  end

  it 'renders inline formats' do
    d = RichText::Delta.new([
      { insert: 'bold', attributes: { bold: true } },
      { insert: ' ' },
      { insert: 'insert', attributes: { ins: true } },
      { insert: ' ' },
      { insert: 'italic', attributes: { italic: true } },
      { insert: ' ' },
      { insert: 'small', attributes: { small: true } },
      { insert: ' ' },
      { insert: 'strike', attributes: { strike: true } },
      { insert: ' ' },
      { insert: 'subscript', attributes: { subscript: true } },
      { insert: ' ' },
      { insert: 'superscript', attributes: { superscript: true } },
      { insert: "\n" },
    ])
    assert_equal '<p><strong>bold</strong> <ins>insert</ins> <em>italic</em> <small>small</small> <s>strike</s> <sub>subscript</sub> <sup>superscript</sup></p>', render_compact_html(d)
  end

  it 'renders inline formats with applied attributes' do
    d = RichText::Delta.new([
      { insert: 'link', attributes: { link: 'https://visitpanama.com' } },
      { insert: "\n" },
    ])
    assert_equal '<p><a href="https://visitpanama.com">link</a></p>', render_compact_html(d)
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
      formats: {
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

  it 'renders back-to-back list types' do
    d = RichText::Delta.new([
      { insert: 'helium' },
      { insert: "\n", attributes: { list: true } },
      { insert: 'neon' },
      { insert: "\n", attributes: { list: true } },
      { insert: 'argon' },
      { insert: "\n", attributes: { bullet: true } },
      { insert: 'krypton' },
      { insert: "\n", attributes: { bullet: true } }
    ])
    assert_equal '<ol> <li>helium</li> <li>neon</li> </ol> <ul> <li>argon</li> <li>krypton</li> </ul>', render_compact_html(d)
  end

  it 'renders headers' do
    d = RichText::Delta.new([
      { insert: 'a' },
      { insert: "\n", attributes: { firstheader: true } },
      { insert: 'b' },
      { insert: "\n", attributes: { secondheader: true } },
      { insert: 'c' },
      { insert: "\n", attributes: { thirdheader: true } },
      { insert: 'd' },
      { insert: "\n", attributes: { fourthheader: true } },
      { insert: 'e' },
      { insert: "\n", attributes: { fifthheader: true } },
    ])
    assert_equal '<h1>a</h1> <h2>b</h2> <h3>c</h3> <h4>d</h4> <h5>e</h5>', render_compact_html(d)
  end

  it 'renders paragraphs' do
    d = RichText::Delta.new([
      { insert: 'mali principii' },
      { insert: "\n", attributes: { paragraph: true } },
      { insert: 'malus finis' },
      { insert: "\n", attributes: { paragraph: true } },
    ])
    assert_equal '<p>mali principii</p> <p>malus finis</p>', render_compact_html(d)
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

  it 'renders horizontal rules' do
    d = RichText::Delta.new([
      { insert: "a man\n" },
      { insert: { hr: true } },
      { insert: "\n" },
      { insert: 'a plan' }
    ])
    assert_equal '<p>a man</p> <p><hr></p> <p>a plan</p>', render_compact_html(d)
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
      formats: {
        oembed: {
          tag: 'iframe',
          build: ->(el, op) { el[:src] = op.value.dig(:oembed, :url); el }
        }
      }
    })
  end

  it 'renders custom object insertions that return new elements' do
    d = RichText::Delta.new([
      { insert: { image: { src: "https://placekitten.com/200/150", credit: 'cuteness' } } },
      { insert: "\n" }
    ])

    f = {
      image: {
        tag: 'img',
        build: ->(el, op) {
          el[:src] = op.value.dig(:image, :src)
          el.wrap('<figure/>')
          el = el.parent
          el.add_child("<cite>#{ op.value.dig(:image, :credit) }</cite>")
          el
        }
      }
    }

    assert_equal '<p><figure><img src="https://placekitten.com/200/150"><cite>cuteness</cite></figure></p>', render_compact_html(d, formats: f)
  end

  it 'renders id attributes' do
    d = RichText::Delta.new([
      { insert: 'mali principii' },
      { insert: "\n", attributes: { id: 'mali' } }
    ])
    assert_equal '<p id="mali">mali principii</p>', render_compact_html(d)
  end

  it 'renders position attributes' do
    d = RichText::Delta.new([
      { insert: 'malus finis' },
      { insert: "\n", attributes: { position: 'float-right' } }
    ])
    assert_equal '<p class="float-right">malus finis</p>', render_compact_html(d)
  end

  it 'ignores invalid attributes' do
    d = RichText::Delta.new([
      { insert: 'malus finis', attributes: { invalid: true } },
      { insert: "\n", attributes: { invalid: true } }
    ])
    assert_equal '<p>malus finis</p>', render_compact_html(d)
  end

  it 'changes default block format' do
    d = RichText::Delta.new([
      { insert: 'malus finis', attributes: { invalid: true } },
      { insert: "\n", attributes: { invalid: true } }
    ])
    assert_equal '<div>malus finis</div>', render_compact_html(d, default_block_format: :div)
  end


  # it 'renders custom object insertions that return new elements' do
  #   d = RichText::Delta.new([
  #     { insert: { image: { src: "https://placekitten.com/200/150" } } },
  #     { insert: "\n", attributes: { id: 'FBZLQ8', position: 'hang-right' } }
  #   ])

  #   assert_equal '<p><img src="https://placekitten.com/200/150"></p>', render_compact_html(d)
  # end

  def render_compact_html(delta, options={})
    RichText::HTML.render(delta, options).gsub(/[[:space:]]+/, " ").strip
  end
end