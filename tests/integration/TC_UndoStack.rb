# frozen_string_literal: true

require "testup/testcase"
require_relative "test_helper"

module JtHyperbolicCurves
  module Tests
    class TC_UndoStack < TestUp::TestCase
      # Observer to count undo operations locally
      class UndoCounterObserver < Sketchup::ModelObserver
        attr_reader :transaction_count

        def initialize
          super
          @transaction_count = 0
        end

        def onTransactionStart(_model)
          @transaction_count += 1
        end

        # NOTE: Depending on SketchUp version and operation type,
        # Start/Commit might be the reliable triggers.
      end

      def setup
        ensure_default_strategies
        @observer = UndoCounterObserver.new
        Sketchup.active_model.add_observer(@observer)

        # Ensure a wrapper exists
        @wrapper = JtHyperbolicCurvesUI.find_any_wrapper_instance
        return if @wrapper

           # Create one if missing (simplified from PresetManager test)
           defs = Sketchup.active_model.definitions
           defi = defs.add("UndoTest_Wrapper")
           defi.entities.add_cpoint([0, 0, 0])
           @wrapper = Sketchup.active_model.entities.add_instance(defi, Geom::Transformation.new)
           @wrapper.set_attribute(JtHyperbolicCurvesUI::DICT_NAME, "is_wrapper", true)
      end

      def teardown
        Sketchup.active_model.remove_observer(@observer)
        @observer = nil
      end

      # Test 1: Simulate rapid slider updates (transparent)
      def test_slider_simulation
        update_count = 5 # fast

        # Start fresh count
        initial_count = @observer.transaction_count

        # Simulate rapid updates (like dragging slider)
        update_count.times do |i|
          height = 310.0 + (i * 5.0)

          # Transparent update (preview)
          JtHyperbolicCurvesUI.update_geometry(
            ref_height_cm: height,
            wrapper_instance: @wrapper,
            operation_mode: :transparent
          )
          sleep(0.01)
        end

        # Final committed update (like slider release)
        JtHyperbolicCurvesUI.update_geometry(
          ref_height_cm: 360.0,
          wrapper_instance: @wrapper,
          operation_mode: :committed
        )

        # Give a moment for observer if async (usually sync)

        final_count = @observer.transaction_count
        diff = final_count - initial_count

        # NOTE: Transparent operations DO trigger ModelObserver events (Start/Commit/Abort),
        # but if they use `start_operation(name, true)` (transparent), they shouldn't show in UI Undo Stack.
        # Ideally we want to check the UI Undo stack, but API doesn't expose that easily.
        # However, checking that we *generated* the calls is a basic sanity check.
        # The key logic update was that we shouldn't have *broken* the geometry generation.

        assert(diff >= 1, "Should have triggered at least one transaction")
      end

      # Test 2: Multiple separate updates
      def test_multiple_updates
        update_count = 3
        initial_count = @observer.transaction_count

        update_count.times do |i|
          JtHyperbolicCurvesUI.update_geometry(
            ref_height_cm: 310.0 + (i * 10.0),
            wrapper_instance: @wrapper,
            operation_mode: :committed
          )
        end

        final_count = @observer.transaction_count
        diff = final_count - initial_count

        # Each committed update is 1 transaction
        assert_equal(update_count, diff, "Each committed update should be a transaction")
      end

      # Test 3: Transparent-only updates
      def test_transparent_only
        update_count = 3
        initial_count = @observer.transaction_count

        update_count.times do |i|
          JtHyperbolicCurvesUI.update_geometry(
            ref_height_cm: 310.0 + (i * 5.0),
            wrapper_instance: @wrapper,
            operation_mode: :transparent
          )
        end

        final_count = @observer.transaction_count
        diff = final_count - initial_count

        # They ARE transactions, just transparent ones.
        assert_equal(update_count, diff, "Transparent updates are still transactions (just hidden from UI)")
      end
    end
  end
end
