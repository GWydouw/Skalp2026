require 'sketchup.rb'
require 'json'

module Skalp
  module BoxSection
    DICTIONARY_NAME = 'Skalp_BoxSection' unless defined?(DICTIONARY_NAME)
    ATTR_IS_BOX_SECTION = 'is_box_section' unless defined?(ATTR_IS_BOX_SECTION)

    # Persistence Layer
    module Data
      DICTIONARY = 'Skalp_BoxSection_Data' unless defined?(DICTIONARY)
      
      def self.get_config(model)
        val = model.get_attribute(DICTIONARY, 'config', '{}')
        return val if val.is_a?(Hash) # Mac auto-eval
        begin
          JSON.parse(val)
        rescue
          {}
        end
      end

      def self.save_config(model, config)
        model.set_attribute(DICTIONARY, 'config', config.to_json)
      end

      def self.get_hierarchy(model)
        val = model.get_attribute(DICTIONARY, 'hierarchy', '[]')
        return val if val.is_a?(Array) # Mac auto-eval
        begin
          JSON.parse(val)
        rescue
          []
        end
      end

      def self.save_hierarchy(model, hierarchy)
        model.set_attribute(DICTIONARY, 'hierarchy', hierarchy.to_json)
      end
      
      def self.safe_read_default(key, default_val = nil)
        begin
          val = Sketchup.read_default("Skalp", key, default_val)
          return val if val.is_a?(Array) || val.is_a?(Hash)
          if val.is_a?(String)
            begin
              # Handle both pure JSON strings (Windows) and potential SB_JSON prefix
              json_str = val.start_with?("SB_JSON:") ? val[8..-1] : val
              return JSON.parse(json_str)
            rescue
              return val # Plain string
            end
          end
          val
        rescue Exception
          default_val
        end
      end

      def self.get_defaults
        defaults = {
          "scale" => "1/50",
          "sides_all_same" => true,
          "rear_view_global" => "off",
          "rear_view_projection" => "off",
          "section_cut_width" => true,
          "style_rule" => "combined",
          "sides" => { "all" => { "cut_width" => true, "style_rule" => "combined", "rear_view" => "off" } }
        }
        saved = safe_read_default("SectionBoxDefaults_v6")
        defaults.merge!(saved) if saved.is_a?(Hash)
        defaults
      end

      def self.save_defaults(settings)
        data = {
          "scale" => settings["scale"],
          "sides_all_same" => settings["sides_all_same"],
          "rear_view_global" => settings["rear_view_global"],
          "sides" => settings["sides"]
        }
        Sketchup.write_default("Skalp", "SectionBoxDefaults_v6", data)
      end

      def self.get_scales
        default_scales = [
          "1:1", "1:2", "1:5", "1:10", "1:20", "1:50", "1:100", "1:200", "1:500", "1:1000",
          "1\" = 1' (1:12)", "1/8\" = 1' (1:96)", "1/4\" = 1' (1:48)", "1/2\" = 1' (1:24)",
          "3/4\" = 1' (1:16)", "3\" = 1' (1:4)"
        ]
        saved = safe_read_default("SectionBoxScales_v6")
        return saved if saved.is_a?(Array)
        default_scales
      end

      def self.save_scales(scales_array)
        Sketchup.write_default("Skalp", "SectionBoxScales_v6", scales_array)
      end
    end

    # Shared drawing utilities
    module DrawHelper
      def self.get_color(face_name)
        case face_name
        when "top", "bottom" then Sketchup::Color.new(0, 0, 255) # Blue (Z)
        when "left", "right" then Sketchup::Color.new(255, 0, 0) # Red (X)
        when "front", "back" then Sketchup::Color.new(0, 255, 0) # Green (Y)
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
        # 10% transparent = alpha 25
        view.drawing_color = Sketchup::Color.new(color.red, color.green, color.blue, 25)
        view.draw(GL_POLYGON, face_vertices)
      end

      def self.draw_plus(view, center, normal, face_name, highlighted, arm_size = 15.0, color_override = nil)
        arm = arm_size
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
      
      trans = root.transformation
      planes_data = []
      root.entities.each do |ent|
        if ent.is_a?(Sketchup::SectionPlane)
          match = ent.name.match(/\[SkalpSectionBox\]-(.+)/)
          face_name = match ? match[1] : "unknown"
          pa = ent.get_plane
          
          # Local to World
          local_norm = Geom::Vector3d.new(pa[0], pa[1], pa[2])
          world_norm = local_norm.transform(trans)
          
          stored = ent.get_attribute(DICTIONARY_NAME, 'original_point')
          local_pos = stored ? Geom::Point3d.new(stored) : Geom::Point3d.new(local_norm.x * -pa[3], local_norm.y * -pa[3], local_norm.z * -pa[3])
          world_pos = trans * local_pos
          
          planes_data << { name: face_name, plane: ent, original_point: world_pos, normal: world_norm, parent_trans: trans, local_point: local_pos }
        end
      end
      
      # Calc dynamic bounds in WORLD space
      plane_map = {}
      planes_data.each { |d| plane_map[d[:name]] = d }
      if ["top", "bottom", "right", "left", "back", "front"].all? { |k| plane_map.key?(k) }
        # Need to be careful with world bounds if box is rotated.
        # It's better to calculate local bounds and transform them.
        local_pts = {
          "x_max" => plane_map["right"][:local_point].x, "x_min" => plane_map["left"][:local_point].x,
          "y_max" => plane_map["back"][:local_point].y,  "y_min" => plane_map["front"][:local_point].y,
          "z_max" => plane_map["top"][:local_point].z,   "z_min" => plane_map["bottom"][:local_point].z
        }
        
        lp = local_pts
        local_bounds = {
          "top" => [[lp["x_min"], lp["y_min"], lp["z_max"]], [lp["x_max"], lp["y_min"], lp["z_max"]], [lp["x_max"], lp["y_max"], lp["z_max"]], [lp["x_min"], lp["y_max"], lp["z_max"]]],
          "bottom" => [[lp["x_min"], lp["y_max"], lp["z_min"]], [lp["x_max"], lp["y_max"], lp["z_min"]], [lp["x_max"], lp["y_min"], lp["z_min"]], [lp["x_min"], lp["y_min"], lp["z_min"]]],
          "right" => [[lp["x_max"], lp["y_min"], lp["z_min"]], [lp["x_max"], lp["y_max"], lp["z_min"]], [lp["x_max"], lp["y_max"], lp["z_max"]], [lp["x_max"], lp["y_min"], lp["z_max"]]],
          "left" => [[lp["x_min"], lp["y_max"], lp["z_min"]], [lp["x_min"], lp["y_min"], lp["z_min"]], [lp["x_min"], lp["y_min"], lp["z_max"]], [lp["x_min"], lp["y_max"], lp["z_max"]]],
          "front" => [[lp["x_min"], lp["y_min"], lp["z_min"]], [lp["x_max"], lp["y_min"], lp["z_min"]], [lp["x_max"], lp["y_min"], lp["z_max"]], [lp["x_min"], lp["y_min"], lp["z_max"]]],
          "back" => [[lp["x_max"], lp["y_max"], lp["z_min"]], [lp["x_min"], lp["y_max"], lp["z_min"]], [lp["x_min"], lp["y_max"], lp["z_max"]], [lp["x_max"], lp["y_max"] , lp["z_max"]]]
        }
        
        # Calculate scale factor for grips (e.g. 5% of largest dimension, min 10", max 100")
        dims = [lp["x_max"] - lp["x_min"], lp["y_max"] - lp["y_min"], lp["z_max"] - lp["z_min"]]
        max_dim = dims.max
        arm_size = (max_dim * 0.05).clamp(10, 100)
        
        planes_data.each do |d|
          d[:arm_size] = arm_size
          if local_bounds[d[:name]]
            d[:face_vertices] = local_bounds[d[:name]].map { |a| trans * Geom::Point3d.new(a) }
          end
        end
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
        @dialog.set_file(path)
        @dialog.add_action_callback("ready") do 
           defaults = Data.get_defaults
           scales = Data.get_scales
           @dialog.execute_script("initScales(#{scales.to_json})")
           # If editing existing, @default_name is actually the settings hash or we pass it differently?
           # Actually, let's keep it simple: if @default_name is a Hash, use it as settings
           if @default_name.is_a?(Hash)
             @dialog.execute_script("loadDefaults(#{@default_name.to_json})")
             @dialog.execute_script("setName(#{@default_name['name'].to_json})") if @default_name['name']
             @dialog.execute_script("setSubmitText('Save')")
           else
             @dialog.execute_script("loadDefaults(#{defaults.to_json})")
             @dialog.execute_script("setName(#{@default_name.to_json})")
             @dialog.execute_script("setSubmitText('Create')")
           end
        end
        @dialog.add_action_callback("save") { |d, json| save(json) }
        @dialog.add_action_callback("save_default") { |d, data| Data.save_defaults(data.is_a?(String) ? JSON.parse(data) : data) }
        @dialog.add_action_callback("save_scales") { |d, data| Data.save_scales(data.is_a?(String) ? JSON.parse(data) : data) }
        @dialog.add_action_callback("open_scale_manager") { |d, p| ScaleManager.new }
        @dialog.add_action_callback("close") { close }
        @dialog.center
        @dialog.show
      end
      
      def save(json)
        data = json.is_a?(String) ? JSON.parse(json) : json
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

    # Scale Manager Dialog
    class ScaleManager
      def initialize
        @dialog = nil
        show
      end
      
      def show
        if @dialog && @dialog.visible?; @dialog.bring_to_front; return; end
        path = File.join(File.dirname(__FILE__), 'ui', 'scale_manager.html')
        @dialog = UI::HtmlDialog.new({:dialog_title => "Drawing Scale Manager", :preferences_key => "com.skalp.sectionbox.scale_manager", :scrollable => false, :resizable => true, :width => 400, :height => 500, :style => UI::HtmlDialog::STYLE_DIALOG})
        @dialog.set_file(path)
        @dialog.add_action_callback("ready") do
          scales = Data.get_scales
          @dialog.execute_script("loadScales(#{scales.to_json})")
        end
        @dialog.add_action_callback("save_scales") do |d, data|
          scales_array = data.is_a?(String) ? JSON.parse(data) : data
          Data.save_scales(scales_array)
        end
        @dialog.add_action_callback("restore_defaults") do
          default_scales = [
            "1:1", "1:2", "1:5", "1:10", "1:20", "1:50", "1:100", "1:200", "1:500", "1:1000",
            "1\" = 1' (1:12)", "1/8\" = 1' (1:96)", "1/4\" = 1' (1:48)", "1/2\" = 1' (1:24)",
            "3/4\" = 1' (1:16)", "3\" = 1' (1:4)"
          ]
          Data.save_scales(default_scales)
          @dialog.execute_script("loadScales(#{default_scales.to_json})")
        end
        @dialog.set_on_closed { @dialog = nil }
        @dialog.center
        @dialog.show
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
        @dialog.add_action_callback("resize_window") { |d, data| dim = data.is_a?(String) ? JSON.parse(data) : data; @dialog.set_size(dim['width'], dim['height']) }
        @dialog.add_action_callback("activate") { |d, id| Engine.activate(id) }
        @dialog.add_action_callback("modify") { |d, id| Engine.modify(id) }
        @dialog.add_action_callback("add_box") { |d, p| Engine.create_from_model_bounds }
        @dialog.add_action_callback("add_folder") { |d, parent_id| Engine.create_folder(parent_id.empty? ? nil : parent_id) }
        @dialog.add_action_callback("move_item") { |d, data| move_data = data.is_a?(String) ? JSON.parse(data) : data; Engine.move_item(move_data['source'], move_data['target'].empty? ? nil : move_data['target']) }
        @dialog.add_action_callback("toggle_folder") { |d, folder_id| Engine.toggle_folder(folder_id) }
        @dialog.add_action_callback("rename_folder") { |d, folder_id| Engine.rename_folder(folder_id) }
        @dialog.add_action_callback("explode_folder") { |d, folder_id| Engine.explode_folder(folder_id) }
        @dialog.add_action_callback("expand_all") { |d, p| Engine.expand_all }
        @dialog.add_action_callback("collaps_all") { |d, p| Engine.collapse_all }
        
        # Context Menu Callbacks
        @dialog.add_action_callback("edit") { |d, id| Engine.edit(id) }
        @dialog.add_action_callback("rename") { |d, id| Engine.rename(id) }
        @dialog.add_action_callback("delete") { |d, id| Engine.delete(id) }
        @dialog.add_action_callback("open_scale_manager") { |d, p| ScaleManager.new }
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
        
        cx = (min.x + max.x) / 2.0
        cy = (min.y + max.y) / 2.0
        cz = (min.z + max.z) / 2.0
        
        min_x = min.x.to_f
        max_x = max.x.to_f
        min_y = min.y.to_f
        max_y = max.y.to_f
        min_z = min.z.to_f
        max_z = max.z.to_f
        
        planes_config = []
        planes_config << { "name" => "top",    "point" => [cx, cy, max_z], "normal" => [0, 0, -1] }
        planes_config << { "name" => "bottom", "point" => [cx, cy, min_z], "normal" => [0, 0, 1] }
        planes_config << { "name" => "right",  "point" => [max_x, cy, cz], "normal" => [-1, 0, 0] }
        planes_config << { "name" => "left",   "point" => [min_x, cy, cz], "normal" => [1, 0, 0] }
        planes_config << { "name" => "front",  "point" => [cx, min_y, cz], "normal" => [0, 1, 0] }
        planes_config << { "name" => "back",   "point" => [cx, max_y, cz], "normal" => [0, -1, 0] }
        
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
          world_normal.reverse! if world_normal.dot(cnt - world_point) > 0 # Point OUTWARDS
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
      
      def self.rename(id)
        model = Sketchup.active_model
        config = Data.get_config(model)
        box = config[id]
        return unless box
        
        result = UI.inputbox(['Name:'], [box['name']], 'Rename SectionBox')
        return unless result
        new_name = result[0].strip
        return if new_name.empty?
        
        box['name'] = new_name
        config[id] = box
        Data.save_config(model, config)
        
        @@manager.sync_data if @@manager && @@manager.visible?
        # If active, might need to update scene/group name? For now just UI.
        if @@active_box_id == id
             # Update status text in UI will happen via sync_data
        end
      end
      
      def self.delete(id)
        return unless UI.messagebox("Are you sure you want to delete this SectionBox?", MB_YESNO) == IDYES
        
        if @@active_box_id == id
          deactivate_current
        end
        
        model = Sketchup.active_model
        config = Data.get_config(model)
        config.delete(id)
        Data.save_config(model, config)
        
        # Remove from hierarchy
        hierarchy = Data.get_hierarchy(model)
        
        delete_recursive = lambda do |items|
          items.each_with_index do |item, index|
            if item["id"] == id
              items.delete_at(index)
              return true
            elsif item["children"]
              return true if delete_recursive.call(item["children"])
            end
          end
          false
        end
        delete_recursive.call(hierarchy)
        Data.save_hierarchy(model, hierarchy)
        
        @@manager.sync_data if @@manager && @@manager.visible?
      end
      
      def self.edit(id)
        model = Sketchup.active_model
        config = Data.get_config(model)
        box = config[id]
        return unless box
        
        # Prepare settings for dialog
        # SettingsDialog expects: name, scale (denominator), sides_all_same, rear_view_global, sides
        # Our stored 'scale' is "1/50", dialog wants 50
        scale_val = parse_scale(box['scale'])
        
        settings_payload = {
          "name" => box['name'],
          "scale" => scale_val,
          "sides_all_same" => box['sides_all_same'],
          "rear_view_global" => box['rear_view_global'],
          "sides" => box['sides']
        }
        
        SettingsDialog.new(settings_payload) do |new_settings|
           do_update(id, new_settings)
        end
      end
      
      def self.parse_scale(scale_str)
        return 50 unless scale_str
        parts = scale_str.split('/')
        return parts.last.to_f if parts.length == 2
        parts = scale_str.split(':')
        return parts.last.to_f if parts.length == 2
        50
      end
      
      def self.do_update(id, settings)
        model = Sketchup.active_model
        config = Data.get_config(model)
        box = config[id]
        return unless box
        
        # Merge new settings
        box.merge!(settings)
        
        # If scale changed, might need logic to update things?
        # For now just saving config.
        # Note: If dimensions/planes need to change, that's complex (re-generation).
        # SettingsDialog only changes styling/properties, not geometry (except maybe rear view projection).
        
        config[id] = box
        Data.save_config(model, config)
        @@manager.sync_data if @@manager && @@manager.visible?
        
        # If active, maybe refresh?
        if @@active_box_id == id
           # Re-activate to apply new styles/rear-view settings?
           # Optimization: Only if specific things changed. For robustness: simple reactivate.
           activate(id)
        end
      end

      def self.activate(id)
        deactivate_current if @@active_box_id
        model = Sketchup.active_model; config = Data.get_config(model); box_data = config[id]; return unless box_data
        model.start_operation('Activate SectionBox', true)
        begin
          @@active_box_id = id
          # 1. Group model geometry first
          all_ents = model.entities.to_a.reject { |e| e.attribute_dictionary('Skalp_BoxSection') || e.attribute_dictionary('Skalp') }
          current_container = model.entities.add_group(all_ents)
          if current_container.nil?
            # Fallback for empty models/selections
            current_container = model.entities.add_group
          end
          current_container.name = "[SkalpSectionBox-Model]"
          
          # 2. Recursive nesting: each level gets one SectionPlane
          box_data["planes"].each_with_index do |pd, i|
            # Create plane at root first to ensure world-space accuracy
            pt = Geom::Point3d.new(pd["point"])
            norm = Geom::Vector3d.new(pd["normal"])
            sp = model.entities.add_section_plane([pt, norm])
            sp.name = "[SkalpSectionBox]-#{pd['name']}"
            sp.set_attribute(DICTIONARY_NAME, 'original_point', pt.to_a)
            
            # Wrap Plane + current container into a new group
            wrapper = model.entities.add_group([sp, current_container])
            
            # Naming convention: 
            # Outermost: [SkalpSectionBox]
            # Intermediates: [SkalpSectionBox]-Side
            if i == box_data["planes"].length - 1
              wrapper.name = "[SkalpSectionBox]"
              wrapper.set_attribute(DICTIONARY_NAME, 'box_id', id)
            else
              wrapper.name = "[SkalpSectionBox]-#{pd['name'].capitalize}"
            end
            current_container = wrapper
          end
          
          model.commit_operation
          @@manager.sync_data if @@manager && @@manager.visible?
        rescue => e
          model.abort_operation
          puts "Activation Error: #{e.message}\n#{e.backtrace.join("\n")}"
        end
      end

      def self.explode_recursive(group)
        return unless group && group.valid? && group.is_a?(Sketchup::Group)
        
        # Erase Skalp SectionPlanes in this group context
        group.entities.grep(Sketchup::SectionPlane).each do |sp|
          sp.erase! if sp.name =~ /\[SkalpSectionBox\]/
        end
        
        child_group = group.entities.find { |e| e.is_a?(Sketchup::Group) && e.name =~ /\[SkalpSectionBox/ }
        group.explode
        explode_recursive(child_group) if child_group
      end

      def self.deactivate_current
        return unless @@active_box_id
        model = Sketchup.active_model; root = model.entities.find { |e| e.get_attribute(DICTIONARY_NAME, 'box_id') == @@active_box_id }
        if root && root.valid?
          model.start_operation('Deactivate SectionBox', true)
          explode_recursive(root)
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
      
      def self.get_unique_folder_name(hierarchy, base_name)
        existing_names = []
        gather_names = lambda do |items|
          items.each do |item|
            existing_names << item["name"] if item["type"] == "folder"
            gather_names.call(item["children"]) if item["children"]
          end
        end
        gather_names.call(hierarchy)
        
        return base_name unless existing_names.include?(base_name)
        
        idx = 1
        new_name = "#{base_name} (#{idx})"
        while existing_names.include?(new_name)
          idx += 1
          new_name = "#{base_name} (#{idx})"
        end
        new_name
      end
      
      def self.create_folder(parent_id = nil)
        model = Sketchup.active_model
        hierarchy = Data.get_hierarchy(model)
        
        # Determine suggest name
        suggested = get_unique_folder_name(hierarchy, "New Folder")
        
        # Prompt for name
        results = UI.inputbox(["Folder Name:"], [suggested], "Create Folder")
        return unless results
        name = get_unique_folder_name(hierarchy, results[0])
        
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
