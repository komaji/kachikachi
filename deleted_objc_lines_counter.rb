require 'octokit'
require 'thor'

class CLI < Thor
  desc 'count', 'Count removed code lines.'
  option 'endpoint', default: ENV['GITHUB_API_ENDPOINT'] || 'https://api.github.com/'
  option 'token', default: ENV['GITHUB_API_TOKEN']
  option 'repo', required: true
  option 'file-regexp'
  option 'milestone'
  option 'pull-request-numbers', type: :array
  option 'state', default: :closed
  option 'ignore-white-space', type: :boolean, default: true
  def count
    options[:milestone] || options['pull-request-numbers'] or raise 'Need to specify milestone or pull request numbers. Please use --milestone or --pull-request-numbers options.'
    Counter.new(self).count
  end
end

class Counter
  def initialize(cli)
    @cli = cli
  end

  def count
    all_target_patch_list = GitHub.new(@cli.options).pull_requests
                              .map(&:target_patch_list)
                              .flatten
    removed_patches_total_count = all_target_patch_list
                                    .map(&:body)
                                    .map(&:only_removed)
                                    .map(&:body)
                                    .join
                                    .lines
                                    .count

    puts "👋👋👋 #{removed_patches_total_count} lines 👋👋👋"
  end
end

class GitHub
  attr_accessor :client

  def initialize(options)
    @options = options
  end

  def pull_requests
    prs = client.pull_requests(@options[:repo], state: @options[:state]).select do |pr|
      (!@options[:milestone] || pr.milestone&.title == @options[:milestone]) &&
        (!@options['pull-request-numbers'] || @options['pull-request-numbers'].map(&:to_i).include?(pr.number)) &&
        pr.user.login == user_name
    end

    prs.map{ |pr| PullRequest.new(pr, @options) }
  end

  def user_name
    client.user.login
  end

  private
  def client
    Octokit.configure do |c|
      c.api_endpoint = @options['endpoint']
    end

    @client ||= Octokit::Client.new(access_token: @options[:token], auto_paginate: true)
  end
end

class PullRequest
  attr_accessor :content, :client

  def initialize(content, options)
    @content = content
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

  def number
    content.number
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

  def initialize(file_name, body, options)
    @file_name = file_name || ''
    @body = PatchBody.new(body, options)
  end
end

class PatchBody
  attr_accessor :body

  def initialize(body, options)
    @body = body || ''
    @options = options
  end

  def only_removed
    patch = ignore_unmodified_lines
      .ignore_added_lines
    patch = patch.ignore_white_space if @options['ignore-white-space']

    patch
  end

  def ignore_unmodified_lines
    PatchBody.new(@body.gsub(/^\s.*(\n|\r\n|\r)/, ''), @options)
  end

  def ignore_added_lines
    PatchBody.new(@body.gsub(/^\+.*(\n|\r\n|\r)/, ''), @options)
  end

  def ignore_white_space
    PatchBody.new(@body.gsub(/^(-|\+)\s*(\n|\r\n|\r)/, ''), @options)
  end
end

CLI.start(ARGV)
