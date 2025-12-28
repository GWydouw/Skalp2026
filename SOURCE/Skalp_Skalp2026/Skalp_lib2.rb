module Skalp
  extend self

  require "base64"

  class Distance
    def initialize(distance)
      @decimal = Skalp.decimal_separator
      @model_unit = Skalp.model_unit
      process_string(distance.to_s)
    end

    def to_inch
      @input_value
    end

    def to_modelunits
      @input_value.to_l
    end

    def to_s
      @input_string
    end

    private

    def process_string(string)
      string = "300cm" if ["", nil].include?(string)

      string.gsub!("feet", "'")
      @input_string = string
      find_unit
      process_string_value
    end

    def process_string_value
      @input_string.gsub!(",", ".") if @decimal == ","
      @input_string.gsub!(%r{[^\d+./]}, "")

      if @input_string.count("/") > 0
        @rational = true
        temp = @input_string.split("/")
        @input_string = temp[0] + "/" + temp[1]
        @input_value = input_to_inch(temp[0].to_f / temp[1].to_f)
      else
        @rational = false
        @input_value = input_to_inch(@input_string.to_f)
      end

      @input_string = format(@input_value) # @input_string + @unit
    end

    def format(value)
      case @unit
      when "mm"
        value_string = (value * 25.4).round(1).to_s + "mm"
      when "cm"
        value_string = (value * 2.54).round(2).to_s + "cm"
      when "m"
        value_string = (value * 0.0254).round(4).to_s + "m"
      when "inch"
        value_string = value.round(3).to_s + '"'
      when "feet"
        value_string = (value * (1.0 / 12.0)).round(4).to_s + "'"
      end
      value_string
    end

    def find_unit
      @metric = false
      @unit = nil

      if @input_string.include?("mm")
        @unit = "mm"
        @input_string.gsub!("mm", "")
        @metric = true
      end
      if @input_string.include?("cm")
        @unit = "cm"
        @input_string.gsub!("cm", "")
        @metric = true
      end
      if @input_string.include?("m") && !@input_string.include?("mm") && !@input_string.include?("cm")
        @unit = "m"
        @input_string.gsub!("m", "")
        @metric = true
      end
      if @input_string.include?('"')
        @unit = "inch"
        @input_string.gsub!('"', "")
      end
      if @input_string.include?("'")
        @unit = "feet"
        @input_string.gsub!("'", "")
      end

      return unless @unit.nil?

      @unit = Skalp.model_unit
    end

    def input_to_inch(num)
      case @unit
      when "mm"
        num / 25.4
      when "cm"
        num / 2.54
      when "m"
        num / 0.0254
      when "inch"
        num
      when "feet"
        num * 12.0
      end
    end
  end

  def sort_section_table(table)
    table.sort do |a, b|
      # split the keys of both elements into fields using the "|" separator
      fields_a = a[0].split("|")
      fields_b = b[0].split("|")

      # compare each field in order, using * as the lowest possible value
      result = 0
      fields_a.each_with_index do |field, i|
        # if one of the fields is * and the other is not, * should be sorted last
        if field == "*" && fields_b[i] != "*"
          result = 1
          break
        elsif field != "*" && fields_b[i] == "*"
          result = -1
          break
        end

        # if the fields are not equal, store the comparison result
        if field != fields_b[i]
          result = field <=> fields_b[i]
          break
        end
      end

      result
    end
  end

  def to_boolean(string)
    return string if [TrueClass, FalseClass].include?(string.class)

    string == "true"
  end

  def page_index_by_name(name)
    pages = Sketchup.active_model.pages

    i = 0
    pages.each do |page|
      return i if page.name == name

      i += 1
    end

    -1
  end

  def page_index(page_to_find)
    pages = Sketchup.active_model.pages

    i = 0
    pages.each do |page|
      return i if page == page_to_find

      i += 1
    end

    -1
  end

  def get_section_group(page_id)
    if Skalp.active_model.section_result_group
      Skalp.active_model.section_result_group.entities.grep(Sketchup::Group).each do |section_group|
        return section_group if section_group.get_attribute("Skalp", "ID") == page_id
      end
    end

    nil
  end

  def p(text)
    puts "#{Time.now.strftime('%H:%M:%S.%L')} #{text}" if DEBUG
  end

  def utf8(params)
    return "" unless params

    params.gsub!("//", "\\").to_s
    eval('"' + params + '"')
  end

  def change_active_sectionplane(sectionplane)
    skalp_sectionplane = Skalp.active_model.get_sectionplane_by_name(sectionplane)

    if sectionplane == "- #{NO_ACTIVE_SECTION_PLANE} -" || skalp_sectionplane.nil?
      Skalp.dialog.active_sectionplane_toggle = false
      Skalp.dialog.script("sections_switch_toggle(false)")
      Skalp.active_model.set_active_sectionplane("")
      Skalp.sectionplane_active = false
      Skalp.active_model.skalp_sections_off
      Skalp.active_model.skpModel.active_entities.active_section_plane = nil if Skalp.active_model.skpModel
      Skalp.dialog.set_icon("sections_delete", "icons/delete_inactive.png")
      Skalp.active_model.set_memory_attribute(Sketchup.active_model, "Skalp", "active_sectionplane_ID", "")
    else
      skpSectionplane = skalp_sectionplane.skpSectionPlane
      if skpSectionplane.valid? && skpSectionplane.parent.valid? && Skalp.active_model.skpModel.active_entities == skpSectionplane.parent.entities
        Skalp.dialog.active_sectionplane_toggle = true
        Skalp.dialog.script("sections_switch_toggle(true)")
        Skalp.active_model.activate_sectionplane_by_name(sectionplane)
        Skalp.sectionplane_active = true
        Skalp.active_model.skpModel.active_entities.active_section_plane = skpSectionplane
        Skalp.dialog.set_icon("sections_delete", "icons/delete.png")
        Skalp.active_model.set_memory_attribute(Sketchup.active_model, "Skalp", "active_sectionplane_ID",
                                                skpSectionplane.get_attribute("Skalp", "ID"))
      end
    end
  end

  def layer_check(layername)
    layername = layername.unicode_normalize(:nfkd).encode("ASCII", replace: "")
    layername.upcase[0..24].gsub(" ", "_").gsub(%r{[.,&<>"':;|=/\\*]}, "_")

    # not allowed:  < > / \ “ : ; ? * | = ‘
    # testing indicated that also not allowed . , & Ï Ë
    # no spaces allowed
    # max length 31 chars
  end

  def get_skalp_pattern_layer_definition
    definitions = Sketchup.active_model.definitions
    definitions.each do |definition|
      next unless definition.get_attribute("Skalp", "layers") == "1"

      definition.entities.clear!
      definition.entities.add_cpoint(Geom::Point3d.new(0, 0, 0))
      return definition if definition.valid?
    end

    new_name = definitions.unique_name("skalp_pattern_layers")
    definition = definitions.add(new_name)
    definition.entities.add_cpoint(Geom::Point3d.new(0, 0, 0))
    definition.set_attribute("Skalp", "layers", "1")
    definition.set_attribute("dynamic_attributes", "_hideinbrowser", true)
    UI.refresh_inspectors

    definition
  end

  def update_page(page)
    page.use_section_planes = true
    page.use_style = true
    page.use_hidden = true
    page.use_hidden_layers = true
    # page.use_camera = true

    Sketchup.active_model.rendering_options["DisplaySectionCuts"] = true
    Sketchup.active_model.rendering_options["SectionCutFilled"] = false

    mask = 115
    mask += 4 if page.use_shadow_info?
    mask += 8 if page.use_axes?

    styles = Sketchup.active_model.styles
    result = true
    result = make_new_style_from_active_settings if styles.active_style_changed

    page.update(mask) if result
  end

  def unique_style_name(style_name)
    num = style_name.reverse.to_i.to_s.reverse.to_i
    basename = style_name.gsub(num.to_s, "")

    styles = Sketchup.active_model.styles
    names = []
    styles.each do |style|
      names << style.name
    end

    num_match = 0
    names.each { |name| num_match += 1 if name.include?(basename) }

    basename + num_match.to_s
  end

  def hash_to_rendering_options(options)
    options.each { |k, v| Sketchup.active_model.rendering_options[k] = v }
  end

  def rendering_options_to_hash
    option_hash = {}
    Sketchup.active_model.rendering_options.each { |k, v| option_hash[k] = v }
    option_hash
  end

  def rendering_options_to_hash_from_page(page)
    option_hash = {}
    page.rendering_options.each { |k, v| option_hash[k] = v }
    option_hash
  end

  def force_style_to_show_skalp_section(skpPage)
    return unless skpPage.rendering_options["SectionCutFilled"]

    styles = Sketchup.active_model.styles

    page_rendering_options = rendering_options_to_hash_from_page(skpPage)
    page_rendering_options["SectionCutFilled"] = false

    hash_to_rendering_options(page_rendering_options)
    styles.update_selected_style

    mask = 115
    mask += 4 if skpPage.use_shadow_info?
    mask += 8 if skpPage.use_axes?

    skpPage.update(mask)
  end

  def make_new_style_from_active_settings
    styles = Sketchup.active_model.styles
    active_rendering_options = rendering_options_to_hash
    old_name = styles.selected_style.name.gsub("[", "").gsub("]", "")
    old_description = styles.selected_style.description.gsub("[", "").gsub("]", "")

    result = UI.inputbox(["Style changed"], ["Update the selected style"],
                         ["Update the selected style|Save as a new style"], "Warning - Scenes and Styles")

    return false unless result

    if result[0] == "Save as a new style"
      default = Sketchup.find_support_file("Plugins") + "/Skalp_Skalp2026/resources/SUStyles/default.style"
      styles.add_style(default, true)
      hash_to_rendering_options(active_rendering_options)
    end

    styles.update_selected_style

    if result[0] == "Save as a new style"
      styles.selected_style.name = unique_style_name(old_name)
      styles.selected_style.description = old_description
    end

    true
  end

  def equal_cameras?(cam1, cam2)
    return false if cam1.aspect_ratio != cam2.aspect_ratio || cam1.direction != cam2.direction || cam1.eye != cam2.eye ||
                    cam1.target != cam2.target || cam1.up != cam2.up || cam1.xaxis != cam1.xaxis || cam1.yaxis != cam2.yaxis ||
                    cam1.zaxis != cam2.zaxis

    return false unless cam1.perspective? == cam2.perspective?

    if cam1.perspective? && cam2.perspective? && (cam1.focal_length != cam2.focal_length || cam1.fov != cam2.fov)
      return false
    end

    true
  end

  def check_color_by_layer_layers
    model = Sketchup.active_model
    materials = model.materials
    layers = model.layers
    missing_material_layers = []
    materials.each do |material|
      next unless material.get_attribute("Skalp", "ID")

      layer_name = if Skalp.skalp_material_info(material, :name)
                     "\uFEFF".encode("utf-8") + "Skalp Pattern Layer - " + Skalp.skalp_material_info(material, :name)
                   else
                     material.name
                   end

      if layers[layer_name]
        layers[layer_name].visible = true
      else
        missing_material_layers << material
      end
    end

    create_Color_by_Layer_layers(missing_material_layers, true) if missing_material_layers != []
  end

  def skalp_pattern_layers_used?
    return true if check_skalp_pattern_style(Sketchup.active_model)

    Sketchup.active_model.pages.each do |page|
      return true if check_skalp_pattern_style(page)
    end

    false
  end

  def check_skalp_pattern_style(object)
    case object
    when Sketchup::Model
      attrib = Skalp.active_model.get_memory_attribute(object, "Skalp", "style_layer")
      return false unless attrib

      rules = eval(attrib)
    when Sketchup::Page
      if Skalp.active_model.get_memory_attribute(object, "Skalp",
                                                 "style_layer") != "" && Skalp.active_model.get_memory_attribute(
                                                   object, "Skalp", "style_layer"
                                                 ) != nil
        rules = eval(Skalp.active_model.get_memory_attribute(object, "Skalp", "style_layer"))
      else
        return false if Skalp.active_model.get_memory_attribute(Sketchup.active_model, "Skalp",
                                                                "style_layer") == "" || Skalp.active_model.get_memory_attribute(
                                                                  @skpModel, "Skalp", "style_layer"
                                                                ).nil?

        rules = eval(Skalp.active_model.get_memory_attribute(Sketchup.active_model, "Skalp", "style_layer"))
      end
    end

    rules.each do |rule_string|
      rule = if rule_string.class == Hash
               rule_string
             else
               eval(rule_string)
             end

      return true if rule[:layer] == "Skalp Pattern Layer"
    end

    false
  end

  def create_Color_by_Layer_layers(materials = Sketchup.active_model.materials, update = false)
    return if @block_color_by_layer

    Skalp.active_model.start("Skalp - #{Skalp.translate('create pattern layers')}", true)

    model = Sketchup.active_model
    layers = model.layers

    block_observer_status = Skalp.block_observers
    observer_status = Skalp.active_model.observer_active

    Skalp.active_model.observer_active = false
    Skalp.block_observers = true

    definition = get_skalp_pattern_layer_definition

    n = 0
    layer_names = []
    to_delete = []
    materials.each do |material|
      next unless material.get_attribute("Skalp", "ID")

      layer_name = if Skalp.skalp_material_info(material, :name)
                     "\uFEFF".encode("utf-8") + "Skalp Pattern Layer - " + Skalp.skalp_material_info(material, :name)
                   else
                     material.name
                   end

      layer_names << layer_name

      if definition.valid?
        face = definition.entities.add_face([0 + n, 0, 0], [10 + n, 0, 0], [10 + n, 10, 0])
        face.material = material
      end
      n += 20
    end

    check_pattern_layername = layer_names.first

    unless check_pattern_layername
      Skalp.block_observers = block_observer_status
      Skalp.active_model.observer_active = observer_status
      Skalp.active_model.commit
      return
    end

    temp_dir = create_temp_dir

    layer_component = temp_dir + "layers.skp"

    definition.save_as(layer_component)
    create_layer_materials(temp_dir, layer_names)

    if update
      layer_names.each do |layername|
        to_delete << layers[layername] if layers[layername] && layers[layername].valid?
      end
    else
      model.layers.each do |layer|
        to_delete << layer if layer.name.include?("Skalp Pattern Layer - ")
      end
    end

    delete_layers(to_delete) if to_delete != []
    layer_component_new = temp_dir + "layers_new.skp"
    File.rename(layer_component, layer_component_new)

    Skalp.delete_definition(definition)
    render_mode = Sketchup.active_model.rendering_options["RenderMode"]
    model.definitions.load(layer_component_new)
    Sketchup.active_model.rendering_options["RenderMode"] = render_mode

    Skalp.active_model.setup_skalp_folders

    Skalp.block_observers = block_observer_status
    Skalp.active_model.observer_active = observer_status
    Skalp.active_model.commit

    Skalp.active_model.active_sectionplane.section.update if Skalp.active_model.active_sectionplane
  end

  def remove_scene_name(filename)
    Sketchup.active_model.pages.each do |page|
      next unless page
      return filename.gsub("-#{page.name}", "") if filename.include?("-#{page.name}")
    end
    filename
  end

  def create_temp_dir
    temp_dir = SKALP_PATH + "resources/temp/"
    FileUtils.mkdir(temp_dir) unless Dir.exist?(temp_dir)
    temp_dir
  end

  def delete_definition(definition_to_delete)
    return unless Skalp.active_model

    observer_status = Skalp.active_model.observer_active
    Skalp.active_model.observer_active = false

    Skalp.active_model.force_start_transparant("Skalp - delete definition")

    definition_to_delete.instances.each { |i| i.erase! }
    definition_to_delete.entities.clear!

    Skalp.active_model.force_commit

    Skalp.active_model.observer_active = observer_status
  end

  def check_pattern_layers
    materials = Sketchup.active_model.materials
    layers = Sketchup.active_model.layers
    materials.each do |material|
      if material.get_attribute("Skalp", "ID")
        layer_name = "\uFEFF".encode("utf-8") + "Skalp Pattern Layer - " + Skalp.skalp_material_info(material, :name)
        return false unless layers[layer_name]
      end
    end
    true
  end

  def create_layer_materials(temp_dir, layer_names)
    require "Skalp_Skalp2026/shellwords/shellwords"

    path = Shellwords.escape(SKALP_PATH + "lib/")

    layer_names_base64 = Base64.strict_encode64(array_to_string_array(layer_names))

    command = if OS == :WINDOWS
                %("#{path[1..-2]}Skalp.exe" "create_layer_materials" "#{temp_dir}" "#{layer_names_base64}")
              else
                %(#{path}Skalp "create_layer_materials" "#{temp_dir}" "#{layer_names_base64}")
              end
    stdout = start_new_process(command.encode("utf-8"))
    stdout.close if stdout && OS == :WINDOWS
  end

  def modifyStyle(temp_path, new_path)
    require "Skalp_Skalp2026/shellwords/shellwords"

    path = Shellwords.escape(SKALP_PATH + "lib/")

    command = if OS == :WINDOWS
                %("#{path[1..-2]}Skalp.exe" "modifyStyle" "#{temp_path}" "#{new_path}" )
              else
                %(#{path}Skalp "modifyStyle" "#{temp_path}" "#{new_path}")
              end

    stdout = start_new_process(command.encode("utf-8"))
    stdout.close if stdout && OS == :WINDOWS
  end

  def setup_reversed_scene(temp_dir, new_temp_dir, index_array, reversed_eye_array, reversed_target_array,
                           transformation_array, group_id_array, up_vector_array, modelbounds)
    require "Skalp_Skalp2026/shellwords/shellwords"

    path = Shellwords.escape(SKALP_PATH + "lib/")

    if OS == :WINDOWS
      command = %("#{path[1..-2]}Skalp.exe" "setup_reversed_scene" "#{temp_dir}" "#{new_temp_dir}" "#{array_to_string_array(index_array)}" "#{point_array_to_string_array(reversed_eye_array)}" "#{point_array_to_string_array(reversed_target_array)}" "#{point_array_to_string_array(transformation_array)}" "#{array_to_string_array(group_id_array)}" "#{point_array_to_string_array(up_vector_array)}" "#{modelbounds}")
    else
      command = %(#{path}Skalp "setup_reversed_scene" "#{temp_dir}" "#{new_temp_dir}" "#{array_to_string_array(index_array)}" "#{point_array_to_string_array(reversed_eye_array)}" "#{point_array_to_string_array(reversed_target_array)}" "#{point_array_to_string_array(transformation_array)}" "#{array_to_string_array(group_id_array)}" "#{point_array_to_string_array(up_vector_array)}" "#{modelbounds}")
    end

    stdout = start_new_process(command.encode("utf-8"))
    stdout.close if stdout && OS == :WINDOWS
  end

  def get_exploded_entities(temp_dir, height, index_array, scale_array, perspective_array, target_array, rear_view)
    require "Skalp_Skalp2026/shellwords/shellwords"

    path = Skalp::Shellwords.escape(SKALP_PATH + "lib/")
    if OS == :WINDOWS
      command = %("#{path[1..-2]}Skalp.exe" "get_exploded_entities" "#{temp_dir}" "#{height}" "#{array_to_string_array(index_array)}" "#{array_to_string_array(scale_array)}" "#{array_to_string_array(perspective_array)}" "#{point_array_to_string_array(target_array)}" "#{rear_view}") #--silent
    else
      command = %(#{path}Skalp "get_exploded_entities" "#{temp_dir}" "#{height}" "#{array_to_string_array(index_array)}" "#{array_to_string_array(scale_array)}" "#{array_to_string_array(perspective_array)}" "#{point_array_to_string_array(target_array)}" "#{rear_view}")
    end

    stdout = start_new_process(command.encode("utf-8"))

    hiddenline_data = nil
    exploded_lines = []

    return exploded_lines unless stdout

    stdout.each_line do |line|
      # The cout stream sometimes add an error message in front about that the stream is a bad TIFF or MDI file
      # We remove all added messages in front of our cout stream
      line = line.sub(/^.*?(\*[DITLE]\*)/, '\1')

      type = line[0, 3]
      data = line[3..-1]

      case type
      when "*D*"
        pp data
      when "*I*"
        hiddenline_data = Hiddenlines_data.new(data)
      when "*T*"
        hiddenline_data.target = Skalp.safe_eval(data)
      when "*L*"
        rgb = data[0..data.index("[") - 1]
        data = data[data.index("[")..-1]
        layer = Skalp.active_model.hiddenlines.get_hiddenline_properties(rgb)
        hiddenline_data.add_line(Skalp.safe_eval(data), layer)
      when "*E*"
        exploded_lines << hiddenline_data
      end
    end

    stdout.close if OS == :WINDOWS
    exploded_lines
  end

  def process_active?
    wmi = WIN32OLE.connect("winmgmts://")
    processes = wmi.ExecQuery("select * from win32_process")

    pid = nil

    for proces in processes
      pid = proces.ProcessId if proces.Name == "Skalp.exe"
    end

    pid ? true : false
  end

  def start_new_process(cmd)
    if OS == :WINDOWS
      output = SKALP_PATH + "lib/skalp_output.txt"
      File.delete(output) if File.exist?(output)

      require "win32ole"
      objStartup = WIN32OLE.connect("winmgmts:\\\\.\\root\\cimv2:Win32_ProcessStartup")
      objConfig = objStartup.SpawnInstance_
      objConfig.ShowWindow = 0 # HIDDEN_WINDOW
      objProcess = WIN32OLE.connect("winmgmts:root\\cimv2:Win32_Process")

      objProcess.Create(cmd, nil, objConfig, nil)

      sleep 0.1 while process_active?
      return false unless File.exist?(output)

      result = File.open(output)

    else
      require "open3"
      result = nil
      error = nil
      puts "[DEBUG] Skalp External Command: #{cmd}"
      Open3.popen3(cmd) do |stdin, stdout, stderr|
        result = stdout.read
        error = stderr.read
      end
      puts "[DEBUG] Skalp External Stderr: #{error}" unless error.empty?
      puts "[DEBUG] Skalp External Stdout snippet: #{result[0..500]}" if result
      return result
    end

    result
  end

  def array_to_string_array(array)
    string_array = nil

    array.each do |element|
      string_array ? string_array += "|" + element.to_s : string_array = element.to_s
    end

    string_array
  end

  def point_to_string_array(array)
    string_array = nil

    array.each do |element|
      string_array ? string_array += "," + element.to_s : string_array = element.to_s
    end

    string_array
  end

  def point_array_to_string_array(array)
    string_array = nil

    array.each do |element|
      string_array ? string_array += "|" + point_to_string_array(element.to_a) : string_array = point_to_string_array(element.to_a)
    end

    string_array
  end

  def inch_to_modelunits(value)
    return 0.0 unless value

    case Sketchup.active_model.options["UnitsOptions"]["LengthFormat"]
    when 0
      factor = Sketchup.format_length(1_000_000).gsub("~", "").to_f / 1_000_000 # decimal
    when 1
      factor = 1.0 # architectural
    when 2
      factor = 1.0 # engineering
    when 3
      factor = Sketchup.format_length(1_000_000).gsub("~", "").to_f / 1_000_000 # fractional
    end

    value * factor
  end

  def aligned(e)
    return false unless e.is_a?(Sketchup::Entity)

    info = get_pattern_info(e)
    if info
      info[:alignment] == "true"
    else
      false
    end
  end

  def key(flags, key = 0, status = :no_status)
    if OS == :MAC
      shift = (flags & CONSTRAIN_MODIFIER_MASK) == CONSTRAIN_MODIFIER_MASK
      alt = (flags & COPY_MODIFIER_MASK) == COPY_MODIFIER_MASK
      command = (flags & ALT_MODIFIER_MASK) == ALT_MODIFIER_MASK
      shift_alt = (flags & (CONSTRAIN_MODIFIER_MASK | COPY_MODIFIER_MASK)) == CONSTRAIN_MODIFIER_MASK | COPY_MODIFIER_MASK

      if shift_alt # -
        :shift_alt
      elsif shift # +-
        :shift
      elsif alt # +
        :alt
      elsif command # +- in component
        :command
      else
        :no_key
      end
    else
      @shift ||= false
      @control ||= false
      @alt ||= false

      @shift = true if key == VK_SHIFT && status == :down
      @alt = true if key == VK_ALT && status == :down
      @control = true if key == VK_CONTROL && status == :down
      @shift = false if key == VK_SHIFT && status == :up
      @alt = false if key == VK_ALT && status == :up
      @control = false if key == VK_CONTROL && status == :up

      # puts "@shift: #{@shift}"
      # puts "@control: #{@control}"
      # puts "@alt: #{@alt}"

      if @shift && @control && !@alt # -
        :shift_alt
      elsif @shift && !@control && !@alt # +-
        :shift
      elsif !@shift && @control && !@alt # +
        :alt
      elsif !@shift && !@control && @alt # +- in component
        :command
      else
        :no_key
      end
    end
  end

  def page_valid?(page)
    Sketchup.active_model.pages.to_a.include?(page)
  end

  def delete_layers(layers_to_delete)
    layers_to_delete = [layers_to_delete] if layers_to_delete.class == Sketchup::Layer
    layers_to_delete = layers_to_delete.to_a

    model = Sketchup.active_model

    ents = model.entities
    defs = model.definitions
    layers = model.layers

    ents.grep(Sketchup::Group) { |e| e if layers_to_delete.include?(e.layer) }.each { |e| e.locked = false if e }
    layers_to_delete.each { |layer| layers.remove(layer, true) }
  end

  def to_inch(measure)
    measure = measure.to_s.gsub(" ", "") # measure = measure.gsub(/[^\d(.|,)]/,"")
    measure_string = correct_decimal(measure.to_s)
    Sketchup.parse_length(measure_string)
    # Sketchup.format_length(Sketchup.parse_length(measure_string)).to_l.to_inch
  end

  def pen2inch(pen)
    if pen.class == Float
      pen
    elsif pen.include?("pt")
      pen.gsub("pt", "").gsub(" ", "").to_f / 72.0
    elsif pen.include?("mm")
      pen.gsub("mm", "").gsub(" ", "").to_f / 25.4
    else
      pen.to_f
    end
  end

  def inch2pen(num)
    return "0.1 pt" unless num
    return "0.00 mm" if num == 0.0

    case num
    when 0.0..0.00148
      "0.1 pt"
    when 0.00148..0.00216
      "0.04 mm"
    when 0.00216..0.00276
      "0.07 mm"
    when 0.00276..0.00394
      "0.2 pt"
    when 0.00394..0.0054
      "0.13 mm"
    when 0.0054001..0.0069
      "0.4 pt"
    when 0.0069001..0.0079
      "0.18 mm"
    when 0.0079001..0.009
      "0.6 pt"
    when 0.009001..0.0099
      "0.25 mm"
    when 0.0099001..0.0137
      "0.8 pt"
    when 0.0137001..0.018
      "0.35 mm"
    when 0.018001..0.019
      "1.0 pt"
    when 0.019001..0.0199
      "0.50 mm"
    when 0.0199001..0.025
      "1.5 pt"
    when 0.02501..0.0276
      "0.70 mm"
    when 0.0276001..0.029
      "2.0 pt"
    when 0.029001..0.05
      "1.00 mm"
    when 0.05001..1.0
      "2.00 mm"
    else
      "0.1 pt"
    end
  end

  def inch2dxf_lineweight(num)
    return 5 unless num
    return 0 if num == 0.0

    case num
    when 0.0..0.00148
      5
    when 0.00148..0.00216
      5
    when 0.00216..0.00276
      9
    when 0.00276..0.00394
      9
    when 0.00394..0.0054
      13
    when 0.0054001..0.0069
      15
    when 0.0069001..0.0079
      18
    when 0.0079001..0.009
      20
    when 0.009001..0.0099
      25
    when 0.0099001..0.0137
      30
    when 0.0137001..0.018
      35
    when 0.018001..0.019
      35
    when 0.019001..0.0199
      50
    when 0.0199001..0.025
      53
    when 0.02501..0.0276
      70
    when 0.0276001..0.029
      70
    when 0.029001..0.05
      100
    when 0.05001..1.0
      200
    else
      5
    end
  end

  def correct_decimal(string_number)
    decimal_separator == "." ? string_number.gsub(",", ".") : string_number.gsub(".", ",")
  end

  def decimal_separator
    "1.0".to_l
    "."
  rescue ArgumentError
    ","
  end

  def model_unit
    user_setting = Sketchup.active_model.options["UnitsOptions"]["SuppressUnitsDisplay"]
    Sketchup.active_model.options["UnitsOptions"]["SuppressUnitsDisplay"] = false
    check = Sketchup.format_length(1)
    Sketchup.active_model.options["UnitsOptions"]["SuppressUnitsDisplay"] = user_setting

    unit = nil
    unit = "mm" if check.include?("mm")
    unit = "cm" if check.include?("cm")
    unit = "m" if check.include?("m") && !check.include?("mm") && !check.include?("cm")
    unit = "inch" if check.include?('"')
    unit = "feet" if check.include?("'")

    unit
  end

  def unit_string_to_inch(unit_string)
    # return unit_string.to_f if unit_string.to_f.to_s == unit_string
    tile = Tile_size.new
    tile.calculate(unit_string, :x)
    tile.x_value
  end
  module_function :unit_string_to_inch

  def mm_or_pts_to_inch(pen)
    return pen if pen.to_f.to_s == pen.to_s

    if pen.include?("mm") # pen_paper
      pen_width = Skalp.to_inch(pen) # TODO: hier blijkt iets fouts te lopen
      pen_width ||= 0.070866
    else
      pen_width = pen.gsub(" pt", "").to_f / 72
      pen_width ||= 0.070866
    end
    pen_width
  end

  def get_ID(entity)
    return unless entity && entity.is_a?(Sketchup::Entity) && entity.valid?

    if entity.class == Sketchup::Page
      Skalp.active_model.get_memory_attribute(entity, "Skalp", "ID")
    else
      entity.get_attribute("Skalp", "ID")
    end
  end

  def set_ID(entity)
    return unless entity && entity.is_a?(Sketchup::Entity) && entity.valid?

    if entity.class == Sketchup::Page
      unless Skalp.active_model.get_memory_attribute(entity, "Skalp", "ID")
        id = generate_ID
        Skalp.active_model.set_memory_attribute(entity, "Skalp", "ID", id)
        Skalp.active_model.start
        entity.set_attribute("Skalp", "ID", id)
        Skalp.active_model.commit
      end
    else
      entity.set_attribute("Skalp", "ID", generate_ID) unless entity.get_attribute("Skalp", "ID")
    end

    Skalp.get_ID(entity)
  end

  def generate_ID
    SecureRandom.uuid
  end

  def get_definition_entities(object)
    return unless object
    return object.entities if object.class == Sketchup::Model
    return object.definition.entities if object.is_a?(Sketchup::ComponentInstance)

    object.entities if object.is_a?(Sketchup::Group)

    # dl=object.model.definitions.to_a
    # if dl.length>0
    #   # find definition
    #   # enumObj.find returns first true result or nil
    #   df = dl.find { |cd|
    #     cd.group? && cd.instances.include?(object)
    #   }
    #   unless df.nil?
    #     return df.entities
    #   else
    #     raise(IndexError, " in `definition', Sketchup::Group object does not have a definition in the active_model DefinitionList. (count: #{dl.length.to_s})")
    #   end
    # else
    #   raise(IndexError, " in `definition', Sketchup::Group object does not have a definition! The active_model DefinitionList is empty.")
    # end
  end

  # class

  def material_inside_object(object)
    return object.material unless object.material.nil?

    entities = get_definition_entities(object)
    materials = Set.new

    entities.grep(Sketchup::Face).each do |face|
      (materials << face.material) || face.back_material
    end

    if materials.size == 1
      return materials.first if materials.first && materials.first.valid?

      nil

    else
      return object.material if object.material && object.material.valid?

      nil

    end
  end

  def layer_inside_object(object)
    return object.layer if object.layer.name != "Layer0"

    entities = get_definition_entities(object)
    layers = Set.new

    entities.grep(Sketchup::Face).each do |face|
      layers << face.layer
    end

    return layers.first.name if layers.size == 1

    object.layer.name
  end

  def active_filename
    name = File.basename(Sketchup.active_model.path.gsub(".skp", ""))
  end

  def check_filename(filename)
    filename.gsub!(%r{^.*(\\|/)}, "")
    filename.gsub!(/[^0-9A-Za-z.-]/, "_")
    filename
  end

  def object?(entity)
    return false unless entity.valid?
    return true if entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)

    false
  end

  def find_toplevel_parents(entity, parents_array)
    return [entity] if entity.parent == Sketchup.active_model

    if entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
      for parentinstance in entity.parent.instances
        if parentinstance.parent == Sketchup.active_model
          parents_array << parentinstance
        elsif parentinstance.parent != Sketchup.active_model
          find_toplevel_parents(parentinstance, parents_array)
        end
      end
    end
    parents_array
  end

  def size_to_filename(size)
    size = size.round(4)
    string_size = Sketchup.format_length(size).to_s

    if string_size.include?("'") && !string_size.include?("\"")
      string_size.gsub!("'", " feet")
    elsif string_size.include?("'") || string_size.include?("\"")
      string_size = size.to_s + " inch"
    end

    string_size
  end

  def self.color_from_name(colorname)
    color = Sketchup::Color.new(colorname)
    "rgb(#{color.red}, #{color.green}, #{color.blue})"
  rescue StandardError
    nil
  end

  def self.linestyle_layer_visible
    style_layers = []

    Sketchup.active_model.layers.each do |layer|
      if layer.name.include?("Skalp linestyle -")
        style_layers << layer
        layer.visible = true
      end
    end

    Sketchup.active_model.pages.each do |page|
      style_layers.each do |layer|
        page.set_visibility(layer, true)
      end
    end
  end

  def self.fixTagFolderBug(location)
    model = Sketchup.active_model
    layers = model.layers
    folders = layers.folders
    Skalp.active_model.start("Skalp - Fix TagFolder Bug", false)
    check_folder(folders, location)
    Skalp.active_model.commit
  end

  def self.check_folder(folders, location)
    folders.each do |folder|
      folder.layers.each do |layer|
        next unless layer.model.nil?

        begin
          folder.remove_layer(layer)
          raise("remove ghost layer: #{folder.name} / #{layer.name} - #{location}")
        rescue StandardError => e
          Skalp.send_info("TagFolder bug")
          Skalp.send_bug(e)
        end
      end
      check_folder(folder.folders, location)
    end
  end

  def self.create_linestyle_layer(linestyle)
    model = Sketchup.active_model
    return nil unless model.line_styles.names.include?(linestyle)

    layername = "Skalp linestyle - #{linestyle}"
    layer = model.layers.add("\uFEFF".encode("utf-8") + layername)
    layer.folder = Skalp.active_model.linestyle_folder
    layer.visible = true
    Skalp.active_model.linestyle_folder.visible = true

    line_style = Sketchup.active_model.line_styles[linestyle]
    layer.line_style = line_style
    layer.set_attribute("Skalp", "ID", generate_ID)
    layer
  end

  def self.create_rearview_layer(layername)
    model = Sketchup.active_model
    layername = "Skalp rearview - #{layername}"
    layer = model.layers.add(layername)
    layer.folder = Skalp.active_model.rearview_folder
    layer.visible = true
    Skalp.active_model.rearview_folder.visible = true
    layer.set_attribute("Skalp", "ID", generate_ID)
    layer
  end

  def self.get_rearview_linestyle_by_tag
    linestyle = {}
    Sketchup.active_model.layers.each do |layer|
      next unless layer.name.include?("Skalp rearview - ")

      layername = layer.name.gsub("Skalp rearview - ", "")

      next unless layer.line_style

      style = layer.line_style.name.gsub(" ", "_").upcase
      style = "CONTINUOUS" if style == "SOLID_BASIC"
      linestyle[layername] = style
    end
    linestyle
  end

  def scene_section_layer
    model = Sketchup.active_model
    layername = "Skalp Scene Sections"
    layer = model.layers.add("\uFEFF".encode("utf-8") + layername)
    layer.set_attribute("Skalp", "ID", generate_ID)
    layer.page_behavior = LAYER_HIDDEN_BY_DEFAULT

    if Skalp.active_model.skalp_folder && Skalp.active_model.skalp_folder.valid?
      Skalp.active_model.skalp_folder.visible = true
    else
      Skalp.active_model.setup_skalp_folders
      Skalp.active_model.skalp_folder.visible = true
    end

    layer.folder = Skalp.active_model.skalp_folder
    layer.visible = false
    layer
  end

  def sectiongroup_visibility(group, status, page = nil)
    if page
      if status
        page.set_drawingelement_visibility(group, true)
        page.set_visibility(group.layer, true)
        group.hidden = false
      else
        page.set_drawingelement_visibility(group, false)
        page.set_visibility(group.layer, true)
        group.hidden = false
      end
    else
      group.hidden = if status
                       false
                     else
                       true
                     end
    end
  end

  def self.create_sectionmaterial(materialname)
    pattern_info = eval(Sketchup.active_model.get_attribute("Skalp_sectionmaterials", materialname))
    pattern_info[:name] = materialname

    if pattern_info[:line_color].nil? && pattern_info[:line_color].nil? && color_from_name(pattern_info[:name])
      pattern_info[:line_color] = color_from_name(pattern_info[:name])
      pattern_info[:fill_color] = color_from_name(pattern_info[:name])
    end

    if pattern_info[:line_color] && !pattern_info[:line_color].include?("rgb")
      pattern_info[:line_color] = color_from_name(pattern_info[:line_color]) || "rgb(0,0,0)"
    end

    if pattern_info[:fill_color] && !pattern_info[:fill_color].include?("rgb")
      pattern_info[:fill_color] = color_from_name(pattern_info[:fill_color]) || "rgb(255,255,255)"
    end

    pattern_info[:line_color] = pattern_info[:fill_color] if pattern_info[:fill_color] && pattern_info[:line_color].nil?

    pattern_definition = {
      name: "no_name",
      pattern: ["*ANSI31, ANSI IRON, BRICK, STONE MASONRY", "45, 0,0, 0,.125"],
      pattern_size: "3mm",
      line_color: "rgb(0,0,0)",
      fill_color: "rgb(255,255,255)",
      pen: 0.0071,
      section_cut_width: 0.0071,
      alignment: false
    }.merge(pattern_info)

    pattern = ["*#{pattern_definition[:name]}"] + pattern_definition[:pattern]
    alignment_string = pattern_definition[:alignment] ? "true" : "false"

    pattern_string = { name: pattern_definition[:name],
                       pattern: pattern,
                       print_scale: 1,
                       resolution: 600,
                       user_x: pattern_definition[:pattern_size],
                       space: :paperspace,
                       line_color: pattern_definition[:line_color],
                       fill_color: pattern_definition[:fill_color],
                       pen: pattern_definition[:pen], # 0.18mm
                       section_cut_width: pattern_definition[:section_cut_width], # 0.35mm
                       alignment: alignment_string }

    if Skalp.active_model
      Skalp.active_model.start("Skalp - #{Skalp.translate('Create Skalp material')}",
                               true)
    else
      Sketchup.active_model.start_operation(
        "Skalp - #{Skalp.translate('Create Skalp material')}", true, false, false
      )
    end

    hatch = SkalpHatch::Hatch.new
    hatch.add_hatchdefinition(SkalpHatch::HatchDefinition.new(pattern_string[:pattern]))

    tile = Tile_size.new
    tile.calculate(pattern_string[:user_x], :x)

    create_png_result = hatch.create_png({
                                           type: :tile,
                                           line_color: pattern_string[:line_color],
                                           fill_color: pattern_string[:fill_color],
                                           pen: pattern_string[:pen], # pen_width in inch (1pt = 1.0 / 72)
                                           resolution: Hatch_dialog::PRINT_DPI,
                                           print_scale: 1,
                                           user_x: tile.x_value,
                                           space: pattern_string[:space]
                                         })

    pattern_string[:pattern] = create_png_result[:original_definition]
    pattern_string[:user_x] = tile.x_string
    pattern_hash = pattern_string.merge(create_png_result)
    pattern_hash.delete(:original_definition)

    Sketchup.active_model.materials[pattern_hash[:name]] || hatch_material = Sketchup.active_model.materials.add(pattern_hash[:name])

    hatch_material.texture = IMAGE_PATH + "tile.png"
    hatch_material.texture.size = hatch.tile_width / Hatch_dialog::PRINT_DPI
    hatch_material.metalness_enabled = false
    hatch_material.normal_enabled = false

    set_ID(hatch_material)
    set_pattern_info_attribute(hatch_material, pattern_hash)

    Skalp.active_model ? Skalp.active_model.commit : Sketchup.active_model.commit_operation
  end

  def create_skalp_default_material(name = "Skalp default", line_color = "rgb(110, 110, 110)",
                                    fill_color = "rgb(244, 244, 244)")
    if Skalp.active_model
      active_model.start("Skalp - #{Skalp.translate('Create default material')}",
                         true)
    else
      Sketchup.active_model.start_operation("Skalp - #{Skalp.translate('Create default material')}", true, false,
                                            false)
    end

    pattern_string = { name: name,
                       pattern: ["*ANSI31, ANSI IRON, BRICK, STONE MASONRY", "45, 0,0, 0,.125"],
                       print_scale: 1,
                       resolution: 600,
                       user_x: "3.0mm",
                       space: :paperspace,
                       line_color: line_color,
                       fill_color: fill_color,
                       pen: 0.007086614173228346, # 0.18mm
                       section_cut_width: 0.0137795276, # 0.35mm
                       alignment: "false" }

    hatch = SkalpHatch::Hatch.new
    hatch.add_hatchdefinition(SkalpHatch::HatchDefinition.new(pattern_string[:pattern]))

    tile = Tile_size.new
    tile.calculate(pattern_string[:user_x], :x)

    create_png_result = hatch.create_png({
                                           type: :tile,
                                           line_color: pattern_string[:line_color],
                                           fill_color: pattern_string[:fill_color],
                                           pen: pattern_string[:pen], # pen_width in inch (1pt = 1.0 / 72)
                                           resolution: Hatch_dialog::PRINT_DPI,
                                           print_scale: 1,
                                           user_x: tile.x_value,
                                           space: pattern_string[:space]
                                         })

    pattern_string[:pattern] = create_png_result[:original_definition]
    pattern_string[:user_x] = tile.x_string
    pattern_hash = pattern_string.merge(create_png_result)
    pattern_hash.delete(:original_definition)

    Sketchup.active_model.materials[pattern_hash[:name]] || hatch_material = Sketchup.active_model.materials.add(pattern_hash[:name])

    hatch_material.texture = IMAGE_PATH + "tile.png"
    hatch_material.texture.size = hatch.tile_width / Hatch_dialog::PRINT_DPI
    hatch_material.metalness_enabled = false
    hatch_material.normal_enabled = false

    set_ID(hatch_material)

    set_pattern_info_attribute(hatch_material, pattern_hash)

    if Skalp.active_model
      Skalp.active_model.commit
      # create_Color_by_Layer_layers([hatch_material], true)
    else
      Sketchup.active_model.commit_operation
    end
  end

  def check_skalp_default_material
    material = Sketchup.active_model.materials["Skalp default"]

    if material
      create_skalp_default_material unless skalp_material_info(material, :pattern)
    else
      create_skalp_default_material
    end

    material = Sketchup.active_model.materials["Skalp linecolor"]
    create_skalp_default_material("Skalp linecolor", "rgb(0,0,0)", "rgb(0,0,0)") unless material

    materials = Sketchup.active_model.materials
    return if materials["Skalp transparent"]

    materials.add("Skalp transparent").alpha = 0.0
  end

  def add_invisible_space(string)
    invisible_space = "\uFEFF".encode("utf-8")
    invisible_space + string
  end

  def rendering_options?(object)
    return object if object == Sketchup.active_model
    return object if object.use_rendering_options?

    Sketchup.active_model
  end

  def edit_skalp_material(hatchname)
    return unless Sketchup.active_model == Skalp.active_model.skpModel && hatchname != ""

    material = Sketchup.active_model.materials[hatchname]

    return unless material && material.get_attribute("Skalp", "ID")

    if Skalp.hatch_dialog
      Skalp.hatch_dialog.show
      Skalp.hatch_dialog.script("select_material('#{hatchname}');")
    else
      Skalp.hatch_dialog = Hatch_dialog.new(hatchname)
      Skalp.hatch_dialog.show
    end
  end

  def duplicate_skalp_material(hatchname)
    return unless Sketchup.active_model == Skalp.active_model.skpModel && hatchname != ""

    material = Sketchup.active_model.materials[hatchname]

    return unless material && material.get_attribute("Skalp", "ID")

    if Skalp.hatch_dialog
      Skalp.hatch_dialog.show
      Skalp.hatch_dialog.script("select_material('#{hatchname}');")
    else
      Skalp.hatch_dialog = Hatch_dialog.new(hatchname)
      Skalp.hatch_dialog.show
    end
  end

  def create_new_skalp_material
    if Skalp.hatch_dialog
      Skalp.hatch_dialog.show
    else
      Skalp.hatch_dialog = Hatch_dialog.new
      Skalp.hatch_dialog.show
    end
    Skalp.hatch_dialog.clear_dialog(true)
  end

  def get_Skalp_sectionplane_name(skpSectionplane)
    name = ""
    symbolname = ""

    if skpSectionplane.get_attribute("Skalp", "ID")

      name = skpSectionplane.get_attribute("Skalp", "sectionplane_name").strip

      if skpSectionplane.name == name
        name = skpSectionplane.name
        symbolname = skpSectionplane.symbol
      else
        symbolname = if name.size > 3
                       name[-3..-1].strip
                     else
                       name
                     end
      end

      if name == ""
        name = skpSectionplane.name
        symbolname = skpSectionplane.symbol
      end
    end

    { name: name.to_s, symbol: symbolname.to_s }
  end

  def show_message_dialog(message)
    @message_dialog = UI::HtmlDialog.new(
      {
        dialog_title: "Skalp message",
        preferences_key: "skalp.plugin",
        scrollable: false,
        resizable: false,
        width: 250,
        height: 100,
        left: 250,
        top: 250,
        style: UI::HtmlDialog::STYLE_UTILITY
      }
    )

    html = <<~HTMLCODE
      <!DOCTYPE html>
      <html>
      <head>

      <style>
      #message {
      font-size: 12px;
      font-family: "Arial", sans-serif;
      text-align: center;
      vertical-align: middle;
      line-height: 84px;
      background-color: rgb(231,231,231);
      margin: 0px;
      }

      body {
      margin: 0px;
      }
      </style>
      </head>
      <body>
      <p id='message'>#{message}</p>
      </body>
      </html>
    HTMLCODE

    @message_dialog.set_html(html)
    @message_dialog.show
  end

  def close_message_dialog
    @message_dialog.close
  end

  def safe_eval(string)
    return nil if string.nil? || string.empty?

    # Check if string contains NaN or Infinity and log where it came from
    if string =~ /\b(NaN|nan|Infinity|inf|INF)\b/
      puts "=" * 60
      puts "⚠️  Skalp.safe_eval: NaN/Infinity detected!"
      puts "    Value found: #{::Regexp.last_match(1)}"
      puts "    String preview: #{string[0..200]}..."
      puts "    Called from:"
      caller[0..5].each { |line| puts "      #{line}" }
      puts "=" * 60
    end

    # Replace NaN and Infinity with nil to avoid NameError during eval
    clean_string = string.gsub(/\b(NaN|nan|Infinity|inf|INF)\b/, "nil")
    eval(clean_string)
  rescue StandardError => e
    puts "Skalp.safe_eval error: #{e.message} for string: #{string[0..100]}..."
    nil
  end
end
