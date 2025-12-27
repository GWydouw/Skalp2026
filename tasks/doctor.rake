# frozen_string_literal: true

# Development environment diagnostic and setup tasks

module DoctorHelpers
  REQUIRED_RUBY_VERSION = "3.2"
  REQUIRED_NODE_VERSION = "18"

  # Check if a command exists and return version output
  def self.check_command(cmd, version_flag = "--version")
    output = `#{cmd} #{version_flag} 2>&1`
    if $?.success?
      [true, output.strip]
    else
      [false, nil]
    end
  end

  # Parse version number from version output string
  def self.parse_version(output)
    output&.match(/\d+\.\d+(\.\d+)?/)&.to_s
  end

  # Check if version meets minimum requirement
  def self.version_meets_requirement?(version, required)
    return false unless version

    Gem::Version.new(version.split(".")[0..1].join(".")) >= Gem::Version.new(required)
  end

  # Print colorized status
  def self.status(success, message)
    icon = success ? "✅" : "❌"
    puts "  #{icon} #{message}"
    success
  end

  # Print warning status
  def self.warn(message)
    puts "  ⚠️  #{message}"
  end
end

namespace :doctor do
  desc "Check development environment (silent, for CI)"
  task :check do
    all_ok = true

    # Ruby check
    ruby_ok, ruby_out = DoctorHelpers.check_command("ruby", "-v")
    ruby_version = DoctorHelpers.parse_version(ruby_out)
    ruby_meets = DoctorHelpers.version_meets_requirement?(ruby_version, DoctorHelpers::REQUIRED_RUBY_VERSION)
    all_ok &&= ruby_ok && ruby_meets

    # Bundle check
    bundle_ok = system("bundle check > /dev/null 2>&1")
    all_ok &&= bundle_ok

    # Node check
    node_ok, node_out = DoctorHelpers.check_command("node", "-v")
    node_version = DoctorHelpers.parse_version(node_out)
    node_meets = DoctorHelpers.version_meets_requirement?(node_version, DoctorHelpers::REQUIRED_NODE_VERSION)
    all_ok &&= node_ok && node_meets

    # npm check
    npm_ok, = DoctorHelpers.check_command("npm", "-v")
    all_ok &&= npm_ok

    # Web dependencies check
    node_modules_path = File.join(Config::WEB_DIR, "node_modules")
    web_deps_ok = File.directory?(node_modules_path)
    all_ok &&= web_deps_ok

    abort "❌ Environment check failed. Run 'rake doctor' for details." unless all_ok
  end
end

desc "Diagnose development environment"
task :doctor do
  puts "\n🔍 Checking Development Environment...\n\n"

  all_ok = true
  issues = []

  # ============================================================================
  # RUBY
  # ============================================================================
  puts "[Ruby]"
  ruby_ok, ruby_out = DoctorHelpers.check_command("ruby", "-v")
  ruby_version = DoctorHelpers.parse_version(ruby_out)

  if ruby_ok
    ruby_meets = DoctorHelpers.version_meets_requirement?(ruby_version, DoctorHelpers::REQUIRED_RUBY_VERSION)
    if ruby_meets
      DoctorHelpers.status(true, "Ruby #{ruby_version} (required: #{DoctorHelpers::REQUIRED_RUBY_VERSION}+)")
    else
      DoctorHelpers.status(false, "Ruby #{ruby_version} is too old (required: #{DoctorHelpers::REQUIRED_RUBY_VERSION}+)")
      issues << "Upgrade Ruby to #{DoctorHelpers::REQUIRED_RUBY_VERSION}+ using rbenv, rvm, or your package manager"
      all_ok = false
    end
  else
    DoctorHelpers.status(false, "Ruby not found")
    issues << "Install Ruby #{DoctorHelpers::REQUIRED_RUBY_VERSION}+"
    all_ok = false
  end

  bundler_ok, bundler_out = DoctorHelpers.check_command("bundle", "-v")
  bundler_version = DoctorHelpers.parse_version(bundler_out)
  if bundler_ok
    DoctorHelpers.status(true, "Bundler #{bundler_version}")
  else
    DoctorHelpers.status(false, "Bundler not found")
    issues << "Install Bundler: gem install bundler"
    all_ok = false
  end

  # ============================================================================
  # GEMS
  # ============================================================================
  puts "\n[Gems]"
  bundle_check = system("bundle check > /dev/null 2>&1")
  if bundle_check
    DoctorHelpers.status(true, "All gems installed")
  else
    DoctorHelpers.status(false, "Missing gems")
    issues << "Run: bundle install"
    all_ok = false
  end

  # ============================================================================
  # NODE.JS
  # ============================================================================
  puts "\n[Node.js]"
  node_ok, node_out = DoctorHelpers.check_command("node", "-v")
  node_version = DoctorHelpers.parse_version(node_out)

  if node_ok
    node_meets = DoctorHelpers.version_meets_requirement?(node_version, DoctorHelpers::REQUIRED_NODE_VERSION)
    if node_meets
      DoctorHelpers.status(true, "Node #{node_version} (required: #{DoctorHelpers::REQUIRED_NODE_VERSION}+)")
    else
      DoctorHelpers.status(false, "Node #{node_version} is too old (required: #{DoctorHelpers::REQUIRED_NODE_VERSION}+)")
      issues << "Upgrade Node.js to #{DoctorHelpers::REQUIRED_NODE_VERSION}+ using nvm, fnm, or your package manager"
      all_ok = false
    end
  else
    DoctorHelpers.status(false, "Node.js not found")
    issues << "Install Node.js #{DoctorHelpers::REQUIRED_NODE_VERSION}+"
    all_ok = false
  end

  npm_ok, npm_out = DoctorHelpers.check_command("npm", "-v")
  npm_version = DoctorHelpers.parse_version(npm_out)
  if npm_ok
    DoctorHelpers.status(true, "npm #{npm_version}")
  else
    DoctorHelpers.status(false, "npm not found")
    issues << "npm should come with Node.js - reinstall Node"
    all_ok = false
  end

  # ============================================================================
  # WEB DEPENDENCIES
  # ============================================================================
  puts "\n[Web Dependencies]"
  node_modules_path = File.join(Config::WEB_DIR, "node_modules")
  if File.directory?(node_modules_path)
    DoctorHelpers.status(true, "node_modules present in src_web/")
  else
    DoctorHelpers.status(false, "node_modules missing in src_web/")
    issues << "Run: cd src_web && npm install"
    all_ok = false
  end

  # ============================================================================
  # SIGNING TOOL (Optional)
  # ============================================================================
  puts "\n[Signing Tool (Optional)]"
  sign_tool_dir = File.join(Config::PROJECT_ROOT, "tools", "sign")
  sign_node_modules = File.join(sign_tool_dir, "node_modules")
  sign_env = File.join(sign_tool_dir, ".env")
  chrome_cache = File.expand_path("~/.cache/puppeteer")

  if File.directory?(sign_node_modules)
    DoctorHelpers.status(true, "Signing tool dependencies installed")

    # Check for Chrome browser
    if Dir.exist?(chrome_cache) && !Dir.glob("#{chrome_cache}/**/chrome*").empty?
      DoctorHelpers.status(true, "Chrome browser for Puppeteer found")
    else
      DoctorHelpers.warn("Chrome browser not downloaded (run: cd tools/sign && npm install)")
    end

    # Check for credentials (optional)
    if File.exist?(sign_env)
      DoctorHelpers.status(true, "Signing credentials configured (.env exists)")
    else
      DoctorHelpers.warn("Signing credentials not configured (copy .env.example to .env)")
    end
  else
    DoctorHelpers.warn("Signing tool not installed (optional, run: rake setup:sign)")
  end

  # ============================================================================
  # SKETCHUP (macOS only)
  # ============================================================================
  puts "\n[SketchUp]"
  if RUBY_PLATFORM.include?("darwin")
    sketchup_path = Config::SKETCHUP_APP
    if File.exist?(sketchup_path)
      DoctorHelpers.status(true, "SketchUp #{Config::SKETCHUP_YEAR} found")
    else
      DoctorHelpers.warn("SketchUp #{Config::SKETCHUP_YEAR} not found at #{sketchup_path}")
      DoctorHelpers.warn("Install SketchUp or update SKETCHUP_YEAR in Rakefile")
    end
  else
    DoctorHelpers.warn("SketchUp path check only available on macOS")
  end

  DoctorHelpers.warn("TestUp 2 status unknown (requires manual check inside SketchUp)")

  # ============================================================================
  # SUMMARY
  # ============================================================================
  puts "\n[Environment Summary]"
  if all_ok
    DoctorHelpers.status(true, "Ready for development! Run 'rake dev' to start.")
  else
    DoctorHelpers.status(false, "Issues found. Please fix the following:")
    puts ""
    issues.each_with_index do |issue, idx|
      puts "   #{idx + 1}. #{issue}"
    end
    puts ""
  end
