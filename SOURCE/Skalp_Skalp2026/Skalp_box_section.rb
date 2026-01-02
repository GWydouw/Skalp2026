require "sketchup"
require "json"

module Skalp
  module BoxSection
    DICTIONARY_NAME = "Skalp_BoxSection" unless defined?(DICTIONARY_NAME)
    ATTR_IS_BOX_SECTION = "is_box_section" unless defined?(ATTR_IS_BOX_SECTION)

    # Persistence Layer
    module Data
      DICTIONARY = "Skalp_BoxSection_Data" unless defined?(DICTIONARY)

      def self.get_config(model)
        val = model.get_attribute(DICTIONARY, "config", "{}")
        return val if val.is_a?(Hash) # Mac auto-eval

        begin
          JSON.parse(val)
        rescue StandardError
          {}
        end
      end

      def self.save_config(model, config)
        model.set_attribute(DICTIONARY, "config", config.to_json)
      end

      def self.get_hierarchy(model)
        val = model.get_attribute(DICTIONARY, "hierarchy", "[]")
        return val if val.is_a?(Array) # Mac auto-eval

        begin
          JSON.parse(val)
        rescue StandardError
          []
        end
      end

      def self.save_hierarchy(model, hierarchy)
        model.set_attribute(DICTIONARY, "hierarchy", hierarchy.to_json)
      end

      def self.safe_read_default(key, default_val = nil)
        val = Sketchup.read_default("Skalp", key, default_val)
        return val if val.is_a?(Array) || val.is_a?(Hash)

        if val.is_a?(String)
          begin
            json_str = val.start_with?("SB_JSON:") ? val[8..-1] : val
            return JSON.parse(json_str)
          rescue StandardError
            return val
          end
        end
        val
      rescue Exception
        default_val
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
        saved = safe_read_default("SectionBoxDefaults_v8")
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
        Sketchup.write_default("Skalp", "SectionBoxDefaults_v8", "SB_JSON:" + data.to_json)
      end

      def self.get_scales
        default_scales = [
          "1:1", "1:2", "1:5", "1:10", "1:20", "1:50", "1:100", "1:200", "1:500", "1:1000",
          "1\" = 1' (1:12)", "1/8\" = 1' (1:96)", "1/4\" = 1' (1:48)", "1/2\" = 1' (1:24)",
          "3/4\" = 1' (1:16)", "3\" = 1' (1:4)"
        ]
        saved = safe_read_default("SectionBoxScales_v8")
        return saved if saved.is_a?(Array)

        default_scales
      end

      def self.save_scales(scales_array)
        Sketchup.write_default("Skalp", "SectionBoxScales_v8", "SB_JSON:" + scales_array.to_json)
      end

      def self.get_active_id(model)
        model.get_attribute(DICTIONARY, "active_box_id", nil)
      end

      def self.save_active_id(model, id)
        if id.nil?
          dict = model.attribute_dictionary(DICTIONARY)
          dict.delete_key("active_box_id") if dict
        else
          model.set_attribute(DICTIONARY, "active_box_id", id)
        end
      end
    end

    # Preview Overlay
    if defined?(Sketchup::Overlay)
      class PreviewOverlay < Sketchup::Overlay
        OVERLAY_ID = "skalp.sectionbox.preview" unless defined?(OVERLAY_ID)
        OVERLAY_NAME = "SectionBox Preview" unless defined?(OVERLAY_NAME)
        def initialize
          super(OVERLAY_ID, OVERLAY_NAME)
          @data = []
          @enabled = true
        end

        def set_data(data) = @data = data

        def draw(view)
          return unless @data && !@data.empty?

          magenta = Sketchup::Color.new(255, 0, 255)
          @data.each { |d| Skalp::BoxSection::SkalpDrawHelper.draw_face_highlight(view, d[:face_vertices], d[:name], 25, magenta) }
          Skalp::BoxSection::SkalpDrawHelper.draw_bounds(view, @data, color: magenta, width: 3, stipple: "")
        end
      end
    end

    module SkalpDrawHelper
      def self.get_color(face_name)
        case face_name
        when "top", "bottom" then Sketchup::Color.new(0, 0, 255)
        when "left", "right" then Sketchup::Color.new(255, 0, 0)
        when "front", "back" then Sketchup::Color.new(0, 255, 0)
        else Sketchup::Color.new(74, 144, 226)
        end
      end

      def self.draw_bounds(view, planes_data, options = {})
        color = options[:color] || Sketchup::Color.new(128, 128, 128)
        width = options[:width] || 1
        stipple = options.key?(:stipple) ? options[:stipple] : "_"
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
        view.drawing_color = color
        view.line_width = width
        view.line_stipple = stipple
        unique_edges.each_value do |edge|
          view.draw(GL_LINES, edge)
        end
        view.line_stipple = ""
      end

      def self.draw_face_highlight(view, face_vertices, face_name, alpha = 25, color_override = nil)
        return unless face_vertices && face_vertices.length >= 3

        base_color = color_override || get_color(face_name)
        view.drawing_color = Sketchup::Color.new(base_color.red, base_color.green, base_color.blue, alpha)
        view.draw(GL_POLYGON, face_vertices)
      end

      def self.draw_plus(view, center, normal, face_name, highlighted, arm_size = 15.0, color_override = nil)
        arm = arm_size || 15.0
        width = highlighted ? 4 : 2
        color = highlighted && color_override ? color_override : get_color(face_name)
        axes = normal.axes
        v1 = axes[0]

        v2 = axes[1]
        v1.length = v2.length = arm / 2.0
        view.drawing_color = color
        view.line_width = width
        view.draw(GL_LINES, [center.offset(v1), center.offset(v1.reverse)])
        view.draw(GL_LINES, [center.offset(v2), center.offset(v2.reverse)])
      end
    end

    if defined?(Sketchup::Overlay)
      class InteractionOverlay < Sketchup::Overlay
        OVERLAY_ID = "skalp.sectionbox.interaction" unless defined?(OVERLAY_ID)
        OVERLAY_NAME = "Skalp SectionBox Status" unless defined?(OVERLAY_NAME)
        attr_accessor :highlight_data, :active_mode_text

        def initialize
          super(OVERLAY_ID, OVERLAY_NAME)
          @highlight_data = nil
          @active_mode_text = nil
          @enabled = true
        end

        def can_capture_mouse?(view) = false

        def draw(view)
          draw_status_text(view, @active_mode_text) if @active_mode_text
        end

        def draw_status_text(view, text)
          pt = [view.vpwidth - 180, 40]
          begin
            view.draw_text(pt, text, color: "Black", size: 12, bold: true)
          rescue StandardError; view.draw_text(pt, text)
          end
        end
      end
    end

    def self.calculate_virtual_planes_data(box_config)
      return [] unless box_config && box_config["planes"]

      plane_map = {}
      box_config["planes"].each do |pd|
        plane_map[pd["name"]] = { point: Geom::Point3d.new(pd["point"]), normal: Geom::Vector3d.new(pd["normal"]) }
      end
      return [] unless %w[top bottom right left back front].all? { |k| plane_map.key?(k) }

      intersect_planes = lambda do |p1, p2, p3|
        n1 = p1[:normal]
        n2 = p2[:normal]
        n3 = p3[:normal]

        pl1 = [p1[:point], n1]
        pl2 = [p2[:point], n2]
        pl3 = [p3[:point], n3]
        line = Geom.intersect_plane_plane(pl1, pl2)
        return nil unless line

        Geom.intersect_line_plane(line, pl3)
      end
      pm = plane_map
      c_rt_bk_tp = intersect_planes.call(pm["right"], pm["back"], pm["top"])
      c_lf_bk_tp = intersect_planes.call(pm["left"], pm["back"], pm["top"])
      c_rt_fr_tp = intersect_planes.call(pm["right"], pm["front"], pm["top"])
      c_lf_fr_tp = intersect_planes.call(pm["left"], pm["front"], pm["top"])
      c_rt_bk_bt = intersect_planes.call(pm["right"], pm["back"], pm["bottom"])
      c_lf_bk_bt = intersect_planes.call(pm["left"], pm["back"], pm["bottom"])
      c_rt_fr_bt = intersect_planes.call(pm["right"], pm["front"], pm["bottom"])
      c_lf_fr_bt = intersect_planes.call(pm["left"], pm["front"], pm["bottom"])
      return [] if [c_rt_bk_tp, c_lf_bk_tp, c_rt_fr_tp, c_lf_fr_tp, c_rt_bk_bt, c_lf_bk_bt, c_rt_fr_bt,
                    c_lf_fr_bt].any?(&:nil?)

      faces = []
      faces << { name: "top", face_vertices: [c_lf_fr_tp, c_rt_fr_tp, c_rt_bk_tp, c_lf_bk_tp] }
      faces << { name: "bottom", face_vertices: [c_lf_fr_bt, c_rt_fr_bt, c_rt_bk_bt, c_lf_bk_bt].reverse }
      faces << { name: "front", face_vertices: [c_lf_fr_bt, c_rt_fr_bt, c_rt_fr_tp, c_lf_fr_tp] }
      faces << { name: "back", face_vertices: [c_lf_bk_bt, c_rt_bk_bt, c_rt_bk_tp, c_lf_bk_tp].reverse }
      faces << { name: "left", face_vertices: [c_lf_bk_bt, c_lf_fr_bt, c_lf_fr_tp, c_lf_bk_tp] }
      faces << { name: "right", face_vertices: [c_rt_bk_bt, c_rt_fr_bt, c_rt_fr_tp, c_rt_bk_tp].reverse }
      faces.each do |f|
        f[:original_point] = pm[f[:name]][:point]
        f[:normal] = pm[f[:name]][:normal]
      end
      faces
    end

    def self.get_active_box_section_group
      Sketchup.active_model.entities.find { |e| e.get_attribute(DICTIONARY_NAME, "box_id") == Engine.active_box_id }
    end

    def self.get_section_planes_data(root = nil)
      root ||= Sketchup.active_model.entities.find do |e|
        e.get_attribute(DICTIONARY_NAME, "box_id") == Engine.active_box_id
      end
      return nil unless root && root.valid?

      planes_data = []
      current_group = root
      parent_trans = root.transformation
      10.times do
        break unless current_group.is_a?(Sketchup::Group)

        found_plane = nil
        next_group = nil
        current_group.entities.each do |ent|
          if ent.is_a?(Sketchup::SectionPlane)
            found_plane = ent
          elsif ent.is_a?(Sketchup::Group)
            next_group = ent
          end
        end
        if found_plane
          match = found_plane.name.match(/\[SkalpSectionBox\]-(.+)/)
          face_name = match ? match[1].downcase : "unknown"
          pa = found_plane.get_plane
          local_norm = Geom::Vector3d.new(pa[0], pa[1], pa[2])
          world_norm = local_norm.transform(parent_trans)
          local_pos = Geom::Point3d.new(local_norm.x * -pa[3], local_norm.y * -pa[3], local_norm.z * -pa[3])
          world_pos = parent_trans * local_pos
          planes_data << { name: face_name, plane: found_plane, original_point: world_pos, normal: world_norm,
                           parent_trans: parent_trans, local_point: local_pos }
        end
        break unless next_group

        parent_trans *= next_group.transformation
        current_group = next_group
        break if current_group.name == "[SkalpSectionBox-Model]"
      end
      plane_map = {}
      planes_data.each { |d| plane_map[d[:name]] = d }
      if %w[top bottom right left back front].all? { |k| plane_map.key?(k) }
        intersect_planes = lambda do |p1, p2, p3|
          n1 = p1[:normal]
          n2 = p2[:normal]
          n3 = p3[:normal]

          pl1 = [p1[:original_point], n1]
          pl2 = [p2[:original_point], n2]
          pl3 = [p3[:original_point], n3]
          line = Geom.intersect_plane_plane(pl1, pl2)
          return nil unless line

          Geom.intersect_line_plane(line, pl3)
        end
        pm = plane_map
        c_rt_bk_tp = intersect_planes.call(pm["right"], pm["back"], pm["top"])
        c_lf_bk_tp = intersect_planes.call(pm["left"], pm["back"], pm["top"])
        c_rt_fr_tp = intersect_planes.call(pm["right"], pm["front"], pm["top"])
        c_lf_fr_tp = intersect_planes.call(pm["left"], pm["front"], pm["top"])
        c_rt_bk_bt = intersect_planes.call(pm["right"], pm["back"], pm["bottom"])
        c_lf_bk_bt = intersect_planes.call(pm["left"], pm["back"], pm["bottom"])
        c_rt_fr_bt = intersect_planes.call(pm["right"], pm["front"], pm["bottom"])
        c_lf_fr_bt = intersect_planes.call(pm["left"], pm["front"], pm["bottom"])
        arm_size = 15.0
        arm_size = (c_rt_bk_tp.distance(c_lf_fr_bt) * 0.05).clamp(10, 100) if c_rt_bk_tp && c_lf_fr_bt
        faces = {}
        faces["top"] = [c_lf_fr_tp, c_rt_fr_tp, c_rt_bk_tp, c_lf_bk_tp].compact
        faces["bottom"] = [c_lf_fr_bt, c_rt_fr_bt, c_rt_bk_bt, c_lf_bk_bt].reverse.compact
        faces["front"] = [c_lf_fr_bt, c_rt_fr_bt, c_rt_fr_tp, c_lf_fr_tp].compact
        faces["back"] = [c_lf_bk_bt, c_rt_bk_bt, c_rt_bk_tp, c_lf_bk_tp].reverse.compact
        faces["left"] = [c_lf_bk_bt, c_lf_fr_bt, c_lf_fr_tp, c_lf_bk_tp].compact
        faces["right"] = [c_rt_bk_bt, c_rt_fr_bt, c_rt_fr_tp, c_rt_bk_tp].reverse.compact
        planes_data.each do |d|
          d[:arm_size] = arm_size
          next unless faces[d[:name]]

          d[:face_vertices] = faces[d[:name]]

          center_pt = Geom::Point3d.new(0, 0, 0)
          d[:face_vertices].each do |v|
            center_pt += v.to_a
          end
          center = Geom::Point3d.new(center_pt.x / 4.0,
                                     center_pt.y / 4.0, center_pt.z / 4.0)
          d[:original_point] = center
        end
      end
      planes_data
    end

    class SettingsDialog
      def initialize(default_name = "SectionBox", &block)
        @default_name = default_name
        @on_save = block
        @dialog = nil
        show
      end

      def show
        path = File.join(File.dirname(__FILE__), "ui", "settings.html")
        @dialog = UI::HtmlDialog.new({ dialog_title: "SectionBox Settings",
                                       preferences_key: "com.skalp.sectionbox.settings", scrollable: false, resizable: false, width: 350, height: 450, style: UI::HtmlDialog::STYLE_UTILITY })
        @dialog.set_file(path)
        @dialog.add_action_callback("ready") do
          defaults = Data.get_defaults
          scales = Data.get_scales
          @dialog.execute_script("initScales(#{scales.to_json})")
          if @default_name.is_a?(Hash)

            @dialog.execute_script("loadDefaults(#{@default_name.to_json})")
            @dialog.execute_script("setName(#{@default_name['name'].to_json})") if @default_name["name"]

            @dialog.execute_script("setSubmitText('Save')")
          else
            @dialog.execute_script("loadDefaults(#{defaults.to_json})")
            @dialog.execute_script("setName(#{@default_name.to_json})")
            @dialog.execute_script("setSubmitText('Create')")
          end
        end
        @dialog.add_action_callback("save") do |d, json|
          save(json)
        end; @dialog.add_action_callback("save_default") do |d, data|
               Data.save_defaults(data.is_a?(String) ? JSON.parse(data) : data)
             end
        @dialog.add_action_callback("save_scales") do |d, data|
          Data.save_scales(data.is_a?(String) ? JSON.parse(data) : data)
        end
        @dialog.add_action_callback("open_scale_manager") do |d, p|
          ScaleManager.new
        end; @dialog.add_action_callback("close") do
               close
             end
        @dialog.center
        @dialog.show
      end

      def save(json)
        data = json.is_a?(String) ? JSON.parse(json) : json
        settings = { "name" => data["name"], "scale" => "1/#{data['scale']}",
                     "rear_view_global" => data["rear_view_global"], "sides_all_same" => data["sides_all_same"], "sides" => data["sides"] }

        settings["style_rule"] = data["sides"]["all"]["style_rule"] if data["sides_all_same"]
        @on_save.call(settings) if @on_save
        close
      end

      def close
        @dialog.close if @dialog
        @dialog = nil
      end
    end

    class ScaleManager
      def initialize
        @dialog = nil
        show
      end

      def show
        if @dialog && @dialog.visible?

          @dialog.bring_to_front
          return
        end

        path = File.join(File.dirname(__FILE__), "ui", "scale_manager.html")
        @dialog = UI::HtmlDialog.new({ dialog_title: "Drawing Scale Manager",
                                       preferences_key: "com.skalp.sectionbox.scale_manager", scrollable: false, resizable: true, width: 400, height: 500, style: UI::HtmlDialog::STYLE_UTILITY })
        @dialog.set_file(path)
        @dialog.add_action_callback("ready") do
          scales = Data.get_scales

          @dialog.execute_script("loadScales(#{scales.to_json})")
        end
        @dialog.add_action_callback("save_scales") do |d, data|
          Data.save_scales(data.is_a?(String) ? JSON.parse(data) : data)
        end
        @dialog.add_action_callback("restore_defaults") do
          default_scales = ["1:1", "1:2", "1:5", "1:10", "1:20", "1:50", "1:100", "1:200", "1:500", "1:1000", "1\" = 1' (1:12)",
                            "1/8\" = 1' (1:96)", "1/4\" = 1' (1:48)", "1/2\" = 1' (1:24)", "3/4\" = 1' (1:16)", "3\" = 1' (1:4)"]
          Data.save_scales(default_scales)
          @dialog.execute_script("loadScales(#{default_scales.to_json})")
        end
        @dialog.set_on_closed { @dialog = nil }
        @dialog.center
        @dialog.show
      end
    end

    class Manager
      def initialize = @dialog = nil

      def show
        if @dialog && @dialog.visible?

          @dialog.bring_to_front
          return
        end

        path = File.join(File.dirname(__FILE__), "ui", "manager.html")
        @dialog = UI::HtmlDialog.new({ dialog_title: "Skalp SectionBox Manager",
                                       preferences_key: "com.skalp.sectionbox.manager", scrollable: false, resizable: true, width: 300, height: 500, style: UI::HtmlDialog::STYLE_UTILITY })
        @dialog.set_file(path)
        @dialog.add_action_callback("ready") { |d, p| sync_data }; @dialog.add_action_callback("sync") do |d, p|
                                                                     sync_data
                                                                   end; @dialog.add_action_callback("close") do |d, p|
                                                                          @dialog.close
                                                                        end
        @dialog.add_action_callback("activate") do |d, id|
          Fiber.new do
            Engine.activate(id)
          end.resume
        end; @dialog.add_action_callback("deactivate") do |d, id|
               Fiber.new do
                 Engine.deactivate_current
               end.resume
             end
        @dialog.add_action_callback("preview") do |d, id|
          Engine.preview(id)
        end; @dialog.add_action_callback("clear_preview") do |d, p|
               Engine.clear_preview
             end; @dialog.add_action_callback("modify") do |d, id|
                    Fiber.new do
                      Engine.modify(id)
                    end.resume
                  end
        @dialog.add_action_callback("add_box") do |d, p|
          Fiber.new do
            Engine.create_from_model_bounds
          end.resume
        end; @dialog.add_action_callback("add_folder") do |d, parent_id|
               Fiber.new do
                 Engine.create_folder(parent_id.empty? ? nil : parent_id)
               end.resume
             end
        @dialog.add_action_callback("toggle_folder") do |d, folder_id|
          Fiber.new do
            Engine.toggle_folder(folder_id)
          end.resume
        end; @dialog.add_action_callback("rename_folder") do |d, folder_id|
               Fiber.new do
                 Engine.rename_folder(folder_id)
               end.resume
             end
        @dialog.add_action_callback("edit") do |d, id|
          Fiber.new do
            Engine.edit(id)
          end.resume
        end; @dialog.add_action_callback("rename") do |d, id|
               Fiber.new do
                 Engine.rename(id)
               end.resume
             end; @dialog.add_action_callback("delete") do |d, id|
                    Fiber.new do
                      Engine.delete(id)
                    end.resume
                  end
        @dialog.add_action_callback("move_item") { |d, json| Fiber.new { Engine.move_item(json) }.resume }
        @dialog.set_on_closed { @dialog = nil }
        @dialog.show
      end

      def sync_data
        return unless @dialog && @dialog.visible?

        model = Sketchup.active_model

        data = { boxes: Data.get_config(model), hierarchy: Data.get_hierarchy(model), active_id: Engine.active_box_id }
        @dialog.execute_script("updateData(#{data.to_json})")
      end

      def visible?
        @dialog && @dialog.visible?
      rescue StandardError
        false
      end
    end

    module Engine
      @@interaction_overlay ||= nil
      @@active_box_id ||= nil
      @@manager ||= nil

      @@observers_active ||= false
      @@model_observer ||= nil
      @@selection_observer ||= nil
      @@original_render_settings ||= {}
      @@overlay ||= nil
      @@ignore_next_selection ||= false
      @@edit_inside_render_settings ||= nil
      def self.active_box_id
        @@active_box_id ||= Data.get_active_id(Sketchup.active_model)
      end

      def self.manager
        @@manager
      end

      def self.observers_active?
        @@observers_active
      end

      def self.run
        @@manager ||= Manager.new
        @@active_box_id ||= Data.get_active_id(Sketchup.active_model)
        @@manager.show
        start_observers
        add_overlay
      end

      def self.stop
        @@manager.close if @@manager
        stop_observers
        exit_edit_inside_mode
        deactivate_current if @@active_box_id
      end

      def self.start_observers
        return if @@observers_active

        model = Sketchup.active_model

        @@model_observer ||= SectionBoxModelObserver.new
        @@selection_observer ||= SectionBoxSelectionObserver.new
        @@frame_observer ||= SectionBoxFrameChangeObserver.new
        model.add_observer(@@model_observer)
        model.selection.add_observer(@@selection_observer)
        Sketchup::Pages.add_frame_change_observer(@@frame_observer)
        @@observers_active = true
      end

      def self.add_overlay
        return unless defined?(Sketchup::Overlay)

        model = Sketchup.active_model; existing = model.overlays.find do |o|
                                         o.respond_to?(:overlay_id) && o.overlay_id == PreviewOverlay::OVERLAY_ID
                                       end
        was_enabled = true; if existing
                              was_enabled = existing.enabled?
                              model.overlays.remove(existing)

                            end
        @@overlay = PreviewOverlay.new
        model.overlays.add(@@overlay)
        @@overlay.enabled = was_enabled
        existing_int = model.overlays.find do |o|
          o.respond_to?(:overlay_id) && o.overlay_id == InteractionOverlay::OVERLAY_ID
        end
        model.overlays.remove(existing_int) if existing_int
        @@interaction_overlay = InteractionOverlay.new
        model.overlays.add(@@interaction_overlay)
        @@interaction_overlay.enabled = true
      end

      def self.enter_edit_inside_mode(box_group)
        return unless @@interaction_overlay

        path_to_model = [box_group]
        find_recursive = lambda do |container, current_path|
          container.entities.each do |e|
            next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)

            is_match = e.name.include?("[SkalpSectionBox-Model]")
            is_match = e.definition.name.include?("[SkalpSectionBox-Model]") if !is_match && e.respond_to?(:definition)
            if is_match

              current_path << e
              return true
            end
            next unless e.respond_to?(:definition) && e.definition.entities.length > 0

            current_path << e
            return true if find_recursive.call(e.definition,
                                               current_path)

            current_path.pop
          end
          false
        end
        if find_recursive.call(box_group.definition, path_to_model)

          Sketchup.active_model.active_path = path_to_model
          @@interaction_overlay.active_mode_text = "Edit Inside Mode"; else
                                                                         UI.messagebox("Could not find inner model context.")
        end
        Sketchup.active_model.active_view.invalidate
      end

      def self.exit_edit_inside_mode
        return unless @@interaction_overlay

        @@interaction_overlay.active_mode_text = nil
        Sketchup.active_model.active_view.invalidate
      end

      def self.preview(id)
        return unless @@overlay

        model = Sketchup.active_model

        config = Data.get_config(model)
        box = config[id]
        @@overlay.set_data(Skalp::BoxSection.calculate_virtual_planes_data(box)) if box
        model.active_view.invalidate
      end

      def self.clear_preview
        return unless @@overlay

        @@overlay.set_data([])
        Sketchup.active_model.active_view.invalidate
      end

      def self.stop_observers
        return unless @@observers_active

        model = Sketchup.active_model

        model.remove_observer(@@model_observer) if @@model_observer
        model.selection.remove_observer(@@selection_observer) if @@selection_observer
        Sketchup::Pages.remove_frame_change_observer(@@frame_observer) if @@frame_observer
        @@observers_active = false
      end

      def self.create_from_model_bounds
        model = Sketchup.active_model

        selection = model.selection
        SettingsDialog.new("SectionBox##{Data.get_config(model).length + 1}") do |settings|
          selection.empty? ? do_create_from_model_bounds(settings) : do_create_from_selection(settings)
        end
      end

      def self.do_create_from_model_bounds(settings)
        model = Sketchup.active_model
        bbox = Geom::BoundingBox.new
        model.entities.each do |ent|
          next if ent.get_attribute(DICTIONARY_NAME, "box_id")

          bbox.add(ent.bounds) if ent.respond_to?(:bounds)
        end
        id = "box_" + Time.now.to_i.to_s
        finalize_creation(id, calculate_planes_from_bounds(bbox), settings, :modify)
      end

      def self.do_create_from_box(group, settings)
        return unless group.valid?

        model = Sketchup.active_model

        faces = group.entities.grep(Sketchup::Face)
        trans = group.transformation
        planes_config = []
        faces.each do |f|
          local_normal = f.normal
          world_normal = local_normal.transform(trans)

          world_point = f.bounds.center.transform(trans)
          world_normal.reverse! if world_normal.dot((trans * group.definition.bounds.center) - world_point) < 0
          planes_config << { "name" => Skalp::BoxSection.get_face_name(local_normal), "point" => world_point.to_a, "normal" => world_normal.to_a }
        end
        id = "box_" + Time.now.to_i.to_s
        finalize_creation(id, planes_config, settings, :activate)
        return unless UI.messagebox("Delete original?", MB_YESNO) == IDYES

        group.erase!
      end

      def self.create_from_selection
        model = Sketchup.active_model
        SettingsDialog.new("SectionBox##{Data.get_config(model).length + 1}") do |settings|
          do_create_from_selection(settings)
        end
      end

      def self.do_create_from_selection(settings)
        model = Sketchup.active_model

        selection = model.selection
        return if selection.empty?

        bbox = Geom::BoundingBox.new
        selection.each do |ent|
          bbox.add(ent.bounds) if ent.respond_to?(:bounds)
        end
        id = "box_" + Time.now.to_i.to_s
        finalize_creation(id, calculate_planes_from_bounds(bbox), settings, :activate)
      end

      def self.calculate_planes_from_bounds(bbox)
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
        [
          { "name" => "top", "point" => [cx, cy, max_z],
            "normal" => [0, 0, -1] }, { "name" => "bottom", "point" => [cx, cy, min_z], "normal" => [0, 0, 1] }, { "name" => "right", "point" => [max_x, cy, cz], "normal" => [-1, 0, 0] }, { "name" => "left", "point" => [min_x, cy, cz], "normal" => [1, 0, 0] }, { "name" => "front", "point" => [cx, min_y, cz], "normal" => [0, 1, 0] }, { "name" => "back", "point" => [cx, max_y, cz], "normal" => [0, -1, 0] }
        ]
      end

      def self.finalize_creation(id, planes, settings, mode = :activate)
        model = Sketchup.active_model
        config = Data.get_config(model)

        box_config = Data.get_defaults.merge(settings).merge({ "name" => settings["name"], "planes" => planes,
                                                               "created_at" => Time.now.to_s })
        config[id] = box_config
        Data.save_config(model, config)
        hierarchy = Data.get_hierarchy(model)
        hierarchy << { "id" => id, "type" => "item" }
        Data.save_hierarchy(model, hierarchy)
        @@manager.sync_data if @@manager
        activate(id)
        return unless mode == :modify

        modify(id)
      end

      def self.rename(id)
        model = Sketchup.active_model
        config = Data.get_config(model)

        box = config[id]
        return unless box

        result = Skalp::InputBox.ask(["Name:"], [box["name"]], [], "Rename")
        return unless result && !result[0].empty?

        box["name"] =
          result[0].strip

        config[id] = box
        Data.save_config(model, config)
        @@manager.sync_data
      end

      def self.delete(id)
        return unless UI.messagebox("Delete this SectionBox?", MB_YESNO) == IDYES

        deactivate_current if @@active_box_id == id

        model = Sketchup.active_model
        config = Data.get_config(model)
        config.delete(id)
        Data.save_config(model, config)
        return unless @@manager

        @@manager.sync_data
      end

      def self.edit(id)
        model = Sketchup.active_model

        config = Data.get_config(model)
        box = config[id]
        return unless box

        SettingsDialog.new({ "name" => box["name"], "scale" => (box["scale"] || "1/50").split(%r{[:/]}).last.to_f,
                             "sides_all_same" => box["sides_all_same"], "rear_view_global" => box["rear_view_global"], "sides" => box["sides"] }) do |s|
          box.merge!(s)
          config[id] = box
          Data.save_config(model, config)
          @@manager.sync_data
          activate(id) if @@active_box_id == id
        end
      end

      def self.activate(id)
        deactivate_current if @@active_box_id
        model = Sketchup.active_model
        config = Data.get_config(model)
        box = config[id]
        return unless box

        all_ents = model.entities.to_a.reject do |e|
          res = false
          if e.attribute_dictionary("Skalp_BoxSection")
            res = true
          elsif e.respond_to?(:name) && e.name && !e.name.empty?

            n = e.name
            res = n.include?("Skalp sections") || n.start_with?("[Skalp")
          end
          res
        end

        model.start_operation("Activate", true)
        begin
          @@active_box_id = id
          Data.save_active_id(model, id)
          locked = {}
          all_ents.each do |e|
            next unless e.respond_to?(:locked?) && e.locked?

            e.locked = false
            locked[e.entityID] =
              true
          end
          current = model.entities.add_group(all_ents)
          current.entities.each do |e|
            e.locked = true if locked[e.entityID]
          end
          current.name = "[SkalpSectionBox-Model]"
          box["planes"].each_with_index do |pd, i|
            pt = Geom::Point3d.new(pd["point"])
            sp = model.entities.add_section_plane([pt, Geom::Vector3d.new(pd["normal"])])

            sp.activate
            wrapper = model.entities.add_group([sp, current])
            sp.set_attribute(DICTIONARY_NAME, "original_point", (wrapper.transformation.inverse * pt).to_a)
            sp.name = "[SkalpSectionBox]-#{pd['name']}"
            if i == box["planes"].length - 1
              wrapper.name = "[SkalpSectionBox]"
              wrapper.set_attribute(DICTIONARY_NAME, "box_id", id); else
                                                                      wrapper.name = "[SkalpSectionBox]-#{pd['name'].capitalize}"

            end

            current = wrapper
          end
          model.commit_operation

          # Generate Skalp section fills for all 6 planes (delayed to ensure Skalp is ready)
          if defined?(SkalpIntegration)
            UI.start_timer(0.5, false) do
              SkalpIntegration.update_all if Skalp.respond_to?(:active_model) && Skalp.active_model
            end
          end

          @@manager.sync_data if @@manager
        rescue StandardError => e
          model.abort_operation
          puts "Err: #{e.message}"
        end
      end

      def self.deactivate_current
        return unless active_box_id

        model = Sketchup.active_model

        # Clean up Skalp section fills first
        SkalpIntegration.cleanup if defined?(SkalpIntegration)

        root = model.entities.find do |e|
          e.get_attribute(DICTIONARY_NAME, "box_id") == active_box_id
        end; if root
               model.start_operation("Deactivate", true)
               (e_rec = lambda { |g|
                 return unless g && g.valid?

                 g.entities.grep(Sketchup::SectionPlane).each do |sp|
                   sp.erase! if sp.name =~ /\[SkalpSectionBox\]/
                 end
                 child = g.entities.find do |e|
                   e.is_a?(Sketchup::Group) && e.name =~ /\[SkalpSectionBox/
                 end
                 g.explode
                 e_rec.call(child) if child
               }).call(root)
               model.commit_operation
             end

        exit_edit_inside_mode
        @@active_box_id = nil
        Data.save_active_id(model, nil)
        return unless @@manager

        @@manager.sync_data
      end

      def self.modify(id)
        activate(id) unless @@active_box_id == id
        Sketchup.active_model.select_tool(Skalp::BoxSectionAdjustTool.new)
      end

      def self.update_planes_from_entities(id)
        # Update saved plane configurations from current section plane positions
        model = Sketchup.active_model
        config = Data.get_config(model)
        box = config[id]
        return unless box

        root = model.entities.find do |e|
          e.get_attribute(DICTIONARY_NAME, "box_id") == id
        end
        return unless root && root.valid?

        planes_data = Skalp::BoxSection.get_section_planes_data(root)
        return unless planes_data

        updated_planes = planes_data.map do |pd|
          { "name" => pd[:name], "point" => pd[:original_point].to_a, "normal" => pd[:normal].to_a }
        end
        box["planes"] = updated_planes
        config[id] = box
        Data.save_config(model, config)
      end

      def self.on_enter_box_context(model)
        add_overlay if @@interaction_overlay.nil?
        opts = model.rendering_options
        keys = opts.keys

        # Backup Normal Mode
        @@original_render_settings = {}
        track_keys = %w[InactiveFade InstanceFade InactiveHidden InstanceHidden FadeInactiveComponents
                        FadeInsideComponents HideInactiveComponents HideInsideComponents]
        track_keys.each { |k| @@original_render_settings[k] = opts[k] if keys.include?(k) }

        # Initialize Inside Mode with user requested defaults
        if @@edit_inside_render_settings.nil?
          @@edit_inside_render_settings = {
            "InactiveFade" => 1.0,
            "InstanceFade" => 1.0,
            "InactiveHidden" => false,
            "InstanceHidden" => false,
            "FadeInactiveComponents" => true,
            "FadeInsideComponents" => true,
            "HideInactiveComponents" => false,
            "HideInsideComponents" => false
          }
        end

        # Apply Inside Mode settings
        @@edit_inside_render_settings.each do |k, v|
          opts[k] = v if keys.include?(k)
        end

        @@interaction_overlay.active_mode_text = "Edit Inside Mode" if @@interaction_overlay
        model.active_view.invalidate
      rescue StandardError => e
        puts "Skalp Debug: Error enter context: #{e.message}" if defined?(DEBUG) && DEBUG
      end

      def self.create_folder(parent_id = nil)
        model = Sketchup.active_model
        h = Data.get_hierarchy(model)

        result = Skalp::InputBox.ask(["Folder Name:"], ["New Folder"], [], "Create Folder")
        return unless result && !result[0].empty?

        new_folder = {
          "id" => "folder_" + Time.now.to_i.to_s,
          "name" => result[0].strip,
          "type" => "folder",
          "children" => [],
          "open" => true
        }

        if parent_id.nil?
          h << new_folder
        else
          insert_into = lambda { |items|
            items.each do |i|
              if i["id"] == parent_id && i["type"] == "folder"
                i["children"] ||= []
                i["children"] << new_folder
                return true
              end
              return true if i["children"] && insert_into.call(i["children"])
            end
            false
          }
          insert_into.call(h) || (h << new_folder)
        end

        Data.save_hierarchy(model, h)
        @@manager.sync_data if @@manager
      end

      def self.rename_folder(fid)
        model = Sketchup.active_model
        h = Data.get_hierarchy(model)

        target_folder = nil
        find_folder = lambda { |items|
          items.each do |i|
            if i["id"] == fid && i["type"] == "folder"
              target_folder = i
              return true
            end
            return true if i["children"] && find_folder.call(i["children"])
          end
          false
        }
        find_folder.call(h)
        return unless target_folder

        result = Skalp::InputBox.ask(["New Name:"], [target_folder["name"]], [], "Rename Folder")
        return unless result && !result[0].empty?

        target_folder["name"] = result[0].strip
        Data.save_hierarchy(model, h)
        @@manager.sync_data if @@manager
      end

      def self.on_exit_box_context(model)
        opts = model.rendering_options
        keys = opts.keys

        # Capture current state as the persistent "Inside Mode" state
        if @@edit_inside_render_settings
          @@edit_inside_render_settings.keys.each do |k|
            @@edit_inside_render_settings[k] = opts[k] if keys.include?(k)
          end
        end

        # Restore Normal Mode settings
        @@original_render_settings.each do |k, v|
          opts[k] = v if keys.include?(k)
        end
        @@original_render_settings = {}

        exit_edit_inside_mode
        if model.active_path && !model.active_path.empty?
          UI.start_timer(0, false) do
            model.active_path = nil
            model.active_view.invalidate
          end
        end
        model.active_view.invalidate
      rescue StandardError => e
        puts "Skalp Debug: Error exit context: #{e.message}" if defined?(DEBUG) && DEBUG
      end

      def self.toggle_folder(fid)
        h = Data.get_hierarchy(Sketchup.active_model); (t_rec = lambda { |items|
          items.each do |i|
            if i["id"] == fid
              i["open"] = !i["open"]
              return true
            end
            return true if i["children"] && t_rec.call(i["children"])
          end
          false
        }).call(h)
        Data.save_hierarchy(Sketchup.active_model, h)
        return unless @@manager

        @@manager.sync_data
      end

      def self.move_item(json)
        data = json.is_a?(String) ? JSON.parse(json) : json
        source_id = data["source"]
        target_id = data["target"]
        return unless source_id

        model = Sketchup.active_model
        h = Data.get_hierarchy(model)
        # Find and remove source item
        source_item = nil
        remove_item = lambda { |items|
          items.each_with_index do |i, idx|
            if i["id"] == source_id
              source_item = items.delete_at(idx)
              return true
            end
            return true if i["children"] && remove_item.call(i["children"])
          end
          false
        }
        remove_item.call(h)
        return unless source_item

        # Insert into target
        if target_id.nil? || target_id.empty?
          h << source_item
        else
          insert_into = lambda { |items|
            items.each do |i|
              if i["id"] == target_id && i["type"] == "folder"
                i["children"] ||= []
                i["children"] << source_item
                return true
              end
              return true if i["children"] && insert_into.call(i["children"])
            end
            false
          }
          insert_into.call(h) || (h << source_item)
        end
        Data.save_hierarchy(model, h)
        @@manager.sync_data if @@manager
      end
    end

    class SectionBoxModelObserver < Sketchup::ModelObserver
      def onActivePathChanged(model)
        path = model.active_path || []; in_box = path.any? do |e|
          n = e.name.to_s
          m = n.include?("[SkalpSectionBox-Model]")

          m ||= e.definition.name.include?("[SkalpSectionBox-Model]") if !m && e.respond_to?(:definition)
          m
        end
        if in_box && !@in_context

          Engine.on_enter_box_context(model)
          @in_context = true

        elsif !in_box && @in_context
          Engine.on_exit_box_context(model)
          Engine.exit_edit_inside_mode
          @in_context = false
        end
      end
    end

    class SectionBoxSelectionObserver < Sketchup::SelectionObserver
      def onSelectionBulkChange(selection)
        return unless Engine.observers_active? && Engine.active_box_id

        active = false
        if selection.length == 1
          ent = selection.first
          active = ent.is_a?(Sketchup::Group) && ent.get_attribute(
            DICTIONARY_NAME, "box_id"
          ) == Engine.active_box_id
        end
        if active
          selection.clear
          Engine.enter_edit_inside_mode(ent)
        else
          Engine.exit_edit_inside_mode
        end
      end
    end

    class SectionBoxFrameChangeObserver
      def frameChange(from_page, to_page, percent_done)
        # Only react when scene transition starts (roughly 0.0 to small positive)
        # However, frameChange provides 0.0 to 1.0.
        # But we really want to catch the *event* of changing scenes.
        # Actually, FrameChangeObserver is for animations.
        # Wait, the user request says "switched scenes".
        # A simple FrameChangeObserver on Pages object triggers on scene change?
        # No, FrameChangeObserver is for Pages (Scene transition).
        # "Implement the FrameChangeObserver interface to be notified of frame changes during an animation."
        # When switching scenes with transition time > 0, this fires.
        # When transition time == 0, it might not fire typically, BUT for Pages specifically:
        # "This observer is triggered when the user clicks on a scene tab..."
        # Actually, `Pages.add_frame_change_observer` is the way.

        return unless Engine.active_box_id

        # Deactivate the box
        Engine.deactivate_current

        # Re-apply the target scene because the deactivation might have changed the camera/shadows etc
        # to the state *before* the box was active, or just 'current' state.
        # The scene switch is in progress. If we deactivate now, we might interfere.
        # But the request says: "deactiveer voordat de switch echt gebeurd of dat we de switch na deactivatie nog eens moeten doen"

        # If we deactivate, we change geometry.
        # If we assume 'to_frame' isn't fully helpful for identifying target scene directly here easily
        # (it's just a float).
        # But `model.pages.selected_page` should be the *new* page being switched TO.

        model = Sketchup.active_model
        page = model.pages.selected_page
        return unless page

        # Force re-application of the scene to ensure we get to the correct final state
        # cleanly without the section box.
        # We use a timer to let the current stack unwind slightly if needed,
        # or just call it. Calling it immediately might interrupt the current transition?
        # If we are IN a transition (FrameChange), calling use might be recursive?
        # But we just deactivated, so active_box_id is nil. Recursion stops.
        page.use
      end
    end

    def self.reload
      load __FILE__
      load File.join(File.dirname(__FILE__), "Skalp_box_section_tool.rb")
    end
    unless defined?(@@ui_loaded)
      tb = UI::Toolbar.new("Skalp SectionBox")
      cmd = UI::Command.new("Manager") { Engine.manager && Engine.manager.visible? ? Engine.stop : Engine.run }
      cmd.set_validation_proc { Engine.manager && Engine.manager.visible? ? MF_CHECKED : MF_UNCHECKED }
      cmd.small_icon = cmd.large_icon = File.join(File.dirname(__FILE__), "icons", "box_section",
                                                  "icon_box_section_create.svg")
      tb.add_item(cmd)

      reload_cmd = UI::Command.new("Reload") do
        Skalp::BoxSection.reload
        UI.messagebox("SectionBox reloaded!")
      end
      reload_cmd.tooltip = "Reload SectionBox Plugin"
      reload_cmd.small_icon = reload_cmd.large_icon = File.join(File.dirname(__FILE__), "icons", "box_section",
                                                                "icon_reload.svg")
      tb.add_item(reload_cmd)

      tb.show
      UI.add_context_menu_handler do |menu|
        s = Sketchup.active_model.selection; if s.length == 1
                                               e = s.first
                                               if e.is_a?(Sketchup::Group) && e.get_attribute(DICTIONARY_NAME,
                                                                                              "box_id") == Engine.active_box_id
                                                 menu.add_item("Deactivate") do
                                                   Fiber.new do
                                                     Engine.deactivate_current
                                                   end.resume
                                                 end
                                               end
                                             end
      end
      @@ui_loaded = true
    end
  end
end
