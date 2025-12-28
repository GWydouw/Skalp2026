module Skalp
  require 'open-uri'
  require 'net/http'

  def self.get_patterns_to_string
    return unless Sketchup.active_model
    skalpList = ["- #{translate('no pattern selected')} -"]
    suList =[]

    Sketchup.active_model.materials.each { |material|
      next if material.name.gsub(' ', '') == ''
      if material.get_attribute('Skalp', 'ID')
        name = material.name.gsub(/%\d+\Z/, '')
        skalpList << name unless skalpList.include?(name)
      else
        suList << material.name
      end
    }

    skalpList.uniq.compact!
    skalpList.sort!
    suList.uniq.compact!
    suList.sort!

    temp = skalpList + ['----------'] + suList
    temp.join(';')
  end

  def self.check_sectiongroups
    pages = Sketchup.active_model.pages
    @active_model.section_result_group.entities.grep(Sketchup::Group).each do |section_group|
      if section_group.get_attribute('Skalp', 'ID')
        if section_group.get_attribute('Skalp', 'ID') == 'skalp_live_sectiongroup' && @active_model.live_sectiongroup.valid? && sectionplane_active == true &&  @active_model.live_sectiongroup
          pp "*** LIVE"
          pp "in model: #{!section_group.hidden?}"
        else
          pp "*** #{section_group.name}"
          pp "in model: #{!section_group.hidden?}"
        end
      end
      pages.each do |page|
        pp "#{page.name}: #{page.get_drawingelement_visibility(section_group)}"
      end
    end

    nil
  end

  def self.metadata
    @string = ""

    add_string("*** SKALP METADATA ***")
    add_string("")

    #memory
    if Skalp.active_model
      add_string("****************")
      add_string("MEMORY ATTRIBUTES")
      add_string("****************")
      add_string("")
      add_string("MODEL")
      page_attributes = Skalp.active_model.memory_attributes[Sketchup.active_model]

      page_attributes.each_pair do |key, value|
        if value.class == StyleRules
          add_string("#{key}: #{value.rules}")
        else
          add_string("#{key}: #{value}")
        end
      end
      add_string("-----")

      add_string("PAGES")
      Sketchup.active_model.pages.each do |page|
        page_attributes = Skalp.active_model.memory_attributes[page]
        add_string(page.name)
        page_attributes.each_pair do |key, value|
          if value.class == StyleRules
            add_string("#{key}: #{value.rules}")
          else
            add_string("#{key}: #{value}")
          end
        end
      end

      add_string("-----")
    end

    #model
    add_string("")
    add_string("****************")
    add_string("STORED MEMORY ATTRIBUTES IN MODEL")
    add_string("****************")
    add_string("")

    data = Sketchup.active_model.attribute_dictionaries['Skalp_memory_attributes']

    if data
      data.each { |key, value| add_string("#{key}: #{value}") }
    end

    #model
    add_string("")
    add_string("****************")
    add_string("MODEL ATTRIBUTES")
    add_string("****************")
    add_string("")

    if Sketchup.active_model.attribute_dictionaries
      data = Sketchup.active_model.attribute_dictionaries['Skalp']
      add_string("MODEL")
      if data

        data.each { |key, value| add_string("#{key}: #{value}") }

      else
        add_string('No data')
      end
      add_string("-----")
    end

    #sectionplanes
    sectionplanes = Sketchup.active_model.entities.grep(Sketchup::SectionPlane)
    add_string("SECTIONPLANES")
    sectionplanes.each { |sectionplane|
      if sectionplane.attribute_dictionaries
        data = sectionplane.attribute_dictionaries['Skalp']
        if data
          data.each { |key, value| add_string("#{key}: #{value}") } if data
          add_string('')
        end
      end
    }
    add_string("-----")

    #pages
    pages = Sketchup.active_model.pages

    add_string("PAGES")
    pages.each { |page|
      dict = page.attribute_dictionaries
      if dict
        data = dict['Skalp']
        if data
          add_string(page.name)
          data.each { |key, value| add_string("#{key}: #{value}") }
          add_string('')
        end
      end

    }
    add_string("-----")

    #layer
    layers = Sketchup.active_model.layers
    add_string("LAYERS")
    layers.each { |layer|
      dict = layer.attribute_dictionaries
      if dict
        data = dict['Skalp']
        if data
          add_string(layer.name)
          data.each { |key, value| add_string("#{key}: #{value}") }
          add_string('')
        end
      end

    }
    add_string("-----")

    #groups
    groups = Sketchup.active_model.entities.grep(Sketchup::Group)
    add_string("GROUPS")
    groups.each { |group|
      dict = group.attribute_dictionaries
      if dict
        data = dict['Skalp']
        if data
          data.each { |key, value|
            if key != 'sectionmaterial'
              add_string(group.name)
              add_string("#{key}: #{value}")
              add_string('')
            end
          }
        end
      end

    }
    add_string("-----")

    #materials
    materials = Sketchup.active_model.materials
    add_string("MATERIALS")
    materials.each { |material|
      dict = material.attribute_dictionaries
      if dict
        data = dict['Skalp']
        if data
          add_string(material.name)
          data.each { |key, value| add_string("#{key}: #{value}") }
          add_string('')
        end
      end
    }
    add_string("-----")

    unless OS == :MAC
      @string.gsub!("%0d%0a","\n") # only emails on windows need weird line endings guys
    end
    UI.messagebox(@string, MB_MULTILINE, "SKALP METADATA")
  end

  def self.hiddenline_style_dialog
    hiddenline_style = Sketchup.read_default('Skalp', 'hiddenline_style') || 'Skalp'

    result = UI.inputbox(['Mode:', 'Ask again?'], ["#{hiddenline_style}", 'yes'], ['Skalp|SketchUp', 'yes|no'], 'Hidden Line Style')
    return unless result

    if result[1] == 'yes'
      Sketchup.write_default('Skalp', 'hiddenline_style_dialog', true)
    else
      Sketchup.write_default('Skalp', 'hiddenline_style_dialog', false)
    end

    hiddenline_style = result[0]
    Sketchup.write_default('Skalp', 'hiddenline_style', hiddenline_style)

    if hiddenline_style == 'SketchUp' && Sketchup.active_model.rendering_options["RenderMode"] == 1
      Sketchup.active_model.rendering_options["DisplayColorByLayer"] = false
    end

    return result
  end

  attr_reader :layers_hash

  def self.define_layers_dialog
    unless @layers_dialog
      Sketchup.read_default('Skalp', 'Layers dialog - width') ? width = Sketchup.read_default('Skalp', 'Layers dialog - width') : width = 316
      Sketchup.read_default('Skalp', 'Layers dialog - height') ? height = Sketchup.read_default('Skalp', 'Layers dialog - height') : height = 635
      Sketchup.read_default('Skalp', 'Layers dialog - x') ? x = Sketchup.read_default('Skalp', 'Layers dialog - x') : x = 100
      Sketchup.read_default('Skalp', 'Layers dialog - y') ? y = Sketchup.read_default('Skalp', 'Layers dialog - y') : y = 100

      if OS == :WINDOWS
        @layers_dialog = UI::WebDialog.new("Define Pattern by Tag", false, 'Skalp Layers', width, height, 0, 0, true)
      else
        @layers_dialog = UI::WebDialog.new("Define Pattern by Tag", false, 'Skalp Layers', width, height, 0, 0, false)
      end

      html_file = Sketchup.find_support_file("Plugins") + "/Skalp_Skalp2026/html/layers_dialog.html"
      @layers_dialog.set_file(html_file)

      @layers_dialog.min_height=300
      OS == :MAC ? @layers_dialog.min_width = 255 : @layers_dialog.min_width = 270
      @layers_dialog.set_size(width, height)
      @layers_dialog.set_position(x, y)

      @layers_dialog.add_action_callback("materialSelector"){|webdialog, params|
        vars = params.split(';')
        x = vars[0]
        y = vars[1]
        id = vars[2..-1].join(';') # Could be multiple IDs separated by ;

        Skalp::Material_dialog.show_dialog(x, y, webdialog, id)
      }

      @layers_dialog.add_action_callback("dialog_position") { |webdialog, params|
        vars = params.split(';')
        x = vars[0].to_i
        y = vars[1].to_i
        Skalp::OS == :MAC ? width = vars[0].to_i : width = vars[2].to_i + 16
        Skalp::OS == :MAC ? height = vars[0].to_i : height = vars[3].to_i + 35

        Sketchup.write_default('Skalp', 'Layers dialog - width', width)
        Sketchup.write_default('Skalp', 'Layers dialog - height', height)
        Sketchup.write_default('Skalp', 'Layers dialog - x', x)
        Sketchup.write_default('Skalp', 'Layers dialog - y', y)
      }


      @layers_dialog.add_action_callback("loaded") { |webdialog, params|
         self.update_layers_dialog
       }

      @layers_dialog.add_action_callback("dialog_focus") { |webdialog, params|
        self.update_layers_dialog
      }

      @layers_dialog.add_action_callback("editPattern"){|webdialog, params|
        self.edit_material_pattern(params)
      }
    else
      update_layers_dialog
    end

    OS == :MAC ? @layers_dialog.show_modal() : @layers_dialog.show()
    @layers_dialog.bring_to_front
  end

  def self.define_layer_material(layer, material)
    unless material == "- #{translate('no pattern selected')} -" || !layer

      Skalp.active_model.start("Skalp - #{translate('associate section-material with layer')}", true)
      layer.set_attribute('Skalp', 'material', material)
      Skalp.add_skalp_material_to_instance([material])

      Skalp.active_model.commit
      data = {
          :action => :update_style
      }

      Skalp.active_model.controlCenter.add_to_queue(data)
    else
      Skalp.active_model.start("Skalp - #{translate('dissociate section-material from layer')}", true)
      layer.delete_attribute('Skalp', 'material')  if layer
      Skalp.active_model.commit
    end
  end

  def self.define_batch_layer_materials(ids, material)
    # ids is a semicolon separated string of IDs
    id_list = ids.split(';')
    
    Skalp.active_model.start("Skalp - #{translate('batch associate section-material')}", true)
    
    id_list.each do |id|
      layer = Skalp.layers_hash[id]
      next unless layer
      
      if material == "- #{translate('no pattern selected')} -" || material == ""
        layer.delete_attribute('Skalp', 'material')
      else
        layer.set_attribute('Skalp', 'material', material)
      end
    end
    
    # Ensure the material is in the model if it's a Skalp material
    unless material == "- #{translate('no pattern selected')} -" || material == ""
       Skalp.add_skalp_material_to_instance([material])
    end

    Skalp.active_model.commit
    
    data = {
        :action => :update_style
    }
    Skalp.active_model.controlCenter.add_to_queue(data)
  end

  def self.update_layers_dialog
    return unless Sketchup.active_model
    return unless @layers_dialog
    
    # Ensure required libraries
    require 'base64'
    require 'json'

    @layers_hash = {}
    
    # Send Materials List (for dropdown/autocompletion if needed, though we primarily use selector now)
    # Keeping this if JS strictly needs it, but we can send it as a simple list mostly.
    materials = get_patterns_to_string.split(';')
    materials_json = materials.to_json
    @layers_dialog.execute_script("layernames = []; materialnames = [];") # Clear old globals if any
    # Pass materials list to JS possibly? JS function add_materialname populates a list.
    # Let's populate the JS array efficiently.
    @layers_dialog.execute_script("materialnames = #{materials_json};")

    # Build Tree Data
    root_items = []
    
    # Check for LayerFolder support (SU 2021+)
    if Sketchup.active_model.layers.respond_to?(:folders)
       # Root folders
       folders = Sketchup.active_model.layers.folders.to_a
       root_items.concat(folders)
        # Root layers (layers not in any folder)
        layers = Sketchup.active_model.layers.to_a.select { |l| !l.respond_to?(:folder) || l.folder.nil? }
        root_items.concat(layers)
       puts "Skalp Debug: root_folders=#{folders.size}, root_layers=#{layers.size}" if defined?(DEBUG) && DEBUG
    else
       # Fallback for old SU: flat list
       root_items.concat(Sketchup.active_model.layers.to_a)
       puts "Skalp Debug: Fallback flat list, layers=#{root_items.size}" if defined?(DEBUG) && DEBUG
    end

    tree_data = build_layer_tree(root_items)
    puts "Skalp Debug: tree_data size=#{tree_data.size}" if defined?(DEBUG) && DEBUG
    
    require 'json'
    json_payload = JSON.generate(tree_data)
    puts "Skalp Debug: JSON payload length=#{json_payload.length}" if defined?(DEBUG) && DEBUG
    
    # Use direct object passing to avoid large string escaping issues in execute_script
    @layers_dialog.execute_script("update_layers(#{json_payload});")
  end

  def self.build_layer_tree(items)
    tree = []
    return tree if items.nil?

    # Mix folders and layers, sort alphabetical
    sorted_items = items.sort_by { |i| i.name.downcase }

    sorted_items.each do |item|
       if item.is_a?(Sketchup::Layer)
         next if is_skalp_internal_layer?(item)
         
         lid = "layer_#{item.entityID}"
         @layers_hash[lid] = item
         mat_name = item.get_attribute('Skalp', 'material') || ''
         
         thumb = nil
         thickness = 1 # default to 1 point
         if !mat_name.empty?
            # Get thumbnail and thickness
            mat = Sketchup.active_model.materials[mat_name]
            if mat && mat.get_attribute('Skalp', 'ID')
               pattern_info = nil
               pattern_info_str = mat.get_attribute('Skalp', 'pattern_info')
               if pattern_info_str
                  begin
                    parts = pattern_info_str.split(';')
                    pattern_info = eval(parts.last)
                  rescue
                  end
               end
               
               if pattern_info.is_a?(Hash)
                  # section_cut_width is in inches. Convert to categorized pixel values.
                  # Thresholds in inches: 0.25mm=0.00984, 0.5mm=0.01969, 1.0mm=0.03937
                  scw = pattern_info[:section_cut_width]
                  if scw.nil? || scw.to_f < 0.0001 # nil or effectively zero = no border
                     thickness = 0
                  elsif scw.to_f <= 0.00984 # <= 0.25mm: thin
                     thickness = 1
                  elsif scw.to_f <= 0.01969 # <= 0.5mm: medium
                     thickness = 2
                  elsif scw.to_f <= 0.03937 # <= 1.0mm: thick
                     thickness = 3
                  else # > 1.0mm: super thick
                     thickness = 4
                  end
                  
                  thumb = pattern_info[:png_blob]
                  unless thumb
                    begin
                       thumb = Skalp.create_thumbnail(pattern_info)
                       if thumb
                          pattern_info[:png_blob] = thumb
                          mat.set_attribute('Skalp', 'pattern_info', "eval(Sketchup.active_model.get_attribute('Skalp', 'version_check').to_s);#{pattern_info.inspect}")
                       else
                          puts "Skalp Debug: Failed to create thumbnail for #{mat_name}" if defined?(DEBUG) && DEBUG
                       end
                    rescue => e
                       puts "Skalp Debug: Error creating thumbnail: #{e.message}" if defined?(DEBUG) && DEBUG
                    end
                  end
                  
                  if thumb
                     require 'base64'
                     # Thumbnail from Skalp is already base64 encoded (starts with iVBOR)
                     # If it doesn't start with iVBOR, it might be raw binary PNG data.
                     unless thumb.start_with?('iVBOR')
                        thumb = Base64.strict_encode64(thumb)
                     end
                  else
                     puts "Skalp Debug: No thumbnail found/created for #{mat_name}" if defined?(DEBUG) && DEBUG
                  end
                end
             end
          end

         tree << {
            type: 'layer',
            name: item.name,
            id: lid,
            material: mat_name,
            thumb: thumb,
            thickness: thickness
         }
       elsif defined?(Sketchup::LayerFolder) && item.is_a?(Sketchup::LayerFolder)
          # Skip Skalp internal folder
          next if item.name == 'Skalp' || item.name.start_with?('Skalp ')
          
          # Folder
          children = build_layer_tree(item.layers.to_a + item.folders.to_a)
          tree << {
             type: 'folder',
             name: item.name,
             id: "folder_#{item.entityID}", 
             children: children
          }
       end
    end
    tree
  end

  def self.is_skalp_internal_layer?(layer)
     layer.get_attribute('Skalp', 'ID') || 
     layer.name.include?('Skalp Pattern Layer -') || 
     layer.name.include?('*** SKALP TAGS ***')
  end

  def self.get_material_thumbnail_base64(mat_name)
     # Potentially redundant now that it's in build_layer_tree, but keeping for compatibility if needed elsewhere
     mat = Sketchup.active_model.materials[mat_name]
     return nil unless mat
     return nil unless mat.get_attribute('Skalp', 'ID')
     
     pattern_info_str = mat.get_attribute('Skalp', 'pattern_info')
     return nil unless pattern_info_str
     
     pattern_info = nil
     begin
        parts = pattern_info_str.split(';')
        pattern_info = eval(parts.last)
     rescue
     end
     
     return nil unless pattern_info.is_a?(Hash)
     
     blob = pattern_info[:png_blob]
     unless blob
        blob = Skalp.create_thumbnail(pattern_info) rescue nil
     end
     
     if blob
        require 'base64'
        unless blob.start_with?('iVBOR')
           blob = Base64.strict_encode64(blob)
        end
        return blob
     end
     nil
  end

  def self.rebuild
    Sketchup.status_text = "Rebuilding started."
    Skalp.active_model.tree = Tree.new(Skalp.active_model.skpModel)
    Skalp.active_model.active_sectionplane.calculate_section if Skalp.active_model.active_sectionplane
    Sketchup.status_text = "Rebuilding finished."
  end

  def self.rebuild_entity(entity)
    Sketchup.status_text = "Rebuilding started."
    Skalp.active_model.tree.rebuild_entity(entity)
    Skalp.active_model.active_sectionplane.calculate_section if Skalp.active_model.active_sectionplane
    Sketchup.status_text = "Rebuilding finished."
  end

  def self.rebuild_selection
    Sketchup.status_text = "Rebuilding started."
    Sketchup.active_model.selection.each do |entity|
      Skalp.active_model.tree.rebuild_entity(entity)
    end
    Skalp.active_model.active_sectionplane.calculate_section if Skalp.active_model.active_sectionplane
    Sketchup.status_text = "Rebuilding finished."
  end

  #################
  # MENU
  #################

  if not file_loaded?('skalp_UI.rb')
    menu = UI.menu("Plugins")
    skalp_menu = menu.add_submenu("Skalp")

    skalp_menu.add_item(translate('Info Dialog')) {
      startup_check(:info)
    }

    skalp_menu.add_separator

    help_menu = skalp_menu.add_submenu(translate('Help'))

    help_menu.add_item(translate('Getting Started Manual')) {
      UI.openURL("http://download.skalp4sketchup.com/downloads/docs/manual.php")
    }

    help_menu.add_item(translate('Video Tutorials')) {
      UI.openURL('http://www.youtube.com/playlist?list=PL4o5Ke8mDBjjka1kZPJ5-tMhf_d51CVbr')
    }

    help_menu.add_item(translate('Visit website')) {
      UI.openURL('http://www.skalp4sketchup.com')
    }

    help_menu.add_item(translate('Contact support')) {
      mail_support
    }

    tool_menu = skalp_menu.add_submenu(translate('Tools'))

    tool_menu.add_item(translate('Deactivate on this computer')) {
      deactivate
    }
    tool_menu.add_item("#{translate('Uninstall')} Skalp") {
      uninstall
    }

    tool_menu.add_separator
    tool_menu.add_item(translate('Cleanup Duplicate Materials')) {
      Skalp.cleanup_duplicate_materials
    }
    tool_menu.add_item(translate('Force Purge Skalp Materials')) {
      result = UI.messagebox("This will remove all Skalp materials from the hidden purge-prevention component that are not currently assigned to any layer or object. These materials can then be purged from the model using SketchUp's standard purge. Proceed?", MB_YESNO)
      Skalp.force_purge_skalp_materials if result == IDYES
    }

    tool_menu = skalp_menu.add_submenu(translate('Skalp commands'))

    # Toggle on/off active section
    active_section_cmd = UI::Command.new('active_section_cmd') {
      return unless Skalp::dialog
      Skalp::dialog.sectionplane_toggle_command
    }

    active_section_cmd.menu_text = 'Toggle on/off active section'
    active_section_cmd.set_validation_proc {
      if @status == 1
        MF_ENABLED
      else
        MF_GRAYED
      end
    }

    tool_menu.add_item(active_section_cmd)

    # Align view with active section
    align_view_cmd = UI::Command.new('align_view_cmd') {
      return unless Skalp::dialog
      Skalp::dialog.align_view_command
    }

    align_view_cmd.menu_text = 'Align view with active section'
    align_view_cmd.set_validation_proc {
      if @status == 1
        MF_ENABLED
      else
        MF_GRAYED
      end
    }

    tool_menu.add_item(align_view_cmd)

    # Toggle on/off Depth clipping
    depth_clipping_cmd = UI::Command.new('depth_clipping_cmd') {
      return unless Skalp::dialog
      status =  !Skalp::dialog.fog_status
      Skalp::dialog.toggle_depth_clipping_command(status)
      Skalp::dialog.set_fog_switch(status)
      status ? Skalp::dialog.fog_status_switch_on : Skalp::dialog.fog_status_switch_off
    }

    depth_clipping_cmd.menu_text = 'Toggle on/off Depth clipping'
    depth_clipping_cmd.set_validation_proc {
      if @status == 1
        MF_ENABLED
      else
        MF_GRAYED
      end
    }

    tool_menu.add_item(depth_clipping_cmd)

    # Toggle on/off Skalp Hiddenline mode
    hiddenline_mode_cmd = UI::Command.new('hiddenline_mode_cmd') {
      return unless Skalp::dialog
      Skalp.active_model.rendering_options.hiddenline_style_active? ? status = 'inactive' : status = 'active'
      Skalp::dialog.toggle_hiddenline_mode_command(status)
    }

    hiddenline_mode_cmd.menu_text = 'Toggle on/off Hiddenline mode'
    hiddenline_mode_cmd.set_validation_proc {
      if @status == 1
        MF_ENABLED
      else
        MF_GRAYED
      end
    }

    tool_menu.add_item(hiddenline_mode_cmd)

    # Toggle on/off Section Cut widths
    lineweights_cmd = UI::Command.new('lineweights_cmd') {
      return unless Skalp::dialog
      status = !Skalp::dialog.lineweights_status
      Skalp::dialog.toggle_lineweights_command(status)
      Skalp::dialog.set_lineweights_switch(status)
      status ? Skalp::dialog.lineweights_status_switch_on : Skalp::dialog.lineweights_status_switch_off
    }

    lineweights_cmd.menu_text = 'Toggle on/off Section Cut widths'
    lineweights_cmd.set_validation_proc {
      if @status == 1
        MF_ENABLED
      else
        MF_GRAYED
      end
    }

    tool_menu.add_item(lineweights_cmd)

    # Toggle on/off Rear View Projection
    rear_view_projection_cmd = UI::Command.new('rear_view_projection_cmd') {
      return unless Skalp::dialog
      status = !Skalp::dialog.rear_view_status
      Skalp::dialog.toggle_rear_view_command(status)
      Skalp::dialog.set_rearview_switch(status)
      status ? Skalp::dialog.rearview_status_switch_on : Skalp::dialog.rearview_status_switch_off
    }

    rear_view_projection_cmd.menu_text = 'Toggle on/off Rear View Projection'
    rear_view_projection_cmd.set_validation_proc {
      if @status == 1
        MF_ENABLED
      else
        MF_GRAYED
      end
    }

    tool_menu.add_item(rear_view_projection_cmd)

    #  Update Rear View Projection
    update_rear_view_projection_cmd = UI::Command.new('update_rear_view_projection_cmd') {
      return unless Skalp::dialog
      Skalp::dialog.section_update_command(true)
    }

    update_rear_view_projection_cmd.menu_text = 'Update Rear View Projection'
    update_rear_view_projection_cmd.set_validation_proc {
      if @status == 1
        MF_ENABLED
      else
        MF_GRAYED
      end
    }

    tool_menu.add_item(update_rear_view_projection_cmd)

  end

  #################
  # TOOLBAR
  #################
  def self.skalpTool
    if @info_dialog_active
      UI.messagebox(translate('Please close the Skalp Info Dialog to start using Skalp'), MB_OK)
      return
    end
    return if @dialog_loading == true
    @dialog_loading = true
    UI.stop_timer(@load_timer) if @load_timer != nil
    @load_timer = UI.start_timer(5, false) { @dialog_loading = false }

    if @status == nil || @status == 0
      skalpbutton_on
      self.start_skalp
    elsif @status == 1
      if @dialog.visible?
        @dialog.close
      else
        skalpbutton_on
        @dialog_loading = false
      end
    end
  end

  def self.edit_material_pattern(material_name)
    if @info_dialog_active
      UI.messagebox(Skalp.translate('Please close the Skalp Info Dialog to start using Skalp'), MB_OK)
      return
    end

    skalpTool if @status == 0

    Skalp.check_skalp_default_material

    if @hatch_dialog
      @hatch_dialog.hatchname = material_name
      @hatch_dialog.show
      @hatch_dialog.select_last_pattern
    else
      @hatch_dialog = Skalp::Hatch_dialog.new(material_name)
      @hatch_dialog.show
    end
    patterndesignerbutton_on
  end

  def self.patternDesignerTool
    if @info_dialog_active
      UI.messagebox(translate('Please close the Skalp Info Dialog to start using Skalp'), MB_OK)
      return
    end

    skalpTool if @status == 0

    Skalp.check_skalp_default_material

    if @hatch_dialog #.class == Skalp::Hatch_dialog
      if @hatch_dialog.visible?
        patterndesignerbutton_off
        @hatch_dialog.webdialog.close
      else
        patterndesignerbutton_on
        @hatch_dialog.show
        @hatch_dialog.select_last_pattern
        #@hatch_dialog.clear_dialog(false)
      end
    else
      @hatch_dialog = Hatch_dialog.new
      @hatch_dialog.show if OS == :WINDOWS
      patterndesignerbutton_on
    end
  end

  @skalp_toolbar = UI::Toolbar.new "Skalp"

  @skalp_activate = UI::Command.new("Skalp") {
    startup_check(:skalpTool)
  }


  if OS == :MAC
    small_icon = "skalp_icon_small.pdf"
    large_icon = "skalp_icon.pdf"
  else
    small_icon = "skalp_icon_small_win.svg"
    large_icon = "skalp_icon.svg"
  end

  @skalp_activate.small_icon = IMAGE_PATH + small_icon
  @skalp_activate.large_icon = IMAGE_PATH + large_icon

  @skalp_activate.tooltip = "Skalp"
  @skalp_activate.status_bar_text = "Skalp"
  @skalp_activate.menu_text = "Skalp"
  @skalp_toolbar = @skalp_toolbar.add_item @skalp_activate

  def self.skalpbutton_off
    @skalp_activate.set_validation_proc { MF_UNCHECKED }
    @skalp_toolbar.hide
    @skalp_toolbar.show
  end

  def self.skalpbutton_on
    @skalp_activate.set_validation_proc { MF_CHECKED }
    @skalp_toolbar.hide
    @skalp_toolbar.show
  end

  @skalp_pattern_designer = UI::Command.new("Skalp #{translate('Pattern Designer')}") {
    startup_check(:patternDesignerTool)
  }

  if OS == :MAC
    small_icon = "skalp_hatch_small.pdf"
    large_icon = "skalp_hatch.pdf"
  else
    small_icon = "skalp_hatch_small_win.svg"
    large_icon = "skalp_hatch.svg"
  end

  @skalp_pattern_designer.small_icon = IMAGE_PATH + small_icon
  @skalp_pattern_designer.large_icon = IMAGE_PATH + large_icon

  @skalp_pattern_designer.tooltip = "Skalp #{translate('Pattern Designer')}"
  @skalp_pattern_designer.status_bar_text = "Skalp #{translate('Pattern Designer')}"
  @skalp_pattern_designer.menu_text = "Skalp #{translate('Pattern Designer')}"

  @skalp_toolbar = @skalp_toolbar.add_item @skalp_pattern_designer

  def self.patterndesignerbutton_off
    @skalp_pattern_designer.set_validation_proc { MF_UNCHECKED }
    @skalp_toolbar.hide
    @skalp_toolbar.show
  end

  def self.patterndesignerbutton_on
    @skalp_pattern_designer.set_validation_proc { MF_CHECKED }
    @skalp_toolbar.hide
    @skalp_toolbar.show
  end

  @skalp_paint_tool = UI::Command.new("Skalp #{translate('Skalp Paint Bucket')}") {
    if @status == 1
      Sketchup.active_model.select_tool(@skalp_paint) unless Skalp::Material_dialog::materialdialog
      paintbucketbutton_on
    else
      UI.messagebox('Please open Skalp before using the Skalp Paint Tool.')
    end
  }

  if OS == :MAC
    small_icon = "paint_icon.pdf"
    large_icon = "paint_icon.pdf"
  else
    small_icon = "paint_icon.svg"
    large_icon = "paint_icon.svg"
  end

  @skalp_paint_tool.small_icon = IMAGE_PATH + small_icon
  @skalp_paint_tool.large_icon = IMAGE_PATH + large_icon

  @skalp_paint_tool.tooltip = "Skalp #{translate('Skalp Section Paint Bucket')}"
  @skalp_paint_tool.status_bar_text = "Skalp #{translate('Skalp Section Paint Bucket')}"
  @skalp_paint_tool.menu_text = "Skalp #{translate('Skalp Section Paint Bucket')}"
  @skalp_paint_tool.set_validation_proc { MF_UNCHECKED }

  @skalp_toolbar = @skalp_toolbar.add_item @skalp_paint_tool

  def self.paintbucketbutton_off
    @skalp_paint_tool.set_validation_proc { MF_UNCHECKED }
    @skalp_toolbar.hide
    @skalp_toolbar.show
  end

  def self.paintbucketbutton_on
    @skalp_paint_tool.set_validation_proc { MF_CHECKED }
    @skalp_toolbar.hide
    @skalp_toolbar.show
  end

  @skalp_layout_export = UI::Command.new("Skalp #{translate('LO Export')}") {
    Sketchup.active_model.select_tool(nil)
    if @status == 1
      if Sketchup.active_model && Skalp.active_model && Sketchup.active_model.pages.count > 0
        exportLObutton_on
        Skalp.active_model.update_all_pages(true, true)
      else
        UI.messagebox('No scenes to export!')
        exportLObutton_off
      end
    else
      UI.messagebox('Please open Skalp before using LayOut export.')
      exportLObutton_off
    end
  }

  if OS == :MAC
    small_icon = "lo_export_icon.pdf"
    large_icon = "lo_export_icon.pdf"
  else
    small_icon = "lo_export_icon.svg"
    large_icon = "lo_export_icon.svg"
  end

  @skalp_layout_export.small_icon = IMAGE_PATH + small_icon
  @skalp_layout_export.large_icon = IMAGE_PATH + large_icon

  @skalp_layout_export.tooltip = "Skalp #{translate('LayOut Export')}"
  @skalp_layout_export.status_bar_text = "Skalp #{translate('LayOut Export')}"
  @skalp_layout_export.menu_text = "Skalp #{translate('LayOut Export')}"
  @skalp_layout_export.set_validation_proc { MF_UNCHECKED }

  @skalp_toolbar = @skalp_toolbar.add_item @skalp_layout_export

  def self.exportLObutton_off
    @skalp_layout_export.set_validation_proc { MF_UNCHECKED }
    @skalp_toolbar.hide
    @skalp_toolbar.show
  end

  def self.exportLObutton_on
    @skalp_layout_export.set_validation_proc { MF_CHECKED }
    @skalp_toolbar.hide
    @skalp_toolbar.show
  end

  @skalp_dwg_export = UI::Command.new("Skalp #{translate('DWG Export')}") {
    Sketchup.active_model.select_tool(nil)
    if @status == 1
      exportDWGbutton_on
      Skalp.dwg_export
    else
      UI.messagebox('Please open Skalp before using DWG export.')
      exportDWGbutton_off
    end
  }

  if OS == :MAC
    small_icon = "dwg_export_icon.pdf"
    large_icon = "dwg_export_icon.pdf"
  else
    small_icon = "dwg_export_icon.svg"
    large_icon = "dwg_export_icon.svg"
  end

  @skalp_dwg_export.small_icon = IMAGE_PATH + small_icon
  @skalp_dwg_export.large_icon = IMAGE_PATH + large_icon

  @skalp_dwg_export.tooltip = "Skalp #{translate('DWG Export')}"
  @skalp_dwg_export.status_bar_text = "Skalp #{translate('DWG Export')}"
  @skalp_dwg_export.menu_text = "Skalp #{translate('DWG Export')}"
  @skalp_dwg_export.set_validation_proc { MF_UNCHECKED }

  @skalp_toolbar = @skalp_toolbar.add_item @skalp_dwg_export

  def self.exportDWGbutton_off
    @skalp_dwg_export.set_validation_proc { MF_UNCHECKED }
    @skalp_toolbar.hide
    @skalp_toolbar.show
  end

  def self.exportDWGbutton_on
    @skalp_dwg_export.set_validation_proc { MF_CHECKED }
    @skalp_toolbar.hide
    @skalp_toolbar.show
  end

  @skalp_rebuild = UI::Command.new("Rebuild") {
    rebuild_on
    Skalp.rebuild if @status == 1
    rebuild_off
  }

  if OS == :MAC
    small_icon = "rebuild_icon.pdf"
    large_icon = "rebuild_icon.pdf"
  else
    small_icon = "rebuild_icon.svg"
    large_icon = "rebuild_icon.svg"
  end

  @skalp_rebuild.small_icon = IMAGE_PATH + small_icon
  @skalp_rebuild.large_icon = IMAGE_PATH + large_icon

  @skalp_rebuild.tooltip = "Rebuild Skalp Section"
  @skalp_rebuild.status_bar_text = "Rebuild Skalp Section"
  @skalp_rebuild.menu_text = "Rebuild Skalp Section"
  @skalp_rebuild.set_validation_proc { MF_UNCHECKED }

  @skalp_toolbar = @skalp_toolbar.add_item @skalp_rebuild

  def self.rebuild_off
    @skalp_rebuild.set_validation_proc { MF_UNCHECKED }
    @skalp_toolbar.hide
    @skalp_toolbar.show
  end

  def self.rebuild_on
    @skalp_rebuild.set_validation_proc { MF_CHECKED }
    @skalp_toolbar.hide
    @skalp_toolbar.show
  end
  @skalp_toolbar.show unless @skalp_toolbar.get_last_state == 0

  #################
  # CONTEXT MENU
  #################

  UI.add_context_menu_handler do |context_menu|
    if @models && @models[Sketchup.active_model]
      selected = Sketchup.active_model.selection[0]
      if selected.is_a?(Sketchup::SectionPlane)
        skpSectionplane = selected
        sectionplaneID = skpSectionplane.get_attribute('Skalp', "ID")
        context_menu.add_separator
        if @status == 1 && !sectionplaneID
          context_menu.add_item(translate("Create Skalp from Section Plane")) {

            Sketchup.active_model.selection.remove(skpSectionplane)

            data = {
                :action => :add_element,
                :entities => Sketchup.active_model.entities,
                :entity => skpSectionplane
            }
            @models[Sketchup.active_model].controlCenter.add_to_queue(data)
          }
        end
        context_menu.add_separator
      end
    end
  end

  def section_status
    model = Sketchup.active_model
    pages = model.pages

    pages.each do |page|
      pp '---'
      pp page.name

      Skalp.active_model.section_result_group.entities.grep(Sketchup::Group).each do |section_group|
        pp "#{section_group.name}: #{page.get_drawingelement_visibility(section_group)}"
      end
    end
  end

  def self.get_multitag_material
    model = Sketchup.active_model
    selection = model.selection

    id = selection.first.entityID.to_i
    node_info = Skalp.active_model.tree.find_nodes_by_id(id).compact.uniq.first.value
    multi_tags = node_info.multi_tags
    sectionmaterial = node_info.multi_tags_hatch

  end


  file_loaded('skalp_UI.rb')
end
