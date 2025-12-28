# frozen_string_literal: true

require "testup/testcase"
require_relative "test_helper"

module JtHyperbolicCurves
  module Tests
    class TC_ShapeRegistry < TestUp::TestCase
      def setup
        # Clear strategies before each test to ensure isolation
        # We need to access the module variable, but ShapeRegistry doesn't expose a clear method.
        # However, `strategies` returns the hash object, so we can clear it.
        JtHyperbolicCurves::Core::ShapeRegistry.strategies.clear
      end

      def teardown
        JtHyperbolicCurves::Core::ShapeRegistry.strategies.clear
      end

      # Mock strategy for testing
      MockStrategy = Struct.new(:id, :name)

      def test_strategies_starts_empty
        assert_empty(JtHyperbolicCurves::Core::ShapeRegistry.strategies)
      end

      def test_register_strategy
        strategy = MockStrategy.new(:test_id, "Test Strategy")
        JtHyperbolicCurves::Core::ShapeRegistry.register(strategy)

        refute_empty(JtHyperbolicCurves::Core::ShapeRegistry.strategies)
        assert_equal(strategy, JtHyperbolicCurves::Core::ShapeRegistry.get(:test_id))
      end

      def test_get_nonexistent_strategy
        assert_nil(JtHyperbolicCurves::Core::ShapeRegistry.get(:nonexistent))
      end

      def test_list_names
        s1 = MockStrategy.new(:s1, "Strategy One")
        s2 = MockStrategy.new(:s2, "Strategy Two")

        JtHyperbolicCurves::Core::ShapeRegistry.register(s1)
        JtHyperbolicCurves::Core::ShapeRegistry.register(s2)

        names = JtHyperbolicCurves::Core::ShapeRegistry.list_names

        assert_kind_of(Hash, names)
        assert_equal(2, names.size)
        assert_equal("Strategy One", names[:s1])
        assert_equal("Strategy Two", names[:s2])
      end
    end
  end
end
