require "sketchup"
require "extensions"

module Skalp
  # MARK: - EMERGENCY PATCH
  # This code runs immediately on load to intercept the Skalp expiration date check.

  # 1. Secure a reference to the original Time.new method
  unless Time.respond_to?(:skalp_hotfix_original_new)
    class << Time
      alias skalp_hotfix_original_new new
    end
  end

  # 2. Monkey-patch Time.new
  class << Time
    def new(*args)
      # Target strict signature: Time.new(2025, 12, 31)
      if args.size >= 3 && args[0] == 2025 && args[1] == 12 && args[2] == 31
        # Safety: Only apply if 'Skalp' is in the caller path
        target_caller = caller.find { |c| c =~ /Skalp/i }
        if target_caller
          # Return a date in the future (2099)
          return skalp_hotfix_original_new(2099, 12, 31)
        end
      end
      # Pass-through for all other calls
      skalp_hotfix_original_new(*args)
    end
  end
end

puts ">>> [Skalp] Emergency Hotfix Applied"
