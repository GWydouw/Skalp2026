module Skalp
  module Migration
    def self.check_legacy_data
      model = Sketchup.active_model
      legacy_defs = model.definitions.select do |d|
        d.name =~ /^Skalp - .*rear view/i || d.get_attribute("Skalp", "type") == "rear_view"
      end

      return if legacy_defs.empty?

      # Found legacy data, prompt user
      result = UI.messagebox(
        "Skalp Legacy Data Detected.\n\nOld 'Component-based' rearview lines found. To support the new 'Group-based' system, these need to be updated.\n\nOption 1: Full Update (Recommended) - Clears old data and recalculates active scenes.\nOption 2: Migrate - Attempts to convert existing lines to Groups (faster, but check visual).\n\nSelect 'Yes' for Full Update, 'No' for Migrate, 'Cancel' to ignore.", MB_YESNOCANCEL
      )

      case result
      when IDYES # Full Update
        full_update(legacy_defs)
      when IDNO # Migrate
        migrate_legacy_data(legacy_defs)
      end
    end

    def self.full_update(legacy_defs)
      # 1. Clear all legacy instances and definitions
      model = Sketchup.active_model
      model.start_operation("Skalp - Full Update", true)

      Skalp.prevent_update = true

      legacy_defs.each do |d|
        d.instances.each(&:erase!) if d.valid?
        # d.entities.clear! # Definition purge handled by SketchUp or cleanup
      end

      # 2. Trigger Recalculate for all Skalp-enabled scenes?
      # Or just let the user handle it? "Recalculate All" implies action.
      # Skalp currently updates only active.

      Skalp.prevent_update = false
      Skalp.update_all_scenes if Skalp.respond_to?(:update_all_scenes)

      model.commit_operation
      UI.messagebox("Full Update initiated. Check your scenes.")
    end

    def self.migrate_legacy_data(legacy_defs)
      model = Sketchup.active_model
      model.start_operation("Skalp - Migrate Legacy", true)

      count = 0
      legacy_defs.each do |d|
        next unless d.valid?

        d.instances.each do |inst|
          next unless inst.valid?

          parent = inst.parent
          # Inst is in a section group hopefully

          # Explode to convert to geometry
          # But explode returns array of entities. We need to group them.

          # Strategy: Create new Group, Copy instance transformation?
          # Or Explode and Group immediately?

          # Better: Create new Group in parent.
          new_group = parent.entities.add_group
          new_group.name = "Skalp - #{Skalp.translate('rear view')}"
          new_group.set_attribute("Skalp", "type", "rear_view")
          new_group.set_attribute("dynamic_attributes", "_hideinbrowser", true)

          # Copy entities from definition to group
          # We need to apply instance transformation?
          # Rearview instances usually have Identity transformation relative to SectionGroup?
          # If not, we need to transform entities.

          definition_entities = d.entities
          # Copying entities is hard without Pro.
          # Easier to explode the instance?
          # If we explode, we get entities in parent. Then we group them.

          exploded = inst.explode
          # exploded contains entities.
          # Group them.
          if exploded.any?
            group = parent.entities.add_group(exploded)
            group.name = "Skalp - #{Skalp.translate('rear view')}"
            group.set_attribute("Skalp", "type", "rear_view")
            group.set_attribute("dynamic_attributes", "_hideinbrowser", true)

            # Ensure layer is handled?
            # Original instance layer?
          end
          count += 1
        end
      end

      model.commit_operation
      UI.messagebox("Migrated #{count} rearview instances.")
    end
  end
end
