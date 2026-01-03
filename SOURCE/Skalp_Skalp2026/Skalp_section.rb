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
      transparent = materials["Skalp transparent"]

      Skalp.linestyle_layer_visible
      Skalp.active_model.entity_strings = {}

      return unless @section2Ds.size > 0

      type = @page || @skpModel
      use_lineweight = Skalp.dialog.lineweights_status(type)
      scale = Skalp.dialog.drawing_scale(type)
      normal = Geom::Vector3d.new 0, 0, 1

      # PERFORMANCE FIX: Disable observers during mass entity creation
      observer_status = Skalp.active_model.observer_active
      Skalp.active_model.observer_active = false

      begin
        sectiongroup.entities.build do |builder|
          if use_lineweight
            # -----------------------------------------------------------------------
            # ADVANCED RENDER PIPELINE (Priority, Unify, Color)
            # -----------------------------------------------------------------------
            # Map: priority => [section2d, ...]
            sections_by_priority = Hash.new { |h, k| h[k] = [] }
            # Map: priority => { color => [section2d, ...] }
            lineweight_groups_by_priority = Hash.new { |h, k| h[k] = Hash.new { |hh, kk| hh[kk] = [] } }
            active_priorities = []

            @section2Ds.each do |section2d|
              next unless section2d.node.value.visibility

              # Determine Priority (-2 to +2, default 0)
              mat = skalp_style_material(section2d, type)
              su_mat = materials[mat] if mat
              priority = 0
              if su_mat
                p_val = Skalp.skalp_material_info(su_mat, :drawing_priority)
                priority = p_val.to_i if p_val
              end

              sections_by_priority[priority] << section2d
              active_priorities << priority unless active_priorities.include?(priority)

              # Determine Line Color
              line_color_str = nil
              line_color_str = Skalp.skalp_material_info(su_mat, :section_line_color) if su_mat
              line_color_str = "Skalp linecolor" if line_color_str.nil? || line_color_str.empty?

              lineweight_groups_by_priority[priority][line_color_str] << section2d

              # Entity Strings
              unless Skalp.active_model.entity_strings[section2d.node.value.top_parent.value.to_s]
                Skalp.active_model.entity_strings[section2d.node.value.top_parent.value.to_s] =
                  section2d.node.value.top_parent.value
              end
              unless Skalp.active_model.entity_strings[section2d.node.value.to_s]
                Skalp.active_model.entity_strings[section2d.node.value.to_s] = section2d.node.value
              end
            end

            active_priorities.sort!

            active_priorities.each do |priority|
              current_sections = sections_by_priority[priority]
              next if current_sections.empty?

              z_offset = priority * 0.001
              transform_vec = Geom::Vector3d.new(0, 0, z_offset)
              has_offset = z_offset.abs > 0.000001

              # A. UNIFY LOGIC
              by_material = Hash.new { |h, k| h[k] = [] }
              current_sections.each do |sec|
                mat = skalp_style_material(sec, type)
                by_material[mat] << sec
              end

              # B. CALCULATE LINEWEIGHT MASK ONCE PER PRIORITY (not per material!)
              # This is the KEY optimization: mask is priority-specific, not material-specific
              slice_mask = Skalp::MultiPolygon.new
              lineweight_groups_by_priority[priority].each do |_, group_secs|
                by_mat_mask = Hash.new { |h, k| h[k] = [] }
                group_secs.each { |sec| by_mat_mask[skalp_style_material(sec, type)] << sec }

                by_mat_mask.each do |m_name, m_sections|
                  s_mat = materials[m_name]
                  u = s_mat ? Skalp.skalp_material_info(s_mat, :unify) == true : false
                  width = get_lineweight_width(m_sections.first, type)
                  next unless width > 0.0

                  if u && m_sections.size > 1
                    u_poly = Skalp::MultiPolygon.new
                    m_sections.each { |sec| u_poly.union!(sec.to_mpoly) }
                    slice_mask.union!(u_poly.outline(width * scale))
                  else
                    m_sections.each { |sec| slice_mask.union!(sec.to_mpoly.outline(width * scale)) }
                  end
                end
              end

              centerline_loops = []

              # C. PROCESS EACH MATERIAL WITH THE SHARED MASK
              by_material.each do |mat_name, sections|
                su_mat = materials[mat_name]
                unify = su_mat ? Skalp.skalp_material_info(su_mat, :unify) == true : false
                final_polygons = []

                if unify && sections.size > 1
                  union_poly = Skalp::MultiPolygon.new
                  sections.each { |sec| union_poly.union!(sec.to_mpoly) }
                  contributing_ids = sections.map { |sec| sec.node.value.to_s }.join(",")
                  union_poly.polygons.polygons.each do |p|
                    final_polygons << { poly: p, ids: contributing_ids, sec: sections.first }
                  end
                else
                  sections.each do |sec|
                    sec_id = sec.node.value.to_s
                    sec.polygons.each do |p|
                      final_polygons << { poly: p, ids: sec_id, sec: sec }
                    end
                  end
                end

                # D. GENERATE FACES (apply pre-calculated mask)
                final_polygons.each do |data|
                  polygon = data[:poly]
                  current_ids = data[:ids]
                  current_section = data[:sec]

                  # Apply the pre-calculated mask
                  poly_to_process = [polygon]
                  unless slice_mask.to_a.empty?
                    mp = Skalp::MultiPolygon.new(polygon.to_a)
                    mp.difference!(slice_mask)
                    poly_to_process = mp.polygons.polygons
                  end

                  centerline_data = { loop: polygon.outerloop, section: current_section }
                  centerline_loops << centerline_data
                  polygon.innerloops.each do |il|
                    centerline_loops << { loop: il, section: current_section }
                  end

                  poly_to_process.each_with_index do |p, pp_idx|
                    # puts "[PROFILE] Adding face #{pp_idx}..." if defined?(DEBUG) && DEBUG
                    outerloop = if has_offset
                                  p.outerloop.vertices.map do |v|
                                    v.offset(transform_vec)
                                  end
                                else
                                  p.outerloop.vertices
                                end
                    innerloops = []
                    p.innerloops.each do |loop|
                      innerloops << (has_offset ? loop.vertices.map { |v| v.offset(transform_vec) } : loop.vertices)
                    end

                    begin
                      face = if innerloops.empty?
                               builder.add_face(outerloop)
                             else
                               builder.add_face(outerloop,
                                                holes: innerloops)
                             end

                      face.set_attribute("Skalp", "from_sub_object", current_ids)
                      if current_ids.include?(",")
                        # Unified: mixed
                        face.set_attribute("Skalp", "from_object", "Unified")
                      else
                        # Single object: use top parent
                        face.set_attribute("Skalp", "from_object", current_section.node.value.top_parent.value.to_s)
                      end
                      face.material = su_mat = Skalp.create_su_material(mat_name)
                      correct_UV_material(face)
                      l_name = sections.first.layer_by_style(type, mat_name)
                      layer = @skpModel.layers[l_name]
                      face.layer = layer if layer && layer.valid?
                      face.normal.dot(normal) < 0 ? face.reverse! : nil

                      pattern_type = Skalp.skalp_material_info(su_mat, :pattern_type)
                      if pattern_type == "cross"
                        draw_procedural_cross_hatch(face, sectiongroup, mat_name)
                      elsif pattern_type == "insulation"
                        insulation_style = Skalp.skalp_material_info(su_mat, :insulation_style)
                        draw_procedural_insulation(face, sectiongroup, mat_name, insulation_style)
                      end
                    rescue ArgumentError
                    end
                  end
                end
              end

              has_offset = z_offset.abs > 0.000001

              # A. UNIFY LOGIC
              by_material = Hash.new { |h, k| h[k] = [] }
              current_sections.each do |sec|
                mat = skalp_style_material(sec, type)
                by_material[mat] << sec
              end

              # B. CALCULATE LINEWEIGHT MASK ONCE PER PRIORITY (not per material!)
              # This is the KEY optimization: mask is priority-specific, not material-specific
              slice_mask = Skalp::MultiPolygon.new
              lineweight_groups_by_priority[priority].each do |_, group_secs|
                by_mat_mask = Hash.new { |h, k| h[k] = [] }
                group_secs.each { |sec| by_mat_mask[skalp_style_material(sec, type)] << sec }

                by_mat_mask.each do |m_name, m_sections|
                  s_mat = materials[m_name]
                  u = s_mat ? Skalp.skalp_material_info(s_mat, :unify) == true : false
                  width = get_lineweight_width(m_sections.first, type)
                  next unless width > 0.0

                  if u && m_sections.size > 1
                    u_poly = Skalp::MultiPolygon.new
                    m_sections.each { |sec| u_poly.union!(sec.to_mpoly) }
                    slice_mask.union!(u_poly.outline(width * scale))
                  else
                    m_sections.each { |sec| slice_mask.union!(sec.to_mpoly.outline(width * scale)) }
                  end
                end
              end

              centerline_loops = []

              # C. PROCESS EACH MATERIAL WITH THE SHARED MASK
              by_material.each do |mat_name, sections|
                su_mat = materials[mat_name]
                unify = su_mat ? Skalp.skalp_material_info(su_mat, :unify) == true : false
                final_polygons = []

                if unify && sections.size > 1
                  union_poly = Skalp::MultiPolygon.new
                  sections.each { |sec| union_poly.union!(sec.to_mpoly) }
                  contributing_ids = sections.map { |sec| sec.node.value.to_s }.join(",")
                  union_poly.polygons.polygons.each do |p|
                    final_polygons << { poly: p, ids: contributing_ids, sec: sections.first }
                  end
                else
                  sections.each do |sec|
                    sec_id = sec.node.value.to_s
                    sec.polygons.each do |p|
                      final_polygons << { poly: p, ids: sec_id, sec: sec }
                    end
                  end
                end

                # D. GENERATE FACES (apply pre-calculated mask)
                final_polygons.each do |data|
                  polygon = data[:poly]
                  current_ids = data[:ids]
                  current_section = data[:sec]

                  # Apply the pre-calculated mask
                  poly_to_process = [polygon]
                  unless slice_mask.to_a.empty?
                    mp = Skalp::MultiPolygon.new(polygon.to_a)
                    mp.difference!(slice_mask)
                    poly_to_process = mp.polygons.polygons
                  end

                  centerline_data = { loop: polygon.outerloop, section: current_section }
                  centerline_loops << centerline_data
                  polygon.innerloops.each do |il|
                    centerline_loops << { loop: il, section: current_section }
                  end

                  poly_to_process.each_with_index do |p, pp_idx|
                    # puts "[PROFILE] Adding face #{pp_idx}..." if defined?(DEBUG) && DEBUG
                    outerloop = if has_offset
                                  p.outerloop.vertices.map do |v|
                                    v.offset(transform_vec)
                                  end
                                else
                                  p.outerloop.vertices
                                end
                    innerloops = []
                    p.innerloops.each do |loop|
                      innerloops << (has_offset ? loop.vertices.map { |v| v.offset(transform_vec) } : loop.vertices)
                    end

                    begin
                      face = if innerloops.empty?
                               builder.add_face(outerloop)
                             else
                               builder.add_face(outerloop,
                                                holes: innerloops)
                             end

                      face.set_attribute("Skalp", "from_sub_object", current_ids)
                      if current_ids.include?(",")
                        # Unified: mixed
                        face.set_attribute("Skalp", "from_object", "Unified")
                      else
                        # Single object: use top parent
                        face.set_attribute("Skalp", "from_object", current_section.node.value.top_parent.value.to_s)
                      end
                      face.material = su_mat = Skalp.create_su_material(mat_name)
                      correct_UV_material(face)
                      l_name = sections.first.layer_by_style(type, mat_name)
                      layer = @skpModel.layers[l_name]
                      face.layer = layer if layer && layer.valid?
                      face.normal.dot(normal) < 0 ? face.reverse! : nil

                      pattern_type = Skalp.skalp_material_info(su_mat, :pattern_type)
                      if pattern_type == "cross"
                        draw_procedural_cross_hatch(face, sectiongroup, mat_name)
                      elsif pattern_type == "insulation"
                        insulation_style = Skalp.skalp_material_info(su_mat, :insulation_style)
                        draw_procedural_insulation(face, sectiongroup, mat_name, insulation_style)
                      end
                    rescue ArgumentError
                    end
                  end
                end
              end

              lineweight_groups_by_priority[priority].each do |color_name, group_sections|
                group_mask = Skalp::MultiPolygon.new

                # Group segments by material to handle Unify
                by_mat = Hash.new { |h, k| h[k] = [] }
                group_sections.each do |sec|
                  mat = skalp_style_material(sec, type)
                  by_mat[mat] << sec
                end

                by_mat.each do |mat_name, sections|
                  su_mat = materials[mat_name]
                  unify = su_mat ? Skalp.skalp_material_info(su_mat, :unify) == true : false
                  w = get_lineweight_width(sections.first, type)
                  next unless w > 0.0

                  if unify && sections.size > 1
                    union_poly = Skalp::MultiPolygon.new
                    sections.each { |sec| union_poly.union!(sec.to_mpoly) }
                    group_mask.union!(union_poly.outline(w * scale))
                  else
                    sections.each do |sec|
                      group_mask.union!(sec.to_mpoly.outline(w * scale))
                    end
                  end
                end

                all_polys_to_draw = []

                # If we have unified sections in this specific color group?
                # Note: group_sections can contain mixed materials if they share the same Line Color!
                # So we can't assume GLOBAL unification. We must continue to respect by_material grouping.

                # Re-iterate by material to decide drawing strategy
                by_mat.each do |mat_name, sections|
                  su_mat = materials[mat_name]
                  unify = su_mat ? Skalp.skalp_material_info(su_mat, :unify) == true : false
                  w = get_lineweight_width(sections.first, type)
                  next unless w > 0.0

                  if unify && sections.size > 1
                    # 1. Calculate the Unified Mask for this material
                    union_poly = Skalp::MultiPolygon.new
                    sections.each { |sec| union_poly.union!(sec.to_mpoly) }
                    unified_outline = union_poly.outline(w * scale)

                    # 2. Add to drawing list directly (No intersection needed if it's the source!)
                    # Wait, group_mask is the Union of ALL materials in this color group.
                    # If we just draw `unified_outline`, it might overlap with other materials in the same color group?
                    # Since they are same color, overlap is fine visually!
                    # BUT z-fighting? No, same plane.

                    # Actually, let's keep it simple:
                    # Calculate the exact shape for these sections.
                    # For Unify: It is the Outline of the Union.
                    all_polys_to_draw << unified_outline
                  else
                    # For Non-Unify:
                    # It is the Union of Outlines (which mimics individual outlines merged)
                    # But we previously did: (Section INTERSECT Mask) + (Mask DIFF Sections)
                    # This was to handle "Inner" vs "Outer".

                    # Simpler approach for same-color group:
                    # Just draw the outline of each section!
                    sections.each do |sec|
                      all_polys_to_draw << sec.to_mpoly.outline(w * scale)
                    end
                  end
                end

                # Improved naming: Skalp linecolor for black, Skalp linecolor - [color] for others
                line_mat_name = if ["rgb(0,0,0)", "rgb(0, 0, 0)"].include?(color_name)
                                  "Skalp linecolor"
                                else
                                  "Skalp linecolor - #{color_name}"
                                end

                line_mat = Skalp.create_su_material(line_mat_name) || materials["Skalp linecolor"]

                # Flatten and draw
                all_polys_to_draw.each do |mpoly|
                  mpoly.polygons.polygons.each do |p|
                    next if p.outerloop.vertices.size < 3

                    draw_lineweight_face(builder, p, line_mat, transparent, has_offset, transform_vec, color_name)
                  end
                end

                # Removed previous complex drawing loop
              end

              # D. CENTERLINES
              centerline_loops.each do |data|
                loop = data[:loop]
                section = data[:section]

                verts = has_offset ? loop.vertices.map { |v| v.offset(transform_vec) } : loop.vertices
                for n in 0..verts.size - 1
                  pt1 = verts[n - 1]
                  pt2 = verts[n]
                  next unless pt1.distance(pt2) > 0.01

                  edge = builder.add_edge(pt1, pt2)

                  # Assign Material for Colored Edges
                  if section
                    # Re-derive color material name
                    c_name = get_section_line_color_name(section, type)
                    mat_line_name = if ["rgb(0,0,0)", "rgb(0, 0, 0)"].include?(c_name)
                                      "Skalp linecolor"
                                    else
                                      "Skalp linecolor - #{c_name}"
                                    end
                    l_mat = Skalp.create_su_material(mat_line_name) || materials["Skalp linecolor"]
                    edge.material = l_mat
                  end

                  edge.smooth = edge.soft = edge.hidden = false
                end
              rescue ArgumentError
              end
            end # priority loop

          else
            # -----------------------------------------------------------------------
            # LEGACY RENDER PIPELINE (No Lineweight)
            # -----------------------------------------------------------------------
            @section2Ds.each do |section2d|
              next unless section2d.node.value.visibility

              # Populate strings (same as before)
              unless Skalp.active_model.entity_strings[section2d.node.value.top_parent.value.to_s]
                Skalp.active_model.entity_strings[section2d.node.value.top_parent.value.to_s] =
                  section2d.node.value.top_parent.value
              end
              unless Skalp.active_model.entity_strings[section2d.node.value.to_s]
                Skalp.active_model.entity_strings[section2d.node.value.to_s] = section2d.node.value
              end

              section2d.polygons.each do |polygon|
                outerloop = polygon.outerloop.vertices
                innerloops = []
                polygon.innerloops.each { |loop| innerloops << loop.vertices }

                begin
                  face = if innerloops.empty?
                           builder.add_face(outerloop)
                         else
                           builder.add_face(outerloop,
                                            holes: innerloops)
                         end
                  face.set_attribute("Skalp", "from_object", section2d.node.value.top_parent.value.to_s)
                  face.set_attribute("Skalp", "from_sub_object", section2d.node.value.to_s)
                  materialname = section2d.hatch_by_style(type).to_s
                  face.material = su_mat = Skalp.create_su_material(materialname)
                  correct_UV_material(face)
                  layer = @skpModel.layers[section2d.layer_by_style(type, materialname)]
                  face.layer = layer if layer && layer.valid?
                  normal.dot(face.normal) < 0 ? face.reverse! : nil

                  if su_mat
                    pattern_type = Skalp.skalp_material_info(su_mat, :pattern_type)
                    if pattern_type == "cross"
                      draw_procedural_cross_hatch(face, sectiongroup, materialname)
                    elsif pattern_type == "insulation"
                      insulation_style = Skalp.skalp_material_info(su_mat, :insulation_style)
                      draw_procedural_insulation(face, sectiongroup, materialname, insulation_style)
                    end
                  end
                rescue ArgumentError
                end
              end
            end
          end
        end # builder
      ensure
        Skalp.active_model.observer_active = observer_status
      end

      transformation_inverse = @sectionplane.transformation.inverse
      place_rear_view_lines_in_model(sectiongroup) if Skalp.dialog.style_settings(@page)[:rearview_status]
      @model.section_result_group.locked = true

      return unless sectiongroup.valid?

      sectiongroup.transform! transformation_inverse * Skalp.transformation_down
    end

    def get_lineweight_width(section2d, type)
      mat_name = skalp_style_material(section2d, type)
      su_mat = Sketchup.active_model.materials[mat_name]
      return 0.0 unless su_mat

      val = Skalp.skalp_material_info(su_mat, :section_cut_width)
      val ? val.to_f : 0.0
    end

    def get_section_line_color_name(section2d, type)
      mat_name = skalp_style_material(section2d, type)
      su_mat = Sketchup.active_model.materials[mat_name]
      return "rgb(0,0,0)" unless su_mat

      Skalp.skalp_material_info(su_mat, :section_line_color) || "rgb(0,0,0)"
    end

    def draw_lineweight_face(builder, polygon, material, back_material, has_offset, transform_vec, layer_suffix)
      outerloop = if has_offset
                    polygon.outerloop.vertices.map do |v|
                      v.offset(transform_vec)
                    end
                  else
                    polygon.outerloop.vertices
                  end
      innerloops = []
      polygon.innerloops.each do |loop|
        innerloops << (has_offset ? loop.vertices.map { |v| v.offset(transform_vec) } : loop.vertices)
      end

      begin
        face = innerloops.empty? ? builder.add_face(outerloop) : builder.add_face(outerloop, holes: innerloops)
        face.material = material
        face.back_material = back_material

        l_name = "\uFEFF".encode("utf-8") + "Skalp Pattern Layer - " + layer_suffix.to_s
        # Ensure fallback if specific color layer doesn't exist? (User request: Use legacy name if standard?)
        # If suffix is "Skalp linecolor", it matches standard.

        face.layer = @skpModel.layers[l_name] ? l_name : "layer0"

        face.normal.dot(Geom::Vector3d.new(0, 0, 1)) < 0 ? face.reverse! : nil
        face.edges.each do |e|
          e.smooth = true
          e.soft = true
          e.hidden = true
        end
      rescue StandardError
      end
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
      place_rear_view_lines_in_model(sectiongroup) if Skalp.dialog.style_settings(type)[:rearview_status]
      @model.section_result_group.locked = true
    end

    def place_rear_view_lines_in_model(target_group = nil)
      target_group ||= @sectiongroup
      # puts "[DEBUG] place_rear_view_lines_in_model for: #{target_group}"
      return unless target_group && target_group.valid?
      return unless Skalp.models[@skpModel]

      observer_status = Skalp.models[@skpModel].observer_active
      Skalp.models[@skpModel].observer_active = false

      type = @page || @skpModel
      # puts "[DEBUG] type: #{type.is_a?(Sketchup::Page) ? type.name : 'Model'}"

      return unless @sectionplane && @sectionplane.respond_to?(:skalpID)

      id = @sectionplane.skalpID
      # puts "[DEBUG] sectionplane id: #{id}"

      active_page = type
      # puts "[DEBUG] active_page calculated[#{active_page}]: #{@model.hiddenlines.calculated[active_page]}"
      if id == @model.hiddenlines.calculated[active_page]
        # puts "[DEBUG] Exact match found for active_page"
        place_lines_or_definition_in_model(active_page, target_group)
      elsif id == @model.hiddenlines.calculated[@skpModel]
        # Fallback: check if calculated for model (live section)
        puts "[DEBUG] Match found for Model fallback"
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
          puts "[DEBUG] Match found for other page: #{type.name}"
          place_lines_or_definition_in_model(type, target_group, true)
        else
          # puts "[DEBUG] NO match found in calculated hash"
          # Fallback: use saved rear_view_definitions if available (for freshly loaded models)
          # Check multiple possible keys since definitions may be keyed by Page, Model, or selected_page
          selected_page = @skpModel.pages.selected_page
          # puts "[DEBUG] Checking rear_view_definitions keys: active_page=#{active_page.class}, selected_page=#{selected_page&.name}, Model"
          # puts "[DEBUG] rear_view_definitions keys: #{@model.hiddenlines.rear_view_definitions.keys.map do |k|
          #   k.is_a?(Sketchup::Page) ? k.name : k.class.to_s
          # end}"

          if @model.hiddenlines.rear_view_definitions[active_page] &&
             @model.hiddenlines.rear_view_definitions[active_page].valid? &&
             @model.hiddenlines.rear_view_definitions[active_page].entities.size > 0
            # puts "[DEBUG] Using saved rear_view_definition for active_page"
            place_lines_or_definition_in_model(active_page, target_group)
          elsif selected_page && @model.hiddenlines.rear_view_definitions[selected_page] &&
                @model.hiddenlines.rear_view_definitions[selected_page].valid? &&
                @model.hiddenlines.rear_view_definitions[selected_page].entities.size > 0
            puts "[DEBUG] Using saved rear_view_definition for selected_page: #{selected_page.name}"
            place_lines_or_definition_in_model(selected_page, target_group)
          elsif @model.hiddenlines.rear_view_definitions[@skpModel] &&
                @model.hiddenlines.rear_view_definitions[@skpModel].valid? &&
                @model.hiddenlines.rear_view_definitions[@skpModel].entities.size > 0
            puts "[DEBUG] Using saved rear_view_definition for Model fallback"
            place_lines_or_definition_in_model(@skpModel, target_group)
          else
            # No valid definition found for this page - don't use definitions from other pages!
            # The lines will need to be recalculated for this page
            puts "[DEBUG] No rear_view_definition found for current page (#{selected_page&.name || 'Model'})"
            # puts "[DEBUG] Available definitions are for: #{@model.hiddenlines.rear_view_definitions.keys.select do |k|
            #   k.is_a?(Sketchup::Page)
            # end.map(&:name).join(', ')}"
            # puts "[DEBUG] Rearview lines will need to be recalculated for this page"
          end

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

      # Fallback: search for any valid definition with entities
      unless definition
        @model.hiddenlines.rear_view_definitions.each_value do |def_candidate|
          if def_candidate && def_candidate.valid? && def_candidate.entities.size > 0
            definition = def_candidate
            break
          end
        end
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
      scale = Skalp.dialog.drawing_scale(type)
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
      type = @page || @skpModel
      scale = Skalp.dialog.drawing_scale(type)

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
          # puts "node not visible"
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
      face.position_material(material, pt_array, true)

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

    def draw_procedural_cross_hatch(face, parent, mat_name)
      return unless face.valid? && face.outer_loop.edges.size == 4

      su_mat = Sketchup.active_model.materials[mat_name]
      return unless su_mat

      pattern_info = Skalp.get_pattern_info(su_mat)
      return unless pattern_info

      # Use dedicated hatch line width from pattern_info, not global section_cut_width
      pen_str = pattern_info[:pen] || "0.18 mm"
      width = Skalp.mm_or_pts_to_inch(pen_str)
      type = @page || @skpModel
      scale = Skalp.dialog.drawing_scale(type)
      model_width = (width * scale)

      line_mat = get_procedural_line_material(su_mat, pattern_info)
      layer = face.layer

      v = face.outer_loop.vertices
      normal = face.normal

      add_procedural_segment(parent, v[0].position, v[2].position, model_width, normal, line_mat, layer)
      add_procedural_segment(parent, v[1].position, v[3].position, model_width, normal, line_mat, layer)
    end

    def draw_procedural_insulation(face, parent, mat_name, style)
      return unless face.valid?

      su_mat = Sketchup.active_model.materials[mat_name]
      return unless su_mat

      pattern_info = Skalp.get_pattern_info(su_mat)
      return unless pattern_info

      # Use dedicated hatch line width from pattern_info, not global section_cut_width
      pen_str = pattern_info[:pen] || "0.18 mm"
      width = Skalp.mm_or_pts_to_inch(pen_str)
      type = @page || @skpModel
      scale = Skalp.dialog.drawing_scale(type)
      model_width = (width * scale)

      line_mat = get_procedural_line_material(su_mat, pattern_info)
      layer = face.layer

      # Find two longest parallel edges
      edges = face.outer_loop.edges.sort_by(&:length).reverse
      return if edges.size < 2

      e1 = edges[0]
      e2 = edges.find { |e| e != e1 && e.line[1].parallel?(e1.line[1]) }
      return unless e2

      # Centerline calculation
      p1a = e1.start.position
      p1b = e1.end.position
      p2a = e2.project_point(p1a)
      p2b = e2.project_point(p1b)

      m1 = Geom.linear_combination(0.5, p1a, 0.5, p2a)
      m2 = Geom.linear_combination(0.5, p1b, 0.5, p2b)
      center_vec = m2 - m1
      return if center_vec.length < 0.01

      thickness = p1a.distance(p2a)
      steps = (center_vec.length / (thickness * 0.8)).to_i
      steps = 1 if steps < 1

      perp_vec = (p2a - p1a).normalize
      normal = face.normal

      cy = m1.dup
      step_vec = center_vec.clone
      step_vec.length = center_vec.length / steps

      if style == "scurve"
        divs = 10
        (0...steps).each do |s|
          (0...divs).each do |d|
            t = d.to_f / divs
            p_start = Geom.linear_combination(1.0 - t, cy, t, cy + step_vec)
            p_start.offset!(perp_vec, Math.sin(t * Math::PI) * thickness * 0.4)

            t_next = (d + 1).to_f / divs
            p_end = Geom.linear_combination(1.0 - t_next, cy, t_next, cy + step_vec)
            p_end.offset!(perp_vec, Math.sin(t_next * Math::PI) * thickness * 0.4)

            add_procedural_segment(parent, p_start, p_end, model_width, normal, line_mat, layer)
          end
          cy.offset!(step_vec)
        end
      else # zigzag
        (0...steps).each do |i|
          p_start = cy.dup
          p_start.offset!(perp_vec, i.even? ? -thickness * 0.4 : thickness * 0.4)
          p_end = cy + step_vec
          p_end.offset!(perp_vec, i.even? ? thickness * 0.4 : -thickness * 0.4)
          add_procedural_segment(parent, p_start, p_end, model_width, normal, line_mat, layer)
          cy.offset!(step_vec)
        end
      end
    end

    def get_procedural_line_material(su_mat, pattern_info)
      # Use dedicated hatch line color from pattern_info, not global section_line_color
      color_str = pattern_info[:line_color] || "rgb(0,0,0)"
      color_str = "rgb(0,0,0)" if color_str.nil? || color_str.empty?

      line_mat_name = if ["rgb(0,0,0)", "rgb(0, 0, 0)"].include?(color_str)
                        "Skalp linecolor"
                      else
                        "Skalp linecolor - #{color_str}"
                      end
      Skalp.create_su_material(line_mat_name)
    end

    def add_procedural_segment(parent, p1, p2, width, normal, material, layer)
      if width > 0.001
        vec = (p2 - p1).normalize
        begin
          perp = vec.cross(normal).normalize
        rescue StandardError
          # Fallback if points are too close
          perp = Geom::Vector3d.new(1, 0, 0)
        end
        half_width = width / 2.0

        pts = [
          p1.offset(perp, half_width),
          p1.offset(perp, -half_width),
          p2.offset(perp, -half_width),
          p2.offset(perp, half_width)
        ]
        f = parent.entities.add_face(pts)
        if f
          f.material = material if material
          f.back_material = material if material
          f.layer = layer if layer
          f.edges.each { |e| e.hidden = true }
        end
      else
        e = parent.entities.add_line(p1, p2)
        if e
          e.material = material if material
          e.layer = layer if layer
        end
      end
    end
  end
end
