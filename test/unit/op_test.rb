describe RichText::Op do
  describe 'parse' do
    it 'raises ArgumentError if invalid hash keys are provided' do
      assert_raises(ArgumentError) { RichText::Op.parse({ bogus: 1 }) }
    end

    it 'raises ArgumentError if a non-Integer is provided for retain or delete' do
      assert_raises(ArgumentError) { RichText::Op.parse({ retain: 'bogus' }) }
      assert_raises(ArgumentError) { RichText::Op.parse({ delete: 'bogus' }) }
      RichText::Op.parse({ retain: 1 }) # must not raise
    end

    it 'raises ArgumentError if a non-Hash is provided as attributes' do
      assert_raises(ArgumentError) { RichText::Op.parse({ insert: 'x', attributes: :bogus }) }
    end
  end

  describe 'attributes' do
    it 'returns what was set as the 3rd argument' do
      attrs = { foo: true }
      assert_equal attrs, RichText::Op.new(:retain, 1, attrs).attributes
    end

    it 'returns {} if none were provided' do
      assert_equal ({}), RichText::Op.new(:retain, 1).attributes
    end
  end

  describe 'attributes?' do
    it 'returns true if there are any' do
      assert_equal true, RichText::Op.new(:retain, 1, { foo: true }).attributes?
    end

    it 'returns false if there are none' do
      assert_equal false, RichText::Op.new(:retain, 1).attributes?
      assert_equal false, RichText::Op.new(:retain, 1, {}).attributes?
    end
  end

  describe 'types' do
    it 'insert? returns true for inserts' do
      assert_equal true, RichText::Op.new(:insert, 'x').insert?
      assert_equal true, RichText::Op.new(:insert, 1).insert?
      assert_equal false, RichText::Op.new(:retain, 1).insert?
      assert_equal false, RichText::Op.new(:delete, 1).insert?
    end

    it 'insert?(String) only returns true for strings' do
      assert_equal true, RichText::Op.new(:insert, 'x').insert?(String)
      assert_equal false, RichText::Op.new(:insert, 1).insert?(String)
    end

    it 'retain? returns true for retains' do
      assert_equal true, RichText::Op.new(:retain, 1).retain?
      assert_equal false, RichText::Op.new(:insert, 1).retain?
      assert_equal false, RichText::Op.new(:delete, 1).retain?
    end

    it 'delete? returns true for deletes' do
      assert_equal false, RichText::Op.new(:retain, 1).delete?
      assert_equal false, RichText::Op.new(:insert, 1).delete?
      assert_equal true, RichText::Op.new(:delete, 1).delete?
    end
  end

  it 'value returns the 2nd argument' do
    assert_equal 'abc', RichText::Op.new(:insert, 'abc').value
    assert_equal 7, RichText::Op.new(:retain, 7).value
    assert_equal 4, RichText::Op.new(:delete, 4).value
  end

  describe 'length' do
    it 'returns the length of the string for text inserts' do
      assert_equal 3, RichText::Op.new(:insert, 'abc').length
    end

    it 'returns 1 for non-text inserts' do
      assert_equal 1, RichText::Op.new(:insert, { foo: 'bar' }).length
    end

    it 'returns the argument for retains' do
      assert_equal 11, RichText::Op.new(:retain, 11).length
    end

    it 'returns the argument for deletes' do
      assert_equal 2, RichText::Op.new(:delete, 2).length
    end
  end

  describe 'slice' do
    it 'returns a dup when no args passed' do
      op = RichText::Op.new(:insert, 'abc')
      assert_equal op, op.slice
      refute_operator op.slice, :equal?, op
    end

    it 'cannot split a non-string insert' do
      op = RichText::Op.new(:insert, 1, { foo: 'bar' })
      assert_equal op, op.slice(0, 1)
      assert_raises(ArgumentError) { op.slice(1, 2) }
    end

    it 'splits a string insert' do
      assert_equal(
        RichText::Op.new(:insert, 'b'),
        RichText::Op.new(:insert, 'abc').slice(1, 1)
      )
      assert_equal(
        RichText::Op.new(:insert, 'bc', { x: true }),
        RichText::Op.new(:insert, 'abc', { x: true }).slice(1, 5)
      )
    end

    it 'splits a retain' do
      assert_equal(
        RichText::Op.new(:retain, 2, { x: true }),
        RichText::Op.new(:retain, 10, { x: true }).slice(4, 2)
      )
      assert_equal(
        RichText::Op.new(:retain, 6, { x: true }),
        RichText::Op.new(:retain, 10, { x: true }).slice(4, 20)
      )
    end

    it 'splits a delete' do
      assert_equal(
        RichText::Op.new(:retain, 2),
        RichText::Op.new(:retain, 10).slice(4, 2)
      )
      assert_equal(
        RichText::Op.new(:retain, 6),
        RichText::Op.new(:retain, 10).slice(4, 20)
      )
    end
  end

  describe 'to_h' do
    it 'omits attributes when not present' do
      assert_equal ({ :insert => 'abc' }), RichText::Op.new(:insert, 'abc').to_h
    end

    it 'includes attributes when present' do
      assert_equal({
        :insert => 'abc',
        :attributes => { :foo => true }
      }, RichText::Op.new(:insert, 'abc', { foo: true }).to_h)
    end
  end

  describe 'inspect' do
    it 'includes class name by default' do
      assert_equal(
        '#<RichText::Op insert="abc" {:foo=>true}>',
        RichText::Op.new(:insert, 'abc', { foo: true }).inspect
      )
    end

    it 'omits class name when flag is passed' do
      assert_equal(
        "retain=4 {:x=>1}",
        RichText::Op.new(:retain, 4, { x: 1 }).inspect(false)
      )
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
      assert_equal b, a
      refute_equal y, x
      refute_equal z, x
    end

    it 'returns false for differing types' do
      refute_equal x, a
      refute_equal z, x
    end

    it 'returns false for differing values' do
      refute_equal c, a
    end

    it 'returns false for differing attributes' do
      refute_equal y, x
    end
  end
end
