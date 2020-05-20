require 'test_helper'

describe RichText::HTML do
  before do
    RichText.configure do |c|
      c.html_inline_formats = {
        bold:           { tag: 'strong' },
        br:             { tag: 'br' },
        italic:         { tag: 'em' },
        link:           { tag: 'a', apply: ->(el, op, ctx){ el[:href] = op.attributes[:link] } },
        size:           { tag: 'span', apply: ->(el, op, ctx) { el[:style] = el[:style].to_s + "font-size: #{op.attributes[:size]};" } },
        color:          { tag: 'span', apply: ->(el, op, ctx) { el[:style] = el[:style].to_s + "color: #{op.attributes[:color]};" } },
        background:     { tag: 'span', apply: ->(el, op, ctx) { el[:style] = el[:style].to_s + "background: #{op.attributes[:background]};" } },
      }.freeze

      c.html_block_formats = {
        align:          { apply: ->(el, op, ctx) { el[:style] = el[:style].to_s + "text-align: #{op.attributes[:align]};" } },
        firstheader:    { tag: 'h1' },
        secondheader:   { tag: 'h2' },
        thirdheader:    { tag: 'h3' },
        bullet:         { tag: 'li', parent: 'ul' },
        list:           { tag: 'li', parent: 'ol' },
        id:             { apply: ->(el, op, ctx){ el[:id] = op.attributes[:id] } }
      }.freeze

      c.html_default_block_format = 'p'
    end
  end

  it 'renders basic paragraph string' do
    d = RichText::Delta.new([{ insert: "hello world\n" }])
    assert_equal '<p>hello world</p>', render_compact_html(d)
  end

  it 'renders multiple paragraph strings' do
    d = RichText::Delta.new([{ insert: "hello\n" }, { insert: "goodbye\n" }])
    assert_equal '<p>hello</p><p>goodbye</p>', render_compact_html(d)
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

    assert_equal '<p>a man <b>a plan</b></p>', render_compact_html(d, inline_formats: {
      bold: { tag: 'b' }
    })
  end

  it 'renders blocks with parent elements' do
    d = RichText::Delta.new([
      { insert: 'a man' },
      { insert: "\n", attributes: { bullet: true } },
      { insert: 'a plan' },
      { insert: "\n", attributes: { bullet: true } },
      { insert: 'panama' },
      { insert: "\n", attributes: { bullet: true } }
    ])
    assert_equal '<ul><li>a man</li><li>a plan</li><li>panama</li></ul>', render_compact_html(d)
  end

  it 'renders properly merged parent sets' do
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
    assert_equal '<ol><li>helium</li><li>neon</li></ol><ul><li>argon</li><li>krypton</li></ul>', render_compact_html(d)
  end

  it 'renders block formats' do
    d = RichText::Delta.new([
      { insert: 'a' },
      { insert: "\n", attributes: { firstheader: true } },
      { insert: 'b' },
      { insert: "\n", attributes: { secondheader: true } },
      { insert: 'c' },
      { insert: "\n", attributes: { thirdheader: true } }
    ])
    assert_equal '<h1>a</h1><h2>b</h2><h3>c</h3>', render_compact_html(d)
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
    assert_equal '<p>a man<br/>a plan<br/>panama</p>', render_compact_html(d)
  end

  it 'renders inline breaks at the end of the delta' do
    d = RichText::Delta.new([
      { insert: 'a man' },
      { insert: "\n", attributes: { br: true } },
      { insert: 'a plan' },
      { insert: "\n", attributes: { br: true } },
      { insert: 'panama' },
      { insert: "\n", attributes: { br: true } }
    ])
    assert_equal '<p>a man<br/>a plan<br/>panama<br/></p>', render_compact_html(d)
  end

  it 'renders attributes' do
    d = RichText::Delta.new([
      { insert: 'mali principii' },
      { insert: "\n", attributes: { id: 'mali' } }
    ])
    assert_equal '<p id="mali">mali principii</p>', render_compact_html(d)
  end

  it 'ignores invalid attributes' do
    d = RichText::Delta.new([
      { insert: 'malus finis', attributes: { invalid: true } },
      { insert: "\n", attributes: { invalid: true } }
    ])
    assert_equal '<p>malus finis</p>', render_compact_html(d)
  end

  it 'accepts an alternate block default referencing a defined format' do
    d = RichText::Delta.new([
      { insert: 'malus finis', attributes: { invalid: true } },
      { insert: "\n", attributes: { invalid: true } }
    ])
    assert_equal '<h1>malus finis</h1>', render_compact_html(d, default_block_format: :firstheader)
  end

  it 'accepts an alternate block default using a one-off tag name' do
    d = RichText::Delta.new([
      { insert: 'malus finis', attributes: { invalid: true } },
      { insert: "\n", attributes: { invalid: true } }
    ])
    assert_equal '<div>malus finis</div>', render_compact_html(d, default_block_format: 'div')
  end

  it 'renders custom object insertions using apply function' do
    d = RichText::Delta.new([
      { insert: { image: { src: "https://placekitten.com/200/150" } } },
      { insert: "\n" }
    ])

    f = {
      image: {
        tag: 'img',
        apply: ->(el, op, ctx){ el[:src] = op.value.dig(:image, :src) }
      }
    }

    assert_equal '<p><img src="https://placekitten.com/200/150"/></p>', render_compact_html(d, inline_formats: f)
  end

  it 'renders object insertions with special block formats, referencing a known format' do
    d = RichText::Delta.new([
      { insert: { image: { src: "https://placekitten.com/200/150" } } },
      { insert: "\n", attributes: { id: 'bingo' } }
    ])

    f = {
      image: {
        tag: 'img',
        block_format: :firstheader,
        apply: ->(el, op, ctx){ el[:src] = op.value.dig(:image, :src) }
      }
    }

    assert_equal '<h1 id="bingo"><img src="https://placekitten.com/200/150"/></h1>', render_compact_html(d, inline_formats: f)
  end

  it 'renders custom object insertions with special block formats, using a custom tag' do
    d = RichText::Delta.new([
      { insert: { image: { src: "https://placekitten.com/200/150" } } },
      { insert: "\n", attributes: { id: 'bingo' } }
    ])

    f = {
      image: {
        tag: 'img',
        block_format: 'figure',
        apply: ->(el, op, ctx){ el[:src] = op.value.dig(:image, :src) }
      }
    }

    assert_equal '<figure id="bingo"><img src="https://placekitten.com/200/150"/></figure>', render_compact_html(d, inline_formats: f)
  end

  it 'renders custom object insertions with no block format' do
    d = RichText::Delta.new([
      { insert: { image: { src: "https://placekitten.com/200/150" } } },
      { insert: "\n", attributes: { id: 'bingo' } }
    ])

    f = {
      image: {
        tag: 'img',
        block_format: false,
        apply: ->(el, op, ctx){ el[:src] = op.value.dig(:image, :src) }
      }
    }

    assert_equal '<img src="https://placekitten.com/200/150" id="bingo"/>', render_compact_html(d, inline_formats: f)
  end

  it 'renders custom object insertions with a tag build function' do
    d = RichText::Delta.new([
      { insert: { image: { src: "https://placekitten.com/200/150", caption: 'cuteness' } } },
      { insert: "\n", attributes: { id: 'bingo' } }
    ])

    f = {
      image: {
        omit_block: true,
        tag: ->(el, op, ctx) {
          el.name = 'figure'
          el.add_child(%(<img src="#{ op.value.dig(:image, :src) }">))
          el.add_child(%(<figcaption>#{ op.value.dig(:image, :caption) }</figcaption>))
          el
        }
      }
    }

    assert_equal '<figure id="bingo"><img src="https://placekitten.com/200/150"/><figcaption>cuteness</figcaption></figure>', render_compact_html(d, inline_formats: f)
  end

  it 'renders custom object insertions into story flow' do
    d = RichText::Delta.new([
      { insert: 'before' },
      { insert: "\n" },
      { insert: { image: { src: 'https://placekitten.com/200/150', caption: 'cuteness' } } },
      { insert: "\n", attributes: { id: 'bingo' } },
      { insert: 'after' },
      { insert: "\n" },
    ])

    f = {
      image: {
        omit_block: true,
        tag: ->(el, op, ctx) {
          el.name = 'figure'
          el.add_child(%(<img src="#{ op.value.dig(:image, :src) }">))
          el.add_child(%(<figcaption>#{ op.value.dig(:image, :caption) }</figcaption>))
          el
        }
      }
    }

    assert_equal '<p>before</p><figure id="bingo"><img src="https://placekitten.com/200/150"/><figcaption>cuteness</figcaption></figure><p>after</p>', render_compact_html(d, inline_formats: f)
  end

  it 'renders nothing for build functions that return no element' do
    d = RichText::Delta.new([
      { insert: 'before' },
      { insert: "\n" },
      { insert: { image: { src: 'https://placekitten.com/200/150', caption: 'cuteness' } } },
      { insert: "\n", attributes: { id: 'bingo' } },
      { insert: 'after' },
      { insert: "\n" },
    ])

    f = {
      image: {
        omit_block: true,
        tag: ->(el, op, ctx) { nil }
      }
    }

    assert_equal '<p>before</p><p>after</p>', render_compact_html(d, inline_formats: f)
  end

  it 'passes a render context argument to build and apply functions' do
    d = RichText::Delta.new([
      { insert: { image: { src: 'https://placekitten.com/200/150' } } },
      { insert: "\n" },
    ])

    render_context = {}
    build_context = nil
    apply_context = nil

    f = {
      image: {
        tag: ->(el, op, ctx) { build_context = ctx; el },
        apply: ->(el, op, ctx) { apply_context = ctx }
      }
    }

    render_compact_html(d, context: render_context, inline_formats: {
      image: {
        tag: ->(el, op, ctx) { build_context = ctx; el },
        apply: ->(el, op, ctx) { apply_context = ctx }
      }
    })

    assert_equal render_context.object_id, build_context.object_id
    assert_equal render_context.object_id, apply_context.object_id
  end

  it 'applies tags then attributes, each ordered by priority' do
    d = RichText::Delta.new([
      { insert: "hitme\n", attributes: { attr2: true, tag2: true, attr1: true, tag1: true } }
    ])

    assert_equal '<p><second id="second"><first>hitme</first></second></p>', render_compact_html(d, inline_formats: {
      tag1: { tag: 'first', priority: 1 },
      tag2: { tag: 'second', priority: 2 },
      attr1: { apply: ->(el, op, ctx){ el[:id] = 'first' }, priority: 1 },
      attr2: { apply: ->(el, op, ctx){ el[:id] = 'second' }, priority: 2 },
    })
  end

  it 'gracefully handles missing newline ends' do
    d = RichText::Delta.new([
      { insert: 'mali principii' },
      { insert: "\n" },
      { insert: 'malus finis', attributes: { invalid: true } }
    ])
    assert_equal '<p>mali principii</p><p>malus finis</p>', render_compact_html(d)
  end

  it 'renders a paragraph with alignment' do
    d = RichText::Delta.new([{ insert: "dextra", attributes: { align: "right"}}])
    assert_equal '<p style="text-align: right;">dextra</p>', render_compact_html(d)
  end

  it 'renders a header with alignment' do
    d = RichText::Delta.new([{ insert: "dextra", attributes: { align: "right", firstheader: true }}])
    assert_equal '<h1 style="text-align: right;">dextra</h1>', render_compact_html(d)
  end

  it 'renders a paragraph with colors' do
    d = RichText::Delta.new([{ insert: "red balloon in blue sky", attributes: { color: "#ff0000", background: "#0000ff" }}])
    assert_equal '<p style="color: #ff0000;background: #0000ff;">red balloon in blue sky</p>', render_compact_html(d)
  end

  it 'renders a paragraph with many attributes' do
    d = RichText::Delta.new([{ insert: "hello\n" }, { insert: "goodbye\n" }])
    d = RichText::Delta.new([{"attributes"=>{"color"=>"#e60000", "background"=>"#ffff00", "size"=>"21px"}, "insert"=>"hello"}, {"attributes"=>{"bold" => true, "align"=>"left", size: "10px"}, "insert"=>"world"}])
    assert_equal '<p style="text-align: left;"><span style="font-size: 21px;background: #ffff00;color:#e60000">hello</span><span style=\"font-size: 10px;\"><strong>world</strong></span></p>', render_compact_html(d)
  end

  it 'renders a paragraph with size' do
    d = RichText::Delta.new([{ insert: "big text", attributes: { size: "50px" }}])
    assert_equal '<p style="font-size: 50px;">big text</p>', render_compact_html(d)
  end

  def render_compact_html(delta, options={})
    RichText::HTML.new(options).render(delta).inner_html(save_with: 0)
  end
end
