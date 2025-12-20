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

    def update(page = nil, force_update = true)
      return unless @model
      @page = page
      @visibility = Skalp::Visibility.new
      @visibility.update(@page)

      @model.undoredo_action ? @force_update = true : @force_update = force_update

      @section2Ds = []
      @hatchmaterials = []
      @material_list = []
      @layer_list = []
      @section_mesh = nil
      @sectiongroup = nil
      @context_sectiongroup = nil
      @representation = :skalpMaterial

      if Skalp.live_section_ON
        Sketchup.active_model.rendering_options['SectionCutFilled'] = false
      else
        Sketchup.active_model.rendering_options['SectionCutFilled'] = true
      end
      create_section
    end

    def create_section
      return unless Skalp.ready
      Skalp.active_model.section_result_group.hidden = false
      get_section2Ds(Skalp.active_model.tree.root)

      unless @model.undoredo_action
        @model.start("Skalp - #{Skalp.translate('update section')}")

        @page ? type = @page : type = @skpModel
        if @model.rendering_options.hiddenline_style_active?(type)
          Skalp.check_color_by_layer_layers
        end

        selected_page = @skpModel.pages.selected_page

        if @page #update for layout
          sectiongroup = create_sectiongroup(@page)
          sectionfaces_to_sectiongroup(sectiongroup)
        elsif selected_page && Skalp.active_model.get_memory_attribute(selected_page, 'Skalp', 'ID')
          sectiongroup = create_sectiongroup(selected_page)
          sectionfaces_to_sectiongroup(sectiongroup)

          sectiongroup = create_sectiongroup
          sectionfaces_to_sectiongroup(sectiongroup, skip_transform = true)
          manage_sections(selected_page)
        else
          #normal update
          sectiongroup = create_sectiongroup
          sectionfaces_to_sectiongroup(sectiongroup)
          manage_sections
        end
        @model.commit
      end
    end

    def sectionfaces_to_sectiongroup(sectiongroup, skip_transform = false)
      @model.section_result_group.locked = false
      return unless sectiongroup && sectiongroup.valid?
      return unless @sectionplane
      return unless @sectionplane.skpSectionPlane.valid?

      materials = Sketchup.active_model.materials
      linecolor = materials["Skalp linecolor"]
      transparent = materials["Skalp transparent"]

      Skalp::linestyle_layer_visible
      Skalp.active_model.entity_strings = {}
      if @section2Ds.size > 0
      sectiongroup.entities.build { |builder|
        @page ? type = @page : type = @skpModel
        use_lineweight = Skalp.dialog.lineweights_status(type)

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
          #fillup lookup table nodes
          Skalp.active_model.entity_strings[section2d.node.value.top_parent.value.to_s] = section2d.node.value.top_parent.value unless Skalp.active_model.entity_strings[section2d.node.value.top_parent.value.to_s]
          Skalp.active_model.entity_strings[section2d.node.value.to_s] = section2d.node.value unless Skalp.active_model.entity_strings[section2d.node.value.to_s]

          if section2d.node.value.visibility
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
                if innerloops && innerloops != []
                  face = builder.add_face(outerloop, holes: innerloops)
                else
                  face = builder.add_face(outerloop)
                end

                #TODO scale???? add_mesh(mesh, scale, section2d, type)
                face.set_attribute('Skalp', 'from_object', section2d.node.value.top_parent.value.to_s)
                face.set_attribute('Skalp', 'from_sub_object', section2d.node.value.to_s)
                materialname = section2d.hatch_by_style(type).to_s
                face.material = Skalp.create_su_material(materialname)
                correct_UV_material(face)
                layer = @skpModel.layers[section2d.layer_by_style(type, materialname)]
                face.layer = layer if layer && layer.valid?
                result ? normal != face.normal && face.reverse! : normal = face.normal
                result = true

              rescue ArgumentError => error
              end
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
              if innerloops && innerloops != []
                face = builder.add_face(outerloop, holes: innerloops)
              else
                face = builder.add_face(outerloop)
              end
              rescue
                next
              end

              face.material = linecolor
              face.back_material = transparent
              @skpModel.layers["\uFEFF".encode('utf-8') + 'Skalp Pattern Layer - Skalp linecolor'] ? layername = "\uFEFF".encode('utf-8') + 'Skalp Pattern Layer - Skalp linecolor' : layername = 'layer0'
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
              if innerloops && innerloops != []
                face = builder.add_face(outerloop, holes: innerloops)
              else
                face = builder.add_face(outerloop)
              end
              face.material = linecolor
              face.back_material = transparent
              @skpModel.layers["\uFEFF".encode('utf-8') + 'Skalp Pattern Layer - Skalp linecolor'] ? layername = "\uFEFF".encode('utf-8') + 'Skalp Pattern Layer - Skalp linecolor' : layername = 'layer0'
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
            begin
            for n in 0..loop.vertices.size-1
              pt1 = loop.vertices[n-1]
              pt2 = loop.vertices[n]
              if pt1.distance(pt2) > 0.01
                edge = builder.add_edge(loop.vertices[n-1], loop.vertices[n])
                edge.smooth = false
                edge.soft = false
                edge.hidden = false
              end
            end
            rescue ArgumentError => error
              e = "#{error}, pt1: #{pt1}, pt2: #{pt2} "
              Skalp.send_info('Add_ege duplicate points error')
              Skalp.send_bug(e)
            end
          end
        end
      }
      end
      transformation_inverse = @sectionplane.transformation.inverse
      place_rear_view_lines_in_model if Skalp.dialog.style_settings(@page)[:rearview_status]
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

      Skalp::linestyle_layer_visible

      @section_mesh.transform! Skalp.transformation_down unless skip_transform

      sectiongroup.entities.fill_from_mesh @section_mesh
      transformation_inverse = @sectionplane.transformation.inverse

      return unless sectiongroup.valid?
      sectiongroup.transform! transformation_inverse

      correct_faces(sectiongroup)

      @page ? type = @page : type = @skpModel
      place_rear_view_lines_in_model if Skalp.dialog.style_settings(type)[:rearview_status]
      @model.section_result_group.locked = true
    end

    def place_rear_view_lines_in_model
      return unless @sectiongroup.valid?
      return unless Skalp.models[@skpModel]

      observer_status = Skalp.models[@skpModel].observer_active
      Skalp.models[@skpModel].observer_active = false

      @page ? type = @page : type = @skpModel

      id = sectionplane.skalpID

      (@skpModel.pages && type == @skpModel) ? active_page = @skpModel.pages.selected_page : active_page = type
      if id == @model.hiddenlines.calculated[active_page]
        place_lines_or_definition_in_model(active_page)
      else
        found = false
        @model.hiddenlines.calculated.each do |k, v|
          next if k == @skpModel
          if v == id
            type = k
            found = true
          end
        end
        place_lines_or_definition_in_model(type, true) if found #TODO what if not found
      end
      Skalp.models[@skpModel].observer_active = observer_status
    end

    def place_lines_or_definition_in_model(page, force = false)
      @model.section_result_group.locked = false
      if @model.hiddenlines.rear_view_definitions[page] && @model.hiddenlines.rear_view_definitions[page].valid? && !force
        definition = @model.hiddenlines.rear_view_definitions[page]
        @sectiongroup.entities.add_instance(definition, Geom::Transformation.new)
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

        pageID = Skalp.active_model.get_memory_attribute(skpPage_toset, 'Skalp', 'ID')
        sectionplaneID = Skalp.active_model.get_memory_attribute(skpPage_toset, 'Skalp', 'sectionplaneID')

        #set visiblity of the section_groups

        @model.section_result_group.entities.grep(Sketchup::Group).each do |section_group|
          if section_group.get_attribute('Skalp', 'ID') == pageID
            page_sectiongroup = section_group
            Skalp.sectiongroup_visibility(section_group, true, skpPage_toset)
          else
            Skalp.sectiongroup_visibility(section_group, false, skpPage_toset)
          end
        end

        #set visibility of the sectionplane
        Sketchup.active_model.entities.grep(Sketchup::SectionPlane).each do |sectionplane|
          if sectionplane.get_attribute('Skalp', 'ID')
            if sectionplane.get_attribute('Skalp', 'ID') == sectionplaneID
              skpPage_toset.set_drawingelement_visibility(sectionplane, true)
            else
              skpPage_toset.set_drawingelement_visibility(sectionplane, false)
            end
          end
        end
      end

      if live
        sectionplaneID = @model.get_memory_attribute(@skpModel, 'Skalp', 'active_sectionplane_ID')

        #set visibility of the sectionplane
        Sketchup.active_model.entities.grep(Sketchup::SectionPlane).each do |sectionplane|
          if sectionplane.get_attribute('Skalp', 'ID')
            if sectionplane.get_attribute('Skalp', 'ID') == sectionplaneID
              sectionplane.hidden = false
            else
              sectionplane.hidden = true
            end
          end
        end

        #set visiblity of the section_groups
        @model.section_result_group.entities.grep(Sketchup::Group).each do |section_group|
          if section_group.get_attribute('Skalp', 'ID')
            if section_group.get_attribute('Skalp', 'ID') == 'skalp_live_sectiongroup' && @model.live_sectiongroup.valid? && Skalp.sectionplane_active == true && @model.live_sectiongroup
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
          if page_sectiongroup.class == Sketchup::Group
            Skalp.sectiongroup_visibility(page_sectiongroup, true, page)
          end
        else
          if page_sectiongroup.class == Sketchup::Group
            Skalp.sectiongroup_visibility(page_sectiongroup, false, page)
          end
        end

        if live_sectiongroup.class == Sketchup::Group
          Skalp.sectiongroup_visibility(live_sectiongroup, false, page)
        end
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
        ids << Skalp.active_model.get_memory_attribute(page, 'Skalp', 'ID') if Skalp.active_model.get_memory_attribute(page, 'Skalp', 'ID')
      end

      return ids
    end

    def delete_sectiongroup(page = nil)
      return if @model.section_result_group.deleted?
      @model.section_result_group.locked = false
      page_ids = get_page_ids
      to_delete = []

      @model.section_result_group.entities.grep(Sketchup::Group).each do |group|
        next if group.deleted?

        if group.get_attribute('Skalp', 'ID') != '' && group.get_attribute('Skalp', 'ID') != nil && !page_ids.include?(group.get_attribute('Skalp', 'ID')) && group.get_attribute('Skalp', 'ID') != 'skalp_live_sectiongroup'
          group.locked = false
          to_delete << group
          next
        end

        if page then
          id = Skalp.active_model.get_memory_attribute(page, 'Skalp', 'ID')
          if id
            if group.get_attribute('Skalp', 'ID') == id
              group.locked = false
              to_delete << group
            end

          end
        else
          if group.get_attribute('Skalp', 'ID') == 'skalp_live_sectiongroup'
            group.locked = false
            to_delete << group
          end
        end
      end
      #@skpModel.entities.erase_entities(to_delete)
      # Avoid Error: #<ArgumentError: cannot remove an instance in the active editing path> in SU2023
      to_delete.each { |e| e.erase! }
      @model.section_result_group.locked = true
    end

    def get_section2Ds(node_to_show = Skalp.active_model.tree.root)
      return unless node_to_show
      node_to_show.get_section_results(self, @force_update)
    end

    def create_lineweight_mask(type)
      scale = Skalp.dialog.drawing_scale(type)
      @section2Ds.each do |section2d|
        next unless section2d.node.value.visibility
        material = skalp_style_material(section2d, type)
        begin
        if material && @skpModel.materials[material] && Skalp.skalp_material_info(@skpModel.materials[material], :section_cut_width)
          lineweight = Skalp.skalp_material_info(@skpModel.materials[material], :section_cut_width).to_f
        else
          lineweight = 0.00
        end

        if lineweight > 0.00
          lineweight = lineweight * scale
          @lineweight_mask.union!(section2d.to_mpoly.outline(lineweight))
        end
        rescue
          pp material
        end
      end
    end

    def create_inner_lineweight_collection
      @section2Ds.each { |section2d|
        next unless section2d.node.value.visibility
        @inner_lineweight_collection << section2d.to_mpoly.intersection(@lineweight_mask)
      }
    end

    def create_outer_lineweight_mask
      @outer_lineweight_mask = @lineweight_mask.clone
      @section2Ds.each { |section2d|
        next unless section2d.node.value.visibility
        @outer_lineweight_mask.difference!(section2d.to_mpoly)
      }
    end

    def skalp_style_material(section2d, type)
      Skalp.scene_style_nested = false
      section2d.hatch_by_style(type)
    end

    def add_polygons_to_sectionmesh
      @page ? type = @page : type = @skpModel
      use_lineweight = Skalp.dialog.lineweights_status(type)

      Skalp.active_model.entity_strings = {}
      @object_list = []
      @sub_object_list = []

      if use_lineweight
        @lineweight_mask = Skalp::MultiPolygon.new
        @inner_lineweight_collection = []
        @outer_lineweight_mask = Skalp::MultiPolygon.new
      end

      @section_mesh = Geom::PolygonMesh.new
      @page ? type = @page : type = @skpModel
      scale = Skalp.dialog.drawing_scale(type)

      if use_lineweight
        create_lineweight_mask(type)
        create_inner_lineweight_collection
        create_outer_lineweight_mask
      end

      @section2Ds.each do |section2d|
        if section2d.node.value.visibility == true #TODO: visisbility hier nazien!

          #fillup lookup table nodes
          Skalp.active_model.entity_strings[section2d.node.value.top_parent.value.to_s] = section2d.node.value.top_parent.value unless Skalp.active_model.entity_strings[section2d.node.value.top_parent.value.to_s]
          Skalp.active_model.entity_strings[section2d.node.value.to_s] = section2d.node.value unless Skalp.active_model.entity_strings[section2d.node.value.to_s]

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
      end

      if use_lineweight
        @inner_lineweight_collection.each do |mpoly|
          mpoly.meshes.each { |mesh| @section_mesh.add_polygon(mesh) if mesh.size > 2 }
        end

        @outer_lineweight_mask.meshes.each { |mesh| @section_mesh.add_polygon(mesh) if mesh.size > 2 }
      end
    end

    def add_mesh(mesh, scale, section2d, type, centerline = false)
      if mesh.size > 2
        @section_mesh.add_polygon(mesh)
        Skalp.scene_style_nested = false
        material = section2d.hatch_by_style(type)
        centerline ? @material_list << :to_delete : @material_list << material
        @object_list << section2d.node.value.top_parent.value
        @sub_object_list << section2d.node.value
        Skalp.scene_style_nested = false

        if centerline
          @layer_list << 'Layer0'
        else
          @layer_list << section2d.layer_by_style(type, material)
        end

      end
    end

    def export_dxf(filename, layer_preset, page = nil)
      @page = page
      hatched_polygons = []

      if @page then
        type = @page
        index = Skalp.page_index(@page)
      else
        type = @skpModel
        index = -1
      end

      style_stettings = Skalp.active_model.get_memory_attribute(type, 'Skalp', 'style_settings')

      if style_stettings.class == Hash
        linetype = Skalp.active_model.get_memory_attribute(type, 'Skalp', 'style_settings')[:rearview_linestyle]
        if linetype == nil || linetype == ''
          linetype = 'Dash'
          style_stettings[:rearview_linestyle] = 'Dash'
        end
      else
        linetype = 'Dash'
      end

      section_scale = Skalp.dialog.drawing_scale(type)
      for section2d in @section2Ds
        if @visibility.check_visibility(section2d.node.value.skpEntity)
          for polygon in section2d.polygons
            if polygon.vertices.size > 2
              for v in polygon.vertices
                min_x = v[0] if (!min_x || v[0] < min_x)
                min_y = v[1] if (!min_y || v[1] < min_y)
                max_x = v[0] if (!max_x || v[0] > max_x)
                max_y = v[1] if (!max_y || v[1] > max_y)
              end
              material = section2d.hatch_by_style(type)

              case layer_preset[:section_layer]
              when 'fixed'
                export_layer = 'Skalp-Section'
              when 'object'
                export_layer = section2d.node.value.layer + layer_preset[:section_suffix]
              when 'material'
                export_layer = material + layer_preset[:section_suffix]
              else
                export_layer = 'Skalp-Section'
              end

              hatched_polygons << Skalp::DXF_export::Hatched_polygon.new(polygon.outerloop, polygon.innerloops, material, section_scale, export_layer) #SkalpHatch.hatchdefs[0]
            end
          end
        else
          puts "node not visible"
        end
      end

      if Sketchup.active_model.pages && Sketchup.active_model.pages.selected_page
        @page ? name = @page.name : name = Sketchup.active_model.pages.selected_page.name #"#{Skalp.translate('active')}_#{Skalp.translate('view')}"
        @page ? object = @page : object = Sketchup.active_model
      else
        name = ''
        object = Sketchup.active_model
      end

      if Skalp.dialog.rearview_status(object)
        Skalp::DXF_export.new(filename, name, hatched_polygons, @model.hiddenlines.forward_lines_result[object], @model.hiddenlines.rear_lines_result[object], [Skalp::inch_to_modelunits(min_x), Skalp::inch_to_modelunits(min_y)], [Skalp::inch_to_modelunits(max_x), Skalp::inch_to_modelunits(max_y)], section_scale, linetype)
      else
        Skalp::DXF_export.new(filename, name, hatched_polygons, @model.hiddenlines.forward_lines_result[object], nil, [Skalp::inch_to_modelunits(min_x), Skalp::inch_to_modelunits(min_y)], [Skalp::inch_to_modelunits(max_x), Skalp::inch_to_modelunits(max_y)], section_scale, linetype)
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
      @page ? type = @page : type = @skpModel
      hide_edges(sectiongroup) if Skalp.dialog.lineweights_status(type)

      normal = Geom::Vector3d.new 0, 0, 1
      result = false

      n = 0

      materials = Sketchup.active_model.materials
      linecolor = materials["Skalp linecolor"]
      transparent = materials["Skalp transparent"]

      sectiongroup.entities.grep(Sketchup::Face).each do |face|
        next unless face.is_a?(Sketchup::Face)

        if n < @material_list.size
          if @material_list[n] != :to_delete
            face.set_attribute('Skalp', 'from_object', @object_list[n].to_s)
            face.set_attribute('Skalp', 'from_sub_object', @sub_object_list[n].to_s)
            face.material = Skalp.create_su_material(@material_list[n].to_s)
            correct_UV_material(face)
            layer = @skpModel.layers[@layer_list[n].to_s]
            face.layer = layer if layer && layer.valid?
            result ? normal != face.normal && face.reverse! : normal = face.normal
            result = true
          else
            show_centerline(face)
          end
        else
          face.material = linecolor
          face.back_material = transparent
          @skpModel.layers["\uFEFF".encode('utf-8') + 'Skalp Pattern Layer - Skalp linecolor'] ? layername = "\uFEFF".encode('utf-8') + 'Skalp Pattern Layer - Skalp linecolor' : layername = 'layer0'

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
    rescue
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

      @page ? type = @page : type = @skpModel
      scale = Skalp.dialog.drawing_scale(type)

      material = face.material
      return unless material && material.class == Sketchup::Material && material.texture

      proportion = material.texture.height / material.texture.width
      if Skalp.skalp_material_info(material, :space) == :modelspace
        ori_scale = scale
      else
        ori_scale = Skalp.skalp_material_info(material, :print_scale).to_f if Skalp.skalp_material_info(material, :print_scale)
      end

      return unless ori_scale
      return if ori_scale == 0.0

      material_layer = "\uFEFF".encode('utf-8') + 'Skalp Pattern Layer - ' + Skalp.skalp_material_info(material, :name)
      scale_correction = Sketchup.active_model.layers[material_layer].get_attribute('Skalp', 'scale_correction') if Sketchup.active_model.layers[material_layer]
      scale_correction = 1.0 unless scale_correction

      aligned = Skalp.aligned(face.material)
      scale == ori_scale ? scaled = false : scaled = true

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

      unless scale == ori_scale || ori_scale == nil || scale == nil

        scaling = Geom::Transformation.scaling (ori_scale / scale)

        p1uv.transform!(scaling)
        p2uv.transform!(scaling)
        p3uv.transform!(scaling)
      end

      pt_array = []
      pt_array[0] = p1
      pt_array[2] = p2

      if aligned
        base_line_endpoint = p1uv + [1, 0, 0]
        rotation = Geom::Transformation.rotation(p1uv, Geom::Vector3d.new(0, 0, 1), Skalp.angle_3_points(base_line_endpoint, p1uv, p2uv)) #angle in radians
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
      face.position_material(material, pt_array, true)

      #handig om de punten te bekijken als er iets mis is:
      #num = -1 ; pt_array.each {|point| @skpModel.entities.add_cpoint(point);@skpModel.entities.add_text("#{num+=1}", point); puts point}
    rescue => e
      Skalp.send_info('UV bug')
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
        #node_value = Skalp.active_model.entity_strings[face.get_attribute('Skalp','from_sub_object')]
        node_value.section2d[@sectionplane]
      end
    end
  end
end
