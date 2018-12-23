require 'kachikachi/patch_body'

module Kachikachi
  class Patch
    attr_accessor :file_name, :body

    def initialize(file_name, content, options)
      @file_name = file_name || ''
      @body = PatchBody.new(content, options)
    end
  end
end
