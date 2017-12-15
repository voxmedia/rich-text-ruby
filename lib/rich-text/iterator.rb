module RichText
  class Iterator
    def initialize(ops)
      @ops = ops
      reset
    end

    def each(size = 1)
      return enum_for(:each, size) unless block_given?
      yield self.next(size) while next?
    end

    def peek
      if op = @ops[@index]
        op.slice(@offset)
      else
        Op.new(:retain, Float::INFINITY)
      end
    end

    def next?
      peek.length < Float::INFINITY
    end

    def next(length = Float::INFINITY)
      next_op = @ops[@index]
      offset = @offset
      if next_op
        if length >= next_op.length - offset
          length = next_op.length - offset
          @index += 1
          @offset = 0
        else
          @offset += length
        end

        next_op.slice(offset, length)
      else
        return Op.new(:retain, Float::INFINITY)
      end
    end

    def reset
      @index = 0
      @offset = 0
    end
  end
end
