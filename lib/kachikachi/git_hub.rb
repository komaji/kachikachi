require 'octokit'
require 'kachikachi/pull_request'

module Kachikachi
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

      issues = milestone_numbers.map { |number|
        options[:milestone] = number
        client.list_issues(@options[:repo], options).select(&:pull_request)
      }.flatten

      issues.map{ |issue| PullRequest.new(issue.number, @options) }.select{ |pr| pr.base.ref == @options['base-branch'] }
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

end
