require 'octokit'

GITHUB_API_TOKEN=ENV['GITHUB_API_TOKEN']
GITHUB_REPO='komaji/test_danger'
GITHUB_MILESTONE='v1.0.0'

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

def pull_request_diffs
  pull_requests.map(&:number).map(&method(:pull_request_diff))
end

puts pull_request_diffs
