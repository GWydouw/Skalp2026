# frozen_string_literal: true

require "json"
require "digest"
require "zip"
require "io/console"

# Build and signing tasks

# Helper: Extract version from version.rb
def extract_version
  version_file = File.join(Config::SOURCE_DIR, Config::EXTENSION_ID, "version.rb")
  abort("❌ Version file not found!") unless File.exist?(version_file)

  content = File.read(version_file)
  match = content.match(/VERSION\s*=\s*["']([^"']+)["']/)
  abort("❌ Could not parse VERSION from version.rb") unless match
  match[1]
end

# Helper: Check git status
def git_dirty?
  !`git status --porcelain`.strip.empty?
end

# Helper: Get git hash
def git_hash
  `git rev-parse --short HEAD`.strip.tap { |h| h.replace("unknown") if h.empty? }
end

# Core build logic (pure Ruby)
def build_rbz(mode:)
  version = extract_version
  timestamp = Time.now.strftime("%Y%m%d_%H%M")
  hash = git_hash
  is_dirty = git_dirty?

  if mode == :release
    puts "== BUILDING RELEASE v#{version} =="

    if is_dirty
      if ENV["CI"] == "true"
        puts "⚠️  WARNING: Uncommitted changes detected in CI. Proceeding anyway..."
      else
        abort("❌ ERROR: Cannot build RELEASE with uncommitted changes.\n   Please commit your changes and tag the release.")
      end
    end

    # Tag check (warning only)
    tag_check = `git tag --points-at HEAD`.split("\n").any? { |t| t.strip == "v#{version}" }
    puts "⚠️  WARNING: Current commit is not tagged with v#{version}" unless tag_check

    target_dir = File.join(Config::BUILD_DIR, "release")
    out_rbz = File.join(target_dir, "#{Config::EXTENSION_NAME}_v#{version}.rbz")
  else
    puts "== BUILDING DEV SNAPSHOT =="
    target_dir = File.join(Config::BUILD_DIR, "dev")
    hash = "#{hash}-dirty" if is_dirty
    puts "⚠️  Building with uncommitted changes (dirty)" if is_dirty
    out_rbz = File.join(target_dir, "#{Config::EXTENSION_NAME}_v#{version}-dev-#{timestamp}.rbz")
  end

  puts "Project : #{Config::PROJECT_ROOT}"
  puts "Output  : #{out_rbz}"
  puts

  FileUtils.mkdir_p(target_dir)

  # Validate source
  loader = "#{Config::EXTENSION_ID}.rb"
  dir = Config::EXTENSION_ID
  abort("❌ Source files missing in #{Config::SOURCE_DIR}") unless File.exist?(File.join(Config::SOURCE_DIR,
                                                                                         loader)) && File.directory?(File.join(
                                                                                                                       Config::SOURCE_DIR, dir
                                                                                                                     ))

  # Staging
  build_tmp = File.join(Config::BUILD_DIR, "tmp_stage_#{Time.now.to_i}")
  FileUtils.mkdir_p(build_tmp)
  FileUtils.cp_r(Dir.glob("#{Config::SOURCE_DIR}/."), build_tmp)

  # Remove .DS_Store
  Dir.glob("#{build_tmp}/**/.DS_Store").each { |f| FileUtils.rm_f(f) }

  # 1. Inject Build Metadata
  staged_version_file = File.join(build_tmp, dir, "version.rb")
  if File.exist?(staged_version_file)
    puts ">> Injecting build metadata..."
    content = File.read(staged_version_file)
    build_date_str = Time.now.strftime("%Y-%m-%d %H:%M:%S")
    content.gsub!(/BUILD_DATE\s*=\s*"[^"]*"/, "BUILD_DATE = \"#{build_date_str}\"")
    content.gsub!(/GIT_HASH\s*=\s*"[^"]*"/, "GIT_HASH   = \"#{hash}\"")
    File.write(staged_version_file, content)
  end

  # 2. Generate Integrity Manifest
  puts ">> Generating manifest.json..."
  manifest = {
    build_date: timestamp,
    version: version,
    git_hash: hash,
    mode: mode.to_s,
    files: {}
  }

  Dir.chdir(build_tmp) do
    Dir.glob("#{dir}/**/*.{rb,js,html,css,json}").each do |file|
      next if file.include?("manifest.json")

      manifest[:files][file] = Digest::SHA256.file(file).hexdigest
    end
  end

  File.write(File.join(build_tmp, dir, "manifest.json"), JSON.pretty_generate(manifest))

  # 3. Zip
  includes = [loader, dir]
  Dir.chdir(build_tmp) do
    %w[LICENSE* README* CHANGELOG*].each do |pattern|
      Dir.glob(pattern).each { |f| includes << f }
    end
  end

  puts ">> Zipping..."
  FileUtils.rm_f(out_rbz) # Remove old if exists

  # Change to staging directory for correct relative paths in ZIP
  Dir.chdir(build_tmp) do
    Zip::File.open(out_rbz, create: true) do |zipfile|
      includes.each do |item|
        if File.directory?(item)
          Dir.glob("#{item}/**/*").each do |file|
            next if File.directory?(file)

            zipfile.add(file, File.join(build_tmp, file))
          end
        elsif File.file?(item)
          zipfile.add(item, File.join(build_tmp, item))
        end
      end
    end
  end
  puts "✅ RBZ Created: #{File.basename(out_rbz)}"

  # Cleanup
  FileUtils.rm_rf(build_tmp)

  # Update symlink
  Dir.chdir(target_dir) do
    symlink_name = "#{Config::EXTENSION_NAME}-latest-#{mode}.rbz"
    FileUtils.ln_sf(File.basename(out_rbz), symlink_name)
    puts "🔗 Updated local symlink: #{symlink_name}"
  end

  puts "== Done =="
