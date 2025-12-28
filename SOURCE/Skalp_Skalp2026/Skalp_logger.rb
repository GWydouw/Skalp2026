module Skalp
  module DebugLogger
    # Path shared with Antigravity for real-time logging
    LOG_FILE_PATH = File.join(Dir.home, ".gemini", "antigravity", "scratch", "skalp_debug.log")

    def self.log(message, severity = "INFO")
      # Only log in DEV_MODE or if explicitly enabled
      return unless defined?(Skalp::DEV_MODE) && Skalp::DEV_MODE

      timestamp = Time.now.strftime("%Y-%m-%d %H:%M:%S")

      # Ensure directory exists
      dir = File.dirname(LOG_FILE_PATH)
      Dir.mkdir(dir) unless File.directory?(dir)

      File.open(LOG_FILE_PATH, "a") do |f|
        f.puts("[#{timestamp}] [#{severity}] #{message}")
        f.flush # Ensure immediate write for Antigravity to pick up
      end
    rescue StandardError => e
      # Fallback to console if file writing fails, but keeping it minimal
      puts "Skalp::DebugLogger Error: #{e.message}"
    end

    def self.clear
      return unless defined?(Skalp::DEV_MODE) && Skalp::DEV_MODE

      # Ensure directory exists
      dir = File.dirname(LOG_FILE_PATH)
      Dir.mkdir(dir) unless File.directory?(dir)

      File.write(LOG_FILE_PATH, "")
      log("Log file cleared. Logging started.")
    rescue StandardError
      # Ignore errors during clear
    end
  end

  # Convenience method
  def self.debug_log(message)
    DebugLogger.log(message.to_s)
  end
end
