module Skalp
  class PaintBucket
    def activate
      Skalp::Material_dialog::show_dialog

      @node = nil
      @sectionface = nil
      @modifier = :no_key
      @rule_cursor = 0

      @cursor_normal = UI.create_cursor(IMAGE_PATH + "cursor_skalp_paint.png", 8, 26)
      @cursor_none = UI.create_cursor(IMAGE_PATH + "cursor_skalp_paintno.png", 8, 26)
      @cursor_object = UI.create_cursor(IMAGE_PATH + "cursor_skalp_paint_object.png", 8, 26)
      @cursor_tags = UI.create_cursor(IMAGE_PATH + "cursor_skalp_paint_tags.png", 8, 26)
      @cursor_model = UI.create_cursor(IMAGE_PATH + "cursor_skalp_paint_model.png", 8, 26)
      @cursor_not_supported = UI.create_cursor(IMAGE_PATH + "cursor_skalp_paint_not_supported.png", 8, 26)
      @cursor_picker = UI.create_cursor(IMAGE_PATH + "cursor_skalp_paint_picker.png", 8, 26)
      @cursor_picker_no = UI.create_cursor(IMAGE_PATH + "cursor_skalp_paint_picker_no.png", 8, 26)

      onSetCursor
    end

    def deactivate(view)
      Skalp::Material_dialog::close_dialog
      Skalp::paintbucketbutton_off
    end

    def onSetCursor
      if @sectionface
        case @modifier
        when :no_key
          @cursor_type = @rule_cursor
        when :shift
          @cursor_type = 1
        when :alt
          @cursor_type = 2
        when :command
          @cursor_type = 4
        when :shift_alt
          @cursor_type = 6
        end
      else
        case @modifier
        when :command
          @cursor_type = 5
        else
          @cursor_type = 3
        end
      end

      case @cursor_type
      when 0
        UI.set_cursor(@cursor_normal)
      when 1
        UI.set_cursor(@cursor_object)
      when 2
        UI.set_cursor(@cursor_tags)
      when 3
        UI.set_cursor(@cursor_none)
      when 4
        UI.set_cursor(@cursor_picker)
      when 5
        UI.set_cursor(@cursor_picker_no)
      when 6
        UI.set_cursor(@cursor_model)
      when 7
        UI.set_cursor(@cursor_not_supported)
      end
      @view.invalidate if @view
    end

    def onKeyDown(key, repeat, flags, view)
      key_status(key, flags, :down)
    end

    def onKeyUp(key, repeat, flags, view)
      key_status(key, flags, :up)
    end

    def key_status(key, flags=0, status=:no_status)
      case Skalp.key(flags, key, status)
      when :shift_alt
        @modifier = :shift_alt
      when :alt #Alt  (Add)
        @modifier = :alt
      when :shift #Shift (Invert)
        @modifier = :shift
      when :command #cmd
        @modifier = :command
      when :no_key
        @modifier = :no_key
      end

      onMouseMove(@flags, @x, @y, @view) if @flags
    end

    def onLButtonDown(flags, x, y, view)
      @view = view

      ph = view.pick_helper
      ph.do_pick(x, y)
      face = ph.picked_face

      if face && Skalp.active_model.entity_strings
        node_value = Skalp.active_model.entity_strings[face.get_attribute('Skalp', 'from_sub_object')]

        if node_value
          @node = node_value.node

          case @modifier
          when :no_key #rule
            rule = rules

            case rule
            when :Model
              Skalp::Material_dialog.selected_material = 'Skalp default' if Skalp::Material_dialog.selected_material == ''
              Skalp::dialog.webdialog.execute_script("$('#model_material').val('#{Skalp::Material_dialog.selected_material}')")
              Skalp.style_update = true
              Skalp::dialog.webdialog.execute_script("save_style(false)")
            when :ByObject
              object = node_value.skpEntity
              Skalp::dialog.define_sectionmaterial(Skalp::Material_dialog.selected_material, object)
            when :ByTag
              tag = Sketchup.active_model.layers[node_value.layer]
              Skalp.define_layer_material(tag, Skalp::Material_dialog.selected_material) if tag
            when :ByTexture
              UI.messagebox('When using the ByTexture rule, you need to paint the object with the SketchUp Paint Tool to change the section.')
            when :Label
              UI.messagebox("Painting the 'Label' rule is not yet implemented in this Skalp version.")
            when :Layer
              UI.messagebox("Painting the 'Layer' rule is not yet implemented in this Skalp version.")
            when :Scene
              UI.messagebox("Painting the 'Scene' rule is not yet implemented in this Skalp version.")
            when :Pattern
              UI.messagebox("Painting the 'Pattern' rule is not yet implemented in this Skalp version.")
            end

          when :shift #object
            object = node_value.skpEntity
            Skalp::dialog.define_sectionmaterial(Skalp::Material_dialog.selected_material, object)
          when :alt #tag
            tag = Sketchup.active_model.layers[node_value.layer]
            Skalp.define_layer_material(tag, Skalp::Material_dialog.selected_material) if tag

            if default_rules
              object = node_value.skpEntity
              Skalp::dialog.define_sectionmaterial('', object)
            end
          when :shift_alt #model
            Skalp::Material_dialog.selected_material = 'Skalp default' if Skalp::Material_dialog.selected_material == ''
            Skalp::dialog.webdialog.execute_script("$('#model_material').val('#{Skalp::Material_dialog.selected_material}')")
            Skalp.style_update = true
            Skalp::dialog.webdialog.execute_script("save_style(false)")

            if default_rules
              tag = Sketchup.active_model.layers[node_value.layer]
              Skalp.define_layer_material(tag, '') if tag
              object = node_value.skpEntity
              Skalp::dialog.define_sectionmaterial('', object)
            end
          when :command
            if face.material
              material = face.material.name
              Skalp::Material_dialog.create_thumbnails
              Skalp::Material_dialog.materialdialog.execute_script("select('#{material}')")
              Skalp::Material_dialog.materialdialog.execute_script("app.selected_library = app.libraries[1]")
              Skalp::Material_dialog.selected_material = material
            end
          end
        end
      end
    end

    def default_rules
      rules = Skalp.dialog.style_settings(Sketchup.active_model)[:style_rules].rules

      if rules.size == 3 && rules[0][:type] == :Model && rules[1][:type] == :ByLayer && rules[2][:type] == :ByObject
        true
      else
        false
      end
    end

    def onMouseMove(flags, x, y, view)
      @flags = flags
      @view = view
      @x = x
      @y = y

      ph = view.pick_helper
      ph.do_pick(x, y)
      face = ph.picked_face

      if face && Skalp.active_model && Skalp.active_model.entity_strings
        node_value = Skalp.active_model.entity_strings[face.get_attribute('Skalp', 'from_sub_object')]

        if node_value
          @node = node_value.node
          @section_material = node_value.section_material
          @section_material = '' if @section_material == 'Skalp default'
          rule = rules

          case rule
          when :Model
            @rule_cursor = 6
          when :ByTag
            @rule_cursor = 2
          when :ByObject
            @rule_cursor = 1
          else
            @rule_cursor = 7
          end

            case @modifier
            when :shift_alt
              info_text = "Select section to paint Model."
            when :alt #Ctrl
              info_text = "Select section to paint Tag: '#{node_value.layer}'."
            when :shift
              info_text = "Select section to paint Object."
            when :command #Alt
              info_text = "Select section to match paint from."
            else
              if OS == :MAC
                info_text = "Select section to paint, SHIFT to paint Object, ALT to paint Tag: '#{node_value.layer}' or SHIFT+ALT to paint Model. Command = Sample Material."
              else
                info_text = "Select section to paint, SHIFT to paint Object, ALT to paint Tag: '#{node_value.layer}' or SHIFT+ALT to paint Model. Command = Sample Material."
              end
            end

          Sketchup.set_status_text info_text, SB_PROMPT
        else
          @node = nil
          Sketchup.set_status_text "no Skalp section", SB_PROMPT
        end
      else
        @node = nil
        Sketchup.set_status_text "no Skalp section", SB_PROMPT
      end

      view.invalidate
      @sectionface = face_from_section?(face)
      onSetCursor
    end

    def face_from_section?(face)
      return false unless face
      return false unless face.is_a?(Sketchup::Face)
      return false unless Skalp.active_model.sectiongroup
      return false unless Skalp.active_model.sectiongroup.valid?
      Skalp.active_model.sectiongroup.entities.grep(Sketchup::Face).each do |face_in_section|
        return true if face_in_section == face
      end
      return false
    end

    def rules(object = Sketchup.active_model)
      return nil unless object

      rules = Skalp.dialog.style_settings(object)[:style_rules]
      return nil unless rules

      rules.merge.reverse.each do |rule|
        case rule[:type]
        when :Scene
          page_name = rule[:type_setting]
          if page_name && Sketchup.active_model.pages[page_name] && Skalp.scene_style_nested == false
            Skalp.scene_style_nested = true
            return rules(Sketchup.active_model.pages[page_name])
          end
        when :ByLayer
          material = Sketchup.active_model.layers[@node.value.layer_used_by_hatch].get_attribute('Skalp', 'material') if Sketchup.active_model.layers[@node.value.layer]
          return :ByTag if material && material != ''
        when :ByTexture
          return :ByTexture
        when :Layer
          material = rule[:type_setting][@node.value.layer_used_by_hatch]
          return :Tag if material
        when :Tag
          if @node.value.tag != nil && @node.value.tag != ''
            tags = @node.value.tag.split(',').map {|tag| Skalp.utf8(tag.strip)}
            return :Label if tags.include?(rule[:type_setting].strip)
          end
        when :Pattern
          return :Pattern if rule[:type_setting] == @section_material
        when :Texture
          if @node.value.su_material
            material = rule[:type_setting][@node.value.su_material_used_by_hatch.name]
            return :Texture if material
          end
        when :ByObject
          if @section_material != nil && @section_material !='' && @section_material != 'Skalp default'
            return :ByObject
          end
        when :Model
          return :Model
        end
      end

      return :Model
    end
  end
end