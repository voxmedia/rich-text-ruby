require 'test_helper'

describe RichText::Attributes do
  subject { RichText::Attributes }
  let(:a) { { a: 1, b: 1, d: nil, x: 3  } }
  let(:b) { { a: 2, c: 2, x: 3 } }

  describe 'compose' do
    it 'reverse merges a into b, removes nil values' do
      subject.compose(a, b, false).must_equal({ a: 2, b: 1, c: 2, x: 3 })
    end

    it 'keeps keys with nil values when requested' do
      subject.compose(a, b, true).must_equal({ a: 2, b: 1, c: 2, d: nil, x: 3 })
    end
  end

  describe 'diff' do
    it 'returns only keys that differ, removals signaled by nil values' do
      subject.diff(a, b).must_equal({ a: 2, b: nil, c: 2 })
    end

    it 'composing `a` with `diff(a, b)` yields `b`' do
      subject.compose(a, subject.diff(a, b), false).must_equal b
    end
  end

  describe 'transform' do
    it 'returns b if a is empty' do
      subject.transform({}, b, false).must_equal(b)
    end

    it 'returns b if b is empty' do
      subject.transform(a, {}, false).must_equal({})
    end

    it 'b overwrites a if b has priority' do
      subject.transform(a, b, false).must_equal b
    end

    it 'keep only the keys from b that are not in a when a has priority' do
      subject.transform(a, b, true).must_equal({ c: 2 })
    end
  end
end
