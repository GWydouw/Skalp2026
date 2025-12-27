# frozen_string_literal: true

# Web frontend build tasks

namespace :web do
  desc "Build Vue frontend"
  task :build do
    # Smart Install: Ensure npm dependencies exist
    unless File.directory?(File.join(Config::WEB_DIR, "node_modules"))
      puts "📦 Installing web dependencies..."
      run_cmd "cd \"#{Config::WEB_DIR}\" && npm install"
    end

    # Force arm64 execution on macOS (local dev) to avoid Rosetta issues
    # On CI (Linux), run standard command
    cmd_prefix = /darwin/ =~ RUBY_PLATFORM ? "arch -arm64" : ""
    run_cmd "#{cmd_prefix} sh -c 'cd \"#{Config::WEB_DIR}\" && npx vite build'"
  end
end
