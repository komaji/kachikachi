require 'octokit'

GITHUB_API_TOKEN=ENV['GITHUB_API_TOKEN']
GITHUB_REPO='komaji/test_danger'
GITHUB_MILESTONE='v1.0.0'
TARGET_FILE_REGEXP=/^.*\.(m|h)/
TARGET_PULL_REQUEST_NUMBERS=nil
PULL_REQUEST_STATE='closed'
IGNORE_WHITE_SPACE=false

class Patch
  attr_accessor :file_name, :body

  def initialize(file_name, body)
    @file_name = file_name || ''
    @body = PatchBody.new(body)
  end
end

class PatchBody
  attr_accessor :body

  def initialize(body)
    @body = body || ''
  end

  def only_removed
    patch = ignore_unmodified_lines
      .ignore_added_lines
    patch.ignore_white_space if IGNORE_WHITE_SPACE
    patch
  end

  def ignore_unmodified_lines
    PatchBody.new(@body.gsub(/^\s.*(\n|\r\n|\r)/, ''))
  end

  def ignore_added_lines
    PatchBody.new(@body.gsub(/^\+.*(\n|\r\n|\r)/, ''))
  end

  def ignore_white_space
    PatchBody.new(@body.gsub(/^(-|\+)\s*(\n|\r\n|\r)/, ''))
  end
end

def client
  Octokit::Client.new(access_token: GITHUB_API_TOKEN, auto_paginate: true)
end

def user_name
  client.user.login
end

def pull_requests
  client.pull_requests(GITHUB_REPO, state: PULL_REQUEST_STATE).select do |pr|
    !GITHUB_MILESTONE || pr.milestone&.title == GITHUB_MILESTONE &&
      pr.user.login == user_name
  end
end

def pull_requests_numbers
  TARGET_PULL_REQUEST_NUMBERS || pull_requests.map(&:number)
end

def pull_request_diff(number)
  client.pull_request(GITHUB_REPO, number, accept: 'application/vnd.github.v3.diff')
end

def pull_request_patch_list(pr_diff)
  patch_body = ''
  patch_list = []
  patch_file_name = ''
  body = false
  lines = pr_diff.lines

  lines.each_with_index do |line, index|
    case line
    when /^diff\s--git\sa\/(?<file_name>.*)\sb\//
      unless patch_body.empty?
        patch_list << Patch.new(patch_file_name, patch_body)
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
      patch_list << Patch.new(patch_file_name, patch_body) if last_line && !patch_body.empty?
    end
  end

  patch_list
end

def all_pull_requests_patch_list
  pull_requests_numbers
    .map(&method(:pull_request_diff))
    .map(&method(:pull_request_patch_list))
    .flatten
end

removed_patches_total_count = all_pull_requests_patch_list
                          .select{ |p| puts p.file_name;p.file_name =~ TARGET_FILE_REGEXP }
                          .map(&:body)
                          .map(&:only_removed)
                          .map(&:body)
                          .join
                          .lines.count
puts "👋👋👋 #{removed_patches_total_count} lines 👋👋👋"
