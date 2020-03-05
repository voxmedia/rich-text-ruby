module RichText
  # @api private
  class Config
    attr_accessor :safe_mode, :html_inline_formats, :html_block_formats, :html_default_block_format
  end
end
