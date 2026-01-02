module Skalp
  class InputBox
    require "json"

    def self.show(prompts, defaults, lists = nil, title = "Skalp Input", &)
      new(prompts, defaults, title, lists, &)
    end

    def self.ask(prompts, defaults, lists = nil, title = "Skalp Input")
      f = Fiber.current
      new(prompts, defaults, title, lists) do |results|
        f.resume(results)
      end
      Fiber.yield
    end

    def initialize(prompts, defaults, title, lists = nil, &block)
      @prompts = prompts
      @defaults = defaults
      @title = title
      @lists = lists
      @block = block
      @dialog = nil
      show_dialog
    end

    def show_dialog
      # Adaptive dimensions
      width = 380
      # Base height for header/footer (padding/margins) + height per prompt
      # Single prompt needs more room than just its input due to layout breathing room
      # min_h 170 is a good floor for single-item dialogs.
      min_h = 170
      calculated_h = 90 + (@prompts.length * 75)
      height = [calculated_h, min_h].max
      height = [height, 800].min

      @dialog = UI::HtmlDialog.new({
                                     dialog_title: @title,
                                     # Reset to v5 for refined spacing
                                     preferences_key: "com.skalp.inputbox.v5.#{@title.to_s.gsub(/[^0-9a-zA-Z]/, '')}",
                                     scrollable: false,
                                     resizable: true,
                                     width: width,
                                     height: height,
                                     style: UI::HtmlDialog::STYLE_UTILITY
                                   })

      # Locate the html file
      html_path = File.join(File.dirname(__FILE__), "ui", "inputbox.html")
      unless File.exist?(html_path)
        html_path = Sketchup.find_support_file("Plugins") + "/Skalp_Skalp2026/ui/inputbox.html"
      end
      @dialog.set_file(html_path)

      @dialog.add_action_callback("ready") do |d|
        data = {
          prompts: @prompts,
          defaults: @defaults,
          lists: @lists
        }
        @dialog.execute_script("init(#{data.to_json})")
      end

      @dialog.add_action_callback("submit") do |d, results|
        # results from JS is an array of strings
        # We try to cast back to original types as UI.inputbox does
        final_results = results.map.with_index do |res, i|
          default = @defaults[i]
          if default.is_a?(Length)
            res.to_l
          elsif default.is_a?(Integer)
            res.to_i
          elsif default.is_a?(Float)
            res.to_f
          elsif default.is_a?(TrueClass) || default.is_a?(FalseClass)
            %w[true yes].include?(res)
          else
            res
          end
        end

        @dialog.close
        @block.call(final_results) if @block
      end

      @dialog.add_action_callback("cancel") do |d|
        @dialog.close
        @block.call(false) if @block
      end

      @dialog.center
      @dialog.show
    end
  end

  # Global convenience method
  def self.inputbox_custom(prompts, defaults, lists_or_title = nil, title = "Skalp", &)
    lists = nil
    if lists_or_title.is_a?(String)
      title = lists_or_title
    elsif lists_or_title.is_a?(Array)
      lists = lists_or_title
    end
    InputBox.show(prompts, defaults, lists, title, &)
  end
end
