# frozen_string_literal: true

require "sketchup"

module JtHyperbolicCurves
  module Tests
    # Helper for displaying non-modal interactive test instructions
    class InteractiveTestUI
      def initialize(title)
        @dialog = UI::HtmlDialog.new(
          {
            dialog_title: title,
            preferences_key: "com.jt.hyperbolic.tests.interactive",
            scrollable: true,
            resizable: true,
            width: 450,
            height: 350,
            left: 100,
            top: 100,
            min_width: 300,
            min_height: 200,
            style: UI::HtmlDialog::STYLE_DIALOG
          }
        )
      end

      def show(instructions, on_pass, on_fail)
        # Simple styling
        css = <<~CSS
          body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; padding: 20px; color: #333; }
          .instructions { margin-bottom: 25px; line-height: 1.5; font-size: 14px; }
          .buttons { display: flex; justify-content: flex-end; gap: 10px; border-top: 1px solid #eee; padding-top: 20px; }
          button { padding: 8px 20px; cursor: pointer; border: none; border-radius: 3px; font-weight: 600; font-size: 13px; }
          .pass { background-color: #4CAF50; color: white; }
          .pass:hover { background-color: #45a049; }
          .fail { background-color: #f44336; color: white; }
          .fail:hover { background-color: #d32f2f; }
        CSS

        html = <<~HTML
          <!DOCTYPE html>
          <html>
          <head>
            <style>#{css}</style>
          </head>
          <body>
            <div class="instructions">
              #{instructions}
            </div>
            <div class="buttons">
              <button class="fail" onclick="sketchup.onFail()">Fail</button>
              <button class="pass" onclick="sketchup.onPass()">Pass</button>
            </div>
            <script>
              window.sketchup = {
                onPass: function() { window.location = 'skp:on_pass'; },
                onFail: function() { window.location = 'skp:on_fail'; }
              }
            </script>
          </body>
          </html>
        HTML

        @dialog.set_html(html)

        @dialog.add_action_callback("on_pass") do |_action_context|
          @dialog.close
          on_pass.call
        end

        @dialog.add_action_callback("on_fail") do |_action_context|
          @dialog.close
          on_fail.call
        end

        @dialog.show
      end
    end
  end
end
