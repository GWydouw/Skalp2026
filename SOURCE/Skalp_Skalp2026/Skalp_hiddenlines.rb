module Skalp
  class Hiddenlines_data
    attr_accessor :page, :target, :lines

    def initialize(index)
      @page = index.to_i == -1 ? Skalp.active_model.skpModel : Skalp.active_model.skpModel.pages[index.to_i]
      @target = []
      @lines = {}
    end

    def add_line(line, layer)
      @lines[layer] = [] unless @lines[layer]
      @lines[layer] << line
    end
  end

  class Hiddenlines
    attr_reader :forward_lines_result, :rear_lines_result, :pages_info_result
    attr_accessor :rear_view_instances, :rear_view_definitions, :uptodate, :calculated, :linestyle,
                  :hiddenline_layer_setup

    R_MASK  = 0b111111110000000000000000 unless defined? R_MASK
    G_MASK  = 0b000000001111111100000000 unless defined? G_MASK
    B_MASK  = 0b000000000000000011111111 unless defined? B_MASK

    unless defined?(Skalp::Hiddenlines::Hiddenline_layers)
      Hiddenline_layers = Struct.new(:layer, :name, :original_color, :index_color)
    end
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
      @used_definitions = []
      load_rear_view_definition

      @temp_model = File.join(ENV["TMPDIR"] || "/tmp", "skalp_temp.skp")
      @temp_model_reversed = File.join(ENV["TMPDIR"] || "/tmp", "skalp_temp_reversed.skp")
    end

    def get_hiddenline_properties(rgb)
      r = rgb[1..rgb.index("G") - 1].to_i
      g = rgb[rgb.index("G") + 1..rgb.index("B") - 1].to_i
      b = rgb[rgb.index("B") + 1..-1].to_i

      color = Sketchup::Color.new(r, g, b)
      layer_setup = get_layer_setup_by_color(color)

      if layer_setup
        layer_setup.layer
      else
        Skalp.active_model.skpModel.layers["Layer0"]
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
        next if layer.get_attribute("Skalp", "ID")

        layer_setup = Hiddenline_layers.new
        layer_setup.layer = layer
        layer_setup.name = layer.name
        layer_setup.original_color = layer.color
        r, g, b = uniquecolor_to_rgb
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
      r = 114 if r == 113
      g = 114 if g == 113
      b = 114 if b == 113

      [r, g, b]
    end

    def restore_layers
      return unless @hiddenline_layer_setup

      Skalp.active_model.skpModel.layers.each do |layer|
        next if layer.get_attribute("Skalp", "ID")
        next unless @hiddenline_layer_setup[layer]

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
      @uptodate.delete_if { |k, v| v == id }
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

    def update_rear_lines(scenes = :active, save_temp = true, progress_weight = 1.0, prep_weight = 0.0)
      # Show progress dialog if updating all scenes and not already showing one
      # Show progress dialog if not already showing one
      if Skalp.progress_dialog.nil?
        count = scenes == :all ? @skpModel.pages.size : 1
        Skalp::ProgressDialog.show(Skalp.translate("Update Rearlines"), count) do |progress|
          @rear_lines_result = get_lines(scenes, true, save_temp, progress_weight, prep_weight)
        end
      else
        @rear_lines_result = get_lines(scenes, true, save_temp, progress_weight, prep_weight)
      end
      @model.model_changes = false if @rear_lines_result != {}
    end

    def set_active_page_hiddenlines_to_model_hiddenlines
      selected = Skalp.active_model.skpModel.pages.selected_page
      return unless selected

      @rear_lines_result[@skpModel] = @rear_lines_result[selected]
      @rear_view_definitions[@skpModel] = @rear_view_definitions[selected]
      @forward_lines_result[@skpModel] = @forward_lines_result[selected]
      @calculated[@skpModel] = @calculated[selected]
      @uptodate[@skpModel] = @uptodate[selected]
    end

    def add_rear_lines_to_model(scenes = :active)
      observer_status = @model.observer_active
      @model.observer_active = false
      @model.start("Skalp - add rear view lines", true)

      if scenes == :active
        page = @skpModel.pages && @skpModel.pages.selected_page ? @skpModel.pages.selected_page : @skpModel
        add_lines_to_page(page, true)
      elsif scenes == :all
        @skpModel.pages.each do |page|
          add_lines_to_page(page)
        end
        add_lines_to_page(@skpModel)
      end

      @model.commit
      @model.observer_active = observer_status
    end

    def update_scale
      selected = Skalp.active_model.skpModel.pages.selected_page

      if @rear_view_definitions[selected] && Skalp.dialog.rearview_status(selected)
        add_lines_to_component(@rear_view_definitions[selected],
                               @rear_lines_result[selected])
      end
      return unless @rear_view_definitions[@skpModel] && Skalp.dialog.rearview_status

      add_lines_to_component(@rear_view_definitions[@skpModel],
                             @rear_lines_result[@skpModel])
    end

    def add_lines_to_page(page = @skpModel, copy_to_active_view = false)
      # puts "[DEBUG] add_lines_to_page for: #{page.is_a?(Sketchup::Page) ? page.name : 'Model'}"
      style_settings = Skalp.dialog.style_settings(page) # Better than direct memory access for inheritance
      rv_status = Skalp.dialog.rearview_status(page)
      # puts "[DEBUG] rv_status: #{rv_status}"
      has_lines = @rear_lines_result && @rear_lines_result[page]
      # puts "[DEBUG] has_lines: #{has_lines ? 'YES' : 'NO'}"

      if style_settings.class == Hash
        @linestyle = style_settings[:rearview_linestyle]
        if @linestyle.nil? || @linestyle == ""
          @linestyle = "Dash"
          style_settings[:rearview_linestyle] = "Dash"
        end
      else
        @linestyle = "Dash"
      end

      # We must call this to ensure existing rearview instances are cleared if status is OFF
      add_rear_view_to_sectiongroup(nil, page) # nil definition forces clear

      return unless @rear_lines_result && @rear_lines_result[page]
      return unless Skalp.dialog.rearview_status(page)

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

        rear_view_definition.set_attribute("dynamic_attributes", "_hideinbrowser", true)
        UI.refresh_inspectors

        @rear_view_definitions[page] = rear_view_definition
        rear_view_definition.set_attribute("Skalp", "type", "rear_view")
      end

      add_lines_to_component(rear_view_definition, @rear_lines_result[page])
      add_rear_view_to_sectiongroup(rear_view_definition, page)

      return unless copy_to_active_view

      add_rear_view_to_sectiongroup(rear_view_definition)
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

    # NOTE: These methods were made public to allow external calls from Skalp_section.rb

    def create_sectiongroup_for_rearview(page)
      return unless page.valid? && Skalp.active_model.pages[page] && Skalp.active_model.pages[page].sectionplane

      transformation = Skalp.transformation_down * Skalp.active_model.pages[page].sectionplane.transformation.inverse
      sectiongroup = @model.active_sectionplane.section.create_sectiongroup(page)
      sectiongroup.transform!(transformation)
    end

    def add_rear_view_to_sectiongroup(rear_view_definition, page = @skpModel)
      return unless @model.active_sectionplane

      sectiongroup = get_sectiongroup(page)

      # If no definition is provided, we are just clearing
      if rear_view_definition.nil?
        remove_rear_view_instances(sectiongroup) if sectiongroup
        return
      end

      sectiongroup ||= create_sectiongroup_for_rearview(page)

      return unless sectiongroup && sectiongroup.valid?

      check_rear = if page
                     Skalp.dialog.rearview_status(page)
                   else
                     Skalp.dialog.rearview_status
                   end

      # Always clear existing rearview instances first to handle visibility changes correctly
      remove_rear_view_instances(sectiongroup)

      return unless check_rear

      rear_view = sectiongroup.entities.add_instance(rear_view_definition, Geom::Transformation.new)
      rear_view.name = "Skalp - #{Skalp.translate('rear view')}"
      rear_view.set_attribute("Skalp", "type", "rear_view")
    end

    private

    def remove_rear_view_instances(sectiongroup)
      sectiongroup.entities.grep(Sketchup::ComponentInstance).each do |instance|
        if instance.valid? && (instance.get_attribute("Skalp",
                                                      "type") == "rear_view" || instance.name =~ /^Skalp - .*rear view/i)
          instance.erase!
        end
      end
    end

    def save_temp_model(prep_weight = 1.0)
      observers = @model.observer_active
      @model.observer_active = false
      # Skalp.force_commit_all # Ensure we start clean - REMOVED to avoid breaking undo stack unnecessarily

      # puts "[DEBUG] Skalp save_temp_model starting for #{@skpModel.pages.size + 1} pages"

      # Start operation to wrap all temp changes
      @skpModel.start_operation("Skalp - save temp model", true)

      begin
        t_start_setup = Time.now
        delete_rear_view_instances
        setup_layers
        Skalp.record_timing("save_temp_model_setup", Time.now - t_start_setup)

        # Removed Ruby-side Style Overrides (now handled in C++)
        # prepare_page_for_temp_save removed.

        # Helper to apply the full set of required hidesline overrides
        def apply_hiddenline_overrides(ro)
          ro["EdgeDisplayMode"] = true
          ro["DrawSilhouettes"] = true
          ro["DrawDepthQue"] = false
          ro["DrawLineEnds"] = false
          ro["JitterEdges"] = false
          ro["ExtendLines"] = false
          ro["SilhouetteWidth"] = 5
          ro["DepthQueWidth"] = 1
          ro["LineExtension"] = 1
          ro["LineEndWidth"] = 1
          ro["DisplayText"] = false
          ro["SectionCutWidth"] = 10
          ro["RenderMode"] = 1 # Hidden Line
          ro["Texture"] = true
          ro["DisplayColorByLayer"] = true
          ro["EdgeColorMode"] = 0
          ro["DrawBackEdges"] = false
        end

        # Prepare pages (styles, section planes, layers)
        t_start_loop = Time.now

        # 0. Capture original state for manual restoration
        original_root_style = @skpModel.styles.selected_style
        original_model_rendering_options = Skalp.rendering_options_to_hash

        unique_styles = ([original_root_style] + @skpModel.pages.map(&:style)).uniq.compact
        style_original_settings = {}

        # Snapshot Active View context (Camera & Section Plane)
        original_camera = {
          eye: @skpModel.active_view.camera.eye,
          target: @skpModel.active_view.camera.target,
          up: @skpModel.active_view.camera.up,
          height: (@skpModel.active_view.camera.perspective? ? nil : @skpModel.active_view.camera.height),
          perspective: @skpModel.active_view.camera.perspective?
        }
        original_active_section_plane = @skpModel.entities.active_section_plane

        # 1. Modify existing styles directly
        unique_styles.each do |style|
          # Capture
          @skpModel.styles.selected_style = style
          style_original_settings[style] = Skalp.rendering_options_to_hash

          # Apply Overrides to ACTIVE rendering options (which are now linked to this style)
          apply_hiddenline_overrides(@skpModel.rendering_options)

          # Bake the changes into the style
          @skpModel.styles.update_selected_style
        end

        # 2. Configure Model state (for Active View)
        # First ensure we are back on the root style
        @skpModel.styles.selected_style = original_root_style

        # Restore Camera orientation and context
        cam = @skpModel.active_view.camera
        cam.set(original_camera[:eye], original_camera[:target], original_camera[:up])
        cam.perspective = original_camera[:perspective]
        cam.height = original_camera[:height] if original_camera[:height]

        # Restore Active Section Plane
        @skpModel.entities.active_section_plane = if original_active_section_plane && original_active_section_plane.valid?
                                                    original_active_section_plane
                                                  else
                                                    nil
                                                  end

        # Apply ALL overrides directly to the model's active state
        apply_hiddenline_overrides(@skpModel.rendering_options)

        # 3. Ensure all pages have section planes active
        @skpModel.pages.each { |page| page.use_section_planes = true }

        Skalp.record_timing("save_temp_model_setup", Time.now - t_start_loop)

        # puts "[DEBUG] Deleting old temp files..."
        # File.delete(@temp_model) if File.exist?(@temp_model)
        # File.delete(@temp_model_reversed) if File.exist?(@temp_model_reversed)

        # puts "[DEBUG] Saving model copy to: #{@temp_model}"
        t_start_save = Time.now
        @skpModel.save_copy(@temp_model)
        Skalp.record_timing("save_temp_model_save_copy", Time.now - t_start_save)
        # puts "[DEBUG] Save copy complete."

        # puts "[DEBUG] Skalp save_temp_model finished successfully."
      rescue StandardError => e
        puts "[ERROR] Skalp hiddenlines save_temp_model failed: #{e.message}"
        puts e.backtrace.join("\n")
      ensure
        # Manual Restoration
        # puts "[DEBUG] Restoring original model state..."

        # 1. Restore each style's settings
        if style_original_settings
          style_original_settings.each do |style, settings|
            next unless style.valid?

            @skpModel.styles.selected_style = style
            Skalp.hash_to_rendering_options(settings)
            @skpModel.styles.update_selected_style
          end
        end
        # 2. Restore model root state
        @skpModel.styles.selected_style = original_root_style
        Skalp.hash_to_rendering_options(original_model_rendering_options)

        # 3. Restore Active View Camera & Section Plane
        if original_camera
          cam = @skpModel.active_view.camera
          cam.set(original_camera[:eye], original_camera[:target], original_camera[:up])
          cam.perspective = original_camera[:perspective]
          cam.height = original_camera[:height] if original_camera[:height]
        end
        @skpModel.entities.active_section_plane = if original_active_section_plane && original_active_section_plane.valid?
                                                    original_active_section_plane
                                                  else
                                                    nil
                                                  end

        # puts "[DEBUG] Aborting operation to restore original state..."
        @skpModel.abort_operation
        @model.observer_active = observers
      end
    end

    # Removed apply_style_overrides and prepare_page_for_temp_save
    # Logic moved to C++ application (setup_reversed_scene.cpp)

    def load_rear_view_definition(page = @skpModel)
      page_name = page.is_a?(Sketchup::Page) ? page.name : "Model"
      sectiongroup = get_sectiongroup(page)

      if defined?(DEBUG) && DEBUG
        # puts "[DEBUG] load_rear_view_definition for page: #{page_name}"
        active_scene_name = Sketchup.active_model.pages.selected_page ? Sketchup.active_model.pages.selected_page.name : "Model"
      end

      return unless sectiongroup && sectiongroup.entities

      if defined?(DEBUG) && DEBUG
        component_count = sectiongroup.entities.grep(Sketchup::ComponentInstance).count
        puts "        component instances in sectiongroup: #{component_count}"
      end

      sectiongroup.entities.grep(Sketchup::ComponentInstance).each do |rear_view_instance|
        if defined?(DEBUG) && DEBUG
          type_attrib = rear_view_instance.get_attribute("Skalp", "type")
          puts "        checking component: '#{rear_view_instance.name}' (type=#{type_attrib})"
          puts "        definition name: '#{rear_view_instance.definition.name}'"
        end

        # Use Skalp type attribute or fallback to name for identification
        # Check both instance name AND definition name since instance name may be empty
        is_rearview = rear_view_instance.get_attribute("Skalp", "type") == "rear_view" ||
                      rear_view_instance.name =~ /^Skalp - .*rear view/i ||
                      rear_view_instance.definition.name =~ /^Skalp - .*rear view/i ||
                      rear_view_instance.definition.name =~ /^Skalp - rear view/i
        next unless is_rearview

        if defined?(DEBUG) && DEBUG
          puts "        FOUND rearview component: #{rear_view_instance.name}"
          puts "        definition: #{rear_view_instance.definition.name}"
          already_used = @used_definitions.include?(rear_view_instance.definition)
          puts "        definition already used: #{already_used}"
        end

        # NOTE: We still track used definitions to avoid duplicates, but we
        # associate the definition with THIS page regardless
        # (previously: next if @used_definitions.include?(rear_view_instance.definition))
        # This was causing pages to not have their rearview definition loaded if
        # another page already used the same definition.

        @rear_view_definitions[page] = rear_view_instance.definition
        unless @used_definitions.include?(rear_view_instance.definition)
          @used_definitions << rear_view_instance.definition
        end

        # Initialize uptodate at load time so UI status is correct
        sectionplaneID = @model.get_memory_attribute(page, "Skalp", "sectionplaneID")
        @uptodate[page] = sectionplaneID if sectionplaneID && sectionplaneID != ""

        # puts "        ✓ Loaded rear_view_definition for page: #{page_name}" if defined?(DEBUG) && DEBUG

        attrib_data = rear_view_instance.definition.get_attribute("Skalp", "rear_view_lines")

        if attrib_data && attrib_data != ""
          begin
            lines = eval(attrib_data)
          rescue SyntaxError => e
            lines = nil
          end

          if lines && lines.class == Hash
            polylines_by_layer = {}
            lines.each do |layer_name, line_data|
              next unless line_data

              polylines = PolyLines.new
              polylines.fill_from_layout(line_data)
              su_layer = Skalp.active_model.skpModel.layers[layer_name]
              polylines_by_layer[su_layer] = polylines if su_layer
            end

            @rear_lines_result[page] = polylines_by_layer

            # Sync up-to-date status
            sectionplaneID = if page == @skpModel
                               @model.get_memory_attribute(@skpModel, "Skalp", "active_sectionplane_ID")
                             else
                               @model.get_memory_attribute(page, "Skalp", "sectionplaneID")
                             end

            @calculated[page] = @uptodate[page] = sectionplaneID if sectionplaneID && sectionplaneID != ""
          end
        # @rear_lines_result[page] = polylines_by_layer
        else
          rear_view_instance.definition.set_attribute("Skalp", "rear_view_lines", "")
        end
      end

      return unless @rear_view_definitions[page] && @rear_lines_result[page]

      @calculated[page] =
        @uptodate[page] = Skalp.active_model.get_memory_attribute(page, "Skalp", "sectionplaneID")
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
        page_id = @model.get_memory_attribute(page, "Skalp", "ID")
        return nil unless page_id
      else
        page_id = "skalp_live_sectiongroup"
      end

      if Skalp.active_model.section_result_group
        Skalp.active_model.section_result_group.entities.each do |section_group|
          next unless section_group.is_a?(Sketchup::Group) || section_group.is_a?(Sketchup::ComponentInstance)
          return section_group if section_group.get_attribute("Skalp", "ID") == page_id
        end
      end

      nil
    end

    def add_lines_to_component(rear_view_definition, lines)
      return unless lines
      return if rear_view_definition.deleted?

      rear_view_lines = {}
      lines.each do |layer, polylines|
        rear_view_lines[layer.name] = polylines.lines
      end

      rear_view_definition.set_attribute("Skalp", "rear_view_lines", rear_view_lines.inspect)
      export_to_sketchup(rear_view_definition, @linestyle, lines)
    end

    def export_to_sketchup(rear_view_definition, linestyle, hiddenlines_by_layer)
      # wordt soms getest buiten Skalp om.
      Skalp.active_model.start("Skalp - add rearview lines to model") if Skalp.active_model

      if Sketchup.read_default("Skalp", "linestyles") == "Skalp"
        mesh = Skalp::DashedMesh.new(rear_view_definition)

        hiddenlines_by_layer.each_value do |lines|
          mesh.dashing_overflow_protection(lines.total_line_length)
          lines.each { |polyline| polyline.make_dashes(mesh) }
        end

        mesh.add_mesh
      else
        component_entities = rear_view_definition.entities
        component_entities.clear!

        linestyle_group = component_entities.add_group
        layer = Skalp.create_linestyle_layer(linestyle)
        linestyle_group.layer = layer

        hiddenlines_by_layer.each do |layer, lines|
          rearviewlayer = Skalp.create_rearview_layer(layer.name)
          lines.all_curves.each do |curve|
            lines = linestyle_group.entities.add_curve(curve)
            next unless lines

            lines.each do |e|
              e.layer = rearviewlayer
            end
          end
        end
      end
      Skalp.active_model.commit if Skalp.active_model
    end

    def remove_not_valid_pages_from_hash(page_hash)
      page_hash.delete_if do |page, hiddenlines_by_layer|
        page.nil? || !page.valid? || has_polylines?(hiddenlines_by_layer)
      end
    end

    def has_polylines?(hiddenlines_by_layer)
      return false unless hiddenlines_by_layer

      hiddenlines_by_layer.each_value { |hiddenline| return false if !hiddenline || !hiddenline.deleted? }
      true
    end

    def get_lines(scenes = :active, reversed = false, save_temp = true, progress_weight = 1.0, prep_weight = 0.0)
      pages_info = get_pages_info(scenes, reversed)

      block_observer_status = Skalp.block_observers

      if save_temp
        Skalp.block_observers = true
        if Skalp.active_model.skpModel.path == ""
          UI.messagebox(Skalp.translate("Your model needs to be saved first."))
          Skalp.block_observers = block_observer_status
          return {}
        else
          save_temp_model(prep_weight)

          # Force UI refresh to clear "thick lines" before potentially long wait
          # The view might be stuck in "thick" state if the operation commit didn't trigger a repaint
          # Force UI refresh to clear "thick lines" before potentially long wait
          # The view might be stuck in "thick" state if the operation commit didn't trigger a repaint
          Sketchup.active_model.active_view.invalidate
          # Also try to refresh inspectors which can force a redraw
          UI.refresh_inspectors
          # Give the UI thread a moment to actually repaint before we block it again
          sleep 0.2

          Skalp.block_observers = block_observer_status
        end
      end

      rear_view = 1.0

      if reversed
        # puts "[DEBUG] REVERSED MODE ACTIVE"
        result = reverse_scenes(scenes, prep_weight)

        return {} unless result

        rear_view = -1.0

        start_time = Time.now

        until File.exist?(@temp_model_reversed)
          sleep 0.1
          break if Time.now - start_time > 30.0
        end
        Skalp.record_timing("get_lines_wait_loop", Time.now - start_time)

        temp_model = @temp_model_reversed

      # no reversed scenes

      else
        temp_model = @temp_model
      end

      # Jump offset forward for C-App
      Skalp.progress_dialog.offset += prep_weight if Skalp.progress_dialog && prep_weight > 0

      scene_names = pages_info.map { |h| h[:page_name] }

      scene_names = pages_info.map { |h| h[:page_name] }

      scene_names = pages_info.map { |h| h[:page_name] }

      # puts ">>> [DEBUG] calling get_exploded_entities"
      # puts "    temp_model: #{temp_model}"
      if File.exist?(temp_model)
        # size = File.size(temp_model)
        # puts "    temp_model size: #{size} bytes"
      else
        # puts "    >>> ERROR: temp_model does not exist!"
      end

      # puts "    pages_info count: #{pages_info.size}"
      # pages_info.each_with_index do |info, i|
      #   puts "    Input #{i}: name='#{info[:page_name]}', index=#{info[:index]}, target=#{info[:target]}, eye=#{info[:eye]}"
      #   puts "             scale=#{info[:scale]}, perspective=#{info[:perspective]}"
      #   puts "             up=#{info[:up_vector] || 'NIL'}"
      # end

      t_start_c_app = Time.now
      result = Skalp.get_exploded_entities(temp_model, @height, page_info_to_array(pages_info, :index),
                                           page_info_to_array(pages_info, :scale), page_info_to_array(pages_info, :perspective),
                                           page_info_to_array(pages_info, :target), rear_view, progress_weight, scene_names)
      Skalp.record_timing("get_exploded_entities_c_ext", Time.now - t_start_c_app)

      # puts ">>> [DEBUG] get_exploded_entities result count: #{result.size}"
      # result.each_with_index do |scene, i|
      #   puts "  > Scene #{i}: Page=#{scene.page.respond_to?(:name) ? scene.page.name : scene.page}"
      #   puts "    Target: #{scene.target.inspect}"
      #   if scene.lines
      #     puts "    Lines keys: #{scene.lines.keys.inspect}"
      #     scene.lines.each do |layer, lines|
      #       puts "      Layer: #{layer} -> #{lines.size} lines"
      #     end
      #   else
      #     puts "    Lines: NIL"
      #   end
      # end

      target2d_array = page_info_to_array(pages_info, :target2d)

      all_polylines = if reversed
                        @rear_lines_result
                      else
                        @forward_lines_result
                      end

      remove_not_valid_pages_from_hash(all_polylines)

      result.each do |scene|
        next unless scene.target && scene.target.size >= 2 && scene.target[0] && scene.target[1]

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
            lines[layer] = [] unless lines[layer]
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
          active_sectionplane_id = Skalp.active_model.get_memory_attribute(Skalp.active_model.skpModel, "Skalp",
                                                                           "active_sectionplane_ID")
          @calculated[page] = @uptodate[page] = active_sectionplane_id

          selected_page = Skalp.active_model.skpModel.pages.selected_page
          # Only sync polylines if sectionplanes match, but always sync uptodate
          if selected_page
            all_polylines[selected_page] = polylines_by_layer
            @calculated[selected_page] = active_sectionplane_id
            # Always update uptodate for selected_page so UI indicator is correct
            @uptodate[selected_page] = active_sectionplane_id
          end
        else
          all_polylines[page] = polylines_by_layer
          @calculated[page] = @uptodate[page] = Skalp.active_model.get_memory_attribute(page, "Skalp", "sectionplaneID")
        end
      end

      all_polylines
    end

    def reverse_scenes(scenes = :active, prep_weight = 1.0)
      pages_info = get_pages_info(scenes, true)

      if Skalp.progress_dialog
        pages_info.each_with_index do |info, i|
          next unless i.even?

          # Use 40% of the prep weight for reversal
          scaled_i = (prep_weight * 0.4) + ((i.to_f / pages_info.size) * (prep_weight * 0.4))
          Skalp.progress_dialog.update(scaled_i, Skalp.translate("Reversing sections for rear view"),
                                       info[:page_name])
        end
      end

      return false if pages_info == []

      modelbounds = @skpModel.bounds.diagonal.to_f
      t_start_reverse = Time.now
      Skalp.setup_reversed_scene(@temp_model, @temp_model_reversed, page_info_to_array(pages_info, :index), page_info_to_array(pages_info, :reversed_eye),
                                 page_info_to_array(pages_info, :reversed_target), page_info_to_array(pages_info, :transformation),
                                 page_info_to_array(pages_info, :group_id), page_info_to_array(pages_info, :up_vector), page_info_to_array(pages_info, :page_name),
                                 page_info_to_array(pages_info, :sectionplaneID), modelbounds, "")
      Skalp.record_timing("setup_reversed_scene_external", Time.now - t_start_reverse)
      true
    end

    def get_reverse_scene_info(page_name)
      # TODO: no camera stored in page
      if page_name == "active_view"
        page_id = "skalp_live_sectiongroup"
        sectionplaneID = @model.get_memory_attribute(Skalp.active_model.skpModel, "Skalp", "active_sectionplane_ID")
        camera = Skalp.active_model.skpModel.active_view.camera
        index = -1
      else
        page = Skalp.active_model.skpModel.pages[page_name]
        page_id = @model.get_memory_attribute(page, "Skalp", "ID")
        sectionplaneID = @model.get_memory_attribute(page, "Skalp", "sectionplaneID")
        camera = page.camera
        index = Skalp.page_index(page)
      end

      return nil if [nil, ""].include?(sectionplaneID)

      sectionplane = @model.sectionplane_by_id(sectionplaneID)
      plane = sectionplane.skpSectionPlane.get_plane

      vector = Geom::Vector3d.new(plane[0], plane[1], plane[2])
      # Fix for Reversed View:
      # Revert to -2.0 * Skalp.tolerance logic.
      # User reported +2.0 made it disappear.
      vector.length = -2.0 * Skalp.tolerance
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

      params[:transformation] = if Skalp.get_section_group(page_id)
                                  (new_trans * Skalp.get_section_group(page_id).transformation).to_a
                                else
                                  new_trans.to_a
                                end

      params[:group_id] = page_id
      params[:up_vector] = up_vector.to_a
      params[:name] = page_name
      params[:sectionplaneID] = sectionplaneID

      params
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
        index = 0
        Skalp.active_model.skpModel.pages.each do |page|
          info = collect_page_info(index, info, page, reversed)
          index += 1
        end

        info = collect_page_info(-1, info, Skalp.active_model.skpModel, reversed)
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
      info
    end

    def collect_page_info(index, info, page, reversed)
      result = get_page_info(index, reversed)

      result[:page_name] = page.is_a?(Sketchup::Model) ? Skalp.translate("Model") : page.name
      if reversed
        result[:perspective] = false
        info << result if result[:sectionplane] && Skalp.dialog.rearview_status(page)
      else
        info << result
      end
      info
    end

    def get_page_info(page_index, reversed = false)
      params = {}
      @height ||= 200.0 # Fallback

      if page_index == -1
        sectionplaneID = @model.get_memory_attribute(@skpModel, "Skalp", "active_sectionplane_ID")
        if !sectionplaneID.nil? && sectionplaneID != ""
          sectionplane = @model.sectionplane_by_id(sectionplaneID)
          plane = sectionplane.skpSectionPlane.get_plane
        end
        camera = @skpModel.active_view.camera
      else
        page = @skpModel.pages[page_index]
        sectionplaneID = @model.get_memory_attribute(page, "Skalp", "sectionplaneID")
        if !sectionplaneID.nil? && sectionplaneID != ""
          sectionplane = @model.sectionplane_by_id(sectionplaneID)
          plane = sectionplane.skpSectionPlane.get_plane
        end
        camera = page.camera
      end

      # REVERSED CAMERA LOGIC UNIFIED
      if reversed && sectionplaneID && sectionplaneID != ""
        sectionplane = @model.sectionplane_by_id(sectionplaneID)
        plane = sectionplane.skpSectionPlane.get_plane

        vector = Geom::Vector3d.new(plane[0], plane[1], plane[2])
        vector.length = -2 * Skalp.tolerance
        new_trans = Geom::Transformation.translation(vector)

        center = @skpModel.bounds.center
        center2 = new_trans * center

        centerline = [center, center2]
        new_target = Geom.intersect_line_plane(centerline, plane)
        dist = camera.eye.distance(new_target)
        eye_vector = vector.reverse
        eye_vector.length = dist
        new_eye = new_target.offset(eye_vector)

        up_vector = Skalp.get_up_vector(plane)

        # Override camera for reversed calculation
        # Note: We don't modify the camera object itself, we just use these values
        work_eye = new_eye
        work_target = new_target
        work_up = up_vector
        work_perspective = false # Rear views are always ortho

        # For reverse model setup compatibility
        params[:reversed_eye] = new_eye.to_a
        params[:reversed_target] = new_target.to_a
        params[:up_vector] = up_vector.to_a

        page_id = if page_index == -1
                    "skalp_live_sectiongroup"
                  else
                    @model.get_memory_attribute(
                      @skpModel.pages[page_index], "Skalp", "ID"
                    )
                  end
        params[:transformation] = if Skalp.get_section_group(page_id)
                                    (new_trans * Skalp.get_section_group(page_id).transformation).to_a
                                  else
                                    new_trans.to_a
                                  end
        params[:group_id] = page_id
        params[:sectionplaneID] = sectionplaneID
      else
        work_eye = camera.eye
        work_target = camera.target
        work_up = camera.respond_to?(:up) ? camera.up : nil # Optional
        work_perspective = camera.perspective?
      end

      v1 = work_target - work_eye

      if plane
        v2 = Geom::Vector3d.new(plane[0], plane[1], plane[2])
        params[:parallel] = (v1.parallel?(v2) || false)
      else
        params[:parallel] = false
      end

      if camera.aspect_ratio == 0.0
        vpheight = Skalp.active_model.skpModel.active_view.vpheight.to_f
        vpwidth = Skalp.active_model.skpModel.active_view.vpwidth.to_f
        aspect_ratio = vpwidth / vpheight
      else
        aspect_ratio = camera.aspect_ratio
      end

      @height = 1000.0 # Fixed large size to prevent resolution issues and aspect ratio clipping
      fov = camera.perspective? ? ((camera.fov / 2.0) * Math::PI / 180.0) : 0.0

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

      distance = work_eye.distance(target).to_f

      # Calculate view extent (height) based on camera type
      view_height = if work_perspective && fov > 0
                      (Math.sin(fov) / Math.cos(fov) * distance * 2.0)
                    elsif camera.perspective?
                      # If we are in Ortho mode (e.g. Reversed) but original camera was Perspective
                      # We must calculate the equivalent Ortho height from the FOV/Distance
                      (Math.tan((camera.fov / 2.0) * Math::PI / 180.0) * distance * 2.0)
                    else
                      camera.height
                    end

      # Calculate scale to fit the largest dimension into @height
      # This prevents clipping when Aspect Ratio > 1.0 (Wide views)
      # Added 10% safety margin (1.1) to ensure full coverage including edges/lines
      scale = @height / (view_height * 1.1 * [1.0, aspect_ratio].max)

      params[:sectionplane] = plane ? true : false
      params[:index] = page_index
      params[:target2d] = target2D || target
      params[:scale] = scale
      params[:perspective] = work_perspective
      params[:target] = target.to_a
      params[:eye] = work_eye.to_a
      params[:up] = work_up.to_a if work_up

      params
    end
  end
end
