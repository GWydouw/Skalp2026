# Skalp Patterns - plugin for SketchUp.
#
# Creates tilable png textures for use in SketchUp and Layout. Imports pattern definitions
# from standard ACAD.PAT pattern files.
#
# @author Skalp (C) 2014

module Skalp
  module SkalpHatch

    #axis aligned rectangle, 0,0 is left bottom
    #implements virtual canvas size in definition units with an extra outward offset defined by a given penwidth
    #it creates 4 boundary edges and 4 corner points to be used as clipping parameters during drawing on a png canvas
    class HatchTile
      attr_accessor :linethickness, :width, :height
      attr_reader :clip_corners, :clipmin, :clipmax_x, :clipmax_y

      def initialize(width = 0.0, height = 0.0)
        @width = width.to_f
        @height = height.to_f
        @linethickness = 0.0
        @not_ready = true
      end

      def linethickness=(linethickness = 0.0)
        @linethickness = linethickness
        updateclippingparams
      end

      def width=(width)
        @width = width
        updateclippingparams
      end

      def height=(height)
        @height = height
        updateclippingparams
      end

      def size=(width, height)
        @width, @height = width, height
        updateclippingparams
      end

      def direction_to(object2D)
        result = []
        @clip_corners.each_value do |pt|
          result << pt.side?(object2D)
        end
        (result.uniq.size == 1) ? result.first : 0
      end

      def intersect(object2D) #currently only Line2D supported
        updateclippingparams
        case object2D
          when Line2D # also takes Edge2D since Edge2D inherits from Line2D? should be tested!
            sectionpoints ||= []
            @clippingedges.each_value { |clipedge|
              point = clipedge.intersect(object2D)
              next unless clipedge.point_on_edge?(point)
              sectionpoints.reject! { |x| x.pointsequal?(point) } unless point.nil?
              if point != nil && clipedge.point_on_edge?(point) #TODO  && clipedge.point_on_edge?(point) might be not necessary > TEST needed
                sectionpoints << point
              end
            }
            if sectionpoints.size == 2
              Edge2D.new(sectionpoints.first, sectionpoints.last)
            else
              sectionpoints.first # return a cornerpoint
            end
          when Edge2D
            raise "not yet implemented: intersect Hatchtile with Edge2D"
        end

      end

      def inside?(object2D)
        updateclippingparams
        case object2D
          when Point2D
            point_inside?(object2D)
          when Edge2D
            point_inside?(object2D.p1) || point_inside?(object2D.p2)
          when Line2D
            raise "not yet for Line2D"
        end
      end

      def point_outside?(p) #p.class == Point2D
        updateclippingparams
        p.x < clipmin || clipmax_x < p.x || p.y < clipmin || clipmax_y < p.y
      end

      def point_inside?(p) #p.class == Point2D
        updateclippingparams
        @clipmin <= p.x && p.x <= @clipmax_x && @clipmin <= p.y && p.y <= @clipmax_y
      end

      def point_above?(p)
        updateclippingparams
        p.y > clipmax_y
      end

      def point_under?(p)
        updateclippingparams
        p.y < clipmin
      end

      def point_left?(p)
        updateclippingparams
        p.x < clipmin
      end

      def point_right?(p)
        updateclippingparams
        p.x > clipmax_x
      end


      # transforms the entire HatchTile
      def transform!(hatch_transformation)
        raise 'Not Yet Implemented'
      end

      def updateclippingparams
        return unless @not_ready
        @not_ready = false
        @clipmin = -linethickness
        @clipmax_x = @width + linethickness
        @clipmax_y = @height + linethickness

        if (@width + 2 * linethickness) * (@height + 2 * linethickness) != 0.0
          @clip_corners = {
              :bottom_left => Point2D.new(@clipmin),
              :bottom_right => Point2D.new(@clipmax_x, @clipmin),
              :top_left => Point2D.new(@clipmin, @clipmax_y),
              :top_right => Point2D.new(@clipmax_x, @clipmax_y)
          }
          @clippingedges = {
              :left => Edge2D.new(@clip_corners[:bottom_left], @clip_corners[:top_left]),
              :bottom => Edge2D.new(@clip_corners[:bottom_right], @clip_corners[:bottom_left]),
              :right => Edge2D.new(@clip_corners[:top_right], @clip_corners[:bottom_right]),
              :top => Edge2D.new(@clip_corners[:top_left], @clip_corners[:top_right])
          }
        end
      end
    end #class HatchTile

  end #module SkalpHatch
end