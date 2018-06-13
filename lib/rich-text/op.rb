require 'active_support/core_ext/hash/indifferent_access'

module RichText
  # Operations are the immutable units of rich-text deltas and documents. As such, we have a class that wraps these values and provides convenient methods for querying type and contents, and for subdividing as needed by {Delta#slice}.
  class Op
    TYPES = [:insert, :retain, :delete].freeze

    # @return [Symbol] one of {TYPES}
    attr_reader :type
    # @return [String, Integer, Hash] value depends on type
    attr_reader :value
    # @return [Hash]
    attr_reader :attributes

    # Creates a new Op object from a Hash. Used by {Delta#initialize} to parse raw data into a convenient form.
    # @param data [Hash] containing exactly one of {TYPES} as a key, and optionally an `:attributes` key. munged to provide indifferent access via String or Symbol keys
    # @return [Op]
    # @raise [ArgumentError] if `data` contains invalid keys, i.e. zero or more than one of {TYPES}
    # @example
    #   RichText::Op.parse({ insert: 'abc', attributes: { bold: true } })
    #   # => #<RichText::Op insert="abc" {"bold"=>true}>
    #
    #   RichText::Op.parse({ insert: 'abc', retain: 3 })
    #   # => ArgumentError: must be a Hash containing exactly one of the following keys: [:insert, :retain, :delete]
    def self.parse(data)
      data = data.to_h.with_indifferent_access
      type_keys = (data.keys & TYPES.map(&:to_s))
      if type_keys.length != 1
        raise ArgumentError.new("must be a Hash containing exactly one of the following keys: #{TYPES.inspect}")
      end

      type = type_keys.first.to_sym
      value = data[type]
      if [:retain, :delete].include?(type) && !value.is_a?(Integer)
        raise ArgumentError.new("value must be an Integer when type is #{type.inspect}")
      end

      attributes = data[:attributes]
      if attributes && !attributes.is_a?(Hash)
        raise ArgumentError.new("attributes must be a Hash")
      end

      self.new(type, value, attributes)
    end

    # Creates a new Op object, based on a type, value, and attributes. No sanity checking is performed on the arguments; please use {Op.parse} for dealing with untrusted user input.
    # @param type [Symbol] one of {TYPES}
    # @param value [Integer, String, Hash] various values corresponding to type
    # @param attributes [Hash]
    # @return [Op]
    def initialize(type, value, attributes = nil)
      @type = type.to_sym
      @value = value.freeze
      @attributes = (attributes || {}).freeze
    end

    # @return [Boolean] whether any attributes are present; `false` when attributes is empty, `true` otherwise.
    # @example
    #   RichText::Op.new(:insert, 'abc').attributes? # => false
    #   RichText::Op.new(:insert, 'abc', {}).attributes? # => false
    #   RichText::Op.new(:insert, 'abc', { bold: true }).attributes? # => true
    def attributes?
      !attributes.empty?
    end

    # Returns whether type is `:insert`, and value is an instance of `kind`
    # @param kind [Class] pass a class to perform an additional `is_a?` check on {value}
    # @return [Boolean]
    # @example
    #   RichText::Op.new(:insert, 'abc').insert? # => true
    #   RichText::Op.new(:insert, 'abc').insert?(String) # => true
    #   RichText::Op.new(:insert, { image: 'http://i.imgur.com/y6Eo48A.gif' }).insert?(String) # => false
    def insert?(kind = Object)
      type == :insert && value.is_a?(kind)
    end

    # Returns whether type is `:retain` or not
    # @return [Boolean]
    def retain?
      type == :retain
    end

    # Returns whether type is `:delete` or not
    # @returns [Boolean]
    def delete?
      type == :delete
    end

    # Returns a number indicating the length of this op, depending of the type:
    #
    # - for `:insert`, returns `value.length` if a String, 1 otherwise
    # - for `:retain` and `:delete`, returns value
    # @return [Integer]
    def length
      case type
      when :insert
        value.is_a?(String) ? value.length : 1
      when :retain, :delete
        value
      end
    end

    # Returns a copy of the op with a subset of the value, measured in number of characters.
    # An op may be subdivided if needed to return at most the requested length. Non-string inserts cannot be subdivided (naturally, as they have length 1).
    # @param start [Integer] starting offset
    # @param len [Integer] how many characters
    # @return [Op] whose length is at most `len`
    def slice(start = 0, len = length)
      if insert?(String)
        Op.new(:insert, value.slice(start, len), attributes)
      elsif insert?
        unless start == 0 && len == 1
          raise ArgumentError.new("cannot subdivide a non-string insert")
        end
        dup
      else
        Op.new(type, [value - start, len].min, attributes)
      end
    end

    # @return [Hash] the Hash representation of this object, the inverse of {Op.parse}
    def to_h
      { type => value }.tap do |json|
        json[:attributes] = attributes if attributes?
      end
    end

    # @return [String] the JSON representation of this object, by delegating to {#to_h}
    def to_json(*args)
      to_h.to_json(*args)
    end

    # A string useful for debugging, that includes type, value, and attributes.
    # @param wrap [Boolean] pass false to avoid including the class name (used by {Delta#inspect})
    # @return [String]
    # @example
    #   RichText::Op.new(:insert, 'abc', { bold: true }).inspect # => '#<RichText::Op insert="abc" {:bold=>true}>'
    #   RichText::Op.new(:insert, 'abc', { bold: true }).inspect(false) => 'insert="abc" {:bold=>true}'
    def inspect(wrap = true)
      str = "#{type}=#{value.inspect}"
      str << " #{attributes.inspect}" if attributes?
      wrap ? "#<#{self.class.name} #{str}>" : str
    end

    # An Op is equal to another if type, value, and attributes all match
    # @param other [Op]
    # @return [Boolean]
    def ==(other)
      other.is_a?(Op) && type == other.type && value == other.value && attributes == other.attributes
    end
    alias :eql? :==
  end
end
