# frozen_string_literal: true

require "testup/testcase"

module JtHyperbolicCurves
  module Tests
    # This module receives the path to the tests when TestUp discovers them.
    # We can use this to locate support files.
    def self.tests_path
      @tests_path
    end

    def self.tests_path=(path)
      @tests_path = path
    end
  end
end

# Tests are located in: SOURCE/jt_hyperbolic_curves/tests/test_helper.rb
# Root of extension is: SOURCE/jt_hyperbolic_curves/

# Adjust paths relative to this file
# Adjust paths relative to this file
require_relative "../../SOURCE/jt_hyperbolic_curves/core" # SOURCE/jt_hyperbolic_curves/core.rb
require_relative "../../SOURCE/jt_hyperbolic_curves/core/geometry_engine" # SOURCE/jt_hyperbolic_curves/core/geometry_engine.rb
require_relative "../../SOURCE/jt_hyperbolic_curves/preset_manager"       # SOURCE/jt_hyperbolic_curves/preset_manager.rb
require_relative "../../SOURCE/jt_hyperbolic_curves/ui_dialog" # SOURCE/jt_hyperbolic_curves/ui_dialog.rb

module TestUp
  class TestCase
    def ensure_default_strategies
      return if JtHyperbolicCurves::Core::ShapeRegistry.get(:hyperbolic)

      JtHyperbolicCurves::Core::ShapeRegistry.register(JtHyperbolicCurves::Shapes::HyperbolicCurve.new)
    end
  end
end
