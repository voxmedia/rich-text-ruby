require 'json'
require 'rich-text/diff'
require 'rich-text/iterator'
require 'rich-text/op'
require 'rich-text/attributes'

module RichText
  # A Delta is made up of an array of operations. All methods maintain the property that Deltas are represented in the most compact form. For example two consecutive insert operations with the same attributes will be merged into one. Thus a vanilla deep Hash/Array comparison can be used to determine Delta equality.
  #
  # A Delta with only insert operations can be used to represent a fully formed document. This can be thought of as a Delta applied to an empty document.
  class Delta
    # @return [Array<Op>]
    attr_reader :ops

    # Parses a new Delta object from incoming data.
    # @param data [String, Array, Hash] String, Array of operations, or a Hash with an `:ops` or `'ops'` key set to an array of operations
    # @raise [ArgumentError] if an argument other than a String, Array, or Hash is passed, or if any of the contained operations cannot be parsed by {Op.parse}
    # @example
    #   # All equivalent
    #   RichText::Delta.new("abc")
    #   RichText::Delta.new([{ insert: 'abc' }])
    #   RichText::Delta.new({ ops: [{ insert: 'abc' }] })
    def initialize(data = [])
      if data.is_a?(String)
        @ops = [Op.new(:insert, data)]
      elsif data.is_a?(Array)
        @ops = data.map { |h| Op.parse(h) }
      elsif data.is_a?(Hash) && (data.key?('ops') || data.key?(:ops))
        @ops = (data['ops'] || data[:ops]).map { |h| Op.parse(h) }
      else
        ArgumentError.new("Please provide either String, Array or Hash with an 'ops' key containing an Array")
      end

      @ops
    end

    # Appends an insert operation. A no-op if the provided value is the empty string.
    # @param value [String|{ String => Object }] the value to insert, either a String or a Hash with a single String or Symbol key
    # @param attributes [Hash]
    # @return [Delta] `self` for chainability
    # @example
    #   delta.insert('abc').insert('xyz', { bold: true })
    #   delta.insert({ image: 'http://i.imgur.com/FUCb95Y.gif' })
    def insert(value, attributes = {})
      return self if value.is_a?(String) && value.length == 0
      push(Op.new(:insert, value, attributes))
    end

    # Appends a delete operation. A no-op if value <= 0.
    # @param value [Integer] the number of characters to delete
    # @return [Delta] `self` for chainability
    # @example
    #   delta.delete(5)
    def delete(value)
      return self if value <= 0
      push(Op.new(:delete, value))
    end

    # Appends a retain operation. A no-op if value <= 0.
    # @param value [Integer] the number of characters to skip or change attributes for
    # @param attributes [Hash] leave blank to leave attributes unchanged
    # @return [Delta] `self` for chainability
    # @example
    #   delta.retain(4).retain(5, { color: '#0c6' })
    def retain(value, attributes = {})
      return self if value <= 0
      push(Op.new(:retain, value, attributes))
    end

    # Adds a new operation to the end of the delta, possibly merging it with the previously-last op if the types and attributes match, and ensuring that inserts always come before deletes.
    # @param op [Op] the operation to add
    # @return [Delta] `self` for chainability
    def push(op)
      index = @ops.length
      last_op = @ops[index - 1]

      if last_op
        if last_op.delete? && op.delete?
          @ops[index - 1] = Op.new(:delete, last_op.value + op.value)
          return self
        end

        # Since it does not matter if we insert before or after deleting at the
        # same index, always prefer to insert first
        if last_op.delete? && op.insert?
          index -= 1
          last_op = @ops[index - 1]
          if !last_op
            @ops.unshift(op)
            return self
          end
        end

        if last_op.attributes == op.attributes
          if last_op.insert?(String) && op.insert?(String)
            @ops[index - 1] = Op.new(:insert, last_op.value + op.value, last_op.attributes)
            return self
          elsif last_op.retain? && op.retain?
            @ops[index - 1] = Op.new(:retain, last_op.value + op.value, last_op.attributes)
            return self
          end
        end
      end

      if index == @ops.length
        @ops.push(op)
      else
        @ops[index, 0] = op
      end

      return self
    end
    alias :<< :push

    # Modifies self by removing the last op if it was a retain without attributes.
    # @return [Delta] `self` for chainability
    def chop!
      last_op = @ops.last
      if last_op && last_op.retain? && !last_op.attributes?
        @ops.pop
      end
      return self
    end

    # Returns true if all operations are inserts, i.e. a fully-composed document
    # @return [Boolean]
    def insert_only?
      @ops.all?(&:insert?)
    end
    alias :document? :insert_only?

    # Returns true if the last operation is a string insert that ends with a `\n` character.
    # @return [Boolean]
    def trailing_newline?
      return false unless @ops.last && @ops.last.insert?(String)
      @ops.last.value.end_with?("\n")
    end

    # Returns true if `other` is a substring of `self`
    # @param other [Delta]
    # @return [Boolean]
    # @todo Not implemented yet
    def include?(other)
      raise NotImplementedError.new("TODO")
    end

    # Yields ops of at most `size` length to the block, or returns an enumerator which will do the same
    # @param size [Integer]
    # @yield [op] an {Op} object
    # @return [Enumerator, Delta] if no block given, returns an {Enumerator}, else returns `self` for chainability
    # @example
    #   delta = RichText::Delta.new.insert('abc')
    #   delta.each_slice(2).to_a # => [#<RichText::Op insert="ab">, #<RichText::Op insert="c">]
    def each_slice(size = 1)
      return enum_for(:each_slice, size) unless block_given?
      Iterator.new(@ops).each(size) { |op| yield op }
      self
    end

    # Yields char + attribute pairs of at most length = 1 to the block, or returns an enumerator which will do the same.
    # Non-string inserts will result in that value being yielded instead of a string.
    # The behavior is not defined with non-insert operations.
    # @yield [char, attributes]
    # @return [Enumerator, Delta] if no block given, returns an {Enumerator}, else returns `self` for chainability
    # @example
    #   delta = RichText::Delta.new.insert('a', { bold: true }).insert('b').insert({ image: 'http://i.imgur.com/YtQPTnw.gif' })
    #   delta.each_char.to_a # => [["a", { bold: true }], ["b", {}], [{ image: "http://i.imgur.com/YtQPTnw.gif" }, {}]]
    def each_char
      return enum_for(:each_char) unless block_given?
      each_slice(1) { |op| yield op.value, op.attributes }
      self
    end

    # Yields {Delta} objects corresponding to each `\n`-separated line in the document, each including a trailing newline (except for the last if no trailing newline is present overall).
    # The behavior is not defined with non-insert operations.
    # @yield [delta]
    # @return [Enumerator, Delta] if no block given, returns an {Enumerator}, else returns `self` for chainability
    # @example
    #   delta = RichText::Delta.new.insert("abc\n123\n")
    #   delta.each_line.to_a # => [#<RichText::Delta [insert="abc\n"]>, #<RichText::Delta [insert="123\n"]>]
    def each_line
      return enum_for(:each_line) unless block_given?

      iter = Iterator.new(@ops)
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

    # Yields each operation in the delta, as-is.
    # @yield [op] an {Op} object
    # @return [Enumerator, Delta] if no block given, returns an {Enumerator}, else returns `self` for chainability
    def each_op
      return enum_for(:each_op) unless block_given?
      @ops.each { |op| yield op }
      self
    end

    # @return [Integer] the sum of the lengths of each operation.
    # @example
    #   RichText::Delta.new.insert('Hello').length # => 5
    #   RichText::Delta.new.insert('A').retain(2).delete(1).length # => 4
    def length
      @ops.reduce(0) { |sum, op| sum + op.length }
    end

    # Returns a copy containing a subset of operations, measured in number of characters.
    # An operation may be subdivided if needed to return just the requested length. Non-string inserts cannot be subdivided (naturally, as they have length 1).
    # @param start [Integer] starting offset
    # @param len [Integer] how many characters
    # @return [Delta] whose length is at most `len`
    # @example
    #   delta = RichText::Delta.new.insert('Hello', { bold: true }).insert(' World')
    #   copy = delta.slice() # => #<RichText::Delta [insert="Hello" {:bold=>true}, insert=" World"]>
    #   world = delta.slice(6) # => #<RichText::Delta [insert="World"]>
    #   space = delta.slice(5, 1) # => #<RichText::Delta [insert=" "]>
    def slice(start = 0, len = length)
      if start.is_a?(Range)
        len = start.size
        start = start.first
      end

      delta = Delta.new
      start = [0, length + start].max if start < 0
      finish = start + len
      iter = Iterator.new(@ops)
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

    # Returns a Delta that is equivalent to first applying the operations of `self`, then applying the operations of `other` on top of that.
    # @param other [Delta]
    # @return [Delta]
    # @example
    #   a = RichText::Delta.new.insert('abc')
    #   b = RichText::Delta.new.retain(1).delete(1)
    #   a.compose(b) # => #<RichText::Delta [insert="ac"]>
    def compose(other)
      iter_a = Iterator.new(@ops)
      iter_b = Iterator.new(other.ops)
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
              delta.push(Op.new(:retain, len, attrs))
            else
              attrs = Attributes.compose(op_a.attributes, op_b.attributes, false)
              delta.push(Op.new(:insert, op_a.value, attrs))
            end
          elsif op_b.delete? && op_a.retain?
            delta.push(op_b)
          end
        end
      end
      delta.chop!
    end
    alias :| :compose

    # Modifies `self` by the concatenating this and another document Delta's operations.
    # Correctly handles the case of merging the last operation of `self` with the first operation of `other`, if possible.
    # The behavior is not defined when either `self` or `other` has non-insert operations.
    # @param other [Delta]
    # @return [Delta] `self`
    # @example
    #   a = RichText::Delta.new.insert('Hello')
    #   b = RichText::Delta.new.insert(' World!')
    #   a.concat(b) # => #<RichText::Delta [insert="Hello World!"]>
    def concat(other)
      if other.length > 0
        push(other.ops.first)
        @ops.concat(other.ops.slice(1..-1))
      end
      self
    end

    # The non-destructive version of {#concat}
    # @see #concat
    def +(other)
      dup.concat(other)
    end

    # Returns a Delta representing the difference between two documents.
    # The behavior is not defined when either `self` or `other` has non-insert operations.
    # @param other [Delta]
    # @return [Delta]
    # @example
    #   a = RichText::Delta.new.insert('Hello')
    #   b = RichText::Delta.new.insert('Hello!')
    #   a.diff(b) # => #<RichText::Delta [retain=5, insert="!"]>
    #   a.compose(a.diff(b)) == b # => true
    def diff(other)
      delta = Delta.new
      return delta if self == other

      iter = Iterator.new(@ops)
      other_iter = Iterator.new(other.ops)

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

      delta.chop!
    end
    alias :- :diff

    # Transform other Delta against own operations, such that [transformation property 1 (TP1)](https://en.wikipedia.org/wiki/Operational_transformation#Convergence_properties) holds:
    #
    #     self.compose(self.transform(other, true)) == other.compose(other.transform(self, false))
    #
    # If called with a number, then acts as an alias for {#transform_position}
    # @param other [Delta, Integer] the Delta to be transformed, or a number to pass along to {#transform_position}
    # @param priority [Boolean] used to break ties; if true, then operations from `self` are seen as having priority over operations from `other`:
    #
    #   - when inserts from `self` and `other` occur at the same index, `other`'s insert is shifted over in order for `self`'s to come first
    #   - retained attributes from `other` can be obsoleted by retained attributes in `self`
    # @example
    #   a = RichText::Delta.new.insert('a')
    #   b = RichText::Delta.new.insert('b')
    #   a.transform(b, true) # => #<RichText::Delta [retain=1, insert="b"]>
    #   a.transform(b, false) # => #<RichText::Delta [insert="b"]>
    #
    #   a = RichText::Delta.new.retain(1, { color: '#bbb' })
    #   b = RichText::Delta.new.retain(1, { color: '#fff', bold: true })
    #   a.transform(b, true) # => #<RichText::Delta [retain=1 {:bold=>true}]>
    #   a.transform(b, false) # => #<RichText::Delta [retain=1 {:color=>"#fff", :bold=>true}]>
    def transform(other, priority)
      return transform_position(other, priority) if other.is_a?(Integer)
      iter = Iterator.new(@ops)
      other_iter = Iterator.new(other.ops)
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
      delta.chop!
    end
    alias :^ :transform

    # Transform an index against the current delta. Useful for shifting cursor & selection positions in response to remote changes.
    # @param index [Integer] an offset position that may be shifted by inserts and deletes happening beforehand
    # @param priority [Boolean] used to break ties
    #
    #   - if true, then an insert happening exactly at `index` does not impact the return value
    #   - if false, then an insert happening exactly at `index` results in the return value being incremented by that insert's length
    # @return [Integer]
    # @example
    #   delta = RichText::Delta.new.retain(3).insert('def')
    #   delta.transform_position(3, true) # => 3
    #   delta.transform_position(3, false) # => 6
    def transform_position(index, priority)
      iter = Iterator.new(@ops)
      offset = 0
      while iter.next? && offset <= index
        op = iter.next
        if op.delete?
          index -= [op.length, index - offset].min
          next
        elsif op.insert? && (offset < index || !priority)
          index += op.length
        end
        offset += op.length
      end
      return index
    end

    # @return [Hash] the Hash representation of this object, by converting each contained op into a Hash
    def to_h
      { :ops => @ops.map(&:to_h) }
    end

    # @return [String] the JSON representation of this object, by delegating to {#to_h}
    def to_json(*args)
      to_h.to_json(*args)
    end

    # Returns a plain text representation of this delta (lossy).
    # The behavior is not defined with non-insert operations.
    # @param embed_str [String] the string to use in place of non-string insert operations
    # @return [String]
    def to_plaintext
      plaintext = @ops.each_with_object('') do |op, str|
        if op.insert?(String)
          str << op.value
        elsif block_given?
          val = yield(op)
          str << val if val.is_a?(String)
        end
      end
      plaintext.strip
    end

    # Returns an HTML representation of this delta.
    # @see {HTML.render}
    # @todo Support options that control how rich-text attributes are converted into HTML tags and attributes.
    def to_html(options = {})
      HTML.render(self, options)
    end

    # Returns a String useful for debugging that includes details of each contained operation.
    # @return [String]
    # @example
    #   '#<RichText::Delta [retain=3, delete=1, insert="abc" {:bold=>true}, insert={:image=>"http://i.imgur.com/vwGN6.gif"}]>'
    def inspect
      str = "#<#{self.class.name} ["
      str << @ops.map { |o| o.inspect(false) }.join(", ")
      str << "]>"
    end

    # A Delta is equal to another if all the ops are equal.
    # @param other [Delta]
    # @return [Boolean]
    def ==(other)
      other.is_a?(RichText::Delta) && @ops == other.ops
    end
    alias_method :eql?, :==
  end
end
