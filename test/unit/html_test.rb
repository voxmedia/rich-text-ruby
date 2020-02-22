require 'test_helper'

describe RichText::HTML do

  # it 'renders basic paragraph string' do
  #   d = RichText::Delta.new([{ insert: "hello world\n" }])
  #   assert_equal '<p>hello world</p>', RichText::HTML.render(d)
  # end

  # it 'renders multiple paragraph strings' do
  #   d = RichText::Delta.new([{ insert: "hello\n" }, { insert: "goodbye\n" }])
  #   assert_equal '<p>hello</p><p>goodbye</p>', RichText::HTML.render(d)
  # end

  # it 'renders basic inline bold and italic HTML formatting' do
  #   d = RichText::Delta.new([
  #     { insert: 'a man ' },
  #     { insert: 'a plan', attributes: { italic: true } },
  #     { insert: ' ' },
  #     { insert: 'panama', attributes: { bold: true } },
  #     { insert: "\n" },
  #   ])
  #   assert_equal '<p>a man <em>a plan</em> <strong>panama</strong></p>', RichText::HTML.render(d)
  # end

  # it 'renders inline link formatting' do
  #   d = RichText::Delta.new([
  #     { insert: 'a man ' },
  #     { insert: 'a plan', attributes: { link: 'https://visitpanama.com' } },
  #     { insert: " panama\n" },
  #   ])
  #   assert_equal '<p>a man <a href="https://visitpanama.com">a plan</a> panama</p>', RichText::HTML.render(d)
  # end

  # it 'renders multiple level of inline attribution' do
  #   d = RichText::Delta.new([
  #     { insert: 'a man ' },
  #     { insert: 'a plan', attributes: { bold: true, italic: true, link: 'https://visitpanama.com' } },
  #     { insert: "\n" },
  #   ])
  #   assert_equal '<p>a man <a href="https://visitpanama.com"><em><strong>a plan</strong></em></a></p>', RichText::HTML.render(d)
  # end

  # it 'allows inline formatting options to override defaults' do
  #   d = RichText::Delta.new([
  #     { insert: 'a man ' },
  #     { insert: 'a plan', attributes: { bold: true } },
  #     { insert: "\n" },
  #   ])
  #   assert_equal '<p>a man <b>a plan</b></p>', RichText::HTML.render(d, { html_inline_tags: { bold: 'b' } })
  # end

  # it 'renders ordered lists' do
  #   d = RichText::Delta.new([
  #     { insert: 'a man' },
  #     { insert: "\n", attributes: { list: true } },
  #     { insert: 'a plan' },
  #     { insert: "\n", attributes: { list: true } },
  #     { insert: 'panama' },
  #     { insert: "\n", attributes: { list: true } }
  #   ])
  #   assert_equal '<ol><li>a man</li><li>a plan</li><li>panama</li></ol>', RichText::HTML.render(d)
  # end

  # it 'renders unordered lists' do
  #   d = RichText::Delta.new([
  #     { insert: 'a man' },
  #     { insert: "\n", attributes: { bullet: true } },
  #     { insert: 'a plan' },
  #     { insert: "\n", attributes: { bullet: true } },
  #     { insert: 'panama' },
  #     { insert: "\n", attributes: { bullet: true } }
  #   ])
  #   assert_equal '<ul><li>a man</li><li>a plan</li><li>panama</li></ul>', RichText::HTML.render(d)
  # end

  # it 'renders whitelisted object insertions' do
  #   d = RichText::Delta.new([
  #     { insert: { image: { src: "https://placekitten.com/200/150" } } },
  #     { insert: "\n" }
  #   ])

  #   assert_equal '<p><img src="https://placekitten.com/200/150"/></p>', RichText::HTML.render(d)
  # end

  # it 'renders custom object insertions' do
  #   d = RichText::Delta.new([
  #     { insert: { embed: { src: "https://www.youtube.com/watch?v=fd8tya7Gmv8" } } },
  #     { insert: "\n" }
  #   ])

  #   assert_equal '<p><iframe src="https://www.youtube.com/watch?v=fd8tya7Gmv8"/></p>', RichText::HTML.render(d, {
  #     html_object_tags: {
  #       embed: ->(content, value) { %(<iframe src="#{content[:src]}"/>) }
  #     }
  #   })
  # end

end