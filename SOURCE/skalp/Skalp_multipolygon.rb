module Skalp
  require 'pp'

  class MultiPolygon
    attr_reader :normal
    attr_accessor :polygon_array

    def initialize(polygon_array = [])
      @polygon_array = polygon_array
    end

    def to_a
      @polygon_array
    end

    def to_lines
      lines = []
      tolerance = Skalp.to_inch(Sketchup.read_default('Skalp', 'tolerance2'))
      @polygon_array.each do |poly|
        for n in 0..poly.size-1
          lines << [Geom::Point3d.new(poly[n-1][0], poly[n-1][1], -1 * tolerance), Geom::Point3d.new(poly[n][0], poly[n][1], -1 * tolerance)]
        end
      end

      lines
    end

    def clone
      MultiPolygon.new(@polygon_array)
    end

    #delta in inches
    def offset(delta)
      new_clipperOffset
      MultiPolygon.new(Skalp.clipperOffset.offset(delta))
    end

    #delta in inches
    def outline(delta)
      temp_out = offset(delta/2)
      temp_in = offset(-delta/2)
      temp_out.difference!(temp_in)
      temp_out
    end

    def union(mpoly)
      set_subject_and_clipper(mpoly)
      MultiPolygon.new(Skalp.clipper.union(:non_zero, :non_zero))
    end

    def difference(mpoly)
      set_subject_and_clipper(mpoly)
      MultiPolygon.new(Skalp.clipper.difference(:non_zero, :non_zero))
    end

    def intersection(mpoly)
      set_subject_and_clipper(mpoly)
      MultiPolygon.new(Skalp.clipper.intersection(:non_zero, :non_zero))
    end

    def offset!(delta)
      new_clipperOffset
      @polygon_array = Skalp.clipperOffset.offset(delta)
      self
    end

    #delta in inches
    def outline!(delta)
      temp_out = offset(delta/2)
      temp_in = offset(-delta/2)
      @polygon_array = temp_out.difference!(temp_in)
      self
    end

    def union!(mpoly)
      set_subject_and_clipper(mpoly)
      @polygon_array = Skalp.clipper.union(:non_zero, :non_zero)
      self
    end

    def difference!(mpoly)
      set_subject_and_clipper(mpoly)
      @polygon_array = Skalp.clipper.difference(:non_zero, :non_zero)
      self
    end

    def intersection!(mpoly)
      set_subject_and_clipper(mpoly)
      @polygon_array = Skalp.clipper.intersection(:non_zero, :non_zero)
      self
    end

    def polygons
      loops = []
      @polygon_array.each do |poly|
        loops << create_loop(poly)
      end

      Skalp::Polygons.new(loops)
    end

    def meshes
      meshes = []
      polygons.polygons.each { |polygon| meshes << polygon.mesh if polygon.mesh.size > 2 }
      meshes
    end

    private

    def create_loop(polygon)
      loop = Skalp::Loop.new

      for n in 0..polygon.size - 1
        p0 = polygon[n-1] + [0.0]
        p1 = polygon[n] + [0.0]
        loop.add_line(Skalp::Line.new(p0, p1))
      end
      loop.loop_of_lines_to_points

      loop
    end

    def set_subject_and_clipper(mpoly)
      Skalp.clipper ? Skalp.clipper.clear! : (Skalp.clipper = Skalp::Clipper.new)
      Skalp.clipper.add_subject_poly_polygon(@polygon_array)
      Skalp.clipper.add_clip_poly_polygon(mpoly.to_a)
    end

    def new_clipperOffset
      Skalp.clipperOffset ? Skalp.clipperOffset.clear! : (Skalp.clipperOffset = Skalp::ClipperOffset.new)
      Skalp.clipperOffset.add_poly_polygon(@polygon_array)
    end
  end
end


#
#     def initialize(face = nil, transformation = Geom::Transformation.new, convert_to_2D = true)
#       @convert_to_2D = convert_to_2D
#       @polygon_array = []
#       @outline = self
#       @fill = self
#
#       if face
#         set_face(face, transformation)
#       else
#         @plane = [0, 0, 1, 0]
#         @normal = Geom::Vector3d.new(0, 0, 1)
#         @transformation = transformation
#         @transform2d = Geom::Transformation.new
#       end
#     end
#

#
#     def set_face(face, transformation = Geom::Transformation.new)
#       @face = face
#       @polygon_array = []
#       @transformation = transformation
#       @normal = @face.normal.transform(@transformation)
#       @plane = @transformation * @face.plane
#
#       @convert_to_2D ? (@transform2d = Skalp::transformation_to_2D(@plane)) : (@transform2d = Geom::Transformation.new)
#
#       @face.loops.each do |loop|
#         sub_poly = []
#         loop.vertices.each do |vertex|
#           point = vertex.position.transform(@transformation).transform(@transform2d)
#           sub_poly << [point.x, point.y]
#         end
#         sub_poly.reverse! if reversed?
#         @polygon_array << sub_poly
#       end
#     end
#
#
#     def reversed?
#       return false unless @face
#       @reversed || @reversed = ((@face.outer_loop.edges.first.reversed_in?(@face)) != (@normal.transform(@transformation).transform(@transform2d).z > 0.0))  #TODO moet hier geen rekening met de @transformation worden gehouden
#     end
#   end
# end
