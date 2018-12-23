require 'octokit'
require 'thor'

class CLI < Thor
  desc 'count', 'Count removed code lines.'
  option 'endpoint', default: ENV['GITHUB_API_ENDPOINT'] || 'https://api.github.com/'
  option 'token', default: ENV['GITHUB_API_TOKEN']
  option 'repo', required: true
  option 'file-regexp'
  option 'milestones', type: :array
  option 'pull-request-numbers', type: :array
  option 'state', default: :closed
  option 'ignore-white-space', type: :boolean, default: true
  option 'ignore-comment-regexp'
  option 'user'
  
  def count
    @options[:milestones] || @options['pull-request-numbers'] or raise 'Need to specify milestones or pull request numbers. Please use --milestones or --pull-request-numbers options.'
    Counter.new(self).count
  end
end

class Counter
  def initialize(cli)
    @cli = cli
  end

  def count
    target_patch_list = GitHub.new(@cli.options).pull_requests.map(&:target_patch_list).flatten
    
    lines_count_list = []
    target_patch_list.map { |patch|
      lines_count = patch.body.only_removed.content.lines.count
      lines_count_list << lines_count
      puts "#{patch.file_name}: deleted #{lines_count} lines" unless lines_count.zero?
    }

    total_lines_count = lines_count_list.inject(0, :+)
    
    puts "👋👋👋 total #{total_lines_count} lines 👋👋👋"
  end
end

class GitHub
  attr_accessor :client

  def initialize(options)
    @options = options
  end

  def pull_requests
    pull_request_numbers = @options['pull-request-numbers']
    return pull_request_numbers.map { |number| PullRequest.new(number, @options) } if pull_request_numbers
    
    options = {
      state: @options[:state]
    }
    options[:creator] = @options[:user] if @options[:user]

    prs = milestone_numbers.map { |number|
      options[:milestone] = number
      client.list_issues(@options[:repo], options).select(&:pull_request)
    }.flatten

    prs.map{ |pr| PullRequest.new(pr.number, @options) }
  end

  private
  def milestone_numbers
    client.list_milestones(@options[:repo], state: :all).select{ |milestone|
      @options[:milestones].include?(milestone.title)
    }.map(&:number)
  end

  def client
    Octokit.configure do |c|
      c.api_endpoint = @options['endpoint']
    end

    @client ||= Octokit::Client.new(access_token: @options[:token], auto_paginate: true)
  end
end

class PullRequest
  attr_accessor :number, :client

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

  def diff
    client.pull_request(@options[:repo], number, accept: 'application/vnd.github.v3.diff')
  end

  private
  def client
    Octokit.configure do |c|
      c.api_endpoint = @options['endpoint']
    end

    @client ||= Octokit::Client.new(access_token: @options['token'], auto_paginate: true)
  end
end

class Patch
  attr_accessor :file_name, :body

  def initialize(file_name, content, options)
    @file_name = file_name || ''
    @body = PatchBody.new(content, options)
  end
end

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

CLI.start(ARGV)
