module Skalp
  extend self

  MAPPING_PATH = SKALP_PATH + "resources/layermappings/"
  MATERIAL_PATH = SKALP_PATH + "resources/materials/"

  def import_skalp_materials
    get_resources("Import Skalp Materials", MATERIAL_PATH) do |chosen_materials|
      next unless chosen_materials
      next unless File.exist?(chosen_materials)
      next unless chosen_materials[-4..-1] == ".skp"

      Sketchup.active_model.start_operation("Skalp - import materials", true)

      materials = Sketchup.active_model.materials
      ori_materials_names = []

      materials.each do |material|
        ori_materials_names << material.name if material.get_attribute("Skalp", "ID")
      end

      Sketchup.active_model.definitions.load(chosen_materials)

      to_delete = []

      materials.each do |material|
        next unless material.get_attribute("Skalp", "ID")

        to_delete << material if material.name[-1] == "1" && ori_materials_names.include?(material.name[0..-2])
      end

      to_delete.each do |material|
        materials.remove(material)
      end

      Sketchup.active_model.commit_operation
      UI.messagebox("Skalp Materials are imported!")
    end
  rescue StandardError
    Sketchup.active_model.abort_operation
  end

  def get_filename(path, title, &block)
    Skalp.inputbox_custom(["filename"], [""], title) do |result|
      if result == false || result.nil? || result[0].strip == ""
        block.call(false) if block
      else
        filename = path + result[0] + ".skp"
        if File.exist?(filename)
          if UI.messagebox("File already exists. Do you want to overwrite the file?", MB_YESNO) == IDNO
            block.call(false) if block
          elsif block
            block.call(filename)
          end
        elsif block
          block.call(filename)
        end
      end
    end
  end

  def get_resources(title, folder, &block)
    files = Dir.glob(folder + "*.skp").join("|").gsub(folder, "").gsub(".skp", "")
    Skalp.inputbox_custom(["File to import"], [files[0]], [files], title) do |result|
      if result
        block.call(folder + result[0] + ".skp") if block
      elsif block
        block.call(false) if block
      end
    end
  end

  def choose_library(&block)
    files = Dir.glob(MATERIAL_PATH + "*.skp").join("|").gsub(MATERIAL_PATH, "").gsub(".skp", "")
    files += "|*** create new library ***"

    Skalp.inputbox_custom(["Choose library"], [files[0]], [files], "Skalp") do |result|
      if !result
        block.call(false) if block
      elsif result[0] == "*** create new library ***"
        block.call(:NEW) if block
      elsif result[0]
        block.call(MATERIAL_PATH + result[0] + ".skp") if block
      elsif block
        block.call(false)
      end
    end
  end

  def export_layer_mapping
    mapping = {}
    materials = []
    suMaterials = Sketchup.active_model.materials

    get_filename(MAPPING_PATH, "Export Layer Mapping") do |filename|
      next if filename == false
      next unless filename

      no_skalp_materials = []
      not_in_model_materials = []

      Sketchup.active_model.layers.each do |layer|
        material = layer.get_attribute("Skalp", "material")
        next unless material

        if material && suMaterials[material]
          mapping[layer.name] = material

          if suMaterials[material].get_attribute("Skalp", "ID").nil?
            no_skalp_materials << material
          else
            materials << suMaterials[material]
          end

        else
          not_in_model_materials << material
        end
      end

      export_materials(materials, filename, mapping)

      unless no_skalp_materials.empty?
        UI.messagebox("The following materials aren't Skalp materials and can't be exported: #{no_skalp_materials.join(',')} ")
      end

      unless not_in_model_materials.empty?
        UI.messagebox("The following Skalp materials are assigned to a layer but are missing in the model: #{not_in_model_materials.join(',')}")
      end

      UI.messagebox("Skalp layer Mapping is exported!")
    end
  end

  def import_layer_mapping
    get_resources("Import Layer Mapping", MAPPING_PATH) do |chosen_mapping|
      next unless chosen_mapping
      next unless File.exist?(chosen_mapping)
      next unless chosen_mapping[-4..-1] == ".skp"

      Sketchup.active_model.start_operation("Skalp - import layer mapping", true)
      mapping_definition = Sketchup.active_model.definitions.load(chosen_mapping)
      mapping_attribute = mapping_definition.entities.grep(Sketchup::ConstructionPoint)[0].get_attribute("Skalp",
                                                                                                         "layermapping")

      raise "No Layer Mapping file!" unless mapping_attribute

      mapping = eval(mapping_attribute)
      raise "No Layer Mapping file!" unless mapping.class == Hash

      mapping.each_pair do |layer, material|
        layers = Sketchup.active_model.layers

        if layers[layer]
          layers[layer].set_attribute("Skalp", "material", material)
        else
          layer = layers.add(layer)
          layer.set_attribute("Skalp", "material", material)
        end
      end

      Sketchup.active_model.commit_operation
      UI.messagebox("Skalp Layer Mapping is imported!")
    end
  rescue StandardError
    Sketchup.active_model.abort_operation
  end

  def export_skalp_materials(filename = nil)
    materials = []
    suMaterials = Sketchup.active_model.materials

    suMaterials.each do |material|
      materials << material if material.get_attribute("Skalp", "ID") && material.name != "Skalp default" &&
                               material.name != "Skalp linecolor"
    end

    if materials == []
      UI.messagebox("No Skalp Materials to export!")
    else
      export_materials(materials, filename) do |result|
        UI.messagebox("Skalp Materials are exported!") unless result == false
      end
    end
  end

  def create_library(&block)
    Skalp.inputbox_custom(["Name"], [""], "Create new Pattern Library") do |result|
      return unless result && result[0] != ""

      name = result[0]
      json_path = File.join(Skalp::MATERIAL_PATH, "#{name}.json")
      cache_path = json_path.sub(/\.json$/, ".cache")

      if File.exist?(json_path)
        answer = UI.messagebox("Library already exists. Overwrite?", MB_YESNO)
        return if answer == IDNO
      end

      File.write(json_path, JSON.pretty_generate([]))
      File.write(cache_path, "")
      UI.messagebox("Library '#{name}' created.")

      block.call(name) if block
    end
  end

  def save_pattern_to_library(materialname)
    pattern_info = nil

    if Skalp::Material_dialog.active_library == "Skalp materials in model"
      if Sketchup.active_model.materials[materialname] &&
         Sketchup.active_model.materials[materialname].get_attribute("Skalp", "pattern_info")
        pattern_info = begin
          eval(Sketchup.active_model.materials[materialname].get_attribute("Skalp",
                                                                           "pattern_info"))
        rescue StandardError
          nil
        end
      end
    else
      library = Skalp::Material_dialog.active_library
      json_path = File.join(Skalp::MATERIAL_PATH, "#{library}.json")
      if File.exist?(json_path)
        json_data = begin
          JSON.parse(File.read(json_path))
        rescue StandardError
          []
        end
        pattern_info = json_data.find { |info| info["name"] == materialname }
        pattern_info = pattern_info.transform_keys(&:to_sym) if pattern_info
      end
    end

    return unless pattern_info.is_a?(Hash)

    libraries = Dir.glob(File.join(Skalp::MATERIAL_PATH, "*.json")).map { |f| File.basename(f, ".json") }
    return if libraries.empty?

    Skalp.inputbox_custom(["Library"], ["#{libraries.first}"], ["#{libraries.join('|')}"],
                          "Save pattern to library") do |result|
      next unless result && result[0] != ""

      name = result[0]
      json_path = File.join(Skalp::MATERIAL_PATH, "#{name}.json")

      json_data = begin
        JSON.parse(File.read(json_path))
      rescue StandardError
        []
      end
      existing = json_data.find { |info| info["name"] == pattern_info[:name].to_s }

      if existing
        answer = UI.messagebox("Pattern '#{pattern_info[:name]}' already exists in library. Overwrite?", MB_YESNO)
        next if answer == IDNO

        json_data.reject! { |info| info["name"] == pattern_info[:name] }
      end

      json_data << pattern_info.transform_keys(&:to_s)
      File.write(json_path, JSON.pretty_generate(json_data))

      UI.messagebox("Pattern saved to library '#{name}'.")

      # Return path via implicit return? No, this is void now.
      # If caller needs return value, we need a block.
      # Caller is library_menu 'move'/'copy'.
      # We return path string: File.join(Skalp::MATERIAL_PATH, "#{name}.skp") - Wait, it's json now?
      # Original returned true?
      # Check original logic: returned 'true' at end.
      # And referenced by material_dialog.

      # We must yield the result to a block if caller needs it.
      # This method signature doesn't have &block yet, but called async.
      # This needs explicit refactor in caller too.
      yield(File.join(Skalp::MATERIAL_PATH, "#{name}.json")) if block_given?
    end
  end

  def export_materials(materials, filename = nil, mapping = nil, &block)
    # Wrapped logic in block for get_filename if filename is nil
    continuation = lambda do |fname|
      return false if fname == false
      return false unless fname

      export_materials_cache(materials, fname)

      suMaterials = Sketchup.active_model.materials

      block_observer_status = Skalp.block_observers
      observer_status = Skalp.active_model.observer_active

      Skalp.active_model.observer_active = false
      Skalp.block_observers = true

      definition = get_skalp_material_definition

      if mapping
        point = definition.entities.add_cpoint(Geom::Point3d.new(0, 0, 0))
        point.set_attribute("Skalp", "layermapping", mapping.inspect)
        Skalp.active_model.start("Skalp - export layer mapping", true)
      else
        Skalp.active_model.start("Skalp - export materials", true)
      end

      n = 0
      m = 0

      materials.each do |material|
        material = material.name if material.class == Sketchup::Material
        next unless suMaterials[material]

        face = definition.entities.add_face([0 + n, 0 + m, 0], [50 + n, 0 + m, 0], [50 + n, 50 + m, 0],
                                            [0 + n, 50 + m, 0])
        face.material = material
        face.back_material = material
        if n == 750
          n = 0
          m += 75
        else
          n += 75
        end
      end

      material_component = fname
      definition.save_as(material_component)

      Skalp.block_observers = block_observer_status
      Skalp.active_model.observer_active = observer_status
      Skalp.active_model.commit

      block.call(true) if block
    end

    if filename
      continuation.call(filename)
    else
      get_filename(MATERIAL_PATH, "Export Skalp Materials", &continuation)
    end
  end

  def export_materials_cache(materials, filename)
    mat_file = File.open(filename.gsub("skp", "cache"), "w:UTF-8")
    materials.each do |material|
      pattern_info = eval(material.get_attribute("Skalp", "pattern_info"))
      next unless pattern_info

      pattern_info[:png_blob] = create_thumbnail(pattern_info) unless pattern_info[:png_blob]
      mat_file.printf "%s\r\n", pattern_info
    end
    mat_file.close
  end

  def create_thumbnail(pattern_string, w = 81, h = 27)
    hatch = Skalp::SkalpHatch::Hatch.new
    hatch.add_hatchdefinition(SkalpHatch::HatchDefinition.new(pattern_string[:pattern], false))

    printscale = if Skalp.dialog
                   Skalp.dialog.drawing_scale.to_f
                 else
                   50
                 end

    # Safe conversion of lineweights using inch2pen (returns "X.XX mm" or "X.X pt")
    pen_val = pattern_string[:pen].to_f
    sc_val = pattern_string[:section_cut_width].to_f

    pen_formatted = Skalp.inch2pen(pen_val, true)
    sc_formatted = Skalp.inch2pen(sc_val, true)

    # Fallback if inch2pen somehow fails or returns unexpected format
    pen_formatted = "0.35 mm" unless pen_formatted.include?("mm") || pen_formatted.include?("pt")
    sc_formatted = "0.00 mm" unless sc_formatted.include?("mm") || sc_formatted.include?("pt")

    # Assuming 's' in the provided snippet refers to 'pattern_string'
    # and '@tile' refers to some tile object, which is not present here.
    # I will adapt the lineweight logic to use pattern_string and default values where necessary.
    space = pattern_string[:space] || "modelspace" # Default to modelspace if not specified

    hatch.create_png({
                       type: :thumbnail,
                       gauge: false,
                       width: w,
                       height: h,
                       line_color: pattern_string[:line_color],
                       fill_color: pattern_string[:fill_color],
                       pen: Skalp::PenWidth.new(pattern_string[:pen], pattern_string[:space]).to_inch,
                       section_cut_width: pattern_string[:section_cut_width].to_f,
                       resolution: 72,
                       print_scale: printscale,
                       zoom_factor: 0.444,
                       user_x: Skalp.unit_string_to_inch(pattern_string[:user_x]),
                       space: space,
                       section_line_color: pattern_string[:section_line_color] || "rgb(0,0,0)",
                       # Lineweights
                       lineweight_model: (if space == "modelspace"
                                            pen_formatted
                                          else
                                            (pen_formatted == "0.00 mm" ? "0.35 mm" : pen_formatted)
                                          end),
                       lineweight_paper: (space == "paperspace" ? pen_formatted : "0.18 mm"),
                       sectioncut_linewidth: sc_formatted
                     })
  end
  module_function :create_thumbnail

  def get_skalp_material_definition
    definitions = Sketchup.active_model.definitions
    definitions.each do |definition|
      if definition.get_attribute("Skalp", "materials_import") == "1"
        definition.entities.clear!
        return definition
      end
    end

    new_name = definitions.unique_name("skalp_materials_import")
    definition = definitions.add(new_name)
    definition.set_attribute("Skalp", "materials_import", "1")
    definition.set_attribute("dynamic_attributes", "_hideinbrowser", true)
    definition.entities.add_cpoint([0, 0, 0])
    UI.refresh_inspectors

    definition
  end

  # Verwijder een Skalp-materiaal uit de actieve bibliotheek of het model
  def delete_skalp_material(name, library_name = nil)
    libraries = Dir.glob(File.join(Skalp::MATERIAL_PATH, "*.json")).map { |f| File.basename(f, ".json") }
    return if libraries.empty?

    # Alleen vragen naar de bibliotheek als die niet is meegegeven
    library_name ||= Skalp::Material_dialog.active_library
    return unless library_name

    if library_name == "Skalp materials in model"
      material = Sketchup.active_model.materials[name]
      unless material && material.get_attribute("Skalp", "ID")
        UI.messagebox("Skalp material '#{name}' not found in the model.")
        return
      end

      if find_used_skalp_materials.include?(material)
        UI.messagebox("Pattern '#{name}' cannot be deleted because it is still used in the model.")
        return
      end

      answer = UI.messagebox("Are you sure you want to delete '#{name}' from the model?", MB_YESNO)
      return if answer == IDNO

      Sketchup.active_model.materials.remove(material)
      UI.messagebox("Pattern '#{name}' deleted from the model.")
      Skalp::Material_dialog.create_thumbnails(library_name) if Skalp::Material_dialog.respond_to?(:create_thumbnails)
      return
    end

    name = name.strip
    json_path = File.join(Skalp::MATERIAL_PATH, "#{library_name}.json")

    json_data = begin
      JSON.parse(File.read(json_path))
    rescue StandardError
      []
    end
    pattern = json_data.find { |info| info["name"] == name }

    unless pattern
      UI.messagebox("Pattern '#{name}' not found in library '#{library_name}'.")
      return
    end

    answer = UI.messagebox("Are you sure you want to delete '#{name}' from library '#{library_name}'?", MB_YESNO)
    return if answer == IDNO

    json_data.reject! { |info| info["name"] == name }
    File.write(json_path, JSON.pretty_generate(json_data))
    Skalp::Material_dialog.create_thumbnails(library_name) if Skalp::Material_dialog.respond_to?(:create_thumbnails)

    UI.messagebox("Pattern '#{name}' deleted from library '#{library_name}'.")
  end

  def save_all_skalp_materials_to_new_library
    Skalp.inputbox_custom(["Name"], [""], "Save all Skalp Materials to New Library") do |result|
      next unless result && result[0] != ""

      name = result[0]
      json_path = File.join(Skalp::MATERIAL_PATH, "#{name}.json")

      if File.exist?(json_path)
        answer = UI.messagebox("Library already exists. Overwrite?", MB_YESNO)
        next if answer == IDNO
      end

      materials = Sketchup.active_model.materials.select do |material|
        material.get_attribute("Skalp", "ID") &&
          material.name != "Skalp default" &&
          material.name != "Skalp linecolor"
      end

      pattern_infos = []

      materials.each do |mat|
        pattern_info = begin
          eval(mat.get_attribute("Skalp", "pattern_info"))
        rescue StandardError
          nil
        end
        next unless pattern_info.is_a?(Hash)

        unless pattern_info[:png_blob]
          png_blob = begin
            Skalp.create_thumbnail(pattern_info)
          rescue StandardError
            nil
          end
          pattern_info[:png_blob] = png_blob if png_blob
        end

        pattern_infos << pattern_info.transform_keys(&:to_s)
      end

      File.write(json_path, JSON.pretty_generate(pattern_infos))
      Skalp::Material_dialog.load_libraries

      UI.messagebox("All Skalp materials are saved to '#{name}.json'")
    end
  end

  def rename_material_in_library(library_name, old_name)
    return if ["Skalp materials in model", "SketchUp materials in model"].include?(library_name)

    json_path = File.join(Skalp::MATERIAL_PATH, "#{library_name}.json")
    return unless File.exist?(json_path)

    json_data = begin
      JSON.parse(File.read(json_path))
    rescue StandardError
      []
    end
    pattern_info = json_data.find { |info| info["name"] == old_name }
    return unless pattern_info

    Skalp.inputbox_custom(["New name for '#{old_name}'"], [old_name], "Rename Material") do |new_name|
      next unless new_name && !new_name[0].strip.empty?

      new_name = new_name[0].strip
      if json_data.any? { |info| info["name"] == new_name }
        UI.messagebox("A material with the name '#{new_name}' already exists in '#{library_name}'.")
        next
      end

      pattern_info["name"] = new_name
      File.write(json_path, JSON.pretty_generate(json_data))

      UI.messagebox("Material '#{old_name}' renamed to '#{new_name}' in library '#{library_name}'.")
    end
  end
end
