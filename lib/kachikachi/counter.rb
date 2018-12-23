require 'kachikachi/github'

module Kachikachi
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
end
