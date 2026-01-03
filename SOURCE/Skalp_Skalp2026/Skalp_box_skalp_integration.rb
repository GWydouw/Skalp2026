# frozen_string_literal: true

# Skalp SectionBox Integration
# This module handles the generation of Skalp section fills for SectionBox planes.

module Skalp
  module BoxSection
    module SkalpIntegration
      MODEL_GROUP_NAME = "[SkalpSectionBox-Model]"
      SECTIONS_GROUP_NAME = "[SkalpSectionBox-Sections]"

      # A lightweight wrapper to mimic Skalp::SectionPlane
      class VirtualSectionPlane
        attr_reader :skpSectionPlane, :skalpID, :normal, :plane, :name
        attr_accessor :visibility # Added to support visibility inheritance

        def initialize(skp_plane, name, point, normal)
          @skpSectionPlane = skp_plane
          @name = name
          @skalpID = "VIRTUAL_#{skp_plane.entityID}"
          @visibility = nil # Will be injected

          # Use coordinates provided (World Coordinates)
          n = normal.normalize
          d = -((n.x * point.x) + (n.y * point.y) + (n.z * point.z))
          @plane = [n.x, n.y, n.z, d]
          @normal = n
        end

        def valid?
          true
        end

        def virtual?
          true
        end

        def sectionplane_name
          @name
        end

        def transformation
          # Standard Skalp transformation logic to align pattern with plane
          # This returns the transform from Plane -> World Origin (canonical)
          global_zaxis = Geom::Vector3d.new(0, 0, 1)

          # IMPORTANT: We use normal.reverse so the pattern faces OUTWARDS.
          # This also means Skalp's transformation_down (negative Z shift)
          # will move the geometry INWARDS into the box.
          zaxis = @normal.reverse

          dist = @plane[3]
          origin = Geom::Point3d.new(-@plane[0] * dist, -@plane[1] * dist, -@plane[2] * dist)

          if zaxis.parallel? global_zaxis
            xaxis = Geom::Vector3d.new(1, 0, 0)
            yaxis = zaxis.cross xaxis
          else
            xaxis = global_zaxis.cross zaxis
            yaxis = zaxis.cross xaxis
          end

          # This matrix moves canonical XY to the Plane in World Coords
          trans = Geom::Transformation.axes origin, xaxis, yaxis, zaxis
          # Skalp expects the transform that moves Plane -> Origin, so we invert it
          trans.invert!
        end
      end

      # Finds the model group and its cumulative transformation
      def self.get_model_context(entity, current_trans = Geom::Transformation.new)
        return nil unless entity.respond_to?(:entities)

        # Check direct children
        entity.entities.grep(Sketchup::Group).each do |g|
          if g.name.include?(MODEL_GROUP_NAME)
            return { group: g, world_trans: current_trans * g.transformation, parent_world_trans: current_trans }
          end
        end

        # Recurse
        entity.entities.grep(Sketchup::Group).each do |g|
          res = get_model_context(g, current_trans * g.transformation)
          return res if res
        end
        nil
      end

      # Updates all SectionBox section fills
      def self.update_all
        puts "[Skalp BoxSection] update_all started - Same Context Logic"

        return unless Engine.active_box_id
        return unless Skalp.respond_to?(:active_model) && Skalp.active_model
        return unless Skalp.live_section_ON

        # 1. Find the SectionBox Root
        root = Sketchup.active_model.entities.find { |e| e.get_attribute(Skalp::BoxSection::DICTIONARY_NAME, "box_id") == Engine.active_box_id }
        unless root
          puts "[Skalp BoxSection] ERROR: Active box root not found"
          return
        end

        # 2. Find target Model Group and its context
        context = get_model_context(root, root.transformation)
        unless context
          puts "[Skalp BoxSection] ERROR: Could not find #{MODEL_GROUP_NAME}"
          return
        end

        model_group = context[:group]
        # Cumulative world transform of the PARENT of the model group
        parent_world_trans = context[:parent_world_trans]
        world_to_parent = parent_world_trans.inverse

        # 3. Find or create sections group in the SAME context as the model group
        parent_entities = model_group.parent.entities
        sections_group = parent_entities.grep(Sketchup::Group).find { |g| g.name == SECTIONS_GROUP_NAME }
        if sections_group
          sections_group.entities.clear!
          # Sections group should be at Identity relative to its parent
          sections_group.transformation = Geom::Transformation.new
        else
          sections_group = parent_entities.add_group
          sections_group.name = SECTIONS_GROUP_NAME
        end

        # 4. Initialize Visibility (respect scenes/layers/hidden)
        visibility = Skalp::Visibility.new
        visibility.update(Sketchup.active_model.pages.selected_page)

        # 5. Get Plane Data (calculates world coords)
        planes_data = Skalp::BoxSection.get_section_planes_data
        return unless planes_data && !planes_data.empty?

        # 6. Process each plane
        planes_data.each do |pd|
          skp_plane = pd[:plane]
          next unless skp_plane && skp_plane.valid? && skp_plane.active?

          process_single_plane(skp_plane, pd[:name], pd[:original_point], pd[:normal], sections_group, world_to_parent,
                               visibility)
        end

        sections_group.visible = true
      end

      # Optimized update for a single plane (used during dragging)
      def self.update_single_plane(face_name)
        return unless Engine.active_box_id
        return unless Skalp.respond_to?(:active_model) && Skalp.active_model
        return unless Skalp.live_section_ON

        # 1. Find the SectionBox Root
        root = Sketchup.active_model.entities.find { |e| e.get_attribute(Skalp::BoxSection::DICTIONARY_NAME, "box_id") == Engine.active_box_id }
        return unless root

        # 2. Find target Model Group and its context
        context = get_model_context(root, root.transformation)
        return unless context

        model_group = context[:group]
        parent_world_trans = context[:parent_world_trans]
        world_to_parent = parent_world_trans.inverse

        # 3. Find/Create sections group
        parent_entities = model_group.parent.entities
        sections_group = parent_entities.grep(Sketchup::Group).find { |g| g.name == SECTIONS_GROUP_NAME }
        unless sections_group
          sections_group = parent_entities.add_group
          sections_group.name = SECTIONS_GROUP_NAME
        end

        # 4. Initialize Visibility
        visibility = Skalp::Visibility.new
        visibility.update(Sketchup.active_model.pages.selected_page)

        # 5. Get Plane Data and find the specific plane
        planes_data = Skalp::BoxSection.get_section_planes_data(root)
        pd = planes_data.find { |d| d[:name] == face_name }
        return unless pd

        skp_plane = pd[:plane]
        return unless skp_plane && skp_plane.valid? && skp_plane.active?

        # 6. Clear only the specific subgroup if it exists
        old_face_group = sections_group.entities.grep(Sketchup::Group).find { |g| g.name == "#{face_name}-sections" }
        old_face_group.erase! if old_face_group

        # 7. Process
        process_single_plane(skp_plane, face_name, pd[:original_point], pd[:normal], sections_group, world_to_parent,
                             visibility)
      end

      def self.process_single_plane(skp_plane, face_name, world_point, world_normal, sections_group, world_to_parent,
                                    visibility)
        # Create Virtual Plane (World Coords)
        virtual_plane = VirtualSectionPlane.new(skp_plane, "SectionBox-#{face_name}", world_point, world_normal)
        virtual_plane.visibility = visibility

        # Create target group
        face_group = sections_group.entities.add_group
        face_group.name = "#{face_name}-sections"

        # Generate!
        # create_section will set face_group.transformation = T_plane_world
        section_logic = Skalp::Section.new(virtual_plane)

        # Force the visibility into the section instance
        section_logic.instance_variable_set(:@visibility, visibility)

        # Generate geometry
        section_logic.create_section(face_group)

        # KEY STEP: Correct the transformation
        # Currently: World_Pos = Container_World * face_group.transformation
        # Here face_group is child of the Parent of [SkalpSectionBox-Model].
        # So: World_Pos = Parent_World * face_group.transformation
        # We need: face_group.transformation = Parent_World.inverse * World_Plane_Target
        face_group.transformation = world_to_parent * face_group.transformation

        cnt = face_group.entities.length
        puts "[Skalp BoxSection]   #{face_name}: #{cnt} entities."
        face_group.visible = true
      rescue StandardError => e
        puts "[Skalp BoxSection] Error processing #{face_name}: #{e.message}"
        puts e.backtrace.first(3).join("\n")
      end

      def self.cleanup
        root = Sketchup.active_model.entities.find { |e| e.get_attribute(Skalp::BoxSection::DICTIONARY_NAME, "box_id") == Engine.active_box_id }
        return unless root

        context = get_model_context(root)
        return unless context

        model_group = context[:group]
        sections_group = model_group.parent.entities.grep(Sketchup::Group).find { |g| g.name == SECTIONS_GROUP_NAME }
        sections_group.erase! if sections_group
      end
    end
  end
end
