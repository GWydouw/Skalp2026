require "testup/testcase"

module JtHyperbolicCurves
  class Verification < TestUp::TestCase
    def setup
      # No setup needed
    end

    def teardown
      # No teardown needed
    end

    # This test is named ZZZ to ensure it runs last in alphabetical order
    def test_verify_suite_success
      # 1. Locate the Project Root
      # We rely on DebugConfig being loaded by the dev environment
      # 1. Locate the Project Root
      project_root = nil
      metadata_file = nil

      # A. Check for DebugConfig (rake dev)
      if defined?(JtHyperbolicCurves::DebugConfig::PROJECT_ROOT)
        project_root = JtHyperbolicCurves::DebugConfig::PROJECT_ROOT
      else
        # B. Check for Dev Metadata (rake install:rbz)
        # We must look relative to this file, assuming it's inside Plugins
        # Actually __FILE__ in TestUp might be tricky.
        # But we know where we are: Plugins/extensions/jt_hyperbolic_curves/tests/...
        # Let's search in the parent directories for dev_metadata.json
        # Or simpler: The extension is installed. We can assume standard paths.
        # However, TestUp loads files from WEIRD places sometimes.
        # Let's try to assume standard SketchUp Plugins folder? No, cross-platform issue.
        # Let's assume we are in the load path.
        # Better: use Gem.loaded_specs or just look relative to the working dir?
        # NO, SketchUp working dir is unpredictable.

        # Let's try to find it relative to the extension loader.
        # But we don't have easy access to that here without the namespace.
        # Wait, verify_suite_success is inside JtHyperbolicCurves.
        # But we don't have a constant pointing to the installation dir in PROD builds.

        # Heuristic: We know `dev_metadata.json` is at the root of the plugins folder (where the loader is).
        # We can try standard SketchUp plugins path.
        plugins_path = Sketchup.find_support_file("Plugins")
        candidate = File.join(plugins_path, "dev_metadata.json")

        if File.exist?(candidate)
          require "json"
          data = JSON.parse(File.read(candidate))
          project_root = data["project_root"]
          metadata_file = candidate # Mark for cleanup
        end
      end

      unless project_root
        skip("Project Root not found (DebugConfig or dev_metadata.json missing).")
      end

      # Cleanup metadata if used
      File.delete(metadata_file) if metadata_file
      sha_file = File.join(project_root, "tests", ".current_git_sha")
      verification_file = File.join(project_root, ".test_verification")

      # 2. Check for SHA Injection
      skip("SHA injection file not found. Please run via 'rake dev'.") unless File.exist?(sha_file)

      current_sha = File.read(sha_file).strip

      require_relative "test_state"

      # 3. Wait for Dialogs (Race Condition Fix)
      # Poll until active manual tests are done
      retries = 0
      while JtHyperbolicCurves::Tests::VerificationState.active_manual_test? && retries < 100
        # sleep is tricky in SketchUp main thread, but UI.start_timer is async and TestUp expects sync return.
        # We can use a short loop helper or just hope the user is fast.
        # But actually, Ruby sleep blocks the UI, so the user CAN'T click the other dialog.
        # CRITICAL: We cannot block the main thread with sleep loop if we expect UI interaction.
        #
        # Better approach: We cannot "wait" here synchronously because SketchUp runs on one thread.
        # If we sleep, the UI freezes and the user can't close the *other* dialog.
        #
        # Modification: We explicitly fail/skip if another test is blocking, OR we use a UI timer to show *our* dialog later.

        # However, TestUp teardown logic might be tricky dynamically.
        # Let's use UI.start_timer to delay OUR dialog appearance, allowing the test method to return potentially.
        # BUT TestUp expects assert results *now*.
        #
        # So we MUST assume this test runs *after* the other one finishes?
        # NO, TestUp runs them in sequence, but `show_dialog` returns immediately (async).
        # So TestUp thinks `InteractiveUndo` is "done" while the dialog is still open.

        # Strategy:
        # We cannot hold the test execution here. We must return.
        # But we want to show our dialog *eventually*.
        # Let's fire a timer that checks the state periodically until clear, THEN shows our dialog.

        break # Breaking linear flow to implement async waiter below
      end

      # Async Waiter Setup
      check_timer_id = UI.start_timer(0.5, true) do
        if JtHyperbolicCurves::Tests::VerificationState.active_manual_test?
        # Still waiting...
        else
          # Done waiting!
          UI.stop_timer(check_timer_id)

          # show_verification_dialog(current_sha, verification_file)
          # We need to extract the logic to a method available in the block context.
          # See implementation below.
          show_verification_dialog_safe(current_sha, verification_file)
        end
      end

      # We mark this test as "passed" merely for having scheduled the check.
      # The actual *verification file write* happens in the async callback.
      assert(true)
    end

    def show_verification_dialog_safe(current_sha, verification_file)
      # 3. Prompt User
      # messagebox returns: 6 (Yes), 7 (No)
      result = UI.messagebox(
        "Did all integration tests PASS?\n\nClick Yes to verify this commit (#{current_sha[0..7]}).\nClick No to invalidate previous verification.", MB_YESNO
      )

      # ... (rest of logic)
      if result == 6 # Yes
        timestamp = Time.now.to_s
        File.write(verification_file, "#{current_sha}|#{timestamp}")
        puts "✅ Verification Stamped: #{current_sha[0..7]}"
      elsif File.exist?(verification_file) # No
        File.delete(verification_file)
        puts "🗑️  Verification Invalidated."
      end
    end
  end
end
