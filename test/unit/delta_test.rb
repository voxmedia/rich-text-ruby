require 'test_helper'

describe RichText::Delta do
  subject { RichText::Delta.new }

  describe 'push' do
    it '#insert is a shortcut' do
      assert_operator subject.insert('abc', x: 1), :eql?, subject
      assert_equal '#<RichText::Delta [insert="abc" {:x=>1}]>', subject.inspect
    end

    it '#retain is a shortcut' do
      assert_operator subject.retain(4, x: 2), :eql?, subject
      assert_equal '#<RichText::Delta [retain=4 {:x=>2}]>', subject.inspect
    end

    it '#delete is a shortcut' do
      assert_operator subject.delete(10), :eql?, subject
      assert_equal '#<RichText::Delta [delete=10]>', subject.inspect
    end

    it 'merges inserts if attributes match' do
      subject.insert('abc', x: 1)
      subject.insert('def', x: 1)
      subject.insert('ghi', x: 2)
      assert_equal '#<RichText::Delta [insert="abcdef" {:x=>1}, insert="ghi" {:x=>2}]>', subject.inspect
    end

    it 'merges retains if attributes match' do
      subject.retain(3, x: 1)
      subject.retain(3, x: 1)
      subject.retain(4)
      assert_equal '#<RichText::Delta [retain=6 {:x=>1}, retain=4]>', subject.inspect
    end

    it 'merges deletes' do
      subject.delete(3)
      subject.delete(4)
      assert_equal '#<RichText::Delta [delete=7]>', subject.inspect
    end

    it 'puts inserts before deletes' do
      subject.retain(1).delete(4).insert('abc')
      assert_equal '#<RichText::Delta [retain=1, insert="abc", delete=4]>', subject.inspect
    end
  end

  describe 'chop!' do
    it 'returns self' do
      assert_operator subject.chop!, :equal?, subject
    end

    it 'removes the last op only if is a retain without attributes' do
      assert_equal '#<RichText::Delta [insert="abc"]>', subject.insert('abc').chop!.inspect
      assert_equal '#<RichText::Delta [insert="abc", retain=3 {:x=>1}]>', subject.retain(3, x: 1).chop!.inspect
      assert_equal '#<RichText::Delta [insert="abc", retain=3 {:x=>1}]>', subject.retain(10).chop!.inspect
    end
  end

  describe 'insert_only?' do
    it 'returns false if there are any non-insert ops' do
      assert_equal true, subject.insert_only?
      subject.insert('abc')
      assert_equal true, subject.insert_only?
      subject.retain(4)
      assert_equal false, subject.insert_only?
    end
  end

  describe 'trailing_newline?' do
    it 'returns true only if the last op is a string that ends in \\n' do
      assert_equal false, subject.trailing_newline?
      assert_equal false, subject.insert('abc').trailing_newline?
      assert_equal true, subject.insert("def\n").trailing_newline?
      assert_equal false, subject.retain(5).trailing_newline?
    end
  end

  describe 'length' do
    it 'returns the sum of each op\'s length' do
      subject.insert('abc').retain(3).delete(4).insert('def')
      assert_equal 13, subject.length
    end
  end

  describe 'slice' do
    subject { RichText::Delta.new.insert('abc').retain(3).delete(3) }

    it 'without arguments, returns a clone' do
      delta = subject.slice
      assert_equal delta, subject
      refute_operator subject, :equal?, delta
    end

    it 'section of desired length and offset' do
      assert_equal '#<RichText::Delta [insert="c"]>', subject.slice(2, 1).inspect
    end

    it 'when start is beyond length, returns an empty delta' do
      assert_equal RichText::Delta.new, subject.slice(50)
    end

    it 'handles negative start value as index from end' do
      assert_equal '#<RichText::Delta [retain=2, delete=3]>', subject.slice(-5).inspect
    end

    it 'handles requested length beyond end of delta' do
      assert_equal subject, subject.slice(0, 50)
    end

    it 'accepts ranges' do
      assert_equal '#<RichText::Delta [insert="c", retain=3, delete=1]>', subject.slice(2..6).inspect
    end

    it 'is available via []' do
      assert_equal '#<RichText::Delta [insert="c"]>', subject[2, 1].inspect
    end
  end

  describe 'concat' do
    it 'returns self' do
      assert_operator subject.concat(RichText::Delta.new.insert('def')), :eql?, subject
    end

    it 'merges consecutive inserts' do
      subject.insert('abc')
      subject.concat RichText::Delta.new.insert('def')
      assert_equal '#<RichText::Delta [insert="abcdef"]>', subject.inspect
    end

    it 'merges consecutive retains'
    it 'merges consecutive deletes'
    it 'otherwise concatenates the ops'
  end

  describe '+' do
    it 'returns a copy concatenated with the argument' do
      subject.insert('abc')
      result = subject + subject
      refute_operator result, :equal?, subject
      assert_equal '#<RichText::Delta [insert="abcabc"]>', result.inspect
    end
  end

  describe 'to_h' do
    it 'returns a hash with an :ops key' do
      assert_equal({
        :ops => [
          { :insert => 'abc' },
          { :retain => 3, :attributes => { :x => 1 } },
          { :delete => 3 }
        ]
      }, subject.insert('abc').retain(3, x: 1).delete(3).to_h)
    end
  end

  describe 'to_plaintext' do
    it 'renders a string of plaintext' do
      subject = RichText::Delta.new([
        { insert: 'a man, ' },
        { insert: 'a plan', attributes: { italic: true } },
        { insert: ', ' },
        { insert: 'panama', attributes: { bold: true } },
        { insert: "\n" },
        { insert: "visit!\n" },
      ])
      assert_equal("a man, a plan, panama\nvisit!", subject.to_plaintext)
    end

    it 'renders plaintext without objects and extra newlines' do
      subject = RichText::Delta.new([
        { insert: "kittens\n" },
        { insert: { image: { src: 'https://placekitten.com/200/150' } } },
        { insert: "\n" },
        { insert: { oembed: { url: 'https://youtu.be/KaOC9danxNo' } } },
        { insert: "\n" },
        { insert: "in space\n" }
      ])
      assert_equal("kittens\nin space", subject.to_plaintext)
    end

    it 'renders plaintext with block handler for objects' do
      subject = RichText::Delta.new([
        { insert: "kittens\n" },
        { insert: { image: { src: 'https://placekitten.com/200/150' } } },
        { insert: "\n" },
        { insert: { oembed: { url: 'https://youtu.be/KaOC9danxNo' } } },
        { insert: "\n" },
        { insert: "in space\n" }
      ])
      result = subject.to_plaintext do |op|
        if op.value.key?(:image)
          op.value[:image][:src]
        end
      end
      assert_equal("kittens\nhttps://placekitten.com/200/150\nin space", result)
    end
  end

  # describe 'include?' do
  #   let(:haystack) { RichText::Delta.new.insert('abc').retain(3).delete(2) }

  #   it 'finds on op boundaries' do
  #     assert_equal true, haystack.include?(subject.insert('abc'))
  #     assert_equal true, haystack.include?(subject.retain(3))
  #   end

  #   it 'finds partial ops' do
  #     assert_equal true, haystack.include?(subject.insert('bc').retain(1))
  #   end
  # end

  describe '=~' do
  end

  describe 'compose' do
    let(:a) { RichText::Delta.new.insert('a') }
    let(:b) { RichText::Delta.new.insert('b') }
    let(:x) { RichText::Delta.new.retain(1, x: 1) }
    let(:y) { RichText::Delta.new.retain(1, y: 1) }
    let(:d) { RichText::Delta.new.delete(1) }

    it 'insert + insert' do
      assert_equal RichText::Delta.new.insert("ba"), a.compose(b)
    end

    it 'insert + retain' do
      assert_equal RichText::Delta.new.insert("a", {:x=>1}), a.compose(x)
    end

    it 'insert + delete' do
      assert_equal RichText::Delta.new, a.compose(d)
    end

    it 'delete + insert' do
      assert_equal RichText::Delta.new.insert("a").delete(1), d.compose(a)
    end

    it 'delete + retain' do
      assert_equal RichText::Delta.new.delete(1).retain(1, {:x=>1}), d.compose(x)
    end

    it 'delete + delete' do
      assert_equal RichText::Delta.new.delete(2), d.compose(d)
    end

    it 'retain + insert' do
      assert_equal RichText::Delta.new.insert("a").retain(1, {:x=>1}), x.compose(a)
    end

    it 'retain + retain' do
      assert_equal RichText::Delta.new.retain(1, {:y=>1, :x=>1}), x.compose(y)
    end

    it 'retain + delete' do
      assert_equal RichText::Delta.new.delete(1), x.compose(d)
    end

    it 'insert in middle' do
      a = RichText::Delta.new.insert('hello')
      b = RichText::Delta.new.retain(3).insert('x')
      assert_equal RichText::Delta.new.insert('helxlo'), a.compose(b)
    end

    it 'insert and delete ordering' do
      base = RichText::Delta.new.insert('hello')
      insert_first = RichText::Delta.new.retain(3).insert('X').delete(1)
      delete_first = RichText::Delta.new.retain(3).delete(1).insert('X')
      expected = RichText::Delta.new.insert('helXo')
      assert_equal expected, base.compose(insert_first)
      assert_equal expected, base.compose(delete_first)
    end

    it 'insert embed' do
      a = RichText::Delta.new.insert(1, src: 'src')
      b = RichText::Delta.new.retain(1, alt: 'alt')
      assert_equal RichText::Delta.new.insert(1, src: 'src', alt: 'alt'), a.compose(b)
    end

    it 'delete everything' do
      a = RichText::Delta.new.retain(4).insert('hello')
      b = RichText::Delta.new.delete(9)
      assert_equal RichText::Delta.new.delete(4), a.compose(b)
    end

    it 'retain more than length' do
      a = RichText::Delta.new.insert('hello')
      b = RichText::Delta.new.retain(10)
      assert_equal RichText::Delta.new.insert('hello'), a.compose(b)
    end

    it 'retain empty embed' do
      a = RichText::Delta.new.insert(1)
      b = RichText::Delta.new.retain(1)
      assert_equal RichText::Delta.new.insert(1), a.compose(b)
    end

    it 'remove all attributes' do
      a = RichText::Delta.new.insert('A', bold: true)
      b = RichText::Delta.new.retain(1, bold: nil)
      assert_equal RichText::Delta.new.insert('A'), a.compose(b)
    end

    it 'remove all embed attributes' do
      a = RichText::Delta.new.insert(1, bold: true)
      b = RichText::Delta.new.retain(1, bold: nil)
      assert_equal RichText::Delta.new.insert(1), a.compose(b)
    end

    it 'immutability' do
    end
  end

  # describe 'diff'
  # describe 'transform'
end
