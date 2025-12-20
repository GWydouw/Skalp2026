module Skalp
  class Model
    attr_accessor :skpModel, :tree, :sectionplanes, :pages, :layers, :live_sectiongroup, :sectiongroup, :context_sectiongroup, :hiddenlines,
                  :model_observer, :entities_observer, :pages_observer, :layers_observer, :selection_observer, :view_observer, :tools_observer, :materials_observer, :material_observer_active, :rendering_options_observer,
                  :active_context, :controlCenter, :observer_active, :operation, :pagesUndoRedo, :page_undo, :page_to_delete, :on_setup,
                  :skalp_version, :prefs,
                  :make_scene, :sectionplane_entityIDs, :skalp_pages_LUT,
                  :entity_strings, :hidden_entities, :undoredo_action, :memory_attributes,
                  :clear_timestamp, :action_finished, :load, :dialog_undo_flag, :delete_old_page_attributes,
                  :model_changes, :rendering_options, :save_settings, :observer_status,
                  :active_page,
                  :section_result_group,
                  :skalp_folder, :linestyle_folder, :patternlayer_folder, :rearview_folder,
                  :used_materials,
                  :active_node, :hide_rest_of_model, :incontext,
                  :multi_tags_sectionmaterial_table, :multi_tags_groups_for_section

    attr_reader :active_section

    def initialize(skpModel)
      load_multitags_materials
      @incontext = false
      @hide_rest_of_model = skpModel.rendering_options["InactiveHidden"]
      @used_materials = Set.new
      @undoredo_action = false
      @on_setup = true
      @skpModel = skpModel
      hidden_entities_for_model
      @page_undo = false
      @skalp_pages_LUT = {}
      @observer_active = false
      @material_observer_active = true
      @operation = 0
      Skalp.active_model = self
      @active_context = @skpModel
      @sectionplane_entityIDs = []
      @clear_timestamp = false
      @load = false
      @dialog_undo_flag = false
      @delete_old_page_attributes = false
      @rendering_options = Skalp::RenderingOptions.new(@skpModel)
      @save_settings = true
      @active_page = @skpModel.pages.selected_page

      #start_operation
      start("Skalp - #{Skalp.translate('start extension')}", true)

      load_layers
      @memory_attributes = Memory_attributes.new
      @memory_attributes.read_from_model

      version_recover
      Skalp.check_SU_material_library

      covert_skalp_layers #NEW 2020

      check_empty_materials
      Skalp.delete_old_scaled_skalp_materials
      Skalp.remove_PBR_properties #NEW 2025
      Skalp.set_thea_render_params
      Skalp.create_thumbnails_cache

      load_prefs

      @model_changes = true
      @tree = Tree.new(@skpModel)

      prepare_section_result_group
      load_sectionplanes
      check_pages
      load_pages

      @hiddenlines = Skalp::Hiddenlines.new(self)

      @live_sectiongroup = find_live_sectiongroup
      turnoff_live_section_in_pages

      @controlCenter = ControlCenter.new(self)
      @pagesUndoRedo = PagesUndoRedo.new(self)

      if get_memory_attribute(@skpModel, 'Skalp', 'active_sectionplane_ID') && get_memory_attribute(@skpModel, 'Skalp', 'active_sectionplane_ID').slice(0, 1) then
        Skalp.sectionplane_active = true
        if Skalp.status != 0
          sectionplane = sectionplane_by_id(get_memory_attribute(@skpModel, 'Skalp', 'active_sectionplane_ID'))
          sectionplane ? sectionplane.activate : Skalp.sectionplane_active = false
        end
      else
        Skalp.sectionplane_active = false
      end

      Skalp.check_skalp_default_material
      Skalp.check_color_by_layer_layers if Skalp.skalp_pattern_layers_used?
      setup_skalp_folders
      Skalp.fixTagFolderBug('Model initialize')
      Skalp.create_skalp_material_instance
      commit
    end

    def modified_multi_tags(objects)
      objects.each do |entity|
        data = {
          :action => :modified_element,
          :entities => @skpModel.entities,
          :entity => entity
        }
        controlCenter.add_to_queue(data)
      end
    end

    def load_multitags_materials
      json_file = SKALP_PATH + 'resources/multitags_materials.json'

      unless File.exist?(json_file)
        data = []
        section_material_table = {
          "afbraak|*|*" => "afbraak",
          "bestaand|*|*" => "bestaand",
          "nieuw|*|*" => "default",
          "afbraak|10 GRONDWERKEN|*"=> "afgraving grond",
          "nieuw|10 GRONDWERKEN|*"=> "aanvulling grond",
          "nieuw|12 FUNDERINGEN OP STAAL|*"=> "ongewapend beton",
          "bestaand|12 FUNDERINGEN OP STAAL|*"=> "ongewapend beton bestaand",
          "nieuw|12 FUNDERINGEN OP STAAL|gewapend beton"=> "gewapend beton",
          "nieuw|13 SPECIALE FUNDERINGEN|*"=> "gewapend beton",
          "nieuw|14 METSELWERKEN ONDERBOUW|*"=> "betonblokken",
          "bestaand|14 METSELWERKEN ONDERBOUW|*"=> "betonblokken bestaand",
          "nieuw|15 VLOERLAGEN ONDERBOUW|*"=> "gewapend beton",
          "nieuw|16 THERMISCHE ISOLATIE ONDERBOUW|*"=> "isolatie PUR",
          "nieuw|16 THERMISCHE ISOLATIE ONDERBOUW|PUR"=> "isolatie PUR",
          "nieuw|16 THERMISCHE ISOLATIE ONDERBOUW|XPS"=> "isolatie XPS",
          "nieuw|16 THERMISCHE ISOLATIE ONDERBOUW|EPS"=> "isolatie EPS",
          "nieuw|16 THERMISCHE ISOLATIE ONDERBOUW|rotswol"=> "isolatie rotswol",
          "nieuw|16 THERMISCHE ISOLATIE ONDERBOUW|glaswol"=> "isolatie glaswol",
          "nieuw|17 RIOLERING WC|*"=> "wit",
          "nieuw|20 OPGAAND METSELWERK|*"=> "wit",
          "nieuw|20 OPGAAND METSELWERK|snelbouw"=> "snelbouw",
          "bestaand|20 OPGAAND METSELWERK|snelbouw"=> "snelbouw bestaand",
          "nieuw|20 OPGAAND METSELWERK|cellenbeton"=> "cellenbeton",
          "bestaand|20 OPGAAND METSELWERK|cellenbeton"=> "cellenbeton bestaand",
          "nieuw|20 OPGAAND METSELWERK|betonblokken"=> "betonblokken",
          "nieuw|21 NIET DRAGEND METSELWERK|*"=> "snelbouw",
          "nieuw|21 NIET DRAGEND METSELWERK|snelbouw"=> "snelbouw",
          "bestaand|21 NIET DRAGEND METSELWERK|snelbouw"=> "snelbouw bestaand",
          "nieuw|21 NIET DRAGEND METSELWERK|cellenbeton"=> "cellenbeton",
          "bestaand|21 NIET DRAGEND METSELWERK|cellenbeton"=> "cellenbeton bestaand",
          "bestaand|22 MUURISOLATIE BOVENBOUW|*"=> "isolatie bestaand",
          "nieuw|22 MUURISOLATIE BOVENBOUW|*"=> "isolatie PUR",
          "nieuw|22 MUURISOLATIE BOVENBOUW|PUR"=> "isolatie PUR",
          "nieuw|22 MUURISOLATIE BOVENBOUW|rotswol"=> "isolatie rotswol",
          "nieuw|22 MUURISOLATIE BOVENBOUW|glaswol"=> "isolatie glaswol",
          "nieuw|22 MUURISOLATIE BOVENBOUW|EPS"=> "isolatie EPS",
          "nieuw|22 MUURISOLATIE BOVENBOUW|XPS"=> "isolatie XPS",
          "nieuw|22 AKOUSTISCHE ISOLATIE GEMENE MUUR|*"=> "wit",
          "bestaand|22 AKOUSTISCHE ISOLATIE GEMENE MUUR|*"=> "isolatie bestaand",
          "nieuw|23 GEVELMETSELWERK|*"=> "gevelsteen",
          "bestaand|23 GEVELMETSELWERK|*"=> "gevelsteen bestaand",
          "nieuw|24 INGEMETSTE GEVELELEMENTEN|*"=> "arduin",
          "nieuw|26 STRUCTUURELEMENTEN GEWAPEND BETON|*"=> "gewapend beton",
          "bestaand|26 STRUCTUURELEMENTEN GEWAPEND BETON|*"=> "gewapend beton bestaand",
          "nieuw|26 DOORHANGENDE BETONBALKEN|prefab beton"=> "prefab beton",
          "nieuw|26 DOORHANGENDE BETONBALKEN|gewapend beton"=> "gewapend beton",
          "bestaand|26 DOORHANGENDE BETONBALKEN|gewapend beton"=> "gewapend beton bestaand",
          "nieuw|26 OMGEKEERDE BETONBALKEN|gewapend beton"=> "gewapend beton",
          "bestaand|26 OMGEKEERDE BETONBALKEN|gewapend beton"=> "gewapend beton bestaand",
          "nieuw|26 BETONSLOFFEN|*"=> "gewapend beton",
          "nieuw|26 BETONSLOFFEN|prefab beton"=> "prefab beton",
          "nieuw|27 STRUCTUURELEMENTEN STAAL|*"=> "zwart",
          "nieuw|28 DRAAGVLOEREN GEWAPEND BETON|*"=> "gewapend beton",
          "bestaand|28 DRAAGVLOEREN GEWAPEND BETON|*"=> "gewapend beton bestaand",
          "nieuw|28 DRAAGVLOEREN GEWAPEND BETON|prefab beton"=> "prefab beton",
          "nieuw|28 DRAAGVLOEREN GEWAPEND BETON DRUKLAAG|*"=> "gewapend beton",
          "nieuw|29 STRUCTUURELEMENTEN HOUT|*"=> "hout",
          "bestaand|29 STRUCTUURELEMENTEN HOUT|*"=> "hout bestaand",
          "nieuw|30 HELLEND DAK - DAKOPBOUW|*"=> "hout",
          "bestaand|30 HELLEND DAK - DAKOPBOUW|*"=> "hout bestaand",
          "nieuw|31 HELLEND DAK - THERMISCHE ISOLATIE|*"=> "isolatie PUR",
          "nieuw|31 HELLEND DAK - THERMISCHE ISOLATIE|PUR"=> "isolatie PUR",
          "nieuw|31 HELLEND DAK - THERMISCHE ISOLATIE|XPS"=> "isolatie XPS",
          "nieuw|31 HELLEND DAK - THERMISCHE ISOLATIE|rotswol"=> "isolatie rotswol",
          "nieuw|31 HELLEND DAK - THERMISCHE ISOLATIE|glaswol"=> "isolatie glaswol",
          "nieuw|31 HELLEND DAK - THERMISCHE ISOLATIE|EPS"=> "isolatie EPS",
          "nieuw|32 HELLEND DAK - DAKDICHTING|*"=> "wit",
          "nieuw|33 PLAT DAK - DAKVLOER|*"=> "wit",
          "nieuw|34 PLAT DAK - THERMISCHE ISOLATIE|*"=> "isolatie PUR",
          "nieuw|34 PLAT DAK - THERMISCHE ISOLATIE|PUR"=> "isolatie PUR",
          "nieuw|34 PLAT DAK - THERMISCHE ISOLATIE|XPS"=> "isolatie XPS",
          "nieuw|34 PLAT DAK - THERMISCHE ISOLATIE|EPS"=> "isolatie EPS",
          "nieuw|34 PLAT DAK - THERMISCHE ISOLATIE|rotswol"=> "isolatie rotswol",
          "nieuw|34 PLAT DAK - THERMISCHE ISOLATIE|glaswol"=> "isolatie glaswol",
          "nieuw|35 PLAT DAK - DAKDICHTING|*"=> "wit",
          "nieuw|36 DAKLICHTOPENINGEN|*"=> "wit",
          "nieuw|37 DAKRANDEN|*"=> "wit",
          "nieuw|38 DAKGOTEN EN RW-AFOER|*"=> "wit",
          "nieuw|40 BUITENSCHRIJNWERK|*"=> "wit",
          "nieuw|44 GEVELBEKLEDINGEN|*"=> "wit",
          "nieuw|50 BINNENPLEISTERWERKEN|*"=> "wit",
          "bestaand|51 BINNENPLAATAFWERKINGEN|*"=> "lichtblauw",
          "nieuw|51 BINNENPLAATAFWERKINGEN|*"=> "wit",
          "nieuw|51 GYPROCWANDEN|*"=> "gyproc",
          "bestaand|51 GYPROCWANDEN|*"=> "gyproc bestaand",
          "nieuw|52 DEK- EN BEDRIJFSVLOEREN|chape"=> "chape",
          "bestaand|52 DEK- EN BEDRIJFSVLOEREN|chape"=> "chape bestaand",
          "nieuw|52 DEK- EN BEDRIJFSVLOEREN|PUR"=> "isolatie PUR",
          "bestaand|52 DEK- EN BEDRIJFSVLOEREN|PUR"=> "isolatie bestaand",
          "nieuw|52 DEK- EN BEDRIJFSVLOEREN|*"=> "wit",
          "nieuw|53 BINNENVLOERAFWERKINGEN|*"=> "wit",
          "nieuw|54 BINNENDEUREN|*"=> "wit",
          "nieuw|55 BINNENBEGLAZING|*"=> "wit",
          "nieuw|56 BINNENTRAPPEN|*"=> "wit",
          "nieuw|57 VAST MEUBILAIR|*"=> "hout",
          "nieuw|58 TABLET- EN WANDBEKLEDINGEN|*"=> "wit",
          "nieuw|60 SANITAIR - LEIDINGENNET|*"=> "wit",
          "nieuw|61 SANITAIR - TOESTELLEN|*"=> "wit",
          "nieuw|62 SANITAIR - KRANEN|*"=> "wit",
          "nieuw|63 SANITAIR - WARMWATERVOORZIENINGEN|*"=> "wit",
          "nieuw|64 GASINSTALLATIES|*"=> "wit",
          "nieuw|64 VERWARMING INSTALLATIES|*"=> "wit",
          "nieuw|68 VENTILATIE|*"=> "wit",
          "nieuw|70 ELEKTRICITEIT - BINNENNET|*"=> "wit",
          "nieuw|71 ELEKTRICITEIT - SCHAKELAARS|*"=> "wit",
          "nieuw|72 ELEKTRICITEIT - LICHTARMATUREN|*"=> "wit",
          "nieuw|80 LOS MEUBILAIR|*"=> "wit",
          "bestaand|90 OMGEVING|*"=> "grond"
        }

        data << ["status", "classificatie", "materiaal"]
        data << section_material_table

        File.write(json_file, JSON.generate(data))
      end

      @multi_tags_groups_for_section, section_material_table = JSON.parse(File.read(json_file))
      @multi_tags_sectionmaterial_table = Skalp.sort_section_table(section_material_table)

      table = {}
      @multi_tags_sectionmaterial_table.each do |rule, hatch|
        table[rule.split('|')] = hatch
      end

      @multi_tags_sectionmaterial_table = table
    end

    def setup_skalp_folders
      Sketchup.active_model.layers.folders.each do |folder|
        if folder.valid? && folder.get_attribute('Skalp', 'folder') == 'Skalp'
          @skalp_folder = folder
          @skalp_folder.name = "\uFEFF".encode('utf-8') + 'Skalp'
        end
      end

      unless @skalp_folder
        @skalp_folder = Sketchup.active_model.layers.add_folder("\uFEFF".encode('utf-8') + 'Skalp')
        @skalp_folder.set_attribute('Skalp', 'folder', 'Skalp')
      end

      @skalp_folder.folders.each do |folder|
        if folder.valid? && folder.get_attribute('Skalp', 'folder') == 'Linestyles'
          @linestyle_folder = folder
          @linestyle_folder.name = 'Linestyles'
        end
        if folder.valid? && folder.get_attribute('Skalp', 'folder') == 'Pattern Layers'
          @patternlayer_folder = folder
          @patternlayer_folder.name = 'Pattern Layers'
        end
        if folder.valid? && folder.get_attribute('Skalp', 'folder') == 'Rearview'
          @rearview_folder = folder
          @rearview_folder.name = 'Rearview'
          @rearview_folder.set_attribute('Skalp', 'ID', Skalp::generate_ID)
        end
      end

      unless @linestyle_folder
        @linestyle_folder = @skalp_folder.add_folder('Linestyles')
        @linestyle_folder.set_attribute('Skalp', 'folder', 'Linestyles')
      end

      unless @rearview_folder
        @rearview_folder = @skalp_folder.add_folder('Rearview')
        @rearview_folder.set_attribute('Skalp', 'folder', 'Rearview')
        @rearview_folder.set_attribute('Skalp', 'ID', Skalp::generate_ID)
      end

      unless @patternlayer_folder
        @patternlayer_folder = @skalp_folder.add_folder('Pattern Layers')
        @patternlayer_folder.set_attribute('Skalp', 'folder', 'Pattern Layers')
      end

      layers = Sketchup.active_model.layers
      layers.each do |layer|
        layer.folder = @skalp_folder if layer.name.include?('Skalp Scene Sections')
        layer.folder = @patternlayer_folder if layer.name.include?('Skalp Pattern Layer')
        layer.folder = @linestyle_folder if layer.name.include?('Skalp Linestyle')
      end

      @skalp_folder.visible = true
      @linestyle_folder.visible = true
      @patternlayer_folder.visible = true
      @rearview_folder.visible = true

      @linestyle_folder.each_layer {|layer| layer.visible = true}
      @patternlayer_folder.each_layer {|layer| layer.visible = true}
      @rearview_folder.each_layer {|layer| layer.visible = true}
    end

    def active_section
      if get_memory_attribute(@skpModel, 'Skalp', 'active_sectionplane_ID') && get_memory_attribute(@skpModel, 'Skalp', 'active_sectionplane_ID').slice(0, 1) then
        Skalp.sectionplane_active = true
        if Skalp.status != 0
          sectionplane = sectionplane_by_id(get_memory_attribute(@skpModel, 'Skalp', 'active_sectionplane_ID'))
          sectionplane ? sectionplane.activate : Skalp.sectionplane_active = false

          return sectionplane.section if Skalp.sectionplane_active
        end
      else
        Skalp.sectionplane_active = false
      end

      return nil
    end

    def to_s
      self.object_id
    end

    def start_operation
      #Skalp.p("+++ START OPERATION +++ #{caller}")
    end

    def commit_operation
      #Skalp.p("+++ COMMIT OPERATION +++ #{caller}")
    end

    def start(name = 'Skalp', new = false)
      @commitname = name

      if @operation == 0
        @operation = 1
        @observer_status = @observer_active
        @observer_active = false
        if new
          @new_operation = true
          @undo_name = name
          @skpModel.start_operation(name, true, false, false)
        else
          @skpModel.start_operation(name, true, false, true)
        end
      elsif @operation > 0
        @skpModel.set_attribute('Skalp', 'commit', Time.now.strftime("%H%M%S%N")) #avoid empty transaction
        @operation += 1
      end
    end

    def show_undo
      @pagesUndoRedo.show_stack
    end

    def commit
      if @operation == 1
        @skpModel.set_attribute('Skalp', 'commit', Time.now.strftime("%H%M%S%N")) #avoid empty transaction
        @skpModel.commit_operation
        @observer_active = true
        @operation = 0

        # MIGRATION SU2026: Removed create_status_on_undo_stack - native undo handles this
        load_commit if @load
      elsif @operation > 1
        @skpModel.set_attribute('Skalp', 'commit', Time.now.strftime("%H%M%S%N")) #avoid empty transaction
        @operation -= 1
      end
    end

    def force_start(name)
      if @operation > 0
        @skpModel.set_attribute('Skalp', 'commit', Time.now.strftime("%H%M%S%N")) #avoid empty transaction
        @skpModel.commit_operation
        @operation = 0
      end
      start(name, true)
    end

    def force_start_transparant(name)
      if @operation > 0
        @restart = true
        @skpModel.set_attribute('Skalp', 'commit', Time.now.strftime("%H%M%S%N")) #avoid empty transaction
        @skpModel.commit_operation
        @operation = 0
      else
        @restart = false
      end
      start(name, false)
    end

    def force_commit
      @restart ? start : @skpModel.commit_operation
    end

    def load_commit
      @load = false
      start('Skalp - ' + Skalp.translate('load model'))
      unless get_memory_attribute(@skpModel, 'Skalp', 'selected_page')
        set_memory_attribute(@skpModel, 'Skalp', 'selected_page', @skpModel.pages.selected_page)
      end
      commit
      @on_setup = false
    end

    def create_status_on_undo_stack
      return unless @controlCenter && @skpModel

      time = Time.now.strftime("%H%M%S%N")
      @place_timestamp = true
      start
      set_memory_attribute(@skpModel, 'Skalp', 'selected_page', @skpModel.pages.selected_page) if @skpModel.pages

      if @skpModel.entities.active_section_plane
        set_memory_attribute(@skpModel, 'Skalp', 'active_sectionplane_ID', @skpModel.entities.active_section_plane.get_attribute('Skalp', 'ID'))
      else
        set_memory_attribute(@skpModel, 'Skalp', 'active_sectionplane_ID', '')
      end

      set_memory_attribute(@skpModel, 'Skalp', 'page_undo', time)
      set_memory_attribute(@skpModel, 'Skalp', 'undo_action', @controlCenter.undo_action.inspect)

      @skpModel.set_attribute('Skalp', 'page_undo', time)
      commit
      @place_timestamp = false
      @controlCenter.undo_action = {}
      pagesUndoRedo.add_status(@memory_attributes.dup)
    end

    def abort_operation
      @skpModel.abort_operation
      @observer_active = @observer_status
      @operation = 0
    end

    # MIGRATION: Updated to use native SketchUp attributes (SU 2026 compatibility)
    # Writes directly to object.set_attribute() instead of in-memory dictionary
    # STYLE_SETTINGS keys that should be flattened to native attributes
    STYLE_SETTINGS_KEYS = [:drawing_scale, :rearview_status, :rearview_linestyle, :section_cut_width_status, :depth_clipping_status, :depth_clipping_distance]
    
    def set_memory_attribute(object, dict_name, key, value)
      return unless object  # Guard against nil object
      
      # Always maintain memory_attributes (required for complex data like style_settings Hash)
      @memory_attributes[object] = {} unless @memory_attributes.include?(object)
      @memory_attributes[object][key] = value
      
      # Handle style_settings Hash specially: flatten to individual native attributes
      if key == 'style_settings' && value.is_a?(Hash)
        STYLE_SETTINGS_KEYS.each do |style_key|
          style_value = value[style_key]
          # Convert to string for storage, skip style_rules (too complex)
          if style_value && !style_value.is_a?(Hash) && style_key != :style_rules
            object.set_attribute(dict_name, "ss_#{style_key}", style_value.to_s)
          end
        end
      # Write simple types to native attributes
      elsif value.nil? || value.is_a?(String) || value.is_a?(Numeric) || value.is_a?(TrueClass) || value.is_a?(FalseClass)
        object.set_attribute(dict_name, key, value)
      end
    end

    def get_memory_attribute(object, dict_name, key)
      return nil unless object  # Guard against nil object
      
      # Handle style_settings specially: reconstruct Hash from flattened native attributes
      if key == 'style_settings'
        # First try memory_attributes (for in-session data)
        if @memory_attributes.include?(object) && @memory_attributes[object]['style_settings'].is_a?(Hash)
          return @memory_attributes[object]['style_settings']
        end
        
        # Then try to reconstruct from native attributes
        reconstructed = {}
        has_any = false
        STYLE_SETTINGS_KEYS.each do |style_key|
          native_value = object.get_attribute(dict_name, "ss_#{style_key}")
          if native_value
            has_any = true
            # Convert back from string to appropriate type
            case style_key
            when :drawing_scale, :depth_clipping_distance
              reconstructed[style_key] = native_value.to_f
            when :rearview_status, :section_cut_width_status, :depth_clipping_status
              reconstructed[style_key] = (native_value == 'true' || native_value == true)
            else
              reconstructed[style_key] = native_value
            end
          end
        end
        return has_any ? reconstructed : nil
      end
      
      # For other keys: read from native attributes first
      value = object.get_attribute(dict_name, key)
      
      # Fallback to memory_attributes for old data during migration
      if value.nil? && @memory_attributes.include?(object)
        value = @memory_attributes[object][key]
      end
      
      return value
    end

    def clear_memory_attributes(object)
      # Clear memory cache (native attributes kept intact)
      @memory_attributes[object] = {}
    end

    def delete_memory_attribute(object, dict_name)
      # Delete from both systems
      @memory_attributes[object] = {}
      if object.attribute_dictionaries && object.attribute_dictionaries[dict_name]
        object.attribute_dictionaries.delete(dict_name)
      end
    end


    def check_empty_materials
      for material in @skpModel.materials do
        if material.name == ""
          Skalp.delete_empty_materials
          return
        end
      end
    end

    def hidden_entities_by_page(page)
      return unless page.class == Sketchup::Page

      entities = page.hidden_entities
      return unless entities

      @hidden_entities = Skalp::Set.new
      entities.each { |e| @hidden_entities << e }
    end

    def hidden_entities_for_model
      @processed_components = Skalp::Set.new
      @hidden_entities = Skalp::Set.new
      get_hidden_entities(@skpModel.entities)
    end

    def get_hidden_entities(entities)
      for e in entities
        next unless e.class == Sketchup::Drawingelement
        @hidden_entities << e if e.hidden?

        if e.class == Sketchup::Group
          get_hidden_entities(e.entities)
        elsif e.class == Sketchup::ComponentInstance
          unless @processed_components.include?(e)
            get_hidden_entities(e.definition.entities)
            @processed_components << e
          end
        end
      end
    end

    def turn_on_animation
      if Skalp::OS == :MAC
        return unless @skpModel && @skpModel.class == Sketchup::Model
        @skpModel.options[1][0] = get_memory_attribute(@skpModel, 'Skalp', 'ShowTransition')
        @skpModel.options[1][1] = get_memory_attribute(@skpModel, 'Skalp', 'TransitionTime').to_f
        @skpModel.options[2][0] = get_memory_attribute(@skpModel, 'Skalp', 'LoopSlideshow')
        @skpModel.options[2][1] = get_memory_attribute(@skpModel, 'Skalp', 'SlideTime').to_f
      else
        return unless @skpModel && @skpModel.class == Sketchup::Model
        @skpModel.options[0][0] = get_memory_attribute(@skpModel, 'Skalp', 'ShowTransition')
        @skpModel.options[0][1] = get_memory_attribute(@skpModel, 'Skalp', 'TransitionTime').to_f
        @skpModel.options[2][0] = get_memory_attribute(@skpModel, 'Skalp', 'LoopSlideshow')
        @skpModel.options[2][1] = get_memory_attribute(@skpModel, 'Skalp', 'SlideTime').to_f
      end
    end

    def load_prefs
      (get_memory_attribute(@skpModel, 'Skalp', 'skalp_version')) ?
          @skalp_version = get_memory_attribute(@skpModel, 'Skalp', 'skalp_version') :
          @skalp_version = Skalp::SKALP_VERSION

      @prefs = {
          'skalp_version' => @skalp_version,
      }

      save_prefs
    end

    def save_prefs
      return unless @prefs #TODO waar worden deze prefs geplaats?
      @prefs.each { |pref, value| set_memory_attribute(@skpModel, 'Skalp', pref, value) }
    end

    def load_layers
      @layers = {}
      for skpLayer in @skpModel.layers
        add_skpLayer(skpLayer) #if skpLayer.get_attribute('Skalp','ID') == nil   #TODO zien of dit geen problemen geeft met de observers
      end
    end

    def load_pages
      @pages = {}
      for skpPage in @skpModel.pages
        next unless skpPage
        add_skpPage(skpPage, false) if get_memory_attribute(skpPage, 'Skalp', 'ID')
      end
    end

    def layer_by_id(skalpID)
      return unless @layers
      @layers.each_value { |layer|
        next unless layer
        return layer if layer.skalpID == skalpID }

      return nil
    end

    def page_by_id(skalpID)
      return unless @pages
      @pages.each_value { |page|
        next unless page
        return page if page.skalpID == skalpID }

      return nil
    end

    def load_sectionplanes
      @sectionplanes = {}
      for skpSectionplane in @skpModel.entities.grep(Sketchup::SectionPlane)
        next unless skpSectionplane
        next unless skpSectionplane.get_attribute('Skalp', 'ID')
        section_name = Skalp::get_Skalp_sectionplane_name(skpSectionplane)
        skpSectionplane.symbol = section_name[:symbol]
        skpSectionplane.name = section_name[:name]
        add_sectionplane(skpSectionplane, false)
      end
    end

    def check_sectionplane_name(name)
      return unless @sectionplanes
      check = true
      @sectionplanes.each_value { |value|
        next unless value
        check = false if value.sectionplane_name == name
      }
      return check
    end

    def sectionplane_by_id(skalpID)
      return unless @sectionplanes
      @sectionplanes.each_value { |sectionplane| return sectionplane if sectionplane.skalpID == skalpID && sectionplane.skalpID != nil }
      return nil
    rescue
      return nil
    end

    def set_sectionplane_layers_off
      return unless @sectionplanes

      observer_status = @observer_active
      @observer_active = false

      @sectionplanes.each_value { |sectionplane|
        next unless sectionplane.skpSectionPlane
        next unless sectionplane.skpSectionPlane.valid?
        sectionplane.skpSectionPlane.hidden = true
      }
      if Skalp.sectionplane_active == false
        @section_result_group.entities.grep(Sketchup::Group).each do |section_group|
          if section_group.get_attribute('Skalp', 'ID')
            if section_group.get_attribute('Skalp', 'ID') == 'skalp_live_sectiongroup'
              section_group.hidden = true
            end
          end
        end
      end

      @observer_active = observer_status
    end

    def set_skalp_layers_off
      return unless @skpModel

      observer_status = @observer_active
      @observer_active = false

      for skpLayer in @skpModel.layers
        skpLayer.visible = false if skpLayer.get_attribute('Skalp', 'ID')
      end

      @observer_active = observer_status
    end

    def load_observers
      @entities_observer = SkalpEntitiesObserver.new
      @skpModel.entities.add_observer(@entities_observer) if @skpModel.entities

      @selection_observer = SkalpSelectionObserver.new
      @skpModel.selection.add_observer(@selection_observer) if @skpModel.selection

      @pages_observer = SkalpPagesObserver.new
      @skpModel.pages.add_observer(@pages_observer) if @skpModel.pages

      @layers_observer = SkalpLayersObserver.new
      @skpModel.layers.add_observer(@layers_observer) if @skpModel.layers

      @tools_observer = SkalpToolsObserver.new
      @skpModel.tools.add_observer(@tools_observer) if @skpModel.tools

      @materials_observer = SkalpMaterialsObserver.new
      @skpModel.materials.add_observer(@materials_observer) if @skpModel.materials

      @render_options_observer = SkalpRenderingOptionsObserver.new
      @skpModel.rendering_options.add_observer(@render_options_observer) if @skpModel.rendering_options

      @model_observer = SkalpModelObserver.new
      @skpModel.add_observer(@model_observer)

    rescue => e
      Skalp.errors(e)
    end

    def unload_observers
      @layers.each_value do |layer|
        next unless layer.skpLayer.valid?
        layer.skpLayer.remove_observer(layer.observer) if layer.observer
      end
      @sectionplanes.each_value do |sectionplane|
        next unless sectionplane.skpSectionPlane.valid?
        sectionplane.skpSectionPlane.remove_observer(sectionplane.observer) if sectionplane.observer
      end
      @skpModel.tools.remove_observer(@tools_observer) if @skpModel.tools && @tools_observer
      @skpModel.layers.remove_observer(@layers_observer) if @skpModel.layers && @layers_observer
      @skpModel.materials.remove_observer(@materials_observer) if @skpModel.materials && @materials_observer
      @skpModel.pages.remove_observer(@pages_observer) if @skpModel.pages && @pages_observer
      @skpModel.selection.remove_observer(@selection_observer) if @skpModel.entities && @skpModel.selection && @selection_observer
      @skpModel.entities.remove_observer(@entities_observer) if @skpModel.entities && @entities_observer
      @skpModel.rendering_options.remove_observer(@render_options_observer) if @skpModel.rendering_options && @render_options_observer
      @skpModel.active_view.remove_observer(view_observer) if view_observer
      @skpModel.remove_observer(@model_observer) if @model_observer

    rescue => e
      Skalp.errors(e)
    end

    def add_skpLayer(skpLayer)
      @layers[skpLayer] = Skalp::Layer.new(skpLayer, self)
    end

    def add_skpPage(skpPage, new = false)
      return unless skpPage
      @pages[skpPage] = Skalp::Page.new(skpPage, new)
    end

    def add_layer(layername, skalpID = nil)

      if skalpID
        layer = layer_by_id(skalpID)
        return layer if layer
      end

      observer_status = @observer_active
      @observer_active = false

      skpLayer = @skpModel.layers.add(layername)
      skpLayer.page_behavior = LAYER_HIDDEN_BY_DEFAULT
      skpLayer.set_attribute('Skalp', 'ID', skalpID) #TODO klopt niet
      layer = Skalp::Layer.new(skpLayer, self)
      @layers[skpLayer] = layer
      @observer_active = observer_status

      return layer
    end

    def safe_layername(layername)
      if @skpModel.layers[layername]
        if layername =~ /#\d+\Z/
          layername = layername.succ
        else
          layername = layername + ' #1'
        end
        return safe_layername(layername)
      else
        return layername
      end
    end

    def rename_scene_layer(pages)
      page = pages.selected_page
      return unless page
      return if get_memory_attribute(page, 'Skalp', 'sectionplaneID') == '' || get_memory_attribute(page, 'Skalp', 'sectionplaneID') == nil

      page_id = get_memory_attribute(page, 'Skalp', 'ID')
      page_name = page.name

      skalp_layer = layer_by_id(page_id)
      skalp_layer ? layer = skalp_layer.skpLayer : return

      if layer.valid? && layer.name.gsub(/ #\d+\Z/, '') != "#{Skalp.translate('Scene') + ': '}#{page_name}"
        start('Skalp - ' + Skalp.translate('rename scene layer'))
        layer.name = "\uFEFF".encode('utf-8') + safe_layername("#{Skalp.translate('Scene') + ': '}#{page_name}")
        commit
      end
    end

    def remove_layer(layer)
      @layers.delete(layer.skpLayer) if layer
    end

    def add_sectionplane(skpSectionplane, make_active = true)
      sectionplane = Skalp::SectionPlane.new(skpSectionplane, self)
      @sectionplanes[skpSectionplane] = sectionplane
      set_active_sectionplane(sectionplane.skalpID) if make_active
    end

    def delete_sectionplane(sectionplane, already_deleted = false)
      return unless sectionplane
      start('Skalp - ' + Skalp.translate('delete Section Plane'))

      observer_status = @observer_active
      @observer_active = false

      skpSectionplane = sectionplane.skpSectionPlane

      if skpSectionplane
        @sectionplane_entityIDs -= [(skpSectionplane.entityID).abs] if skpSectionplane.valid?
        @sectionplanes.delete(skpSectionplane)
      end

      sectionplane.delete
      Skalp.dialog.no_active_sectionplane

      @observer_active = observer_status
      commit
    end

    def active_sectionplane
      # SU 2026: Priority to native SketchUp state (Source of Truth)
      skpSectionplane = @skpModel.active_entities.active_section_plane
      if skpSectionplane && skpSectionplane.valid?
        id = skpSectionplane.get_attribute('Skalp', 'ID')
        sp = sectionplane_by_id(id) if id
        return sp if sp
      end
      
      # Fallback to attribute
      skalpID = get_memory_attribute(@skpModel, 'Skalp', 'active_sectionplane_ID')
      skalpID && skalpID != '' && sectionplane_by_id(skalpID)
    end

    def sectionplane_in_active_page_match_model_sectionplane?
      get_memory_attribute(@skpModel.pages.selected_page, 'Skalp', 'sectionplaneID') == get_memory_attribute(@skpModel, 'Skalp', 'active_sectionplane_ID')
    end

    def set_active_sectionplane(skalpID)
      observer_status = @observer_active
      @observer_active = false
      set_memory_attribute(@skpModel, 'Skalp', 'active_sectionplane_ID', skalpID)
      Skalp.sectionplane_active = true
      Skalp.dialog.update(1) if Skalp.dialog && sectionplane_by_id(skalpID)
      @observer_active = observer_status

      if skalpID && skalpID != ''
        Skalp.dialog.show_dialog_settings
      else
        Skalp.dialog.blur_dialog_settings
      end
    end

    def activate_sectionplane_by_name(name)
      return if Skalp.page_change
      @sectionplanes.each_value { |sectionplane| sectionplane.sectionplane_name == name && sectionplane.activate && return }
    end

    def get_sectionplane_by_name(name)
      return nil unless @sectionplanes
      @sectionplanes.each_value { |sectionplane|
        return sectionplane if sectionplane.sectionplane_name == name }
      return nil
    end

    def new_sectiongroup(skpPage = @skpModel)
      return unless @skpModel.entities

      @section_result_group.locked = false
      @sectiongroup = @section_result_group.entities.add_group

      return unless @sectiongroup.class == Sketchup::Group #Bug SU2016 the add_group returns wrong types
      (skpPage.class == Sketchup::Page) ? @sectiongroup.name = 'Skalp ' + 'scene section - ' + skpPage.name : @sectiongroup.name = 'Skalp ' + 'active section'
      (skpPage.class == Sketchup::Page) ? @sectiongroup.set_attribute('Skalp', 'ID', get_memory_attribute(skpPage, 'Skalp', 'ID')) : @sectiongroup.set_attribute('Skalp', 'ID', 'skalp_live_sectiongroup')

      cpoint = @sectiongroup.entities.add_cpoint(Geom::Point3d.new(0, 0, 0))
      cpoint.hidden = true if cpoint.class == Sketchup::ConstructionPoint
      @section_result_group.locked = true
      return @sectiongroup
    end

    def version
      @skpModel.get_attribute('Skalp', 'version')
    end

    def set_version
      @skpModel.set_attribute('Skalp', 'version', Skalp::SKALP_VERSION)
    end

    def skalp_sections_off
      return unless @skpModel

      #set visibility of the sectionplane
      @skpModel.entities.grep(Sketchup::SectionPlane).each do |sectionplane|
        sectionplane.hidden = true if sectionplane.get_attribute('Skalp', 'ID')
      end

      #set visiblity of the section_groups
      return unless @section_result_group
      @section_result_group.entities.grep(Sketchup::Group).each do |section_group|
        if section_group.get_attribute('Skalp', 'ID')
          section_group.hidden = true
        end
      end
    end

    def manage_scenes
      skalp_pages = []
      no_skalp_pages = []
      check_pages
      for skpPage in @skpModel.pages
        if get_memory_attribute(skpPage, 'Skalp', 'ID')
          Skalp.force_style_to_show_skalp_section(skpPage)
          skalp_pages << skpPage
        else
          no_skalp_pages << skpPage
        end
      end

      manage_sections(skalp_pages, no_skalp_pages)
    end

    def hiddenline_bounds(page)
      result = {}
      min_x, min_y, max_x, max_y = nil

      return unless (@hiddenlines.forward_lines_result[page] && @hiddenlines.forward_lines_result[page].class == Hash)

      @hiddenlines.forward_lines_result[page].each do |layer, lines|
        lines.each_curve do |line|
          line.each do |point|
            min_x = point[0] if (!min_x || point[0] < min_x)
            min_y = point[1] if (!min_y || point[1] < min_y)
            max_x = point[0] if (!max_x || point[0] > max_x)
            max_y = point[1] if (!max_y || point[1] > max_y)
          end
        end
      end

      result[:min_x] = min_x
      result[:min_y] = min_y
      result[:max_x] = max_x
      result[:max_y] = max_y

      return result
    end

    def export_dxf_pages(filename, layer_preset, pages = nil)
      if pages
        page = pages.shift
        index = Skalp.page_index(page)
      else
        page = Sketchup.active_model
        index = -1
      end

      style_stettings = Skalp.active_model.get_memory_attribute(page, 'Skalp', 'style_settings')
      if style_stettings.class == Hash
        @linestyle = Skalp.active_model.get_memory_attribute(page, 'Skalp', 'style_settings')[:rearview_linestyle]
        if @linestyle == nil || @linestyle == ''
          @linestyle = 'Dash'
          style_stettings[:rearview_linestyle] = 'Dash'
        end
      else
        @linestyle = 'Dash'
      end

      if @hiddenlines.get_page_info_by_index(index) && @hiddenlines.get_page_info_by_index(index)[:parallel] && @hiddenlines.get_page_info_by_index(index)[:sectionplane] #Skalp section and view parallel with section
        if page && @pages[page] && @pages[page].sectionplane
          @pages[page].sectionplane.section.export_dxf(filename, layer_preset, page)
        else
          active_sectionplane.section.export_dxf(filename, layer_preset)
        end
      else
        bounds = hiddenline_bounds(page)
        if (page && page.class == Sketchup::Page) then
          name = page.name
        elsif Sketchup.active_model.pages && Sketchup.active_model.pages.selected_page
          name = Sketchup.active_model.pages.selected_page.name
        else
          name = ""
        end

        if bounds
          Skalp::DXF_export.new(filename, name, nil, @hiddenlines.forward_lines_result[page], nil, [Skalp::inch_to_modelunits(bounds[:min_x]), Skalp::inch_to_modelunits(bounds[:min_y])], [Skalp::inch_to_modelunits(bounds[:max_x]), Skalp::inch_to_modelunits(bounds[:max_y])], @hiddenlines.get_page_info_by_index(index)[:scale], @linestyle)
        end
      end

      export_dxf_pages(filename, layer_preset, pages) if pages && pages != []
    end

    def export_all_dxf_pages(filename, layer_preset)
      pages = []
      @skpModel.pages.each do |skpPage|
        pages << skpPage
      end

      export_dxf_pages(filename, layer_preset, pages)
    end

    def export_selected_pages_dxf(filename, layer_preset)
      export_dxf_pages(filename, layer_preset, Skalp.export_scene_list)
    end

    def update_all_pages_dxf
      check_pages

      for skpPage in @skpModel.pages
        sectionplane_by_id(get_memory_attribute(skpPage, 'Skalp', 'sectionplaneID')).calculate_section(false, skpPage) if get_memory_attribute(skpPage, 'Skalp', 'ID')
      end
    end

    def update_selected_pages_dxf
      check_pages

      pages = Skalp.export_scene_list
      for skpPage in pages
        sectionplane_by_id(get_memory_attribute(skpPage, 'Skalp', 'sectionplaneID')).calculate_section(false, skpPage) if get_memory_attribute(skpPage, 'Skalp', 'ID')
      end
    end

    def covert_skalp_layers
      start('Skalp - remove old Skalp layers', true)
      layers_to_delete = []

      layers = @skpModel.layers
      entities = @skpModel.entities

      old_version = false
      #Place sectionplanes on Layer0
      section_planes = entities.grep(Sketchup::SectionPlane)

      section_planes.each do |sectionplane|
        if sectionplane.get_attribute('Skalp', 'ID') && sectionplane.layer.name.include?('Section Plane:')
          old_version = true
          layers_to_delete << sectionplane.layer
          sectionplane.layer = nil
        end
      end

      #Remove sectiongroup layers
      layers.each do |layer|
        layer_id = layer.get_attribute('Skalp', 'ID')
        if layer_id && layer.name.include?("Scene:")
          old_version = true
          layers_to_delete << layer
        end
        layers_to_delete << layer if layer.name.include?("*** SKALP LAYERS ***")
        layers_to_delete << layer if layer.name.include?("Skalp Live Section")
      end

      if old_version
        result = UI.messagebox('This model contains Skalp sections from a previous version. Skalp will update these sections.')

        if result == IDOK
          section_groups = entities.grep(Sketchup::Group)

          section_groups.each { |group| group.locked = false if group.get_attribute('Skalp', 'ID') }
          layers_to_delete.each { |layer| layers.remove(layer, true) }
          UI.messagebox('Skalp sections are updated!')
        end
      end

      commit
    end

    def manage_sections(skalp_pages, no_skalp_pages)
      @section_result_group.locked = false
      @section_result_group.hidden = false
      section_groups = @section_result_group.entities.grep(Sketchup::Group)
      section_planes = @skpModel.entities.grep(Sketchup::SectionPlane)

      skalp_pages.each do |page|
        Skalp.sectiongroup_visibility(@section_result_group, true, page)

        pageID = get_memory_attribute(page, 'Skalp', 'ID')
        sectionplaneID = get_memory_attribute(page, 'Skalp', 'sectionplaneID')

        #visibility of the section result group
        @skalp_folder.visible = true
        section_groups.each do |section_group|
          if section_group.get_attribute('Skalp', 'ID') == pageID
            section_group.layer = Skalp.scene_section_layer
            Skalp.sectiongroup_visibility(section_group, true, page)
          else
            Skalp.sectiongroup_visibility(section_group, false, page)
          end
        end

        #set visibility of the sectionplane
        section_planes.each do |sectionplane|
          if sectionplane.get_attribute('Skalp', 'ID')
            if sectionplane.get_attribute('Skalp', 'ID') == sectionplaneID
              page.set_drawingelement_visibility(sectionplane, true)
            else
              page.set_drawingelement_visibility(sectionplane, false)
            end
          end
        end
      end

      #active model
      sectionplaneID = get_memory_attribute(@skpModel, 'Skalp', 'active_sectionplane_ID')

      #set visibility of the sectionplane
      @skpModel.entities.grep(Sketchup::SectionPlane).each do |sectionplane|
        if sectionplane.get_attribute('Skalp', 'ID')
          if sectionplane.get_attribute('Skalp', 'ID') == sectionplaneID
            sectionplane.hidden = false
          else
            sectionplane.hidden = true
          end
        end
      end

      #set visiblity of the section_groups
      section_result_group.entities.grep(Sketchup::Group).each do |section_group|
        if section_group.get_attribute('Skalp', 'ID') == 'skalp_live_sectiongroup' && Skalp.sectionplane_active == true
          section_group.layer = nil
          Skalp.sectiongroup_visibility(section_group, true)
        else
          Skalp.sectiongroup_visibility(section_group, false)
        end
      end

      no_skalp_pages.each do |page|
        #visibility of the section result group
        section_groups.each do |section_group|
          Skalp.sectiongroup_visibility(section_group, false, page)
        end

        #set visibility of the sectionplane
        section_planes.each do |sectionplane|
          page.set_drawingelement_visibility(sectionplane, false)
        end
      end

      Skalp.scene_section_layer.visible = false
      @section_result_group.layer = nil
      @section_result_group.locked = true
    end

    def update_all_pages(save = true, rear_view = true)
      Skalp.block_observers = true
      skalp_pages = []
      no_skalp_pages = []
      check_pages

      start('Skalp - set style to show Skalp section', true)

      for skpPage in @skpModel.pages
        if get_memory_attribute(skpPage, 'Skalp', 'ID')
          Skalp.force_style_to_show_skalp_section(skpPage)
          skalp_pages << skpPage
        else
          no_skalp_pages << skpPage
        end
      end

      return if pages == []

      commit

      if OS == :WINDOWS
        Sketchup.set_status_text "#{Skalp.translate('Processing Scene')} (#{Skalp.translate('step')} 1/4) #{Skalp.translate('Please wait...')}"
        start('Skalp - Processing Scene', true)
        skalp_pages.each { |skpPage| sectionplane_by_id(get_memory_attribute(skpPage, 'Skalp', 'sectionplaneID')).calculate_section(false, skpPage) }

        manage_sections(skalp_pages, no_skalp_pages)
        commit

        start('Skalp - Processing rear lines', true)
        Sketchup.set_status_text "#{Skalp.translate('Processing rear lines')} (#{Skalp.translate('step')} 2/4) #{Skalp.translate('Please wait...')}"
        @hiddenlines.update_rear_lines(:all, true) if rear_view
        commit

        if rear_view
          Sketchup.set_status_text "#{Skalp.translate('Adding rear lines')} (#{Skalp.translate('step')} 3/4) #{Skalp.translate('Please wait...')}"
          start('Skalp - adding rear lines', true)
          @hiddenlines.add_rear_lines_to_model(:all)
          manage_sections(skalp_pages, no_skalp_pages)
          commit
        end

        Skalp.block_observers = false

        if save
          Sketchup.set_status_text "#{Skalp.translate('Saving Model')} (#{Skalp.translate('step')} 4/4) #{Skalp.translate('Please wait...')}"
          Sketchup.send_action 'saveDocument:'
          Sketchup.set_status_text "#{Skalp.translate('All Scenes successfully processed.')} #{Skalp.translate('Model saved.')}"
        else
          Sketchup.set_status_text "#{Skalp.translate('All Scenes successfully processed.')}"
        end

        Skalp.active_model.observer_active = true
        Skalp.exportLObutton_off
      else
        UI.start_timer(0.01, false) { Sketchup.set_status_text "#{Skalp.translate('Processing Scene')} (#{Skalp.translate('step')} 1/4) #{Skalp.translate('Please wait...')}" }
        UI.start_timer(0.01, false) do
          start('Skalp - Processing rear lines', true)
          skalp_pages.each { |skpPage| sectionplane_by_id(get_memory_attribute(skpPage, 'Skalp', 'sectionplaneID')).calculate_section(false, skpPage) }
          manage_sections(skalp_pages, no_skalp_pages)
          commit
        end

        if rear_view
          UI.start_timer(0.01, false) { Sketchup.set_status_text "#{Skalp.translate('Processing rear lines')} (#{Skalp.translate('step')} 2/4) #{Skalp.translate('Please wait...')}" }
          UI.start_timer(0.01, false) do
            start('Skalp - adding rear lines', true)
            @hiddenlines.update_rear_lines(:all, true)
            commit
          end
        end

        if rear_view
          UI.start_timer(0.01, false) { Sketchup.set_status_text "#{Skalp.translate('Adding rear lines')} (#{Skalp.translate('step')} 3/4) #{Skalp.translate('Please wait...')}" }
          UI.start_timer(0.01, false) {
            start('Skalp - adding rear lines', true)
            @hiddenlines.add_rear_lines_to_model(:all)
            manage_sections(skalp_pages, no_skalp_pages)
            commit
          }
        end

        if save
          UI.start_timer(0.01, false) { Sketchup.set_status_text "#{Skalp.translate('Saving Model')} (#{Skalp.translate('step')} 4/4) #{Skalp.translate('Please wait...')}" }
          UI.start_timer(0.01, false) { Sketchup.send_action 'saveDocument:' }
          UI.start_timer(0.01, false) { Sketchup.set_status_text "#{Skalp.translate('All Scenes successfully processed.')} #{Skalp.translate('Model saved.')}" }
        else
          UI.start_timer(0.01, false) { Sketchup.set_status_text "#{Skalp.translate('All Scenes successfully processed.')}" }
        end

        UI.start_timer(0.01, false) {Skalp.active_model.observer_active = true; Skalp.exportLObutton_off }
      end
    end

    def turn_off_animation
      start('Skalp - ' + Skalp.translate('turn OFF live updating'), true)
      if Skalp::OS == :MAC
        return unless @skpModel && @skpModel.class == Sketchup::Model
        set_memory_attribute(@skpModel, 'Skalp', 'ShowTransition', @skpModel.options[1][0])
        set_memory_attribute(@skpModel, 'Skalp', 'TransitionTime', @skpModel.options[1][1])
        set_memory_attribute(@skpModel, 'Skalp', 'LoopSlideshow', @skpModel.options[2][0])
        set_memory_attribute(@skpModel, 'Skalp', 'SlideTime', @skpModel.options[2][1])

        @skpModel.options[1][0] = false
        @skpModel.options[1][1] = 0.0
        @skpModel.options[2][0] = false
        @skpModel.options[2][1] = 0.0
      else #BLIJKBAAR HEEFT WINDOWS ANDERE INDEXEN
        return unless @skpModel && @skpModel.class == Sketchup::Model
        set_memory_attribute(@skpModel, 'Skalp', 'ShowTransition', @skpModel.options[0][0])
        set_memory_attribute(@skpModel, 'Skalp', 'TransitionTime', @skpModel.options[0][1])
        set_memory_attribute(@skpModel, 'Skalp', 'LoopSlideshow', @skpModel.options[2][0])
        set_memory_attribute(@skpModel, 'Skalp', 'SlideTime', @skpModel.options[2][1])

        @skpModel.options[0][0] = false
        @skpModel.options[0][1] = 0.0
        @skpModel.options[2][0] = false
        @skpModel.options[2][1] = 0.0
      end

    rescue
      unless @retried
        @retried = true
        retry if @skpModel && Sketchup.active_model
      end
    ensure
      commit
    end

    def prepare_section_result_group
      @section_result_group = nil

      @skpModel.entities.grep(Sketchup::Group).each do |group|
        if group.get_attribute('Skalp', 'section_result_group') == true
          @section_result_group = group
          @section_result_group.name = 'Skalp sections'
          @section_result_group.layer = nil
        end
      end

      unless @section_result_group
        start
        @section_result_group = @skpModel.entities.add_group
        @section_result_group.set_attribute('Skalp', 'section_result_group', true)
        @section_result_group.name = 'Skalp sections'
        @section_result_group.layer = nil

        point1 = Geom::Point3d.new(0, 0, 0)
        point2 = Geom::Point3d.new(0.01, 0, 0)
        line = @section_result_group.entities.add_line point1, point2
        line.hidden = true

        @section_result_group.locked = true
        commit
      end
    end

    def check_pages
      @skpModel.pages.each { |page|
        if get_memory_attribute(page, 'Skalp', 'sectionplaneID')
          if sectionplane_by_id(get_memory_attribute(page, 'Skalp', 'sectionplaneID'))
            unless get_memory_attribute(page, 'Skalp', 'ID')
              Skalp.set_ID(page)
            end
          else
            delete_memory_attribute(page, 'Skalp')
          end
        end
        if get_memory_attribute(page, 'Skalp', 'ID')
          unless get_memory_attribute(page, 'Skalp', 'sectionplaneID')
            delete_memory_attribute(page, 'Skalp')
          end
        end
      }
    end

    def find_deleted_sectionplane
      return_sectionplane = nil

      @sectionplanes.each do |skpSectionplane, sectionplane|
        if skpSectionplane.deleted?
          return_sectionplane = sectionplane
          break
        end
      end

      return return_sectionplane
    end

    def find_live_sectiongroup
      found_group = nil
      to_delete = []
      name = 'skalp_live_sectiongroup'
      for group in @section_result_group.entities.grep(Sketchup::Group)
        to_delete << group if group.layer.name == 'Skalp Live Section' && group.get_attribute('Skalp', 'ID') != name
        found_group == group if group.get_attribute('Skalp', 'ID') == name
      end

      observer_status = @observer_active
      @observer_active = false
      @skpModel.entities.erase_entities(to_delete)
      @observer_active = observer_status

      return found_group
    end

    def turnoff_live_section_in_pages
      return unless @live_sectiongroup
      @skpModel.pages.each { |skpPage| Skalp.sectiongroup_visibility(@live_sectiongroup, false, skpPage) }
    end

    def count_sectionplanes_by_name(name)
      count = 0
      @skpModel.entities.grep(Sketchup::SectionPlane).each do |sectionplane|
        count += 1 if sectionplane.get_attribute('Skalp', 'sectionplane_name') == name
      end
      count
    end

    def version_recover
      version = get_memory_attribute(@skpModel, 'Skalp', 'skalp_version').to_s

      case version
      when '2.0.0055', '2.0.0056', '2.0.0062'
        #eval(material.get_attribute('Skalp', 'pattern_info').split(')).to_s;').last)     OLD
        #eval(material.get_attribute('Skalp', 'pattern_info').split(').to_s);').last)     NIEUW
        @skpModel.materials.each do |mat|
          attrib = material.get_attribute('Skalp', 'pattern_info')
          mat.set_attribute('Skalp', 'pattern_info', attrib.gsub(".split(')).to_s;", ".split(').to_s);"))
        end
      end
    end

    def correct_sectiongroup(id, layer)
      Sketchup.active_model.entities.grep(Sketchup::Group).each { |group| group.layer = layer if group.get_attribute('Skalp', 'ID') == id }
    end

    def find_layer(name)
      search_name = "Scene: " + name
      @skalp_layers.each do |layer|
        return layer if layer.name.include?(search_name)
      end
    end

    def live_section_off
      delete_sectiongroups
      Sketchup.active_model.rendering_options['SectionDefaultFillColor'] = 'DarkGray'
      Sketchup.active_model.rendering_options['SectionCutFilled'] = true
    end

    def live_section_on
      Sketchup.active_model.rendering_options['SectionCutFilled'] = false
    end

    def delete_sectiongroups
      to_delete = []
      @skpModel.entities.grep(Sketchup::Group).each do |group|
        next if group.deleted?
        if (group.name.include?('Skalp scene section - ') || group.name == 'Skalp Active View')
          to_delete << group
        end
      end

      to_delete.each do |group|
        group.locked = false
        @skpModel.entities.erase_entities(group)
      end
    end
  end
end


