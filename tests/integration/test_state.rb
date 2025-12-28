# frozen_string_literal: true

module JtHyperbolicCurves
  module Tests
    # Shared state to track if a manual test dialog is currently open.
    # This prevents the final Verification dialog from spamming over active tests.
    module VerificationState
      @active_manual_test = false

      def self.active_manual_test?
        @active_manual_test
      end

      def self.set_active_manual_test(state)
        @active_manual_test = state
      end
    end
  end
end
