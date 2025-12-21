module Skalp
  def print_style_settings(object)
    settings = Skalp.dialog.style_settings(object)

    if object.class == Sketchup::Model
      puts "--- #{object} ---"
    else
      puts "--- #{object.name} ---"
    end

    return unless Skalp.active_model.get_memory_attribute(object, 'Skalp', 'style_settings') || object.class == Sketchup::Model

    settings.each do |key, value|
      if key == :style_rules
        puts "#{key}:#{value.rules.inspect}"
      else
        puts "#{key}: #{value}"
      end
    end
  end

  def show_styles
    puts "****************************"
    puts "STYLE SETTINGS"
    puts "****************************"

    model = Sketchup.active_model

    print_style_settings(model)

    model.pages.each do |page|
      print_style_settings(page)
    end
    puts "END*************************"
  end

  module StyleSettings
    STYLE_SETTINGS = [:drawing_scale, :rearview_status, :rearview_linestyle, :section_cut_width_status, :depth_clipping_status, :depth_clipping_distance, :style_rules]

    def style_settings(object = Sketchup.active_model)
      return {} unless Skalp.active_model
      page_settings = Skalp.active_model.get_memory_attribute(object, 'Skalp', 'style_settings')

      if page_settings == nil || page_settings == ''
        model_settings = Skalp.active_model.get_memory_attribute(Sketchup.active_model, 'Skalp', 'style_settings')
        model_settings.class == Hash ? model_settings : {}
      else
        page_settings.class == Hash ? page_settings : {}
      end
    end

    def check_SU_style
      if Skalp.active_model.rendering_options.hiddenline_style_active?
        set_hiddenline_mode_active
      else
        set_hiddenline_mode_inactive
      end
    end

    def page_changed(object)
      settings_from_page(object) if object.class == Sketchup::Page
      update_dialog
    end

    def update_dialog
      save_settings_status ? save_settings_checkbox_on : save_settings_checkbox_off
      rearview_status ? rearview_status_switch_on : rearview_status_switch_off
      rearview_update ? rearview_update_checkbox_on : rearview_update_checkbox_off
      set_rearview_linestyle

      lineweights_status ? lineweights_status_switch_on : lineweights_status_switch_off

      set_drawing_scale_in_dialog(drawing_scale)

      if fog_status then
        set_fog_distance_in_dialog(fog_distance)
        fog_status_switch_on
      else
        fog_status_switch_off
        align_view_symbol_black
      end

      check_SU_style
      check_rearview_uptodate
      style_rules.to_dialog
    end

    def blur_dialog_settings
      script("$('#display_settings_blured').show()")
      script("$('#save_check').prop('disabled', true)")
      script("$('#save_style').css('color', 'LightGrey')")
      set_icon("align_view", "icons/align_view_inactive.png")
      set_icon("sections_update", "icons/update_icon_inactive.png")
    end

    def show_dialog_settings
      script("$('#display_settings_blured').hide()")
      script("$('#save_check').prop('disabled', false)")
      script("$('#save_style').css('color', 'black')")
      set_icon("align_view", "icons/align_view.png")
    end

    def check_rearview_uptodate
      if Sketchup.active_model.pages.selected_page
        index = Sketchup.active_model.pages.selected_page
      else
        index = Sketchup.active_model
      end

      result = Skalp.active_model.hiddenlines.uptodate[index]

      if result || rearview_status == false then
        rearview_status_black
        true
      else
        rearview_status_red
        false
      end
    end

    def check_uptodate
      check_rearview_uptodate
    end

    def settings_from_dialog(params)
      style_rules = StyleRules.new
      style_rules.from_dialog(params)

      save_style_rules(style_rules)
    end

    # READ AND WRITE TO MEMORY_ATTRIBUTES
    def settings_to_active_page_if_save_settings_is_on
      selected_page = Sketchup.active_model.pages.selected_page
      return unless selected_page && save_settings_status
      settings_to_page(selected_page)
    end

    def settings_to_page(page)
      return unless Skalp.active_model
      Skalp.active_model.set_memory_attribute(page, 'Skalp', 'style_settings', Hash.new)
      page_settings = Skalp.active_model.get_memory_attribute(page, 'Skalp', 'style_settings')
      model_settings = style_settings
      STYLE_SETTINGS.each { |setting| page_settings[setting] = model_settings[setting] }
    end

    def settings_from_page(page)
      return unless Skalp.active_model
      page_settings = style_settings(page)

      if page_settings
        model_settings = style_settings
        STYLE_SETTINGS.each { |setting| model_settings[setting] = page_settings[setting] }
        Skalp.active_model.save_settings = true
      else
        Skalp.active_model.save_settings = false
      end
    end

    def remove_settings(object)
      return unless Skalp.active_model
      Skalp.active_model.set_memory_attribute(object, 'Skalp', 'style_settings', nil)
    end

    def save_settings_status
      return false unless Sketchup.active_model

      page = Sketchup.active_model.pages.selected_page
      return false unless page

      style = Skalp.active_model.get_memory_attribute(page, 'Skalp', 'style_settings')
      style!=nil && style.class == Hash
    end

    def save_rearview_update(status, object = Sketchup.active_model)
      return unless Skalp.active_model
      if status
        Skalp.active_model.set_memory_attribute(object, 'Skalp', 'rearview_update', 'true')
      else
        Skalp.active_model.set_memory_attribute(object, 'Skalp', 'rearview_update', 'false')
      end
    end

    def rearview_update(object = Sketchup.active_model)
      return unless Skalp.active_model
      Skalp.active_model.get_memory_attribute(object, 'Skalp', 'rearview_update') == 'true'
    end

    def save_rearview_status(status, object = Sketchup.active_model)
      style_settings(object)[:rearview_status] = status
    end

    def save_rearview_linestyle(linetype, object = Sketchup.active_model)
      style_settings(object)[:rearview_linestyle] = linetype
    end

    def rearview_linestyle(object = Sketchup.active_model)
      linestyle = style_settings(object)[:rearview_linestyle]
      if linestyle == nil || linestyle == ''
        linestyle = 'Dash'
        save_rearview_linestyle(linestyle, object)
      end

      linestyle
    end

    def rearview_status(object = Sketchup.active_model)
      style_settings(object)[:rearview_status]
    end

    def save_lineweights_update(status, object = Sketchup.active_model)
      return unless Skalp.active_model
      if status
        Skalp.active_model.set_memory_attribute(object, 'Skalp', 'lineweights_update', 'true')
      else
        Skalp.active_model.set_memory_attribute(object, 'Skalp', 'lineweights_update', 'false')
      end
    end

    def lineweights_update(object = Sketchup.active_model)
      return false unless Skalp.active_model
      Skalp.active_model.get_memory_attribute(object, 'Skalp', 'lineweights') == 'true'
    end

    def save_lineweights_status(status, object = Sketchup.active_model)
      style_settings(object)[:section_cut_width_status] = status
    end

    def rear_view_status(object = Sketchup.active_model)
      style_settings(object)[:rearview_status]
    end

    def lineweights_status(object = Sketchup.active_model)
      style_settings(object)[:section_cut_width_status]
    end

    def save_drawing_scale(scale, object = Sketchup.active_model)
      style_settings(object)[:drawing_scale] = scale.to_f
    end

    def drawing_scale(object = Sketchup.active_model)
      style_settings(object)[:drawing_scale]
    end

    def save_fog_status(status, object = Sketchup.active_model)
      style_settings(object)[:depth_clipping_status] = status
    end

    def fog_status(object = Sketchup.active_model)
      style_settings(object)[:depth_clipping_status]
    end

    def fog_distance(object = Sketchup.active_model)
      style_settings(object)[:depth_clipping_distance]
    end

    def save_fog_distance(distance, object = Sketchup.active_model)
      distance.class == Distance ? style_settings(object)[:depth_clipping_distance] = distance : style_settings(object)[:depth_clipping_distance] = Distance.new(distance)
    end

    def fog_action
      return unless Skalp.active_model

      if fog_status
        Skalp.fog
      else
        align_view_symbol_black

        if Skalp.active_model.view_observer
          Sketchup.active_model.active_view.remove_observer(Skalp.active_model.view_observer)
          Skalp.active_model.view_observer = nil
        end

        Skalp.active_model.skpModel.rendering_options['DisplayFog'] = false

        if save_settings_status
          page = Sketchup.active_model.pages.selected_page
          page.use_rendering_options? && page.rendering_options['DisplayFog'] = false
        end
      end
    end

    def style_rules(object = Sketchup.active_model)
      style_settings(object)[:style_rules] || StyleRules.new
    end

    def save_style_rules(rules, object = Sketchup.active_model)
      style_settings(object)[:style_rules] = rules
    end

    #DIALOG CALLBACK ACTIONS
    def set_drawing_scale(scale)
      save_drawing_scale(scale)
      save_drawing_scale(scale, Sketchup.active_model.pages.selected_page) if save_settings_status && Sketchup.active_model.pages.selected_page
    end

    def set_rearview_switch(status)
      save_rearview_status(status)
      save_rearview_status(status, Sketchup.active_model.pages.selected_page) if save_settings_status && Sketchup.active_model.pages.selected_page
    end

    def set_lineweights_switch(status)
      save_lineweights_status(status)
      save_lineweights_status(status, Sketchup.active_model.pages.selected_page) if save_settings_status && Sketchup.active_model.pages.selected_page
    end

    def set_fog_switch(status)
      save_fog_status(status)
      save_fog_status(status, Sketchup.active_model.pages.selected_page) if save_settings_status && Sketchup.active_model.pages.selected_page
      fog_action
    end

    def set_fog_distance(distance)
      save_fog_distance(distance)
      save_fog_distance(distance, Sketchup.active_model.pages.selected_page) if save_settings_status && Sketchup.active_model.pages.selected_page
      fog_action
    end

    #INTERACT WITH MODEL
    def turnoff_rearview_lines_in_model
      return unless Skalp.active_model
      Skalp.active_model.hiddenlines.remove_rear_view_instance(Sketchup.active_model.pages.selected_page) if Sketchup.active_model.pages.selected_page
    end

    def turnon_rearview_lines_in_model
      return unless Skalp.active_model
      Skalp.active_model.active_section && Skalp.active_model.active_section.place_rear_view_lines_in_model
    end

    # SET DIALOG DOM ELEMENTS

    def set_hiddenline_mode_active
      set_icon("render_mode", "icons/render_hiddenline_active.png")
    end

    def set_hiddenline_mode_inactive
      set_icon("render_mode", "icons/render_hiddenline.png")
    end

    def save_settings_checkbox_on
      script("$('#save_check').prop('checked', true)")
    end

    def save_settings_checkbox_off
      script("$('#save_check').prop('checked', false)")
    end

    def rearview_update_checkbox_on
      script("$('#rearview_checkbox').prop('checked', true)")
    end

    def rearview_update_checkbox_off
      script("$('#rearview_checkbox').prop('checked', false)")
    end

    def rearview_status_switch_on
      set_icon("onoff_rearview", "icons/onoff_green_small.png")
      set_select_linestyle_active
    end

    def rearview_status_switch_off
      set_icon("onoff_rearview", "icons/onoff_grey_small.png")
      set_select_linestyle_inactive
    end

    def set_rearview_linestyle
      script("$('#linestyles').val('#{rearview_linestyle}')")
    end

    def lineweights_status_switch_on
      set_icon("onoff_lineweights", "icons/onoff_green_small.png")
    end

    def lineweights_status_switch_off
      set_icon("onoff_lineweights", "icons/onoff_grey_small.png")
    end

    def fog_status_switch_on
      set_icon("onoff_fog", "icons/onoff_green_small.png")
      set_fog_distance_active
    end

    def fog_status_switch_off
      set_icon("onoff_fog", "icons/onoff_grey_small.png")
      set_fog_distance_inactive
    end

    def set_select_linestyle_active
      script("$('#linestyles').prop('disabled', false)")
    end

    def set_select_linestyle_inactive
      script("$('#linestyles').prop('disabled', true)")
    end

    def set_fog_distance_active
      script("$('#fog_distance_input').prop('disabled', false)")
    end

    def set_fog_distance_inactive
      script("$('#fog_distance_input').prop('disabled', true)")
    end

    def set_fog_distance_in_dialog(distance)
      return unless Skalp.dialog
      script("$('#fog_distance_input').val('#{distance.to_s}')")
      fog_action
    end

    def set_drawing_scale_in_dialog(scale)
      script("$('#drawing_scale_input').val(#{scale})")
    end

    def rearview_status_black
      script("$('#rear_lines').css('color', 'black')")
      update_symbol_black #TODO change when lineweighs will be implemented
    end

    def rearview_status_red
      script("$('#rear_lines').css('color', 'red')")
      update_symbol_red #TODO change when lineweighs will be implemented
    end

    def update_symbol_black
      set_icon('sections_update', 'icons/update_icon_black.png')
    end

    def update_symbol_red
      set_icon('sections_update', 'icons/update_icon_red.png')
    end

    def align_view_symbol_black
      script("$('#fog_label').css('color', 'black')")
      set_icon('align_view', 'icons/align_view.png')
    end

    def align_view_symbol_red
      script("$('#fog_label').css('color', 'red')")
      set_icon('align_view', 'icons/align_view_red.png')
    end
  end
end
