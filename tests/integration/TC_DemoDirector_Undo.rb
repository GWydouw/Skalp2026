# frozen_string_literal: true

require "testup/testcase"
require_relative "test_helper"

module JtHyperbolicCurves
  module Tests
    class TC_DemoDirector_Undo < TestUp::TestCase
      def setup
        ensure_default_strategies
        @model = Sketchup.active_model
        
        # HARD RESET: Ensure no wrappers exist so we test creation/reversion cleanly
        @model.selection.clear
        @model.entities.clear!
        
        # Prepare mock UI
        @mock_ui = Class.new do
          attr_accessor :active, :last_params

          def set_demo_active(state)
            @active = state
          end

          def update_ui_state(params)
            @last_params = params
          end

          def update_geometry(**params)
            # Delegate to real geometry engine for accurate testing
            # But force :nested if requested, else :committed
            JtHyperbolicCurvesUI.update_geometry(**params)
          end

          def find_any_wrapper_instance
            JtHyperbolicCurvesUI.find_any_wrapper_instance
          end
        end.new

        @director = JtHyperbolicCurves::Core::DemoDirector.new(@mock_ui)
      end

      def teardown
        # Ensure director stops anything it started, just in case test crashed mid-run
        @director.stop_demo(commit: false) if @director
      end

      def test_demo_revert_on_stop
        # 1. Create initial state (An Entity)
        cpoint = @model.entities.add_cpoint([0,0,0])
        initial_ent_count = @model.entities.count
        
        # 2. Start Demo (Starts Operation "Demo Mode")
        # We need to simulate the async loop or just check the start state
        # Since start_demo calls process_next_step which uses timers, 
        # we can't easily wait for it in sync test unless we mock UI.start_timer.
        # However, start_demo does the setup synchronously before the first timer.
        
        # Monkey patch UI.start_timer to run instantly or capture id
        # For this test, we just want to verify the 'abort' mechanism.
        
        @director.start_demo
        
        # Verify an operation is active? (Hard via API)
        # But we can verify geometry was created/changed
        wrapper = JtHyperbolicCurvesUI.find_any_wrapper_instance
        assert(wrapper, "Wrapper should be created during demo start")
        
        # 3. Stop Demo (Cancel / Revert)
        # This should trigger abort_operation
        @director.stop_demo(commit: false)
        
        # 4. Assertions
        # Wrapper should be gone if it was created during demo
        # But we are inside a 'Test Setup' operation... 
        # WAIT. Nested operations are tricky.
        # If 'Test Setup' is open, and reset_demo starts 'Demo Mode'...
        # SketchUp collapses them?
        # Actually, `testup` usually wraps tests in an operation/transaction.
        # If our code calls `start_operation`, it might fail if one is open?
        # Or it might merge.
        
        # Let's verify if the wrapper persists.
        # If abort worked, it should be gone.
        
        # Note: TestUp usually runs tests inside an evaluation that might be wrapped.
        # But `abort_operation` cancels the *last* start_operation.
        
        wrapper_check = JtHyperbolicCurvesUI.find_any_wrapper_instance
        assert_nil(wrapper_check, "Wrapper should be reverted (deleted) after abort")
        
        # Check initial entity still exists
        assert(cpoint.valid?, "Initial entity should persist")
      end

      def test_demo_commit_on_finish
        # 1. Start
        @director.start_demo
        wrapper = JtHyperbolicCurvesUI.find_any_wrapper_instance
        assert(wrapper, "Wrapper created")
        
        # 2. Stop (Commit)
        @director.stop_demo(commit: true)
        
        # 3. Assertions
        # Wrapper should persist
        wrapper_check = JtHyperbolicCurvesUI.find_any_wrapper_instance
        refute_nil(wrapper_check, "Wrapper should persist after commit")
        
        # Undo stack check?
        # We can't easily check undo stack string via API.
        # But persistence proves commit worked (or at least didn't abort).
      end
    end
  end
end
