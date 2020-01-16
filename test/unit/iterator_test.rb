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
      assert_equal RichText::Op.new(:insert, 'abc'), subject.peek
      subject.next(1)
      assert_equal RichText::Op.new(:insert, 'bc'), subject.peek
    end

    it 'returns an inifinite retain when no more ops' do
      assert_equal RichText::Op.new(:retain, Float::INFINITY), RichText::Iterator.new([]).peek
    end
  end

  describe 'next?' do
    it 'returns true if we have not advanced beyond the end' do
      assert_equal true, subject.next?
    end

    it 'returns false if we have advanced beyond the end' do
      4.times { subject.next }
      assert_equal false, subject.next?
    end
  end

  describe 'next' do
    it 'without argument, returns remainder of current op' do
      assert_equal RichText::Op.new(:insert, 'abc'), subject.next
      assert_equal RichText::Op.new(:retain, 3, { test: true }), subject.next
    end

    it 'with argument, returns an op of at most that length' do
      assert_equal RichText::Op.new(:insert, 'ab'), subject.next(2)
      assert_equal RichText::Op.new(:insert, 'c'), subject.next(2)
      assert_equal RichText::Op.new(:retain, 2, { test: true }), subject.next(2)
    end
  end

  describe 'reset' do
    it 'rewinds iteration back to the beginning' do
      4.times { subject.next }
      subject.reset
      assert_equal RichText::Op.new(:insert, 'abc'), subject.next
    end
  end
end
