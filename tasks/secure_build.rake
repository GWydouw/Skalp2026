# frozen_string_literal: true

require "fileutils"
require "zip"

namespace :build do
  desc "Perform a full secure release build for Skalp 2026"
  task :secure do
    puts "🚀 Starting Secure Build Pipeline for Skalp 2026..."
    
    # 1. Compilation & Embedding
    puts "\n--- [1/5] Compiling and Embedding ---"
    Rake::Task["compile:build"].invoke
    Rake::Task["embed"].invoke
    
    # 2. Package Inner RBZ (C-Extensions)
    puts "\n--- [2/5] Packaging Inner.rbz ---"
    inner_staging = "BUILDS/inner_staging"
    FileUtils.rm_rf(inner_staging)
    inner_skalp_dir = File.join(inner_staging, "Skalp_Skalp2026")
    FileUtils.mkdir_p(inner_skalp_dir)
    
    # Copy main loader
    FileUtils.cp("SOURCE/Skalp_Skalp2026.rb", inner_staging)
    
    # Copy binary extensions from SOURCE (where compile task should have placed them)
    # Note: Legacy naming used .mac and .win
    Dir.glob("SOURCE/Skalp_Skalp2026/SkalpC.{bundle,so,dll,mac,win}").each do |f|
      puts "    Adding binary: #{File.basename(f)}"
      FileUtils.cp(f, inner_skalp_dir)
    end
    
    inner_rbz = "BUILDS/inner/Skalp_Inner.rbz"
    FileUtils.mkdir_p(File.dirname(inner_rbz))
    FileUtils.rm_f(inner_rbz)
    
    Zip::File.open(inner_rbz, Zip::File::CREATE) do |zipfile|
      Dir.glob("#{inner_staging}/**/*").each do |file|
        next if File.directory?(file)
        # Entry name relative to inner_staging
        entry_name = file.sub("#{inner_staging}/", "")
        zipfile.add(entry_name, file)
      end
    end
    puts "✅ Inner.rbz created."

    # 3. Sign Inner RBZ
    puts "\n--- [3/5] Signing Inner.rbz ---"
    # We reuse the sign:auto logic but we need it to target our inner rbz
    # For now, we will simulate or call the signing script directly if needed.
    # PRO-TIP: We can set an ENV var to tell sign:auto which file to sign.
    ENV["SIGN_TARGET"] = inner_rbz
    Rake::Task["sign:auto"].invoke
    
    # Identify the signed inner RBZ
    signed_inner = Dir.glob("BUILDS/signed/Skalp_Inner*-signed.rbz").max_by { |f| File.mtime(f) }
    abort("❌ Failed to find signed Inner.rbz!") unless signed_inner && File.exist?(signed_inner)
    
    # 4. Remote Encryption of Outer Ruby
    puts "\n--- [4/5] Remote Encryption ---"
    # Outer Ruby is the SOURCE/Skalp_Skalp2026/ folder (excluding what's embedded)
    # The encrypt task will process everything in SOURCE/Skalp_Skalp2026/
    # and put results in BUILD_ENCRYPTED/skalp/
    Rake::Task["encrypt"].invoke("SOURCE/Skalp_Skalp2026", "BUILDS/encrypted_ruby")
    
    # 5. Package Final RBZ
    puts "\n--- [5/5] Packaging Final RBZ ---"
    final_staging = "BUILDS/final_staging"
    FileUtils.rm_rf(final_staging)
    final_skalp_dir = File.join(final_staging, "Skalp_Skalp2026")
    FileUtils.mkdir_p(final_skalp_dir)
    
    # Copy main loader
    FileUtils.cp("SOURCE/Skalp_Skalp2026.rb", final_staging)
    
    # Copy encrypted Ruby files
    FileUtils.cp_r(Dir.glob("BUILDS/encrypted_ruby/*"), final_skalp_dir)
    
    # Copy Assets (html, resources, etc.)
    %w[html resources chunky_png shellwords eval].each do |asset|
      src = "SOURCE/Skalp_Skalp2026/#{asset}"
      if Dir.exist?(src)
        FileUtils.cp_r(src, final_skalp_dir)
      end
    end
    
    # Inject the Signed Inner RBZ
    # Skalp loader expects it in the main extension directory
    FileUtils.cp(signed_inner, File.join(final_skalp_dir, "Skalp_Inner.rbz"))
    
    version = extract_version rescue "2026"
    final_rbz = "BUILDS/release/Skalp_v#{version}_Secure.rbz"
    FileUtils.mkdir_p(File.dirname(final_rbz))
    FileUtils.rm_f(final_rbz)
    
    Zip::File.open(final_rbz, Zip::File::CREATE) do |zipfile|
      Dir.glob("#{final_staging}/**/*").each do |file|
        next if File.directory?(file)
        entry_name = file.sub("#{final_staging}/", "")
        zipfile.add(entry_name, file)
      end
    end
    
    puts "✅ Final Secure RBZ created: #{final_rbz}"
    
    # Optional: Final Sign
    puts "\n📢 Final signing of Secure RBZ..."
    ENV["SIGN_TARGET"] = final_rbz
    # We might need to re-enable/re-run the task if it was already invoked
    Rake::Task["sign:auto"].reenable
    Rake::Task["sign:auto"].invoke
    
    puts "\n🏁 SECURE BUILD COMPLETE!"
  end
end