end

# Build the outer "installer" RBZ that wraps the main extension RBZ
def build_installer_rbz(inner_rbz_path)
  version = extract_version
  timestamp = Time.now.strftime("%Y%m%d_%H%M")
  
  puts "\n== BUILDING INSTALLER RBZ =="
  puts "Inner RBZ: #{inner_rbz_path}"
  
  # Staging directory
  installer_tmp = File.join(Config::BUILD_DIR, "tmp_installer_stage_#{Time.now.to_i}")
  FileUtils.mkdir_p(installer_tmp)
  
  # Copy installer skeleton
  installer_source = File.join(Config::PROJECT_ROOT, "Skalp_Skalp2026_installer")
  unless File.directory?(installer_source)
    abort("❌ Installer skeleton not found at: #{installer_source}")
  end
  
  FileUtils.cp_r(Dir.glob("#{installer_source}/*"), installer_tmp)
  FileUtils.cp(File.join(Config::PROJECT_ROOT, "Skalp_Skalp2026_installer.rb"), installer_tmp) if File.exist?(File.join(Config::PROJECT_ROOT, "Skalp_Skalp2026_installer.rb"))
  
  # Copy the inner RBZ to the installer folder
  installer_rbz_dest = File.join(installer_tmp, "Skalp_Skalp2026_installer", "Skalp.rbz")
  FileUtils.cp(inner_rbz_path, installer_rbz_dest)
  puts ">> Embedded inner RBZ: #{File.basename(inner_rbz_path)}"
  
  # Create output RBZ
  target_dir = File.join(Config::BUILD_DIR, "release")
  FileUtils.mkdir_p(target_dir)
  out_installer_rbz = File.join(target_dir, "Skalp_Skalp2026_installer_v#{version}.rbz")
  FileUtils.rm_f(out_installer_rbz)
  
  puts ">> Packaging installer RBZ..."
  Dir.chdir(installer_tmp) do
    Zip::File.open(out_installer_rbz, create: true) do |zipfile|
      Dir.glob("**/*").each do |file|
        next if File.directory?(file)
        zipfile.add(file, File.join(installer_tmp, file))
      end
    end
  end
  
  # Cleanup
  FileUtils.rm_rf(installer_tmp)
  
  puts "✅ Installer RBZ Created: #{File.basename(out_installer_rbz)}"
  puts "== Done =="
  
  out_installer_rbz
end


desc "Build RBZ package (Defaults to Dev Snapshot)"
task build: "build:dev"

