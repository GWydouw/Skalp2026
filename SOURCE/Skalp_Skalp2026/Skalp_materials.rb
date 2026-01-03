module Skalp
  extend self

  #  Use Custom Skalp materials
  #
  # ASSIGNMENT
  # .set_attribute('Skalp', 'sectionmaterial', <materialname>)
  #
  # <materialname>  namedcolor -> don't need to do anything
  # <materialname>  already in model -> don't need to do anything
  # <materialname>  not in model or you don't know -> place definition in Skalp_sectionmaterial dictionary
  #
  # Sketchup.active_model.set_attribute('Skalp_sectionmaterials', <materialname>, <hach definition>.inspect)
  #
  #  full example:
  #
  #  <hach definition> = {
  #      pattern:  ["45, 0,0, 0,.125", "135, 0,0, 0,.125"],   #Array with strings for every line  (angle, x-origin,y-origin, delta-x,delta-y,dash-1,dash-2, …)
  #      pattern_size: '3mm',                                 #String with size including unit mm, cm, m, inch, feet
  #      line_color: 'rgb(0,0,0)',                            #string with named color or rgb(,,)
  #      fill_color: 'rgba(255,255,255,0.5)',                 #string with named color, rgb(,,) or rgba(,,,)
  #      hatchline_width: 0.0071,                             #Float width in inch
  #      sectioncut_width: 0.014,                             #Float width in inch
  #      alignment: false                                     #Boolean
  #  }
  #
  # EXAMPLE:
  # Sketchup.active_model.set_attribute('Skalp_sectionmaterials', 'test', {line_color: 'rgb(255,0,0)', pattern:["45, 0,0, 0,.125", "135, 0,0, 0,.125"], pattern_size: '3mm'}.inspect)
  #

  def self.string_to_color(str)
    return str if str.is_a?(Sketchup::Color)
    return Sketchup::Color.new(0, 0, 0) if str.nil? || str.to_s.empty?

    str = str.to_s.strip
    if str =~ /rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([\d.]+)\s*)?\)/i
      r = Regexp.last_match(1).to_i
      g = Regexp.last_match(2).to_i
      b = Regexp.last_match(3).to_i
      a = Regexp.last_match(4)
      color = Sketchup::Color.new(r, g, b)
      color.alpha = (a.to_f * 255).to_i if a
      return color
    end

    Sketchup::Color.new(str)
  rescue StandardError
    Sketchup::Color.new(0, 0, 0)
  end

  def find_used_skalp_materials
    model = Sketchup.active_model
    layers = model.layers
    mats = model.materials
    ents = model.entities
    defs = model.definitions

    used_materials = Set.new
    # find assigned materials to layers
    layers.each do |layer|
      materialname = layer.get_attribute("Skalp", "material")
      used_materials << mats[materialname] if materialname && mats[materialname]
    end

    # find assinged to objects
    ents.each do |e|
      next unless [Sketchup::Group, Sketchup::ComponentInstance].include?(e.class)

      materialname = e.get_attribute("Skalp", "material")
      used_materials << mats[materialname] if materialname && mats[materialname]

      sectionmaterial = e.get_attribute("Skalp", "sectionmaterial")
      used_materials << mats[sectionmaterial] if sectionmaterial && mats[sectionmaterial]
    end

    defs.each do |d|
      d.entities.each do |e|
        next unless [Sketchup::Group, Sketchup::ComponentInstance].include?(e.class)

        materialname = e.get_attribute("Skalp", "material")
        used_materials << mats[materialname] if materialname && mats[materialname]

        sectionmaterial = e.get_attribute("Skalp", "sectionmaterial")
        used_materials << mats[sectionmaterial] if sectionmaterial && mats[sectionmaterial]
      end
    end

    # Check Style Rules (Model + Scenes)
    check_rules = lambda do |rules|
      return unless rules && rules.is_a?(Array)

      rules.each do |rule|
        used_materials << mats[rule[:pattern]] if rule[:pattern] && mats[rule[:pattern]]
        next unless rule[:type_setting].is_a?(Hash)

        rule[:type_setting].each_value do |mat_name|
          used_materials << mats[mat_name] if mat_name && mats[mat_name]
        end
      end
    end

    # 1. Model default style
    model_settings = Skalp::StyleSettings.style_settings(Sketchup.active_model)
    check_rules.call(model_settings[:style_rules].rules) if model_settings[:style_rules]

    # 2. Page specific styles
    Sketchup.active_model.pages.each do |page|
      page_settings = Skalp.active_model.get_memory_attribute(page, "Skalp", "style_settings")
      next unless page_settings.is_a?(Hash) && page_settings[:style_rules]

      check_rules.call(page_settings[:style_rules].rules)
    end

    used_materials
  end

  def create_skalp_material_instance
    cleanup_duplicate_skalp_materials_definitions
    componentdefinition = find_skalp_materials_definition || Sketchup.active_model.definitions.add("skalp_materials")

    if componentdefinition.count_instances == 0
      point = Geom::Point3d.new(0, 0, 0)
      transform = Geom::Transformation.new(point)
      instance = Sketchup.active_model.entities.add_instance(componentdefinition, transform)
      instance.hidden = true
      instance.locked = true
    end

    update_skalp_materials_definition(componentdefinition)
  end

  def delete_skalp_materials_definition
    material_definition = find_skalp_materials_definition

    return unless material_definition

    material_definition.instances.each do |instance|
      instance.locked = false
      instance.erase!
    end
  end

  def update_skalp_materials_definition(componentdefinition)
    materials_in_model = Sketchup.active_model.materials
    added_groups = []
    materials_stored = get_materials_in_defintion(componentdefinition)
    missing_materials = []

    Skalp.active_model.used_materials = find_used_skalp_materials if Skalp.active_model.used_materials.empty?

    Skalp.active_model.used_materials.each do |material|
      if materials_in_model.include?(material)
        if materials_stored.keys.include?(material)
          added_groups << materials_stored[material]
        else
          material_group = componentdefinition.entities.add_group
          material_group.name = material.name
          added_groups << material_group
          edge = material_group.entities.add_line([0, 0, 0], [0, 0, 1])
          edge.hidden = true
          material_group.material = material
        end
      elsif !material.nil?
        missing_materials << material
      end
    end

    componentdefinition.entities.each do |group|
      group.erase! unless added_groups.include?(group)
    end

    return unless missing_materials != []

    UI.messagebox("The following materials are missing in your model: #{missing_materials.join(', ')}")
  end

  def force_purge_skalp_materials
    componentdefinition = find_skalp_materials_definition
    return unless componentdefinition

    @used_materials = Set.new # Force refresh of used materials
    Skalp.active_model.start("Skalp - #{Skalp.translate('purge stored materials')}", true)
    update_skalp_materials_definition(componentdefinition)
    Skalp.active_model.commit
    Sketchup.active_model.materials.purge_unused

    UI.messagebox("Force Purge Completed.\n\nAll unused Skalp materials have been removed from the hidden storage and purged from the model.")
  end

  def cleanup_duplicate_materials(auto = false)
    materials = Sketchup.active_model.materials
    # Group materials by Skalp ID
    skalp_groups = {}

    materials.each do |mat|
      id = mat.get_attribute("Skalp", "ID")
      next unless id

      skalp_groups[id] ||= []
      skalp_groups[id] << mat
    end

    duplicates = {} # { dup_mat => base_mat }

    # 1. Group by ID
    skalp_groups.each do |id, mats|
      next if mats.size < 2

      sorted = mats.sort_by { |m| [m.name.length, m.name] }
      base_mat = sorted.shift
      sorted.each { |dup| duplicates[dup] = base_mat }
    end

    # 2. Setup regex for name stripping (Plan B)
    # Catches: Name1, Name2, Name#1, Name#2
    suffix_regex = /(#?\d+)\z/

    # 3. Check for name-based duplicates among those NOT yet handled
    materials.each do |mat|
      next if duplicates.key?(mat) # Already marked as duplicate via ID
      next if duplicates.value?(mat) # This is a base material for something else, keep it safe?

      # actually, a base material could theoretically be a duplicate of another even-baser material,
      # but let's keep it simple: if it has an ID, we prioritize ID grouping.

      original_name = mat.name.gsub(suffix_regex, "")
      next if original_name == mat.name # No suffix found

      base_mat = materials[original_name]
      next unless base_mat

      # Visual check to ensure safety
      next unless materials_identical?(mat, base_mat)

      duplicates[mat] = base_mat
    end

    return if duplicates.empty?

    # Usage tracking
    used_duplicates = Set.new

    # Check definitions
    Sketchup.active_model.definitions.each do |d|
      d.entities.grep(Sketchup::Drawingelement).each do |e|
        used_duplicates << e.material if e.respond_to?(:material) && duplicates.key?(e.material)
        used_duplicates << e.back_material if e.respond_to?(:back_material) && duplicates.key?(e.back_material)

        # Check Skalp attributes
        mat_name = e.get_attribute("Skalp", "material")
        if mat_name && materials[mat_name] && duplicates.key?(materials[mat_name])
          used_duplicates << materials[mat_name]
        end

        sec_name = e.get_attribute("Skalp", "sectionmaterial")
        if sec_name && materials[sec_name] && duplicates.key?(materials[sec_name])
          used_duplicates << materials[sec_name]
        end
      end
    end

    # Check model entities
    Sketchup.active_model.entities.grep(Sketchup::Drawingelement).each do |e|
      used_duplicates << e.material if e.respond_to?(:material) && duplicates.key?(e.material)
      used_duplicates << e.back_material if e.respond_to?(:back_material) && duplicates.key?(e.back_material)

      # Check Skalp attributes
      mat_name = e.get_attribute("Skalp", "material")
      used_duplicates << materials[mat_name] if mat_name && materials[mat_name] && duplicates.key?(materials[mat_name])

      sec_name = e.get_attribute("Skalp", "sectionmaterial")
      used_duplicates << materials[sec_name] if sec_name && materials[sec_name] && duplicates.key?(materials[sec_name])
    end

    # Check layers
    Sketchup.active_model.layers.each do |layer|
      mat_name = layer.get_attribute("Skalp", "material")
      used_duplicates << materials[mat_name] if mat_name && materials[mat_name] && duplicates.key?(materials[mat_name])
    end

    # Check Style Rules (Model + Scenes)
    check_style_rules_for_duplicates(duplicates, used_duplicates, materials)

    unused_duplicates = duplicates.keys.reject { |m| used_duplicates.include?(m) }

    merge_assigned = false
    unless used_duplicates.empty?
      if auto
        merge_assigned = true
      else
        msg = "Found #{used_duplicates.size} duplicate Skalp materials that are currently assigned to objects. \n\n"
        msg += "Do you want to reassign these to their original materials and delete the duplicates? \n\n"
        msg += "(Click 'No' to only delete unused duplicates)"
        result = UI.messagebox(msg, MB_YESNO)
        merge_assigned = (result == IDYES)
      end
    end

    # Only start a new operation if we are not already in one
    in_operation = Skalp.active_model && Skalp.active_model.operation > 0
    Skalp.active_model.start("Skalp - #{Skalp.translate('cleanup duplicate materials')}", true) unless in_operation

    removed_unused = 0
    merged_assigned = 0

    # 1. Handle Unused
    unused_duplicates.each do |mat|
      materials.remove(mat)
      removed_unused += 1
    end

    # 2. Handle Used/Assigned if approved
    if merge_assigned
      to_merge = duplicates.select { |k, v| used_duplicates.include?(k) }

      # Reassign in definitions
      Sketchup.active_model.definitions.each do |d|
        d.entities.grep(Sketchup::Drawingelement).each do |e|
          # Standard materials
          e.material = to_merge[e.material] if e.respond_to?(:material) && to_merge.key?(e.material)
          e.back_material = to_merge[e.back_material] if e.respond_to?(:back_material) && to_merge.key?(e.back_material)

          # Skalp attributes
          start_mat_name = e.get_attribute("Skalp", "material")
          if start_mat_name && materials[start_mat_name] && to_merge.key?(materials[start_mat_name])
            e.set_attribute("Skalp", "material", to_merge[materials[start_mat_name]].name)
          end

          sec_mat_name = e.get_attribute("Skalp", "sectionmaterial")
          if sec_mat_name && materials[sec_mat_name] && to_merge.key?(materials[sec_mat_name])
            e.set_attribute("Skalp", "sectionmaterial", to_merge[materials[sec_mat_name]].name)
          end
        end
      end

      # Reassign in model
      Sketchup.active_model.entities.grep(Sketchup::Drawingelement).each do |e|
        # Standard materials
        e.material = to_merge[e.material] if e.respond_to?(:material) && to_merge.key?(e.material)
        e.back_material = to_merge[e.back_material] if e.respond_to?(:back_material) && to_merge.key?(e.back_material)

        # Skalp attributes
        start_mat_name = e.get_attribute("Skalp", "material")
        if start_mat_name && materials[start_mat_name] && to_merge.key?(materials[start_mat_name])
          e.set_attribute("Skalp", "material", to_merge[materials[start_mat_name]].name)
        end

        sec_mat_name = e.get_attribute("Skalp", "sectionmaterial")
        if sec_mat_name && materials[sec_mat_name] && to_merge.key?(materials[sec_mat_name])
          e.set_attribute("Skalp", "sectionmaterial", to_merge[materials[sec_mat_name]].name)
        end
      end

      # Reassign in layers
      Sketchup.active_model.layers.each do |layer|
        mat_name = layer.get_attribute("Skalp", "material")
        if mat_name && materials[mat_name] && to_merge.key?(materials[mat_name])
          layer.set_attribute("Skalp", "material", to_merge[materials[mat_name]].name)
        end
      end

      # Update Style Rules
      to_merge.each do |dup_mat, base_mat|
        replace_material_in_style_rules(dup_mat.name, base_mat.name)
      end

      # Delete them
      to_merge.each_key do |mat|
        begin
          materials.remove(mat)
        rescue StandardError
          nil
        end
        merged_assigned += 1
      end
    end

    Skalp.active_model.commit unless in_operation

    unless auto
      summary = "Skalp Cleanup Summary:\n\n"
      summary += "- Unused duplicates removed: #{removed_unused}\n"
      summary += "- Assigned duplicates merged: #{merged_assigned}\n" if merge_assigned
      summary += "- Assigned duplicates kept: #{used_duplicates.size}\n" if !merge_assigned && !used_duplicates.empty?
      UI.messagebox(summary)
    end
  rescue StandardError => e
    UI.messagebox("Skalp Cleanup Error: #{e.message}\n\n#{e.backtrace.first(5).join("\n")}")
    if defined?(DEBUG) && DEBUG
      puts "Skalp Cleanup Error: #{e.message}"
      puts e.backtrace
    end
  end

  def check_style_rules_for_duplicates(duplicates, used_duplicates, materials)
    # Helper to check a single ruleset
    check_rules = lambda do |rules|
      return unless rules && rules.is_a?(Array)

      rules.each do |rule|
        # Check 'pattern' (the material name)
        if rule[:pattern] && materials[rule[:pattern]] && duplicates.key?(materials[rule[:pattern]])
          used_duplicates << materials[rule[:pattern]]
        end
        # Check 'type_setting' for layer/texture mapping hash
        next unless rule[:type_setting].is_a?(Hash)

        rule[:type_setting].each_value do |mat_name|
          if mat_name && materials[mat_name] && duplicates.key?(materials[mat_name])
            used_duplicates << materials[mat_name]
          end
        end
      end
    end

    # 1. Model default style
    if defined?(Skalp::StyleSettings) && Skalp::StyleSettings.respond_to?(:style_settings)
      model_settings = Skalp::StyleSettings.style_settings(Sketchup.active_model)
      check_rules.call(model_settings[:style_rules].rules) if model_settings[:style_rules]
    end

    # 2. Page specific styles
    if Skalp.active_model && Skalp.active_model.respond_to?(:get_memory_attribute)
      Sketchup.active_model.pages.each do |page|
        page_settings = Skalp.active_model.get_memory_attribute(page, "Skalp", "style_settings")
        next unless page_settings.is_a?(Hash) && page_settings[:style_rules]

        check_rules.call(page_settings[:style_rules].rules)
      end
    end
  rescue StandardError => e
    if defined?(DEBUG) && DEBUG
      puts "Skalp Warning: Error checking style rules for duplicates: #{e}"
      puts e.backtrace.first(5).join("\n")
    end
  end

  def replace_material_in_style_rules(old_name, new_name)
    # Helper to replace in a single ruleset
    replace_in_rules = lambda do |rules|
      return false unless rules && rules.is_a?(Array)

      changed = false
      rules.each do |rule|
        # Replace 'pattern' (the material name)
        if rule[:pattern] == old_name
          rule[:pattern] = new_name
          changed = true
        end
        # Replace in 'type_setting' for layer/texture mapping hash
        next unless rule[:type_setting].is_a?(Hash)

        rule[:type_setting].each do |key, val|
          if val == old_name
            rule[:type_setting][key] = new_name
            changed = true
          end
        end
      end
      changed
    end

    # 1. Model default style
    model_settings = Skalp::StyleSettings.style_settings(Sketchup.active_model)
    if model_settings[:style_rules] && replace_in_rules.call(model_settings[:style_rules].rules)
      Skalp::StyleSettings.save_style_rules(model_settings[:style_rules], Sketchup.active_model)
    end

    # 2. Page specific styles
    Sketchup.active_model.pages.each do |page|
      page_settings = Skalp.active_model.get_memory_attribute(page, "Skalp", "style_settings")
      next unless page_settings.is_a?(Hash) && page_settings[:style_rules]

      if replace_in_rules.call(page_settings[:style_rules].rules)
        # We need to save it back because we modify the hash in place but might need to trigger save mechanisme if any
        Skalp.active_model.set_memory_attribute(page, "Skalp", "style_settings", page_settings)
      end
    end
  end

  def materials_identical?(mat1, mat2)
    return false unless mat1.color.to_i == mat2.color.to_i
    return false unless mat1.alpha == mat2.alpha

    t1 = mat1.texture
    t2 = mat2.texture

    return true if t1.nil? && t2.nil?
    return false if t1.nil? || t2.nil?

    # Both have texture
    return false unless t1.filename == t2.filename
    # Check dimensions (tolerance needed?)
    return false unless t1.width == t2.width
    return false unless t1.height == t2.height

    true
  end

  def add_skalp_material_to_instance(materialnames)
    materialnames.each do |materialname|
      next if materialname == ""

      material = Sketchup.active_model.materials[materialname]
      Skalp.active_model.used_materials << material unless Skalp.active_model.used_materials.include?(material)
    end
    create_skalp_material_instance
  end

  def get_materials_in_defintion(definition)
    materials = {}
    definition.entities.each do |group|
      materials[group.material] = group if group.material
    end
    materials
  end

  def find_skalp_materials_definition
    Sketchup.active_model.definitions.each do |definition|
      return definition if definition.name == "skalp_materials"
    end
    nil
  end

  def cleanup_duplicate_skalp_materials_definitions
    model = Sketchup.active_model
    skalp_defs = model.definitions.select { |d| d.name =~ /\Askalp_materials(#\d+)?\z/ }
    return if skalp_defs.size <= 1

    # Pick the base one or rename the first one to be the master
    base_def = skalp_defs.find { |d| d.name == "skalp_materials" }
    unless base_def
      base_def = skalp_defs.first
      base_def.name = "skalp_materials"
    end

    other_defs = skalp_defs - [base_def]

    # We don't use Skalp.active_model.start here because this might be called
    # during very early initialization before the Skalp model is fully ready.
    model.start_operation("Skalp - cleanup duplicate definitions", true)
    other_defs.each do |d|
      # Erase instances of the duplicate definition
      d.instances.each do |inst|
        inst.locked = false if inst.respond_to?(:locked=)
        inst.erase!
      end
      # Remove the definition from the model
      begin
        model.definitions.remove(d)
      rescue StandardError
        nil
      end
    end
    model.commit
  end

  def create_su_material(material_name)
    return nil if material_name == "su_default"

    material_name = "Skalp default" if ["", nil].include?(material_name)
    su_material = Sketchup.active_model.materials[material_name]

    if su_material.nil? || !su_material.get_attribute("Skalp", "ID")
      if color_from_name(material_name)
        Sketchup.active_model.set_attribute("Skalp_sectionmaterials", material_name,
                                            { fill_color: "#{color_from_name(material_name)}" }.inspect)
        create_sectionmaterial(material_name)
        su_material = Sketchup.active_model.materials[material_name]
      elsif Sketchup.active_model.get_attribute("Skalp_sectionmaterials", material_name)
        create_sectionmaterial(material_name)
        su_material = Sketchup.active_model.materials[material_name]
      elsif !su_material.nil? && su_material.get_attribute("Skalp", "ID")
        create_skalp_default_material
        su_material = Sketchup.active_model.materials["Skalp default"]
      end
    end
    su_material
  end

  def remove_PBR_properties
    materials = Sketchup.active_model.materials
    target_materials = materials.select { |mat| mat.get_attribute("Skalp", "ID") }

    return if target_materials.empty?

    Skalp.active_model.start("Skalp - #{Skalp.translate('remove PBR properties from Skalp materials')}", true)

    target_materials.each do |material|
      material.metalness_enabled = false
      material.roughness_enabled = false
    end

    Skalp.active_model.commit
  end

  def is_float?(str)
    # Let op: dit accepteert ook integer strings zoals "3"
    Float(str)
    true
  rescue ArgumentError, TypeError
    false
  end

  def self.convert_old_libraries_to_json
    cache_files = Dir.glob(File.join(Skalp::MATERIAL_PATH, "*.cache"))

    cache_files.each do |cache_file|
      base = File.basename(cache_file, ".cache")
      json_file = File.join(Skalp::MATERIAL_PATH, "#{base}.json")

      lines = File.readlines(cache_file, chomp: true)
      json_data = []

      lines.each do |line|
        info = eval(line)

        unless info[:section_cut_width]
          info[:section_cut_width] = 0.007086614173228346 # '0.25 mm'
        end

        pattern = info[:pattern]

        if is_float?(pattern[0].split(",").first)
          pattern = ["*#{info[:name].upcase.gsub(' ', '_')}, #{info[:name]}"] + pattern
        end

        pattern[0] = "*" + pattern[0] if pattern[0][0] != "*"

        pattern[0] = "*SOLID_COLOR, solid color without hatching" if info[:line_color] == info[:fill_color]

        info[:pattern] = pattern

        json_data << info
      rescue StandardError => e
        puts "Error parsing line in #{cache_file}: #{e}" if defined?(DEBUG) && DEBUG
      end

      File.write(json_file, JSON.pretty_generate(json_data))
    end

    # Verwijder alle overgebleven .skp bestanden
    Dir.glob(File.join(Skalp::MATERIAL_PATH, "*.skp")).each do |skp_file|
      File.delete(skp_file) if File.exist?(skp_file)
    end

    # Verwijder alle overgebleven .skp bestanden
    Dir.glob(File.join(Skalp::MATERIAL_PATH, "*.cache")).each do |cache_file|
      File.delete(cache_file) if File.exist?(cache_file)
    end
  end

  def get_texture(material)
    model = Sketchup.active_model
    tw = Sketchup.create_texture_writer
    gr = model.entities.add_group
    gr.material = material
    tw.load(gr)
    tw.write(gr, IMAGE_PATH + "tile.png")
    gr.erase! if gr.valid?
  end

  def remove_scaled_textures
    model = Sketchup.active_model
    scaled_val = Skalp.active_model.get_memory_attribute(model, "Skalp", "scaled_materials")
    # Handle both boolean and integer values
    begin
      return unless [1, true].include?(scaled_val) || scaled_val.to_i == 1
    rescue StandardError
      false
    end

    to_delete = []
    materials = model.materials

    materials.each do |material|
      to_delete << material if material.name =~ /\[1-\d+\]/
    end

    Skalp.active_model.start("Skalp - #{Skalp.translate('remove scaled textures')}", true)
    to_delete.each { |material| materials.remove(material) }
    Skalp.active_model.set_memory_attribute(model, "Skalp", "scaled_materials", 0)
    Skalp.active_model.commit
  end

  def export_material_textures(layout = false)
    observer_status = Skalp.active_model.observer_active
    Skalp.active_model.observer_active = false
    path = if layout
             SKALP_PATH + "resources/Layout Pattern-Fill Images/Skalp Patterns/"
           else
             SKALP_PATH + "resources/material_images/"
           end

    FileUtils.rm_rf(path) unless layout
    FileUtils.mkdir_p(path)

    model = Sketchup.active_model
    materials = model.materials
    tw = Sketchup.create_texture_writer

    model.start_operation("Skalp - #{Skalp.translate('export material textures')}", true, false, false)

    gr = model.entities.add_group

    for material in materials
      next if material.name.include?("%") && layout
      next unless material.get_attribute("Skalp", "ID")

      gr.material = material

      tw.load(gr)
      if layout
        matname = path + material.name + ".png"
      else
        scale = skalp_material_info(material, :print_scale)
        matname = path + material.name + " " + size_to_filename(material.texture.width).to_s + " x " + size_to_filename(material.texture.height).to_s + "[1-" + scale.to_s + "].png"
      end
      tw.write(gr, matname)
    end

    model.abort_operation
    Skalp.active_model.observer_active = observer_status
  end

  def delete_empty_materials
    skpModel = Sketchup.active_model

    entities = skpModel.entities
    materials = skpModel.materials
    temp = entities.add_group

    for material in materials do
      unless material.name == ""
        mat_group = temp.entities.add_group
        mat_group.material = material
      end
    end

    materials.purge_unused
    temp.erase!
  end

  def version_check(material)
    eval(material.get_attribute("Skalp", "pattern_info").to_s)
  end

  def check_syntax_skalp_material(material)
    version_check(material) unless version_compare
    name = material.name.gsub(/%\d+\Z/, "")
    skalp_name = skalp_material_info(material, :name)

    if name == skalp_name
      set_pattern_info_attribute(material,
                                 get_pattern_info(material))
    else
      set_skalp_material_info(material,
                              :name, name)
    end
  end

  def version_compare
    @version_compare_flag ||= SKALP_VERSION == Skalp.active_model.get_memory_attribute(Sketchup.active_model, "Skalp",
                                                                                       "skalp_version")
  end

  def check_SU_material_library(material = nil)
    Skalp.active_model.start("Skalp - #{Skalp.translate('correct renamed Skalp materials')}", true)
    Skalp.active_model.material_observer_active = false

    if material
      check_syntax_skalp_material(material)
    else
      Sketchup.active_model.materials.each do |material|
        check_syntax_skalp_material(material)
      end
    end

    Skalp.active_model.commit
    Skalp.active_model.material_observer_active = true
  end

  def skalp_material_info(su_material, info_type = :name)
    return nil unless su_material

    # :name, :pattern, :print_scale, :resolution=, :user_x, :space, :pen, :line_color, :fill_color, :gauge_ratio, :pat_scale, :angle, :alignment ,:section_cut_width
    material_ID = su_material.get_attribute("Skalp", "ID")

    if material_ID
      pattern_info = get_pattern_info(su_material)
      if pattern_info.nil?
        su_material.delete_attribute("Skalp")
        return
      end

      pattern_string = get_pattern_info(su_material)

      return pattern_string[info_type] if pattern_string
    end
    nil
  end

  def set_skalp_material_info(su_material, info_type, new_setting)
    material_ID = su_material.get_attribute("Skalp", "ID")

    return unless material_ID

    pattern_info = get_pattern_info(su_material)
    if pattern_info.nil?
      su_material.delete_attribute("Skalp")
      return
    end
    pattern_string = if pattern_info.class == Hash
                       pattern_info
                     else
                       eval(pattern_info)
                     end
    updated_string = {}

    pattern_string.each_pair do |key, value|
      updated_string[key] = if key == info_type
                              new_setting
                            else
                              value
                            end
    end
    set_pattern_info_attribute(su_material, updated_string)
  end

  def calc_brightness(rgb)
    # https://en.wikipedia.org/wiki/Luma_(video)
    # http://stackoverflow.com/questions/596216/formula-to-determine-brightness-of-rgb-color

    (0.299 * rgb[0].to_f) + (0.587 * rgb[1].to_f) + (0.114 * rgb[2].to_f) # max 252.45
  end

  def material_brightness(material)
    light_power = 0.0001

    if material.get_attribute("Skalp", "ID")
      pattern_info = get_pattern_info(material)
      rgb_fill = pattern_info[:fill_color].scan(/\d{1,3}/)
      rgb_line = pattern_info[:line_color].scan(/\d{1,3}/)

      fill = calc_brightness(rgb_fill)
      line = calc_brightness(rgb_line)

      brightness = fill > line ? fill : line
    else
      brightness = calc_brightness([255, 255, 255])
    end

    render_brightness = Sketchup.read_default("Skalp", "render_brightness").to_f || 1.0
    brightness * brightness * brightness * light_power * render_brightness
  end

  def get_pattern_info(material)
    return {} unless material.get_attribute("Skalp", "pattern_info")

    pattern_string = material.get_attribute("Skalp", "pattern_info").split(").to_s);").last
    # Handle corrupted data with Infinity or NaN values
    pattern_string = pattern_string.gsub(/(?<![a-zA-Z])Infinity(?![a-zA-Z])/, "1.0")
    pattern_string = pattern_string.gsub(/(?<![a-zA-Z])NaN(?![a-zA-Z])/, "1.0")
    eval(pattern_string)
  rescue StandardError => e
    puts "Skalp Warning: Error parsing pattern_info for #{material.name}: #{e.message}" if defined?(DEBUG) && DEBUG
    {}
  end

  def set_thea_render_params(material = nil)
    Skalp.active_model.start("Skalp - update materials for Thea Render")
    if material
      set_light_power(material, material_brightness(material))
    else
      Sketchup.active_model.materials.each do |material|
        set_light_power(material, material_brightness(material)) if material.get_attribute("Skalp", "ID")
      end
    end

    Skalp.active_model.commit
  end

  def set_light_power(material, light_power)
    material.set_attribute("TH4SU_Settings", "MaterialXML", "\n\n\n<Parameter Name=\"Type\" Type=\"String\" Value=\"Emitter\"/>\n
<Parameter Name=\"Emitter/Power\" Type=\"Real\" Value=\"#{light_power}\"/>\n<Parameter Name=\"Emitter/Unit\" Type=\"String\" Value=\"W/m2\"/>\n
<Parameter Name=\"Emitter/Passive\" Type=\"Boolean\" Value=\"1\"/>\n")
  end

  def set_render_brightness
    brightness = Sketchup.read_default("Skalp", "render_brightness").to_f || 1.0
    brightness = 1.0 if brightness == 0.0

    Skalp.inputbox_custom(["Render Brightness Factor"], ["#{brightness}"], "Skalp") do |input|
      next unless input

      Sketchup.write_default("Skalp", "render_brightness", input.first.to_f)
      set_thea_render_params
    end
  end

  def create_thumbnails_cache(thumbnails = false)
    materials = Sketchup.active_model.materials
    updated = {}
    any_updated = false

    materials.each do |material|
      next unless material.get_attribute("Skalp", "ID")

      pattern_info = begin
        eval(material.get_attribute("Skalp", "pattern_info"))
      rescue StandardError
        nil
      end
      next unless pattern_info.is_a?(Hash)

      # Force regeneration once to clear old red X blobs
      if true # was unless pattern_info[:png_blob]
        png_blob = begin
          Skalp.create_thumbnail(pattern_info, 81, 27)
        rescue StandardError
          nil
        end
        if png_blob
          unless any_updated
            Skalp.active_model.start("Skalp - update png_blob", true)
            any_updated = true
          end
          pattern_info[:png_blob] = png_blob
          material.set_attribute("Skalp", "pattern_info",
                                 "eval(Sketchup.active_model.get_attribute('Skalp', 'version_check').to_s);#{pattern_info.inspect}")
        end
      end

      updated[material.name] = pattern_info[:png_blob] if pattern_info[:png_blob]
    end

    Skalp.active_model.commit if any_updated
    updated if thumbnails
  end

  def merge_material_dialog_action(source_material_name)
    source_material = Sketchup.active_model.materials[source_material_name]
    unless source_material
      UI.messagebox(Skalp.translate("Source material not found."))
      return
    end

    # Collect other Skalp materials
    materials = Sketchup.active_model.materials
    target_names = []
    materials.each do |mat|
      next if mat == source_material

      target_names << mat.name if mat.get_attribute("Skalp", "ID")
    end

    target_names.sort!

    if target_names.empty?
      UI.messagebox(Skalp.translate("No other Skalp materials found to merge into."))
      return
    end

    prompts = [Skalp.translate("Merge") + " '#{source_material_name}' " + Skalp.translate("into") + ":"]
    defaults = [target_names.first]
    list = [target_names.join("|")]

    Skalp.inputbox_custom(prompts, defaults, list, Skalp.translate("Merge Material")) do |input|
      next unless input

      target_material_name = input[0]
      target_material = materials[target_material_name]
      next unless target_material

      Skalp::Material_dialog.replace_material(source_material_name, target_material_name)
    end
  end

  def self.edit_material_pattern(material_name)
    return unless material_name

    material_name = material_name.to_s.strip

    # UI Checks (migrated from Skalp_UI.rb)
    if Skalp.respond_to?(:info_dialog_active) && Skalp.info_dialog_active
      UI.messagebox(Skalp.translate("Please close the Skalp Info Dialog to start using Skalp"), MB_OK)
      return
    end
    Skalp.skalpTool if Skalp.respond_to?(:skalpTool) && Skalp.respond_to?(:status) && Skalp.status == 0

    # Ensure Skalp default material is valid if targeted
    Skalp.check_skalp_default_material if material_name.downcase.start_with?("skalp default")

    # Check if model material
    su_material = Sketchup.active_model.materials[material_name]

    # Allow if:
    # 1. The material doesn't exist yet (this happens when CREATING a new material)
    # 2. It's a known Skalp material (has ID or pattern_info)
    # 3. It's a built-in Skalp material name (starts with Skalp)
    is_skalp = su_material && (su_material.get_attribute("Skalp",
                                                         "ID") || su_material.get_attribute("Skalp", "pattern_info"))
    is_builtin = material_name.downcase.start_with?("skalp")

    unless su_material.nil? || is_skalp || is_builtin
      puts "[Skalp DEBUG] edit_material_pattern denied for '#{material_name}'. Material found: #{!su_material.nil?}, Skalp ID: #{if su_material
                                                                                                                                   su_material.get_attribute(
                                                                                                                                     'Skalp', 'ID'
                                                                                                                                   )
                                                                                                                                 else
                                                                                                                                   'N/A'
                                                                                                                                 end}"
      UI.messagebox("Only Skalp materials in the model can be edited in the Pattern Designer.")
      return
    end

    # Open or refresh Hatch Dialog
    if Skalp.hatch_dialog && Skalp.hatch_dialog.webdialog.visible?
      Skalp.hatch_dialog.webdialog.bring_to_front
      Skalp.hatch_dialog.hatchname = material_name
      Skalp.hatch_dialog.load_patterns_and_materials
      Skalp.hatch_dialog.select_last_pattern if Skalp.hatch_dialog.respond_to?(:select_last_pattern)
    else
      # Force new instance to ensure fresh HTML injection
      Skalp.hatch_dialog = Skalp::Hatch_dialog.new(material_name)
      Skalp.hatch_dialog.webdialog.show
    end
    Skalp.patterndesignerbutton_on if Skalp.respond_to?(:patterndesignerbutton_on)
  end
end

# Copy a material between JSON libraries
def copy_material_between_libraries(source_library, target_library, materialname)
  source_path = File.join(Skalp::MATERIAL_PATH, "#{source_library}.json")
  target_path = File.join(Skalp::MATERIAL_PATH, "#{target_library}.json")
  return unless File.exist?(source_path) && File.exist?(target_path)

  source_data = begin
    JSON.parse(File.read(source_path))
  rescue StandardError
    []
  end
  target_data = begin
    JSON.parse(File.read(target_path))
  rescue StandardError
    []
  end

  material_info = source_data.find { |info| info["name"] == materialname }
  return unless material_info

  existing = target_data.find { |info| info["name"] == materialname }
  if existing
    result = UI.messagebox("Material '#{materialname}' already exists in '#{target_library}'. Overwrite?", MB_YESNO)
    return if result == IDNO

    target_data.reject! { |info| info["name"] == materialname }
  end

  target_data << material_info
  File.write(target_path, JSON.pretty_generate(target_data))
end

# Move a material between JSON libraries
def move_material_between_libraries(source_library, target_library, materialname)
  copy_material_between_libraries(source_library, target_library, materialname)
  path = File.join(Skalp::MATERIAL_PATH, "#{source_library}.json")
  return unless File.exist?(path)

  data = begin
    JSON.parse(File.read(path))
  rescue StandardError
    []
  end
  data.reject! { |info| info["name"] == materialname }
  File.write(path, JSON.pretty_generate(data))
end
