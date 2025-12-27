# frozen_string_literal: true

module Skalp
  module Debug
    @enabled = true

    def self.enabled?
      @enabled
    end

    def self.enable!
      @enabled = true
    end

    def self.disable!
      @enabled = false
    end

    def self.log_file_path
      unless defined?(Skalp::DebugConfig::PROJECT_ROOT) && Skalp::DebugConfig::PROJECT_ROOT
        return nil
      end

      path = File.join(Skalp::DebugConfig::PROJECT_ROOT, "test_logs")
      Dir.mkdir(path) unless Dir.exist?(path)
      
      File.join(path, "ui_debug.log")
    end

    def self.log(msg)
      puts "[Skalp Debug] #{msg}"

      path = log_file_path
      return unless path

      File.open(path, "a") do |f|
        f.puts "[#{Time.now.strftime('%H:%M:%S')}] #{msg}"
      end
    rescue StandardError => e
      puts "Log Error: #{e}"
    end
  end
end
