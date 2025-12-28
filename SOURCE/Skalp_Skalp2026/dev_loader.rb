module Skalp
  def self.load_development_mode
    puts ">>> Skalp Development Mode Loaded"
    require_relative "Skalp_loader"
  end
end
