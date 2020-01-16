require 'test_helper'

describe RichText::Attributes do
  subject { RichText::Attributes }
  let(:a) { { a: 1, b: 1, d: nil, x: 3  } }
  let(:b) { { a: 2, c: 2, x: 3 } }

  describe 'compose' do
    it 'reverse merges a into b, removes nil values' do
      assert_equal ({ a: 2, b: 1, c: 2, x: 3 }), subject.compose(a, b, false)
    end

    it 'keeps keys with nil values when requested' do
      assert_equal ({ a: 2, b: 1, c: 2, d: nil, x: 3 }), subject.compose(a, b, true)
    end
  end

  describe 'diff' do
    it 'returns only keys that differ, removals signaled by nil values' do
      assert_equal ({ a: 2, b: nil, c: 2 }), subject.diff(a, b)
    end

    it 'composing `a` with `diff(a, b)` yields `b`' do
      assert_equal b, subject.compose(a, subject.diff(a, b), false)
    end
  end

  describe 'transform' do
    it 'returns b if a is empty' do
      assert_equal b, subject.transform({}, b, false)
    end

    it 'returns b if b is empty' do
      assert_equal ({}), subject.transform(a, {}, false)
    end

    it 'b overwrites a if b has priority' do
      assert_equal b, subject.transform(a, b, false)
    end

    it 'keep only the keys from b that are not in a when a has priority' do
      assert_equal ({ c: 2 }), subject.transform(a, b, true)
    end
  end
end
