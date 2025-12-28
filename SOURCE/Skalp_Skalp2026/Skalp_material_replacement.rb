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

      # 2. Prompt user to select replacement IF not provided
      unless new_material_name
        # Use a simple inputbox with a dropdown
        prompts = ["Replace '#{old_material_name}' with:"]
        defaults = [all_materials.first]
        list = [all_materials.join("|")]

        result = UI.inputbox(prompts, defaults, list, "Replace Material")
        return unless result

        new_material_name = result[0]
      end

      return if new_material_name == old_material_name

      # 3. Perform Replacement
      # We can reuse logic similar to cleanup_duplicate_materials but specifically for this pair.

      model = Sketchup.active_model
      materials = model.materials

      old_mat = materials[old_material_name]
      new_mat = materials[new_material_name]

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
          e.set_attribute("Skalp", "material", new_material_name) if start_mat_name == old_material_name

          sec_mat_name = e.get_attribute("Skalp", "sectionmaterial")
          e.set_attribute("Skalp", "sectionmaterial", new_material_name) if sec_mat_name == old_material_name
        end
      end

      # Reassign in model
      model.entities.grep(Sketchup::Drawingelement).each do |e|
        # Standard materials
        e.material = new_mat if e.respond_to?(:material) && e.material == old_mat
        e.back_material = new_mat if e.respond_to?(:back_material) && e.back_material == old_mat

        # Skalp attributes
        start_mat_name = e.get_attribute("Skalp", "material")
        e.set_attribute("Skalp", "material", new_material_name) if start_mat_name == old_material_name

        sec_mat_name = e.get_attribute("Skalp", "sectionmaterial")
        e.set_attribute("Skalp", "sectionmaterial", new_material_name) if sec_mat_name == old_material_name
      end

      # Reassign in layers
      model.layers.each do |layer|
        mat_name = layer.get_attribute("Skalp", "material")
        layer.set_attribute("Skalp", "material", new_material_name) if mat_name == old_material_name
      end

      # Update Style Rules
      if Skalp.respond_to?(:replace_material_in_style_rules)
        Skalp.replace_material_in_style_rules(old_material_name, new_material_name)
      end

      # Delete the old material - USER REQUESTED TO KEEP IT (2025-12-29)
      # begin
      #   materials.remove(old_mat)
      # rescue StandardError => e
      #    puts "Could not delete material: #{e}"
      # end

      Skalp.active_model.commit

      # Update active section if present
      Skalp.active_model.active_section.update(nil, true) if Skalp.active_model && Skalp.active_model.active_section

      UI.messagebox("'#{old_material_name}' has been replaced by '#{new_material_name}'.")
      true
    end
  end
end
