describe RichText::Op do
  describe 'new' do
    it 'raises ArgumentError if the first arg is invalid' do
      proc { RichText::Op.new(:bogus, 1) }.must_raise ArgumentError
    end

    it 'raises ArgumentError if a non-Fixnum is provided for retain or delete' do
      proc { RichText::Op.new(:retain, 'bogus') }.must_raise ArgumentError
      proc { RichText::Op.new(:delete, 'bogus') }.must_raise ArgumentError
      RichText::Op.new(:retain, Float::INFINITY) # must not raise
    end

    it 'raises ArgumentError if a non-Hash is provided as attributes' do
      proc { RichText::Op.new(:insert, 'x', :bogus) }.must_raise ArgumentError
    end
  end

  describe 'attributes' do
    it 'returns what was set as the 3rd argument' do
      attrs = { foo: true }
      RichText::Op.new(:retain, 1, attrs).attributes.must_equal attrs
    end

    it 'returns {} if none were provided' do
      RichText::Op.new(:retain, 1).attributes.must_equal({})
    end
  end

  describe 'attributes?' do
    it 'returns true if there are any' do
      RichText::Op.new(:retain, 1, { foo: true }).attributes?.must_equal true
    end

    it 'returns false if there are none' do
      RichText::Op.new(:retain, 1).attributes?.must_equal false
      RichText::Op.new(:retain, 1, {}).attributes?.must_equal false
    end
  end

  describe 'types' do
    it 'insert? returns true for inserts' do
      RichText::Op.new(:insert, 'x').insert?.must_equal true
      RichText::Op.new(:insert, 1).insert?.must_equal true
      RichText::Op.new(:retain, 1).insert?.must_equal false
      RichText::Op.new(:delete, 1).insert?.must_equal false
    end

    it 'insert?(String) only returns true for strings' do
      RichText::Op.new(:insert, 'x').insert?(String).must_equal true
      RichText::Op.new(:insert, 1).insert?(String).must_equal false
    end

    it 'retain? returns true for retains' do
      RichText::Op.new(:retain, 1).retain?.must_equal true
      RichText::Op.new(:insert, 1).retain?.must_equal false
      RichText::Op.new(:delete, 1).retain?.must_equal false
    end

    it 'delete? returns true for deletes' do
      RichText::Op.new(:retain, 1).delete?.must_equal false
      RichText::Op.new(:insert, 1).delete?.must_equal false
      RichText::Op.new(:delete, 1).delete?.must_equal true
    end
  end

  it 'value returns the 2nd argument' do
    RichText::Op.new(:insert, 'abc').value.must_equal 'abc'
    RichText::Op.new(:retain, 7).value.must_equal 7
    RichText::Op.new(:delete, 4).value.must_equal 4
  end

  describe 'length' do
    it 'returns the length of the string for text inserts' do
      RichText::Op.new(:insert, 'abc').length.must_equal 3
    end

    it 'returns 1 for non-text inserts' do
      RichText::Op.new(:insert, { foo: 'bar' }).length.must_equal 1
    end

    it 'returns the argument for retains' do
      RichText::Op.new(:retain, 11).length.must_equal 11
    end

    it 'returns the argument for deletes' do
      RichText::Op.new(:delete, 2).length.must_equal 2
    end
  end

  describe 'slice' do
    it 'returns a dup when no args passed' do
      op = RichText::Op.new(:insert, 'abc')
      op.slice.must_equal op
      op.slice.wont_be :eql?, op
    end

    it 'cannot split a non-string insert' do
      op = RichText::Op.new(:insert, 1, { foo: 'bar' })
      op.slice(0, 1).must_equal op
      proc { op.slice(1, 2) }.must_raise ArgumentError
    end

    it 'splits a string insert' do
      RichText::Op.new(:insert, 'abc').slice(1, 1)
        .must_equal RichText::Op.new(:insert, 'b')
      RichText::Op.new(:insert, 'abc', { x: true }).slice(1, 5)
        .must_equal RichText::Op.new(:insert, 'bc', { x: true })
    end

    it 'splits a retain' do
      RichText::Op.new(:retain, 10, { x: true }).slice(4, 2)
        .must_equal RichText::Op.new(:retain, 2, { x: true })
      RichText::Op.new(:retain, 10, { x: true }).slice(4, 20)
        .must_equal RichText::Op.new(:retain, 6, { x: true })
    end

    it 'splits a delete' do
      RichText::Op.new(:retain, 10).slice(4, 2)
        .must_equal RichText::Op.new(:retain, 2)
      RichText::Op.new(:retain, 10).slice(4, 20)
        .must_equal RichText::Op.new(:retain, 6)
    end
  end

  describe 'as_json' do
    it 'omits attributes when not present' do
      RichText::Op.new(:insert, 'abc').as_json.must_equal(:insert => 'abc')
    end

    it 'includes attributes when present' do
      RichText::Op.new(:insert, 'abc', { foo: true }).as_json.must_equal({
        :insert => 'abc',
        :attributes => { :foo => true }
      })
    end
  end

  describe 'inspect' do
    it 'includes class name by default' do
      RichText::Op.new(:insert, 'abc', { foo: true }).inspect
        .must_equal '#<RichText::Op insert="abc" {:foo=>true}>'
    end

    it 'omits class name when flag is passed' do
      RichText::Op.new(:retain, 4, { x: 1 }).inspect(false)
        .must_equal "retain=4 {:x=>1}"
    end
  end

  describe '==' do
    let(:a) { RichText::Op.new(:insert, '!', { foo: 'bar' }) }
    let(:b) { RichText::Op.new(:insert, '!', { foo: 'bar' }) }
    let(:c) { RichText::Op.new(:insert, '?', { foo: 'bar' }) }
    let(:x) { RichText::Op.new(:retain, 4) }
    let(:y) { RichText::Op.new(:retain, 4, { foo: 'bar' }) }
    let(:z) { RichText::Op.new(:delete, 4) }

    it 'returns true for same type, arg, and attributes' do
      a.must_equal b
      x.wont_equal y
      x.wont_equal z
    end

    it 'returns false for differing types' do
      a.wont_equal x
      x.wont_equal z
    end

    it 'returns false for differing values' do
      a.wont_equal c
    end

    it 'returns false for differing attributes' do
      x.wont_equal y
    end
  end

  describe '<=>' do
    it 'returns nil for differing types' do
      a = RichText::Op.new(:insert, 'abc')
      b = RichText::Op.new(:retain, 3)
      (a <=> b).must_be_nil
    end

    it 'compares inserts by value, ignoring attributes' do
      a = RichText::Op.new(:insert, 'abc', { x: 100 })
      b = RichText::Op.new(:insert, 'abc', { x: 2 })
      (a <=> b).must_equal 0
      b = RichText::Op.new(:insert, 'def', { x: 2 })
      (a <=> b).must_equal -1
    end

    it 'compares retains by value, ignoring attributes' do
      a = RichText::Op.new(:retain, 3, { x: 100 })
      b = RichText::Op.new(:retain, 3, { x: 200 })
      (a <=> b).must_equal 0
      b = RichText::Op.new(:retain, 1, { x: 200 })
      (a <=> b).must_equal 1
    end

    it 'compares deletes by value' do
      a = RichText::Op.new(:delete, 3)
      b = RichText::Op.new(:delete, 1)
      (a <=> a).must_equal 0
      (a <=> b).must_equal 1
    end
  end
end
