require 'test_helper'

describe RichText::Delta do
  subject { RichText::Delta.new }

  describe 'push' do
    it '#insert is a shortcut' do
      subject.insert('abc', x: 1).must_be :eql?, subject
      subject.inspect.must_equal '#<RichText::Delta [insert="abc" {:x=>1}]>'
    end

    it '#retain is a shortcut' do
      subject.retain(4, x: 2).must_be :eql?, subject
      subject.inspect.must_equal '#<RichText::Delta [retain=4 {:x=>2}]>'
    end

    it '#delete is a shortcut' do
      subject.delete(10).must_be :eql?, subject
      subject.inspect.must_equal '#<RichText::Delta [delete=10]>'
    end

    it 'merges inserts if attributes match' do
      subject.insert('abc', x: 1)
      subject.insert('def', x: 1)
      subject.insert('ghi', x: 2)
      subject.inspect.must_equal '#<RichText::Delta [insert="abcdef" {:x=>1}, insert="ghi" {:x=>2}]>'
    end

    it 'merges retains if attributes match' do
      subject.retain(3, x: 1)
      subject.retain(3, x: 1)
      subject.retain(4)
      subject.inspect.must_equal '#<RichText::Delta [retain=6 {:x=>1}, retain=4]>'
    end

    it 'merges deletes' do
      subject.delete(3)
      subject.delete(4)
      subject.inspect.must_equal '#<RichText::Delta [delete=7]>'
    end

    it 'puts inserts before deletes' do
      subject.retain(1).delete(4).insert('abc')
      subject.inspect.must_equal '#<RichText::Delta [retain=1, insert="abc", delete=4]>'
    end
  end

  describe 'chop!' do
    it 'returns self' do
      subject.chop!.must_be :equal?, subject
    end

    it 'removes the last op only if is a retain without attributes' do
      subject.insert('abc').chop!.inspect.must_equal '#<RichText::Delta [insert="abc"]>'
      subject.retain(3, x: 1).chop!.inspect.must_equal '#<RichText::Delta [insert="abc", retain=3 {:x=>1}]>'
      subject.retain(10).chop!.inspect.must_equal '#<RichText::Delta [insert="abc", retain=3 {:x=>1}]>'
    end
  end

  describe 'insert_only?' do
    it 'returns false if there are any non-insert ops' do
      subject.insert_only?.must_equal true
      subject.insert('abc')
      subject.insert_only?.must_equal true
      subject.retain(4)
      subject.insert_only?.must_equal false
    end
  end

  describe 'trailing_newline?' do
    it 'returns true only if the last op is a string that ends in \\n' do
      subject.trailing_newline?.must_equal false
      subject.insert('abc').trailing_newline?.must_equal false
      subject.insert("def\n").trailing_newline?.must_equal true
      subject.retain(5).trailing_newline?.must_equal false
    end
  end

  describe 'length' do
    it 'returns the sum of each op\'s length' do
      subject.insert('abc').retain(3).delete(4).insert('def')
      subject.length.must_equal 13
    end
  end

  describe 'slice' do
    subject { RichText::Delta.new.insert('abc').retain(3).delete(3) }

    it 'without arguments, returns a clone' do
      delta = subject.slice
      subject.must_equal delta
      subject.wont_be :equal?, delta
    end

    it 'section of desired length and offset' do
      subject.slice(2, 1).inspect.must_equal '#<RichText::Delta [insert="c"]>'
    end

    it 'when start is beyond length, returns an empty delta' do
      subject.slice(50).must_equal RichText::Delta.new
    end

    it 'handles negative start value as index from end' do
      subject.slice(-5).inspect.must_equal '#<RichText::Delta [retain=2, delete=3]>'
    end

    it 'handles requested length beyond end of delta' do
      subject.slice(0, 50).must_equal subject
    end

    it 'accepts ranges' do
      subject.slice(2..6).inspect.must_equal '#<RichText::Delta [insert="c", retain=3, delete=1]>'
    end

    it 'is available via []' do
      subject[2, 1].inspect.must_equal '#<RichText::Delta [insert="c"]>'
    end
  end

  describe 'concat' do
    it 'returns self' do
      subject.concat(RichText::Delta.new.insert('def')).must_be :eql?, subject
    end

    it 'merges consecutive inserts' do
      subject.insert('abc')
      subject.concat RichText::Delta.new.insert('def')
      subject.inspect.must_equal '#<RichText::Delta [insert="abcdef"]>'
    end

    it 'merges consecutive retains'
    it 'merges consecutive deletes'
    it 'otherwise concatenates the ops'
  end

  describe '+' do
    it 'returns a copy concatenated with the argument' do
      subject.insert('abc')
      result = subject + subject
      result.wont_be :equal?, subject
      result.inspect.must_equal '#<RichText::Delta [insert="abcabc"]>'
    end
  end

  describe 'to_h' do
    it 'returns a hash with an :ops key' do
      subject.insert('abc').retain(3, x: 1).delete(3).to_h.must_equal({
        :ops => [
          { :insert => 'abc' },
          { :retain => 3, :attributes => { :x => 1 } },
          { :delete => 3 }
        ]
      })
    end
  end

  # describe 'include?' do
  #   let(:haystack) { RichText::Delta.new.insert('abc').retain(3).delete(2) }

  #   it 'finds on op boundaries' do
  #     haystack.include?(subject.insert('abc')).must_equal true
  #     haystack.include?(subject.retain(3)).must_equal true
  #   end

  #   it 'finds partial ops' do
  #     haystack.include?(subject.insert('bc').retain(1)).must_equal true
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
      a.compose(b).must_equal RichText::Delta.new.insert("ba")
    end

    it 'insert + retain' do
      a.compose(x).must_equal RichText::Delta.new.insert("a", {:x=>1})
    end

    it 'insert + delete' do
      a.compose(d).must_equal RichText::Delta.new
    end

    it 'delete + insert' do
      d.compose(a).must_equal RichText::Delta.new.insert("a").delete(1)
    end

    it 'delete + retain' do
      d.compose(x).must_equal RichText::Delta.new.delete(1).retain(1, {:x=>1})
    end

    it 'delete + delete' do
      d.compose(d).must_equal RichText::Delta.new.delete(2)
    end

    it 'retain + insert' do
      x.compose(a).must_equal RichText::Delta.new.insert("a").retain(1, {:x=>1})
    end

    it 'retain + retain' do
      x.compose(y).must_equal RichText::Delta.new.retain(1, {:y=>1, :x=>1})
    end

    it 'retain + delete' do
      x.compose(d).must_equal RichText::Delta.new.delete(1)
    end

    it 'insert in middle' do
      a = RichText::Delta.new.insert('hello')
      b = RichText::Delta.new.retain(3).insert('x')
      a.compose(b).must_equal RichText::Delta.new.insert('helxlo')
    end

    it 'insert and delete ordering' do
      base = RichText::Delta.new.insert('hello')
      insert_first = RichText::Delta.new.retain(3).insert('X').delete(1)
      delete_first = RichText::Delta.new.retain(3).delete(1).insert('X')
      expected = RichText::Delta.new.insert('helXo')
      base.compose(insert_first).must_equal expected
      base.compose(delete_first).must_equal expected
    end

    it 'insert embed' do
      a = RichText::Delta.new.insert(1, src: 'src')
      b = RichText::Delta.new.retain(1, alt: 'alt')
      a.compose(b).must_equal RichText::Delta.new.insert(1, src: 'src', alt: 'alt')
    end

    it 'delete everything' do
      a = RichText::Delta.new.retain(4).insert('hello')
      b = RichText::Delta.new.delete(9)
      a.compose(b).must_equal RichText::Delta.new.delete(4)
    end

    it 'retain more than length' do
      a = RichText::Delta.new.insert('hello')
      b = RichText::Delta.new.retain(10)
      a.compose(b).must_equal RichText::Delta.new.insert('hello')
    end

    it 'retain empty embed' do
      a = RichText::Delta.new.insert(1)
      b = RichText::Delta.new.retain(1)
      a.compose(b).must_equal RichText::Delta.new.insert(1)
    end

    it 'remove all attributes' do
      a = RichText::Delta.new.insert('A', bold: true)
      b = RichText::Delta.new.retain(1, bold: nil)
      a.compose(b).must_equal RichText::Delta.new.insert('A')
    end

    it 'remove all embed attributes' do
      a = RichText::Delta.new.insert(1, bold: true)
      b = RichText::Delta.new.retain(1, bold: nil)
      a.compose(b).must_equal RichText::Delta.new.insert(1)
    end

    it 'immutability' do
    end
  end

  # describe 'diff'
  # describe 'transform'
end
