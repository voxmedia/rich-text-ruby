require 'test_helper'

describe RichText::Iterator do
  subject do
    RichText::Iterator.new([
      RichText::Op.new(:insert, 'abc'),
      RichText::Op.new(:retain, 3, { test: true }),
      RichText::Op.new(:delete, 3),
      RichText::Op.new(:insert, 'def')
    ])
  end

  describe 'peek' do
    it 'returns the full remainder of the current op' do
      subject.peek.must_equal RichText::Op.new(:insert, 'abc')
      subject.next(1)
      subject.peek.must_equal RichText::Op.new(:insert, 'bc')
    end

    it 'returns an inifinite retain when no more ops' do
      RichText::Iterator.new([]).peek.must_equal RichText::Op.new(:retain, Float::INFINITY)
    end
  end

  describe 'next?' do
    it 'returns true if we have not advanced beyond the end' do
      subject.next?.must_equal true
    end

    it 'returns false if we have advanced beyond the end' do
      4.times { subject.next }
      subject.next?.must_equal false
    end
  end

  describe 'next' do
    it 'without argument, returns remainder of current op' do
      subject.next.must_equal RichText::Op.new(:insert, 'abc')
      subject.next.must_equal RichText::Op.new(:retain, 3, { test: true })
    end

    it 'with argument, returns an op of at most that length' do
      subject.next(2).must_equal RichText::Op.new(:insert, 'ab')
      subject.next(2).must_equal RichText::Op.new(:insert, 'c')
      subject.next(2).must_equal RichText::Op.new(:retain, 2, { test: true })
    end
  end

  describe 'reset' do
    it 'rewinds iteration back to the beginning' do
      4.times { subject.next }
      subject.reset
      subject.next.must_equal RichText::Op.new(:insert, 'abc')
    end
  end
end
