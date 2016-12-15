require 'json'
require 'rich-text/iterator'
require 'rich-text/op'
require 'rich-text/attributes'

module RichText
  class Delta
    IncompleteError = Class.new(StandardError)

    def initialize
      @ops = []
    end

    def insert(text, attributes = nil)
      return self if text.length == 0
      push(Op.new(:insert, text, attributes))
    end

    def delete(length)
      return self if length <= 0
      push(Op.new(:delete, length))
    end

    def retain(length, attributes = nil)
      return self if length <= 0
      push(Op.new(:retain, length, attributes))
    end

    def push(new_op)
      index = -1
      last_op = @ops.last
      new_op = new_op.dup

      if last_op
        if last_op.delete? && new_op.delete?
          @ops[index] = Op.new(:delete, last_op.delete + new_op.delete)
          return self
        end

        # Since it does not matter if we insert before or after deleting at the
        # same index, always prefer to insert first
        if last_op.delete? && new_op.insert?
          index -= 1
          last_op = @ops[index]
          if !last_op
            @ops.unshift(new_op)
            return self
          end
        end

        if last_op.attributes == new_op.attributes
          if last_op.insert?(String) && new_op.insert?(String)
            @ops[index] = Op.new(:insert, last_op.insert + new_op.insert)
            return self
          elsif last_op.retain? && new_op.retain?
            @ops[index] = Op.new(:retain, last_op.retain + new_op.retain)
            return self
          end
        end
      end

      @ops.insert(index, new_op)
      return self
    end

    def chop
      last_op = @ops.last
      if last_op && last_op.retain? && !last_op.attributes?
        @ops.pop
      end
      return self
    end

    def composed?
      @ops.all?(&:insert?)
    end

    def each_op
      return enum_for(:each_op) unless block_given?
      @ops.each { |op| yield op }
    end

    def each_char
      raise IncompleteError.new unless composed?
      return enum_for(:each_char) unless block_given?
      iter = Iterator.new(@ops)
      while iter.next?
        yield iter.next(1)
      end
    end

    def each_line
      raise IncompleteError.new unless composed?
      return enum_for(:each_line) unless block_given?
      iter = Iterator.new(@ops)
      line = []
      while iter.next?
        op = iter.next
        if idx = op.insert?(String) && op.insert.index(/\n/)
          line << op[0, idx]
          yield line
          line = []
          line << op[idx] if idx < op.length
        else
          line << op
        end
      end
      yield line if line.length > 0
    end

    def length
      @ops.map(&:length).reduce(:+)
    end

    def slice(start = 0, len = length)
      if start.is_a?(Range)
        len = start.size
        start = start.first
      end

      delta = Delta.new
      iter = Iterator.new(@ops)
      idx = 0
      while idx < len && iter.next?
        if idx < start
          next_op = iter.next(start - idx)
        else
          next_op = iter.next(len - idx)
          delta.push(next_op)
        end
        idx += next_op.length
      end
      return delta
    end
    alias_method :[], :slice

    def compose(delta)
      iter_a = Iterator.new(@ops)
      iter_b = Iterator.new(delta.instance_variable_get(:@ops))
      delta = Delta.new
      while iter_a.next? || iter_b.next?
        if iter_b.peek.insert?
          delta.push(iter_b.next)
        elsif iter_a.peek.delete?
          delta.push(iter_a.next)
        else
          len = [iter_a.peek.length, iter_b.peek.length].min
          op_a = iter_a.next(len)
          op_b = iter_b.next(len)
          if op_b.retain?
            new_op = op_a.retain? ? Op.new(:retain, len) : Op.new(:insert, op_a.insert)
            new_op.attributes = Attributes.compose(op_a.attributes, op_b.attributes, op_a.retain?)
            delta.push(new_op)
          elsif op_b.delete? && op_a.retain?
            delta.push(op_b)
          end
        end
      end
      delta.chop
    end

    def concat(other)
      delta = dup
      if other.length > 0
        delta.push(other.ops.first)
        delta.ops.concat(other.ops.slice(1))
      end
      delta
    end

    def diff(delta)
    end

    def transform(delta, priority)
    end

    def transform_position(index, priority)
    end

    def as_json(*)
      { :ops => @ops.map(&:as_json) }
    end

    def to_json(*)
      as_json.to_json
    end

    def to_s
      raise IncompleteError.new unless composed?
      @ops.join
    end
  end
end
