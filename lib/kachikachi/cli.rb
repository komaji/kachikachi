require 'thor'
require 'counter'

module KachiKachi
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
    option 'base-branch'
    option 'user'
    
    def count
      @options[:milestones] || @options['pull-request-numbers'] or raise 'Need to specify milestones or pull request numbers. Please use --milestones or --pull-request-numbers options.'
      Counter.new(self).count
    end
  end
end
