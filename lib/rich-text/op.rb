module RichText
  class Op
    include Comparable

    TYPES = [:insert, :retain, :delete]
    EMBED_CHAR = '!'

    attr_reader :type, :value, :attributes

    def initialize(type, value, attributes = nil)
      if !TYPES.include?(type)
        raise ArgumentError.new("#{type} is not a valid op type")
      end

      if [:retain, :delete].include?(type) && !value.is_a?(Numeric)
        raise ArgumentError.new("value must be a number when type is #{type}")
      end

      @type = type
      @value = value.freeze
      @attributes = attributes.freeze
    end

    def attributes?
      !attributes.nil? && !attributes.empty?
    end

    def insert?(kind = Object)
      type == :insert && value.is_a?(kind)
    end

    def retain?
      type == :retain
    end

    def delete?
      type == :delete
    end

    def length
      case type
      when :insert
        value.is_a?(String) ? value.length : 1
      when :retain, :delete
        value
      end
    end

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

    def as_json
      { type => value }.tap do |json|
        json[:attributes] = attributes if attributes?
      end
    end

    def to_json(*)
      as_json.to_json
    end

    def inspect(wrap = true)
      str = "#{type}=#{value.inspect}"
      str << " #{attributes.inspect}" if attributes?
      wrap ? "#<#{self.class.name} #{str}>" : str
    end
    alias :to_s :inspect

    def ==(other)
      type == other.type && value == other.value && attributes == other.attributes
    end

    def <=>(other)
      value <=> other.value if type == other.type
    end
  end
end
