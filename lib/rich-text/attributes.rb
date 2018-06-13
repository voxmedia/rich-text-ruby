module RichText
  # @api private
  module Attributes
    class << self
      def compose(a, b, keep_nil)
        return b if a.nil?
        return a if b.nil?
        result = b.merge(a) { |k,vb,va| vb }
        result.delete_if { |k,v| v.nil? } unless keep_nil
        result
      end

      def diff(a, b)
        return b if a.nil?
        return a if b.nil?
        (a.keys | b.keys).each_with_object({}) do |key, memo|
          memo[key] = b[key] if a[key] != b[key]
        end
      end

      def transform(a, b, priority)
        return b if a.nil? || a.empty? || b.nil? || b.empty? || !priority
        (b.keys - a.keys).each_with_object({}) do |key, memo|
          memo[key] = b[key]
        end
      end
    end
  end
end
