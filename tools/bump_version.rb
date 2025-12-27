#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"

# Usage:
#   ruby tools/bump_version.rb next <minor|major|patch|X.Y.Z>
#   ruby tools/bump_version.rb apply <version_string>

# Load extension configuration
CONFIG = YAML.load_file(File.expand_path("../extension.yml", __dir__))
EXTENSION_ID = CONFIG.dig("extension", "id")
VERSION_FILE = "SOURCE/#{EXTENSION_ID}/version.rb"

def current_version
  content = File.read(VERSION_FILE)
  match = content.match(/VERSION\s*=\s*"(\d+\.\d+\.\d+)"/)
  abort "Could not find VERSION in #{VERSION_FILE}" unless match
  match[1]
end

def calculate_next(current, type)
  major, minor, patch = current.split(".").map(&:to_i)
  case type.downcase
  when "major" then "#{major + 1}.0.0"
  when "minor" then "#{major}.#{minor + 1}.0"
  when "patch" then "#{major}.#{minor}.#{patch + 1}"
  else
    if type.match?(/^\d+\.\d+\.\d+$/)
      type
    else
      abort "Invalid version argument: #{type}. Use 'major', 'minor', 'patch', or 'X.Y.Z'."
    end
  end
end

abort "Usage: bump_version.rb <next|apply> <arg>" if ARGV.length < 2

command = ARGV[0]
arg = ARGV[1]

cur = current_version

if command == "next"
  puts calculate_next(cur, arg)
elsif command == "apply"
  # Validate inputs by recalculating (or verifying X.Y.Z)
  # But here we expect ARGV[1] to be the final version string passed from Rake
  new_ver = arg
  abort "Error: 'apply' expects a version string (X.Y.Z), got: #{new_ver}" unless new_ver.match?(/^\d+\.\d+\.\d+$/)

  puts ">> Bumping version: #{cur} -> #{new_ver}"

  # Update File
  content = File.read(VERSION_FILE)
  new_content = content.sub(/VERSION\s*=\s*".*"/, "VERSION = \"#{new_ver}\"")
  File.write(VERSION_FILE, new_content)
  puts ">> Updated #{VERSION_FILE}"

  # Git Operations
  puts ">> Staging files..."
  system("git add #{VERSION_FILE}") or abort "Git add failed"
  # release_notes.md is updated by Rake task prior to this script
  system("git add RELEASE_NOTES.md") or abort "Git add failed"

  puts ">> Committing..."
  system("git commit -m 'chore: release v#{new_ver}'") or abort "Git commit failed"

  puts ">> Tagging v#{new_ver}..."
  system("git tag v#{new_ver}") or abort "Git tag failed"

  puts ">> Done."
else
  abort "Unknown command: #{command}"
end
