module Skalp
  class Sections_dialog < Webdialog
    attr_accessor :webdialog, :active_sectionplane_toggle, :active_skpModel, :dxf_path, :showmore_dialog

    include StyleSettings

    def initialize
      @active_skpModel = Sketchup.active_model
      @html_path = Sketchup.find_support_file("Plugins")+"/Skalp_Skalp/html/"

      read_border_size

      @w_size = 255
      @h_size = 78
      @h_size_expand = 275

      @showmore_dialog = true
      @startup = true
      @width = @w_size
      @height={}
      @height[:sections] = @h_size
      @height_expand = {}
      @height_expand[:sections] = @h_size_expand

      Sketchup.read_default('Skalp', 'height_expand_resize').to_i > 0 ? @height_expand_resize = Sketchup.read_default('Skalp', 'height_expand_resize').to_i : @height_expand_resize = @height_expand[:sections]
      Sketchup.read_default('Skalp', 'sections_x').to_i > 0 ? @dialog_x = Sketchup.read_default('Skalp', 'sections_x').to_i : @dialog_x = 100
      Sketchup.read_default('Skalp', 'sections_y').to_i > 0 ? @dialog_y = Sketchup.read_default('Skalp', 'sections_y').to_i : @dialog_y = 100
      Sketchup.read_default('Skalp', 'sections_w').to_i > 0 ? @dialog_w = Sketchup.read_default('Skalp', 'sections_w').to_i : @dialog_w = @width
      @show_more_saved = Sketchup.read_default('Skalp', 'sections_show_more').to_i

      @dialogbox_type = :sections
      @show_more_toggle = {}
      @show_more_toggle[:sections] = false
      @temp_tag=[]

      if Skalp::OS == :WINDOWS
        @webdialog = UI::WebDialog.new(Skalp.translate('Skalp'), false, 'Skalp', @width + @w_border, @height[:sections] + @h_border, 0, 0, true)
      else
        @webdialog = UI::WebDialog.new(Skalp.translate('Skalp'), false, 'Skalp', @width + @w_border, @height[:sections] + @h_border, 0, 0, false)
      end

      @webdialog.set_file(@html_path + 'skalp_dialog.html')

      Skalp.message1 unless Skalp.ready

      @webdialog.set_position(@dialog_x, @dialog_y)
      self.min_height= @height[:sections]
      self.max_height= @height[:sections]
      self.min_width = @w_size
      set_size(@dialog_w, @height[:sections])

      @webdialog.show if Skalp::OS == :WINDOWS #workaround for windows, dialoog start anders niet op van de eerste keer

      @webdialog.add_action_callback("reset_dialog_undo_flag") { |webdialog, params|
        Skalp.active_model.dialog_undo_flag = false
      }

      # DIALOG ####################
      @webdialog.add_action_callback("dialog_focus") {
        unless Sketchup.active_model
          Skalp::stop_skalp
        end

        if Sketchup.active_model&.get_attribute('Skalp', 'CreateSection') != false
          Skalp.style_update = true
          if not Skalp.models[Sketchup.active_model]
            UI.start_timer(0.01, false) { Skalp.activate_model(Sketchup.active_model) }
          elsif Sketchup.active_model != @active_skpModel
            @active_skpModel = Sketchup.active_model
            Skalp.change_active_model(Sketchup.active_model)
          else
            update_dialog_lists
          end
          no_focus
        end
      }

      @webdialog.add_action_callback("dialog_blur") { |webdialog, params|
        vars = params.split(';')
        x = vars[0]
        y = vars[1]
        style = vars[2]

        if style && style != ''
          apply_style(style)
        end

        Sketchup.write_default('Skalp', 'sections_x', x)
        Sketchup.write_default('Skalp', 'sections_y', y)

        Skalp.style_update = false
        no_focus
      }

      @webdialog.add_action_callback("puts") { |webdialog, params|
        puts params
      }

      @webdialog.add_action_callback("dialog_resize") { |webdialog, params|
        vars = params.split(';')

        @dialog_w = vars[0].to_i
        @dialog_h = vars[1].to_i

        @dialog_w = @min_w if @dialog_w < @min_w
        @dialog_h = @max_h if @dialog_h > @max_h
        @dialog_h = @min_h if @dialog_h < @min_h

        Sketchup.write_default('Skalp', 'sections_w', @dialog_w)

        if @show_more_toggle[:sections]
          @height_expand_resize = @dialog_h
          Sketchup.write_default('Skalp', 'height_expand_resize', @height_expand_resize)
        end
      }

      # UPDATE SKALP SETTING TO ACTIVE SCENE
      @webdialog.add_action_callback("update_Skalp_scene") { |webdialog, value|
        unless Skalp.active_model.dialog_undo_flag
          data = {
              :action => :update_skalp_scene,
          }
          Skalp.active_model.controlCenter.add_to_queue(data)
        end
      }

      #####################################
      # SECTIONS
      #####################################

      #SET STYLE SETTINGS

      @webdialog.add_action_callback("change_drawing_scale") { |webdialog, value|
        save_drawing_scale(value.to_f)
        Skalp.set_default_drawing_scale(value.to_f)
        update_active_sectionplane
        Skalp.active_model.hiddenlines.update_scale if Sketchup.read_default('Skalp', 'linestyles') != 'SketchUp'
        settings_to_active_page_if_save_settings_is_on
      }

      @webdialog.add_action_callback("set_rearview_switch") { |webdialog, params|
        toggle_rear_view_command(params)
      }


      @webdialog.add_action_callback("set_linestyle") { |webdialog, params|
        set_linestyle(params)
      }

      @webdialog.add_action_callback("set_lineweights_switch") { |webdialog, params|
        toggle_lineweights_command(params)
      }

      @webdialog.add_action_callback("set_fog_switch") { |webdialog, params|
        toggle_depth_clipping_command(params)
      }

      @webdialog.add_action_callback("set_fog_distance") { |webdialog, params|
        set_fog_distance(params)
        settings_to_active_page_if_save_settings_is_on
      }

      # STYLES ###############################
      @webdialog.add_action_callback("apply_style") { |webdialog, params|
        apply_style(params)
      }

      @webdialog.add_action_callback("save_active_style_to_library") { |webdialog, params|
        style_rules.save_to_library
      }

      @webdialog.add_action_callback("load_style_from_library") { |webdialog, params|
        style_rules.load_from_library
      }

      def apply_style(params)
        if Skalp.style_update
          if Sketchup.active_model == @active_skpModel
            if Skalp.status == 1
              check = params.slice!(0..1).slice(0) #remove check
              params.slice!(0..0) #remove first | from string
              params.chomp!('|') #remove last | from string
              params = params.split('|,|')

              Skalp.active_model.start("Skalp - #{Skalp.translate('save style settings')}", true)

              settings_from_dialog(params)

              if check == '1'
                Skalp.active_model.save_settings = true
                settings_to_page(Sketchup.active_model.pages.selected_page) if Sketchup.active_model.pages.selected_page
              else
                Skalp.active_model.save_settings = false
                remove_settings(Sketchup.active_model.pages.selected_page) if Sketchup.active_model.pages.selected_page
              end

              materialnames = Set.new
              materialnames << Skalp.utf8(params[1]) if params[1] != ''

              style_rules = params[2..-1]

              for i in (0..style_rules.size-1).step(14)
                style_type = style_rules[i+2]
                style_type_setting = Skalp.utf8(style_rules[i+5])
                style_pattern = Skalp.utf8(style_rules[i+11])

                next if style_type == '' || style_type == 'undefined'
                next if style_type_setting == '' || style_type_setting == 'undefined'
                materialnames << style_pattern if style_pattern != ''
              end

              Skalp.add_skalp_material_to_instance(materialnames.to_a)

              Skalp.active_model.commit

              data = {
                  :action => :update_style
              }

              Skalp.active_model.controlCenter.add_to_queue(data)
            end
          end
        end
      end

      # SECTION_UPDATE ####################
      @webdialog.add_action_callback("sections_update") { |webdialog, params|
        section_update_command(params)
      }

      @webdialog.add_action_callback("sections_update_all") { |webdialog, params|
        rearview = Skalp.to_boolean(params)

        if (Sketchup.active_model == @active_skpModel) && Skalp.active_model && @active_skpModel.pages.count > 0
          Skalp.active_model.update_all_pages(false, rearview)
          rearview_status_black if rearview_update
        end
      }

      @webdialog.add_action_callback("export_LayOut") {
        if (Sketchup.active_model == @active_skpModel) && Skalp.active_model && @active_skpModel.pages.count > 0
          Skalp.active_model.update_all_pages(true, true)
        end
      }

      # SECTION_SWITCH ####################
      @sections_switch_toggle = true

      @webdialog.add_action_callback("set_live_updating") {
        unless Skalp.active_model.dialog_undo_flag

          if Sketchup.active_model == @active_skpModel
            @sections_switch_toggle = !@sections_switch_toggle

            if @sections_switch_toggle then
              Skalp.live_section_ON = true
              Skalp.active_model.live_section_on
              update_active_sectionplane
              script(%Q^$("#live_updating").text("#{Skalp.translate('Turn OFF Skalp Section Fill')}")^)
              script("$('#sections_list').css('color','black')")
              script("$('#sections_rename').css('color','black')")
            else
              Skalp.live_section_ON = false
              Skalp.active_model.live_section_off
              script(%Q^$("#live_updating").text("#{Skalp.translate('Turn ON Skalp Section Fill')}")^)
              script("$('#sections_list').css('color','red')")
              script("$('#sections_rename').css('color','red')")
            end
          end
        end
      }

      @webdialog.add_action_callback("align_view") {
        align_view_command
      }

      @webdialog.add_action_callback("reverse_sectionplane") {
        reverse_sectionplane
      }

      @webdialog.add_action_callback("switch_rendermode") { |webdialog, params|
        toggle_hiddenline_mode_command(params)
      }

      # SECTION_ADD ####################
      @webdialog.add_action_callback("sections_add") {
        unless Skalp.active_model.dialog_undo_flag
          if Sketchup.active_model == @active_skpModel
            Sketchup.send_action('selectSectionPlaneTool:')
          end
        end
      }

      # SECTION_DELETE ####################
      @webdialog.add_action_callback("sections_delete") {
          unless Skalp.active_model.dialog_undo_flag
            if Sketchup.active_model == @active_skpModel
              if get_value('sections_list') != '' && Skalp.active_model.active_sectionplane
                Skalp.active_model.delete_sectionplane(Skalp.active_model.active_sectionplane)
              end
            end
          end
      }
      # SECTION_SHOW_MORE ####################

      @webdialog.add_action_callback("sections_show_more") { |webdialog, params|
        @show_more_toggle[:sections] = !@show_more_toggle[:sections]
        vars = params.split(';')
        @dialog_x = vars[0]
        @dialog_y = vars[1]
        show_more(:sections)
      }

      # SECTION_LIST #################
      #sections

      @webdialog.add_action_callback("change_active_sectionplane") { |webdialog, params|
        unless Skalp.active_model.dialog_undo_flag
          unless Skalp.page_change
            data = {
                :action => :change_active_sectionplane,
                :sectionplane => Skalp.utf8(params)
            }
            Skalp.active_model.controlCenter.add_to_queue(data)
          end
        end

      }

      @active_sectionplane_toggle = false
      @webdialog.add_action_callback("active_sectionplane_toggle") { |webdialog, params|
        sectionplane_toggle_command
      }
      #sections rename
      @webdialog.add_action_callback("rename_sectionplane") { |webdialog, params|
        unless Skalp.active_model.dialog_undo_flag
          if Sketchup.active_model == @active_skpModel
            Skalp.active_model.active_sectionplane.rename(Skalp.utf8(params))
            update(1)
          end
        end

      }
      #####################################
      # MATERIAL
      #####################################

      # MATERIAL SELECTOR ##########################
      @webdialog.add_action_callback("materialSelector") { |webdialog, params|
        vars = params.split(';')
        x = vars[0]
        y = vars[1]
        id = vars[2]

        Skalp::Material_dialog.show_dialog(x, y, webdialog, id)
      }

      @webdialog.add_action_callback("su_focus") {
      }

      @webdialog.add_action_callback("define_tag") { |webdialog, tag|
        if Sketchup.active_model == @active_skpModel
          Skalp.active_model.start("Skalp - #{Skalp.translate('define tag')}", true)
          entities = []

          tag = tag.gsub(' ', '')
          new_tags = tag.split(',')

          new_tags.map! { |tag| Skalp.utf8(tag) }

          selection = Sketchup.active_model.selection

          for e in selection
            if e.valid?
              if selection.size == 1
                e.set_attribute('Skalp', 'tag', new_tags.join(','))
              else
                e.get_attribute('Skalp', 'tag') ? old_tags = e.get_attribute('Skalp', 'tag').split(',') : old_tags = [e.get_attribute('Skalp', 'tag')]

                if old_tags != []
                  if @temp_tag != []
                    tags = (old_tags - @temp_tag) + new_tags
                  else
                    tags = old_tags + new_tags
                  end
                else
                  tags = new_tags
                end

                tags ? e.set_attribute('Skalp', 'tag', tags.join(',')) : e.set_attribute('Skalp', 'tag', '')
              end
              entities << e
            end
          end

          Skalp.active_model.commit

          entities.each do |e|
            data = {
                :action => :changed_tag,
                :entity => e
            }

            Skalp.active_model.controlCenter.add_to_queue(data)
          end
        end
      }

      @webdialog.add_action_callback("deselect") { |webdialog, params|
        Sketchup.active_model.selection.clear
      }

      @webdialog.add_action_callback("hatch_generator") { |webdialog, params|
        if Skalp.hatch_dialog
          Skalp.hatch_dialog.show
        else
          Skalp.hatch_dialog = Hatch_dialog.new
          Skalp.hatch_dialog.show
        end
      }

      @webdialog.add_action_callback("create_color_by_layer_layers") { |webdialog, params|
        Skalp.create_Color_by_Layer_layers
      }

      @webdialog.add_action_callback("define_layer_materials") { |webdialog, params|
        Skalp.define_layers_dialog
      }

      @webdialog.add_action_callback("edit_hatchmaterial") { |webdialog, params|
        hatchname = Skalp.utf8(params)
        Skalp::edit_skalp_material(hatchname)
      }

      @webdialog.add_action_callback("export_patterns") { |webdialog, params|
        Skalp.export_material_textures(true)
      }

      @webdialog.add_action_callback("set_render_brightness") { |webdialog, params|
        Skalp.set_render_brightness
      }

      @webdialog.add_action_callback("set_linestyle_system") { |webdialog, params|

        active_setting = Sketchup.read_default('Skalp', 'linestyles')

        if active_setting == 'Skalp'
          input = UI.inputbox(["Linestyles?"], ["Skalp"], ["Skalp|SketchUp"], "Set Linestyle System")
        else
          input = UI.inputbox(["Linestyles?"], ["SketchUp"], ["Skalp|SketchUp"], "Set Linestyle System")
        end

        if input[0] == 'SketchUp'
          Sketchup.write_default('Skalp', 'linestyles' , 'SketchUp')
          script("$('#linestyles_div').show()")
        else
          Sketchup.write_default('Skalp', 'linestyles' , 'Skalp')
          script("$('#linestyles_div').hide()")
        end
      }

      @webdialog.add_action_callback("export_materials") { |webdialog, params|
        Skalp.export_skalp_materials
      }

      @webdialog.add_action_callback("import_materials") { |webdialog, params|
        Skalp.import_skalp_materials
      }

      @webdialog.add_action_callback("export_layer_mapping") { |webdialog, params|
        Skalp.export_layer_mapping
      }

      @webdialog.add_action_callback("import_layer_mapping") { |webdialog, params|
        Skalp.import_layer_mapping
      }

      @webdialog.add_action_callback("scenes2images") { |webdialog, params|
        Skalp::scenes2images
      }

      @webdialog.add_action_callback("skalp2dxf") { |webdialog, params|
        Skalp.dwg_export
      }

      @webdialog.add_action_callback("set_hiddenline_style") { |webdialog, params|
        Skalp.hiddenline_style_dialog
      }

      @webdialog.add_action_callback("set_section_offset") { |webdialog, params|
        Skalp.set_section_offset
      }

      @webdialog.add_action_callback("define_sectionmaterial") { |webdialog, sectionmaterial|
        define_sectionmaterial(sectionmaterial)
      }

      # MATERIAL_SHOW_MORE ####################

      @webdialog.add_action_callback("material_show_more") { |webdialog, params|
        @show_more_toggle[:material] = !@show_more_toggle[:material]
        vars = params.split(';')
        @dialog_x = vars[0]
        @dialog_y = vars[1]
        show_more(:material)
      }

      # SHOW ###############################
      @webdialog.add_action_callback("dialog_ready") { |webdialog, params|
        write_border_size(:sections)

        self.min_height= @height[:sections]
        self.max_height= @height[:sections]

        if @show_more_saved == 1
          @show_more_toggle[:sections] = !@show_more_toggle[:sections]
          show_more(:sections)
        else
          visibility('dialog_styles', false)
          visibility('save_style', false)
          visibility('display_settings_blured', false)
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
          #set_dialog_translation
          update_dialog
          show

          if  Sketchup.read_default('Skalp', 'linestyles') == 'Skalp'
            script("$('#linestyles_div').hide()")
          else
            script("$('#linestyles_div').show()")
          end

          @webdialog.bring_to_front
          Skalp.dialog_loading = false

          sectionplane = Sketchup.active_model.entities.active_section_plane
          if sectionplane && sectionplane.get_attribute('Skalp', 'sectionplane_name')
            section_name = sectionplane.get_attribute('Skalp', 'sectionplane_name')
            if Skalp.active_model.active_sectionplane
              #Skalp.page_change = true
              Skalp.dialog.script("$('#sections_list').val('#{section_name}')")
              Skalp.dialog.script("change_active_sectionplane('#{section_name}')")
              #Skalp.page_change = false
            end
          else

            Skalp.dialog.script("$('#sections_list').val('- #{NO_ACTIVE_SECTION_PLANE} -')")
            Skalp.dialog.script("change_active_sectionplane('- #{NO_ACTIVE_SECTION_PLANE} -')")
          end
        end
        no_focus
      }

      @webdialog.add_action_callback("reset_style") do
        reset_style
      end

      # LISTS_UPDATE ####################
      @webdialog.add_action_callback("update_dialog_lists") {
        update_dialog_lists
      }

      @webdialog.set_on_close {
        if @webdialog.get_element_value("RUBY_BRIDGE") == 'ESC'
          UI.start_timer(0, false) {
            @webdialog.show_modal
          } if OS == :MAC
        else
          unless @show_more
            Skalp.stop_skalp(false)
            Skalp.skalpbutton_off
            Skalp.dialog_loading = false
          end
        end
      }
    end

    def define_sectionmaterial(sectionmaterial, object = nil)
      if Sketchup.active_model == Skalp.active_model.skpModel
        if object
          selection = [object]
        else
          selection = Sketchup.active_model.selection
        end

        Skalp.active_model.start('Skalp - ' + Skalp.translate('define section material'), true)
        entities = []
        for e in selection
          if e.valid? && e.class != Sketchup::SectionPlane then
            if Skalp.utf8(sectionmaterial) == "- #{Skalp.translate('None')} -" then
              e.delete_attribute 'Skalp'
            else
              e.set_attribute('Skalp', 'sectionmaterial', Skalp.utf8(sectionmaterial))
            end
            entities << e
          end
        end

        Skalp.add_skalp_material_to_instance([Skalp.utf8(sectionmaterial)])
        Skalp.active_model.commit

        entities.each do |e|
          data = {
              :action => :changed_sectionmaterial,
              :entity => e
          }
          Skalp.active_model.controlCenter.add_to_queue(data)
        end
      end
    end

    def no_active_sectionplane(page = nil)
      blur_dialog_settings
      script("$('#sections_list').val('- #{NO_ACTIVE_SECTION_PLANE} -')")
      script("change_active_sectionplane('- #{NO_ACTIVE_SECTION_PLANE} -')")

      Skalp.active_model.set_active_sectionplane('')
      Skalp.sectionplane_active = false

      Skalp.dialog.update
      Skalp.active_model.pagesUndoRedo.update_dialog

      for layer in Sketchup.active_model.layers
        next unless layer.valid?
        if layer.get_attribute('Skalp','ID')
          page.set_visibility(layer, false) if page
        end
      end

      unless page
        Skalp.active_model && Skalp.active_model.live_sectiongroup.valid? && Skalp.active_model.live_sectiongroup.layer.visible = false
      end
    end

    def section_update_command(params)
      unless Skalp.active_model.dialog_undo_flag
        rearview = Skalp.to_boolean(params)
        rearview_status_red
        save_rearview_update(rearview)

        if Sketchup.active_model == @active_skpModel
          status = Skalp.live_section_ON
          Skalp.live_section_ON = true

          if OS == :WINDOWS
            if rearview_status && rearview_update
              Sketchup.set_status_text "#{Skalp.translate('Update Section')} (#{Skalp.translate('step')} 1/3) #{Skalp.translate('Please wait...')}"
              update_active_sectionplane
              Sketchup.set_status_text "#{Skalp.translate('Processing rear lines')} (#{Skalp.translate('step')} 2/3) #{Skalp.translate('Please wait...')}"
              Skalp.active_model.hiddenlines.update_rear_lines
              Sketchup.set_status_text "#{Skalp.translate('Adding rear lines')} (#{Skalp.translate('step')} 3/3) #{Skalp.translate('Please wait...')}"
              Skalp.active_model.hiddenlines.add_rear_lines_to_model
              rearview_status_black if Skalp.active_model.model_changes == false
            else
              Sketchup.set_status_text "#{Skalp.translate('Update Section')} (#{Skalp.translate('step')} 1/1) #{Skalp.translate('Please wait...')}"
              update_active_sectionplane
            end

            Skalp.live_section_ON = status
            Sketchup.set_status_text "#{Skalp.translate('Section successfully updated.')}"

          else
            if rearview_status && rearview_update
              UI.start_timer(0.01, false) { Sketchup.set_status_text "#{Skalp.translate('Update Section')} (#{Skalp.translate('step')} 1/3) #{Skalp.translate('Please wait...')}" }
              UI.start_timer(0.01, false) { update_active_sectionplane }
              UI.start_timer(0.01, false) { Sketchup.set_status_text "#{Skalp.translate('Processing rear lines')} (#{Skalp.translate('step')} 2/3) #{Skalp.translate('Please wait...')}" }
              UI.start_timer(0.01, false) { Skalp.active_model.hiddenlines.update_rear_lines }
              UI.start_timer(0.01, false) { Sketchup.set_status_text "#{Skalp.translate('Adding rear lines')} (#{Skalp.translate('step')} 3/3) #{Skalp.translate('Please wait...')}" }
              UI.start_timer(0.01, false) { Skalp.active_model.hiddenlines.add_rear_lines_to_model }
              UI.start_timer(0.01, false) { rearview_status_black if Skalp.active_model.model_changes == false }
            else
              UI.start_timer(0.01, false) { Sketchup.set_status_text "#{Skalp.translate('Update Section')} (#{Skalp.translate('step')} 1/1) #{Skalp.translate('Please wait...')}" }
              UI.start_timer(0.01, false) { update_active_sectionplane }
            end

            UI.start_timer(0.01, false) {
              Skalp.live_section_ON = status
              Sketchup.set_status_text "#{Skalp.translate('Section successfully updated.')}"
            }
          end
        end
      end
    end

    def toggle_hiddenline_mode_command(params)
      observer_status = Skalp.block_observers
      Skalp.block_observers = true
      if params == 'active'
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

     Skalp.active_model.start('Skalp - set rearview linestyle')
     layer = Skalp::create_linestyle_layer(linestyle_name)

     rear_view_def = Skalp.active_model.hiddenlines.rear_view_definitions[Sketchup.active_model.pages.selected_page]
     rear_view_def.entities.each {|e| e.layer = layer} if rear_view_def

     Skalp.active_model.commit
    end

    def toggle_depth_clipping_command(params)
      unless Sketchup.active_model.entities.active_section_plane
        UI.messagebox(Skalp.translate('Easy Fog only works when there is an active Section Plane.'))
        fog_status_switch_off
      else
        set_fog_switch(Skalp.to_boolean(params))
        settings_to_active_page_if_save_settings_is_on
      end
    end

    def toggle_lineweights_command(params)
      set_lineweights_switch(Skalp.to_boolean(params))
      update_active_sectionplane
      settings_to_active_page_if_save_settings_is_on
    end

    def align_view_command
      if (Sketchup.active_model == @active_skpModel) && Skalp.active_model && Skalp.active_model.active_sectionplane
        sectionplane = Skalp.active_model.active_sectionplane
        Skalp.align_view(sectionplane.skpSectionPlane)
        Skalp.fog if fog_status
      end
    end

    def reverse_sectionplane
      if (Sketchup.active_model == @active_skpModel) && Skalp.active_model && Skalp.active_model.active_sectionplane
        sectionplane = Skalp.active_model.active_sectionplane.skpSectionPlane
        if sectionplane.valid?
          create_new_sectionplane = UI.messagebox('Create a new section?', MB_YESNO)

          Sketchup.active_model.start_operation('Skalp - reverse sectionplane', true, false, false)
          Skalp.reverse_view
          if create_new_sectionplane == IDYES
            prompts = ["Name", "Symbol"]
            defaults = [sectionplane.name, sectionplane.symbol]
            list = ["", ""]
            input = UI.inputbox(prompts, defaults, list, "Name Section Plane")

            new_sectionplane = Sketchup.active_model.entities.add_section_plane(sectionplane.get_plane.map! { |i| -i })
            new_sectionplane.name = input[0]
            new_sectionplane.symbol = input[1][0..2]
            new_sectionplane.activate
          else
            sectionplane.set_plane(sectionplane.get_plane.map! { |i| -i })
          end
          Sketchup.active_model.commit_operation
        end
      end
    end

    def sectionplane_toggle_command
      if Skalp.active_model && Sketchup.active_model == @active_skpModel
        @active_section_switch_toggle = !@active_section_switch_toggle

        if @active_sectionplane_toggle then
          script("$('#sections_list').val('- #{NO_ACTIVE_SECTION_PLANE} -')")
          script("change_active_sectionplane('- #{NO_ACTIVE_SECTION_PLANE} -')")
        elsif Sketchup.active_model.pages.selected_page && Skalp.active_model.get_memory_attribute(Sketchup.active_model.pages.selected_page, 'Skalp', 'ID')
          active_sectionplane = Skalp.active_model.sectionplane_by_id(Skalp.active_model.get_memory_attribute(Sketchup.active_model.pages.selected_page, 'Skalp', 'sectionplaneID'))
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

          if Skalp.active_model.sectionplanes == {}
            Sketchup.send_action('selectSectionPlaneTool:') if Sketchup.active_model == @active_skpModel
          end
        end
      end
    end

    def set_dialog_translation
      #icons
      string = Skalp.translate('Activate Sectionplane Toggle')
      @webdialog.execute_script(%Q^$("#sections_switch").prop("title", "#{string}")^)
      string = Skalp.translate('Manual Update')
      @webdialog.execute_script(%Q^$("#sections_update").prop("title", "#{string}")^)
      string = Skalp.translate('Place new Section Plane')
      @webdialog.execute_script(%Q^$("#sections_add").prop("title", "#{string}")^)
      string = Skalp.translate('Delete active Section Plane')
      @webdialog.execute_script(%Q^$("#sections_delete").prop("title", "#{string}")^)
      string = Skalp.translate('Drawing Scale')
      @webdialog.execute_script(%Q^$("#drawing_scale").prop("title", "#{string}")^)
      string = Skalp.translate('Save settings to Scene')
      @webdialog.execute_script(%Q^$("#not_uptodate").prop("title", "#{string}")^)
      string = Skalp.translate('Show more')
      @webdialog.execute_script(%Q^$("#sections_show_more").prop("title", "#{string}")^)
      string = Skalp.translate('Menu')
      @webdialog.execute_script(%Q^$("#sections_menu").prop("title", "#{string}")^)

      #menu
      string = Skalp.translate('Export')
      @webdialog.execute_script(%Q^$("#label_export").prop("label","#{string}")^)

      string = Skalp.translate('Export active view to DXF')
      @webdialog.execute_script(%Q^$("#export_active_view_to_dxf").text("#{string}")^)
      string = Skalp.translate('Export all scenes to DXF')
      @webdialog.execute_script(%Q^$("#export_all_scenes_to_dxf").text("#{string}")^)

      string = Skalp.translate('Preferences')
      @webdialog.execute_script(%Q^$("#label_preferences").prop("label","#{string}")^)

      string = Skalp.translate('Turn OFF Skalp Section Fill')
      @webdialog.execute_script(%Q^$("#live_updating").text("#{string}")^)
      string = Skalp.translate('Set Section Offset Distance')
      @webdialog.execute_script(%Q^$("#offset_distance").text("#{string}")^)

      #selectionbox
      string = Skalp.translate('Select Sectionplane')
      @webdialog.execute_script(%Q^$("#sections_arrow").prop("title", "#{string}")^)
      string = Skalp.translate('Rename Section Plane')
      @webdialog.execute_script(%Q^$("#sections_rename").prop("title", "#{string}")^)

      #styles
      string = Skalp.translate('Pattern Fill Rules:')
      @webdialog.execute_script(%Q^$("#style_title").text("#{string}")^)

      string = Skalp.translate('Add new rule line')
      @webdialog.execute_script(%Q^$("#add_item").prop("title", "#{string}")^)
      string = Skalp.translate('Edit Skalp Style')
      @webdialog.execute_script(%Q^$("#edit_style").prop("title", "#{string}")^)

      string = Skalp.translate('save style to scene')
      @webdialog.execute_script(%Q^$("#save_style").text("#{string}")^)
      @webdialog.execute_script(%Q^$("#save_style").append("<input type='checkbox' name='save' id='save_check' onchange='save_style()' >")^)
    end

    def model_changed
      Skalp.active_model.hiddenlines.uptodate = {}
      rearview_status_red if rearview_status
    end

    def show_drawing_scale
      if @webdialog.get_element_value('sections_list').to_s != "- #{NO_ACTIVE_SECTION_PLANE} -"
        @webdialog.execute_script("$('#drawing_scale_title').hide()")
        @webdialog.execute_script("$('#drawing_scale').hide()")
      else
        @webdialog.execute_script("$('#drawing_scale_title').show()")
        @webdialog.execute_script("$('#drawing_scale').show()")
      end
    end

    def show
      Skalp::OS == :MAC ? @webdialog.show_modal() : @webdialog.show()
    end

    def no_focus
      script("if (document.activeElement != document.body) document.activeElement.blur();")
    end

    def update_dialog_lists
      return unless Sketchup.active_model
      set_value_clear('patterns')
      patterns =  get_patterns
      patterns.each do |pat|
        if patterns.first == pat
          set_value_add('patterns', "#{pat}")
        else
          set_value_add('patterns', ";#{pat}")
        end
      end

      set_value_clear('layers')
      layers =  get_layers(1)
      layers.each do |layer|
        if layers.first == layer
          set_value_add('layers', "#{layer}")
        else
          set_value_add('layers', ";#{layer}")
        end
      end

      set_value_clear('layers2')
      layers =  get_layers(2)
      layers.each do |layer|
        if layers.first == layer
          set_value_add('layers2', "#{layer}")
        else
          set_value_add('layers2', ";#{layer}")
        end
      end

      set_value_clear('scenes')
      scenes =  get_scenes
      scenes.each do |scene|
        if scenes.first == scene
          set_value_add('scenes', "#{scene}")
        else
          set_value_add('scenes', ";#{scene}")
        end
      end

      script("multitag_visible = #{multitag_visible?}")
      script("model_lists()")
    end

    def multitag_visible?
      return true if defined?(AW::Tags)

      # Check model default style
      model_settings = Skalp::StyleSettings.style_settings(Sketchup.active_model)
      if model_settings[:style_rules] && model_settings[:style_rules].respond_to?(:any?)
        return true if model_settings[:style_rules].any? { |r| r[:type] == :ByMultiTag }
      end

      # Check scenes
      Sketchup.active_model.pages.each do |page|
         page_settings = Skalp.active_model.get_memory_attribute(page, 'Skalp', 'style_settings')
         next unless page_settings.is_a?(Hash) && page_settings[:style_rules]
         if page_settings[:style_rules].respond_to?(:any?)
            return true if page_settings[:style_rules].any? { |r| r[:type] == :ByMultiTag }
         end
      end

      false
    end

    def reset_style
      if Sketchup.active_model.pages && Sketchup.active_model.pages.selected_page
        object = Sketchup.active_model.pages.selected_page
      else
        object = Sketchup.active_model
      end


      settings = Skalp::StyleSettings.style_settings(object)[:style_rules] || StyleRules.new
      settings.create_default_model_rule
      update_dialog

      unless Skalp.active_model.page_undo
        data = {
            :action => :update_style,
        }

        Skalp.active_model.controlCenter.add_to_queue(data) unless Skalp.page_change
      end
    end

    def update_styles(object)
      page_changed(object) if Skalp.page_change

      unless Skalp.active_model.page_undo
        data = {
            :action => :update_style,
        }

        Skalp.active_model.controlCenter.add_to_queue(data) unless Skalp.page_change
      end

    end

    def update_active_sectionplane
      Skalp.active_model.active_sectionplane.calculate_section if Skalp.active_model && Skalp.active_model.active_sectionplane
    end

    def get_sectionplanes(sectionplane_name = nil)
      clear('sections_list')

      add('sections_list', "- #{NO_ACTIVE_SECTION_PLANE} -")

      section_list = []

      Skalp.active_model.sectionplanes.each_value { |sectionplane|
        section_list << sectionplane.sectionplane_name if sectionplane.sectionplane_name
      }

      section_list << sectionplane_name if sectionplane_name

      section_list.sort!

      for section_name in section_list
        add('sections_list', section_name)
      end

      if sectionplane_name
        set_value('sections_list', sectionplane_name)
      else
        if Skalp.active_model.active_sectionplane
          set_value('sections_list', Skalp.active_model.active_sectionplane.sectionplane_name)
        else
          set_value('sections_list', "- #{NO_ACTIVE_SECTION_PLANE} -")
        end
      end
      set_delete_button
    end

    def selected_materials
      materials = []
      for e in Skalp.active_model.skpModel.selection
        materials << e.get_attribute('Skalp', 'sectionmaterial')
      end

      materials = materials.compact
      materials.uniq!
      if materials.size == 1 then
        return materials[0].to_s
      elsif materials.size == 0 then
        return 'Skalp default'
      else
        return "- #{Skalp.translate('Multiple selected')} -"
      end
    end

    def selected_tags
      tags = []
      first = false
      for e in Skalp.active_model.skpModel.selection
        (e.get_attribute('Skalp', 'tag')!=nil && e.get_attribute('Skalp', 'tag')!="") ? tag = e.get_attribute('Skalp', 'tag').split(',') : tag = []
        unless first
          tags = tag
          first = true
        else
          tags = tags & tag #intersection 2 array's
        end
      end

      tags.compact!
      tags = tags - [""]
      @temp_tag = tags

      return tags.sort.join(',').gsub(',', ', ')
    end

    def set_delete_button
      l = script("get_length('sections_list')")
      l.to_i > 1 ?
          set_icon('sections_delete', 'icons/delete.png') :
          set_icon('sections_delete', 'icons/delete_inactive.png')
    end

    def show_sections
      visibility('material_dialog', false)
      visibility('sections_dialog', true)
      visibility('sections_list', true)
      visibility('sections_arrow', true)
      visibility('sections_rename', false)
      @dialogbox_type == :sections ? return : @dialogbox_type = :sections
    end

    def get_patterns
      return unless Sketchup.active_model
      skalpList = ["- #{Skalp.translate('no pattern selected')} -"]
      suList =[]

      begin
        Sketchup.active_model.materials.each { |material|
          next if material.name.gsub(' ', '') == ''
          if material.get_attribute('Skalp', 'ID')
            name = material.name.gsub(/%\d+\Z/, '')
            skalpList << name unless skalpList.include?(name)
          else
            suList << material.name
          end
        }
      rescue
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
      temp = skalpList + ['----------'] + suList
    end

    def get_layers(option)
      return unless Sketchup.active_model

      layers =[]

      Sketchup.active_model.layers.each { |layer|
        layers << layer.name unless layer.get_attribute('Skalp', 'ID') || layer.name.include?('Skalp Pattern Layer - ')
      }

      layers.sort!
      layers.insert(0, "Skalp Pattern Layer") if option == 1
      layers.insert(0, "Object Layer") if option == 1
      layers.insert(0, "- no layer selected -")
    end

    def get_scenes
      scenes =["- no scene selected -"]
      return unless Sketchup.active_model

      Sketchup.active_model.pages.each { |page|
        next unless page.class == Sketchup::Page
        scenes << page.name if Skalp.active_model.get_memory_attribute(page, 'Skalp', 'ID')
      }

      scenes.sort!
    end

    def get_linestyles
      Sketchup.active_model.line_styles.names
    end

    def show_materials
      get_section_materials
      @dialogbox_type == :material ? return : @dialogbox_type = :material
      visibility('sections_dialog', false)
      visibility('sections_list', false)
      visibility('sections_arrow', false)
      visibility('sections_rename', false)
      visibility('material_dialog', true)
    end

    def show_sections_rename
      visibility('material_dialog', false)
      visibility('sections_dialog', true)
      visibility('sections_list', false)
      visibility('sections_arrow', false)
      visibility('sections_rename', true)

      @dialogbox_type == :sections ? return : @dialogbox_type = :sections
      show_more(:sections)
    end

    def update(update_sectionplanes=0, sectionplane_name=nil) #1: new #2: load
      if Skalp.active_model
        if Skalp.active_model.skpModel.selection && Skalp.active_model.skpModel.selection.first == Skalp.active_model.live_sectiongroup && Skalp.active_model.skpModel.selection.count == 1
          Sketchup.active_model.select_tool(Skalp.selectTool)
        end

        update_dialog_lists
        sectionplane_name ? get_sectionplanes(sectionplane_name) : get_sectionplanes if update_sectionplanes == 1

        if Skalp.active_model.active_sectionplane
          show_dialog_settings
          set_value('sections_list', Skalp.active_model.active_sectionplane.sectionplane_name)
          script("sections_switch_toggle(true)")
        else
          blur_dialog_settings
          set_value('sections_list', "- #{NO_ACTIVE_SECTION_PLANE} -")
          script("sections_switch_toggle(false)")
        end

          # materials dialog
        if Skalp.active_model.skpModel.selection && (Skalp.active_model.skpModel.selection[0].is_a?(Sketchup::Group) || Skalp.active_model.skpModel.selection[0].is_a?(Sketchup::ComponentInstance))
          if not Skalp.active_model.skpModel.selection[0].get_attribute('Skalp', 'ID')
            show_materials
            set_value('tag', selected_tags)
            set_value('material_list', selected_materials)
          end
        else #standard sections dialog
          show_sections
        end
      end

    end
  end
end
