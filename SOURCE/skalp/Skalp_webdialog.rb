module Skalp
  class Webdialog
    def script(javascript)
      @webdialog.execute_script(javascript)
      result = @webdialog.get_element_value('RUBY_BRIDGE')
      @webdialog.execute_script("document.getElementById('RUBY_BRIDGE').value = ''")
      return result
    rescue
      return false
    end

    def read_border_size
      w = Sketchup.read_default('Skalp', 'w_border')
      h = Sketchup.read_default('Skalp', 'h_border')

      if Skalp::OS == :MAC
        w ? @w_border = 0 : @w_border = w.to_i
        h ? @h_border = 22 : @h_border = h.to_i
      else
        w ? @w_border = 10 : @w_border = w.to_i
        h ? @h_border = 36 : @h_border = h.to_i
      end
    end

    def write_border_size(dialog_type)
      check_h_border = script("document.getElementById('RUBY_BRIDGE').value = window.outerHeight-window.innerHeight").to_i
      check_w_border = script("document.getElementById('RUBY_BRIDGE').value = window.outerWidth-window.innerWidth").to_i

      Sketchup.write_default('Skalp', 'w_border_section', check_w_border)
      Sketchup.write_default('Skalp', 'h_border_section', check_h_border)

      if check_h_border != @h_border || check_w_border != @w_border || @startup
        if Skalp::OS == :WINDOWS
          self.min_height= @height[dialog_type] + check_h_border
          self.max_height= @height[dialog_type] + check_h_border
          self.min_width = @w_size + check_w_border
        else
          self.min_height= @height[dialog_type]
          self.max_height= @height[dialog_type]
          self.min_width = @w_size
        end

        set_size(@dialog_w + check_w_border, @height[dialog_type] + check_h_border)

        @w_border = check_w_border
        @h_border = check_h_border

        @startup = false
      end
    end

    def set_icon(id, image)
      script("document.getElementById('#{id}').src = '#{image}'")
    end

    def set_preview(id, image)
      script("document.getElementById('#{id}').src = '#{image}?random='+new Date().getTime();")
    end

    def set_value(id, value)
      script("set_value('#{id}', '#{value}')")
    end

    def set_value_add(id, value)
      script("set_value_add('#{id}','#{value}')")
    end

    def set_value_clear(id)
      script("set_value_clear('#{id}')")
    end

    def visibility(id, visible)
      visible ?
          script("document.getElementById('#{id}').style.visibility = 'visible'") :
          script("document.getElementById('#{id}').style.visibility = 'hidden'")
    end

    def get_value(id)
      @webdialog.get_element_value(id)
    rescue
      return false
    end

    def set_title(id, title)
      script("document.getElementById('#{id}').title = '#{title}'")
    end

    def clear(id)
      script("clear_listbox('#{id}')")
    end

    def clear_by_class(class_name)
      script("clear_listbox_by_class('#{class_name}')")
    end

    def add(id, item)
      script("add_listbox('#{id}', '#{item}')")
    end

    def add_by_class(class_name, item)
      script("add_listbox_by_class('#{class_name}', '#{item}')")
    end

    def visible?
      @webdialog.visible?
    end

    def show
      Skalp::OS == :MAC ? @webdialog.show_modal() : @webdialog.show()
    end

    def close
      @webdialog.close
      #@webdialog = nil
    end

    def set_size(x, y)
      x += @w_border
      y += @h_border

      Skalp::OS == :MAC ? @webdialog.execute_script("window.resizeTo(#{x},#{y})") : @webdialog.set_size(x, y)
    end

    def min_width=(w)
      @min_w = w
      if Skalp::OS == :MAC
        @webdialog.execute_script("$('#min_width').val(#{w})")
        @webdialog.min_width = w unless @showmore_dialog
      else
        w += @w_border
        @webdialog.min_width = w
      end
    end

    def max_width=(w)
      @max_w = w
      if Skalp::OS == :MAC
        @webdialog.execute_script("$('#max_width').val(#{w})")
        @webdialog.max_width = w
      else
        w += @w_border
        @webdialog.max_width = w
      end
    end

    def min_height=(h)
      @min_h = h
      if Skalp::OS == :MAC
        @webdialog.execute_script("$('#min_height').val(#{h})")
        @webdialog.min_height = h unless @showmore_dialog
      else
        h += @h_border
        @webdialog.min_height = h
      end
    end

    def max_height=(h)
      @max_h = h
      if Skalp::OS == :MAC
        @webdialog.execute_script("$('#max_height').val(#{h})")
        @webdialog.max_height = h unless @showmore_dialog
      else
        h += @h_border
        @webdialog.max_height = h
      end
    end

    def show_more(dialog_type)

      @show_more = true

      x = @dialog_x.to_i
      y = @dialog_y.to_i
      w = @dialog_w.to_i

      if @show_more_toggle[dialog_type]
        if dialog_type == :sections
          @show_more_saved = Sketchup.write_default('Skalp', 'sections_show_more', 1)
        end

        #eerst zorgen dat de nieuwe afmetingen van de dialoogbox niet in conflict komen met zijn min en max afmetingen.
        self.max_height = 1440
        set_size(w, @height_expand_resize) if dialog_type == :sections
        self.min_height = @height_expand[dialog_type]

        visibility('dialog_styles', true)
        visibility('save_style', true)
        visibility('display_settings_blured', true)

        dialog_type == :sections ? set_icon(dialog_type.to_s + '_show_more', 'icons/show_less.png') : set_icon(dialog_type.to_s + '_show_more', 'icons/show_less.png')
      else
        if dialog_type == :sections
          @show_more_saved = Sketchup.write_default('Skalp', 'sections_show_more', 0)
        end
        self.min_height = @height[dialog_type]
        set_size(w, @height[dialog_type])
        self.max_height = @height[dialog_type]

        visibility('dialog_styles', false)
        visibility('save_style', false)
        visibility('display_settings_blured', false)

        dialog_type == :sections ? set_icon(dialog_type.to_s + '_show_more', 'icons/show_more.png') : set_icon(dialog_type.to_s + '_show_more', 'icons/show_more.png')
      end

      @show_more = false
    end

    # 31/7/2016 GW - verplaatst naar de style_settings class
    # def get_drawing_scale
    #   Skalp.active_model.get_memory_attribute(Sketchup.active_model, 'Skalp', 'active_drawing_scale') ? Skalp.active_model.get_memory_attribute(Sketchup.active_model, 'Skalp', 'active_drawing_scale'): Skalp.default_drawing_scale
    # rescue
    #   Skalp.default_drawing_scale
    # end

    def get_section_materials
      clear('material_list')
      skalpList = []
      suList =[]

      Sketchup.active_model.materials.each { |material|
        material.get_attribute('Skalp', 'ID') ? (skalpList << material.name unless material.name.include?('%')) : suList << material.name }

      skalpList.uniq.compact!
      skalpList.sort!
      suList.uniq.compact!
      suList.sort!

      add('material_list', '')
      add('material_list', '- None -')

      skalpList.each { |material|
        add('material_list', material) unless material == '' }

      add('material_list', '-----------')

      suList.each { |material|
        add('material_list', material) unless material == '' }

      add('material_list', '- Multiple selected -')
    end
  end
end
