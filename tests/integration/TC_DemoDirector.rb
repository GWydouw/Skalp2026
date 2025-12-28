# frozen_string_literal: true

require "testup/testcase"
require_relative "test_helper"

module JtHyperbolicCurves
  module Tests
    class TC_DemoDirector < TestUp::TestCase
      def setup
        # Mock UI interface that responds to update_ui_state and set_demo_active
        @mock_ui = Class.new do
          attr_reader :active, :last_params

          def set_demo_active(state)
            @active = state
          end

          def update_ui_state(params)
            @last_params = params
          end

          def update_geometry(**params)
            # no-op
          end
        end.new

        @director = JtHyperbolicCurves::Core::DemoDirector.new(@mock_ui)
      end

      def test_initialization
        refute_nil(@director)
      end

      def test_cubic_easing
        # Test boundaries
        assert_equal(0.0, @director.send(:ease_in_out_cubic, 0.0))
        assert_equal(1.0, @director.send(:ease_in_out_cubic, 1.0))
        assert_equal(0.5, @director.send(:ease_in_out_cubic, 0.5))

        # Test intermediate value (accelerating)
        val_0_1 = @director.send(:ease_in_out_cubic, 0.1)
        assert_in_delta(0.004, val_0_1, 0.0001)
      end

      def test_fallback_scenario_structure
        # Access the private constant or method return
        scenario = JtHyperbolicCurves::Core::DemoDirector::FALLBACK_SCENARIO

        assert_kind_of(Array, scenario)
        refute_empty(scenario)

        first_step = scenario.first
        assert(first_step.key?(:reset) || first_step.key?(:wait))
      end

      def test_transition_builder
        # Test private method build_transition
        current = { x: 10.0, y: 20.0, flag: false }
        target  = { x: 15.0, y: 20.0, flag: true }

        steps = @director.send(:build_transition, current, target)

        assert_kind_of(Array, steps)

        # Should have found 2 changes (x and flag), y is unchanged
        # 'flag' is boolean, might be prioritized (handled as set_params typically,
        # but DemoDirector specifically handles known toggles like :secondary_enabled)
        # In this generic test, unknown keys are often ignored by animation logic,
        # so let's use real keys from the class constant

        real_current = { ref_height_cm: 300.0, secondary_enabled: false }
        real_target = { ref_height_cm: 400.0, secondary_enabled: true }

        steps = @director.send(:build_transition, real_current, real_target)

        # Should have:
        # 1. Toggle step (secondary_enabled) - instant
        # 2. Animation step (ref_height_cm) - duration

        assert_operator(steps.size, :>=, 2)

        toggle_step = steps.find { |s| s[:set_params]&.key?(:secondary_enabled) }
        refute_nil(toggle_step, "Should generate a toggle step for boolean change")
        assert_equal(true, toggle_step[:set_params][:secondary_enabled])

        anim_step = steps.find { |s| s[:param] == :ref_height_cm }
        refute_nil(anim_step, "Should generate animation step for numeric change")
        assert_equal(300.0, anim_step[:from])
        assert_equal(400.0, anim_step[:to])
      end
    end
  end
end
