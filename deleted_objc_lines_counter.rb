require 'octokit'

GITHUB_API_TOKEN=ENV['GITHUB_API_TOKEN']
GITHUB_REPO='komaji/test_danger'
GITHUB_MILESTONE='v1.0.0'

class Patch
  attr_accessor :file_name, :body

  def initialize(file_name, body)
    @file_name = file_name || ''
    @body = body || ''
  end
end

def client
  Octokit::Client.new(access_token: GITHUB_API_TOKEN, auto_paginate: true)
end

def milestone_number
  milestones = client.list_milestones(GITHUB_REPO).find do |milestone|
    milestone.title == GITHUB_MILESTONE
  end
  milestones.number
end

def user_name
  client.user.login
end

def pull_requests
  client.pull_requests(GITHUB_REPO, state: 'all').select do |pr|
    pr.milestone&.title == GITHUB_MILESTONE && pr.user.login == user_name
  end
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
  pull_requests
    .map(&:number)
    .map(&method(:pull_request_diff))
    .map(&method(:pull_request_patch_list))
    .flatten
end

def remove_unmodified_lines(pr_patch)
  pr_patch.gsub(/^\s.*(\n|\r\n|\r)/, '')
end

def remove_added_lines(pr_patch)
  pr_patch.gsub(/^\+.*(\n|\r\n|\r)/, '')
end

def remove_white_space(pr_patch)
  pr_patch.gsub(/^(-|\+)\s*(\n|\r\n|\r)/, '')
end

def only_removed_patch(pr_patch)
  remove_added_lines(remove_unmodified_lines(remove_white_space(pr_patch)))
end

puts "👋👋👋 #{only_removed_patch(all_pull_requests_patch_list.map(&:body).join("\n")).lines.count} lines 👋👋👋"
