require 'sketchup.rb'

module Skalp
  class BoxSectionAdjustTool
    # State tracking
    GRIP_RADIUS = 15 unless defined?(GRIP_RADIUS)
    DRAG_THRESHOLD = 5

    def initialize
      @hovered_index = nil
      @dragging_index = nil
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
      if @hovered_index || @dragging_index
        UI.set_cursor(634) # Hand cursor
      else
        UI.set_cursor(632) # Move cursor (since we are in adjust mode)
      end
    end

    def onKeyDown(key, repeat, flags, view)
    end

    def onMouseMove(flags, x, y, view)
      if @dragging_index
        handle_drag(x, y, view)
      else
        new_hover = hit_test(x, y, view)
        if new_hover != @hovered_index
          @hovered_index = new_hover
          view.invalidate
        end
      end
    end

    def onLButtonDown(flags, x, y, view)
      @dragging_index = hit_test(x, y, view)
      if @dragging_index
        @drag_start_point = @planes_data[@dragging_index][:original_point].clone
      end
    end

    def onLButtonUp(flags, x, y, view)
      @dragging_index = nil
      view.invalidate
    end

    def hit_test(x, y, view)
      @planes_data.each_with_index do |data, i|
        screen_pt = view.screen_coords(data[:original_point])
        next unless screen_pt
        dist = Math.sqrt((screen_pt.x - x)**2 + (screen_pt.y - y)**2)
        return i if dist <= GRIP_RADIUS
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
        # Normal vector transform: ignore translation
        local_norm = normal.transform(parent_trans.inverse) 
        
        Sketchup.active_model.start_operation("Adjust", true, false, true)
        plane_ent.set_plane([local_pt, local_norm])
        plane_ent.set_attribute(Skalp::BoxSection::DICTIONARY_NAME, 'original_point', local_pt.to_a)
        
        # Sync hit target position
        target = plane_ent.parent.entities.find { |e| e.get_attribute(Skalp::BoxSection::DICTIONARY_NAME, 'is_grip_target') }
        if target
          # Target group is in same context, so we just set its transform
          # Create_hit_target now draws at origin, so origin of group = position
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
        is_highlighted = (@hovered_index == i || @dragging_index == i)
        Skalp::BoxSection::DrawHelper.draw_face_highlight(view, data[:face_vertices], data[:name]) if is_highlighted
        Skalp::BoxSection::DrawHelper.draw_plus(view, data[:original_point], data[:normal], data[:name], is_highlighted)
      end
    end
  end
end
