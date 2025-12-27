# frozen_string_literal: true

# Extension installation tasks

namespace :install do
  desc "Remove all extension files and dev artifacts from Plugins"
  task :clean do
    puts "🧹 Cleaning Plugins folder..."

    # 1. Main Extension Files
    FileUtils.rm_f(File.join(Config::PLUGINS_DIR, "#{Config::EXTENSION_ID}.rb"))
    FileUtils.rm_rf(File.join(Config::PLUGINS_DIR, Config::EXTENSION_ID))

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

  desc "Clean install of extension to Plugins folder"
  task local: ["skp:kill", "install:clean"] do
    puts "🚀 Deploying to #{Config::PLUGINS_DIR}..."

    # Ensure plugins dir exists
    FileUtils.mkdir_p(Config::PLUGINS_DIR)

    # Copy new source
    FileUtils.cp_r(Dir.glob("#{Config::SOURCE_DIR}/*"), Config::PLUGINS_DIR)

    puts "✅ Extension installed."
  end

  desc "Inject Debug Loaders (Development Only)"
  task :debug_loaders do
    puts "💉 Injecting Debug Resources..."

    # 1. Generate Config
    config_path = File.join(Config::PLUGINS_DIR, "skalp_debug_config.rb")
    File.write(config_path, "module #{Config::EXTENSION_MODULE}; module DebugConfig; PROJECT_ROOT = '#{Dir.pwd}'; end; end")

    # 2. Copy Loaders
    Config::DEV_LOADERS.each do |src, dest|
      src_path = File.join(Dir.pwd, src) # Temporarily root-based
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

    # 1. Determine codebase version
    version_file = File.read(File.join(Config::SOURCE_DIR, Config::EXTENSION_ID, "version.rb"))
    match = version_file.match(/VERSION\s*=\s*["']([^"']+)["']/)
    abort("❌ Could not determine version from version.rb") unless match
    target_version = match[1]

    puts "   Codebase Version: v#{target_version}"

    # 2. Strict Search: Look for explicit match
    rbz_candidate = nil

    # Check SIGNED
    signed_candidates = Dir.glob(File.join(Config::SIGNED_DIR, "*_v#{target_version}*.rbz"))
    if signed_candidates.any?
      rbz_candidate = signed_candidates.max_by { |f| File.mtime(f) }
      puts "🎯 Found SIGNED build: #{File.basename(rbz_candidate)}"
    end

    # Check RELEASE (Fallback)
    unless rbz_candidate
      release_candidates = Dir.glob(File.join(Config::BUILD_DIR, "release", "*_v#{target_version}*.rbz"))
      if release_candidates.any?
        rbz_candidate = release_candidates.max_by { |f| File.mtime(f) }
        puts "🎯 Found RELEASE build: #{File.basename(rbz_candidate)}"
        puts "⚠️  WARNING: Installing UNSIGNED release build."
      end
    end

    # 3. Fail if not found
    unless rbz_candidate && File.exist?(rbz_candidate)
      puts "❌ Integrity Check Failed!"
      puts "   Codebase is at v#{target_version}, but no matching build artifact found in BUILDS/."
      puts "   Expected: *#{Config::EXTENSION_NAME}_v#{target_version}*.rbz"
      puts "   Action  : Run 'rake build:release' or 'rake release:patch' to generate this version."
      abort
    end

    puts "🚀 Deploying GOLD MASTER: #{File.basename(rbz_candidate)}..."

    # Ensure plugins dir exists
    FileUtils.mkdir_p(Config::PLUGINS_DIR)

    # Unzip RBZ directly to Plugins
    sh "unzip -q '#{rbz_candidate}' -d '#{Config::PLUGINS_DIR}'"

    # Inject Dev Metadata for Verification
    metadata = {
      project_root: Dir.pwd,
      git_sha: `git rev-parse HEAD`.strip
    }
    File.write(File.join(Config::PLUGINS_DIR, "dev_metadata.json"), JSON.generate(metadata))

    puts "✅ Gold Master installed."
  end

  desc "Stage latest RBZ to BUILD_DEPLOY for distribution"
  task :stage do
    stage_dir = File.join(Config::PROJECT_ROOT, "BUILD_DEPLOY")
    FileUtils.mkdir_p(stage_dir)

    # Find latest RBZ (prefer signed, then release, then dev)
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
