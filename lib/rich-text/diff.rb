require 'diff-lcs'

module RichText
  # @api private
  class Diff
    attr_reader :chunks

    def initialize(left, right)
      @chunks = []
      ::Diff::LCS.traverse_sequences(left.to_plaintext, right.to_plaintext, self)
      @chunks.each { |c| yield c } if block_given?
    end

    def push(type)
      if @chunks.any? && @chunks[-1][0] == type
        @chunks[-1][1] += 1
      else
        @chunks.push [type, 1]
      end
    end

    def match(args)
      push :retain
    end

    def discard_a(args)
      push :delete
    end

    def discard_b(args)
      push :insert
    end
  end
end
