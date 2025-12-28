# frozen_string_literal: true

require "testup/testcase"
require_relative "test_helper"
require_relative "test_state"
require_relative "interactive_ui"

module JtHyperbolicCurves
  module Tests
    class TC_InteractiveUndo < TestUp::TestCase
      # Disable transaction wrapping so changes persist for user verification after test returns
      def self.run_in_transaction?
        false
      end

      def setup
        ensure_default_strategies

        # Ensure a wrapper exists
        @wrapper = JtHyperbolicCurvesUI.find_any_wrapper_instance
        return if @wrapper

        defs = Sketchup.active_model.definitions
        defi = defs.add("InteractiveUndo_Wrapper")
        defi.entities.add_cpoint([0, 0, 0])
        @wrapper = Sketchup.active_model.entities.add_instance(defi, Geom::Transformation.new)
        @wrapper.set_attribute(JtHyperbolicCurvesUI::DICT_NAME, "is_wrapper", true)
      end

      def test_verify_undo_stack_visually
        # 1. Perform Transparent Update
        JtHyperbolicCurvesUI.update_geometry(
          ref_height_cm: 400.0,
          wrapper_instance: @wrapper,
          operation_mode: :transparent
        )

        # 2. Perform Committed Update
        JtHyperbolicCurvesUI.update_geometry(
          ref_height_cm: 450.0,
          wrapper_instance: @wrapper,
          operation_mode: :committed
        )

        instructions = "<b>Manual Verification Required:</b><br><br>" \
                       "1. Check the SketchUp <b>Edit</b> menu.<br>" \
                       "2. It SHOULD say <b>'Undo Hyperbolic Curves'</b>.<br>" \
                       "3. Try Undoing. It should revert the shape.<br><br>" \
                       "If this works, click <b>Pass</b>.<br>" \
                       "If the menu is incorrect or grayed out, click <b>Fail</b>."

        # Keep wrapper reference for callback closure
        wrapper_to_clean = @wrapper

        pass_callback = lambda do
          puts "[InteractiveTest] Passed by User."
          Sketchup.active_model.entities.erase_entities(wrapper_to_clean) if wrapper_to_clean.valid?
          JtHyperbolicCurves::Tests::VerificationState.set_active_manual_test(false)
        end

        fail_callback = lambda do
          puts "[InteractiveTest] Failed by User."
          UI.messagebox("Test Failed: User indicated Undo stack was incorrect.")
          Sketchup.active_model.entities.erase_entities(wrapper_to_clean) if wrapper_to_clean.valid?
          JtHyperbolicCurves::Tests::VerificationState.set_active_manual_test(false)
        end

        # Flag as active BEFORE showing dialog
        JtHyperbolicCurves::Tests::VerificationState.set_active_manual_test(true)

        dialog = JtHyperbolicCurves::Tests::InteractiveTestUI.new("Verify Undo Stack")
        dialog.show(instructions, pass_callback, fail_callback)

        # Mark test as skipped so it shows as Yellow in TestUp results,
        # indicating that manual action is required via the popup.
        skip("Manual Verification Required - Check Popup")
      end
    end
  end
end
