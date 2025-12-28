module Skalp
  class InputBox
    def self.show(prompts, defaults, lists = [], title = "Skalp Input", &block)
      @on_submit = block
      setup_dialog(prompts, defaults, lists, title)
      @dialog.show
    end

    def self.ask(prompts, defaults, lists = [], title = "Skalp Input")
      f = Fiber.current
      setup_dialog(prompts, defaults, lists, title)
      
      @dialog.add_action_callback("submit") do |d, results|
        @dialog.close
        f.resume(results)
      end
      
      @dialog.add_action_callback("cancel") do |d|
        @dialog.close
        f.resume(nil)
      end

      @dialog.show
      Fiber.yield
    end

    private

    def self.setup_dialog(prompts, defaults, lists, title)
      # Estimate size
      width = 450
      height = 130 + (prompts.length * 62)
      
      @dialog = UI::HtmlDialog.new({
        :dialog_title => title,
        :preferences_key => "com.skalp.inputbox",
        :scrollable => false,
        :resizable => true,
        :width => width,
        :height => height,
        :style => UI::HtmlDialog::STYLE_DIALOG
      })
      
      path = File.join(File.dirname(__FILE__), 'ui', 'inputbox.html')
      @dialog.set_file(path)
      
      @dialog.add_action_callback("ready") do |d|
        data = {
          prompts: prompts,
          defaults: defaults,
          lists: lists
        }
        @dialog.execute_script("init(#{data.to_json})")
      end

      @dialog.add_action_callback("submit") do |d, results|
        @on_submit.call(results) if @on_submit
        @dialog.close
      end
      
      @dialog.add_action_callback("cancel") do |d|
        @dialog.close
      end
      
      @dialog.center
    end
  end
end
