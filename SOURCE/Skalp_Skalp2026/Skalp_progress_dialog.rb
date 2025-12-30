# Skalp Progress Dialog
# Provides visual feedback during long-running operations like Update for Layout,
# Update Rearlines, and Export DWG.

module Skalp
  class ProgressDialog
    # Class method for convenient block-style usage
    def self.show(title, total, &block)
      instance = new(title, total)
      instance.show
      Skalp.progress_dialog = instance

      if block_given?
        begin
          block.call(instance)
        ensure
          instance.close
          Skalp.progress_dialog = nil
        end
      end

      instance
    end

    attr_reader :dialog, :title, :current, :cancelled
    attr_accessor :offset, :total

    def initialize(title, total)
      @title = title
      @total = [total, 1].max
      @current = 0
      @offset = 0
      @cancelled = false
      @dialog = nil
    end

    def show
      create_dialog
      @dialog.show
    end

    def update(current, message, scene_name = nil)
      return if @cancelled || @dialog.nil?

      @current = current
      actual_current = current + @offset

      # Escape strings for JavaScript
      safe_message = escape_js(message || "")
      safe_scene = escape_js(scene_name || "")

      @dialog.execute_script("updateProgress(#{actual_current}, #{@total}, '#{safe_message}', '#{safe_scene}')")
    end

    def phase(phase_name)
      # Update phase text without changing progress
      safe_phase = escape_js(phase_name)
      @dialog.execute_script("updatePhase('#{safe_phase}')") if @dialog
    end

    def close
      if @dialog
        @dialog.close
        @dialog = nil
      end
      Skalp.progress_dialog = nil
    end

    def cancelled?
      @cancelled
    end

    private

    def create_dialog
      @dialog = UI::HtmlDialog.new(
        dialog_title: @title,
        preferences_key: "Skalp_ProgressDialog",
        width: 400,
        height: 120,
        resizable: false,
        style: UI::HtmlDialog::STYLE_DIALOG
      )

      @dialog.set_html(dialog_html)

      @dialog.add_action_callback("cancel") do |_context|
        @cancelled = true
        close
      end

      @dialog.add_action_callback("ready") do |_context|
        # Dialog is ready, can start updates
      end

      # Handle dialog close by user
      @dialog.set_on_closed do
        @cancelled = true
        @dialog = nil
      end
    end

    def dialog_html
      <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <style>
            * {
              margin: 0;
              padding: 0;
              box-sizing: border-box;
              -webkit-user-select: none;
              user-select: none;
            }
        #{'    '}
            body {
              font-family: "Arial", sans-serif;
              background-color: rgb(237, 237, 237);
              color: #333;
              padding: 20px;
              height: 100vh;
              overflow: hidden;
              display: flex;
              flex-direction: column;
              justify-content: center;
            }
        #{'    '}
            .header {
              display: flex;
              justify-content: space-between;
              align-items: center;
              margin-bottom: 12px;
            }
        #{'    '}
            .phase {
              font-size: 13px;
              font-weight: bold;
              color: #444;
            }
        #{'    '}
            .percentage {
              font-size: 13px;
              font-weight: bold;
              color: rgb(111, 170, 204);
            }
        #{'    '}
            .progress-container {
              background: #fff;
              border: 1px solid #ccc;
              border-radius: 4px;
              height: 22px;
              overflow: hidden;
              margin-bottom: 10px;
              box-shadow: inset 0 1px 2px rgba(0,0,0,0.1);
            }
        #{'    '}
            .progress-bar {
              height: 100%;
              background-color: rgb(111, 170, 204);
              width: 0%;
              transition: width 0.2s ease-out;
            }
        #{'    '}
            .info {
              font-size: 11px;
              color: #666;
              overflow: hidden;
              text-overflow: ellipsis;
              white-space: nowrap;
            }
        #{'    '}
            .scene-name {
              font-style: italic;
            }
          </style>
        </head>
        <body>
          <div class="header">
            <span class="phase" id="phase">Initializing...</span>
            <span class="percentage" id="percentage">0%</span>
          </div>
        #{'  '}
          <div class="progress-container">
            <div class="progress-bar" id="progressBar"></div>
          </div>
        #{'  '}
          <div class="info" id="sceneInfo">
            <span class="scene-name" id="sceneName">Starting...</span>
          </div>
        #{'  '}
          <script>
            function updateProgress(current, total, message, sceneName) {
              const percent = Math.round((current / total) * 100);
              document.getElementById('progressBar').style.width = percent + '%';
              document.getElementById('percentage').textContent = percent + '%';
              document.getElementById('phase').textContent = message || 'Processing...';
              document.getElementById('sceneName').textContent = sceneName || '';
            }
        #{'    '}
            function updatePhase(phase) {
              document.getElementById('phase').textContent = phase;
            }
        #{'    '}
            // Signal ready
            window.location = 'skp:ready';
          </script>
        </body>
        </html>
      HTML
    end

    def escape_js(str)
      str.to_s.gsub("\\", "\\\\\\\\").gsub("'", "\\\\'").gsub("\n", "\\n").gsub("\r", "")
    end
  end
end
