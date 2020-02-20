require 'test_helper'

describe RichText::HTML do

  it 'renders basic paragraph string' do
    d = RichText::Delta.new([{ insert: "hello world\n" }])
    assert_equal '<p>hello world</p>', RichText::HTML.render(d)
  end

  it 'renders multiple paragraph strings' do
    d = RichText::Delta.new([{ insert: "hello\n" }, { insert: "goodbye\n" }])
    assert_equal '<p>hello</p><p>goodbye</p>', RichText::HTML.render(d)
  end

  it 'renders basic inline bold and italic HTML formatting' do
    d = RichText::Delta.new([
      { insert: 'a man ' },
      { insert: 'a plan', attributes: { italic: true } },
      { insert: ' ' },
      { insert: 'panama', attributes: { bold: true } },
      { insert: "\n" },
    ])
    assert_equal '<p>a man <em>a plan</em> <strong>panama</strong></p>', RichText::HTML.render(d)
  end

  it 'renders inline link formatting' do
    d = RichText::Delta.new([
      { insert: 'a man ' },
      { insert: 'a plan', attributes: { link: 'https://visitpanama.com' } },
      { insert: "\n" },
    ])
    assert_equal '<p>a man <a href="https://visitpanama.com">a plan</a></p>', RichText::HTML.render(d)
  end

  it 'renders multiple level of inline attribution' do
    d = RichText::Delta.new([
      { insert: 'a man ' },
      { insert: 'a plan', attributes: { bold: true, italic: true, link: 'https://visitpanama.com' } },
      { insert: "\n" },
    ])
    assert_equal '<p>a man <a href="https://visitpanama.com"><em><strong>a plan</strong></em></a></p>', RichText::HTML.render(d)
  end

  describe 'basic html' do
    subject = RichText::Delta.new([
      { insert: 'hello ' },
      { insert: 'world', attributes: { bold: true } },
      { insert: "\n" },
      {
        insert: {
          image: {
            caption: "School board chairwoman Miska Clay Bibbs, left, and Superintendent Joris Ray.",
            credit: "Laura Faith Kebede/Chalkbeat",
            crop: {
              h: 1920,
              w: 2560,
              x: 0,
              y: 0
            },
            height: 1920,
            hide_credit: false,
            id: 19684875,
            letterbox: false,
            src: "https://cdn.vox-cdn.com/uploads/chorus_asset/file/19684875/school_board_2_scaled.jpg",
            subject: {
              x: 1280,
              y: 960
            },
            width: 2560
          }
        }
      },
      { insert: "\n" },
      { insert: 'testing ' },
      { insert: 'links', attributes: { link: 'https://voxmedia.com' } },
      { insert: " with tail\n" },
      { insert: "items" },
      { insert: "\n", attributes: { thirdheader: true } },
      { insert: "items 1" },
      { insert: "\n", attributes: { bullet: true } },
      { insert: "items 2" },
      { insert: "\n", attributes: { bullet: true } },
      { insert: "items 3" },
      { insert: "\n", attributes: { bullet: true } }
    ])

    puts RichText::HTML.render(subject)
  end

  describe '' do

  end

end