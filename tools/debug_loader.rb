# frozen_string_literal: true

require "sketchup"

module Skalp
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
