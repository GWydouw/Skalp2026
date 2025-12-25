require 'sketchup.rb'

module Skalp
  module BoxSection
    class GlobalOverlay < Sketchup::Overlay
      GRIP_RADIUS = 15 unless defined?(GRIP_RADIUS) # screen pixels
      attr_reader :hovered_index


      def initialize
        super('skalp.box_section.overlay', 'Box Section')
        @hovered_index = nil
      end


      def draw(view)
        box_section = Skalp::BoxSection.get_active_box_section
        return unless box_section && box_section.valid?

        @planes_data = Skalp::BoxSection.get_section_planes_data
        return unless @planes_data && @planes_data.any?

        # Use shared drawing utilities
        DrawHelper.draw_bounds(view, @planes_data)
        
        @planes_data.each_with_index do |data, i|
          is_hovered = (@hovered_index == i)
          DrawHelper.draw_face_highlight(view, data[:face_vertices], data[:name]) if is_hovered
          
          # Grip always keeps its color, just gets thicker on hover (handled by DrawHelper)
          DrawHelper.draw_plus(view, data[:original_point], data[:normal], data[:name], is_hovered, nil)
        end


      end

      def onLButtonDown(flags, x, y, view)
        # puts "Overlay Click: #{x},#{y} Hovered: #{@hovered_index}"
        return false unless @hovered_index
        
        # Clicked on a grip! Activate tool directly.
        Sketchup.active_model.select_tool(Skalp::BoxSectionAdjustTool.new)
        return true # Consume execution
      end

      def onMouseMove(flags, x, y, view)
        unless @planes_data
          @planes_data = Skalp::BoxSection.get_section_planes_data
          # puts "Overlay Initial Data Load: #{@planes_data ? 'Found' : 'Nil'}"
        end
        return unless @planes_data

        
        new_hover = nil
        @planes_data.each_with_index do |data, i|
          screen_pt = view.screen_coords(data[:original_point])
          next unless screen_pt
          dist = Math.sqrt((screen_pt.x - x)**2 + (screen_pt.y - y)**2)
          if dist <= GRIP_RADIUS
            new_hover = i
            break
          end
        end
        
        if new_hover != @hovered_index
          @hovered_index = new_hover
          view.invalidate
        end
      end
    end
  end
end

