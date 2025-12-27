# frozen_string_literal: true

# SketchUp lifecycle management tasks

namespace :skp do
  desc "Kill running SketchUp processes"
  task :kill do
    puts "🔪 Nuking SketchUp..."

    if OS.mac?
      sh "killall -9 'SketchUp' 2>/dev/null || true"

      # Wait for death
      puts "⏳ Waiting for termination..."
      start = Time.now
      while `pgrep -x 'SketchUp'`.strip.length > 0
        sleep 0.2
        break if Time.now - start > 5 # Timeout
      end
    elsif OS.windows?
      sh "taskkill /F /IM SketchUp.exe 2>nul || exit 0"
    end

    # Cleanup injected SHA if it exists (End of session cleanup)
    Rake::Task["test:cleanup_sha"].invoke if Rake::Task.task_defined?("test:cleanup_sha")

    puts "💀 SketchUp is dead."
  end

  desc "Launch SketchUp #{Config::SKETCHUP_YEAR}"
  task :open do
    puts "💎 Launching SketchUp #{Config::SKETCHUP_YEAR}..."
    app_path = Config::SKETCHUP_APP

    unless File.exist?(app_path)
      puts "❌ SketchUp executable not found at: #{app_path}"
      puts "   Tip: Set SKETCHUP_PATH environment variable to override."
      next
    end

    Bundler.with_unbundled_env do
      if OS.mac?
        sh "open '#{app_path}'"
      elsif OS.windows?
        sh "start \"\" \"#{app_path}\""
      else
        sh "'#{app_path}'"
      end
    end
  end
end
