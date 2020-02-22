module RichText
  # @api private
  class Config
    attr_accessor :safe_mode,
      :html_default_block_format,
      :html_block_formats,
      :html_inline_formats,
      :html_object_formats
  end
end
