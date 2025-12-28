# frozen_string_literal: true

# Start SimpleCov for code coverage analysis
require "simplecov"
SimpleCov.start do
  add_filter "/tests/"
  add_filter "/vendor/"
  
  add_group "Source", "SOURCE"
end

require "minitest/autorun"

# Load Mock SketchUp API
require_relative "sketchup"
$LOAD_PATH.unshift(__dir__)
$LOAD_PATH.unshift(File.expand_path("../../SOURCE", __dir__))

# Load Extension
# This assumes the main loader is in SOURCE/AW_MultiTags.rb
require_relative "../../SOURCE/Skalp_Skalp2026"
