# frozen_string_literal: true

# SketchUp lifecycle management tasks

namespace :skp do
  desc "Kill running SketchUp processes"
  task :kill do
    puts "🔪 Nuking SketchUp..."

    if OS.mac?
      year = Config::SKETCHUP_YEAR
      puts "🔫 Targeting SketchUp #{year} processes..."

      # Find PIDs running from the specific year's application path
      # Uses pgrep -f to match the command line which typically contains the full path
      # e.g. /Applications/SketchUp 2026/SketchUp.app
      pids = `pgrep -f "SketchUp #{year}"`.split("\n")

      if pids.empty?
        puts "🤷 No SketchUp #{year} processes found."
      else
        pids.each do |pid|
          puts "   💥 Killing PID #{pid}..."
          sh "kill -9 #{pid} 2>/dev/null || true"
        end
        puts "⏳ Waiting for termination..."
        sleep 2 # Give it a moment to die
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
