# frozen_string_literal: true

require "sketchup"

module Skalp
  # Called by Skalp_Skalp2026.rb when DEV_MODE is active
  def self.load_development_mode
    puts ">>> [Skalp Check] Skalp.load_development_mode called from #{__FILE__}"
    
    # In Dev Mode, we need to explicitly load the main loader because the standard loader skipped it
    # We load it from the Plugins directory where it was deployed by rake install:local
    loader_path = File.join(File.dirname(__FILE__), "Skalp_loader.rb")
    
    if File.exist?(loader_path)
      puts ">>> Loading Skalp from: #{loader_path}"
      require loader_path
    else
      # If not found in current dir, try one level up (if dev_loader is inside Skalp_Skalp2026)
      puts ">>> [Warn] Skalp_loader.rb not found in #{File.dirname(__FILE__)}"
    end
  end

  module DebugLoader
    def self.run
      UI.start_timer(1.0, false) do
        SKETCHUP_CONSOLE.show
        puts "[Skalp DebugLoader] 🚀 System Ready."
      end
    end
  end
end

Skalp::DebugLoader.run
