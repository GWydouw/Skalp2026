module Skalp
  require 'pp'
  #require 'Skalp_hatchpatterns'

  class Polygon3D
    attr_accessor :points, :face, :transformation
    attr_reader :plane, :normal, :ccw

    def initialize(params)
      @transformation = params[:transformation]
      @face = params[:face]
      @loop = params[:loop]
      @plane = Skalp::transform_plane(@loop.face.plane, @transformation)
      @normal = Skalp::plane_normal(@plane)
      polygon_from_loop(params[:loop])
    end

    def points= (points_array, hole = false)
      if analyse_points(points_array)
        @points = points_array

        if (ccw_orientation && !hole) || (!ccw_orientation && hole)
          @points.reverse!
          @ccw = !@ccw
        end
      end
    end

    def reverse!
      @points.reverse!
    end

    def transform(transformation)
      polygon3d_trans = self.clone
      polygon3d_trans.points = []

      for point in @points
        polygon3d_trans.points << Skalp::transform_point(point, transformation)
      end

      return polygon3d_trans
    end

    def transform!(transformation)
      temp_points = []
      for point in @points
        temp_points << Skalp::transform_point(point, transformation)
      end

      @points = temp_points
    end

    def parrallel_to_plane?(plane)
      Skalp::plane_normal(@plane).parallel?(Skalp::plane_normal(plane))
    end

    def intersection_line_with_plane(plane)
      Geom.intersect_plane_plane(@plane, plane)
    end

    def draw(entities, linestyle = '') # "" (Solid Line), "." (Dotted Line), "-" (Short Dashes Line), "_" (Long Dashes Line), "-.-" (Dash Dot Dash Line)
      for n in 0..@points.size - 1
        n == @points.size-1 ? m = 0 : m = n + 1
        point1 = Geom::Point3d.new(@points[n][0], @points[n][1], @points[n][2])
        point2 = Geom::Point3d.new(@points[m][0], @points[m][1], @points[m][2])
        if linestyle == ''
          entities.add_line(point1, point2)
        else
          constline = entities.add_cline(point1, point2)
          constline.stipple = linestyle
        end
      end
    end

    private

    def polygon_from_loop(loop)
      @points = []
      for vertex in loop.vertices
        @points << vertex.position.transform(@transformation).to_a
      end

      for n in 0..@points.size-1
        p1 = Geom::Point3d.new(@points[n-2][0], @points[n-2][1], @points[n-2][2])
        p2 = Geom::Point3d.new(@points[n-1][0], @points[n-1][1], @points[n-1][2])
        p3 = Geom::Point3d.new(@points[n][0], @points[n][1], @points[n][2])
        if !Skalp::collinear(p1, p2, p3)

          @ccw = Skalp::ccw(p1.to_a, p2.to_a, p3.to_a)
        end
      end

      outer = loop.outer?

      if (@ccw && outer) || (!@ccw && !outer)
        @points.reverse!
        @ccw = !@ccw
      end
    end

    def side_face(face)
      @clip_points_LUT[face] = []
      check = Skalp::Set.new

      vertices = face.outer_loop.vertices

      vertex_last = vertices[-1]
      p_last = @transformation * vertex_last
      last_result = side_point(p_last)
      check << last_result if result != 0

      @clip_points_LUT[face] << p_last unless last_result == -1
      clip_point_count = 0

      for vertex in vertices
        p_new = @transformation * vertex
        result = side_point(p_new)
        check << result if result != 0

        if result * last_result < 0
          line = [p_last, p_new]
          p_section = Geom.intersect_line_plane(line, @plane)

          @point_from_edge_LUT[vertex.common_edge(vertex_last)] = p_section.to_a

          @clip_points_LUT[face] << p_section
          clip_point_count += 1
          last_result = result
        end

        if clip_point_count == 1 || clip_point_count == 2
          @clip_points_LUT[face] << p_new
        end

        p_last = p_new

      end

      if check.size == 1
        return check[0]
      elsif check.size > 1
        return 0 #face span
      else
        return 2 #ignore
      end
    end


  end

  def clip_face(face)

  end
end