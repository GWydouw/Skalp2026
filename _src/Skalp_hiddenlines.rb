module Skalp
  class Hiddenlines_data
    attr_accessor :page, :target, :lines

    def initialize(index)
      (index.to_i == -1) ? @page = Skalp.active_model.skpModel : @page = Skalp.active_model.skpModel.pages[index.to_i]
      @target = []
      @lines = {}
    end

    def add_line(line, layer)
      @lines[layer]=[] unless @lines[layer]
      @lines[layer] << line
    end
  end

  class Hiddenlines
    attr_reader :forward_lines_result, :rear_lines_result, :pages_info_result
    attr_accessor :rear_view_instances, :rear_view_definitions, :uptodate, :calculated, :linestyle, :hiddenline_layer_setup

    R_MASK  = 0b111111110000000000000000 unless defined? R_MASK
    G_MASK  = 0b000000001111111100000000 unless defined? G_MASK
    B_MASK  = 0b000000000000000011111111 unless defined? B_MASK

    Hiddenline_layers = Struct.new(:layer, :name, :original_color, :index_color) unless defined?(Skalp::Hiddenlines::Hiddenline_layers)
    Line = Struct.new(:line, :layer) unless defined?(Skalp::Hiddenlines::Line)

    def lo_color_from_su_color(rgb)
      # Shadow settings Shadows ON, Light 0, Dark 80, Time not at night
      # never use 113
      # 0-112 is ok
      # 114-255 -1
      # => layout color
    end

    def initialize(model)
      @uptodate = {}
      @calculated = {}
      @model = model
      @skpModel = @model.skpModel
      @rear_view_definitions = {}
      @forward_lines_result = {}
      @rear_lines_result = {}
      load_rear_view_definitions

      @temp_model = SKALP_PATH + "lib/temp.skp"
      @temp_model_reversed = SKALP_PATH + "lib/temp_reversed.skp"
    end

    def get_hiddenline_properties(rgb)
      r = rgb[1..rgb.index('G')-1].to_i
      g = rgb[rgb.index('G')+1..rgb.index('B')-1].to_i
      b = rgb[rgb.index('B')+1..-1].to_i

      color = Sketchup::Color.new(r,g, b)
      layer_setup = get_layer_setup_by_color(color)

      if layer_setup
        layer_setup.layer
      else
        Skalp.active_model.skpModel.layers['Layer0']
      end
    end

    def get_layer_setup_by_color(color)
      @hiddenline_layer_setup.each_value do |layer_setup|
        return layer_setup if layer_setup.index_color == color
      end
      nil
    end

    def setup_layers
      @hiddenline_layer_setup = {}
      @uniquecolor = 100
      Skalp.active_model.skpModel.layers.each do |layer|
        next unless layer
        next if layer.get_attribute('Skalp', 'ID')
        layer_setup = Hiddenline_layers.new
        layer_setup.layer = layer
        layer_setup.name = layer.name
        layer_setup.original_color = layer.color
        r,g,b = uniquecolor_to_rgb
        color = Sketchup::Color.new(r, g, b)
        layer.color = color

        layer_setup.index_color = color
        @hiddenline_layer_setup[layer] = layer_setup
      end
    end

    def uniquecolor_to_rgb
      r = (@uniquecolor & R_MASK) >> 16
      g = (@uniquecolor & G_MASK) >> 8
      b = (@uniquecolor & B_MASK)
      @uniquecolor += 100

      # color 113 can't convert unique between SU and LO on faces
      r= 114 if r == 113
      g= 114 if g == 113
      b= 114 if b == 113

      return r,g,b
    end

    def restore_layers
      Skalp.active_model.skpModel.layers.each do |layer|
        next if layer.get_attribute('Skalp', 'ID')
        layer.color = @hiddenline_layer_setup[layer].original_color
      end
    end

    def get_page_info_by_index(index)
      @pages_info_result.each do |page_info|
        return page_info if page_info[:index] == index
      end
      nil
    end

    def sectionplane_changed(id)
      @uptodate.delete_if {|k, v| v == id}
    end

    def clear_hiddenlines
      @forward_lines_result = {}
      @rear_lines_result = {}
    end

    def update_hiddenlines(scenes = :active)
      update_forward_lines(scenes)
      update_rear_lines(scenes, false)
    end

    def update_forward_lines(scenes = :active)
      @forward_lines_result = get_lines(scenes, false)
    end

    def update_rear_lines(scenes = :active, save_temp = true)
      @rear_lines_result = get_lines(scenes, true, save_temp)
      @model.model_changes = false if @rear_lines_result != {}
    end

    def set_active_page_hiddenlines_to_model_hiddenlines
      selected = Skalp.active_model.skpModel.pages.selected_page
      @rear_lines_result[@skpModel] =  @rear_lines_result[selected]
      @rear_view_definitions[@skpModel] = @rear_view_definitions[selected]
    end

    def add_rear_lines_to_model(scenes = :active)
      observer_status = @model.observer_active
      @model.observer_active = false
      @model.start('Skalp - add rear view lines', true)

      if scenes == :active
        if Skalp.dialog.rearview_status
          if Skalp.active_model.skpModel.pages && Skalp.active_model.skpModel.pages.selected_page
            add_lines_to_page(Skalp.active_model.skpModel.pages.selected_page, true)
          else
            add_lines_to_page
          end
        end
      elsif scenes == :all
        @skpModel.pages.each do |page|
          add_lines_to_page(page) if Skalp.dialog.rearview_status(page)
        end
        add_lines_to_page if Skalp.dialog.rearview_status
      end

      @model.commit
      @model.observer_active = observer_status
    end

    def update_scale
      selected = Skalp.active_model.skpModel.pages.selected_page

      add_lines_to_component(@rear_view_definitions[selected], @rear_lines_result[selected]) if @rear_view_definitions[selected] && Skalp.dialog.rearview_status(selected)
      add_lines_to_component(@rear_view_definitions[@skpModel], @rear_lines_result[@skpModel]) if @rear_view_definitions[@skpModel] && Skalp.dialog.rearview_status
    end

    def add_lines_to_page(page = @skpModel, copy_to_active_view = false)

      style_stettings =  @model.get_memory_attribute(page, 'Skalp', 'style_settings')

      if style_stettings.class == Hash
        @linestyle = @model.get_memory_attribute(page, 'Skalp', 'style_settings')[:rearview_linestyle]
        if @linestyle == nil || @linestyle == ''
          @linestyle = 'Dash'
          style_stettings[:rearview_linestyle] = 'Dash'
        end
      else
        @linestyle = 'Dash'
      end

      return unless @rear_lines_result && @rear_lines_result[page]

      if @rear_view_definitions[page] && @rear_view_definitions[page].valid?
        rear_view_definition = @rear_view_definitions[page]

        rear_view_definition.instances.each do |instance|
          instance.erase!
        end
        rear_view_definition.entities.clear!
      else
        definitions = Skalp.active_model.skpModel.definitions
        new_name = definitions.unique_name "Skalp - #{Skalp.translate('rear view')}"
        rear_view_definition = Skalp.active_model.skpModel.definitions.add(new_name)

        rear_view_definition.set_attribute('dynamic_attributes', '_hideinbrowser', true)
        UI.refresh_inspectors

        @rear_view_definitions[page] = rear_view_definition
      end

      add_lines_to_component(rear_view_definition, @rear_lines_result[page])
      add_rear_view_to_sectiongroup(rear_view_definition, page)

      if copy_to_active_view
        add_rear_view_to_sectiongroup(rear_view_definition)
      end
    end

    def remove_rear_view_instance(page)
      observer_status = @model.observer_active
      @model.observer_active = false

      if @rear_view_definitions[page] && !@rear_view_definitions[page].deleted?
        @rear_view_definitions[page].instances.each do |instance|
          instance.erase! unless instance.deleted?
        end
      end

      if @rear_view_definitions[@skpModel] && !@rear_view_definitions[@skpModel].deleted?
        @rear_view_definitions[@skpModel].instances.each do |instance|
          instance.erase! unless instance.deleted?
        end
      end

      @model.observer_active = observer_status
    end

    def remove_rear_views
      Skalp.active_model.skpModel.pages.each do |page|
        sectiongroup = get_sectiongroup(page)
        remove_rear_view_instances(sectiongroup) if sectiongroup
      end

      sectiongroup = get_sectiongroup
      remove_rear_view_instances(sectiongroup) if sectiongroup
    end

    private

    def create_sectiongroup_for_rearview(page)
      return unless page.valid? && Skalp.active_model.pages[page] && Skalp.active_model.pages[page].sectionplane
      transformation = Skalp.transformation_down * Skalp.active_model.pages[page].sectionplane.transformation.inverse
      sectiongroup = @model.active_sectionplane.section.create_sectiongroup(page)
      sectiongroup.transform!(transformation)
    end

    def add_rear_view_to_sectiongroup(rear_view_definition, page = @skpModel)
      return unless @model.active_sectionplane
      sectiongroup = get_sectiongroup(page)
      sectiongroup = create_sectiongroup_for_rearview(page) unless sectiongroup

      return unless sectiongroup && sectiongroup.valid?

      if page
        check_rear = Skalp.dialog.rearview_status(page)
      else
        check_rear = Skalp.dialog.rearview_status
      end

      if check_rear
        remove_rear_view_instances(sectiongroup)
        rear_view = sectiongroup.entities.add_instance(rear_view_definition, Geom::Transformation.new)
        rear_view.name = "Skalp - #{Skalp.translate('rear view')}"
      end
    end

    def remove_rear_view_instances(sectiongroup)
      sectiongroup.entities.grep(Sketchup::ComponentInstance).each {|instance| instance.erase! if instance.valid?}
    end

    def save_temp_model
      observers = @model.observer_active
      @model.observer_active = false

      settings_saved = {}
      # shadow_settings_saved = {}

      pages = [Skalp.active_model.skpModel]

      @model.start('Skalp - save temp model preparation', true)
      delete_rear_view_instances
      setup_layers

      Skalp.active_model.skpModel.pages.each do |page|
        pages << page
      end

      page_settings = {}

      pages.each do |page|
        next unless page
        unless page == Skalp.active_model.skpModel
          page_settings[page] = {use_rendering_options: page.use_rendering_options?, use_camera: page.use_camera?}
          page.use_rendering_options = true
          page.use_camera = true
        end

        # shadow_settings = {}
        #
        # shadow_settings[:City] = page.shadow_info["City"]
        # shadow_settings[:Country] = page.shadow_info["Country"]
        # shadow_settings[:Dark] = page.shadow_info["Dark"]
        # shadow_settings[:DayOfYear] = page.shadow_info["DayOfYear"]
        # shadow_settings[:DaylightSavings] = page.shadow_info["DaylightSavings"]
        # shadow_settings[:DisplayNorth] = page.shadow_info["DisplayNorth"]
        # shadow_settings[:DisplayOnAllFaces] = page.shadow_info["DisplayOnAllFaces"]
        # shadow_settings[:DisplayOnGroundPlane] = page.shadow_info["DisplayOnGroundPlane"]
        # shadow_settings[:DisplayShadows] = page.shadow_info["DisplayShadows"]
        # shadow_settings[:EdgesCastShadows] = page.shadow_info["EdgesCastShadows"]
        # shadow_settings[:Latitude] = page.shadow_info["Latitude"]
        # shadow_settings[:Light] = page.shadow_info["Light"]
        # shadow_settings[:Longitude] = page.shadow_info["Longitude"]
        # shadow_settings[:North] = page.shadow_info["North"]
        # shadow_settings[:ShadowTime] = page.shadow_info["ShadowTime"]
        # shadow_settings[:TZOffset] = page.shadow_info["TZOffset"]
        # shadow_settings[:UseSunForAllShading] = page.shadow_info["UseSunForAllShading"]
        #
        # shadow_settings_saved[page] = shadow_settings

        # page.shadow_info["City"] = "Skalp"
        # page.shadow_info["Country"] = "Skalp"
        # page.shadow_info["Dark"] = 80 #IMPORTANT TOT GET CORRECT CONVERTION
        # page.shadow_info["DayOfYear"] = 100
        # page.shadow_info["DaylightSavings"] = false
        # page.shadow_info["DisplayNorth"] = false
        # page.shadow_info["DisplayOnAllFaces"] = false
        # page.shadow_info["DisplayOnGroundPlane"] = false
        # page.shadow_info["DisplayShadows"] = false
        # page.shadow_info["EdgesCastShadows"] = false
        # page.shadow_info["Latitude"] = 55.18
        # page.shadow_info["Light"] = 0  #IMPORTANT TOT GET CORRECT CONVERTION
        # page.shadow_info["Longitude"] = 0.1
        # page.shadow_info["North"] = 0.0
        # page.shadow_info["ShadowTime"] = Time.new(2019, 5, 10, 14, 0, 0, "+00:00")
        # page.shadow_info["TZOffset"] = 0.0
        # page.shadow_info["UseSunForAllShading"] = true

        style_settings = {}

        style_settings[:edgeDisplayMode] = page.rendering_options["EdgeDisplayMode"]
        style_settings[:drawSilhouettes] = page.rendering_options["DrawSilhouettes"]
        style_settings[:drawDepthQue] = page.rendering_options["DrawDepthQue"]
        style_settings[:drawLineEnds] = page.rendering_options["DrawLineEnds"]
        style_settings[:jitterEdges] = page.rendering_options["JitterEdges"]
        style_settings[:extendLines] = page.rendering_options["ExtendLines"]

        style_settings[:silhouetteWidth] = page.rendering_options["SilhouetteWidth"]
        style_settings[:depthQueWidth] = page.rendering_options["DepthQueWidth"]
        style_settings[:lineExtension] = page.rendering_options["LineExtension"]
        style_settings[:lineEndWidth] = page.rendering_options["LineEndWidth"]

        style_settings[:displayText] = page.rendering_options["DisplayText"]
        style_settings[:sectionCutWidth] = page.rendering_options["SectionCutWidth"]

        style_settings[:renderMode] = page.rendering_options["RenderMode"]
        style_settings[:texture] = page.rendering_options["Texture"]
        style_settings[:displayColorByLayer] = page.rendering_options["DisplayColorByLayer"]
        style_settings[:EdgeColorMode] = page.rendering_options["EdgeColorMode"]

        settings_saved[page] = style_settings

        page.rendering_options["EdgeDisplayMode"] = true
        page.rendering_options["DrawSilhouettes"] = true
        page.rendering_options["DrawDepthQue"] = false
        page.rendering_options["DrawLineEnds"] = false
        page.rendering_options["JitterEdges"] = false
        page.rendering_options["ExtendLines"] = false

        page.rendering_options["SilhouetteWidth"] = 5
        page.rendering_options["DepthQueWidth"] = 1
        page.rendering_options["LineExtension"] = 1
        page.rendering_options["LineEndWidth"] = 1

        page.rendering_options["DisplayText"] = false
        page.rendering_options["SectionCutWidth"] = 10

        page.rendering_options["RenderMode"] = 1
        page.rendering_options["Texture"] = true
        page.rendering_options["DisplayColorByLayer"] = true
        page.rendering_options["EdgeColorMode"] = 0
      end

      File.delete(@temp_model) if File.exist?(@temp_model)
      File.delete(@temp_model_reversed) if File.exist?(@temp_model_reversed)

      @model.commit
      Skalp.active_model.skpModel.save_copy(@temp_model)
      @model.start('Skalp - save temp model cleanup', true)

      restore_layers

      pages.each do |page|
        page.rendering_options["EdgeDisplayMode"] = settings_saved[page][:edgeDisplayMode]
        page.rendering_options["DrawSilhouettes"] = settings_saved[page][:drawSilhouettes]
        page.rendering_options["DrawDepthQue"] = settings_saved[page][:drawDepthQue]
        page.rendering_options["DrawLineEnds"] = settings_saved[page][:drawLineEnds]
        page.rendering_options["JitterEdges"] = settings_saved[page][:jitterEdges]
        page.rendering_options["ExtendLines"] = settings_saved[page][:extendLines]

        page.rendering_options["SilhouetteWidth"] = settings_saved[page][:silhouetteWidth]
        page.rendering_options["DepthQueWidth"] = settings_saved[page][:depthQueWidth]
        page.rendering_options["LineExtension"] = settings_saved[page][:lineExtension]
        page.rendering_options["LineEndWidth"] = settings_saved[page][:lineEndWidth]

        page.rendering_options["DisplayText"] = settings_saved[page][:displayText]
        page.rendering_options["SectionCutWidth"] = settings_saved[page][:sectionCutWidth]

        page.rendering_options["RenderMode"] = settings_saved[page][:renderMode]
        page.rendering_options["Texture"] = settings_saved[page][:texture]
        page.rendering_options["DisplayColorByLayer"] = settings_saved[page][:displayColorByLayer]
        page.rendering_options["EdgeColorMode"] = settings_saved[page][:EdgeColorMode]

        unless page == Skalp.active_model.skpModel
          page.use_rendering_options = page_settings[page][:use_rendering_options]
          page.use_camera = page_settings[page][:use_camera]
        end

        # page.shadow_info["City"] = shadow_settings_saved[page][:City]
        # page.shadow_info["Country"] = shadow_settings_saved[page][:Country]
        # page.shadow_info["Dark"] = shadow_settings_saved[page][:Dark]
        # page.shadow_info["DayOfYear"] = shadow_settings_saved[page][:DayOfYear]
        # page.shadow_info["DaylightSavings"] = shadow_settings_saved[page][:DaylightSavings]
        # page.shadow_info["DisplayNorth"] = shadow_settings_saved[page][:DisplayNorth]
        # page.shadow_info["DisplayOnAllFaces"] = shadow_settings_saved[page][:DisplayOnAllFaces]
        # page.shadow_info["DisplayOnGroundPlane"] = shadow_settings_saved[page][:DisplayOnGroundPlane]
        # page.shadow_info["DisplayShadows"] = shadow_settings_saved[page][:DisplayShadows]
        # page.shadow_info["EdgesCastShadows"] = shadow_settings_saved[page][:EdgesCastShadows]
        # page.shadow_info["Latitude"] = shadow_settings_saved[page][:Latitude]
        # page.shadow_info["Light"] = shadow_settings_saved[page][:Light]
        # page.shadow_info["Longitude"] = shadow_settings_saved[page][:Longitude]
        # page.shadow_info["North"] = shadow_settings_saved[page][:North]
        # page.shadow_info["ShadowTime"] = shadow_settings_saved[page][:ShadowTime]
        # page.shadow_info["TZOffset"] = shadow_settings_saved[page][:TZOffset]
        # page.shadow_info["UseSunForAllShading"] = shadow_settings_saved[page][:UseSunForAllShading]
      end

      @model.commit
      @model.observer_active = observers
    end

    def load_rear_view_definitions
      @used_definitions = []

      Skalp.active_model.skpModel.pages.each do |page|
        load_rear_view_definition(page)
      end
      load_rear_view_definition
    end

    def load_rear_view_definition(page = @skpModel)
      sectiongroup = get_sectiongroup(page)

      if sectiongroup && sectiongroup.entities
        sectiongroup.entities.grep(Sketchup::ComponentInstance).each do |rear_view_instance|
          next if @used_definitions.include?(rear_view_instance.definition)
          @rear_view_definitions[page] = rear_view_instance.definition
          @used_definitions << rear_view_instance.definition

          attrib_data = rear_view_instance.definition.get_attribute('Skalp', 'rear_view_lines')

          if attrib_data && attrib_data != ""
            begin
              lines = eval(attrib_data)
            rescue SyntaxError => e
              lines = nil
            end

            if lines && lines.class == Hash
              polylines_by_layer = {}
              lines.each do |layer, lines|
                next unless lines
                next unless lines.class == Hash
                polylines = PolyLines.new
                polylines.fill_from_layout(lines)
                su_layer = Skalp.active_model.skpModel.layers[layer]
                polylines_by_layer[su_layer] = polylines if su_layer
              end
              @rear_lines_result[page] = polylines_by_layer
            else
              rear_view_instance.definition.set_attribute('Skalp', 'rear_view_lines', '')
            end
          end

          if @rear_view_definitions[page] && @rear_lines_result[page]
            @calculated[page] = @uptodate[page] = Skalp.active_model.get_memory_attribute(page, 'Skalp', 'sectionplaneID')
          end
        end
      end
    end

    def delete_rear_view_instances
      return unless @rear_view_definitions

      @rear_view_definitions.each_value do |definition|
        next unless definition && definition.valid?
        definition.instances.each do |instance|
          instance.erase! if instance.valid?
        end
      end
    end

    def delete_rear_view_instance(page = @skpModel)
      @rear_view_definitions[page].instances.each do |instance|
        instance.erase!
      end
    end

    def get_sectiongroup(page = @skpModel)
      if page.class == Sketchup::Page
        page_id = @model.get_memory_attribute(page, 'Skalp', 'ID')
        return nil unless page_id
      else
        page_id = 'skalp_live_sectiongroup'
      end

      if Skalp.active_model.section_result_group
        Skalp.active_model.section_result_group.entities.each do |section_group|
          next unless section_group.is_a?(Sketchup::Group) || section_group.is_a?(Sketchup::ComponentInstance)
          return section_group if section_group.get_attribute('Skalp', 'ID') == page_id
        end
      end

      return nil
    end

    def add_lines_to_component(rear_view_definition, lines)
      return unless lines
      return if rear_view_definition.deleted?

      rear_view_lines = {}
      lines.each do |layer, polylines|
        rear_view_lines[layer.name] = polylines.lines
      end

      rear_view_definition.set_attribute('Skalp', 'rear_view_lines', rear_view_lines.inspect)
      export_to_sketchup(rear_view_definition, @linestyle, lines)
    end

    def export_to_sketchup(rear_view_definition, linestyle, hiddenlines_by_layer)

      Skalp.active_model.start('Skalp - add rearview lines to model') if Skalp.active_model #wordt soms getest buiten Skalp om.

      if Sketchup.read_default('Skalp', 'linestyles') != 'Skalp'
        component_entities = rear_view_definition.entities
        component_entities.clear!

        linestyle_group = component_entities.add_group
        layer = Skalp::create_linestyle_layer(linestyle)
        linestyle_group.layer = layer

        hiddenlines_by_layer.each do |layer, lines|
          rearviewlayer = Skalp::create_rearview_layer(layer.name)
          lines.all_curves.each do |curve|
            lines = linestyle_group.entities.add_curve(curve)
            if lines
              lines.each do |e|
                e.layer = rearviewlayer
              end
            end
          end
        end
      else
        mesh = Skalp::DashedMesh.new(rear_view_definition)

        hiddenlines_by_layer.each_value do |lines|
          mesh.dashing_overflow_protection(lines.total_line_length)
          lines.each { |polyline| polyline.make_dashes(mesh) }
        end

        mesh.add_mesh
      end
      Skalp.active_model.commit if Skalp.active_model
    end

    def remove_not_valid_pages_from_hash(page_hash)
      page_hash.delete_if{|page, hiddenlines_by_layer| page == nil || !page.valid? || has_polylines?(hiddenlines_by_layer)}
    end

    def has_polylines?(hiddenlines_by_layer)
      return false unless hiddenlines_by_layer
      hiddenlines_by_layer.each_value {|hiddenline| return false if !hiddenline || !hiddenline.deleted? }
      true
    end

    def get_lines(scenes = :active, reversed = false, save_temp = true)
      pages_info = get_pages_info(scenes, reversed)

      block_observer_status = Skalp.block_observers

      if save_temp
        Skalp.block_observers = true
        if Skalp.active_model.skpModel.path != ''
          save_temp_model
          Skalp.block_observers = block_observer_status
        else
          UI.messagebox(Skalp.translate('Your model needs to be saved first.'))
          Skalp.block_observers = block_observer_status
          return {}
        end
      end

      rear_view = 1.0

      if reversed
        result = reverse_scenes

        if result
          rear_view = -1.0

          start_time = Time.now
          while !File.exist?(@temp_model_reversed)
            sleep 0.1
            break if Time.now - start_time > 30.0
          end

          temp_model = @temp_model_reversed
        else
          #no reversed scenes
          return {}
        end

      else
        temp_model = @temp_model
      end

      result = Skalp.get_exploded_entities(temp_model, @height, page_info_to_array(pages_info, :index),
                                           page_info_to_array(pages_info, :scale), page_info_to_array(pages_info, :perspective),
                                           page_info_to_array(pages_info, :target), rear_view)

      target2d_array = page_info_to_array(pages_info, :target2d)

      if reversed
        all_polylines = @rear_lines_result
      else
        all_polylines = @forward_lines_result
      end

      remove_not_valid_pages_from_hash(all_polylines)

      result.each do |scene|
        lo_target_point = Geom::Point3d.new(scene.target[0], scene.target[1], 0.0)
        t = Geom::Transformation.translation(target2d_array.shift - lo_target_point)
        lines = {}
        scene.lines.each_key do |layer|
          scene.lines[layer].each do |line|
            transformed_line = []
            line.each do |point|
              transformed_point = (t * Geom::Point3d.new(point[0], point[1], 0.0)).to_a[0..1]
              transformed_point[2] = -1.0 * Skalp.tolerance
              transformed_line << transformed_point
            end
            lines[layer]=[] unless lines[layer]
            lines[layer] << transformed_line
          end
        end

        polylines_by_layer = {}
        lines.each do |layer, lines|
          next unless lines
          polylines = PolyLines.new
          polylines.fill_from_layout(lines)
          polylines_by_layer[layer] = polylines
        end

        page = scene.page

        if scenes == :active
          all_polylines[page] = polylines_by_layer
          @calculated[page] = @uptodate[page] = Skalp.active_model.get_memory_attribute(Skalp.active_model.skpModel, 'Skalp', 'active_sectionplane_ID')

          selected_page = Skalp.active_model.skpModel.pages.selected_page
          if Skalp.active_model.pages[selected_page] && Skalp.active_model.pages[selected_page].sectionplane.skpSectionPlane == Skalp.active_model.skpModel.entities.active_section_plane
            all_polylines[selected_page] = polylines_by_layer
            @calculated[selected_page] = @uptodate[selected_page] = Skalp.active_model.get_memory_attribute(Skalp.active_model.skpModel, 'Skalp', 'active_sectionplane_ID')
          end
        else
          all_polylines[page] = polylines_by_layer
          @calculated[page] = @uptodate[page] = Skalp.active_model.get_memory_attribute(page, 'Skalp', 'sectionplaneID')
        end
      end

      return all_polylines
    end

    def reverse_scenes
      pages_info = []
      if Skalp.dialog.rearview_status
        info = get_reverse_scene_info('active_view')
        pages_info << info if info
      end

      @skpModel.pages.each do |page|
        info = get_reverse_scene_info(page.name)
        pages_info << info if info
      end

      return false if pages_info == []

      modelbounds = @skpModel.bounds.diagonal.to_f
      Skalp.setup_reversed_scene(@temp_model, @temp_model_reversed, page_info_to_array(pages_info, :index), page_info_to_array(pages_info, :reversed_eye),
                                 page_info_to_array(pages_info, :reversed_target), page_info_to_array(pages_info, :transformation),
                                 page_info_to_array(pages_info, :group_id), page_info_to_array(pages_info, :up_vector), modelbounds)
      return true
    end

    def get_reverse_scene_info(page_name)
      #TODO no camera stored in page
      if page_name != 'active_view'
        page = Skalp.active_model.skpModel.pages[page_name]
        page_id = @model.get_memory_attribute(page, 'Skalp', 'ID')
        sectionplaneID = @model.get_memory_attribute(page, 'Skalp', 'sectionplaneID')
        camera = page.camera
        index = Skalp.page_index(page)
      else
        page_id = 'skalp_live_sectiongroup'
        sectionplaneID = @model.get_memory_attribute(Skalp.active_model.skpModel, 'Skalp', 'active_sectionplane_ID')
        camera = Skalp.active_model.skpModel.active_view.camera
        index = -1
      end

      return nil if sectionplaneID == nil || sectionplaneID == ''
      sectionplane = @model.sectionplane_by_id(sectionplaneID)
      plane = sectionplane.skpSectionPlane.get_plane

      vector = Geom::Vector3d.new(plane[0], plane[1], plane[2])
      vector.length = -2 * Skalp.tolerance
      new_trans = Geom::Transformation.translation(vector)

      center = Skalp.active_model.skpModel.bounds.center
      center2 = new_trans * center

      centerline = [center, center2]
      new_target = Geom.intersect_line_plane(centerline, plane)
      dist = new_target.distance(camera.eye)
      eye_vector = vector.reverse
      eye_vector.length = dist
      new_eye = new_target.offset(eye_vector)

      up_vector = Skalp.get_up_vector(plane)

      params = {}
      params[:index] = index
      params[:reversed_eye] = new_eye.to_a
      params[:reversed_target] = new_target.to_a

      if Skalp.get_section_group(page_id)
        params[:transformation] = (new_trans * Skalp.get_section_group(page_id).transformation).to_a
      else
        params[:transformation] = new_trans.to_a
      end

      params[:group_id] = page_id
      params[:up_vector] = up_vector.to_a

      return params
    end

    def page_info_to_array(params, type)
      type_array = []
      return type_array unless params
      params.each do |param|
        type_array << param[type]
      end
      type_array
    end

    def get_pages_info(scenes = :active, reversed = false)
      info = []

      if scenes == :active
        info = collect_page_info(-1, info, Skalp.active_model.skpModel, reversed)
      elsif scenes == :all
        info = collect_page_info(-1, info, Skalp.active_model.skpModel, reversed)

        index = 0
        Skalp.active_model.skpModel.pages.each do |page|
          info = collect_page_info(index, info, page, reversed)
          index += 1
        end
      elsif scenes == :selected
        pages = Skalp.export_scene_list

        pages.each do |page|
          info = collect_page_info(Skalp.page_index(page), info, page, reversed)
        end
      elsif scenes.class == Array
        scenes.each do |index|
          info = collect_page_info(index, info, Skalp.active_model.skpModel.pages[index], reversed)
        end
      end

      @pages_info_result = info unless reversed
      return info
    end

    def collect_page_info(index, info, page, reversed)
      result = get_page_info(index)
      if reversed
        result[:perspective] = false
        info << result if result[:sectionplane] && Skalp.dialog.rearview_status(page)
      else
        info << result
      end
      return info
    end

    def get_page_info(page_index)
      params = {}

      if page_index == -1
        sectionplaneID = @model.get_memory_attribute(@skpModel, 'Skalp', 'active_sectionplane_ID')
        if sectionplaneID != nil && sectionplaneID != ''
          sectionplane = @model.sectionplane_by_id(sectionplaneID)
          plane = sectionplane.skpSectionPlane.get_plane
        end
        camera = @skpModel.active_view.camera
      else
        page = @skpModel.pages[page_index]
        sectionplaneID = @model.get_memory_attribute(page, 'Skalp', 'sectionplaneID')
        if sectionplaneID != nil && sectionplaneID != ''
          sectionplane = @model.sectionplane_by_id(sectionplaneID)
          plane = sectionplane.skpSectionPlane.get_plane
        end
        camera = page.camera
      end

      v1 = camera.target - camera.eye

      if plane
        v2 = Geom::Vector3d.new(plane[0], plane[1], plane[2])
        if !v1.parallel?(v2)
          params[:parallel] = false
        else
          params[:parallel] = true
        end
      else
        params[:parallel] = false
      end

      if camera.aspect_ratio == 0.0
        vpheight = Skalp.active_model.skpModel.active_view.vpheight.to_f
        vpwidth = Skalp.active_model.skpModel.active_view.vpwidth.to_f
        aspect_ratio = vpwidth/vpheight
      else
        aspect_ratio = camera.aspect_ratio
      end

      @height = 200.0 / aspect_ratio
      camera.perspective? ? fov = ((camera.fov / 2.0) * Math::PI / 180.0) : fov = 0.0

      if plane && sectionplane
        target = Geom.intersect_line_plane([camera.eye, camera.target], plane)
        if target
          target2D = sectionplane.transformation * target
        else
          target = camera.target
        end
      else
        target = camera.target
      end

      distance = camera.eye.distance(target).to_f
      scale = (@height / (Math.sin(fov)/Math.cos(fov) * distance * 2.0))

      plane ? params[:sectionplane] = true : params[:sectionplane] = false
      params[:index] = page_index
      target2D ? params[:target2d] = target2D : params[:target2d] = target
      params[:scale] = scale
      params[:perspective] = camera.perspective?
      params[:target] = target.to_a

      return params
    end
  end
end