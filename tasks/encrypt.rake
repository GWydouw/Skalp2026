# frozen_string_literal: true

require "fileutils"

desc "Encrypt Ruby source using remote RubyEncoder (Legacy)"
task :encrypt, [:src_dir, :out_dir] do |_t, args|
  require "fileutils"

  # Config
  REMOTE_USER = "skalpadmin"
  REMOTE_HOST = "builder.skalp4sketchup.com"
  REMOTE_DIR = "/home/skalpadmin/rbin"
  
  # Allow overrides via args, fallback to defaults
  src_dir = args[:src_dir] || "SOURCE"
  out_dir = args[:out_dir] || "BUILD_ENCRYPTED"

  puts "🔐 Starting Remote Encryption on #{REMOTE_HOST}..."
  puts "   Source: #{src_dir}"
  puts "   Target: #{out_dir}"

  # 1. Clean Local Output
  FileUtils.rm_rf(out_dir)
  FileUtils.mkdir_p(out_dir)

  # 2. Prepare Remote (SSH)
  puts "   -> Cleaning remote directory..."
  system("ssh #{REMOTE_USER}@#{REMOTE_HOST} 'rm -rf #{REMOTE_DIR} && mkdir -p #{REMOTE_DIR}'") or abort("Failed to clean remote dir")

  # 3. Upload Source (SCP)
  puts "   -> Uploading source files..."
  # Note: -r to include subdirectories
  system("scp -q -r #{src_dir}/* #{REMOTE_USER}@#{REMOTE_HOST}:#{REMOTE_DIR}/") or abort("Failed to upload files")

  # 4. Run Encryption (SSH)
  puts "   -> Running RubyEncoder..."
  # Shellwords.escape would be safer but let's stick to the verified working command
  enc_cmd = "/home/skalpadmin/rubyencoder-3.0/bin/rubyencoder --ruby 3.2 -r --external ./Skalp.lic --rails --const \"SKALP_EXPIRE=12/30/2099\" --projid s353DaIOwXj3SZIRoqtA --projkey 91buLYpxAjWPjrbyw0UL -p \"# Copyright (C) 2014 - 2026 Skalp, All rights reserved.; Skalp::remove_wrong_rgloader;Dir.chdir(Skalp::SKALP_PATH);\" -j \"_f = (\\\"./eval/loader.rb\\\"); load _f and break;\" -b- \"#{REMOTE_DIR}/**/*.rb\""
  
  system("ssh #{REMOTE_USER}@#{REMOTE_HOST} '#{enc_cmd}'") or abort("Encryption failed on server")

  # 5. Download Results (SCP)
  puts "   -> Downloading encrypted files..."
  system("scp -q -r #{REMOTE_USER}@#{REMOTE_HOST}:#{REMOTE_DIR}/* #{out_dir}/") or abort("Failed to download results")

  # 6. Cleanup Remote
  puts "   -> Cleaning up..."
  system("ssh #{REMOTE_USER}@#{REMOTE_HOST} 'rm -rf #{REMOTE_DIR}'")

  puts "✅ Encryption Complete."
end
