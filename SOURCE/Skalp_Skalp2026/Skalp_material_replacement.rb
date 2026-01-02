module Skalp
  module Material_dialog
    def self.replace_material(old_material_name, new_material_name = nil)
      # 1. Get available materials (model + skalp defaults?)
      # For simplicity, let's list all materials in the model except the one being replaced.
      all_materials = Sketchup.active_model.materials.map(&:name).sort
      all_materials.delete(old_material_name)

      if all_materials.empty?
        UI.messagebox("No other materials available to replace with.")
        return
      end

      # Logic to perform replacement
      perform_replacement = lambda do |target_name|
        return if target_name == old_material_name

        model = Sketchup.active_model
        materials = model.materials

        old_mat = materials[old_material_name]
        new_mat = materials[target_name]

        return unless old_mat && new_mat

        Skalp.active_model.start("Skalp - Replace Material", true)

        # Reassign in definitions
        model.definitions.each do |d|
          d.entities.grep(Sketchup::Drawingelement).each do |e|
            # Standard materials
            e.material = new_mat if e.respond_to?(:material) && e.material == old_mat
            e.back_material = new_mat if e.respond_to?(:back_material) && e.back_material == old_mat

            # Skalp attributes
            start_mat_name = e.get_attribute("Skalp", "material")
            e.set_attribute("Skalp", "material", target_name) if start_mat_name == old_material_name

            sec_mat_name = e.get_attribute("Skalp", "sectionmaterial")
            e.set_attribute("Skalp", "sectionmaterial", target_name) if sec_mat_name == old_material_name
          end
        end

        # Reassign in model
        model.entities.grep(Sketchup::Drawingelement).each do |e|
          # Standard materials
          e.material = new_mat if e.respond_to?(:material) && e.material == old_mat
          e.back_material = new_mat if e.respond_to?(:back_material) && e.back_material == old_mat

          # Skalp attributes
          start_mat_name = e.get_attribute("Skalp", "material")
          e.set_attribute("Skalp", "material", target_name) if start_mat_name == old_material_name

          sec_mat_name = e.get_attribute("Skalp", "sectionmaterial")
          e.set_attribute("Skalp", "sectionmaterial", target_name) if sec_mat_name == old_material_name
        end

        # Reassign in layers
        model.layers.each do |layer|
          mat_name = layer.get_attribute("Skalp", "material")
          layer.set_attribute("Skalp", "material", target_name) if mat_name == old_material_name
        end

        # Update Style Rules
        if Skalp.respond_to?(:replace_material_in_style_rules)
          Skalp.replace_material_in_style_rules(old_material_name, target_name)
        end

        Skalp.active_model.commit

        # Update active section if present
        Skalp.active_model.active_section.update(nil, true) if Skalp.active_model && Skalp.active_model.active_section

        UI.messagebox("'#{old_material_name}' has been replaced by '#{target_name}'.")
        true
      end

      # 2. Prompt user if needed
      if new_material_name
        perform_replacement.call(new_material_name)
      else
        prompts = ["Replace '#{old_material_name}' with:"]
        defaults = [all_materials.first]
        list = [all_materials.join("|")]

        Skalp.inputbox_custom(prompts, defaults, list, "Replace Material") do |result|
          perform_replacement.call(result[0]) if result
        end
      end
    end
  end
end
