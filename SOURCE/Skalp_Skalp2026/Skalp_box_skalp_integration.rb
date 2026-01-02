# frozen_string_literal: true

# Skalp SectionBox Integration
# This module handles the generation of Skalp section fills for SectionBox planes.
# It temporarily registers SectionBox planes with Skalp to generate sections.

module Skalp
  module BoxSection
    module SkalpIntegration
      SECTIONS_GROUP_NAME = "[SkalpSectionBox]-sections"

      @@temp_sectionplane = nil

      # Updates all SectionBox section fills by triggering Skalp's live section
      def self.update_all
        puts "[Skalp BoxSection] update_all called"

        unless Engine.active_box_id
          puts "[Skalp BoxSection] No active box ID"
          return
        end

        unless Skalp.respond_to?(:active_model) && Skalp.active_model
          puts "[Skalp BoxSection] No Skalp active model"
          return
        end

        unless Skalp.live_section_ON
          puts "[Skalp BoxSection] Live section is OFF"
          return
        end

        planes_data = Skalp::BoxSection.get_section_planes_data
        puts "[Skalp BoxSection] Planes data: #{planes_data&.size || 0} planes"

        unless planes_data && !planes_data.empty?
          puts "[Skalp BoxSection] No planes data"
          return
        end

        # Get the outermost/active section plane (the one actually cutting the model)
        active_plane_data = planes_data.find { |pd| pd[:plane]&.active? }
        puts "[Skalp BoxSection] Active plane data: #{active_plane_data ? active_plane_data[:name] : 'NONE'}"

        # If no active plane found, try the first one
        active_plane_data ||= planes_data.first

        unless active_plane_data
          puts "[Skalp BoxSection] No active plane data found"
          return
        end

        active_skp_plane = active_plane_data[:plane]
        puts "[Skalp BoxSection] Active SketchUp plane: #{active_skp_plane&.name}, valid: #{active_skp_plane&.valid?}"

        unless active_skp_plane && active_skp_plane.valid?
          puts "[Skalp BoxSection] Invalid section plane"
          return
        end

        begin
          # Check if this plane is already registered with Skalp
          existing_sp = Skalp.active_model.sectionplanes[active_skp_plane]
          puts "[Skalp BoxSection] Existing Skalp::SectionPlane: #{existing_sp ? 'YES' : 'NO'}"

          if existing_sp
            # Already registered, just trigger update
            puts "[Skalp BoxSection] Triggering calculate_section on existing"
            existing_sp.calculate_section(true)
          else
            # Temporarily register the SectionBox plane with Skalp
            puts "[Skalp BoxSection] Registering temp sectionplane"
            register_temp_sectionplane(active_skp_plane)
          end
        rescue StandardError => e
          puts "[Skalp BoxSection] Error in update_all: #{e.message}"
          puts e.backtrace.first(5).join("\n")
        end
      end

      # Registers a SectionBox plane temporarily with Skalp for section generation
      def self.register_temp_sectionplane(skp_plane)
        puts "[Skalp BoxSection] register_temp_sectionplane called"

        unless skp_plane && skp_plane.valid?
          puts "[Skalp BoxSection] Invalid skp_plane"
          return
        end

        unless Skalp.active_model
          puts "[Skalp BoxSection] No Skalp.active_model in register_temp"
          return
        end

        # Store original make_scene setting and disable it
        original_make_scene = Skalp.active_model.make_scene
        puts "[Skalp BoxSection] Original make_scene: #{original_make_scene}"
        Skalp.active_model.make_scene = false

        begin
          # Give the plane a temporary Skalp name if it doesn't have one
          unless skp_plane.get_attribute("Skalp", "sectionplane_name")
            face_name = skp_plane.name.gsub("[SkalpSectionBox]-", "").capitalize
            skp_plane.set_attribute("Skalp", "sectionplane_name", "SectionBox-#{face_name}")
            puts "[Skalp BoxSection] Set sectionplane_name: SectionBox-#{face_name}"
          end

          # Register the plane with Skalp (this creates a Skalp::SectionPlane object)
          puts "[Skalp BoxSection] Calling add_sectionplane..."
          Skalp.active_model.add_sectionplane(skp_plane, true)
          puts "[Skalp BoxSection] add_sectionplane completed"

          # Store reference for cleanup
          @@temp_sectionplane = skp_plane

          # Verify registration
          sp = Skalp.active_model.sectionplanes[skp_plane]
          puts "[Skalp BoxSection] Registered: #{sp ? 'YES' : 'NO'}"

          if sp
            puts "[Skalp BoxSection] Triggering calculate_section..."
            sp.calculate_section(true)
            puts "[Skalp BoxSection] calculate_section completed"
          end
        rescue StandardError => e
          puts "[Skalp BoxSection] Error registering temp sectionplane: #{e.message}"
          puts e.backtrace.first(5).join("\n")
        ensure
          # Restore original make_scene setting
          Skalp.active_model.make_scene = original_make_scene
        end
      end

      # Updates a single SectionBox section fill by face name
      def self.update_single(face_name)
        # For now, just trigger a full update
        # Optimized single-face updates can be implemented later
        update_all
      end

      # Cleans up temporary Skalp registrations and section groups
      def self.cleanup
        return unless Skalp.respond_to?(:active_model) && Skalp.active_model

        begin
          # Unregister any temporary SectionBox planes from Skalp
          if @@temp_sectionplane && Skalp.active_model.sectionplanes
            sp = Skalp.active_model.sectionplanes[@@temp_sectionplane]
            if sp
              # Remove observer to prevent issues
              begin
                sp.remove_observer
              rescue StandardError
                nil
              end

              # Remove from Skalp's registry (but don't delete the SketchUp plane)
              Skalp.active_model.sectionplanes.delete(@@temp_sectionplane)

              # Clean up any section groups created for this plane
              if Skalp.active_model.respond_to?(:section_result_group) &&
                 Skalp.active_model.section_result_group&.valid?
                section_group = Skalp.active_model.section_result_group
                section_group.locked = false
                section_group.entities.grep(Sketchup::Group).each do |g|
                  g.erase! if (g.get_attribute("Skalp", "ID") == sp&.skalpID) && g.valid?
                end
                section_group.locked = true
              end
            end
          end

          @@temp_sectionplane = nil

          puts "[Skalp BoxSection] Cleanup completed" if $DEBUG
        rescue StandardError => e
          puts "[Skalp BoxSection] Error in cleanup: #{e.message}"
        end
      end
    end
  end
end
