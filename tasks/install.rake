# frozen_string_literal: true

# Extension installation tasks

namespace :install do
  desc "Remove all extension files and dev artifacts from Plugins"
  task :clean do
    puts "🧹 Cleaning Plugins folder..."

    # 1. Main Extension Files
    FileUtils.rm_f(File.join(Config::PLUGINS_DIR, "#{Config::EXTENSION_ID}.rb"))
    FileUtils.rm_rf(File.join(Config::PLUGINS_DIR, Config::EXTENSION_ID))
    # Skalp specific dir
    FileUtils.rm_rf(File.join(Config::PLUGINS_DIR, "Skalp_Skalp2026"))

    # 2. Dev/Debug Artifacts
    artifacts = [
      "debug_loader.rb",
      "undo_research.rb",
      "skalp_debug_config.rb",
      "skalp_debug_impl.rb"
    ]

    artifacts.each do |f|
      path = File.join(Config::PLUGINS_DIR, f)
      if File.exist?(path)
        FileUtils.rm_f(path)
        puts "   - Removed: #{f}"
      end
    end
  end

  desc "Clean install of extension to Plugins folder. Selection: LIC=Guy.lic (or Guy.lic_trial etc)"
  task local: ["skp:kill", "install:clean"] do
    puts "🚀 Deploying to #{Config::PLUGINS_DIR}..."

    # Ensure plugins dir exists
    FileUtils.mkdir_p(Config::PLUGINS_DIR)

    # Copy new source
    # We use -L to follow symlinks so Skalp_Skalp2026 is copied as a directory
    sh "cp -R -L '#{Config::SOURCE_DIR}/'* '#{Config::PLUGINS_DIR}/'"
    
    # Copy embed.yml for development mode
    embed_yml_src = File.join(Config::PROJECT_ROOT, 'embed.yml')
    embed_yml_dest = File.join(Config::PLUGINS_DIR, 'Skalp_Skalp2026', 'embed.yml')
    if File.exist?(embed_yml_src)
      FileUtils.cp(embed_yml_src, embed_yml_dest)
      puts "   📋 Copied embed.yml for DevMode"
    end
    
    # Extract SkalpC from .bundle directory to .so file (Ruby can't load .bundle directories)
    skalpc_bundle_binary = File.join(Config::PLUGINS_DIR, 'Skalp_Skalp2026', 'SkalpC.bundle', 'Contents', 'MacOS', 'SkalpC')
    skalpc_so = File.join(Config::PLUGINS_DIR, 'Skalp_Skalp2026', 'SkalpC.so')
    if File.exist?(skalpc_bundle_binary)
      FileUtils.cp(skalpc_bundle_binary, skalpc_so)
      puts "   💎 Extracted SkalpC.so from bundle"
    end

    # --- [NEW] Inject Skalp Placeholders ---
    # These placeholders exist in Skalp_Skalp2026/Skalp.rb
    # And we also update the root loader for consistency
    skalp_rb = File.join(Config::PLUGINS_DIR, "Skalp_Skalp2026", "Skalp.rb")
    root_loader = File.join(Config::PLUGINS_DIR, "Skalp_Skalp2026.rb")
    
    # Get version logic
    # FastBuild always uses .9999 version (not registered in database)
    version = "2026.0.9999"
    build_date = Time.now.strftime("%d %B %Y").downcase
    
    # Update version.rb in installed Plugins to show fastbuild version
    installed_version_rb = File.join(Config::PLUGINS_DIR, 'Skalp_Skalp2026', 'version.rb')
    if File.exist?(installed_version_rb)
      version_content = File.read(installed_version_rb)
      version_content.gsub!(/VERSION\s*=\s*["'][^"']+["']/, "VERSION = \"#{version}\"")
      version_content.gsub!(/BUILD_DATE\s*=\s*["'][^"']+["']/, "BUILD_DATE = \"#{build_date}\"")
      File.write(installed_version_rb, version_content)
      puts "   🔢 Updated version.rb to FastBuild version #{version}"
    end

    [skalp_rb, root_loader].each do |file|
      next unless File.exist?(file)
      puts "💉 Injecting Skalp Metadata into #{File.basename(file)}..."
      
      content = File.read(file)
      
      # 1. Placeholders
      content.gsub!("#SKALPVERSION#", version)
      content.gsub!("#SKALPBUILDDATE#", build_date)
      
      # 2. Hardcoded Patterns (mostly for root loader which might not use placeholders)
      content.gsub!(/(# Version\s*:\s*)\d+\.\d+\.\d+/, "\\1#{version}")
      content.gsub!(/(# Date\s*:\s*)\d+ \w+ \d+/, "\\1#{build_date}")
      
      # 3. SketchUp Version Lock (e.g. 26 for 2026)
      short_year = Config::SKETCHUP_YEAR.to_s[-2..-1]
      content.gsub!(/(@version_required\s*=\s*)\d+/, "\\1#{short_year}")
      content.gsub!(/(@version_max\s*=\s*)\d+/, "\\1#{short_year}")
      content.gsub!(/2014-\d{4}/, "2014-#{Time.now.year}") # Auto-update copyright to current year

      # 4. Debug / Dev Defaults (Skalp.rb only)
      if file == skalp_rb
        content.gsub!("#SKALPCONSOLE#", "DEBUG = true")
        content.gsub!("#SKALPDEBUG#", "SKALPDEBUG = true")
        content.gsub!("#SKETCHUPDEBUG#", "SKETCHUPDEBUG = false")
        content.gsub!("#SKALPDEBUGGER#", "SKALPDEBUGGER = false")
      end
      
      File.write(file, content)
    end
    puts "   ✅ Metadata injected (Version: #{version})"
    # ---------------------------------------

    dest_lic = File.join(Config::PLUGINS_DIR, "Skalp_Skalp2026", "Skalp.lic")
    
    # Handle License selection
    lic_choice = ENV['LIC']
    if lic_choice
      lic_src = File.join(Config::PROJECT_ROOT, "dev_licenses", lic_choice)
      if File.exist?(lic_src)
        FileUtils.cp(lic_src, dest_lic)
        puts "✅ Applied License: #{lic_choice}"
      else
        puts "❌ License not found: #{lic_choice}"
        puts "Available licenses in dev_licenses/:"
        Dir.glob(File.join(Config::PROJECT_ROOT, "dev_licenses", "*.lic*")).each do |f|
          puts "  - #{File.basename(f)}"
        end
      end
    else
      # User requested no default license
      FileUtils.rm_f(dest_lic)
      puts "ℹ️ No license specified (LIC=...). Skipping Skalp.lic installation."
    end

    puts "✅ Extension installed."
  end

  # ... [rest of the file stays same, but I'll write the whole file to be safe]
  
  desc "Inject Debug Loaders (Development Only)"
  task :debug_loaders do
    puts "💉 Injecting Debug Resources..."
    config_path = File.join(Config::PLUGINS_DIR, "skalp_debug_config.rb")
    File.write(config_path, "module #{Config::EXTENSION_MODULE}; module DebugConfig; PROJECT_ROOT = '#{Dir.pwd}'; end; end")
    Config::DEV_LOADERS.each do |src, dest|
      src_path = File.join(Dir.pwd, src)
      dest_path = File.join(Config::PLUGINS_DIR, dest)
      if File.exist?(src_path)
        FileUtils.cp(src_path, dest_path)
        puts "   + #{dest}"
      else
        puts "   ⚠️ Missing dev loader: #{src}"
      end
    end
  end

  desc "Install latest RBZ (Gold Master) to Plugins folder"
  task rbz: ["skp:kill", "install:clean"] do
    puts "🔍 Resolving RBZ for current version..."
    version_file = File.read(File.join(Config::SOURCE_DIR, Config::EXTENSION_ID, "version.rb"))
    match = version_file.match(/VERSION\s*=\s*["']([^"']+)["']/)
    abort("❌ Could not determine version from version.rb") unless match
    target_version = match[1]
    puts "   Codebase Version: v#{target_version}"
    rbz_candidate = nil
    signed_candidates = Dir.glob(File.join(Config::SIGNED_DIR, "*_v#{target_version}*.rbz"))
    if signed_candidates.any?
      rbz_candidate = signed_candidates.max_by { |f| File.mtime(f) }
      puts "🎯 Found SIGNED build: #{File.basename(rbz_candidate)}"
    end
    unless rbz_candidate
      release_candidates = Dir.glob(File.join(Config::BUILD_DIR, "release", "*_v#{target_version}*.rbz"))
      if release_candidates.any?
        rbz_candidate = release_candidates.max_by { |f| File.mtime(f) }
        puts "🎯 Found RELEASE build: #{File.basename(rbz_candidate)}"
        puts "⚠️  WARNING: Installing UNSIGNED release build."
      end
    end
    unless rbz_candidate && File.exist?(rbz_candidate)
      abort("❌ Integrity Check Failed! No matching build artifact found in BUILDS/.")
    end
    puts "🚀 Deploying GOLD MASTER: #{File.basename(rbz_candidate)}..."
    FileUtils.mkdir_p(Config::PLUGINS_DIR)
    sh "unzip -q '#{rbz_candidate}' -d '#{Config::PLUGINS_DIR}'"
    metadata = { project_root: Dir.pwd, git_sha: `git rev-parse HEAD`.strip }
    File.write(File.join(Config::PLUGINS_DIR, "dev_metadata.json"), JSON.generate(metadata))
    puts "✅ Gold Master installed."
  end

  desc "Stage latest RBZ to BUILD_DEPLOY for distribution"
  task :stage do
    stage_dir = File.join(Config::PROJECT_ROOT, "BUILD_DEPLOY")
    FileUtils.mkdir_p(stage_dir)
    rbz = [Config::SIGNED_DIR, "#{Config::BUILD_DIR}/release", "#{Config::BUILD_DIR}/dev"]
          .flat_map { |d| Dir.glob("#{d}/*.rbz") }
          .reject { |f| f.include?("-latest-") }
          .max_by { |f| File.mtime(f) }
    abort("❌ No RBZ found. Run 'rake build:dev' first.") unless rbz
    dest = File.join(stage_dir, File.basename(rbz))
    FileUtils.cp(rbz, dest)
    puts "📦 Staged: #{dest}"
  end
end
