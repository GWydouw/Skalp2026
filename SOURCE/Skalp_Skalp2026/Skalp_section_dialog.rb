module Skalp
  class Sections_dialog < Webdialog
    attr_accessor :webdialog, :active_sectionplane_toggle, :active_skpModel, :dxf_path, :showmore_dialog

    include StyleSettings

    def initialize
      @active_skpModel = Sketchup.active_model
      @html_path = Sketchup.find_support_file("Plugins") + "/Skalp_Skalp2026/html/"

      read_border_size

      @w_size = 255
      @h_size = 78
      @h_size_expand = 275

      @showmore_dialog = true
      @startup = true
      @width = @w_size
      @height = {}
      @height[:sections] = @h_size
      @height_expand = {}
      @height_expand[:sections] = @h_size_expand

      @height_expand_resize = if Sketchup.read_default("Skalp",
                                                       "height_expand_resize").to_i > 0
                                Sketchup.read_default("Skalp",
                                                      "height_expand_resize").to_i
                              else
                                @height_expand[:sections]
                              end
      @dialog_x = if Sketchup.read_default("Skalp",
                                           "sections_x").to_i > 0
                    Sketchup.read_default("Skalp",
                                          "sections_x").to_i
                  else
                    100
                  end
      @dialog_y = if Sketchup.read_default("Skalp",
                                           "sections_y").to_i > 0
                    Sketchup.read_default("Skalp",
                                          "sections_y").to_i
                  else
                    100
                  end
      @dialog_w = if Sketchup.read_default("Skalp",
                                           "sections_w").to_i > 0
                    Sketchup.read_default("Skalp",
                                          "sections_w").to_i
                  else
                    @width
                  end
      @show_more_saved = Sketchup.read_default("Skalp", "sections_show_more").to_i

      @dialogbox_type = :sections
      @show_more_toggle = {}
      @show_more_toggle[:sections] = false
      @temp_tag = []

      @webdialog = if Skalp::OS == :WINDOWS
                     UI::WebDialog.new(Skalp.translate("Skalp"), false, "Skalp", @width + @w_border,
                                       @height[:sections] + @h_border, 0, 0, true)
                   else
                     UI::WebDialog.new(Skalp.translate("Skalp"), false, "Skalp", @width + @w_border,
                                       @height[:sections] + @h_border, 0, 0, false)
                   end

      @webdialog.set_file(@html_path + "skalp_dialog.html")

      Skalp.message1 unless Skalp.ready

      @webdialog.set_position(@dialog_x, @dialog_y)
      self.min_height = @height[:sections]
      self.max_height = @height[:sections]
      self.min_width = @w_size
      set_size(@dialog_w, @height[:sections])

      @webdialog.show if Skalp::OS == :WINDOWS # workaround for windows, dialoog start anders niet op van de eerste keer

      @webdialog.add_action_callback("reset_dialog_undo_flag") do |webdialog, params|
        Skalp.active_model.dialog_undo_flag = false
      end

      # DIALOG ####################
      @webdialog.add_action_callback("dialog_focus") do
        Skalp.stop_skalp unless Sketchup.active_model

        if Sketchup.active_model&.get_attribute("Skalp", "CreateSection") != false
          Skalp.style_update = true
          if !Skalp.models[Sketchup.active_model]
            UI.start_timer(0.01, false) { Skalp.activate_model(Sketchup.active_model) }
          elsif Sketchup.active_model != @active_skpModel
            @active_skpModel = Sketchup.active_model
            Skalp.change_active_model(Sketchup.active_model)
          else
            update_dialog_lists
          end
          no_focus
        end
      end

      @webdialog.add_action_callback("dialog_blur") do |webdialog, params|
        vars = params.split(";")
        x = vars[0]
        y = vars[1]
        style = vars[2]

        apply_style(style) if style && style != ""

        Sketchup.write_default("Skalp", "sections_x", x)
        Sketchup.write_default("Skalp", "sections_y", y)

        Skalp.style_update = false
        no_focus
      end

      @webdialog.add_action_callback("puts") do |webdialog, params|
        puts params
      end

      @webdialog.add_action_callback("dialog_resize") do |webdialog, params|
        vars = params.split(";")

        @dialog_w = vars[0].to_i
        @dialog_h = vars[1].to_i

        @dialog_w = @min_w if @dialog_w < @min_w
        @dialog_h = @max_h if @dialog_h > @max_h
        @dialog_h = @min_h if @dialog_h < @min_h

        Sketchup.write_default("Skalp", "sections_w", @dialog_w)

        if @show_more_toggle[:sections]
          @height_expand_resize = @dialog_h
          Sketchup.write_default("Skalp", "height_expand_resize", @height_expand_resize)
        end
      end

      # UPDATE SKALP SETTING TO ACTIVE SCENE
      @webdialog.add_action_callback("update_Skalp_scene") do |webdialog, value|
        unless Skalp.active_model.dialog_undo_flag
          data = {
            action: :update_skalp_scene
          }
          Skalp.active_model.controlCenter.add_to_queue(data)
        end
      end

      #####################################
      # SECTIONS
      #####################################

      # SET STYLE SETTINGS

      @webdialog.add_action_callback("change_drawing_scale") do |webdialog, value|
        save_drawing_scale(value.to_f)
        Skalp.set_default_drawing_scale(value.to_f)
        update_active_sectionplane
        Skalp.active_model.hiddenlines.update_scale if Sketchup.read_default("Skalp", "linestyles") != "SketchUp"
        settings_to_active_page_if_save_settings_is_on
      end

      @webdialog.add_action_callback("set_rearview_switch") do |webdialog, params|
        toggle_rear_view_command(params)
      end

      @webdialog.add_action_callback("set_linestyle") do |webdialog, params|
        set_linestyle(params)
      end

      @webdialog.add_action_callback("set_lineweights_switch") do |webdialog, params|
        toggle_lineweights_command(params)
      end

      @webdialog.add_action_callback("set_fog_switch") do |webdialog, params|
        toggle_depth_clipping_command(params)
      end

      @webdialog.add_action_callback("set_fog_distance") do |webdialog, params|
        set_fog_distance(params)
        settings_to_active_page_if_save_settings_is_on
      end

      # STYLES ###############################
      @webdialog.add_action_callback("apply_style") do |webdialog, params|
        apply_style(params)
      end

      @webdialog.add_action_callback("save_active_style_to_library") do |webdialog, params|
        style_rules.save_to_library
      end

      @webdialog.add_action_callback("load_style_from_library") do |webdialog, params|
        style_rules.load_from_library
      end

      def apply_style(params)
        return unless Skalp.style_update
        return unless Sketchup.active_model == @active_skpModel
        return unless Skalp.status == 1

        check = params.slice!(0..1).slice(0) # remove check
        params.slice!(0..0) # remove first | from string
        params.chomp!("|") # remove last | from string
        params = params.split("|,|")

        Skalp.active_model.start("Skalp - #{Skalp.translate('save style settings')}", true)

        settings_from_dialog(params)

        if check == "1"
          Skalp.active_model.save_settings = true
          settings_to_page(Sketchup.active_model.pages.selected_page) if Sketchup.active_model.pages.selected_page
        else
          Skalp.active_model.save_settings = false
          remove_settings(Sketchup.active_model.pages.selected_page) if Sketchup.active_model.pages.selected_page
        end

        materialnames = Set.new
        materialnames << Skalp.utf8(params[1]) if params[1] != ""

        style_rules = params[2..-1]

        for i in (0..style_rules.size - 1).step(14)
          style_type = style_rules[i + 2]
          style_type_setting = Skalp.utf8(style_rules[i + 5])
          style_pattern = Skalp.utf8(style_rules[i + 11])

          next if ["", "undefined"].include?(style_type)
          next if ["", "undefined"].include?(style_type_setting)

          materialnames << style_pattern if style_pattern != ""
        end

        Skalp.add_skalp_material_to_instance(materialnames.to_a)

        Skalp.active_model.commit

        data = {
          action: :update_style
        }

        Skalp.active_model.controlCenter.add_to_queue(data)
      end

      # SECTION_UPDATE ####################
      @webdialog.add_action_callback("sections_update") do |webdialog, params|
        section_update_command(params)
      end

      @webdialog.add_action_callback("sections_update_all") do |webdialog, params|
        rearview = Skalp.to_boolean(params)

        if (Sketchup.active_model == @active_skpModel) && Skalp.active_model && @active_skpModel.pages.count > 0
          Skalp.active_model.update_all_pages(false, rearview)
          rearview_status_black if rearview_update
        end
      end

      @webdialog.add_action_callback("export_LayOut") do
        if (Sketchup.active_model == @active_skpModel) && Skalp.active_model && @active_skpModel.pages.count > 0
          Skalp.active_model.update_all_pages(true, true)
        end
      end

      # SECTION_SWITCH ####################
      @sections_switch_toggle = true

      @webdialog.add_action_callback("set_live_updating") do
        if !Skalp.active_model.dialog_undo_flag && (Sketchup.active_model == @active_skpModel)
          @sections_switch_toggle = !@sections_switch_toggle

          if @sections_switch_toggle
            Skalp.live_section_ON = true
            Skalp.active_model.live_section_on
            update_active_sectionplane
            script(%^$("#live_updating").text("#{Skalp.translate('Turn OFF Skalp Section Fill')}")^)
            script("$('#sections_list').css('color','black')")
            script("$('#sections_rename').css('color','black')")
          else
            Skalp.live_section_ON = false
            Skalp.active_model.live_section_off
            script(%^$("#live_updating").text("#{Skalp.translate('Turn ON Skalp Section Fill')}")^)
            script("$('#sections_list').css('color','red')")
            script("$('#sections_rename').css('color','red')")
          end
        end
      end

      @webdialog.add_action_callback("align_view") do
        align_view_command
      end

      @webdialog.add_action_callback("reverse_sectionplane") do
        reverse_sectionplane
      end

      @webdialog.add_action_callback("switch_rendermode") do |webdialog, params|
        toggle_hiddenline_mode_command(params)
      end

      # SECTION_ADD ####################
      @webdialog.add_action_callback("sections_add") do
        if !Skalp.active_model.dialog_undo_flag && (Sketchup.active_model == @active_skpModel)
          Sketchup.send_action("selectSectionPlaneTool:")
        end
      end

      # SECTION_DELETE ####################
      @webdialog.add_action_callback("sections_delete") do
        if !Skalp.active_model.dialog_undo_flag && (Sketchup.active_model == @active_skpModel) && get_value("sections_list") != "" && Skalp.active_model.active_sectionplane
          Skalp.active_model.delete_sectionplane(Skalp.active_model.active_sectionplane)
        end
      end
      # SECTION_SHOW_MORE ####################

      @webdialog.add_action_callback("sections_show_more") do |webdialog, params|
        @show_more_toggle[:sections] = !@show_more_toggle[:sections]
        vars = params.split(";")
        @dialog_x = vars[0]
        @dialog_y = vars[1]
        show_more(:sections)
      end

      # SECTION_LIST #################
      # sections

      @webdialog.add_action_callback("change_active_sectionplane") do |webdialog, params|
        if !Skalp.active_model.dialog_undo_flag && !Skalp.page_change
          data = {
            action: :change_active_sectionplane,
            sectionplane: Skalp.utf8(params)
          }
          Skalp.active_model.controlCenter.add_to_queue(data)
        end
      end

      @active_sectionplane_toggle = false
      @webdialog.add_action_callback("active_sectionplane_toggle") do |webdialog, params|
        sectionplane_toggle_command
      end
      # sections rename
      @webdialog.add_action_callback("rename_sectionplane") do |webdialog, params|
        if !Skalp.active_model.dialog_undo_flag && (Sketchup.active_model == @active_skpModel)
          Skalp.active_model.active_sectionplane.rename(Skalp.utf8(params))
          update(1)
        end
      end
      #####################################
      # MATERIAL
      #####################################

      # MATERIAL SELECTOR ##########################
      @webdialog.add_action_callback("materialSelector") do |webdialog, params|
        vars = params.split(";")
        x = vars[0]
        y = vars[1]
        id = vars[2]

        Skalp::Material_dialog.show_dialog(x, y, webdialog, id)
      end

      @webdialog.add_action_callback("su_focus") do
      end

      @webdialog.add_action_callback("define_tag") do |webdialog, tag|
        if Sketchup.active_model == @active_skpModel
          Skalp.active_model.start("Skalp - #{Skalp.translate('define tag')}", true)
          entities = []

          tag = tag.gsub(" ", "")
          new_tags = tag.split(",")

          new_tags.map! { |tag| Skalp.utf8(tag) }

          selection = Sketchup.active_model.selection

          for e in selection
            next unless e.valid?

            if selection.size == 1
              e.set_attribute("Skalp", "tag", new_tags.join(","))
            else
              old_tags = if e.get_attribute("Skalp",
                                            "tag")
                           e.get_attribute("Skalp",
                                           "tag").split(",")
                         else
                           [e.get_attribute(
                             "Skalp", "tag"
                           )]
                         end

              tags = if old_tags == []
                       new_tags
                     elsif @temp_tag != []
                       (old_tags - @temp_tag) + new_tags
                     else
                       old_tags + new_tags
                     end

              tags ? e.set_attribute("Skalp", "tag", tags.join(",")) : e.set_attribute("Skalp", "tag", "")
            end
            entities << e
          end

          Skalp.active_model.commit

          entities.each do |e|
            data = {
              action: :changed_tag,
              entity: e
            }

            Skalp.active_model.controlCenter.add_to_queue(data)
          end
        end
      end

      @webdialog.add_action_callback("deselect") do |webdialog, params|
        Sketchup.active_model.selection.clear
      end

      @webdialog.add_action_callback("hatch_generator") do |webdialog, params|
        if Skalp.hatch_dialog
          Skalp.hatch_dialog.show
        else
          Skalp.hatch_dialog = Hatch_dialog.new
          Skalp.hatch_dialog.show
        end
      end

      @webdialog.add_action_callback("create_color_by_layer_layers") do |webdialog, params|
        Skalp.create_Color_by_Layer_layers
      end

      @webdialog.add_action_callback("define_layer_materials") do |webdialog, params|
        Skalp.define_layers_dialog
      end

      @webdialog.add_action_callback("edit_hatchmaterial") do |webdialog, params|
        hatchname = Skalp.utf8(params)
        Skalp.edit_skalp_material(hatchname)
      end

      @webdialog.add_action_callback("export_patterns") do |webdialog, params|
        Skalp.export_material_textures(true)
      end

      @webdialog.add_action_callback("set_render_brightness") do |webdialog, params|
        Skalp.set_render_brightness
      end

      @webdialog.add_action_callback("set_linestyle_system") do |webdialog, params|
        active_setting = Sketchup.read_default("Skalp", "linestyles")

        default_val = active_setting == "Skalp" ? "Skalp" : "SketchUp"

        Skalp.inputbox_custom(["Linestyles?"], [default_val], ["Skalp|SketchUp"], "Set Linestyle System") do |input|
          next unless input

          if input[0] == "SketchUp"
            Sketchup.write_default("Skalp", "linestyles", "SketchUp")
            script("$('#linestyles_div').show()")
          else
            Sketchup.write_default("Skalp", "linestyles", "Skalp")
            script("$('#linestyles_div').hide()")
          end
        end
      end

      @webdialog.add_action_callback("export_materials") do |webdialog, params|
        Skalp.export_skalp_materials
      end

      @webdialog.add_action_callback("import_materials") do |webdialog, params|
        Skalp.import_skalp_materials
      end

      @webdialog.add_action_callback("export_layer_mapping") do |webdialog, params|
        Skalp.export_layer_mapping
      end

      @webdialog.add_action_callback("import_layer_mapping") do |webdialog, params|
        Skalp.import_layer_mapping
      end

      @webdialog.add_action_callback("scenes2images") do |webdialog, params|
        Skalp.scenes2images
      end

      @webdialog.add_action_callback("skalp2dxf") do |webdialog, params|
        Skalp.dwg_export
      end

      @webdialog.add_action_callback("set_hiddenline_style") do |webdialog, params|
        Skalp.hiddenline_style_dialog
      end

      @webdialog.add_action_callback("set_section_offset") do |webdialog, params|
        Skalp.set_section_offset
      end

      @webdialog.add_action_callback("define_sectionmaterial") do |webdialog, sectionmaterial|
        define_sectionmaterial(sectionmaterial)
      end

      # MATERIAL_SHOW_MORE ####################

      @webdialog.add_action_callback("material_show_more") do |webdialog, params|
        @show_more_toggle[:material] = !@show_more_toggle[:material]
        vars = params.split(";")
        @dialog_x = vars[0]
        @dialog_y = vars[1]
        show_more(:material)
      end

      # SHOW ###############################
      @webdialog.add_action_callback("dialog_ready") do |webdialog, params|
        write_border_size(:sections)

        self.min_height = @height[:sections]
        self.max_height = @height[:sections]

        if @show_more_saved == 1
          @show_more_toggle[:sections] = !@show_more_toggle[:sections]
          show_more(:sections)
        else
          visibility("dialog_styles", false)
          visibility("save_style", false)
          visibility("display_settings_blured", false)
        end

        if Sketchup.active_model && Skalp.active_model
          get_sectionplanes
          get_section_materials

          if Sketchup.active_model.pages && Sketchup.active_model.pages.selected_page
            update_styles(Sketchup.active_model.pages.selected_page)
          else
            update_styles(Sketchup.active_model)
          end

          show_sections
          update_dialog_lists
          # set_dialog_translation
          update_dialog
          show

          if Sketchup.read_default("Skalp", "linestyles") == "Skalp"
            script("$('#linestyles_div').hide()")
          else
            script("$('#linestyles_div').show()")
          end

          @webdialog.bring_to_front
          Skalp.dialog_loading = false

          sectionplane = Sketchup.active_model.entities.active_section_plane
          if sectionplane && sectionplane.get_attribute("Skalp", "sectionplane_name")
            section_name = sectionplane.get_attribute("Skalp", "sectionplane_name")
            if Skalp.active_model.active_sectionplane
              # Skalp.page_change = true
              Skalp.dialog.script("$('#sections_list').val('#{section_name}')")
              Skalp.dialog.script("change_active_sectionplane('#{section_name}')")
              # Skalp.page_change = false
            end
          else

            Skalp.dialog.script("$('#sections_list').val('- #{NO_ACTIVE_SECTION_PLANE} -')")
            Skalp.dialog.script("change_active_sectionplane('- #{NO_ACTIVE_SECTION_PLANE} -')")
          end
        end
        no_focus
      end

      @webdialog.add_action_callback("reset_style") do
        reset_style
      end

      # LISTS_UPDATE ####################
      @webdialog.add_action_callback("update_dialog_lists") do
        update_dialog_lists
      end

      @webdialog.set_on_close do
        if @webdialog.get_element_value("RUBY_BRIDGE") == "ESC"
          if OS == :MAC
            UI.start_timer(0, false) do
              @webdialog.show_modal
            end
          end
        else
          unless @show_more
            Skalp.stop_skalp(false)
            Skalp.skalpbutton_off
            Skalp.dialog_loading = false
          end
        end
      end
    end

    def define_sectionmaterial(sectionmaterial, object = nil)
      return unless Sketchup.active_model == Skalp.active_model.skpModel

      selection = if object
                    [object]
                  else
                    Sketchup.active_model.selection
                  end

      Skalp.active_model.start("Skalp - " + Skalp.translate("define section material"), true)
      entities = []
      for e in selection
        next unless e.valid? && e.class != Sketchup::SectionPlane

        if Skalp.utf8(sectionmaterial) == "- #{Skalp.translate('None')} -"
          e.delete_attribute "Skalp"
        else
          e.set_attribute("Skalp", "sectionmaterial", Skalp.utf8(sectionmaterial))
        end
        entities << e
      end

      Skalp.add_skalp_material_to_instance([Skalp.utf8(sectionmaterial)])
      Skalp.active_model.commit

      entities.each do |e|
        data = {
          action: :changed_sectionmaterial,
          entity: e
        }
        Skalp.active_model.controlCenter.add_to_queue(data)
      end
    end

    def no_active_sectionplane(page = nil)
      blur_dialog_settings
      script("$('#sections_list').val('- #{NO_ACTIVE_SECTION_PLANE} -')")
      script("change_active_sectionplane('- #{NO_ACTIVE_SECTION_PLANE} -')")

      Skalp.active_model.set_active_sectionplane("")
      Skalp.sectionplane_active = false

      Skalp.dialog.update
      Skalp.active_model.pagesUndoRedo.update_dialog

      for layer in Sketchup.active_model.layers
        next unless layer.valid?

        page.set_visibility(layer, false) if layer.get_attribute("Skalp", "ID") && page
      end

      return if page

      Skalp.active_model && Skalp.active_model.live_sectiongroup.valid? && Skalp.active_model.live_sectiongroup.layer.visible = false
    end

    def section_update_command(params)
      return if Skalp.active_model.dialog_undo_flag

      rearview = Skalp.to_boolean(params)
      rearview_status_red
      save_rearview_update(rearview)

      return unless Sketchup.active_model == @active_skpModel

      status = Skalp.live_section_ON
      Skalp.live_section_ON = true

      if OS == :WINDOWS
        if rearview_status && rearview_update
          Sketchup.set_status_text "#{Skalp.translate('Update Section')} (#{Skalp.translate('step')} 1/2) #{Skalp.translate('Please wait...')}"
          update_active_sectionplane
          Sketchup.set_status_text "#{Skalp.translate('Processing and adding rear lines')} (#{Skalp.translate('step')} 2/2) #{Skalp.translate('Please wait...')}"
          # update_rear_lines now automatically adds lines to model after calculation
          Skalp.active_model.hiddenlines.update_rear_lines
          rearview_status_black if Skalp.active_model.model_changes == false
        else
          Sketchup.set_status_text "#{Skalp.translate('Update Section')} (#{Skalp.translate('step')} 1/1) #{Skalp.translate('Please wait...')}"
          update_active_sectionplane
        end

        Skalp.live_section_ON = status
        Sketchup.set_status_text "#{Skalp.translate('Section successfully updated.')}"

      else
        if rearview_status && rearview_update
          UI.start_timer(0.01, false) do
            Sketchup.set_status_text "#{Skalp.translate('Update Section')} (#{Skalp.translate('step')} 1/2) #{Skalp.translate('Please wait...')}"
          end
          UI.start_timer(0.01, false) { update_active_sectionplane }
          UI.start_timer(0.01, false) do
            Sketchup.set_status_text "#{Skalp.translate('Processing and adding rear lines')} (#{Skalp.translate('step')} 2/2) #{Skalp.translate('Please wait...')}"
          end
          # update_rear_lines now automatically adds lines to model after calculation
          UI.start_timer(0.01, false) { Skalp.active_model.hiddenlines.update_rear_lines }
          UI.start_timer(0.01, false) { rearview_status_black if Skalp.active_model.model_changes == false }
        else
          UI.start_timer(0.01, false) do
            Sketchup.set_status_text "#{Skalp.translate('Update Section')} (#{Skalp.translate('step')} 1/1) #{Skalp.translate('Please wait...')}"
          end
          UI.start_timer(0.01, false) { update_active_sectionplane }
        end

        UI.start_timer(0.01, false) do
          Skalp.live_section_ON = status
          Sketchup.set_status_text "#{Skalp.translate('Section successfully updated.')}"
        end
      end
    end

    def toggle_hiddenline_mode_command(params)
      observer_status = Skalp.block_observers
      Skalp.block_observers = true
      if params == "active"
        Skalp.check_color_by_layer_layers
        Skalp.active_model.rendering_options.set_hiddenline_mode

        if Skalp.active_model && Skalp.active_model.active_sectionplane
          Skalp.block_observers = observer_status
          Skalp.active_model.active_sectionplane.calculate_section(nil, false)
        end
      else
        Skalp.active_model.rendering_options.reset_hiddenline_mode
        Skalp.block_observers = observer_status
      end
    end

    def toggle_rear_view_command(params)
      set_rearview_switch(Skalp.to_boolean(params))
      if Skalp.to_boolean(params)
        set_select_linestyle_active
        if check_rearview_uptodate
          turnon_rearview_lines_in_model
        else
          result = UI.messagebox("Do you want to calculate the 'Rear View Projection'?", MB_YESNO)
          if result == IDYES
            section_update_command(true)
          else
            rearview_status_red
          end
        end
      else
        set_select_linestyle_inactive
        rearview_status_black
        turnoff_rearview_lines_in_model
      end
      settings_to_active_page_if_save_settings_is_on
    end

    def set_linestyle(linestyle_name)
      save_rearview_linestyle(linestyle_name)
      settings_to_active_page_if_save_settings_is_on

      Skalp.active_model.start("Skalp - set rearview linestyle")
      layer = Skalp.create_linestyle_layer(linestyle_name)

      rear_view_def = Skalp.active_model.hiddenlines.rear_view_definitions[Sketchup.active_model.pages.selected_page]
      rear_view_def.entities.each { |e| e.layer = layer } if rear_view_def

      Skalp.active_model.commit
    end

    def toggle_depth_clipping_command(params)
      if Sketchup.active_model.entities.active_section_plane
        set_fog_switch(Skalp.to_boolean(params))
        settings_to_active_page_if_save_settings_is_on
      else
        UI.messagebox(Skalp.translate("Easy Fog only works when there is an active Section Plane."))
        fog_status_switch_off
      end
    end

    def toggle_lineweights_command(params)
      set_lineweights_switch(Skalp.to_boolean(params))
      update_active_sectionplane
      settings_to_active_page_if_save_settings_is_on
    end

    def align_view_command
      unless (Sketchup.active_model == @active_skpModel) && Skalp.active_model && Skalp.active_model.active_sectionplane
        return
      end

      sectionplane = Skalp.active_model.active_sectionplane
      Skalp.align_view(sectionplane.skpSectionPlane)
      Skalp.fog if fog_status
    end

    def reverse_sectionplane
      unless (Sketchup.active_model == @active_skpModel) && Skalp.active_model && Skalp.active_model.active_sectionplane
        return
      end

      sectionplane = Skalp.active_model.active_sectionplane.skpSectionPlane
      return unless sectionplane.valid?

      create_new_sectionplane = UI.messagebox("Create a new section?", MB_YESNO)

      Sketchup.active_model.start_operation("Skalp - reverse sectionplane", true, false, false)
      Skalp.reverse_view
      if create_new_sectionplane == IDYES
        prompts = %w[Name Symbol]
        defaults = [sectionplane.name, sectionplane.symbol]
        list = ["", ""]
        Skalp.inputbox_custom(prompts, defaults, list, "Name Section Plane") do |input|
          if input
            new_sectionplane = Sketchup.active_model.entities.add_section_plane(sectionplane.get_plane.map! { |i| -i })
            new_sectionplane.name = input[0]
            new_sectionplane.symbol = input[1][0..2]
            new_sectionplane.activate
          end
          Sketchup.active_model.commit_operation
        end
      else
        sectionplane.set_plane(sectionplane.get_plane.map! { |i| -i })
        Sketchup.active_model.commit_operation
      end
    end

    def sectionplane_toggle_command
      return unless Skalp.active_model && Sketchup.active_model == @active_skpModel

      @active_section_switch_toggle = !@active_section_switch_toggle

      if @active_sectionplane_toggle
        script("$('#sections_list').val('- #{NO_ACTIVE_SECTION_PLANE} -')")
        script("change_active_sectionplane('- #{NO_ACTIVE_SECTION_PLANE} -')")
      elsif Sketchup.active_model.pages.selected_page && Skalp.active_model.get_memory_attribute(
        Sketchup.active_model.pages.selected_page, "Skalp", "ID"
      )
        active_sectionplane = Skalp.active_model.sectionplane_by_id(Skalp.active_model.get_memory_attribute(
                                                                      Sketchup.active_model.pages.selected_page, "Skalp", "sectionplaneID"
                                                                    ))
        if active_sectionplane
          active_sectionplane_name = active_sectionplane.sectionplane_name
          script("$('#sections_list').val('#{active_sectionplane_name}')")
          script("change_active_sectionplane('#{active_sectionplane_name}')")
        else
          script("$('#sections_list').val('- #{NO_ACTIVE_SECTION_PLANE} -')")
          script("change_active_sectionplane('- #{NO_ACTIVE_SECTION_PLANE} -')")
        end
      else
        script("$('#sections_list').val('- #{NO_ACTIVE_SECTION_PLANE} -')")
        script("change_active_sectionplane('- #{NO_ACTIVE_SECTION_PLANE} -')")

        if (Skalp.active_model.sectionplanes == {}) && (Sketchup.active_model == @active_skpModel)
          Sketchup.send_action("selectSectionPlaneTool:")
        end
      end
    end

    def set_dialog_translation
      # icons
      string = Skalp.translate("Activate Sectionplane Toggle")
      @webdialog.execute_script(%^$("#sections_switch").prop("title", "#{string}")^)
      string = Skalp.translate("Manual Update")
      @webdialog.execute_script(%^$("#sections_update").prop("title", "#{string}")^)
      string = Skalp.translate("Place new Section Plane")
      @webdialog.execute_script(%^$("#sections_add").prop("title", "#{string}")^)
      string = Skalp.translate("Delete active Section Plane")
      @webdialog.execute_script(%^$("#sections_delete").prop("title", "#{string}")^)
      string = Skalp.translate("Drawing Scale")
      @webdialog.execute_script(%^$("#drawing_scale").prop("title", "#{string}")^)
      string = Skalp.translate("Save settings to Scene")
      @webdialog.execute_script(%^$("#not_uptodate").prop("title", "#{string}")^)
      string = Skalp.translate("Show more")
      @webdialog.execute_script(%^$("#sections_show_more").prop("title", "#{string}")^)
      string = Skalp.translate("Menu")
      @webdialog.execute_script(%^$("#sections_menu").prop("title", "#{string}")^)

      # menu
      string = Skalp.translate("Export")
      @webdialog.execute_script(%^$("#label_export").prop("label","#{string}")^)

      string = Skalp.translate("Export active view to DXF")
      @webdialog.execute_script(%^$("#export_active_view_to_dxf").text("#{string}")^)
      string = Skalp.translate("Export all scenes to DXF")
      @webdialog.execute_script(%^$("#export_all_scenes_to_dxf").text("#{string}")^)

      string = Skalp.translate("Preferences")
      @webdialog.execute_script(%^$("#label_preferences").prop("label","#{string}")^)

      string = Skalp.translate("Turn OFF Skalp Section Fill")
      @webdialog.execute_script(%^$("#live_updating").text("#{string}")^)
      string = Skalp.translate("Set Section Offset Distance")
      @webdialog.execute_script(%^$("#offset_distance").text("#{string}")^)

      # selectionbox
      string = Skalp.translate("Select Sectionplane")
      @webdialog.execute_script(%^$("#sections_arrow").prop("title", "#{string}")^)
      string = Skalp.translate("Rename Section Plane")
      @webdialog.execute_script(%^$("#sections_rename").prop("title", "#{string}")^)

      # styles
      string = Skalp.translate("Pattern Fill Rules:")
      @webdialog.execute_script(%^$("#style_title").text("#{string}")^)

      string = Skalp.translate("Add new rule line")
      @webdialog.execute_script(%^$("#add_item").prop("title", "#{string}")^)
      string = Skalp.translate("Edit Skalp Style")
      @webdialog.execute_script(%^$("#edit_style").prop("title", "#{string}")^)

      string = Skalp.translate("save style to scene")
      @webdialog.execute_script(%^$("#save_style").text("#{string}")^)
      @webdialog.execute_script(%^$("#save_style").append("<input type='checkbox' name='save' id='save_check' onchange='save_style()' >")^)
    end

    def model_changed
      Skalp.active_model.hiddenlines.uptodate = {}
      rearview_status_red if rearview_status
    end

    def show_drawing_scale
      if @webdialog.get_element_value("sections_list").to_s == "- #{NO_ACTIVE_SECTION_PLANE} -"
        @webdialog.execute_script("$('#drawing_scale_title').show()")
        @webdialog.execute_script("$('#drawing_scale').show()")
      else
        @webdialog.execute_script("$('#drawing_scale_title').hide()")
        @webdialog.execute_script("$('#drawing_scale').hide()")
      end
    end

    def show
      Skalp::OS == :MAC ? @webdialog.show_modal : @webdialog.show
    end

    def no_focus
      script("if (document.activeElement != document.body) document.activeElement.blur();")
    end

    def update_dialog_lists
      return unless Sketchup.active_model

      set_value_clear("patterns")
      patterns = get_patterns
      patterns.each do |pat|
        if patterns.first == pat
          set_value_add("patterns", "#{pat}")
        else
          set_value_add("patterns", ";#{pat}")
        end
      end

      set_value_clear("layers")
      layers = get_layers(1)
      layers.each do |layer|
        if layers.first == layer
          set_value_add("layers", "#{layer}")
        else
          set_value_add("layers", ";#{layer}")
        end
      end

      set_value_clear("layers2")
      layers = get_layers(2)
      layers.each do |layer|
        if layers.first == layer
          set_value_add("layers2", "#{layer}")
        else
          set_value_add("layers2", ";#{layer}")
        end
      end

      set_value_clear("scenes")
      scenes = get_scenes
      scenes.each do |scene|
        if scenes.first == scene
          set_value_add("scenes", "#{scene}")
        else
          set_value_add("scenes", ";#{scene}")
        end
      end

      script("multitag_visible = #{multitag_visible?}")
      script("model_lists()")
    end

    def multitag_visible?
      return true if defined?(AW::Tags)

      # Check model default style
      model_settings = Skalp::StyleSettings.style_settings(Sketchup.active_model)
      if model_settings[:style_rules] && model_settings[:style_rules].respond_to?(:any?) && model_settings[:style_rules].any? do |r|
        r[:type] == :ByMultiTag
      end
        return true
      end

      # Check scenes
      Sketchup.active_model.pages.each do |page|
        page_settings = Skalp.active_model.get_memory_attribute(page, "Skalp", "style_settings")
        next unless page_settings.is_a?(Hash) && page_settings[:style_rules]

        if page_settings[:style_rules].respond_to?(:any?) && page_settings[:style_rules].any? do |r|
          r[:type] == :ByMultiTag
        end
          return true
        end
      end

      false
    end

    def reset_style
      object = if Sketchup.active_model.pages && Sketchup.active_model.pages.selected_page
                 Sketchup.active_model.pages.selected_page
               else
                 Sketchup.active_model
               end

      settings = Skalp::StyleSettings.style_settings(object)[:style_rules] || StyleRules.new
      settings.create_default_model_rule
      update_dialog

      return if Skalp.active_model.page_undo

      data = {
        action: :update_style
      }

      Skalp.active_model.controlCenter.add_to_queue(data) unless Skalp.page_change
    end

    def update_styles(object)
      page_changed(object) if Skalp.page_change

      return if Skalp.active_model.page_undo

      data = {
        action: :update_style
      }

      Skalp.active_model.controlCenter.add_to_queue(data) unless Skalp.page_change
    end

    def update_active_sectionplane
      return unless Skalp.active_model && Skalp.active_model.active_sectionplane

      Skalp.active_model.active_sectionplane.calculate_section
    end

    def get_sectionplanes(sectionplane_name = nil)
      clear("sections_list")

      add("sections_list", "- #{NO_ACTIVE_SECTION_PLANE} -")

      section_list = []

      Skalp.active_model.sectionplanes.each_value do |sectionplane|
        section_list << sectionplane.sectionplane_name if sectionplane.sectionplane_name
      end

      section_list << sectionplane_name if sectionplane_name

      section_list.sort!

      for section_name in section_list
        add("sections_list", section_name)
      end

      if sectionplane_name
        set_value("sections_list", sectionplane_name)
      elsif Skalp.active_model.active_sectionplane
        set_value("sections_list", Skalp.active_model.active_sectionplane.sectionplane_name)
      else
        set_value("sections_list", "- #{NO_ACTIVE_SECTION_PLANE} -")
      end
      set_delete_button
    end

    def selected_materials
      materials = []
      for e in Skalp.active_model.skpModel.selection
        materials << e.get_attribute("Skalp", "sectionmaterial")
      end

      materials = materials.compact
      materials.uniq!
      if materials.size == 1
        materials[0].to_s
      elsif materials.size == 0
        "Skalp default"
      else
        "- #{Skalp.translate('Multiple selected')} -"
      end
    end

    def selected_tags
      tags = []
      first = false
      for e in Skalp.active_model.skpModel.selection
        tag = if e.get_attribute("Skalp",
                                 "tag") != nil && e.get_attribute("Skalp",
                                                                  "tag") != ""
                e.get_attribute("Skalp",
                                "tag").split(",")
              else
                []
              end
        if first
          tags &= tag # intersection 2 array's
        else
          tags = tag
          first = true
        end
      end

      tags.compact!
      tags -= [""]
      @temp_tag = tags

      tags.sort.join(",").gsub(",", ", ")
    end

    def set_delete_button
      l = script("get_length('sections_list')")
      if l.to_i > 1
        set_icon("sections_delete", "icons/delete.png")
      else
        set_icon("sections_delete", "icons/delete_inactive.png")
      end
    end

    def show_sections
      visibility("material_dialog", false)
      visibility("sections_dialog", true)
      visibility("sections_list", true)
      visibility("sections_arrow", true)
      visibility("sections_rename", false)
      @dialogbox_type == :sections ? return : @dialogbox_type = :sections
    end

    def get_patterns
      return unless Sketchup.active_model

      skalpList = ["- #{Skalp.translate('no pattern selected')} -"]
      suList = []

      begin
        Sketchup.active_model.materials.each do |material|
          next if material.name.gsub(" ", "") == ""

          if material.get_attribute("Skalp", "ID")
            name = material.name.gsub(/%\d+\Z/, "")
            skalpList << name unless skalpList.include?(name)
          else
            suList << material.name
          end
        end
      rescue StandardError
        #  1.0.0349	undefined method `name' for #<Sketchup::Edge:0x007fcefda60a08>
        # NoMethodError
        # ["eval:910:in `block in get_patterns_to_string'", "eval:909:in `each'", "eval:909:in `get_patterns_to_string'",
        # "eval:751:in `update_dialog_lists'", "eval:986:in `update'", "eval:4:in `cleared_selection'", "eval:4:in `ccA'",
        # "eval:99:in `select_action'", "eval:99:in `block in process_queue'", "eval:94:in `each'", "eval:94:in `process_queue'",
        # "eval:55:in `block in restart_queue_timer'", "SketchUp:1:in `call'"]
      end

      skalpList.uniq.compact!
      skalpList.sort!
      suList.uniq.compact!
      suList.sort!
      temp = skalpList + ["----------"] + suList
    end

    def get_layers(option)
      return unless Sketchup.active_model

      layers = []

      Sketchup.active_model.layers.each do |layer|
        layers << layer.name unless layer.get_attribute("Skalp", "ID") || layer.name.include?("Skalp Pattern Layer - ")
      end

      layers.sort!
      layers.insert(0, "Skalp Pattern Layer") if option == 1
      layers.insert(0, "Object Layer") if option == 1
      layers.insert(0, "- no layer selected -")
    end

    def get_scenes
      scenes = ["- no scene selected -"]
      return unless Sketchup.active_model

      Sketchup.active_model.pages.each do |page|
        next unless page.class == Sketchup::Page

        scenes << page.name if Skalp.active_model.get_memory_attribute(page, "Skalp", "ID")
      end

      scenes.sort!
    end

    def get_linestyles
      Sketchup.active_model.line_styles.names
    end

    def show_materials
      get_section_materials
      @dialogbox_type == :material ? return : @dialogbox_type = :material

      visibility("sections_dialog", false)
      visibility("sections_list", false)
      visibility("sections_arrow", false)
      visibility("sections_rename", false)
      visibility("material_dialog", true)
    end

    def show_sections_rename
      visibility("material_dialog", false)
      visibility("sections_dialog", true)
      visibility("sections_list", false)
      visibility("sections_arrow", false)
      visibility("sections_rename", true)

      @dialogbox_type == :sections ? return : @dialogbox_type = :sections

      show_more(:sections)
    end

    def update(update_sectionplanes = 0, sectionplane_name = nil) # 1: new #2: load
      return unless Skalp.active_model

      if Skalp.active_model.skpModel.selection && Skalp.active_model.skpModel.selection.first == Skalp.active_model.live_sectiongroup && Skalp.active_model.skpModel.selection.count == 1
        Sketchup.active_model.select_tool(Skalp.selectTool)
      end

      update_dialog_lists
      if update_sectionplanes == 1
        sectionplane_name ? get_sectionplanes(sectionplane_name) : get_sectionplanes
      end

      if Skalp.active_model.active_sectionplane
        show_dialog_settings
        set_value("sections_list", Skalp.active_model.active_sectionplane.sectionplane_name)
        script("sections_switch_toggle(true)")
      else
        blur_dialog_settings
        set_value("sections_list", "- #{NO_ACTIVE_SECTION_PLANE} -")
        script("sections_switch_toggle(false)")
      end

      # materials dialog
      if Skalp.active_model.skpModel.selection && (Skalp.active_model.skpModel.selection[0].is_a?(Sketchup::Group) || Skalp.active_model.skpModel.selection[0].is_a?(Sketchup::ComponentInstance))
        unless Skalp.active_model.skpModel.selection[0].get_attribute("Skalp", "ID")
          show_materials
          set_value("tag", selected_tags)
          set_value("material_list", selected_materials)
        end
      else # standard sections dialog
        show_sections
      end
    end
  end
end
