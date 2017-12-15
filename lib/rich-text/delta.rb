require 'json'
require 'rich-text/diff'
require 'rich-text/iterator'
require 'rich-text/op'
require 'rich-text/attributes'

module RichText
  class Delta
    include Comparable

    attr_reader :ops

    def initialize(data = [])
      if data.is_a?(Array)
        @ops = data
      elsif data.is_a?(Hash) && (data.key?('ops') || data.key?(:ops))
        @ops = data['ops'] || data[:ops]
      else
        ArgumentError.new("Please provide either an Array or a Hash with an 'ops' key containing an Array")
      end

      @ops
    end

    def insert(value, attributes = {})
      return self if value.is_a?(String) && value.length == 0
      push(Op.new(:insert, value, attributes))
    end

    def delete(value)
      return self if value <= 0
      push(Op.new(:delete, value))
    end

    def retain(value, attributes = {})
      return self if value <= 0
      push(Op.new(:retain, value, attributes))
    end

    def push(new_op)
      index = -1
      last_op = @ops[index]

      if last_op
        if last_op.delete? && new_op.delete?
          @ops[index] = Op.new(:delete, last_op.value + new_op.value)
          return self
        end

        # Since it does not matter if we insert before or after deleting at the
        # same index, always prefer to insert first
        if last_op.delete? && new_op.insert?
          delete_op = @ops.pop
          last_op = @ops.last
          if !last_op
            @ops.push(new_op, delete_op)
            return self
          end
        end

        if last_op.attributes == new_op.attributes
          if last_op.insert?(String) && new_op.insert?(String)
            @ops[index] = Op.new(:insert, last_op.value + new_op.value, last_op.attributes)
            return self
          elsif last_op.retain? && new_op.retain?
            @ops[index] = Op.new(:retain, last_op.value + new_op.value, last_op.attributes)
            return self
          end
        end

        if delete_op
          @ops.push(delete_op)
        end
      end

      @ops.insert(index, new_op)
      return self
    end
    alias :<< :push

    def chop
      last_op = @ops.last
      if last_op && last_op.retain? && !last_op.attributes?
        @ops.pop
      end
      return self
    end

    def iterator
      Iterator.new(@ops)
    end

    def insert_only?
      @ops.all?(&:insert?)
    end

    def trailing_newline?
      return false unless @ops.last && @ops.last.insert?(String)
      @ops.last.value.end_with?("\n")
    end

    def each_slice(size = 1)
      return enum_for(:each_slice) unless block_given?
      iterator.each(size) { |op| yield op }
    end

    def each_char
      raise TypeError.new("cannot iterate each character when retain or delete ops are present") unless insert_only?
      return enum_for(:each_char) unless block_given?
      each_slice(1) { |op| yield op.value, op.attributes }
    end

    def each_line
      raise TypeError.new("cannot iterate each line when retain or delete ops are present") unless insert_only?
      return enum_for(:each_line) unless block_given?

      iter = iterator
      line = Delta.new

      while iter.next?
        op = iter.next
        if !op.insert?(String)
          line.push(op)
          next
        end

        offset = 0
        while idx = op.value.index("\n", offset)
          line.push op.slice(offset, idx - offset + 1)
          yield line
          line = Delta.new
          offset = idx + 1
        end

        if offset < op.value.length
          line.push op.slice(offset)
        end
      end

      yield line if line.length > 0
    end

    def each_op
      return enum_for(:each_op) unless block_given?
      @ops.each { |op| yield op }
    end

    def length
      @ops.reduce(0) { |sum, op| sum + op.length }
    end

    def slice(start = 0, len = length)
      if start.is_a?(Range)
        len = start.size
        start = start.first
      end

      delta = Delta.new
      start = [0, length + start].max if start < 0
      finish = start + len
      iter = iterator
      idx = 0
      while idx < finish && iter.next?
        if idx < start
          op = iter.next(start - idx)
        else
          op = iter.next(finish - idx)
          delta.push(op)
        end
        idx += op.length
      end
      return delta
    end
    alias :[] :slice

    def compose(delta)
      iter_a = iterator
      iter_b = delta.iterator
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
            if op_a.retain?
              attrs = Attributes.compose(op_a.attributes, op_b.attributes, true)
              delta.push Op.new(:retain, len, attrs)
            else
              attrs = Attributes.compose(op_a.attributes, op_b.attributes, false)
              delta.push Op.new(:insert, op_a.value, attrs)
            end
          elsif op_b.delete? && op_a.retain?
            delta.push(op_b)
          end
        end
      end
      delta.chop
    end
    alias :| :compose

    def concat(other)
      if other.length > 0
        push(other.ops.first)
        @ops.concat(other.ops.slice(1..-1))
      end
      self
    end

    def +(other)
      dup.concat(other)
    end

    def diff(other)
      throw TypeError.new("cannot diff deltas that contain retain or delete ops") unless insert_only? && other.insert_only?

      delta = Delta.new
      return delta if self == other

      iter = iterator
      other_iter = other.iterator

      Diff.new(self, other) do |kind, len|
        while len > 0
          case kind
          when :insert
            op_len = [len, other_iter.peek.length].min
            delta.push(other_iter.next(op_len))
          when :delete
            op_len = [len, iter.peek.length].min
            iter.next(op_len)
            delta.delete(op_len)
          when :retain
            op_len = [iter.peek.length, other_iter.peek.length, len].min
            this_op = iter.next(op_len)
            other_op = other_iter.next(op_len)
            if this_op.value == other_op.value
              delta.retain(op_len, Attributes.diff(this_op.attributes, other_op.attributes))
            else
              delta.push(other_op).delete(op_len)
            end
          end
          len -= op_len
        end
      end

      delta.chop
    end
    alias :- :diff

    def transform(other, priority)
      iter = iterator
      other_iter = other.iterator
      delta = Delta.new
      while iter.next? || other_iter.next?
        if iter.peek.insert? && (priority || !other_iter.peek.insert?)
          delta.retain iter.next.length
        elsif other_iter.peek.insert?
          delta.push other_iter.next
        else
          len = [iter.peek.length, other_iter.peek.length].min
          op = iter.next(len)
          other_op = other_iter.next(len)
          if op.delete?
            # Our delete makes their delete redundant, or removes their retain
            next
          elsif other_op.delete?
            delta.push(other_op)
          else
            # We either retain their retain or insert
            delta.retain(len, Attributes.transform(op.attributes, other_op.attributes, priority))
          end
        end
      end
      delta.chop
    end
    alias :^ :transform

    def transform_position(index, priority)
      # TODO
    end

    def as_json(*)
      { :ops => @ops.map(&:as_json) }
    end

    def to_json(*)
      as_json.to_json
    end

    def to_plaintext(convert_embeds = true)
      raise TypeError.new("cannot convert retain or delete ops to plaintext") unless insert_only?
      @ops.each_with_object('') do |op, str|
        if op.insert?(String)
          str << op.value
        elsif convert_embeds
          str << Op::EMBED_CHAR
        end
      end
    end

    def to_html(options = {})
      HTML.render(self)
    end

    def include?(delta)
      # TODO
    end

    def inspect
      str = "#<#{self.class.name} ["
      str << @ops.map { |o| o.inspect(false) }.join(", ")
      str << "]>"
    end

    def hash
      self.class.hash + @ops.hash
    end

    def ==(other)
      @ops == other.ops
    end
    alias_method :eql?, :==

    def =~(pattern)
      @ops.any? do |op|
        op.insert?(String) && op.value =~ pattern
      end
    end
  end
end
