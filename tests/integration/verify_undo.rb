# frozen_string_literal: true

# Integration Test: Verify Undo Logic
# Load this file in SketchUp Ruby Console:
# load "/path/to/project/tests/integration/verify_undo.rb"

module JtHyperbolicCurves
  module Verification
    # Patch Debug to print logs to Console
    module Debug
      def self.log(msg)
        puts "[Debug] #{msg}"
      end
    end
    
    extend self

    def run
      puts "=== STARTING UNDO VERIFICATION ==="
      model = Sketchup.active_model
      
      # 1. Clear model
      model.start_operation("Clear Model", true)
      model.entities.clear!
      model.commit_operation
      puts "Step 1: Cleared Model."

      # 2. Create Anchor (Initial State)
      JtHyperbolicCurvesUI.update_geometry(
        ref_height_cm: 300.0,
        instances_count: 5,
        operation_mode: :committed
      )
      
      wrapper = JtHyperbolicCurvesUI.find_any_wrapper_instance
      unless wrapper
        puts "❌ ERROR: Failed to create initial wrapper."
        return
      end
      
      ent_count_initial = wrapper.definition.entities.count
      puts "Step 2: Created Anchor. Entities: #{ent_count_initial}"

      # 3. Simulate Interactive Update (Guard -> Transparent -> Committed)
      # We simulate a "Drag" sequence as performed by ui_bridge.rb
      
      # 3a. GUARD (Start of Interaction)
      # This operation acts as a buffer. The subsequent transparent ops will merge into THIS one.
      # Start as a standard operation (not transparent, not merged yet).
      # Args: name, disable_ui, transparent, prev_transparent
      model.start_operation("Interactive Update (Guard)", true, false, false)
      # Force a modification so the commit counts
      model.active_entities.add_cpoint(ORIGIN).hidden = true
      model.commit_operation
      puts "Step 3a: Created Interaction Guard."

      # 3b. T1 (Simulate Drag)
      # This should merge with the Guard (3a) because it uses :transparent
      JtHyperbolicCurvesUI.update_geometry(
        ref_height_cm: 300.0,
        instances_count: 10,
        wrapper_instance: wrapper,
        operation_mode: :transparent
      )
      puts "Step 3b: Dragged to 10 instances (Transparent)."
      
      # 3c. Final Commit (Simulate Release)
      # This starts a NEW operation but merges with previous, sealing 3a+3b.
      JtHyperbolicCurvesUI.update_geometry(
        ref_height_cm: 300.0,
        instances_count: 15,
        wrapper_instance: wrapper,
        operation_mode: :merged
      )
      
      wrapper = JtHyperbolicCurvesUI.find_any_wrapper_instance
      ent_count_final = wrapper.definition.entities.count
      puts "Step 3: Updated. Entities: #{ent_count_final} (Instances: 15)"

      if ent_count_final == ent_count_initial
        puts "⚠️ WARNING: improved geometry might have same entity count? Unlikely."
      end

      # 4. PERFORM UNDO
      puts "Step 4: Performing Undo..."
      Sketchup.undo

      # 5. VERIFY
      wrapper_check = JtHyperbolicCurvesUI.find_any_wrapper_instance
      
      if wrapper_check.nil?
        puts "❌ FAIL: Wrapper disappeared after Undo!"
        UI.messagebox("FAIL: Wrapper disappeared.")
        return
      end
      
      # Check parameters
      instances = JtHyperbolicCurvesUI::ModelStore.load_params_from_wrapper(wrapper_check)[:instances_count]
      ent_count_check = wrapper_check.definition.entities.count
      
      puts "Post-Undo State: Instances=#{instances}, Ents=#{ent_count_check}"
      
      if instances == 5
        puts "✅ PASS: Successfully reverted to initial state (5 instances)."
        UI.messagebox("VERIFICATION PASSED:\nUndo correctly reverted model to initial state.")
      else
        puts "❌ FAIL: Expected 5 instances, got #{instances}."
        UI.messagebox("FAIL: Undo did not revert correctly.\nExpected 5, got #{instances}.")
      end
      
      puts "=== VERIFICATION COMPLETE ==="
    end
  end
end

JtHyperbolicCurves::Verification.run
