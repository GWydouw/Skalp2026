require 'sketchup.rb'

module Skalp
  class BoxSectionAdjustTool
    # State tracking
    GRIP_RADIUS = 15 unless defined?(GRIP_RADIUS)
    DRAG_THRESHOLD = 5 unless defined?(DRAG_THRESHOLD)

    def initialize
      @hovered_index = nil
      @hovered_type = nil # :grip or :face
      @dragging_index = nil
      @dragging_type = nil
      load_cursors
    end
    
    def load_cursors
      return if @cursors_loaded
      icon_path = File.join(File.dirname(__FILE__), 'icons', 'box_section')
      @cursor_default = UI.create_cursor(File.join(icon_path, 'cursor_pushpull.svg'), 0, 0)
      @cursor_red     = UI.create_cursor(File.join(icon_path, 'cursor_pushpull_red.svg'), 0, 0)
      @cursor_green   = UI.create_cursor(File.join(icon_path, 'cursor_pushpull_green.svg'), 0, 0)
      @cursor_blue    = UI.create_cursor(File.join(icon_path, 'cursor_pushpull_blue.svg'), 0, 0)
      @cursors_loaded = true
    end

    def activate
      @view = Sketchup.active_model.active_view
      Skalp::BoxSection.set_overlay_visibility(false)
      refresh_data
      @view.invalidate
    end

    def deactivate(view)
      Skalp::BoxSection.set_overlay_visibility(true)
      view.invalidate
    end

    def refresh_data
      @planes_data = Skalp::BoxSection.get_section_planes_data || []
    end

    def onSetCursor
      if @hovered_index && @hovered_type == :grip
        # Colored cursor based on face name/axis
        data = @planes_data[@hovered_index]
        case data[:name]
        when "top", "bottom" then UI.set_cursor(@cursor_blue)
        when "left", "right" then UI.set_cursor(@cursor_red)
        when "front", "back" then UI.set_cursor(@cursor_green)
        else UI.set_cursor(@cursor_default)
        end
      else
        # Default pushpull cursor for face hover or general tool use
        UI.set_cursor(@cursor_default)
      end
    end

    def onKeyDown(key, repeat, flags, view)
    end

    def onMouseMove(flags, x, y, view)
      if @dragging_index
        handle_drag(x, y, view)
      else
        new_index, new_type = hit_test(x, y, view)
        if new_index != @hovered_index || new_type != @hovered_type
          @hovered_index = new_index
          @hovered_type = new_type
          view.invalidate
        end
      end
    end

    def onLButtonDown(flags, x, y, view)
      @dragging_index, @dragging_type = hit_test(x, y, view)
      if @dragging_index
        @drag_start_point = @planes_data[@dragging_index][:original_point].clone
      end
    end

    def onLButtonUp(flags, x, y, view)
      @dragging_index = nil
      @dragging_type = nil
      view.invalidate
    end

    def hit_test(x, y, view)
      # Priority 1: Grips (Plusses)
      @planes_data.each_with_index do |data, i|
        screen_pt = view.screen_coords(data[:original_point])
        next unless screen_pt
        dist = Math.sqrt((screen_pt.x - x)**2 + (screen_pt.y - y)**2)
        
        # Calculate pixels for grip radius
        pixel_scale = view.pixels_to_model(1.0, data[:original_point])
        # Safe guard against zero scale
        pixel_scale = 1.0 if pixel_scale == 0
        
        # Use arm_size or fallback, convert to pixels via scale info isn't always reliable for "size on screen"
        # Simplification: Assume grip area is roughly 20px radius around center for easy clicking
        grip_px = 20
        
        if dist <= grip_px
          return [i, :grip]
        end
      end
      
      # Priority 2: Faces
      point = Geom::Point3d.new(x, y, 0)
      @planes_data.each_with_index do |data, i|
        verts = data[:face_vertices]
        next unless verts
        
        screen_poly = verts.map do |v| 
          sp = view.screen_coords(v)
          next unless sp
          Geom::Point3d.new(sp.x, sp.y, 0)
        end
        next if screen_poly.include?(nil) # Clip if vertices behind camera
        
        if Geom.point_in_polygon_2D(point, screen_poly, true)
          return [i, :face]
        end
      end
      
      nil
    end

    def handle_drag(x, y, view)
      return unless @dragging_index
      
      data = @planes_data[@dragging_index]
      plane_ent = data[:plane]
      normal = data[:normal] # World normal
      parent_trans = data[:parent_trans]
      
      pick_ray = view.pickray(x, y)
      
      # Project pick ray onto the drag line (defined by start point and normal direction)
      # We drag along the normal vector
      line = [@drag_start_point, normal]
      new_pt = Geom.closest_points(line, pick_ray)[0]
      
      if new_pt
        # Convert world point back to local space of the group containing the plane
        local_pt = parent_trans.inverse * new_pt
        
        # Calculate local normal (should be constant but for correctness)
        local_norm = normal.transform(parent_trans.inverse) 
        
        Sketchup.active_model.start_operation("Adjust", true, false, true)
        plane_ent.set_plane([local_pt, local_norm])
        plane_ent.set_attribute(Skalp::BoxSection::DICTIONARY_NAME, 'original_point', local_pt.to_a)
        
        # Sync hit target position if it exists (legacy support?)
        target = plane_ent.parent.entities.find { |e| e.get_attribute(Skalp::BoxSection::DICTIONARY_NAME, 'is_grip_target') }
        if target
          target.transformation = Geom::Transformation.translation(local_pt)
        end
        
        Sketchup.active_model.commit_operation
        refresh_data
        view.invalidate
      end
    end


    def draw(view)
      return unless @planes_data && @planes_data.any?
      
      # Use shared drawing utilities
      Skalp::BoxSection::DrawHelper.draw_bounds(view, @planes_data)
      
      @planes_data.each_with_index do |data, i|
        is_highlighted = (@hovered_index == i) # Highlight on both grip and face hover
        
        # Highlight Face
        Skalp::BoxSection::DrawHelper.draw_face_highlight(view, data[:face_vertices], data[:name]) if is_highlighted
        
        # Draw Plus
        # Highlight Plus ONLY if hovering grip specifically? Or always when highlighted?
        # User requirement: "Als we over een plus zitten veranderd de cursur..." => interactions implies plus is distinct.
        # But visually: "de vlakken welke in de juiste kleur oplichten als je over de plus hovert".
        # So hovering plus highlights face.
        # Does hovering face highlight plus? Probably consistent.
        # Let's keep plus highlighting tied to generic highlight for now, or just face.
        # User said: "cursor... on hover plus".
        # Visuals: gray dotted, colored plus, highlighted face.
        
        # Let's assume the specific "highlighted" style of the plus (thicker line) matches the face highlight.
        Skalp::BoxSection::DrawHelper.draw_plus(view, data[:original_point], data[:normal], data[:name], is_highlighted, data[:arm_size] || 15.0)
      end
    end
  end
end
