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
      
      get_cursor = lambda do |name|
        pdf = File.join(icon_path, "#{name}.pdf")
        png = File.join(icon_path, "#{name}.png")
        svg = File.join(icon_path, "#{name}.svg")
        
        # Priority: PDF (Mac) > PNG (Reliable) > SVG (Default)
        if Sketchup.platform == :platform_osx && File.exist?(pdf)
           path = pdf
        elsif File.exist?(png)
           path = png
        else
           path = svg
        end
        
        path
      end

      @cursor_default = UI.create_cursor(get_cursor.call('cursor_pushpull'), 0, 0)
      @cursor_red     = UI.create_cursor(get_cursor.call('cursor_pushpull_red'), 0, 0)
      @cursor_green   = UI.create_cursor(get_cursor.call('cursor_pushpull_green'), 0, 0)
      @cursor_blue    = UI.create_cursor(get_cursor.call('cursor_pushpull_blue'), 0, 0)
      @cursors_loaded = true
    end

    def activate
      @view = Sketchup.active_model.active_view
      @box_group = Skalp::BoxSection.get_active_box_section_group
      refresh_data
      @state = :idle
      @view.invalidate
    end

    def deactivate(view)
      # Save any modifications made during this session
      active_id = Skalp::BoxSection::Engine.active_box_id
      if active_id
        Skalp::BoxSection::Engine.update_planes_from_entities(active_id)
      end
      view.invalidate
    end

    def refresh_data
      @planes_data = Skalp::BoxSection.get_section_planes_data(@box_group) || []
    end


    def onSetCursor
      # Allow directional cursor for both :grip and :face
      if @hovered_index && (@hovered_type == :grip || @hovered_type == :face)
        data = @planes_data[@hovered_index]
        case data[:name]
        when "top", "bottom" then UI.set_cursor(@cursor_blue)
        when "left", "right" then UI.set_cursor(@cursor_red)
        when "front", "back" then UI.set_cursor(@cursor_green)
        else UI.set_cursor(@cursor_default)
        end
      else
        UI.set_cursor(@cursor_default)
      end
    end

    def onKeyDown(key, repeat, flags, view)
    end

    # State machine for interaction
    # :idle -> (Click) -> :check_drag -> (Move > threshold) -> :dragging -> (Release) -> :idle
    #                                 -> (Release < threshold) -> :moving -> (Click) -> :idle
    
    def onLButtonDown(flags, x, y, view)

      if @state == :moving
        # Click to finish move (Click-Move-Click end)
        commit_move
        @state = :idle
        view.invalidate
      else
        # Start potential drag or click
        index, type = hit_test(x, y, view)
        if index
          @dragging_index = index
          @dragging_type = type
          @drag_start_point = @planes_data[index][:original_point].clone
          @drag_start_screen = [x, y]
          @state = :check_drag
        end
      end
    end

    def onLButtonUp(flags, x, y, view)
      if @state == :check_drag
        # Released effectively immediately?
        # Check distance just in case
        dx = x - @drag_start_screen[0]
        dy = y - @drag_start_screen[1]
        dist = Math.sqrt(dx*dx + dy*dy)
        
        if dist < 5 # pixels threshold
           # It was a CLICK. Enter Moving state.
           @state = :moving
        else
           # It was a micro-drag that ended.
           commit_move
           @state = :idle
        end
      elsif @state == :dragging
        # End of standard drag
        commit_move
        @state = :idle
      end
      # If :moving, button up does nothing (waiting for second click)
      view.invalidate
    end
    
    def onMouseMove(flags, x, y, view)
      case @state
      when :idle
        # Hover logic
        new_index, new_type = hit_test(x, y, view)
        if new_index != @hovered_index || new_type != @hovered_type
          @hovered_index = new_index
          @hovered_type = new_type
          view.invalidate
        end
        
      when :check_drag
        # Check if moved enough to trigger dragging
        dx = x - @drag_start_screen[0]
        dy = y - @drag_start_screen[1]
        dist = Math.sqrt(dx*dx + dy*dy)
        if dist > 5
          @state = :dragging
          handle_drag(x, y, view)
        end
        
      when :dragging, :moving
        # Use dragging index (set in down)
        handle_drag(x, y, view)
      end
    end
    
    def commit_move
      @dragging_index = nil
      @dragging_type = nil
    end



    def suspend(view)
      view.invalidate
    end
    
    def resume(view)
      view.invalidate
    end
    
    def onViewChanged(view)
      view.invalidate
    end

    def hit_test(x, y, view)
      # Priority 1: Check FACES using 3D Raycast + Axis-Aligned Polygon Check
      # This avoids "behind camera" issues with screen_coords
      
      pick_ray = view.pickray(x, y)
      eye = view.camera.eye
      best_hit = nil
      best_dist = Float::INFINITY
      
      @planes_data.each_with_index do |data, i|
        verts = data[:face_vertices]
        next unless verts && verts.length >= 3
        
        # 1. Intersect Ray with Infinite Plane
        norm = data[:normal]
        pt_on_plane = data[:original_point]
        d_val = - (norm.x * pt_on_plane.x + norm.y * pt_on_plane.y + norm.z * pt_on_plane.z)
        world_plane = [norm.x, norm.y, norm.z, d_val]
        
        intersect_pt = Geom.intersect_line_plane(pick_ray, world_plane)
        
        if intersect_pt
          # 2. Check if Intersection Point is inside the Face Polygon
          # Strategy: Project to 2D based on face orientation (Dominant Axis)
          # This works regardless of Section Box rotation
          in_poly = false
          
          # Map 3D points to 2D for Point-in-Poly check
          nx, ny, nz = norm.x.abs, norm.y.abs, norm.z.abs
          
          if nz > nx && nz > ny
            # Normal is roughly Z-aligned (Top/Bottom-ish) -> Project to XY
            poly_2d = verts.map { |v| Geom::Point3d.new(v.x, v.y, 0) }
            check_pt = Geom::Point3d.new(intersect_pt.x, intersect_pt.y, 0)
            in_poly = Geom.point_in_polygon_2D(check_pt, poly_2d, true)
          elsif ny > nx
            # Normal is roughly Y-aligned (Front/Back-ish) -> Project to XZ
            poly_2d = verts.map { |v| Geom::Point3d.new(v.x, v.z, 0) }
            check_pt = Geom::Point3d.new(intersect_pt.x, intersect_pt.z, 0)
            in_poly = Geom.point_in_polygon_2D(check_pt, poly_2d, true)
          else
            # Normal is roughly X-aligned (Left/Right-ish) -> Project to YZ
            poly_2d = verts.map { |v| Geom::Point3d.new(v.y, v.z, 0) }
            check_pt = Geom::Point3d.new(intersect_pt.y, intersect_pt.z, 0)
            in_poly = Geom.point_in_polygon_2D(check_pt, poly_2d, true)
          end
          
          if in_poly
            dist = eye.distance(intersect_pt)
            if dist < best_dist
              best_dist = dist
              best_hit = [i, :face]
            end
          end
        end
      end
      
      return best_hit if best_hit
      
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
        # Refresh data now using optimized cached group
        refresh_data
        view.invalidate
      end
    end


    def draw(view)
      return unless @planes_data && @planes_data.any?
      
      # Use shared drawing utilities
      # Use shared drawing utilities with Magenta 3px style
      Skalp::BoxSection::SkalpDrawHelper.draw_bounds(view, @planes_data, { color: Sketchup::Color.new(255, 0, 255), width: 3, stipple: "" })
      
      # Draw Drag Guide (Grey Dotted Line)
      if @dragging_index
         # draw_drag_guide(view)
      end
      
      @planes_data.each_with_index do |data, i|
        # Highlight if hovered OR if currently being dragged.
        # This ensures the highlight persists during the interaction ("Click-Move-Click").
        is_highlighted = (@hovered_index == i) || (@dragging_index == i)
        
        if is_highlighted
          Skalp::BoxSection::SkalpDrawHelper.draw_face_highlight(view, data[:face_vertices], data[:name], 25)
        end
        
        # Draw Plus (Dynamic Size)
        pt = data[:original_point]
        pixel_size = 15
        model_size = view.pixels_to_model(pixel_size, pt)
        model_size = 15.0.inch if model_size == 0
        
        # Draw Plus Handles (Restored as visual anchor, interaction remains on full face)
        plus_color = Skalp::BoxSection::SkalpDrawHelper.get_color(data[:name])
        plus_color.alpha = 255 # opaque handles
        width = is_highlighted ? 5 : 3
        # method signature: draw_plus(view, center, normal, face_name, highlighted, arm_size, color_override)
        # We pass: view, pt, normal, name, is_highlighted, model_size, plus_color
        Skalp::BoxSection::SkalpDrawHelper.draw_plus(view, pt, data[:normal], data[:name], is_highlighted, model_size, plus_color)
      end
    end
    
    def draw_drag_guide(view)
      return unless @dragging_index && @drag_start_point
      
      data = @planes_data[@dragging_index]
      normal = data[:normal]
      current_pt = data[:original_point]
      
      # User Request: Magenta, 3px lines
      view.drawing_color = Sketchup::Color.new(255, 0, 255)
      view.line_width = 3
      view.line_stipple = "" # Solid line for better visibility with thickness? Or kept dotted?
      # User said "modify tool toont geen grijze stippellijn... replace by magenta 3px".
      # Usually thick lines don't stipple well in SU. Let's try solid first or large stipple.
      # User didn't explicitly say "dotted" for magenta, just "replace grey dotted by magenta 3px".
      
      len = 1000.m
      p1 = current_pt.offset(normal, len)
      p2 = current_pt.offset(normal.reverse, len)
      view.draw(GL_LINES, [p1, p2])
    end
  end
end
