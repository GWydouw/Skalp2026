module Skalp
  class RenderingOptions
    def initialize(model)
      @model = model
      @stored_hiddenline_rendering_options = {}
      @stored_section_cut_width_rendering_options = {}
      @stored_fog_rendering_options = {}
    end

    def set_hiddenline_mode(object = @model)
      return if object.class == Sketchup::Page && !object.use_rendering_options?

      active_rendering_options = {}
      active_rendering_options["RenderMode"] = object.rendering_options["RenderMode"]
      active_rendering_options["DisplayColorByLayer"] = object.rendering_options["DisplayColorByLayer"]

      @stored_hiddenline_rendering_options[object] = active_rendering_options

      observer_status = Skalp.block_observers
      Skalp.block_observers = true
      object.rendering_options["RenderMode"] = 1
      object.rendering_options["DisplayColorByLayer"] = true
      Skalp.block_observers = observer_status

      Skalp.dialog.set_hiddenline_mode_active if Skalp.dialog
    end

    def get_hiddenline_settings(object = @model)
      @hiddenline_settings = {}
      @hiddenline_settings["RenderMode"] = object.rendering_options["RenderMode"]
      @hiddenline_settings["DisplayColorByLayer"] = object.rendering_options["DisplayColorByLayer"]
    end

    def set_hiddenline_settings(object = @model)
      object.rendering_options["RenderMode"] = @hiddenline_settings["RenderMode"]
      object.rendering_options["DisplayColorByLayer"] = @hiddenline_settings["DisplayColorByLayer"]
    end

    def reset_hiddenline_mode(object = @model)
      return if object.class == Sketchup::Page && !object.use_rendering_options?

      unless @stored_hiddenline_rendering_options[object]
        observer_status = Skalp.block_observers
        Skalp.block_observers = true

        get_fog_settings(object)
        get_section_cut_width_settings(object)

        styles = Sketchup.active_model.styles
        styles.selected_style = styles.selected_style if styles.active_style_changed

        set_fog_settings(object)
        set_section_cut_width_settings(object)

        Skalp.block_observers = observer_status
        return
      end

      observer_status = Skalp.block_observers
      Skalp.block_observers = true
      object.rendering_options["RenderMode"] = @stored_hiddenline_rendering_options[object]["RenderMode"]
      object.rendering_options["DisplayColorByLayer"] = @stored_hiddenline_rendering_options[object]["DisplayColorByLayer"]
      Skalp.block_observers = observer_status

      #if reset doesn't change anything, we turn off color by layer and set the rendermode to textures
      if object.rendering_options["DisplayColorByLayer"] == true  &&  object.rendering_options["RenderMode"] == 1
        object.rendering_options["DisplayColorByLayer"] = false
        object.rendering_options["RenderMode"] = 2
      end

      Skalp.dialog.set_hiddenline_mode_inactive if Skalp.dialog
    end

    def set_section_cut_width_mode(object = @model, color = 'black')
      return if object.class == Sketchup::Page && !object.use_rendering_options?

      active_rendering_options = {}
      active_rendering_options["SectionDefaultCutColor"] = object.rendering_options["SectionDefaultCutColor"]
      active_rendering_options["SectionCutWidth"] = object.rendering_options["SectionCutWidth"]

      @stored_section_cut_width_rendering_options[object] = active_rendering_options

      observer_status = Skalp.block_observers
      Skalp.block_observers = true
      object.rendering_options["SectionDefaultCutColor"] = color
      object.rendering_options["SectionCutWidth"] = 1
      Skalp.block_observers = observer_status
    end

    def get_section_cut_width_settings(object = @model)
      @section_cut_width_settings = {}
      @section_cut_width_settings["SectionDefaultCutColor"] = object.rendering_options["SectionDefaultCutColor"]
      @section_cut_width_settings["SectionCutWidth"] = object.rendering_options["SectionCutWidth"]
    end

    def set_section_cut_width_settings(object = @model)
      object.rendering_options["SectionDefaultCutColor"] = @section_cut_width_settings["SectionDefaultCutColor"]
      object.rendering_options["SectionCutWidth"] = @section_cut_width_settings["SectionCutWidth"]
    end

    def reset_section_cut_width(object = @model)
      return if object.class == Sketchup::Page && !object.use_rendering_options?

      unless @stored_section_cut_width_rendering_options[object]
        observer_status = Skalp.block_observers
        Skalp.block_observers = true

        get_fog_settings(object)
        get_hiddenline_settings(object)

        styles = Sketchup.active_model.styles
        styles.selected_style = styles.selected_style if styles.active_style_changed

        set_fog_settings(object)
        set_hiddenline_settings(object)

        Skalp.block_observers = observer_status
        return
      end

      observer_status = Skalp.block_observers
      Skalp.block_observers = true
      object.rendering_options["SectionDefaultCutColor"] = @stored_section_cut_width_rendering_options[object]["SectionDefaultCutColor"]
      object.rendering_options["SectionCutWidth"] = @stored_section_cut_width_rendering_options[object]["SectionCutWidth"]
      Skalp.block_observers = observer_status
    end

    def set_fog_mode(object = @model, startDist, endDist)
      return if object.class == Sketchup::Page && !object.use_rendering_options?

      active_rendering_options = {}
      active_rendering_options["DisplayFog"] = object.rendering_options["DisplayFog"]
      active_rendering_options["FogEndDist"] = object.rendering_options["FogEndDist"]
      active_rendering_options["FogStartDist"] = object.rendering_options["FogStartDist"]

      @stored_section_cut_width_rendering_options[object] = active_rendering_options

      observer_status = Skalp.block_observers
      Skalp.block_observers = true
      object.rendering_options['DisplayFog'] = true
      object.rendering_options["FogEndDist"] = endDist
      object.rendering_options["FogStartDist"] = startDist
      Skalp.block_observers = observer_status
    end

    def get_fog_settings(object = @model)
      @fog_settings = {}
      @fog_settings["DisplayFog"] = object.rendering_options["DisplayFog"]
      @fog_settings["FogEndDist"] = object.rendering_options["FogEndDist"]
      @fog_settings["FogStartDist"] = object.rendering_options["FogStartDist"]
    end

    def set_fog_settings(object = @model)
      object.rendering_options["DisplayFog"] = @fog_settings["DisplayFog"]
      object.rendering_options["FogEndDist"] = @fog_settings["FogEndDist"]
      object.rendering_options["FogStartDist"] = @fog_settings["FogStartDist"]
    end

    def reset_fog(object = @model)
      return if object.class == Sketchup::Page && !object.use_rendering_options?

      unless @stored_fog_rendering_options[object]
        observer_status = Skalp.block_observers
        Skalp.block_observers = true

        get_section_cut_width_settings(object)
        get_hiddenline_settings(object)

        styles = Sketchup.active_model.styles
        styles.selected_style = styles.selected_style if styles.active_style_changed

        set_section_cut_width_settings(object)
        set_hiddenline_settings(object)

        Skalp.block_observers = observer_status
        return
      end

      observer_status = Skalp.block_observers
      Skalp.block_observers = true
      object.rendering_options["DisplayFog"] = @stored_fog_rendering_options[object]["DisplayFog"]
      object.rendering_options["FogEndDist"] = @stored_fog_rendering_options[object]["FogEndDist"]
      object.rendering_options["FogStartDist"] = @stored_fog_rendering_options[object]["FogStartDist"]
      Skalp.block_observers = observer_status
    end

    def hiddenline_style_active?(object = Sketchup.active_model)
      return false unless object.class == Sketchup::Page || object == Sketchup.active_model
      return false unless object.rendering_options
      object.rendering_options["RenderMode"] == 1 && object.rendering_options["DisplayColorByLayer"] == true
    end

    def color_by_layer_active?(object = Sketchup.active_model)
      return false unless object.class == Sketchup::Page || object == Sketchup.active_model
      return false unless object.rendering_options
      object.rendering_options["DisplayColorByLayer"] == true
    end
  end
end
