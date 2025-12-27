#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "digest"
require "yaml"

# Test Configuration
# tools/verify_build.rb -> project root is one level up
PROJECT_ROOT = File.expand_path("..", __dir__)

# Load extension configuration
CONFIG = YAML.load_file(File.join(PROJECT_ROOT, "extension.yml"))
EXTENSION_ID = CONFIG.dig("extension", "id")
EXTENSION_NAME = CONFIG.dig("extension", "artifact_prefix")
EXTENSION_MODULE = CONFIG.dig("extension", "module_name")

# Use test_assets directory for temp files (since it is .gitignored)
TEST_DIR = File.join(PROJECT_ROOT, "test_assets")
FileUtils.mkdir_p(TEST_DIR)
TEST_TMP_DIR = File.join(TEST_DIR, "verify_build_tmp")

EXTENSION_DIR_NAME = EXTENSION_ID

puts "=== STARTING BUILD PIPELINE TEST ==="

# 1. execute rake build:dev
puts "\n[1/5] Running rake build:dev..."
_, stderr, status = Open3.capture3("rake build:dev", chdir: PROJECT_ROOT)

unless status.success?
  puts "❌ Build failed!"
  puts stderr
  exit 1
end

# Extract RBZ path from output or find latest in BUILDS
LATEST_RBZ = File.join(PROJECT_ROOT, "BUILDS", "dev", "#{EXTENSION_NAME}-latest-dev.rbz")

unless File.exist?(LATEST_RBZ)
  puts "❌ Latest RBZ not found at #{LATEST_RBZ}"
  exit 1
end
puts "✅ Build successful. Found #{LATEST_RBZ}"

# 2. Unzip to temp
puts "\n[2/5] Unzipping RBZ..."
FileUtils.rm_rf(TEST_TMP_DIR)
FileUtils.mkdir_p(TEST_TMP_DIR)

system("unzip -q \"#{LATEST_RBZ}\" -d \"#{TEST_TMP_DIR}\"")

EXT_ROOT = File.join(TEST_TMP_DIR, EXTENSION_DIR_NAME)
unless File.directory?(EXT_ROOT)
  puts "❌ Extension directory not found in RBZ"
  exit 1
end
puts "✅ Unzip successful."

# 3. Verify Version Metadata Injection
puts "\n[3/5] Verifying Metadata Injection in version.rb..."
VERSION_FILE = File.join(EXT_ROOT, "version.rb")
unless File.exist?(VERSION_FILE)
  puts "❌ version.rb missing in RBZ"
  exit 1
end

content = File.read(VERSION_FILE)
if content.include?('BUILD_DATE = "Development"')
  puts "❌ BUILD_DATE not injected"
  exit 1
end
if content.include?('GIT_HASH   = "HEAD"')
  puts "❌ GIT_HASH not injected"
  exit 1
end

puts "✅ Metadata injected successfully."

# 4. Verify Manifest Existence
puts "\n[4/5] Verifying manifest.json..."
MANIFEST_FILE = File.join(EXT_ROOT, "manifest.json")
unless File.exist?(MANIFEST_FILE)
  puts "❌ manifest.json missing in RBZ"
  exit 1
end

begin
  manifest = JSON.parse(File.read(MANIFEST_FILE))
  puts "✅ Manifest valid JSON, contains #{manifest['files'].count} files."
rescue JSON::ParserError
  puts "❌ Manifest JSON corrupted"
  exit 1
end

# 5. Run Integrity Check Logic
puts "\n[5/5] Running Self-Verification (IntegrityCheck)..."

# Mock SketchUp UI
module UI; def self.messagebox(m) = puts("[MockUI] #{m}"); end
module Sketchup; end

require File.join(EXT_ROOT, "integrity_check.rb")

# Dynamically get the extension module based on config
extension_module = Object.const_get(EXTENSION_MODULE)
result = extension_module::IntegrityCheck.verify_installation

if result[:status] == :ok
  puts "✅ Integrity Check PASSED: #{result[:message]}"
else
  puts "❌ Integrity Check FAILED!"
  puts "   Message: #{result[:message]}"
  exit 1
end

puts "\n=== TEST COMPLETE: ALL SYSTEMS GO === 🚀"
FileUtils.rm_rf(TEST_TMP_DIR)