namespace :build do
  desc "Build Development Snapshot (Allows dirty git state)"
  task :dev do
    build_rbz(mode: :dev)
  end

  desc "Build Release Artifact (Requires clean git state)"
  task :release do
    build_rbz(mode: :release)
    
    # Register version in database
    puts "\n📤 Registering version in database..."
    Rake::Task["version:register"].invoke("alpha")
    
    # Build the installer RBZ
    puts "\n📦 Building installer package..."
    release_dir = File.join(Config::BUILD_DIR, "release")
    version = extract_version
    inner_rbz = File.join(release_dir, "#{Config::EXTENSION_NAME}_v#{version}.rbz")
    
    if File.exist?(inner_rbz)
      build_installer_rbz(inner_rbz)
    else
      puts "⚠️  Inner RBZ not found, skipping installer build"
    end
  end

  desc "Build Release, open Signing Portal, and capture result"
  task sign: :release do
    puts "📝 Preparing for signing..."

    # 1. Find latest release RBZ
    release_dir = File.join(Config::BUILD_DIR, "release")
    rbz = Dir.glob("#{release_dir}/*.rbz")
             .reject { |f| f.include?("-latest-") }
             .max_by { |f| File.mtime(f) }

    abort("❌ Build failed or no RBZ found in #{release_dir}") unless rbz && File.exist?(rbz)

    filename = File.basename(rbz)

    # 2. Copy to clipboard
    safe_path = rbz.gsub("'", "\\'")
    if OS.mac?
      system("echo -n '#{safe_path}' | pbcopy")
      puts "📋 Copied upload path to clipboard: #{filename}"
    elsif OS.windows?
      system("echo #{safe_path} | clip")
      puts "📋 Copied upload path to clipboard: #{filename}"
    else
      puts "📋 Path to upload: #{safe_path}"
    end

    # 3. Open Portal
    portal_url = "https://extensions.sketchup.com/en/developer_center/extension_signature"

    # 3b. Pre-clean Downloads (Prevent 'file-1.rbz' issues)
    downloads_dir = File.expand_path("~/Downloads")
    target_path = File.join(downloads_dir, filename)
    if File.exist?(target_path)
      puts "🧹 Cleaning up old file in Downloads: #{filename}"
      FileUtils.rm_f(target_path)
    end

    puts "🌍 Opening Signing Portal..."
    if OS.mac?
      system("open '#{portal_url}'")
    elsif OS.windows?
      system("start #{portal_url}")
    else
      # Linux/Other
      system("xdg-open '#{portal_url}'")
    end

    puts "\n👉 ACTION REQUIRED: Upload '#{filename}' (path in clipboard) and click 'Sign and Download'."
    puts "   (Waiting for signed file in Downloads folder...)"

    # 4. Wait for Download
    start_time = Time.now
    found = false

    loop do
      elapsed = (Time.now - start_time).round
      print "\r⏳ Waiting: #{elapsed}s"

      if File.exist?(target_path) && (File.mtime(target_path) > (start_time - 5))
        found = true
        print "\n"
        puts "✅ Signed file detected: #{target_path}"
        break
      end

      sleep 1
    end

    # 5. Move to Signed Directory
    if found
      FileUtils.mkdir_p(Config::SIGNED_DIR)

      version_match = filename.match(/_v(\d+\.\d+\.\d+)/)
      version_suffix = version_match ? "_v#{version_match[1]}" : ""

      final_name = if version_suffix.empty?
                     filename.sub(/(\.rbz)$/i, "-signed.rbz")
                   else
                     "#{Config::EXTENSION_NAME}#{version_suffix}-signed.rbz"
                   end

      final_dest = File.join(Config::SIGNED_DIR, final_name)

      FileUtils.mv(target_path, final_dest)
      puts "📦 Moved to: #{final_dest}"

      # 6. Update Symlink
      Dir.chdir(Config::SIGNED_DIR) do
        symlink_name = "#{Config::EXTENSION_NAME}-latest-signed.rbz"
        FileUtils.ln_sf(final_name, symlink_name)
        puts "🔗 Updated latest symlink: #{symlink_name}"
      end
    end
  end

  desc "Build Release and sign automatically via browser automation (requires EW credentials)"
  task "sign:auto" => :release do
    puts "🤖 Starting automated signing..."

    # 0. Cleanup old download directories
    sign_tool_dir = File.join(Config::PROJECT_ROOT, "tools", "sign")
    if File.exist?(sign_tool_dir)
      Dir.glob(File.join(sign_tool_dir, "download-*")).each do |dir|
        next unless File.directory?(dir)

        puts "🧹 Cleaning up old download directory: #{File.basename(dir)}"
        FileUtils.rm_rf(dir)
      end
    end

    # 1. Find latest release RBZ
    release_dir = File.join(Config::BUILD_DIR, "release")
    rbz = Dir.glob("#{release_dir}/*.rbz")
             .reject { |f| f.include?("-latest-") }
             .max_by { |f| File.mtime(f) }

    abort("❌ Build failed or no RBZ found in #{release_dir}") unless rbz && File.exist?(rbz)

    filename = File.basename(rbz)
    puts "📦 Signing: #{filename}"

    # 2. Check if signing tool is installed
    # sign_tool_dir is defined above
    unless File.exist?(File.join(sign_tool_dir, "node_modules"))
      puts "📦 Installing signing tool dependencies..."
      Dir.chdir(sign_tool_dir) do
        system("npm install") || abort("❌ Failed to install signing tool dependencies")
      end
    end

    # 3. Check for credentials
    env_file = File.join(sign_tool_dir, ".env")

    # Check if .env exists and has content
    has_valid_env_file = if File.exist?(env_file)
                           content = File.read(env_file)
                           content.match?(/^EW_USERNAME=.+/) && content.match?(/^EW_PASSWORD=.+/)
                         else
                           false
                         end

    has_env_vars = ENV.fetch("EW_USERNAME", nil) && ENV.fetch("EW_PASSWORD", nil)

    unless has_valid_env_file || has_env_vars
      puts "\n⚠️  Extension Warehouse credentials missing or incomplete."
      puts "   To automate signing, we need your Trimble Identity credentials."
      puts "   These will be stored secure locally in: tools/sign/.env"
      puts "   🔒 This file is ALREADY gitignored and will NOT be committed."
      puts ""

      print "   Username (email): "
      username = $stdin.gets&.strip

      print "   Password: "
      password = $stdin.noecho(&:gets)&.strip
      puts "" # Newline after password

      if username.nil? || username.empty? || password.nil? || password.empty?
        puts "⚠️  No credentials entered. You will need to login manually in the browser window."
      else
        File.write(env_file, "EW_USERNAME=#{username}\nEW_PASSWORD=#{password}\n")
        puts "✅ Credentials saved to #{env_file}"
      end
    end

    # 4. Run the signing script
    puts ""
    output_lines = []
    Dir.chdir(sign_tool_dir) do
      # Stream output in real-time while capturing it
      IO.popen(["npx", "tsx", "sign.ts", rbz, "--no-headless"], err: %i[child out]) do |io|
        io.each do |line|
          puts line
          output_lines << line
        end
      end
      abort("❌ Signing failed") unless $CHILD_STATUS.success?
    end
    output = output_lines.join

    # 5. Parse the signed file path from output
    signed_match = output.match(/__SIGNED_FILE__:(.+)$/)
    abort("❌ Could not determine signed file path from script output") unless signed_match

    signed_file = signed_match[1].strip

    # 6. Move to signed directory
    FileUtils.mkdir_p(Config::SIGNED_DIR)

    version_match = filename.match(/_v(\d+\.\d+\.\d+)/)
    version_suffix = version_match ? "_v#{version_match[1]}" : ""

    final_name = if version_suffix.empty?
                   filename.sub(/(.rbz)$/i, "-signed.rbz")
                 else
                   "#{Config::EXTENSION_NAME}#{version_suffix}-signed.rbz"
                 end

    final_dest = File.join(Config::SIGNED_DIR, final_name)

    FileUtils.mv(signed_file, final_dest)
    puts "📦 Moved to: #{final_dest}"

    # 7. Cleanup temp download directory
    temp_dir = File.dirname(signed_file)
    FileUtils.rm_rf(temp_dir) if temp_dir.include?("download-") && File.directory?(temp_dir)

    # 8. Update Symlink
    Dir.chdir(Config::SIGNED_DIR) do
      symlink_name = "#{Config::EXTENSION_NAME}-latest-signed.rbz"
      FileUtils.ln_sf(final_name, symlink_name)
      puts "🔗 Updated latest symlink: #{symlink_name}"
    end

    puts "\n✅ Automated signing complete!"
  end
end
