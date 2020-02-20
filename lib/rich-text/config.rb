module RichText
  # @api private
  class Config
    attr_accessor :safe_mode, :html_default_block_tag, :html_sibling_merge_tags,
                  :html_block_tags, :html_inline_tags, :html_object_tags
  end
end
