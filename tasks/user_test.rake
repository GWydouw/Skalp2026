# frozen_string_literal: true

desc "Compile Dev + Install Local (with License) + Restart"
task :test_dev do
  puts "🧪 Starting Test Cycle (Compile -> Install with License -> Restart)..."

  # 1. Compile C++ extensions (skipping if no changes ideally, but cmake handles that)
  Rake::Task["dev:cpp"].invoke

  # 2. Set License for install:local
  ENV["LIC"] = "Skalp.lic"

  # 3. Running install:local triggers 'skp:kill' -> install -> 'skp:open'
  Rake::Task["install:local"].invoke
end
