require 'test_helper'

class PymAwareBuilder < Object
  def render(delta)
    RichText::HTML.new(context: self).render(delta).inner_html
  end

  def build_pym(el, op)
    pym = op.value[:pym]
    el.name = 'div'
    el.add_class('pym')
    el.add_child(%(<p data-pym-src="#{ pym[:url] }"><a href="#{ pym[:url] }">Don't see the graphic? Click here.</a></p>))
    el.add_child(%(<script></script>))
    script = el.children.last
    script['async'] = nil
    script.attributes['async'].value = nil
    script['type'] = "text/javascript"
    script['src'] = "https://pym.nprapps.org/pym.v1.min.js"
    el
  end
end

describe RichText::HTML do
  before do
    RichText.configure do |c|
      c.html_inline_formats = {
        pym: { tag: ->(el, op, ctx) { ctx.build_pym(el, op) }, omit_block: true },
      }.freeze
    end
  end

  it 'renders pym insert' do
    d = RichText::Delta.new([
      { insert: { pym: { url: "https://www.youtube.com/watch?v=fd8tya7Gmv8" } } },
      { insert: "\n" }
    ])
    assert_equal '<div class="pym"><p data-pym-src="https://www.youtube.com/watch?v=fd8tya7Gmv8"><a href="https://www.youtube.com/watch?v=fd8tya7Gmv8">Don\'t see the graphic? Click here.</a></p><script async type="text/javascript" src="https://pym.nprapps.org/pym.v1.min.js"></script></div>', render_compact_html(d)
  end

  def render_compact_html(delta, options={})
    PymAwareBuilder.new.render(delta).gsub("\n", "")
  end
end