end

desc "Install all dependencies"
task :setup do
  puts "🔧 Setting up development environment...\n\n"

  # Check Ruby first
  ruby_ok, ruby_out = DoctorHelpers.check_command("ruby", "-v")
  ruby_version = DoctorHelpers.parse_version(ruby_out)
  unless ruby_ok && DoctorHelpers.version_meets_requirement?(ruby_version, DoctorHelpers::REQUIRED_RUBY_VERSION)
    abort "❌ Ruby #{DoctorHelpers::REQUIRED_RUBY_VERSION}+ is required. Please install it first."
  end

  # Check Node first
  node_ok, node_out = DoctorHelpers.check_command("node", "-v")
  node_version = DoctorHelpers.parse_version(node_out)
  unless node_ok && DoctorHelpers.version_meets_requirement?(node_version, DoctorHelpers::REQUIRED_NODE_VERSION)
    abort "❌ Node.js #{DoctorHelpers::REQUIRED_NODE_VERSION}+ is required. Please install it first."
  end

  # Install gems
  puts "[1/2] Installing Ruby gems..."
  sh "bundle install"

  # Install npm packages
  puts "\n[2/2] Installing npm packages..."
  Dir.chdir(Config::WEB_DIR) do
    sh "npm install"
  end

  puts "\n✅ Setup complete! Run 'rake doctor' to verify, then 'rake dev' to start."
  puts "\n💡 For automated signing, also run: rake setup:sign"
end

desc "Install signing tool dependencies (optional)"
task "setup:sign" do
  puts "🔧 Setting up signing tool...\n\n"

  sign_tool_dir = File.join(Config::PROJECT_ROOT, "tools", "sign")

  # Install npm packages (this also downloads Chrome via postinstall)
  puts "[1/2] Installing signing tool dependencies..."
  Dir.chdir(sign_tool_dir) do
    sh "npm install"
    sh "npx puppeteer browsers install chrome"
  end

  # Check/prompt for credentials
  env_file = File.join(sign_tool_dir, ".env")
  env_example = File.join(sign_tool_dir, ".env.example")

  puts "\n[2/2] Checking credentials..."
  if File.exist?(env_file)
    puts "  ✅ .env file already exists"
  else
    puts "  📝 Creating .env from template..."
    FileUtils.cp(env_example, env_file)
    puts "  ⚠️  Edit tools/sign/.env with your Extension Warehouse credentials"
  end

  puts "\n✅ Signing tool setup complete!"
  puts "   Edit tools/sign/.env with your credentials, then run: rake build:sign:auto"
end
