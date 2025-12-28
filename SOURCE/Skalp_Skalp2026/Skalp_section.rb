module Skalp
  class Section
    attr_accessor :sectionplane, :section2Ds, :visibility

    def initialize(sectionplane)
      @sectionplane = sectionplane
      @model = Skalp.active_model
      @skpModel = @model.skpModel
      @section2Ds = []
      @hatchmaterials = []
      @material_list = []
      @layer_list = []
    end

    # Check if section should be auto-saved to page
    # Conditions:
    # 1. Sectionplane matches the one stored in the page
    # 2. Layer visibility matches the page's stored visibility
    # 3. Hidden entities match the page's stored hidden entities
    def should_auto_save?(page)
      return false unless page
      return false unless @model.active_sectionplane

      stored_sectionplane_id = @model.get_memory_attribute(page, "Skalp", "sectionplaneID")
      active_sectionplane_id = @model.get_memory_attribute(@skpModel, "Skalp", "active_sectionplane_ID")

      # Condition 1: Sectionplane must match
      return false unless stored_sectionplane_id == active_sectionplane_id

      # Condition 2 & 3: Visibility must match (layers + hidden entities)
      visibility_matches?(page)
    end

    # Check if current model visibility matches page's stored visibility
    def visibility_matches?(page)
      return false unless page.respond_to?(:layers)

      # Compare layer visibility
      page_visible_layers = page.layers # Array<Layer> or nil (all visible)

      if page_visible_layers.nil?
        # Page stores "all layers visible" - check if current model has all visible
        @skpModel.layers.each do |layer|
          return false unless layer.visible?
        end
      else
        # Check each layer matches stored visibility
        @skpModel.layers.each do |layer|
          page_has_visible = page_visible_layers.include?(layer)
          return false unless layer.visible? == page_has_visible
        end
      end

      # Compare hidden entities
      return true unless page.respond_to?(:hidden_entities)

      page_hidden = Set.new(page.hidden_entities)

      # Get currently hidden top-level entities in model
      model_hidden = Set.new
      @skpModel.entities.each do |entity|
        model_hidden.add(entity) if entity.respond_to?(:hidden?) && entity.hidden?
      end

      page_hidden == model_hidden
    rescue StandardError => e
      puts "[Section] visibility_matches? error: #{e.message}" if defined?(DEBUG) && DEBUG
      false
    end

    # Auto-save section to page if conditions are met
    def auto_save_section_to_page(page)
      return false unless should_auto_save?(page)

      # Skip if page already has a valid sectiongroup with content
      existing = get_existing_sectiongroup(page)
      if existing && existing.valid? && existing.entities.size > 0
        if defined?(DEBUG) && DEBUG
          puts "[Section] Auto-save skipped: page '#{page.name}' already has valid sectiongroup"
        end
        return false
      end

      puts "[Section] Auto-saving section to page: #{page.name}" if defined?(DEBUG) && DEBUG

      # Create/update sectiongroup for this page
      @model.start("Skalp - auto-save section", true)
      sectiongroup = create_sectiongroup(page)
      sectionfaces_to_sectiongroup(sectiongroup)
      manage_sections(page)
      @model.commit

      true
    rescue StandardError => e
      puts "[Section] auto_save_section_to_page error: #{e.message}" if defined?(DEBUG) && DEBUG
      @model.abort if @model
      false
    end

    # Get existing sectiongroup for a page
    def get_existing_sectiongroup(page)
      return nil unless @model.section_result_group

      page_id = @model.get_memory_attribute(page, "Skalp", "ID")
      return nil unless page_id

      @model.section_result_group.entities.grep(Sketchup::Group).find do |group|
        group.get_attribute("Skalp", "ID") == page_id
      end
    end

    def update(page = nil, force_update = true)
      return unless @model

      @page = page
      @visibility = Skalp::Visibility.new
      @visibility.update(@page)

      @force_update = @model.undoredo_action ? true : force_update

      @section2Ds = []
      @hatchmaterials = []
      @material_list = []
      @layer_list = []
      @section_mesh = nil
      @sectiongroup = nil
      @context_sectiongroup = nil
      @representation = :skalpMaterial

      Sketchup.active_model.rendering_options["SectionCutFilled"] = if Skalp.live_section_ON
                                                                      false
                                                                    else
                                                                      true
                                                                    end
      create_section
    end

    def create_section
      return unless Skalp.ready

      Skalp.active_model.section_result_group.hidden = false
      get_section2Ds(Skalp.active_model.tree.root)

      return if @model.undoredo_action

      @model.start("Skalp - #{Skalp.translate('update section')}")

      type = @page || @skpModel
      Skalp.check_color_by_layer_layers if @model.rendering_options.hiddenline_style_active?(type)

      selected_page = @skpModel.pages.selected_page

      if @page # update for layout
        sectiongroup = create_sectiongroup(@page)
        sectionfaces_to_sectiongroup(sectiongroup)
      elsif selected_page && Skalp.active_model.get_memory_attribute(selected_page, "Skalp", "ID")
        sectiongroup = create_sectiongroup(selected_page)
        sectionfaces_to_sectiongroup(sectiongroup)

        sectiongroup = create_sectiongroup
        sectionfaces_to_sectiongroup(sectiongroup, skip_transform = true)
        manage_sections(selected_page)
      else
        # normal update
        sectiongroup = create_sectiongroup
        sectionfaces_to_sectiongroup(sectiongroup)
        manage_sections
      end
      @model.commit
    end

    def sectionfaces_to_sectiongroup(sectiongroup, skip_transform = false)
      @model.section_result_group.locked = false
      return unless sectiongroup && sectiongroup.valid?
      return unless @sectionplane
      return unless @sectionplane.skpSectionPlane.valid?

      materials = Sketchup.active_model.materials
      linecolor = materials["Skalp linecolor"]
      transparent = materials["Skalp transparent"]

      Skalp.linestyle_layer_visible
      Skalp.active_model.entity_strings = {}
      if @section2Ds.size > 0
        sectiongroup.entities.build do |builder|
          type = @page || @skpModel
          use_lineweight = Skalp.dialog ? Skalp.dialog.lineweights_status(type) : false

          normal = Geom::Vector3d.new 0, 0, 1
          result = false

          if use_lineweight
            @lineweight_mask = Skalp::MultiPolygon.new
            @inner_lineweight_collection = []
            @outer_lineweight_mask = Skalp::MultiPolygon.new
            create_lineweight_mask(type)
            create_inner_lineweight_collection
            create_outer_lineweight_mask
          end

          centerline_loops = []

          @section2Ds.each do |section2d|
            # fillup lookup table nodes
            unless Skalp.active_model.entity_strings[section2d.node.value.top_parent.value.to_s]
              Skalp.active_model.entity_strings[section2d.node.value.top_parent.value.to_s] =
                section2d.node.value.top_parent.value
            end
            unless Skalp.active_model.entity_strings[section2d.node.value.to_s]
              Skalp.active_model.entity_strings[section2d.node.value.to_s] =
                section2d.node.value
            end

            next unless section2d.node.value.visibility

            if use_lineweight
              polygons = section2d.to_mpoly.difference(@lineweight_mask).polygons.polygons

              section2d.polygons.each do |polygon|
                centerline_loops << polygon.outerloop
                centerline_loops += polygon.innerloops
              end
            else
              polygons = section2d.polygons
            end

            polygons.each do |polygon|
              outerloop = polygon.outerloop.vertices

              innerloops = []
              polygon.innerloops.each do |loop|
                innerloops << loop.vertices
              end

              begin
                face = if innerloops && innerloops != []
                         builder.add_face(outerloop, holes: innerloops)
                       else
                         builder.add_face(outerloop)
                       end

                # TODO: scale???? add_mesh(mesh, scale, section2d, type)
                face.set_attribute("Skalp", "from_object", section2d.node.value.top_parent.value.to_s)
                face.set_attribute("Skalp", "from_sub_object", section2d.node.value.to_s)
                materialname = section2d.hatch_by_style(type).to_s
                face.material = Skalp.create_su_material(materialname)
                correct_UV_material(face)
                layer = @skpModel.layers[section2d.layer_by_style(type, materialname)]
                face.layer = layer if layer && layer.valid?
                result ? normal != face.normal && face.reverse! : normal = face.normal
                result = true
              rescue ArgumentError => e
              end
            end
          end

          if use_lineweight
            @inner_lineweight_collection.each do |mpoly|
              mpoly.polygons.polygons.each do |polygon|
                next if polygon.outerloop.vertices.size < 3

                outerloop = polygon.outerloop.vertices
                innerloops = []
                polygon.innerloops.each do |loop|
                  innerloops << loop.vertices
                end

                begin
                  face = if innerloops && innerloops != []
                           builder.add_face(outerloop, holes: innerloops)
                         else
                           builder.add_face(outerloop)
                         end
                rescue StandardError
                  next
                end

                face.material = linecolor
                face.back_material = transparent
                @skpModel.layers["\uFEFF".encode("utf-8") + "Skalp Pattern Layer - Skalp linecolor"] ? layername = "\uFEFF".encode("utf-8") + "Skalp Pattern Layer - Skalp linecolor" : layername = "layer0"
                face.layer = layername

                result ? normal != face.normal && face.reverse! : normal = face.normal
                result = true

                face.edges.each do |edge|
                  edge.smooth = true
                  edge.soft = true
                  edge.hidden = true
                end
              end
            end

            @outer_lineweight_mask.polygons.polygons.each do |polygon|
              next if polygon.vertices.size < 3

              outerloop = polygon.outerloop.vertices
              innerloops = []
              polygon.innerloops.each do |loop|
                innerloops << loop.vertices
              end
              face = if innerloops && innerloops != []
                       builder.add_face(outerloop, holes: innerloops)
                     else
                       builder.add_face(outerloop)
                     end
              face.material = linecolor
              face.back_material = transparent
              @skpModel.layers["\uFEFF".encode("utf-8") + "Skalp Pattern Layer - Skalp linecolor"] ? layername = "\uFEFF".encode("utf-8") + "Skalp Pattern Layer - Skalp linecolor" : layername = "layer0"
              face.layer = layername

              result ? normal != face.normal && face.reverse! : normal = face.normal
              result = true

              face.edges.each do |edge|
                edge.smooth = true
                edge.soft = true
                edge.hidden = true
              end
            end

            centerline_loops.each do |loop|
              for n in 0..loop.vertices.size - 1
                pt1 = loop.vertices[n - 1]
                pt2 = loop.vertices[n]
                next unless pt1.distance(pt2) > 0.01

                edge = builder.add_edge(loop.vertices[n - 1], loop.vertices[n])
                edge.smooth = false
                edge.soft = false
                edge.hidden = false
              end
            rescue ArgumentError => e
              e = "#{e}, pt1: #{pt1}, pt2: #{pt2} "
              Skalp.send_info("Add_ege duplicate points error")
              Skalp.send_bug(e)
            end
          end
        end
      end
      transformation_inverse = @sectionplane.transformation.inverse
      if Skalp.dialog && Skalp.dialog.style_settings(@page)[:rearview_status]
        place_rear_view_lines_in_model(sectiongroup)
      end
      @model.section_result_group.locked = true

      return unless sectiongroup.valid?

      sectiongroup.transform! transformation_inverse * Skalp.transformation_down

      # if skip_transform
      #   sectiongroup.transform! transformation_inverse * Skalp.transformation_down
      # else
      #   sectiongroup.transform! transformation_inverse
      # end
    end

    def section_to_sectiongroup(sectiongroup, skip_transform = false)
      @model.section_result_group.locked = false
      return unless sectiongroup && sectiongroup.valid?
      return unless @section_mesh && @sectionplane
      return unless @sectionplane.skpSectionPlane.valid?

      Skalp.linestyle_layer_visible

      @section_mesh.transform! Skalp.transformation_down unless skip_transform

      sectiongroup.entities.fill_from_mesh @section_mesh
      transformation_inverse = @sectionplane.transformation.inverse

      return unless sectiongroup.valid?

      sectiongroup.transform! transformation_inverse

      correct_faces(sectiongroup)

      type = @page || @skpModel
      if Skalp.dialog && Skalp.dialog.style_settings(type)[:rearview_status]
        place_rear_view_lines_in_model(sectiongroup)
      end
      @model.section_result_group.locked = true
    end

    def place_rear_view_lines_in_model(target_group = nil)
      target_group ||= @sectiongroup
      return unless target_group && target_group.valid?
      return unless Skalp.models[@skpModel]

      Skalp.debug_log "[DEBUG] place_rear_view_lines_in_model for: #{target_group}"

      observer_status = Skalp.models[@skpModel].observer_active
      Skalp.models[@skpModel].observer_active = false

      type = @page || @skpModel
      # puts "[DEBUG] type: #{type.is_a?(Sketchup::Page) ? type.name : 'Model'}"

      return unless @sectionplane && @sectionplane.respond_to?(:skalpID)

      id = @sectionplane.skalpID
      Skalp.debug_log "[DEBUG] sectionplane id: #{id}"

      active_page = type
      selected_page = @skpModel.pages.selected_page

      if id == @model.hiddenlines.calculated[active_page]
        Skalp.debug_log "[DEBUG] Exact match found for active_page: #{active_page.respond_to?(:name) ? active_page.name : active_page.to_s}"
        place_lines_or_definition_in_model(active_page, target_group)
      elsif id == @model.hiddenlines.calculated[@skpModel]
        # Fallback: check if calculated for model (live section)
        Skalp.debug_log "[DEBUG] Match found for Model fallback"
        place_lines_or_definition_in_model(@skpModel, target_group)
      else
        found = false
        @model.hiddenlines.calculated.each do |k, v|
          next if k == @skpModel

          if v == id
            type = k
            found = true
          end
        end
        if found
          Skalp.debug_log "[DEBUG] Match found for other page: #{type.is_a?(Sketchup::Page) ? type.name : 'Model'}"
          place_lines_or_definition_in_model(type, target_group, true)
        elsif @model.hiddenlines.rear_view_definitions[active_page] &&
              @model.hiddenlines.rear_view_definitions[active_page].valid? &&
              @model.hiddenlines.rear_view_definitions[active_page].entities.size > 0
          Skalp.debug_log "[DEBUG] NO match found in calculated hash, using saved definition for active_page"
          place_lines_or_definition_in_model(active_page, target_group)
        elsif selected_page && @model.hiddenlines.rear_view_definitions[selected_page] &&
              @model.hiddenlines.rear_view_definitions[selected_page].valid? &&
              @model.hiddenlines.rear_view_definitions[selected_page].entities.size > 0
          Skalp.debug_log "[DEBUG] Using saved rear_view_definition for selected_page: #{selected_page.name}"
          place_lines_or_definition_in_model(selected_page, target_group)
        elsif @model.hiddenlines.rear_view_definitions[@skpModel] &&
              @model.hiddenlines.rear_view_definitions[@skpModel].valid? &&
              @model.hiddenlines.rear_view_definitions[@skpModel].entities.size > 0
          # puts "[DEBUG] Using saved rear_view_definition for Model fallback"
          place_lines_or_definition_in_model(@skpModel, target_group)
        else
          # No valid definition found for this page - don't use definitions from other pages!
          # The lines will need to be recalculated for this page
          # puts "[DEBUG] No rear_view_definition found for current page (#{selected_page&.name || 'Model'})"
          # puts "[DEBUG] Available definitions are for: #{@model.hiddenlines.rear_view_definitions.keys.select do |k|
          #   k.is_a?(Sketchup::Page)
          # end.map(&:name).join(', ')}"
          Skalp.debug_log "[DEBUG] Rearview lines will need to be recalculated for this page"

        end
      end
      Skalp.models[@skpModel].observer_active = observer_status
    end

    def place_lines_or_definition_in_model(page, target_group, force = false)
      @model.section_result_group.locked = false

      # Try to find an existing valid definition with entities
      definition = nil
      if @model.hiddenlines.rear_view_definitions[page] && @model.hiddenlines.rear_view_definitions[page].valid? && !force
        def_check = @model.hiddenlines.rear_view_definitions[page]
        definition = def_check if def_check.entities.size > 0
      end

      if definition
        # Check if instance already exists to prevent duplicates (and slow double-work)
        existing = target_group.entities.grep(Sketchup::ComponentInstance).find { |i| i.definition == definition }
        target_group.entities.add_instance(definition, Geom::Transformation.new) unless existing
      elsif @model.hiddenlines.rear_lines_result[page]
        @model.hiddenlines.add_lines_to_page(page, true)
      end

      @model.section_result_group.locked = true
    end

    def manage_sections(skpPage_toset = nil, live = true)
      @model.section_result_group.locked = false
      return unless @model.live_sectiongroup
      return if @model.live_sectiongroup.deleted?

      page_sectiongroup = nil
      live_sectiongroup = nil

      if skpPage_toset && @skpModel

        pageID = Skalp.active_model.get_memory_attribute(skpPage_toset, "Skalp", "ID")
        sectionplaneID = Skalp.active_model.get_memory_attribute(skpPage_toset, "Skalp", "sectionplaneID")

        # set visiblity of the section_groups

        @model.section_result_group.entities.grep(Sketchup::Group).each do |section_group|
          if section_group.get_attribute("Skalp", "ID") == pageID
            page_sectiongroup = section_group
            Skalp.sectiongroup_visibility(section_group, true, skpPage_toset)
          else
            Skalp.sectiongroup_visibility(section_group, false, skpPage_toset)
          end
        end

        # set visibility of the sectionplane
        Sketchup.active_model.entities.grep(Sketchup::SectionPlane).each do |sectionplane|
          if sectionplane.get_attribute("Skalp", "ID")
            if sectionplane.get_attribute("Skalp", "ID") == sectionplaneID
              if sectionplane.is_a?(Sketchup::Drawingelement) && sectionplane.valid?
                skpPage_toset.set_drawingelement_visibility(sectionplane,
                                                            true)
              end
            elsif sectionplane.is_a?(Sketchup::Drawingelement) && sectionplane.valid?
              if sectionplane.is_a?(Sketchup::Drawingelement) && sectionplane.valid?
                skpPage_toset.set_drawingelement_visibility(sectionplane,
                                                            false)
              end
            end
          end
        end
      end

      if live
        sectionplaneID = @model.get_memory_attribute(@skpModel, "Skalp", "active_sectionplane_ID")

        # set visibility of the sectionplane
        Sketchup.active_model.entities.grep(Sketchup::SectionPlane).each do |sectionplane|
          next unless sectionplane.get_attribute("Skalp", "ID")

          sectionplane.hidden = !(sectionplane.get_attribute("Skalp", "ID") == sectionplaneID)
        end

        # set visiblity of the section_groups
        @model.section_result_group.entities.grep(Sketchup::Group).each do |section_group|
          if section_group.get_attribute("Skalp", "ID")
            if section_group.get_attribute("Skalp",
                                           "ID") == "skalp_live_sectiongroup" && @model.live_sectiongroup.valid? && Skalp.sectionplane_active == true && @model.live_sectiongroup
              live_sectiongroup = section_group
              Skalp.sectiongroup_visibility(section_group, true)
            else
              Skalp.sectiongroup_visibility(section_group, false)
            end
          end
        end
      end

      @skpModel.pages.each do |page|
        if page == skpPage_toset
          Skalp.sectiongroup_visibility(page_sectiongroup, true, page) if page_sectiongroup.class == Sketchup::Group
        elsif page_sectiongroup.class == Sketchup::Group
          Skalp.sectiongroup_visibility(page_sectiongroup, false, page)
        end

        Skalp.sectiongroup_visibility(live_sectiongroup, false, page) if live_sectiongroup.class == Sketchup::Group
      end

      if page_sectiongroup
        page_sectiongroup.layer = Skalp.scene_section_layer
        page_sectiongroup.layer.visible = false
        page_sectiongroup.hidden = true
      end

      live_sectiongroup.layer = nil if live_sectiongroup
      @model.section_result_group.layer = nil
      @model.section_result_group.locked = true
    end

    def create_sectiongroup(page = nil)
      delete_sectiongroup(page)
      @sectiongroup = Skalp.active_model.new_sectiongroup(page)
      return unless @sectiongroup && @sectiongroup.valid?

      @model.section_result_group.locked = false
      @sectiongroup.entities.clear!
      Skalp.active_model.live_sectiongroup = @sectiongroup unless page

      @sectiongroup.transformation = Geom::Transformation.new
      @sectiongroup.casts_shadows = false
      @sectiongroup.receives_shadows = false
      @sectiongroup.layer = Skalp.scene_section_layer
      @model.section_result_group.locked = true
      @sectiongroup
    end

    def get_page_ids
      ids = []

      Sketchup.active_model.pages.each do |page|
        ids << Skalp.active_model.get_memory_attribute(page, "Skalp", "ID") if Skalp.active_model.get_memory_attribute(
          page, "Skalp", "ID"
        )
      end

      ids
    end

    def delete_sectiongroup(page = nil)
      return if @model.section_result_group.deleted?

      @model.section_result_group.locked = false
      page_ids = get_page_ids
      to_delete = []

      @model.section_result_group.entities.grep(Sketchup::Group).each do |group|
        next if group.deleted?

        if group.get_attribute("Skalp",
                               "ID") != "" && group.get_attribute("Skalp",
                                                                  "ID") != nil && !page_ids.include?(group.get_attribute("Skalp",
                                                                                                                         "ID")) && group.get_attribute(
                                                                                                                           "Skalp", "ID"
                                                                                                                         ) != "skalp_live_sectiongroup"
          group.locked = false
          to_delete << group
          next
        end

        if page
          id = Skalp.active_model.get_memory_attribute(page, "Skalp", "ID")
          if id && (group.get_attribute("Skalp", "ID") == id)
            group.locked = false
            to_delete << group
          end

        elsif group.get_attribute("Skalp", "ID") == "skalp_live_sectiongroup"
          group.locked = false
          to_delete << group
        end
      end
      # @skpModel.entities.erase_entities(to_delete)
      # Avoid Error: #<ArgumentError: cannot remove an instance in the active editing path> in SU2023
      to_delete.each { |e| e.erase! }
      @model.section_result_group.locked = true
    end

    def get_section2Ds(node_to_show = Skalp.active_model.tree.root)
      return unless node_to_show

      node_to_show.get_section_results(self, @force_update)
    end

    def create_lineweight_mask(type)
      scale = Skalp.dialog ? Skalp.dialog.drawing_scale(type) : 1.0
      @section2Ds.each do |section2d|
        next unless section2d.node.value.visibility

        material = skalp_style_material(section2d, type)
        begin
          lineweight = if material && @skpModel.materials[material] && Skalp.skalp_material_info(@skpModel.materials[material],
                                                                                                 :section_cut_width)
                         Skalp.skalp_material_info(@skpModel.materials[material], :section_cut_width).to_f
                       else
                         0.00
                       end

          if lineweight > 0.00
            lineweight *= scale
            @lineweight_mask.union!(section2d.to_mpoly.outline(lineweight))
          end
        rescue StandardError
          pp material
        end
      end
    end

    def create_inner_lineweight_collection
      @section2Ds.each do |section2d|
        next unless section2d.node.value.visibility

        @inner_lineweight_collection << section2d.to_mpoly.intersection(@lineweight_mask)
      end
    end

    def create_outer_lineweight_mask
      @outer_lineweight_mask = @lineweight_mask.clone
      @section2Ds.each do |section2d|
        next unless section2d.node.value.visibility

        @outer_lineweight_mask.difference!(section2d.to_mpoly)
      end
    end

    def skalp_style_material(section2d, type)
      Skalp.scene_style_nested = false
      section2d.hatch_by_style(type)
    end

    def add_polygons_to_sectionmesh
      type = @page || @skpModel
      use_lineweight = Skalp.dialog ? Skalp.dialog.lineweights_status(type) : false

      Skalp.active_model.entity_strings = {}
      @object_list = []
      @sub_object_list = []

      if use_lineweight
        @lineweight_mask = Skalp::MultiPolygon.new
        @inner_lineweight_collection = []
        @outer_lineweight_mask = Skalp::MultiPolygon.new
      end

      @section_mesh = Geom::PolygonMesh.new
      type = @page || @skpModel
      scale = Skalp.dialog ? Skalp.dialog.drawing_scale(type) : 1.0

      if use_lineweight
        create_lineweight_mask(type)
        create_inner_lineweight_collection
        create_outer_lineweight_mask
      end

      @section2Ds.each do |section2d|
        next unless section2d.node.value.visibility == true # TODO: visisbility hier nazien!

        # fillup lookup table nodes
        unless Skalp.active_model.entity_strings[section2d.node.value.top_parent.value.to_s]
          Skalp.active_model.entity_strings[section2d.node.value.top_parent.value.to_s] =
            section2d.node.value.top_parent.value
        end
        unless Skalp.active_model.entity_strings[section2d.node.value.to_s]
          Skalp.active_model.entity_strings[section2d.node.value.to_s] =
            section2d.node.value
        end

        if use_lineweight
          section2d.to_mpoly.difference(@lineweight_mask).meshes.each do |mesh|
            add_mesh(mesh, scale, section2d, type)
          end
          section2d.meshes.each do |mesh|
            add_mesh(mesh, scale, section2d, type, true)
          end
        else
          section2d.meshes.each do |mesh|
            add_mesh(mesh, scale, section2d, type)
          end
        end
      end

      return unless use_lineweight

      @inner_lineweight_collection.each do |mpoly|
        mpoly.meshes.each { |mesh| @section_mesh.add_polygon(mesh) if mesh.size > 2 }
      end

      @outer_lineweight_mask.meshes.each { |mesh| @section_mesh.add_polygon(mesh) if mesh.size > 2 }
    end

    def add_mesh(mesh, scale, section2d, type, centerline = false)
      return unless mesh.size > 2

      @section_mesh.add_polygon(mesh)
      Skalp.scene_style_nested = false
      material = section2d.hatch_by_style(type)
      @material_list << (centerline ? :to_delete : material)
      @object_list << section2d.node.value.top_parent.value
      @sub_object_list << section2d.node.value
      Skalp.scene_style_nested = false

      @layer_list << if centerline
                       "Layer0"
                     else
                       section2d.layer_by_style(type, material)
                     end
    end

    def export_dxf(filename, layer_preset, page = nil)
      @page = page
      hatched_polygons = []

      if @page
        type = @page
        index = Skalp.page_index(@page)
      else
        type = @skpModel
        index = -1
      end

      style_stettings = Skalp.active_model.get_memory_attribute(type, "Skalp", "style_settings")

      if style_stettings.class == Hash
        linetype = Skalp.active_model.get_memory_attribute(type, "Skalp", "style_settings")[:rearview_linestyle]
        if [nil, ""].include?(linetype)
          linetype = "Dash"
          style_stettings[:rearview_linestyle] = "Dash"
        end
      else
        linetype = "Dash"
      end

      return unless Skalp.dialog

      section_scale = Skalp.dialog.drawing_scale(type)
      for section2d in @section2Ds
        if @visibility.check_visibility(section2d.node.value.skpEntity)
          for polygon in section2d.polygons
            next unless polygon.vertices.size > 2

            for v in polygon.vertices
              min_x = v[0] if !min_x || v[0] < min_x
              min_y = v[1] if !min_y || v[1] < min_y
              max_x = v[0] if !max_x || v[0] > max_x
              max_y = v[1] if !max_y || v[1] > max_y
            end
            material = section2d.hatch_by_style(type)

            export_layer = case layer_preset[:section_layer]
                           when "fixed"
                             "Skalp-Section"
                           when "object"
                             section2d.node.value.layer + layer_preset[:section_suffix]
                           when "material"
                             material + layer_preset[:section_suffix]
                           else
                             "Skalp-Section"
                           end

            hatched_polygons << Skalp::DXF_export::Hatched_polygon.new(polygon.outerloop, polygon.innerloops, material, section_scale, export_layer) # SkalpHatch.hatchdefs[0]
          end
        else

        end
      end

      if Sketchup.active_model.pages && Sketchup.active_model.pages.selected_page
        name = @page ? @page.name : Sketchup.active_model.pages.selected_page.name # "#{Skalp.translate('active')}_#{Skalp.translate('view')}"
        object = @page || Sketchup.active_model
      else
        name = ""
        object = Sketchup.active_model
      end

      if Skalp.dialog.rearview_status(object)
        Skalp::DXF_export.new(filename, name, hatched_polygons, @model.hiddenlines.forward_lines_result[object],
                              @model.hiddenlines.rear_lines_result[object], [Skalp.inch_to_modelunits(min_x), Skalp.inch_to_modelunits(min_y)], [Skalp.inch_to_modelunits(max_x), Skalp.inch_to_modelunits(max_y)], section_scale, linetype)
      else
        Skalp::DXF_export.new(filename, name, hatched_polygons, @model.hiddenlines.forward_lines_result[object], nil,
                              [Skalp.inch_to_modelunits(min_x), Skalp.inch_to_modelunits(min_y)], [Skalp.inch_to_modelunits(max_x), Skalp.inch_to_modelunits(max_y)], section_scale, linetype)
      end
    end

    def show_centerline(face)
      lines_processed = {}
      edges = []

      face.edges.each do |edge|
        next unless edge.class == Sketchup::Edge

        num_before = lines_processed.length
        lines_processed[[edge.start.position.to_a, edge.end.position.to_a]] = edge
        lines_processed[[edge.end.position.to_a, edge.start.position.to_a]] = edge

        if num_before < lines_processed.length
          edges << edge
        else
          connection_edge = lines_processed[[edge.start.position.to_a, edge.end.position.to_a]]
          edges.delete(connection_edge)
        end
      end
      face.erase!

      edges.each do |edge|
        edge.smooth = false
        edge.soft = false
        edge.hidden = false
      end
    end

    def correct_faces(sectiongroup)
      type = @page || @skpModel
      hide_edges(sectiongroup) if Skalp.dialog && Skalp.dialog.lineweights_status(type)

      normal = Geom::Vector3d.new 0, 0, 1
      result = false

      n = 0

      materials = Sketchup.active_model.materials
      linecolor = materials["Skalp linecolor"]
      transparent = materials["Skalp transparent"]

      sectiongroup.entities.grep(Sketchup::Face).each do |face|
        next unless face.is_a?(Sketchup::Face)

        if n < @material_list.size
          if @material_list[n] == :to_delete
            show_centerline(face)
          else
            face.set_attribute("Skalp", "from_object", @object_list[n].to_s)
            face.set_attribute("Skalp", "from_sub_object", @sub_object_list[n].to_s)
            face.material = Skalp.create_su_material(@material_list[n].to_s)
            correct_UV_material(face)
            layer = @skpModel.layers[@layer_list[n].to_s]
            face.layer = layer if layer && layer.valid?
            result ? normal != face.normal && face.reverse! : normal = face.normal
            result = true
          end
        else
          face.material = linecolor
          face.back_material = transparent
          @skpModel.layers["\uFEFF".encode("utf-8") + "Skalp Pattern Layer - Skalp linecolor"] ? layername = "\uFEFF".encode("utf-8") + "Skalp Pattern Layer - Skalp linecolor" : layername = "layer0"

          face.layer = layername
        end
        n += 1
      end
    end

    # Returns a Geom::Point3d, which is a member of the face and is at the largest distance from the given edge.
    # Measurement is done perpendicular to the given edge.
    # the edge can be member of the face but it does not need to be part of the face.
    def max_offset_point(face, edge)
      vertices = face.vertices.to_a.compact
      vertices.max_by do |vertex|
        next unless vertex.class == Sketchup::Vertex

        vertex.position.distance_to_line(edge.line)
      end.position
    rescue StandardError
      nil
    end

    def uv_scaling(point, factor)
      point.y = point.y * factor
      point
    end

    # scales, translates and rotates texture on a face as needed
    def correct_UV_material(face)
      return unless face.class == Sketchup::Face
      return unless face.valid?

      type = @page || @skpModel
      return unless Skalp.dialog

      scale = Skalp.dialog.drawing_scale(type)

      material = face.material
      return unless material && material.class == Sketchup::Material && material.texture

      proportion = material.texture.height / material.texture.width
      if Skalp.skalp_material_info(material, :space) == :modelspace
        ori_scale = scale
      elsif Skalp.skalp_material_info(material,
                                      :print_scale)
        ori_scale = Skalp.skalp_material_info(material, :print_scale).to_f
      end

      return unless ori_scale
      return if ori_scale == 0.0

      material_layer = "\uFEFF".encode("utf-8") + "Skalp Pattern Layer - " + Skalp.skalp_material_info(material, :name)
      if Sketchup.active_model.layers[material_layer]
        scale_correction = Sketchup.active_model.layers[material_layer].get_attribute("Skalp",
                                                                                      "scale_correction")
      end
      scale_correction ||= 1.0

      aligned = Skalp.aligned(face.material)
      scaled = !(scale == ori_scale)

      return unless aligned || scaled

      edge = longest_edge(face)

      return unless edge.is_a?(Sketchup::Edge) && edge.valid?
      return unless edge.start.class == Sketchup::Vertex && edge.end.class == Sketchup::Vertex

      tw = Sketchup.create_texture_writer
      return unless tw.class == Sketchup::TextureWriter

      uvHelp = face.get_UVHelper(true, true, tw)
      return unless uvHelp.class == Sketchup::UVHelper

      p1 = edge.start.position
      p2 = edge.end.position

      if aligned
        p1uv = uv_scaling(uvHelp.get_front_UVQ(p1), proportion)
        p2uv = uv_scaling(uvHelp.get_front_UVQ(p2), proportion)

        p3 = max_offset_point(face, edge)
        return unless p3

        p3uv = uvHelp.get_front_UVQ(p3)
      else
        p1uv = uvHelp.get_front_UVQ(p1)
        p2uv = uvHelp.get_front_UVQ(p2)

        p3 = max_offset_point(face, edge)
        return unless p3

        p3uv = uvHelp.get_front_UVQ(p3)
      end

      unless scale == ori_scale || ori_scale.nil? || scale.nil?

        scaling = Geom::Transformation.scaling(ori_scale / scale)

        p1uv.transform!(scaling)
        p2uv.transform!(scaling)
        p3uv.transform!(scaling)
      end

      pt_array = []
      pt_array[0] = p1
      pt_array[2] = p2

      if aligned
        base_line_endpoint = p1uv + [1, 0, 0]
        rotation = Geom::Transformation.rotation(p1uv, Geom::Vector3d.new(0, 0, 1), Skalp.angle_3_points(base_line_endpoint, p1uv, p2uv)) # angle in radians
        p2uv.transform!(rotation)
        p1uv = uv_scaling(p1uv, 1.0 / proportion)
        p2uv = uv_scaling(p2uv, 1.0 / proportion)
        pt_array[1] = Geom::Point3d.new(0, 0, 0)
        pt_array[3] = Geom::Point3d.new(p2uv.x - p1uv.x, p2uv.y - p1uv.y, p2uv.z - p1uv.z)
      else
        pt_array[1] = p1uv
        pt_array[3] = p2uv
        pt_array[4] = p3
        pt_array[5] = p3uv
      end

      begin
        face.position_material(material, pt_array, true)
      rescue ArgumentError
        # Suppress "Could not compute valid matrix from points" error
        # This happens often with degenerate geometry and spams the log.
        # Fallback is just unpositioned texture, which is acceptable.
      end

      # handig om de punten te bekijken als er iets mis is:
      # num = -1 ; pt_array.each {|point| @skpModel.entities.add_cpoint(point);@skpModel.entities.add_text("#{num+=1}", point); puts point}
    rescue StandardError => e
      Skalp.send_info("UV bug")
      Skalp.send_bug(e)
    end

    def longest_edge(face)
      max_edge = nil
      face.edges.each do |edge|
        next unless edge.class == Sketchup::Edge

        max_edge || max_edge = edge
        max_edge = edge if edge.length > max_edge.length
      end

      max_edge
    end

    def hide_edges(sectiongroup)
      sectiongroup.entities.grep(Sketchup::Edge).each { |edge| edge.hidden = true }
    end

    def lineweights(sectiongroup)
      sectiongroup.entities.each do |face|
        # node_value = Skalp.active_model.entity_strings[face.get_attribute('Skalp','from_sub_object')]
        node_value.section2d[@sectionplane]
      end
    end
  end
end
