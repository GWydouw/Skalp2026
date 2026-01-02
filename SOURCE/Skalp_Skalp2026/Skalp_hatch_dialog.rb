module Skalp
  require "json"
  class Hatch_dialog
    attr_accessor :webdialog, :selected_material, :hatchname

    SKALP_MATERIALS = ["Skalp default", "Skalp linecolor", "Skalp transparant"]

    # Original WebDialog preview dimensions
    PREVIEW_X_SIZE = 215
    PREVIEW_Y_SIZE = 100
    PRINT_DPI = 600
    SCREEN_DPI = 72
    QUALITY = 1

    def initialize(hatchname = "Skalp default")
      @selected_material = {}
      @selected_material[:material] = "Skalp default"
      @selected_material[:pattern] = "ANSI31, ANSI IRON, BRICK, STONE MASONRY"
      @showmore_dialog = false
      @startup = true
      @tile = Skalp::Tile_size.new
      SkalpHatch.load_hatch
      @hatchname = hatchname
      @active_skpModel = Sketchup.active_model
      @html_path = Sketchup.find_support_file("Plugins") + "/Skalp_Skalp2026/html/"
      @thumb_path = @html_path + "icons/thumbs/"
      Dir.mkdir(@thumb_path) unless File.exist?(@thumb_path)

      # Pre-compute initial preview for instant display when dialog opens
      pre_compute_initial_preview

      @height = {}
      @w_size = @dialog_w = 235  # 215px content + 10px padding each side
      @height[:material] = 600   # Height for collapsible sections

      @dialog_x = 200
      @dialog_y = 200
      @resize = false

      # Set min/max dimensions for resize callback
      @min_w = 300
      @min_h = 500
      @max_h = 800

      @webdialog = UI::HtmlDialog.new(
        {
          dialog_title: "Edit Skalp material",
          preferences_key: "Skalp_pattern_designer_v5",
          scrollable: false,
          resizable: true,
          width: @dialog_w,
          height: 700,
          left: @dialog_x,
          top: @dialog_y,
          min_width: @dialog_w,
          min_height: 300,
          max_width: @dialog_w,
          max_height: 1000,
          style: UI::HtmlDialog::STYLE_UTILITY
        }
      )

      # @webdialog.set_file(@html_path + "hatch_dialog.html")
      # HTML Injection for Instant Load
      begin
        html_content = File.read(File.join(@html_path, "hatch_dialog.html"), encoding: "UTF-8")

        # Inject Base URL for relative assets
        base_url = "file://" + @html_path
        html_content.sub!("<head>", "<head><base href='#{base_url}'>")

        # Generate and Inject Initial Data
        data = get_initial_data_payload
        json_str = data.to_json

        # Safe injection: usage of block to avoid backslash issues interpretation
        html_content.gsub!("var SKALP_INITIAL_DATA = null;") { "var SKALP_INITIAL_DATA = #{json_str};" }

        @webdialog.set_html(html_content)
      rescue StandardError => e
        msg = "Skalp HTML Injection Failed: #{e.message}"
        puts "[Skalp] #{msg}"
        puts e.backtrace.first(5)
        UI.messagebox(msg) # Visible feedback for user
        @webdialog.set_file(@html_path + "hatch_dialog.html") # Fallback
      end

      # CALLBACKS
      @webdialog.add_action_callback("dialog_focus") do
        if Sketchup.active_model
          load_patterns_and_materials
        else
          Skalp.stop_skalp
        end
      end

      @webdialog.add_action_callback("dialog_resize") do |webdialog, params|
        vars = params.split(";")
        @resize = true
        @dialog_w = vars[0].to_i
        @dialog_h = vars[1].to_i

        @dialog_w = @min_w if @dialog_w < @min_w
        @dialog_h = @max_h if @dialog_h > @max_h
        @dialog_h = @min_h if @dialog_h < @min_h
      end

      @webdialog.add_action_callback("attach_material_from_pattern_designer") do |webdialog, params|
        sectionmaterial = Skalp.utf8(params)
        if Sketchup.active_model == @active_skpModel
          if Sketchup.active_model

            selection = Sketchup.active_model.selection
            if sectionmaterial
              Skalp.active_model.start("Skalp - #{Skalp.translate('define section material')}", true)
              entities = []
              for e in selection
                if e.valid?
                  e.set_attribute("Skalp", "sectionmaterial", sectionmaterial.to_s)
                  entities << e
                end
              end
              Skalp.active_model.commit
              entities.each do |e|
                data = {
                  action: :changed_sectionmaterial,
                  entity: e
                }

                Skalp.active_model.controlCenter.add_to_queue(data)
              end

            end
          else # only Pattern Designer active
            selection = Sketchup.active_model.selection
            if sectionmaterial
              Skalp.active_model.start("Skalp - #{Skalp.translate('define section material')}", true)
              entities = []
              for e in selection
                if e.valid?
                  e.set_attribute("Skalp", "sectionmaterial", sectionmaterial.to_s)
                  entities << e
                end
              end
              Skalp.active_model.commit
              entities.each do |e|
                data = {
                  action: :changed_sectionmaterial,
                  entity: e
                }

                Skalp.active_model.controlCenter.add_to_queue(data)
              end
            end
          end
        end
      end

      # SHOW ###############################
      @webdialog.add_action_callback("dialog_ready") do
        set_dialog_translation

        # If injection data was missing (fallback), load via Ruby
        load_patterns_and_materials unless @initial_preview_base64 && @initial_pattern_string

        show
      end

      # PREVIEW ###############################
      @webdialog.add_action_callback("create_preview") do |webdialog, params|
        create_preview(params)
      end

      # CREATE HATCH ###############################
      @webdialog.add_action_callback("create_hatch") do |webdialog, params|
        if Skalp.active_model
          Skalp.active_model.start("Skalp - #{Skalp.translate('create hatch')}",
                                   true)
        else
          Sketchup.active_model.start_operation(
            "Skalp - #{Skalp.translate('create hatch')}", true, false, false
          )
        end
        create_hatch(params)
        Skalp.active_model ? Skalp.active_model.commit : Sketchup.active_model.commit_operation
        load_patterns_and_materials
        Skalp::Material_dialog.update_dialog if Skalp::Material_dialog.materialdialog
      end

      # MENU ###############################
      @webdialog.add_action_callback("import_pat_file") do |webdialog, params|
        chosen_image = UI.openpanel(Skalp.translate("Open Image File"), Skalp::SKALP_PATH, "*.pat")

        if chosen_image
          FileUtils.copy(chosen_image, File.join(Skalp::SKALP_PATH, "resources", "hatchpats"))

          # reload pat files
          SkalpHatch.load_hatch
          load_patterns_and_materials
        end
      end

      # CREATE HATCH ###############################
      @webdialog.add_action_callback("create_new_hatch") do |webdialog, params|
        clear_dialog(true)
      end

      # DELETE HATCH ###############################
      @webdialog.add_action_callback("delete_hatch") do |webdialog, params|
        delete_hatch(Skalp.utf8(params))
        Skalp::Material_dialog.update_dialog if Skalp::Material_dialog.materialdialog
      end

      # SAVE MATERIAL ###############################
      @webdialog.add_action_callback("get_thumbnails") do |action_context, params|
        generate_thumbnails
        script("thumbnails_ready();")
      end

      # SAVE MATERIAL ###############################
      @webdialog.add_action_callback("save_material") do |action_context, params|
        # params format: "material_name"
        material_name = Skalp.utf8(params)
        @hatchname = material_name if material_name && !material_name.empty?
        # Save happens via create_hatch on blur or explicit save
        @webdialog.close
        Skalp::Material_dialog.update_dialog if Skalp::Material_dialog.materialdialog
      end

      # CANCEL EDIT ###############################
      @webdialog.add_action_callback("cancel_edit") do |action_context|
        @webdialog.close
      end

      # Add callback to handle window resizing
      @webdialog.add_action_callback("resize_window") do |action_context, width, height|
        # Add some padding for window borders if needed, or trust JS
        @webdialog.set_size(width.to_i, height.to_i)
      end

      # SIZE ###############################
      @webdialog.add_action_callback("change_tile_x") do |webdialog, params|
        vars = params.split(";")
        @tile.calculate(vars[0], :y)

        if @tile.unit == "feet"
          script("$('#tile_y').val(\"#{@tile.y_string}\");")
          script("$('#tile_x').val(\"#{@tile.x_string}\");")
        else
          script("$('#tile_y').val('#{@tile.y_string}');")
          script("$('#tile_x').val('#{@tile.x_string}');")
        end

        script("create_preview(0)")
      end

      @webdialog.add_action_callback("change_tile_y") do |webdialog, params|
        vars = params.split(";")
        @tile.calculate(vars[0], :x)

        if @tile.unit == "feet"
          script("$('#tile_y').val(\"#{@tile.y_string}\");")
          script("$('#tile_x').val(\"#{@tile.x_string}\");")
        else
          script("$('#tile_y').val('#{@tile.y_string}');")
          script("$('#tile_x').val('#{@tile.x_string}');")
        end

        script("create_preview(0)")
      end

      @webdialog.add_action_callback("print_units") do |webdialog, params|
        @tile.default_value
        visibility("lineweight_model", false)
        visibility("lineweight_paper", true)
        set_value("tile_x", @tile.x_string)
        set_value("tile_y", @tile.y_string)
        set_value("lineweight_model", "1.0cm")
        set_value("lineweight_paper", "0.18 mm")
      end

      @webdialog.add_action_callback("model_units") do |webdialog, params|
        @tile.default_model_value
        visibility("lineweight_model", true)
        visibility("lineweight_paper", false)
        set_value("tile_x", @tile.x_string)
        set_value("tile_y", @tile.y_string)
        set_value("lineweight_model", "1.0cm")
        set_value("lineweight_paper", "0.18 mm")
      end

      @webdialog.set_on_closed do
        # HtmlDialog doesn't support get_element_value or show_modal
        # Simply handle close event
        Skalp.patterndesignerbutton_off
        # Refresh layers dialog to restore previews only if not already updated by create_hatch
        Skalp.update_layers_dialog unless @updated_layers
        @updated_layers = false

        if @recalc_section_needed
          # Prevent observers from triggering a second dialog update during calculation
          Skalp.observers_disabled = true if defined?(Skalp.observers_disabled)
          begin
            if Skalp.active_model && Skalp.active_model.active_sectionplane
              Skalp.active_model.active_sectionplane.calculate_section
            end
          ensure
            Skalp.observers_disabled = false if defined?(Skalp.observers_disabled)
          end
          @recalc_section_needed = false
        end
      end
    end

    def show
      @webdialog.show
    end

    # Pre-compute the initial preview so it's ready when the dialog opens
    def pre_compute_initial_preview
      return unless @hatchname

      suMaterial = Sketchup.active_model.materials[@hatchname]
      unless suMaterial && suMaterial.get_attribute("Skalp", "ID")
        puts "[Skalp] Material not found or not Skalp material (Name: #{@hatchname})"
        return
      end

      pattern_string = Skalp.get_pattern_info(suMaterial)
      return unless pattern_string

      penwidth = Skalp::PenWidth.new(pattern_string[:pen], pattern_string[:space])
      pattern_name = pattern_string[:pattern][0].gsub("*", "").strip

      @hatch = Skalp::SkalpHatch::Hatch.new

      solidcolor = pattern_name == "SOLID_COLOR, solid color without hatching"
      if solidcolor
        @hatch.add_hatchdefinition(SkalpHatch::HatchDefinition.new(["SOLID_COLOR, solid color without hatching",
                                                                    "45, 0,0, 0,.125"]))
        pattern_string[:line_color] = pattern_string[:fill_color]
      else
        @hatch.add_hatchdefinition(SkalpHatch::HatchDefinition.new(pattern_string[:pattern]))
      end

      @tile.calculate(pattern_string[:user_x], :x)
      drawing_scale = Skalp.dialog ? Skalp.dialog.drawing_scale.to_f : 50.0

      pattern_info = @hatch.create_png({
                                         solid_color: solidcolor,
                                         type: :preview,
                                         gauge: true,
                                         width: PREVIEW_X_SIZE,
                                         height: PREVIEW_Y_SIZE,
                                         line_color: pattern_string[:line_color],
                                         fill_color: pattern_string[:fill_color],
                                         pen: penwidth.to_inch,
                                         section_cut_width: pattern_string[:section_cut_width].to_f,
                                         resolution: SCREEN_DPI,
                                         print_scale: drawing_scale,
                                         zoom_factor: 1.0 / ((105 - 60) * 5.0 / 100.0), # Default slider value = 60
                                         user_x: @tile.x_value,
                                         space: pattern_string[:space]
                                       })

      @initial_preview_base64 = pattern_info[:png_base64] if pattern_info
      @tile.gauge = pattern_info[:gauge_ratio] if pattern_info
      @initial_pattern_string = pattern_string
    rescue StandardError => e
      puts "[Skalp PreCompute] ERROR: #{e.message}"
      @initial_preview_base64 = nil
    end

    def script(js_code)
      @webdialog.execute_script(js_code)
    end

    # Public method to update material from external call (e.g. from main dialog)
    def update_material(hatchname)
      t_start = Time.now
      puts "[Skalp] update_material called with: #{hatchname}"
      @hatchname = hatchname

      # 1. Pre-compute data (should be fast)
      pre_compute_initial_preview

      puts "[Skalp] Pre-computation took: #{Time.now - t_start}s"

      # 2. Show dialog
      show

      # 3. Push data immediately
      if @initial_preview_base64 && @initial_pattern_string
        ps = @initial_pattern_string
        penwidth = Skalp::PenWidth.new(ps[:pen], ps[:space])
        @tile.calculate(ps[:user_x], :x)

        # Force the pattern dropdown
        script("select_material_ui_only('#{hatchname}');")

        set_value("hatch_name", @hatchname)
        script("$('#line_color_input').spectrum('set', '#{ps[:line_color]}');")
        script("$('#fill_color_input').spectrum('set', '#{ps[:fill_color]}');")
        script("$('#section_line_color_input').spectrum('set', '#{ps[:section_line_color] || 'rgb(0,0,0)'}');")
        set_value("units", ps[:space])
        set_value("lineweight_model", penwidth.to_s)
        set_value("lineweight_paper", penwidth.to_s)
        if ps[:section_cut_width].to_f < 0.0001
          set_value("sectioncut_linewidth", "0.00 mm")
        else
          set_value("sectioncut_linewidth", Skalp.inch2pen(ps[:section_cut_width].to_f, true))
        end
        script("$('#tile_x').val('#{@tile.x_string}');")
        script("$('#tile_y').val('#{@tile.y_string}');")
        set_value("gauge_ratio", @tile.gauge.to_s) if @tile.gauge

        set_preview_base64("hatch_preview", @initial_preview_base64)
      else
        puts "[Skalp] Pre-compute failed, fallback"
        script("select_material('#{hatchname}');")
      end
      puts "[Skalp] Total update_material time: #{Time.now - t_start}s"
    end

    def set_value(element_id, value)
      escaped_value = value.to_s.gsub("'", "\\\\'")
      script("document.getElementById('#{element_id}').value = '#{escaped_value}';")
    end

    def visibility(element_id, visible)
      display = visible ? "block" : "none"
      script("document.getElementById('#{element_id}').style.display = '#{display}';")
    end

    def clear(element_id)
      script("document.getElementById('#{element_id}').innerHTML = '';")
    end

    def add(element_id, option_text)
      escaped_text = option_text.to_s.gsub("'", "\\\\'")
      script("var opt = document.createElement('option'); opt.text = '#{escaped_text}'; opt.value = '#{escaped_text}'; document.getElementById('#{element_id}').add(opt);")
    end

    def select_last_pattern
      @hatchname ? script("select_material('#{@hatchname}');") : script("select_material('Skalp default')")
      script("refresh_custom_dropdown();")
    end

    def clear_dialog(name = true)
      continuation = lambda do
        # Set color values using Spectrum's set method
        script("$('#fill_color_input').spectrum('set', 'rgb(255,255,255)');")
        script("$('#line_color_input').spectrum('set', 'rgb(0,0,0)');")

        set_value("units", "paperspace")
        set_value("lineweight_model", "1.0cm")
        set_value("lineweight_paper", "0.18 mm")
        set_value("sectioncut_linewidth", "0.35 mm")
        set_value("tile_x", @tile.x_string)
        set_value("tile_y", @tile.y_string)
        set_value("acad_pattern_list", "ANSI31, ANSI IRON, BRICK, STONE MASONRY")
        script("create_preview(1)") if name
      end

      if name
        new_material_name(&continuation)
      else
        continuation.call
      end
    end

    def new_material_name(&block)
      num = 0
      Sketchup.active_model.materials.each { |mat| num += 1 if mat.name.include?("skalp material#") }

      Skalp.inputbox_custom(["Materialname:"], [""], "Create new Skalp material") do |input|
        if input && input[0].gsub(" ", "") != ""
          set_value("material_name", input[0])
          block.call if block
        end
      end
    end

    def set_dialog_translation
      # PATTERN DESIGNER DIALOG
      # text = Skalp.translate('Fill Color:')
      # @webdialog.execute_script(%Q^$("#translate_03").text("#{text}")^)
      #
      # text = Skalp.translate('Line Color:')
      # @webdialog.execute_script(%Q^$("#translate_02").text("#{text}")^)
      #
      # text = Skalp.translate('Line Width:')
      # @webdialog.execute_script(%Q^$("#translate_01").text("#{text}")^)
      #
      # text = Skalp.translate('Section Cut Width:')
      # @webdialog.execute_script(%Q^$("#translate_04").text("#{text}")^)
      #
      # text = Skalp.translate('Align with Objects:')
      # tooltip =Skalp.translate('Align red X-axis with the longest Edge in an Objects section result.')
      # @webdialog.execute_script(%Q^$("#pattern_alignment").text("")^)
      # @webdialog.execute_script(%Q^$("#pattern_alignment").append("<h2 title='#{tooltip}'>#{text}</h2>")^)
      # @webdialog.execute_script(%Q^$("#pattern_alignment").append("<input type='checkbox' name='align with object' title='#{tooltip}' value='align' id='align_pattern' onchange='$('#update_preview').show();'>")^)
    end

    def get_initial_data_payload
      patterns = get_patterns_list
      materials = get_skalp_materials_list
      full_list = patterns + materials

      # Determine pattern name from settings
      pat_name_raw = nil
      if @initial_pattern_string && @initial_pattern_string[:pattern]
        pat_entry = @initial_pattern_string[:pattern]
        pat_name_raw = if pat_entry.is_a?(Array)
                         pat_entry[0].to_s.gsub("*", "").strip
                       else
                         pat_entry.to_s.gsub("*", "").strip
                       end
      end
      pat_name_raw ||= "Skalp default"

      # Find matching full name in list
      # The list items are "Name, Description" or just "Name"
      # Find selection in list (handle "Name" vs "Name, Description" and case insensitivity)
      pat_selection = full_list.find do |item|
        item.upcase == pat_name_raw.upcase || item.upcase.start_with?("#{pat_name_raw.upcase},")
      end || pat_name_raw

      # If still not found, we might want to check for underscore/space swapping but let's stick to this for now.

      # Compute extra UI settings
      s = @initial_pattern_string || {}

      # Pen / Units
      # Logic inferred from PenWidth usage and legacy set_value
      # If space is 'modelspace', we use lineweight_model. If 'paperspace', lineweight_paper.
      space = s[:space] || "paperspace"
      pen_val = s[:pen] # Float or string

      # Create richer settings hash for JS
      # Try to use @tile formatted strings if available (set in pre_compute)
      # If not set, calculate usage
      # Always calculate from material attributes to ensure correct units are loaded
      @tile.calculate(s[:user_x], :x) if s[:user_x]

      # Robust formatting helper using Skalp.inch2pen to match dropdown options
      # s[:section_cut_width] is likely float in inches (e.g. 0.0137...)
      # pen_val is likely float in inches.

      pen_val = if s[:pen].is_a?(String)
                  Skalp::Distance.new(s[:pen]).to_inch
                else
                  s[:pen].to_f
                end

      sc_val = if s[:section_cut_width].is_a?(String)
                 Skalp::Distance.new(s[:section_cut_width]).to_inch
               else
                 s[:section_cut_width].to_f
               end

      pen_formatted = Skalp.inch2pen(pen_val, true)
      sc_formatted = Skalp.inch2pen(sc_val, true)

      # Fallback defaults if conversion returns "0.00 mm" unexpectedly for non-zero inputs
      # (Though valid 0.0 should be "0.00 mm")

      # Ensure pattern is in list if not found (but only if it's reasonably a pattern name, not just a material name fallback)
      # We check if it's an AutoCAD pattern or known Skalp pattern type
      is_known_pattern = SkalpHatch.hatchdefs.any? { |h| h.name.to_s.upcase == pat_name_raw.upcase }
      full_list << pat_selection if is_known_pattern && !full_list.include?(pat_selection)
      full_list.sort! if full_list.respond_to?(:sort!)

      ui_settings = s.merge({
                              user_x: @tile.x_string,
                              tile_x: @tile.x_string,
                              tile_y: @tile.y_string,

                              line_color: s[:line_color].to_s,
                              fill_color: s[:fill_color].to_s,
                              section_line_color: s[:section_line_color] || "rgb(0,0,0)",

                              space: space,

                              # Lineweights
                              lineweight_model: (if space == "modelspace"
                                                   s[:pen].is_a?(String) ? s[:pen] : pen_formatted
                                                 else
                                                   "0.35 mm"
                                                 end),
                              lineweight_paper: (if space == "paperspace"
                                                   s[:pen].is_a?(String) ? s[:pen] : pen_formatted
                                                 else
                                                   "0.18 mm"
                                                 end),

                              sectioncut_linewidth: sc_formatted.to_s.empty? || sc_formatted.to_s == "0.00 mm" ? "0.00 mm" : sc_formatted,

                              slider: "60",
                              priority: s[:drawing_priority],
                              unify: s[:unify]
                            })

      raw_data = {
        hatch_name: @hatchname,
        pattern_list: full_list,
        settings: ui_settings,
        pattern_name: pat_selection,
        preview_base64: @initial_preview_base64
      }

      ensure_json_safe(raw_data)
    end

    def ensure_json_safe(obj)
      if obj.is_a?(String)
        obj.encode("UTF-8", "binary", invalid: :replace, undef: :replace, replace: "")
      elsif obj.is_a?(Array)
        obj.map { |v| ensure_json_safe(v) }
      elsif obj.is_a?(Hash)
        new_h = {}
        obj.each { |k, v| new_h[k] = ensure_json_safe(v) }
        new_h
      else
        obj
      end
    end

    def get_patterns_list
      pat_names = []
      names_map = {} # To keep hatchdefs if needed, but for list we just need strings

      SkalpHatch.hatchdefs.each do |hatchdef|
        name = hatchdef.name.to_s.strip
        if hatchdef.description && hatchdef.description.to_s.strip != ""
          description = hatchdef.description.to_s.strip
          key = "#{name}, #{description}"
        else
          key = name
        end
        pat_names << key
      end

      pat_names.compact!
      pat_names.uniq!
      pat_names.sort!

      pat_names.unshift("SOLID_COLOR, solid color without hatching")

      # Ensure current material pattern is in list
      if @selected_material && @selected_material[:pattern]
        current_pat = @selected_material[:pattern].to_s.strip
        if current_pat != "" && current_pat != "SOLID_COLOR, solid color without hatching"
          pat_names.delete(current_pat)
          pat_names.unshift(current_pat)
        end
      end

      # Add footer items
      pat_names << "----------------------"
      pat_names << "Import AutoCAD pattern..."

      pat_names
    end

    def get_skalp_materials_list
      return [] unless Sketchup.active_model

      skalpList = []
      Sketchup.active_model.materials.each do |material|
        if material.get_attribute("Skalp", "ID")
          name = material.name.gsub(/%\d+\Z/, "")
          skalpList << name unless skalpList.include?(name)
        end
      end

      skalpList.compact!
      skalpList.uniq!
      skalpList.sort!
      skalpList
    end

    def load_patterns
      clear("acad_pattern_list")

      pat_names = []
      @hatchdefs = {}

      SkalpHatch.hatchdefs.each do |hatchdef|
        name = hatchdef.name.to_s.strip
        if hatchdef.description && hatchdef.description.to_s.strip != ""
          description = hatchdef.description.to_s.strip
          key = "#{name}, #{description}"
        else
          key = name
        end
        @hatchdefs[key] = hatchdef
        pat_names << key
      end

      pat_names.compact!
      pat_names.uniq!
      pat_names.sort!

      pat_names.unshift("SOLID_COLOR, solid color without hatching")

      # Ensure current material pattern is in list and in @hatchdefs
      current_pat = @selected_material[:pattern].to_s.strip
      if current_pat != "" && current_pat != "SOLID_COLOR, solid color without hatching"
        # If it's already in the list, move it to the front
        pat_names.delete(current_pat)
        pat_names.unshift(current_pat)
      end

      pat_names.each do |pat|
        add("acad_pattern_list", pat) unless pat.nil? || pat == ""
      end

      # Add Import footer
      add("acad_pattern_list", "----------------------")
      add("acad_pattern_list", "Import AutoCAD pattern...")

      generate_thumbnails
      script("thumbnails_ready();")
    end

    def load_materials
      return unless Sketchup.active_model

      # clear("acad_pattern_list") -- DO NOT CLEAR, append to existing patterns

      skalpList = []

      Sketchup.active_model.materials.each do |material|
        if material.get_attribute("Skalp", "ID")
          name = material.name.gsub(/%\d+\Z/, "")
          skalpList << name unless skalpList.include?(name)
        end
      end

      skalpList.compact!
      skalpList.uniq!
      skalpList.sort!

      skalpList = skalpList
      skalpList.each do |pat|
        add("acad_pattern_list", pat) # unless pat == ''
      end
    end

    def load_patterns_and_materials
      load_patterns
      load_materials
      select_last_pattern
    end

    def ensure_hatchdefs
      return if @hatchdefs

      @hatchdefs = {}
      SkalpHatch.hatchdefs.each do |hatchdef|
        name = hatchdef.name.to_s.strip
        if hatchdef.description && hatchdef.description.to_s.strip != ""
          description = hatchdef.description.to_s.strip
          key = "#{name}, #{description}"
        else
          key = name
        end
        @hatchdefs[key] = hatchdef
      end
    end

    def create_preview(params)
      ensure_hatchdefs
      vars = params.split(";")
      new = vars[8].to_i == 1
      aligned = vars[9]
      materialname = vars[11]
      return unless materialname

      @hatchname = Skalp.utf8(materialname)
      suMaterial = Sketchup.active_model.materials[@hatchname]

      if suMaterial && suMaterial.get_attribute("Skalp", "ID") && new && @selected_material[:pattern] == vars[0] # TODO: hier nog opvangen wat gedaan bij een aanpassing slider (preview)

        pattern_string = Skalp.get_pattern_info(suMaterial)

        penwidth = Skalp::PenWidth.new(pattern_string[:pen], pattern_string[:space])

        pattern_name = pattern_string[:pattern][0].gsub("*", "").strip

        @selected_material[:material] = suMaterial.name
        @selected_material[:pattern] = pattern_name

        @hatch = Skalp::SkalpHatch::Hatch.new

        if pattern_name == "SOLID_COLOR, solid color without hatching"
          @hatch.add_hatchdefinition(SkalpHatch::HatchDefinition.new(["SOLID_COLOR, solid color without hatching",
                                                                      "45, 0,0, 0,.125"]))
          pattern_string[:line_color] = pattern_string[:fill_color]
          solidcolor = true
        else
          @hatch.add_hatchdefinition(SkalpHatch::HatchDefinition.new(pattern_string[:pattern]))
          solidcolor = false
        end

        zoom_factor = 1.0 / ((105 - vars[7].to_i) * 5.0 / 100.0)

        # previewing a pattern that already exist in the model
        @tile.calculate(pattern_string[:user_x], :x)
        drawing_scale = Skalp.dialog ? Skalp.dialog.drawing_scale.to_f : 50.0

        script("solid_color(#{solidcolor});")

        # Set new fields in UI
        section_line_color = pattern_string[:section_line_color] || "rgb(0,0,0)"
        unify = pattern_string[:unify] == true
        drawing_priority = pattern_string[:drawing_priority] || 0
        script("$('#section_line_color_input').spectrum('set', '#{section_line_color}');")
        script("$('#section_line_color_block').css('background-color', '#{section_line_color}');")
        script("$('#unify_material').prop('checked', #{unify});")
        script("$('#zindex').val('#{drawing_priority}');")

        zoom_factor ||= 1.0

        pattern_info = @hatch.create_png({
                                           solid_color: solidcolor,
                                           type: :preview,
                                           gauge: true,
                                           width: PREVIEW_X_SIZE,
                                           height: PREVIEW_Y_SIZE,
                                           line_color: pattern_string[:line_color],
                                           fill_color: pattern_string[:fill_color],
                                           pen: penwidth.to_inch,
                                           section_cut_width: pattern_string[:section_cut_width].to_f,
                                           resolution: SCREEN_DPI,
                                           print_scale: drawing_scale,
                                           zoom_factor: zoom_factor,
                                           user_x: @tile.x_value,
                                           space: pattern_string[:space],
                                           section_line_color: pattern_string[:section_line_color] || "rgb(0,0,0)"
                                         })

        @tile.gauge = pattern_info[:gauge_ratio]
        @last_preview_base64 = pattern_info[:png_base64] # Store for final set_preview call
        set_value("gauge_ratio", @tile.gauge)

        script("$('#tile_x').val('#{@tile.x_string}');")
        script("$('#tile_y').val('#{@tile.y_string}');")

        # Set color values using Spectrum's set method
        line_color = pattern_string[:line_color].to_s
        fill_color = pattern_string[:fill_color].to_s
        script("$('#line_color_input').spectrum('set', '#{line_color}');")
        script("$('#fill_color_input').spectrum('set', '#{fill_color}');")
        set_value("units", pattern_string[:space])

        # lineweight_model
        set_value("lineweight_model", penwidth.to_s)
        set_value("lineweight_paper", penwidth.to_s)
        set_value("sectioncut_linewidth", Skalp.inch2pen(pattern_string[:section_cut_width].to_f))

        if pattern_string[:alignment] == "true"
          script("$('#align_pattern').prop('checked', true)")
        else
          script("$('#align_pattern').prop('checked', false)")
        end

      else
        if new
          pattern_key = Skalp.utf8(vars[0]).to_s.strip
          return if ([nil,
                      ""].include?(Skalp.utf8(vars[11])) || @hatchdefs[pattern_key].nil?) && pattern_key != "SOLID_COLOR, solid color without hatching"

          @hatch = Skalp::SkalpHatch::Hatch.new

          if pattern_key == "SOLID_COLOR, solid color without hatching"
            @hatch.add_hatchdefinition(SkalpHatch::HatchDefinition.new(["SOLID_COLOR, solid color without hatching",
                                                                        "45, 0,0, 0,.125"]))
            vars[5] = vars[6]
          else
            @hatch.add_hatchdefinition(@hatchdefs[pattern_key])
          end

          script("$('#update_preview').show()")
        elsif vars[0] == "SOLID_COLOR, solid color without hatching"
          @hatch.add_hatchdefinition(SkalpHatch::HatchDefinition.new(["SOLID_COLOR, solid color without hatching",
                                                                      "45, 0,0, 0,.125"]))
          vars[5] = vars[6]
        end

        solidcolor = vars[0] == "SOLID_COLOR, solid color without hatching"
        script("solid_color(#{solidcolor});")

        zoom_divisor = (105 - vars[7].to_i) * 5.0 / 100.0
        zoom_factor = zoom_divisor == 0 ? 1.0 : 1.0 / zoom_divisor

        pen_width = if vars[2].to_sym == :modelspace
                      Skalp::PenWidth.new(vars[4], vars[2],
                                          true)
                    else
                      Skalp::PenWidth.new(
                        vars[3], vars[2], true
                      )
                    end
        set_value("lineweight_model", pen_width.to_s)
        set_value("lineweight_paper", pen_width.to_s)

        if @hatch
          pattern_info = @hatch.create_png({
                                             solid_color: solidcolor,
                                             type: :preview,
                                             gauge: true,
                                             width: PREVIEW_X_SIZE,
                                             height: PREVIEW_Y_SIZE,
                                             line_color: vars[5],
                                             fill_color: vars[6],
                                             pen: pen_width.to_inch, # pen_width in inch (1pt = 1.0 / 72) was: 1.0 / SCREEN_DPI
                                             section_cut_width: Skalp.mm_or_pts_to_inch(vars[10]), # pen_width in inch (1pt = 1.0 / 72) was: 1.0 / SCREEN_DPI
                                             resolution: SCREEN_DPI,
                                             print_scale: Skalp.dialog.drawing_scale.to_f,
                                             zoom_factor: zoom_factor,
                                             user_x: @tile.x_value,
                                             space: vars[2].to_s.to_sym,
                                             section_line_color: vars[12] || "rgb(0,0,0)",
                                             unify: vars[13] == "true",
                                             drawing_priority: (vars[14] || 0).to_i
                                           })
          @tile.gauge = pattern_info[:gauge_ratio]
          @last_preview_base64 = pattern_info[:png_base64] # Store for final set_preview call
          set_value("gauge_ratio", @tile.gauge.to_s)
          script("$('#tile_x').val('#{@tile.x_string}');")
          script("$('#tile_y').val('#{@tile.y_string}');")
        end
      end

      # Use Base64 data URL for instant preview (no disk I/O)
      if @last_preview_base64
        set_preview_base64("hatch_preview", @last_preview_base64)
      else
        set_preview("hatch_preview", "icons/preview.png")
      end
    end

    def set_preview(element_id, image_path)
      # HtmlDialog version: we need to force a refresh by adding a timestamp
      # and the path should be relative to the html folder or absolute
      # Since we are in DevMode, we might need to handle paths carefully
      full_path = @html_path + image_path
      # Check if file exists to avoid broken images during dev
      if File.exist?(full_path)
        timestamp = Time.now.to_i
        script("document.getElementById('#{element_id}').src = '#{image_path}?t=#{timestamp}';")
      else
        puts "Skalp Error: Preview file not found at #{full_path}"
        # Fallback to empty image to avoid broken icon
        script("document.getElementById('#{element_id}').src = 'icons/skalp_empty.png';")
      end
    end

    def set_preview_base64(element_id, base64_data)
      # Direct Base64 data URL - no disk I/O, instant update
      script("document.getElementById('#{element_id}').src = 'data:image/png;base64,#{base64_data}';")
    end

    def delete_hatch(name)
      if SKALP_MATERIALS.include?(name)
        UI.messagebox("This material can't be deleted!")
        script("delete_hatch_ready = true")
        return
      end

      result = UI.messagebox("#{Skalp.translate('Do you want to delete this Skalp material?')} => #{name}", MB_YESNO)

      # Geen start en commit omdat ons mechanisme enkel werkt wanneer ook skalp opgestart is. Ik ga ervan uit dat mits de remove material
      # een sketchup functie is zij zelf de start en commit operation onder controle houden!

      if result == 6
        materials = Sketchup.active_model.materials
        material = materials[name]
        materials.remove(material) if material
      end

      script("select_material('Skalp default')")

      load_patterns_and_materials
      script("delete_hatch_ready = true")
    end

    def update_all_material_scales(su_material)
      materials = []
      for material in Sketchup.active_model.materials do
        if (material.get_attribute("Skalp",
                                   "ID") == su_material.get_attribute("Skalp", "ID")) && !(material == su_material)
          materials << material
        end
      end

      texture = Skalp::IMAGE_PATH + "tile.png"
      ori_scale = Skalp.dialog.drawing_scale.to_f
      ori_scale = 1.0 if ori_scale == 0.0

      new_pattern_string = Skalp.get_pattern_info(su_material)

      for material in materials do
        if new_pattern_string
          old_pattern_string = Skalp.get_pattern_info(material)

          new_scale = old_pattern_string[:print_scale].to_i
          new_scale = 1 if new_scale == 0 # Safeguard new_scale

          calc_size = su_material.texture.width * new_scale / ori_scale
          calc_size = 0.001 if calc_size < 0.001 # Minimum safe size

          material.texture = texture
          material.texture.size = calc_size
          material.metalness_enabled = false
          material.normal_enabled = false

          old_pattern_string = new_pattern_string.dup
          old_pattern_string[:print_scale] = new_scale
          Skalp.set_pattern_info_attribute(material, old_pattern_string)
        else
          material.delete_attribute("Skalp")
        end
      end
    end

    def create_hatch(params)
      puts "[Skalp] create_hatch called. Params: #{params.inspect}"
      script("$('#update_preview').hide()")

      return if params == @params_cache
      return unless @hatch # Check if @hatch exists

      @params_cache = params

      vars = params.split(";")
      if (Skalp.utf8(vars[0]) == "" || Skalp.utf8(vars[11]) == "") && vars[0] != "SOLID_COLOR, solid color without hatching"
        puts "[Skalp] create_hatch: Missing vars!"
      end

      # Ensure tile is calculated from input params
      @tile.calculate(vars[1], :x)

      # -----------------------------------------------------------------------
      # PARAMS MAPPING (Matches hatch_dialog.html v2026.01.01)
      # 0: pattern
      # 1: tile_x
      # 2: units
      # 3: lineweight (paper)
      # 4: lineweight_model
      # 5: line_color
      # 6: fill_color
      # 7: slider
      # 8: isNew
      # 9: aligned
      # 10: sectionCutWidth
      # 11: materialName
      # 12: sectionLineColor
      # 13: unify
      # 14: drawingPriority
      # -----------------------------------------------------------------------

      name = Skalp.utf8(vars[11])
      pen_width = if vars[2].to_sym == :modelspace
                    Skalp::PenWidth.new(vars[4], vars[2],
                                        true)
                  else
                    Skalp::PenWidth.new(vars[3],
                                        vars[2], true)
                  end
      if vars[0] == "SOLID_COLOR, solid color without hatching"
        vars[5] = vars[6]
        solidcolor = true
      else
        solidcolor = false
      end

      script("solid_color(#{solidcolor});")

      pattern_info = @hatch.create_png({
                                         solid_color: solidcolor,
                                         type: :tile,
                                         line_color: vars[5],
                                         fill_color: vars[6],
                                         pen: pen_width.to_inch, # pen_width in inch (1pt = 1.0 / 72)
                                         section_cut_width: Skalp.mm_or_pts_to_inch(vars[10]), # pen_width in inch (1pt = 1.0 / 72) was: 1.0 / SCREEN_DPI
                                         resolution: PRINT_DPI,
                                         print_scale: 1,
                                         user_x: @tile.x_value,
                                         space: vars[2].to_s.to_sym,
                                         section_line_color: vars[12] || "rgb(0,0,0)"
                                       })

      unless pattern_info
        puts "[Skalp] create_hatch: create_png failed"
        return
      end

      Skalp.active_model.start("Skalp - create new material")
      hatch_material = Sketchup.active_model.materials[name] || Sketchup.active_model.materials.add(name)

      hatch_material.texture = Skalp::IMAGE_PATH + "tile.png"
      # Guard against NaN/Infinity in texture size to prevent FloatDomainError
      tile_size = @hatch.tile_width / PRINT_DPI
      if tile_size.nil? || (tile_size.respond_to?(:nan?) && tile_size.nan?) || (tile_size.respond_to?(:infinite?) && tile_size.infinite?) || tile_size.abs < 0.0001
        tile_size = 0.001
      end
      hatch_material.texture.size = tile_size
      hatch_material.metalness_enabled = false
      hatch_material.normal_enabled = false

      Skalp.set_ID(hatch_material)

      # Create thumbnail for layers dialog preview
      # Ensure pattern array includes the name at the beginning
      pattern_array = pattern_info[:original_definition]

      # vars[0] might be the pattern name OR the definition string if things went wrong
      # vars[9] is the material name (user input)

      current_name_or_def = Skalp.utf8(vars[0])
      material_name = Skalp.utf8(vars[11])

      # Determine the best name to use
      pattern_name_to_use = if current_name_or_def =~ /^\d/ # Starts with a digit, likely a definition line
                              material_name
                            else
                              current_name_or_def
                            end

      if pattern_array.is_a?(Array) && pattern_array[0]
        first_line = pattern_array[0].to_s
        # If the first line is NOT a name line (doesn't start with *), prepend the name
        pattern_array = ["*#{pattern_name_to_use}"] + pattern_array unless first_line.start_with?("*")
      end

      # Use the pattern name (first part of vars[0]) NOT the material name (vars[11])
      new_pattern_info = {
        name: Skalp.utf8(vars[0]).split(",").first.strip,
        pattern: pattern_array,
        print_scale: 1,
        resolution: PRINT_DPI,
        user_x: @tile.x_string,
        space: vars[2].to_s.to_sym,
        pen: pen_width.to_s,
        section_cut_width: Skalp.mm_or_pts_to_inch(vars[10]),
        line_color: vars[5],
        fill_color: vars[6],
        gauge_ratio: @tile.gauge.to_s,
        pat_scale: pattern_info[:pat_scale],
        alignment: vars[9],
        section_line_color: vars[12] || "rgb(0,0,0)",
        unify: vars[13] == "true",
        drawing_priority: (vars[14] || 0).to_i
      }

      # Generate thumbnail for this pattern
      begin
        thumb = Skalp.create_thumbnail(new_pattern_info)
        new_pattern_info[:png_blob] = thumb if thumb
      rescue StandardError => e
        puts "[Skalp] create_thumbnail failed: #{e.message}"
        # Thumbnail generation failed, continue without it
      end

      # Optimisation: Check if we need to recalculate section (geometry)
      # Only needed if section_cut_width (line weight) changes
      old_pattern_info = Skalp.get_pattern_info(hatch_material)

      Skalp.set_pattern_info_attribute(hatch_material, new_pattern_info.inspect)

      update_all_material_scales(hatch_material) unless vars[2] == "modelspace"
      # get_section_materials - REMOVED (undefined method)
      load_materials
      select_last_pattern

      # Defer recalculation to on_close
      if Skalp.active_model && Skalp.active_model.active_sectionplane && Skalp.dialog.lineweights_status &&
         (old_pattern_info.nil? ||
          (old_pattern_info[:section_cut_width].to_f - new_pattern_info[:section_cut_width].to_f).abs > 0.000001 ||
          old_pattern_info[:drawing_priority] != new_pattern_info[:drawing_priority] ||
          old_pattern_info[:unify] != new_pattern_info[:unify] ||
          old_pattern_info[:section_line_color] != new_pattern_info[:section_line_color])

        @recalc_section_needed = true
      end
      Skalp.set_thea_render_params(hatch_material)

      Skalp.active_model.commit

      # Refresh layers dialog to show updated preview
      Skalp.update_layers_dialog
      @updated_layers = true

      layer_name = "\uFEFF".encode("utf-8") + "Skalp Pattern Layer - " + hatch_material.name
      Skalp.create_Color_by_Layer_layers([hatch_material], true) if Sketchup.active_model.layers[layer_name]
    end

    def generate_thumbnails
      patterns = SkalpHatch.hatchdefs
      patterns.each do |hatchdef|
        name = hatchdef.name.to_s.strip.gsub(/[^a-zA-Z0-9]/, "_")
        filepath = File.join(@thumb_path, "#{name}.png")
        next if File.exist?(filepath)

        begin
          hatch = Skalp::SkalpHatch::Hatch.new
          hatch.add_hatchdefinition(hatchdef)
          hatch.create_png({
                             solid_color: false,
                             type: :thumbnail,
                             width: 50,
                             height: 50,
                             output_path: filepath
                           })
        rescue StandardError => e
          # Skip patterns that fail to render
        end
      end
    end
  end
end
