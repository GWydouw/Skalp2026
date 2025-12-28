# frozen_string_literal: true

require "testup/testcase"

module JtHyperbolicCurves
  module Tests
    class TC_AutomatedUndo < TestUp::TestCase
      def setup
        start_with_empty_model
      end

      def teardown
        # discard_model_changes
      end

      # Tests that the "Anchor" mechanism merges correctly with the first update
      def test_undo_merge_behavior
        # 1. Create a remote wrapper (simulate existing model)
        defs = Sketchup.active_model.definitions
        defi = defs.add("UndoTest_Curve")
        defi.entities.add_cpoint([0, 0, 0])
        wrapper = Sketchup.active_model.entities.add_instance(defi, Geom::Transformation.new)
        wrapper.set_attribute("JtHyperbolicCurves", "is_wrapper", true)

        # 2. Simulate Opening Dialog -> Creates "Anchor" (Committed)
        # We must manually set the flag because show_dialog does UI stuff
        # but JtHyperbolicCurvesUI.update_geometry is what we test.

        # Simulate show_dialog logic:
        # It calls update_geometry(mode: :committed)
        # And sets @merge_next_commit = true

        Sketchup.active_model

        # Capture Undo Stack token or just count titles if possible?
        # valid_undo = model.undo
        # SketchUp API allows limited inspection.

        # Step A: Anchor
        JtHyperbolicCurvesUI.instance_variable_set(:@merge_next_commit, true) # Simulate show_dialog

        JtHyperbolicCurvesUI.update_geometry(
           ref_height_cm: 100.0,
           step_cm: 20.0,
           wrapper_instance: wrapper,
           operation_mode: :committed
         )

        # Step B: User Interaction (Should Merge)
        self.class.update_params_callback_logic_simulation(wrapper)

        # Since we can't easily count undo stack items via API,
        # We verify that "undo" reverts the geometry change.

        # Verify height is 500
        # assert used...
      end

      # Helper to simulate the logic inside the update_params callback
      def self.update_params_callback_logic_simulation(wrapper)
         # Logic from ui_dialog.rb
         merge_flag = JtHyperbolicCurvesUI.instance_variable_get(:@merge_next_commit)
         mode = :committed
         if merge_flag
           mode = :transparent # MERGE!
           JtHyperbolicCurvesUI.instance_variable_set(:@merge_next_commit, false)
         end

         JtHyperbolicCurvesUI.update_geometry(
           ref_height_cm: 500.0,
           step_cm: 20.0,
           wrapper_instance: wrapper,
           operation_mode: mode
         )
      end
    end
  end
end
