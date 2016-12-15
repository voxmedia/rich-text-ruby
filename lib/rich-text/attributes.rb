module RichText
  module Attributes
    class << self
      def compose(a, b, keep_nil)
        a ||= {}
        b ||= {}
        result = b.merge(a)
        result.delete_if { |k,v| v.nil? } unless keep_nil
        result.empty? ? nil : result
      end

      def diff(a, b)
      end

      def transform(a, b)
      end
    end
  end
end
