module JtHyperbolicCurvesUI
  module UndoTest
    extend self

    # Simple Undo Observer
    class UndoSpy < Sketchup::ModelObserver
      attr_reader :transactions

      def initialize
        @transactions = 0
      end

      def onTransactionCommit(model)
        @transactions += 1
        # puts "📝 Transaction Committed! (Total: #{@transactions})"
      end

      def onTransactionUndo(model)
        # puts "↩️ Undo performed"
      end

      def onTransactionRedo(model)
        # puts "↪️ Redo performed"
      end
    end

    def start_monitoring
      @spy = UndoSpy.new
      Sketchup.active_model.add_observer(@spy)
      puts "👀 UndoSpy attached. Waiting for transactions..."
    end

    def stop_monitoring
      if @spy
        Sketchup.active_model.remove_observer(@spy)
        count = @spy.transactions
        @spy = nil
        puts "🛑 Monitoring stopped."
        return count
      end
      0
    end

    # Test 1: Simulate slider drag (rapid updates)
    def test_slider_simulation(update_count: 10, delay_ms: 50)
      puts "\n🧪 TEST: Slider Simulation (#{update_count} rapid updates)"
      puts "Expected: 1-2 undo entries (intermediate updates should be transparent)"

      start_monitoring

      # Get a wrapper instance (assumed one exists)
      wrapper = JtHyperbolicCurvesUI.find_selected_wrapper_instance ||
                JtHyperbolicCurvesUI.find_any_wrapper_instance

      unless wrapper
        puts "❌ ERROR: No wrapper instance found in model. Please create one first."
        return 0
      end

      # Simulate rapid drag events (Transparent)
      update_count.times do |i|
        val = 310.0 + (i * 5.0)

        # Call the update method directly as if from UI
        JtHyperbolicCurvesUI.update_geometry(
          ref_height_cm: val,
          wrapper_instance: wrapper,
          operation_mode: :transparent
        )

        sleep(delay_ms / 1000.0)
      end

      # Final committed update (like slider release)
      JtHyperbolicCurvesUI.update_geometry(
        ref_height_cm: 360.0,
        wrapper_instance: wrapper,
        operation_mode: :committed
      )

      sleep(0.5) # Wait for any pending operations

      count = stop_monitoring

      puts "\n📊 RESULT: #{count} undo entries created"
      if count <= 2
        puts "✅ PASS: Slider simulation created acceptable number of undo entries"
      else
        puts "❌ FAIL: Too many undo entries (expected ≤2, got #{count})"
      end

      count
    end

    # Test 2: Multiple separate updates
    def test_multiple_updates(update_count: 3)
      puts "\n🧪 TEST: #{update_count} separate committed updates"
      puts "Expected: #{update_count} undo entries"

      start_monitoring

      wrapper = JtHyperbolicCurvesUI.find_selected_wrapper_instance ||
                JtHyperbolicCurvesUI.find_any_wrapper_instance

      update_count.times do |i|
        JtHyperbolicCurvesUI.update_geometry(
          ref_height_cm: 310.0 + (i * 10.0),
          wrapper_instance: wrapper,
          operation_mode: :committed
        )
        sleep(0.1)
      end

      sleep(0.3)

      count = stop_monitoring

      puts "\n📊 RESULT: #{count} undo entries created"
      if count == update_count
        puts "✅ PASS: Correct number of undo entries"
      else
        puts "❌ FAIL: Wrong number of undo entries (expected #{update_count}, got #{count})"
      end

      count
    end

    # Test 3: Transparent-only updates (should create 0 committed undo entries)
    def test_transparent_only(update_count: 5)
      puts "\n🧪 TEST: #{update_count} transparent-only updates"
      puts "Expected: 0 committed undo entries (transparent operations don't appear in undo stack)"

      start_monitoring

      wrapper = JtHyperbolicCurvesUI.find_selected_wrapper_instance ||
                JtHyperbolicCurvesUI.find_any_wrapper_instance

      update_count.times do |i|
        JtHyperbolicCurvesUI.update_geometry(
          ref_height_cm: 310.0 + (i * 5.0),
          wrapper_instance: wrapper,
          operation_mode: :transparent
        )
        sleep(0.05)
      end

      sleep(0.3)

      count = stop_monitoring

      puts "\n📊 RESULT: #{count} transactions observed"
      puts "⚠️  Note: Transparent operations still trigger observer events"
      puts "    but don't appear in Edit > Undo menu"

      count
    end

    # Run all tests
    def run_all_tests
      puts "\n" + ("=" * 60)
      puts "RUNNING ALL UNDO STACK TESTS"
      puts "=" * 60

      results = {}

      results[:slider] = test_slider_simulation(update_count: 10, delay_ms: 50)
      sleep(1)

      results[:multiple] = test_multiple_updates(update_count: 3)
      sleep(1)

      results[:transparent] = test_transparent_only(update_count: 5)

      puts "\n" + ("=" * 60)
      puts "TEST SUMMARY"
      puts "=" * 60
      puts "Slider simulation: #{results[:slider]} undo entries"
      puts "Multiple updates:  #{results[:multiple]} undo entries"
      puts "Transparent only:  #{results[:transparent]} transactions"
      puts ("=" * 60) + "\n"

      results
    end

    # Interactive test: monitor while user interacts with UI
    def interactive_test(instructions, title: "Interactive Test")
      puts "\n" + ("=" * 60)
      puts "INTERACTIVE TEST: #{title}"
      puts "=" * 60
      puts instructions
      puts "\nMonitoring started. Click 'Stop Test' button when done."
      puts ("=" * 60) + "\n"

      start_monitoring

      # Create non-modal HTML dialog
      html_content = <<-HTML
        <!DOCTYPE html>
        <html>
        <head>
          <style>
            body {
              font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif;
              margin: 20px;
              background: #f5f5f5;
            }
            .container {
              background: white;
              padding: 20px;
              border-radius: 8px;
              box-shadow: 0 2px 8px rgba(0,0,0,0.1);
              min-height: 400px;
            }
            h2 {
              margin-top: 0;
              color: #333;
              font-size: 18px;
            }
            .instructions {
              background: #f8f9fa;
              padding: 15px;
              border-radius: 4px;
              margin: 15px 0;
              line-height: 1.6;
            }
            .instructions ol {
              margin: 10px 0;
              padding-left: 20px;
            }
            .instructions li {
              margin: 8px 0;
            }
            .status {
              background: #d4edda;
              color: #155724;
              padding: 10px;
              border-radius: 4px;
              margin: 15px 0;
              font-weight: 500;
            }
            button {
              background: #007bff;
              color: white;
              border: none;
              padding: 12px 24px;
              border-radius: 4px;
              font-size: 14px;
              font-weight: 500;
              cursor: pointer;
              width: 100%;
            }
            button:hover {
              background: #0056b3;
            }
            button:active {
              background: #004085;
            }
          </style>
        </head>
        <body>
          <div class="container">
            <h2>#{title}</h2>
            <div class="instructions">
              #{instructions.gsub("\n", '<br>')}
            </div>
            <div class="status">
              ✅ Monitoring actief - voer je test uit
            </div>
            <button onclick="stopTest()">Stop Test & Toon Resultaten</button>
          </div>
          <script>
            function stopTest() {
              if (window.sketchup && sketchup.stop_test) {
                sketchup.stop_test();
              }
            }
          </script>
        </body>
        </html>
      HTML

      dlg = UI::HtmlDialog.new(
        dialog_title: title,
        preferences_key: "JtHyperbolicCurvesUndoTest",
        scrollable: true,
        resizable: true,
        width: 500,
        height: 550,
        style: UI::HtmlDialog::STYLE_UTILITY
      )

      dlg.set_html(html_content)

      dlg.add_action_callback("stop_test") do
        count = stop_monitoring
        dlg.close

        # Show results in a simple message
        UI.messagebox(
          "Test voltooid!\n\n" +
          "Aantal undo entries: #{count}\n\n" +
          "Check de Ruby Console voor gedetailleerde timeline.",
          MB_OK
        )
      end

      dlg.show
    end
  end
