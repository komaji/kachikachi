require 'octokit'
require 'kachikachi/patch'

module Kachikachi
  class PullRequest
    attr_accessor :number, :client, :content, :diff

    def initialize(number, options)
      @number = number
      @options = options
    end

    def target_patch_list
      patch_list.select do |patch|
        !@options['file-regexp'] || patch.file_name =~ Regexp.new(@options['file-regexp'])
      end
    end

    def patch_list
      patch_body = ''
      patch_list = []
      patch_file_name = ''
      body = false
      lines = diff.lines

      lines.each_with_index do |line, index|
        case line
        when /^diff\s--git\sa\/(?<file_name>.*)\sb\//
          unless patch_body.empty?
            patch_list << Patch.new(patch_file_name, patch_body, @options)
            patch_body = ''
          end

          patch_file_name = Regexp.last_match[:file_name]
          body = false
        when /^@@\s-\d+,\d+\s\+\d+,\d+\s@@/
          body = true
        else
          next unless body

          patch_body << line
          last_line = lines.count == index + 1
          patch_list << Patch.new(patch_file_name, patch_body, @options) if last_line && !patch_body.empty?
        end
      end

      patch_list
    end

    def base
      content.base
    end

    private
    def diff
      @diff ||= client.pull_request(@options[:repo], number, accept: 'application/vnd.github.v3.diff')
    end

    def content
      @content ||= client.pull_request(@options[:repo], number)
    end

    def client
      Octokit.configure do |c|
        c.api_endpoint = @options['endpoint']
      end

      @client ||= Octokit::Client.new(access_token: @options['token'], auto_paginate: true)
    end
  end
end
