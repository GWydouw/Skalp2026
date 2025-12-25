require 'sketchup.rb'
require 'json'

module Skalp
  module BoxSection
    DICTIONARY_NAME = 'Skalp_BoxSection' unless defined?(DICTIONARY_NAME)
    ATTR_IS_BOX_SECTION = 'is_box_section' unless defined?(ATTR_IS_BOX_SECTION)

    # Persistence Layer
    module Data
      DICTIONARY = 'Skalp_BoxSection_Data'
      
      def self.get_config(model)
        json = model.get_attribute(DICTIONARY, 'config', '{}')
        JSON.parse(json) rescue {}
      end

      def self.save_config(model, config)
        model.set_attribute(DICTIONARY, 'config', config.to_json)
      end

      def self.get_hierarchy(model)
        json = model.get_attribute(DICTIONARY, 'hierarchy', '[]')
        JSON.parse(json) rescue []
      end

      def self.save_hierarchy(model, hierarchy)
        model.set_attribute(DICTIONARY, 'hierarchy', hierarchy.to_json)
      end
      
      def self.safe_read_default(key, default_val = nil)
        begin
          Sketchup.read_default("Skalp", key, default_val)
        rescue Exception => e
          # Catches SyntaxError from auto-eval on Mac
          puts "Skalp: Recovering from read_default error for #{key}: #{e}"
          default_val
        end
      end

      def self.get_defaults
        defaults = {
          "scale" => "1/50",
          "sides_all_same" => true,
          "rear_view_global" => "off",
          "rear_view_projection" => "off", # Legacy/fallback
          "section_cut_width" => true,
          "style_rule" => "combined",
          "sides" => { "all" => { "cut_width" => true, "style_rule" => "combined", "rear_view" => "off" } }
        }
        begin
          # Use versioned keys to avoid corrupted / auto-evaluating old data on Mac
          saved = safe_read_default("SectionBoxDefaults_v3")
          if saved
            if saved.is_a?(String) && saved.start_with?("SB_JSON:")
              saved_data = JSON.parse(saved[8..-1])
            elsif saved.is_a?(Hash)
              saved_data = saved
            else
              saved_data = JSON.parse(saved) rescue nil
            end
            defaults.merge!(saved_data) if saved_data.is_a?(Hash)
          end
        rescue Exception => e
          puts "Skalp: Error parsing defaults: #{e}"
        end
        defaults
      end

      def self.save_defaults(settings)
        # Store essential defaults
        defaults = {
          "scale" => settings["scale"],
          "sides_all_same" => settings["sides_all_same"],
          "rear_view_global" => settings["rear_view_global"],
          "sides" => settings["sides"]
        }
        Sketchup.write_default("Skalp", "SectionBoxDefaults_v3", "SB_JSON:" + defaults.to_json)
      end

      def self.get_scales
        default_scales = [
          "1:1", "1:2", "1:5", "1:10", "1:20", "1:50", "1:100", "1:200", "1:500", "1:1000",
          "1\" = 1' (1:12)", "1/8\" = 1' (1:96)", "1/4\" = 1' (1:48)", "1/2\" = 1' (1:24)",
          "3/4\" = 1' (1:16)", "3\" = 1' (1:4)"
        ]
        begin
          # Use versioned keys to avoid corrupted / auto-evaluating old data on Mac
          saved = safe_read_default("SectionBoxScales_v3")
          if saved
            if saved.is_a?(String) && saved.start_with?("SB_JSON:")
              return JSON.parse(saved[8..-1])
            elsif saved.is_a?(Array)
              return saved
            else
              return JSON.parse(saved) rescue nil
            end
          end
        rescue Exception => e
          puts "Skalp: Error parsing scales: #{e}"
        end
        default_scales
      end

      def self.save_scales(scales_array)
        Sketchup.write_default("Skalp", "SectionBoxScales_v3", "SB_JSON:" + scales_array.to_json)
      end
    end

    # Shared drawing utilities
    module DrawHelper
      def self.get_color(face_name)
        case face_name
        when "top", "bottom" then Sketchup::Color.new(0, 0, 255)
        when "front", "back" then Sketchup::Color.new(255, 0, 0)
        when "left", "right" then Sketchup::Color.new(0, 255, 0)
        else Sketchup::Color.new(74, 144, 226)
        end
      end

      def self.draw_bounds(view, planes_data)
        unique_edges = {}
        planes_data.each do |data|
          verts = data[:face_vertices]
          next unless verts && verts.length >= 3
          verts.each_with_index do |v, i|
            v2 = verts[(i + 1) % verts.length]
            key = [[v.x.round(2), v.y.round(2), v.z.round(2)], [v2.x.round(2), v2.y.round(2), v2.z.round(2)]].sort.to_s
            unique_edges[key] ||= [v, v2]
          end
        end
        view.drawing_color = Sketchup::Color.new(128, 128, 128)
        view.line_width = 1
        view.line_stipple = "_"
        unique_edges.each_value { |edge| view.draw(GL_LINES, edge) }
        view.line_stipple = ""
      end

      def self.draw_face_highlight(view, face_vertices, face_name)
        return unless face_vertices && face_vertices.length >= 3
        color = get_color(face_name)
        view.drawing_color = Sketchup::Color.new(color.red, color.green, color.blue, 25)
        view.draw(GL_POLYGON, face_vertices)
      end

      def self.draw_plus(view, center, normal, face_name, highlighted, color_override = nil)
        arm = 15.0
        width = highlighted ? 4 : 2
        color = highlighted && color_override ? color_override : get_color(face_name)
        axes = normal.axes
        v1 = axes[0]; v2 = axes[1]
        v1.length = v2.length = arm / 2.0
        view.drawing_color = color
        view.line_width = width
        view.draw(GL_LINES, [center.offset(v1), center.offset(v1.reverse)])
        view.draw(GL_LINES, [center.offset(v2), center.offset(v2.reverse)])
      end
    end

    def self.get_active_box_section_group
      Sketchup.active_model.entities.find { |e| e.get_attribute(DICTIONARY_NAME, 'box_id') == Engine.active_box_id }
    end

    def self.get_section_planes_data
      root = get_active_box_section_group
      return nil unless root && root.valid?
      
      planes_data = []
      root.entities.each do |ent|
        if ent.is_a?(Sketchup::SectionPlane)
          match = ent.name.match(/\[SkalpSectionBox\]-(.+)/)
          face_name = match ? match[1] : "unknown"
          pa = ent.get_plane
          norm = Geom::Vector3d.new(pa[0], pa[1], pa[2])
          # Point retrieval (stored or calculated)
          stored = ent.get_attribute(DICTIONARY_NAME, 'original_point')
          pos = stored ? Geom::Point3d.new(stored) : Geom::Point3d.new(norm.x * -pa[3], norm.y * -pa[3], norm.z * -pa[3])
          planes_data << { name: face_name, plane: ent, original_point: pos, normal: norm, parent_trans: Geom::Transformation.new }
        end
      end
      
      # Calc dynamic bounds (simplified for top-level root)
      plane_map = {}
      planes_data.each { |d| plane_map[d[:name]] = d }
      if ["top", "bottom", "right", "left", "back", "front"].all? { |k| plane_map.key?(k) }
        x_max = plane_map["right"][:original_point].x; x_min = plane_map["left"][:original_point].x
        y_max = plane_map["back"][:original_point].y;  y_min = plane_map["front"][:original_point].y
        z_max = plane_map["top"][:original_point].z;   z_min = plane_map["bottom"][:original_point].z
        bounds = {
          "top" => [[x_min, y_min, z_max], [x_max, y_min, z_max], [x_max, y_max, z_max], [x_min, y_max, z_max]],
          "bottom" => [[x_min, y_max, z_min], [x_max, y_max, z_min], [x_max, y_min, z_min], [x_min, y_min, z_min]],
          "right" => [[x_max, y_min, z_min], [x_max, y_max, z_min], [x_max, y_max, z_max], [x_max, y_min, z_max]],
          "left" => [[x_min, y_max, z_min], [x_min, y_min, z_min], [x_min, y_min, z_max], [x_min, y_max, z_max]],
          "front" => [[x_min, y_min, z_min], [x_max, y_min, z_min], [x_max, y_min, z_max], [x_min, y_min, z_max]],
          "back" => [[x_max, y_max, z_min], [x_min, y_max, z_min], [x_min, y_max, z_max], [x_max, y_max, z_max]]
        }
        planes_data.each { |d| d[:face_vertices] = bounds[d[:name]].map { |a| Geom::Point3d.new(a) } if bounds[d[:name]] }
      end
      planes_data
    end

    # Dialog Classes
    class SettingsDialog
      def initialize(default_name = "SectionBox", &block)
        @default_name = default_name
        @on_save = block
        @dialog = nil
        show
      end
      
      def show
        path = File.join(File.dirname(__FILE__), 'ui', 'settings.html')
        @dialog = UI::HtmlDialog.new({:dialog_title => "SectionBox Settings", :preferences_key => "com.skalp.sectionbox.settings", :scrollable => false, :resizable => false, :width => 350, :height => 450, :style => UI::HtmlDialog::STYLE_DIALOG})
        @dialog.set_file(path)
        @dialog.add_action_callback("ready") do 
           defaults = Skalp::BoxSection::Data.get_defaults
           scales = Skalp::BoxSection::Data.get_scales
           @dialog.execute_script("initScales(#{scales.to_json})")
           @dialog.execute_script("loadDefaults(#{defaults.to_json})")
           @dialog.execute_script("setName('#{@default_name}')")
        end
        @dialog.add_action_callback("save") { |d, json| save(json) }
        @dialog.add_action_callback("save_default") do |d, data| 
          parsed = data.is_a?(String) ? JSON.parse(data) : data
          Skalp::BoxSection::Data.save_defaults(parsed) if parsed.is_a?(Hash)
        end
        @dialog.add_action_callback("save_scales") do |d, data| 
          parsed = data.is_a?(String) ? JSON.parse(data) : data
          Skalp::BoxSection::Data.save_scales(parsed) if parsed.is_a?(Array)
        end
        @dialog.add_action_callback("close") { close }
        @dialog.center
        @dialog.show
      end
      
      def save(json_data)
        data = JSON.parse(json_data)
        # Construct the settings hash matching the new UI structure
        settings = {
          "name" => data['name'],
          "scale" => "1/#{data['scale']}",
          "rear_view_global" => data['rear_view_global'],
          "sides_all_same" => data['sides_all_same'],
          "sides" => data['sides'] # Hash of side settings (or single 'all' key if same)
        }
        # Backward compatibility / flattening for simple access if needed (optional)
        settings["style_rule"] = data['sides']['all']['style_rule'] if data['sides_all_same']
        
        @on_save.call(settings) if @on_save
        close
      end
      
      def close; @dialog.close if @dialog; @dialog = nil; end
    end

    # Dialog Manager
    class Manager
      def initialize; @dialog = nil; end
      def show
        if @dialog && @dialog.visible?; @dialog.bring_to_front; return; end
        path = File.join(File.dirname(__FILE__), 'ui', 'manager.html')
        @dialog = UI::HtmlDialog.new({:dialog_title => "Skalp SectionBox Manager", :preferences_key => "com.skalp.sectionbox.manager", :scrollable => false, :resizable => true, :width => 300, :height => 500, :style => UI::HtmlDialog::STYLE_DIALOG})
        @dialog.set_file(path)
        @dialog.add_action_callback("ready") { |d, p| sync_data }
        @dialog.add_action_callback("sync") { |d, p| sync_data }
        @dialog.add_action_callback("close") { |d, p| @dialog.close }
        @dialog.add_action_callback("resize_window") { |d, json| dim = JSON.parse(json); @dialog.set_size(dim['width'], dim['height']) }
        @dialog.add_action_callback("activate") { |d, id| Engine.activate(id) }
        @dialog.add_action_callback("modify") { |d, id| Engine.modify(id) }
        @dialog.add_action_callback("add_box") { |d, p| Engine.create_from_model_bounds }
        @dialog.add_action_callback("add_folder") { |d, parent_id| Engine.create_folder(parent_id.empty? ? nil : parent_id) }
        @dialog.add_action_callback("move_item") { |d, json| data = JSON.parse(json); Engine.move_item(data['source'], data['target'].empty? ? nil : data['target']) }
        @dialog.add_action_callback("toggle_folder") { |d, folder_id| Engine.toggle_folder(folder_id) }
        @dialog.add_action_callback("rename_folder") { |d, folder_id| Engine.rename_folder(folder_id) }
        @dialog.add_action_callback("explode_folder") { |d, folder_id| Engine.explode_folder(folder_id) }
        @dialog.add_action_callback("expand_all") { |d, p| Engine.expand_all }
        @dialog.add_action_callback("collaps_all") { |d, p| Engine.collapse_all }
        @dialog.set_on_closed { @dialog = nil }
        @dialog.show
      end
      def sync_data
        return unless @dialog && @dialog.visible?
        model = Sketchup.active_model; data = { :boxes => Data.get_config(model), :hierarchy => Data.get_hierarchy(model), :active_id => Engine.active_box_id }
        @dialog.execute_script("updateData(#{data.to_json})")
      end
      def close
        @dialog.close if @dialog
        @dialog = nil
      end
      def visible?
        @dialog && @dialog.visible?
      rescue
        false
      end
    end

    # Core Engine
    module Engine
      @@active_box_id = nil; @@manager = nil; @@observers_active = false; @@model_observer = nil; @@selection_observer = nil; @@original_render_settings = {}
      def self.active_box_id; @@active_box_id; end
      def self.manager; @@manager; end
      def self.run; @@manager ||= Manager.new; @@manager.show; start_observers; end
      def self.stop; @@manager.close if @@manager; stop_observers; deactivate_current if @@active_box_id; end
      def self.start_observers
        return if @@observers_active
        model = Sketchup.active_model; @@model_observer ||= SectionBoxModelObserver.new; @@selection_observer ||= SectionBoxSelectionObserver.new
        model.add_observer(@@model_observer); model.selection.add_observer(@@selection_observer); @@observers_active = true
      end
      def self.stop_observers
        return unless @@observers_active
        model = Sketchup.active_model; model.remove_observer(@@model_observer) if @@model_observer; model.selection.remove_observer(@@selection_observer) if @@selection_observer; @@observers_active = false
      end

      def self.create_from_model_bounds
        SettingsDialog.new("SectionBox##{Data.get_config(Sketchup.active_model).length + 1}") do |settings|
          do_create_from_model_bounds(settings)
        end
      end

      def self.do_create_from_model_bounds(settings)
        model = Sketchup.active_model
        
        # Get bounding box of all model entities (excluding any existing SectionBox groups)
        bbox = Geom::BoundingBox.new
        model.entities.each do |ent|
          next if ent.get_attribute(DICTIONARY_NAME, 'box_id')
          bbox.add(ent.bounds) if ent.respond_to?(:bounds)
        end
        
        if bbox.empty?
          UI.messagebox("Model appears to be empty. Cannot create SectionBox.")
          return
        end
        
        # Calculate the 6 planes from the bounding box
        min = bbox.min
        max = bbox.max
        
        planes_config = [
          { "name" => "top",    "point" => [0, 0, max.z.to_f], "normal" => [0, 0, 1] },
          { "name" => "bottom", "point" => [0, 0, min.z.to_f], "normal" => [0, 0, -1] },
          { "name" => "right",  "point" => [max.x.to_f, 0, 0], "normal" => [1, 0, 0] },
          { "name" => "left",   "point" => [min.x.to_f, 0, 0], "normal" => [-1, 0, 0] },
          { "name" => "back",   "point" => [0, max.y.to_f, 0], "normal" => [0, 1, 0] },
          { "name" => "front",  "point" => [0, min.y.to_f, 0], "normal" => [0, -1, 0] }
        ]
        
        # Create the SectionBox configuration
        id = "box_" + Time.now.to_i.to_s
        config = Data.get_config(model)
        
        # Merge defaults with user settings
        box_config = Data.get_defaults.merge(settings)
        box_config.merge!({
          "name" => settings["name"],
          "planes" => planes_config,
          "created_at" => Time.now.to_s
        })
        
        config[id] = box_config
        Data.save_config(model, config)
        
        # Add to hierarchy
        hierarchy = Data.get_hierarchy(model)
        hierarchy << { "id" => id, "type" => "item" }
        Data.save_hierarchy(model, hierarchy)
        
        # Update UI and activate
        @@manager.sync_data if @@manager && @@manager.visible?
        activate(id)
        
        # Immediately start modify mode
        modify(id)
      end
      
      def self.create_from_selection
        model = Sketchup.active_model
        selection = model.selection
        group = selection.to_a.find { |e| Skalp::BoxSection.is_valid_box_group?(e) }
        
        unless group
          UI.messagebox("Please select a group with exactly 6 parallel faces.")
          return
        end
        
        SettingsDialog.new("SectionBox##{Data.get_config(model).length + 1}") do |settings|
           do_create_from_selection(group, settings)
        end
      end

      def self.do_create_from_selection(group, settings)
        return unless group.valid? 
        model = Sketchup.active_model
        
        faces = group.entities.grep(Sketchup::Face)
        trans = group.transformation
        planes_config = []
        
        faces.each do |f|
          local_normal = f.normal
          world_normal = local_normal.transform(trans)
          world_point = f.bounds.center.transform(trans)
          cnt = group.bounds.center.transform(trans)
          world_normal.reverse! if world_normal.dot(cnt - world_point) < 0
          planes_config << {
            "name" => Skalp::BoxSection.get_face_name(local_normal),
            "point" => world_point.to_a,
            "normal" => world_normal.to_a
          }
        end
        
        id = "box_" + Time.now.to_i.to_s
        config = Data.get_config(model)
        
        # Merge defaults with user settings
        box_config = Data.get_defaults.merge(settings)
        box_config.merge!({
          "name" => settings["name"],
          "planes" => planes_config,
          "created_at" => Time.now.to_s
        })
        
        config[id] = box_config
        Data.save_config(model, config)
        
        hierarchy = Data.get_hierarchy(model)
        hierarchy << { "id" => id, "type" => "item" }
        Data.save_hierarchy(model, hierarchy)
        
        group.erase!
        @@manager.sync_data if @@manager && @@manager.visible?
        activate(id)
      end

      def self.activate(id)
        deactivate_current if @@active_box_id
        model = Sketchup.active_model; config = Data.get_config(model); box_data = config[id]; return unless box_data
        model.start_operation('Activate SectionBox', true)
        begin
          @@active_box_id = id
          root = model.entities.add_group; root.name = "[SkalpSectionBox]"; root.set_attribute(DICTIONARY_NAME, 'box_id', id)
          all_ents = model.entities.to_a.reject { |e| e == root || e.attribute_dictionary('Skalp') }
          model_group = root.entities.add_group(all_ents); model_group.name = "[SkalpSectionBox-Model]"
          box_data["planes"].each do |pd|
            pt = Geom::Point3d.new(pd["point"]); norm = Geom::Vector3d.new(pd["normal"])
            sp = root.entities.add_section_plane([pt, norm]); sp.name = "[SkalpSectionBox]-#{pd['name']}"
            sp.set_attribute(DICTIONARY_NAME, 'original_point', pt.to_a)
          end
          model.commit_operation; @@manager.sync_data if @@manager && @@manager.visible?
        rescue => e
          model.abort_operation; puts "Activation Error: #{e.message}"
        end
      end

      def self.deactivate_current
        return unless @@active_box_id
        model = Sketchup.active_model; root = model.entities.find { |e| e.get_attribute(DICTIONARY_NAME, 'box_id') == @@active_box_id }
        if root && root.valid?
          model.start_operation('Deactivate SectionBox', true)
          model_group = root.entities.find { |e| e.name == "[SkalpSectionBox-Model]" }; model_group.explode if model_group && model_group.valid?
          root.erase!
          model.commit_operation
        end
        @@active_box_id = nil; @@manager.sync_data if @@manager && @@manager.visible?
      end

      def self.modify(id)
        activate(id) unless @@active_box_id == id
        Sketchup.active_model.select_tool(Skalp::BoxSectionAdjustTool.new)
      end

      def self.on_enter_box_context(model)
        opts = model.rendering_options; @@original_render_settings = { 'FadeInactive' => opts['FadeInactive'], 'HideContext' => opts['HideContext'] }
        opts['FadeInactive'] = true; opts['HideContext'] = false
      end

      def self.on_exit_box_context(model)
        opts = model.rendering_options; @@original_render_settings.each { |k, v| opts[k] = v }; @@original_render_settings = {}
      end
      
      def self.create_folder(parent_id = nil)
        model = Sketchup.active_model
        hierarchy = Data.get_hierarchy(model)
        
        # Determine where to add
        target_list = hierarchy
        if parent_id
          find_list = lambda do |items|
            items.each do |item|
               if item["id"] == parent_id && item["type"] == "folder"
                 item["children"] ||= []
                 return item["children"]
               elsif item["children"]
                 found = find_list.call(item["children"])
                 return found if found
               end
            end
            nil
          end
          found_list = find_list.call(hierarchy)
          target_list = found_list if found_list
        end

        # Generate unique name
        base_name = "New Folder"
        name = base_name
        counter = 1
        
        name_exists = lambda do |n, list|
          list.any? { |i| i["type"] == "folder" && i["name"] == n }
        end
        
        while name_exists.call(name, target_list)
          name = "#{base_name} (#{counter})"
          counter += 1
        end
        
        # Create
        target_list << { "id" => "folder_#{Time.now.to_i}", "type" => "folder", "name" => name, "open" => true, "children" => [] }
        Data.save_hierarchy(model, hierarchy)
        
        @@manager.sync_data if @@manager && @@manager.visible?
      end
      
      def self.move_item(source_id, target_id)
        model = Sketchup.active_model
        hierarchy = Data.get_hierarchy(model)
        
        # 1. Find and remove source item
        source_item = nil
        remove_recursive = lambda do |items|
          items.each_with_index do |item, index|
            if item["id"] == source_id
              source_item = items.delete_at(index)
              return true
            elsif item["children"]
              return true if remove_recursive.call(item["children"])
            end
          end
          false
        end
        
        return unless remove_recursive.call(hierarchy)
        
        # 2. Find target folder (if target_id is valid folder) or add to root (if nil or not found)
        target_added = false
        if target_id
           add_recursive = lambda do |items|
             items.each do |item|
               if item["id"] == target_id && item["type"] == "folder"
                 item["children"] ||= []
                 item["children"] << source_item
                 item["open"] = true # Open target folder
                 return true
               elsif item["children"]
                 return true if add_recursive.call(item["children"])
               end
             end
             false
           end
           target_added = add_recursive.call(hierarchy)
        end
        
        # If target not found or nil, add back to root
        hierarchy << source_item unless target_added
        
        Data.save_hierarchy(model, hierarchy)
        @@manager.sync_data if @@manager && @@manager.visible?
      end

      def self.toggle_folder(folder_id)
        model = Sketchup.active_model
        hierarchy = Data.get_hierarchy(model)
        
        toggle_recursive = lambda do |items|
          items.each do |item|
            if item["type"] == "folder" && item["id"] == folder_id
              item["open"] = !item["open"]
              return true
            elsif item["children"]
              return true if toggle_recursive.call(item["children"])
            end
          end
          false
        end
        
        toggle_recursive.call(hierarchy)
        Data.save_hierarchy(model, hierarchy)
        @@manager.sync_data if @@manager && @@manager.visible?
      end
      
      def self.rename_folder(folder_id)
        model = Sketchup.active_model
        hierarchy = Data.get_hierarchy(model)
        
        # Find the folder
        current_name = nil
        find_folder = lambda do |items|
          items.each do |item|
            if item["type"] == "folder" && item["id"] == folder_id
              current_name = item["name"]
              return
            elsif item["children"]
              find_folder.call(item["children"])
            end
          end
        end
        
        find_folder.call(hierarchy)
        return unless current_name
        
        result = UI.inputbox(['Folder Name:'], [current_name], 'Rename Folder')
        return unless result
        
        new_name = result[0].strip
        return if new_name.empty?
        
        # Update the folder name
        rename_recursive = lambda do |items|
          items.each do |item|
            if item["type"] == "folder" && item["id"] == folder_id
              item["name"] = new_name
              return true
            elsif item["children"]
              return true if rename_recursive.call(item["children"])
            end
          end
          false
        end
        
        rename_recursive.call(hierarchy)
        Data.save_hierarchy(model, hierarchy)
        @@manager.sync_data if @@manager && @@manager.visible?
      end
      
      def self.explode_folder(folder_id)
        model = Sketchup.active_model
        hierarchy = Data.get_hierarchy(model)
        
        # Find and remove folder, move children to parent level
        explode_recursive = lambda do |items, parent|
          items.each_with_index do |item, index|
            if item["type"] == "folder" && item["id"] == folder_id
              children = item["children"] || []
              items.delete_at(index)
              children.reverse.each { |child| items.insert(index, child) }
              return true
            elsif item["children"]
              return true if explode_recursive.call(item["children"], items)
            end
          end
          false
        end
        
        explode_recursive.call(hierarchy, nil)
        Data.save_hierarchy(model, hierarchy)
        @@manager.sync_data if @@manager && @@manager.visible?
      end
      
      def self.expand_all
        model = Sketchup.active_model
        hierarchy = Data.get_hierarchy(model)
        
        expand_recursive = lambda do |items|
          items.each do |item|
            if item["type"] == "folder"
              item["open"] = true
              expand_recursive.call(item["children"]) if item["children"]
            end
          end
        end
        
        expand_recursive.call(hierarchy)
        Data.save_hierarchy(model, hierarchy)
        @@manager.sync_data if @@manager && @@manager.visible?
      end
      
      def self.collapse_all
        model = Sketchup.active_model
        hierarchy = Data.get_hierarchy(model)
        
        collapse_recursive = lambda do |items|
          items.each do |item|
            if item["type"] == "folder"
              item["open"] = false
              collapse_recursive.call(item["children"]) if item["children"]
            end
          end
        end
        
        collapse_recursive.call(hierarchy)
        Data.save_hierarchy(model, hierarchy)
        @@manager.sync_data if @@manager && @@manager.visible?
      end
    end

    def self.get_face_name(normal)
        if normal.parallel?(Geom::Vector3d.new(0,0,1)) then normal.z > 0 ? "top" : "bottom"
        elsif normal.parallel?(Geom::Vector3d.new(1,0,0)) then normal.x > 0 ? "right" : "left"
        elsif normal.parallel?(Geom::Vector3d.new(0,1,0)) then normal.y > 0 ? "back" : "front"
        else "face"
        end
    end

    def self.is_valid_box_group?(ent)
      return false unless ent.is_a?(Sketchup::Group)
      faces = ent.entities.grep(Sketchup::Face); return false if faces.length != 6
      normals = faces.map { |f| n = f.normal; (n.x.abs > 0.001) ? (n.x > 0 ? n : n.reverse) : (n.y.abs > 0.001) ? (n.y > 0 ? n : n.reverse) : (n.z > 0 ? n : n.reverse) }
      unique_dirs = []; normals.each { |n| unique_dirs << n unless unique_dirs.any? { |un| un.parallel?(n) } }
      unique_dirs.length == 3
    end

    # OBSERVERS
    class SectionBoxModelObserver < Sketchup::ModelObserver
      def onActivePathChanged(model)
        path = model.active_path || []; in_box = path.any? { |e| e.name == "[SkalpSectionBox-Model]" }
        if in_box && !@in_context then Engine.on_enter_box_context(model); @in_context = true
        elsif !in_box && @in_context then Engine.on_exit_box_context(model); @in_context = false
        end
      end
    end

    class SectionBoxSelectionObserver < Sketchup::SelectionObserver
       def onSelectionBulkChange(selection); end
    end

    def self.set_overlay_visibility(visible); end # Legacy stub

    def self.reload
      load __FILE__
      load File.join(File.dirname(__FILE__), 'Skalp_box_section_tool.rb')
      puts "✓ Skalp SectionBox System reloaded!"
    end

    # UI Initialization
    unless defined?(@@ui_loaded)
      toolbar = UI::Toolbar.new('Skalp SectionBox')
      cmd_engine = UI::Command.new('SectionBox Manager') { (Engine.manager && Engine.manager.visible?) ? Engine.stop : Engine.run }
      cmd_engine.small_icon = cmd_engine.large_icon = File.join(File.dirname(__FILE__), 'icons', 'box_section', 'icon_box_section_create.svg')
      cmd_engine.tooltip = 'Toggle SectionBox Manager'
      cmd_engine.set_validation_proc { (Engine.manager && Engine.manager.visible?) ? MF_CHECKED : MF_UNCHECKED }
      toolbar.add_item(cmd_engine)
      
      # Temporary reload button for development
      cmd_reload = UI::Command.new('Reload SectionBox') { reload }
      cmd_reload.small_icon = cmd_reload.large_icon = File.join(File.dirname(__FILE__), 'icons', 'box_section', 'icon_reload.svg')
      cmd_reload.tooltip = 'Reload SectionBox (Dev)'
      toolbar.add_item(cmd_reload)
      
      toolbar.show

      UI.add_context_menu_handler do |menu|
        selection = Sketchup.active_model.selection
        if selection.length == 1
          ent = selection.first
          if ent.is_a?(Sketchup::Group)
            if ent.get_attribute(DICTIONARY_NAME, 'box_id') == Engine.active_box_id
              menu.add_item("Deactivate SectionBox") { Engine.deactivate_current }
            elsif is_valid_box_group?(ent)
              menu.add_item("Create Skalp SectionBox") { Engine.create_from_selection }
            else
              menu.add_item("Create Skalp SectionBox (no valid group)") {}.set_validation_proc { MF_GRAYED }
            end
          elsif ent.is_a?(Sketchup::ComponentInstance)
            menu.add_item("Create Skalp SectionBox (no valid group)") {}.set_validation_proc { MF_GRAYED }
          end
        end
      end
      @@ui_loaded = true
    end
  end
end