end

# Convenience methods for Ruby Console
def start_undo_test
  JtHyperbolicCurvesUI::UndoTest.start_monitoring
end

def stop_undo_test
  JtHyperbolicCurvesUI::UndoTest.stop_monitoring
end

def test_slider
  JtHyperbolicCurvesUI::UndoTest.test_slider_simulation
end

def test_all
  JtHyperbolicCurvesUI::UndoTest.run_all_tests
end

def test_interactive_slider
  JtHyperbolicCurvesUI::UndoTest.interactive_test(
    "<strong>TEST: Slider Interactie</strong><br><br>" +
    "<ol>" +
    "<li>Open de Hyperbolic Curves dialog (als nog niet open)</li>" +
    "<li>Sleep de <strong>Reference Height</strong> slider heen en weer</li>" +
    "<li>Laat de slider los</li>" +
    "<li>Klik op <strong>Stop Test</strong> hieronder</li>" +
    "</ol>" +
    "<br><strong>Verwacht resultaat:</strong> 1-2 undo entries",
    title: "Slider Interactie Test"
  )
end

puts "\n" + ("=" * 60)
puts "Undo Stack Test Loaded"
puts "=" * 60
puts "Available commands:"
puts "  start_undo_test          - Start monitoring"
puts "  stop_undo_test           - Stop and show report"
puts "  test_slider              - Test slider simulation"
puts "  test_all                 - Run all automated tests"
puts "  test_interactive_slider  - Interactive slider test"
puts ("=" * 60) + "\n"
