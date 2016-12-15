module RichText
  class Op
    TYPES = [:insert, :retain, :delete]
    EMBED_CHAR = '!'
    InvalidType = Class.new(StandardError)

    attr_accessor :attributes

    def initialize(type, arg, attributes = nil)
      raise InvalidType.new(type) unless TYPES.include?(type)

      @type = type
      @arg = arg
      @attributes = attributes
    end

    def insert?(kind = Object)
      @type == :insert && @arg.is_a?(Object)
    end

    def retain?
      @type == :retain
    end

    def delete?
      @type == :delete
    end

    def attributes?
      !@attributes.nil? && !@attributes.empty?
    end

    def insert
      if @type == :insert
        @arg
      else
        raise InvalidType.new(@type)
      end
    end

    def length
      case @type
      when :insert
        @arg.is_a?(String) ? @arg.length : 1
      when :retain, :delete
        @arg
      end
    end

    def slice(start = 0, len = length)
      if start.is_a?(Range)
        len = start.size
        start = start.first
      end

      if insert?(String)
        Op.new(:insert, @arg.slice(start, len), @attributes)
      elsif insert?
        unless start == 0 && len == 1
          raise ArgumentError.new("cannot subdivide a non-string insert")
        end
        dup
      else
        Op.new(@type, [@arg - start, len].min, @attributes)
      end
    end
    alias_method :[], :slice

    def as_json
      { @type => @arg }.tap do |json|
        json[:attributes] = @attributes if attributes?
      end
    end

    def to_json(*)
      as_json.to_json
    end

    def to_s
      if insert?(String)
        @arg
      elsif insert?
        EMBED_CHAR
      else
        raise InvalidType.new
      end
    end

    def inspect
      "#<#{self.class.name} #{@type}=#{@arg.inspect}".tap do |str|
        str << " #{@attributes.inspect}" if attributes?
        str << ">"
      end
    end
  end
end
