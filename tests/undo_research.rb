# frozen_string_literal: true

# undo_research.rb
# Injected by `rake dev`

require "sketchup"

# Try to load config
begin
  require "jt_debug_config"
rescue LoadError
  # Fallback if running manually/testing without injection
  module JtHyperbolicCurves
    module DebugConfig
      PROJECT_ROOT = nil
    end
  end
end

module JtHyperbolicCurves
  module UndoResearch
    MENU_NAME = "🧪 Undo Research"

    def self.init
      menu = UI.menu("Plugins").add_submenu(MENU_NAME)

      menu.add_item("Test 1: Standard Commits") { run_test(:test_standard) }
      menu.add_item("Test 2: Transparent Sequence") { run_test(:test_transparent_sequence) }
      menu.add_item("Test 3: Transparent Only") { run_test(:test_transparent_only) }
      menu.add_item("Test 4: Merge Previous") { run_test(:test_merge_previous) }
      menu.add_item("Test 5: Abort Operation") { run_test(:test_abort) }
      menu.add_item("Test 6: Demo Mode Revert (NEW)") { run_test(:test_demo_flow) }
      menu.add_separator
      menu.add_item("RUN ALL & LOG") { run_all_tests }

      console_log "Loaded. Project Root: #{DebugConfig::PROJECT_ROOT || 'Not Set'}"
    end

    def self.log_file_path
      return nil unless DebugConfig::PROJECT_ROOT

      File.join(DebugConfig::PROJECT_ROOT, "test_logs", "undo_research.log")
    end

    def self.file_log(msg)
      path = log_file_path
      return unless path

      File.open(path, "a") do |f|
        f.puts "[#{Time.now.strftime('%H:%M:%S')}] #{msg}"
      end
    rescue StandardError => e
      puts "Log Error: #{e}"
    end

    def self.console_log(msg)
      # puts "[UndoResearch] #{msg}"
      file_log(msg)
    end

    def self.run_test(method_name)
      file_log "----------------------------------------"
      console_log "STARTING: #{method_name}"
      send(method_name)
      console_log "FINISHED: #{method_name}"
      file_log "----------------------------------------"
    end

    # ==========================================================
    # Integration Tests (Simulating Extension Logic)
    # ==========================================================

    class MockDialog
      def add_action_callback(name, &block)
        @callbacks ||= {}
        @callbacks[name] = block
      end

      def execute_callback(name, param)
        if @callbacks && @callbacks[name]
          @callbacks[name].call(self, param)
        else
          puts "[MockDialog] Callback '#{name}' not found."
        end
      end

      def center; end
      def show; end
      def execute_script(script); end
      def close; end
    end

    def self.test_undo_sync_integrity
      file_log "=== INTEGRATION TEST: UNDO SYNC INTEGRITY ==="
      console_log "Running Undo Sync Integrity Test..."

      model = Sketchup.active_model
      model.selection.clear
      model.entities.clear!

      # 1. ANCHOR (Standard Commit)
      # Note: update_geometry manages its own start/commit_operation.
      # Wrapping it here causes "New operation started while existing open" warning.
      JtHyperbolicCurvesUI.update_geometry(
        ref_height_cm: 300.0,
        instances_count: 20,
        operation_mode: :committed
      )

      wrapper_inst = JtHyperbolicCurvesUI.find_any_wrapper_instance
      ent_count_anchor = wrapper_inst.definition.entities.count
      console_log "Step 1 (Anchor): Created. Ents: #{ent_count_anchor}"
      file_log "Step 1 (Anchor): Created. Ents: #{ent_count_anchor}"

      # 2. SLIDER START (Geometry Guard - Transparent)
      # This mimicks ui_dialog.rb:815 start_operation(..., true, true, false)
      model.start_operation("Interaction Guard", disable_ui: true, transparent: true, prev_transparent: false)
      cpoint = model.active_entities.add_cpoint(ORIGIN)
      cpoint.set_attribute("JtHyperbolicCurves", "guard_point", true)
      cpoint.hidden = true
      model.commit_operation
      console_log "Step 2 (Guard): Created & Committed (Transparent)."

      # 3. SLIDER DRAG (Transparent x2)
      # T1 - Direct call, blindly trusts core.rb to handle start_operation(:transparent)
      JtHyperbolicCurvesUI.update_geometry(
        ref_height_cm: 300.0,
        instances_count: 15,
        wrapper_instance: wrapper_inst,
        operation_mode: :transparent
      )
      console_log "Step 3 (Drag T1): Instances=15"

      # T2
      JtHyperbolicCurvesUI.update_geometry(
        ref_height_cm: 300.0,
        instances_count: 10,
        wrapper_instance: wrapper_inst,
        operation_mode: :transparent
      )
      console_log "Step 4 (Drag T2): Instances=10"

      # T3 (Merged Final)
      # This logic in core.rb should squash T2+T1+Guard into one step.
      JtHyperbolicCurvesUI.update_geometry(
        ref_height_cm: 300.0,
        instances_count: 5,
        wrapper_instance: wrapper_inst,
        operation_mode: :merged
      )
      ent_count_final = wrapper_inst.definition.entities.count
      console_log "Step 5 (Release/Merged): Instances=5. Ents: #{ent_count_final}"
      file_log "Step 5 (Release): Instances=5. Ents: #{ent_count_final}"

      # VERIFICATION

      # Undo 1: Should revert to Anchor (Instances=20)
      console_log "Performing Undo 1..."
      Sketchup.undo

      wrapper_check = JtHyperbolicCurvesUI.find_any_wrapper_instance

      if wrapper_check.nil?
        console_log "❌ FAIL: Wrapper GONE after 1 Undo!"
        file_log "FAIL: Wrapper GONE after 1 Undo"
      else
        current_ents = wrapper_check.definition.entities.count
        current_inst = JtHyperbolicCurves::ModelStore.load_params_from_wrapper(wrapper_check)[:instances_count]

        console_log "Post-Undo State: Ents=#{current_ents}, Instances=#{current_inst}"
        file_log "Post-Undo State: Ents=#{current_ents}, Instances=#{current_inst}"

        if current_ents == ent_count_anchor && current_inst == 20
          console_log "✅ PASS: Reverted to Anchor State correctly."
          file_log "PASS: Reverted to Anchor State"
        else
          console_log "❌ FAIL: State mismatch! Expected 20 instances, got #{current_inst}."
          file_log "FAIL: State mismatch. Expected 20, got #{current_inst}"
        end
      end
    end

    def self.run_all_tests
      console_log "=== RUNNING ALL TESTS ==="
      # Clear log file
      File.write(log_file_path, "=== UNDO RESEARCH LOG START ===\n") if log_file_path

      test_undo_sync_integrity

      # Optional: run others if needed, but Test Flow is the main one now.
      # run_test(:test_standard)

      console_log "=== ALL TESTS COMPLETED. CHECK LOGS. ==="
      # UI.messagebox("Automated Verification Complete.\nCheck Ruby Console or Log File.")
    end

    def self.reset_box
      model = Sketchup.active_model
      model.selection.clear
      model.entities.clear!

      # Draw initial box (Anchor)
      model.start_operation("Init Box", true)
      group = model.entities.add_group
      group.entities.add_face([0, 0, 0], [10, 0, 0], [10, 10, 0], [0, 10, 0]).pushpull(-10)
      console_log "Reset: Created 10x10x10 Box."
      model.commit_operation
      group
    end

    # CASE 1: Standard
    # Expected: Undo C -> B. Undo B -> A.
    def self.test_standard
      console_log "Running Test 1..."
      group = reset_box

      # Step B
      model = Sketchup.active_model
      model.start_operation("Step B (Scale)", true)
      t = Geom::Transformation.scaling(2.0)
      group.transform!(t)
      model.commit_operation
      console_log "Committed Step B (Scale 2x)."

      # Step C
      model.start_operation("Step C (Move)", true)
      t = Geom::Transformation.translation([20, 0, 0])
      group.transform!(t)
      model.commit_operation
      console_log "Committed Step C (Move 20)."

      console_log "Test 1 Complete. Try Undoing twice."
    end

    # CASE 2: Transparent Sequence
    # This simulates our Slider Drag: Many transparents, then one commit?
    # Actually, our slider does: Transp, Transp, Transp...
    # The LAST one is "Committed".
    # Expected: Undo should revert ALL T's and the Commit to state A?
    def self.test_transparent_sequence
      console_log "Running Test 2 (Simulating Slider)..."
      group = reset_box
      model = Sketchup.active_model

      # T1
      model.start_operation("T1 (Move 5)", true, false, true) # 4th param: transparent
      group.transform!(Geom::Transformation.translation([5, 0, 0]))
      model.commit_operation
      console_log "Committed T1 (Transparent)."

      # Wait a bit to simulate drag
      sleep(0.5)

      # T2
      model.start_operation("T2 (Move 5)", true, false, true)
      group.transform!(Geom::Transformation.translation([5, 0, 0]))
      model.commit_operation
      console_log "Committed T2 (Transparent)."

      sleep(0.5)

      # Final Commit (The Mouse Release)
      # In our code: operation_mode: :committed
      # model.start_operation(op_name, true, false, false)

      model.start_operation("Final Commit (Move 5)", true, false, false) # Not transparent
      group.transform!(Geom::Transformation.translation([5, 0, 0]))
      model.commit_operation
      console_log "Committed Final (Standard)."

      console_log "Test 2 Complete. Expected: Total Move = 15. One Undo should revert ALL 15?"
      # If T1 and T2 were transparent, they are not on stack.
      # But they modified the model!
      # Does "Final Commit" capture the delta from T2 -> Final?
      # Or does it capture current state?
      # If undoing Final reverts to T2... and T2 is not on stack...
      # This is the crucial question.
    end

    # CASE 3: Transparent Only
    # What if we never commit?
    def self.test_transparent_only
      console_log "Running Test 3..."
      group = reset_box
      model = Sketchup.active_model

      model.start_operation("T1 (Up 10)", true, false, true)
      group.transform!(Geom::Transformation.translation([0, 0, 10]))
      model.commit_operation
      console_log "Committed T1 (Transparent)."

      console_log "Test 3 Complete. Check Undo Stack. Should NOT have 'T1'."
      # If I Undo 'Init Box', what happens to the move?
    end

    # CASE 4: Merge Previous
    # This uses the 3rd argument `next_transparent` (Merge with previous)
    def self.test_merge_previous
      console_log "Running Test 4..."
      group = reset_box
      model = Sketchup.active_model

      # Step A
      model.start_operation("Step A (Scale)", true)
      group.transform!(Geom::Transformation.scaling(1.5))
      model.commit_operation
      console_log "Committed Step A."

      # Step B (Merge)
      # NOTE: This API arg is confusing.
      # Arg 3: next_transparent. "If true, the NEXT operation will be appended to this one."
      # WAIT. Docs say: "If true, this operation should be merged with the previous one."
      # Let's test "true".

      model.start_operation("Step B (Merge? Move)", true, true, false)
      group.transform!(Geom::Transformation.translation([0, 20, 0]))
      model.commit_operation
      console_log "Committed Step B (Merge=true)."

      console_log "Test 4 Complete. Undo should revert BOTH A and B in one step?"
    end

    def self.test_abort
       console_log "Running Test 5..."
       group = reset_box
       model = Sketchup.active_model

       model.start_operation("Going to Abort", true)
       group.transform!(Geom::Transformation.translation([0, 0, 50]))
       puts "Moved box... now aborting."
       model.abort_operation
       console_log "Aborted. Box should be back at origin."
    end

    # CASE 6: Demo Flow Integration (Proposed Architecture)
    def self.test_demo_flow
      console_log "Running Test 6: Demo Director Logic..."
      model = Sketchup.active_model
      model.selection.clear
      model.entities.clear!
      
      # 1. Start with an Anchor
      cpoint = model.entities.add_cpoint(ORIGIN)
      cpoint.set_attribute(JtHyperbolicCurvesUI::DICT_NAME, "is_anchor", true)
      ent_count_start = model.entities.count
      console_log "Start: #{ent_count_start} entities."

      # 2. Setup Mock UI logic just like in TC_DemoDirector_Undo
      mock_ui = MockDialog.new
      
      # We need real geometry updates to populate standard defaults?
      # Or we let DemoDirector auto-create wrapper.
      # Stub update_geometry to delegate to real one
      mock_ui.add_action_callback("update_geometry") do |_, params| 
        # CAUTION: We must respect the :nested mode or we crash
        # Core code handles this now.
        JtHyperbolicCurvesUI.update_geometry(**params) 
      end
      
      # DemoDirector expects an object responding to update_geometry, set_demo_active etc.
      # Create a simple delegator
      ui_shim = Class.new do
        def initialize(real_ui_mod); @ui = real_ui_mod; end
        def set_demo_active(state); puts "UI: Demo Active=#{state}"; end
        def update_ui_state(params); end
        def update_geometry(**params); @ui.update_geometry(**params); end
      end.new(JtHyperbolicCurvesUI)
      
      director = JtHyperbolicCurves::Core::DemoDirector.new(ui_shim)
      
      # 3. START DEMO
      # This calls start_operation("Demo Mode").
      console_log "Action: Starting Demo..."
      director.start_demo
      
      # Check if wrapper created?
      wrapper = JtHyperbolicCurvesUI.find_any_wrapper_instance
      if wrapper
        console_log "✓ Wrapper auto-created inside Demo OP."
      else
        console_log "❌ Wrapper NOT created!"
      end
      
      # 4. STOP DEMO (Simulation of Cancel)
      # Should call abort_operation
      console_log "Action: Stopping Demo (Cancel)..."
      director.stop_demo(commit: false)
      
      # 5. Verify Revert
      wrapper_check = JtHyperbolicCurvesUI.find_any_wrapper_instance
      ent_count_end = model.entities.count
      
      if wrapper_check.nil? && ent_count_end == ent_count_start
        console_log "✅ PASS: Demo Reverted. Wrapper gone. Entity count matches start."
        UI.messagebox("Test 6 PASSED:\nDemo started, wrapper created,\nthen stopped (aborted).\nWrapper successfully reverted.")
      else
         msg = "❌ FAIL: Revert failed.\nWrapper: #{wrapper_check}\nEnts: #{ent_count_end} (expected #{ent_count_start})"
         console_log msg
         UI.messagebox(msg)
      end
    end
  end
end

JtHyperbolicCurves::UndoResearch.init
