module Kachikachi
  class PatchBody
    attr_accessor :content

    def initialize(content, options)
      @content = content || ''
      @options = options
    end

    def only_removed
      patch = ignore_unmodified_lines
                .ignore_added_lines
      patch = patch.ignore_white_space if @options['ignore-white-space']
      pattern = @options['ignore-comment-regexp']
      patch = patch.ignore_comment_lines(pattern) if pattern

      patch
    end

    def ignore_unmodified_lines
      PatchBody.new(@content.gsub(/^\s.*(\n|\r\n|\r)/, ''), @options)
    end

    def ignore_added_lines
      PatchBody.new(@content.gsub(/^\+.*(\n|\r\n|\r)/, ''), @options)
    end

    def ignore_white_space
      PatchBody.new(@content.gsub(/^(-|\+)\s*(\n|\r\n|\r)/, ''), @options)
    end

    def ignore_comment_lines(pattern)
      comment_line_regexp = Regexp.new("^[-+]?\s*#{pattern}.*(\n|\r\n|\r)")
      PatchBody.new(@content.gsub(comment_line_regexp, ''), @options)
    end
  end
end
