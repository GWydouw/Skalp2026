# frozen_string_literal: true

# ==============================================================================
# SketchUp Extension Scaffold - Rakefile
# ==============================================================================
# This is the main entry point for development tasks.
# Individual task domains are split into tasks/*.rake files.
#
# Extension-specific settings are loaded from extension.yml.
# See docs/SCAFFOLD_GUIDE.md for customization instructions.

require "fileutils"
require "open3"
require "yaml"
require "bundler/setup"
require "rake"

# ==============================================================================
# CONFIGURATION
# ==============================================================================
module OS
  def self.windows?
    (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
  end

  def self.mac?
    (/darwin/ =~ RUBY_PLATFORM) != nil
  end
end

module Config
  # Load extension configuration from extension.yml
  EXTENSION_CONFIG = YAML.load_file(File.expand_path("extension.yml", __dir__)).freeze

  # Extension identity (from extension.yml)
  EXTENSION_NAME   = EXTENSION_CONFIG.dig("extension", "artifact_prefix")
  EXTENSION_ID     = EXTENSION_CONFIG.dig("extension", "id")
  EXTENSION_MODULE = EXTENSION_CONFIG.dig("extension", "module_name")

  # Toolkit version (independent of extension version)
  TOOLKIT_VERSION  = EXTENSION_CONFIG.dig("toolkit", "version")

  # Project paths
  PROJECT_ROOT   = File.expand_path(__dir__)
  SOURCE_DIR     = File.expand_path("SOURCE", __dir__)
  BUILD_DIR      = File.expand_path("BUILDS", __dir__)
  WEB_DIR        = File.expand_path("src_web", __dir__)
  SIGNED_DIR     = File.join(BUILD_DIR, "signed")

  # SketchUp Paths
  SKETCHUP_YEAR = ENV.fetch("SKETCHUP_YEAR", "2026")

  if OS.mac?
    DEFAULT_PLUGINS_DIR = File.expand_path("~/Library/Application Support/SketchUp #{SKETCHUP_YEAR}/SketchUp/Plugins")
    DEFAULT_APP_PATH    = "/Applications/SketchUp #{SKETCHUP_YEAR}/SketchUp.app"
  elsif OS.windows?
    appdata = ENV.fetch("APPDATA", "")
    DEFAULT_PLUGINS_DIR = File.expand_path(File.join(appdata, "SketchUp", "SketchUp #{SKETCHUP_YEAR}", "SketchUp",
                                                     "Plugins"))
    prog_files = ENV.fetch("ProgramFiles", "C:/Program Files")
    DEFAULT_APP_PATH = File.join(prog_files, "SketchUp", "SketchUp #{SKETCHUP_YEAR}", "SketchUp.exe")
  else
    # Fallback/Linux (unsupported but harmless)
    DEFAULT_PLUGINS_DIR = File.expand_path("Plugins")
    DEFAULT_APP_PATH    = "sketchup"
  end

  # Allow explicit overrides
  PLUGINS_DIR  = ENV.fetch("SKETCHUP_PLUGINS", DEFAULT_PLUGINS_DIR)
  SKETCHUP_APP = ENV.fetch("SKETCHUP_PATH", DEFAULT_APP_PATH)

  # Loaders to inject for dev mode
  DEV_LOADERS = {
    "tools/debug_loader.rb" => "debug_loader.rb",
    "tests/undo_research.rb" => "undo_research.rb",
    "tools/debug_impl.rb" => "skalp_debug_impl.rb"
  }.freeze
end

# ==============================================================================
# HELPERS
# ==============================================================================
def run_cmd(cmd)
  puts ">> Running: #{cmd}"
  system(cmd) or raise "Command failed: #{cmd}"
end

# ==============================================================================
# LOAD TASK FILES
# ==============================================================================
Dir.glob("tasks/*.rake").each { |r| load r }

# ==============================================================================
# TOP-LEVEL TASKS
# ==============================================================================

desc "Default task: list available tasks"
task :default do
  puts "JT Hyperbolic Curves - Development Tasks"
  puts "----------------------------------------"
  sh "rake -T"
end

desc "Full Development Cycle (Kill -> Build Web -> Install -> Inject -> Launch)"
task dev: [
  "skp:kill", "log:clear", "test:inject_sha", "web:build",
  "install:local", "install:debug_loaders", "skp:open"
]

desc "Generate Documentation (YARD)"
task :docs do
  puts "📚 Generating Documentation..."
  sh "yard doc"
end
