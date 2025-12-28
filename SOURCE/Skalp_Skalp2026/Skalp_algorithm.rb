require "pp"
module Skalp
  class SectionAlgorithm # moet nog voor gezorgd worden dat er niet steeds een nieuwe klasse aangemaakt wordt
    include Skalp

    @@count_sections = 0

    attr_accessor :point_LUT, :sectionresult

    def calculate_section(solid, transformation, sectionplane)
      clear!

      return unless sectionplane.skpSectionPlane.valid?

      @count = 0

      @solid = solid
      @transformation = transformation
      @sectionplane = sectionplane.skpSectionPlane
      @plane = sectionplane.plane
      @section_transformation = sectionplane.transformation
      @num_version = Sketchup.read_default("Skalp", "uptodate")
      @point_LUT = {}
      @lines_LUT = {}
      @start_calculate = false
      calculate if check_distance && Skalp.ready
    end

    def clear!
      @count = 0
      @solid = nil
      @transformation = nil
      @sectionplane = nil
      @plane = nil
      @section_transformation = nil
      @num_version = nil
      @point_LUT = {}
      @lines_LUT = {}
      @sectionresult = nil
    end

    def self.count_sections_reset
      @@count_sections = 0
    end

    def polygons
      @sectionresult
    end

    def calculate
      return if @start_calculate

      @start_calculate = true

      @@count_sections += 1
      @vertices2D = Skalp::Set.new
      @loops = []

      @faces = remove_parallel_faces(Skalp.get_definition_entities(@solid).grep(Sketchup::Face))

      section_face_with_sectionplane
      sort_loops_out_of_points if @vertices2D != []
      @sectionresult = Skalp::Polygons.new(@loops)
    end

    def remove_parallel_faces(faces)
      faces_parallel_removed = []
      normal = [@plane[0], @plane[1], @plane[2]]

      for face in faces
        facenormal = @transformation * face.normal
        facenormal.normalize!

        faces_parallel_removed << face if facenormal != normal && facenormal.reverse != normal
      end

      faces_parallel_removed
    end

    def check_distance
      return true if @solid.is_a?(Sketchup::Model)

      begin
        bb = @solid.bounds
        transformation = @transformation * @solid.transformation.inverse

        cpt = transformation * bb.center
        ptt = transformation * bb.corner(7)

        d = cpt.distance(ptt).abs
        dp = cpt.distance_to_plane(@plane).abs

        d >= dp
      rescue NoMethodError
        true
      end
    end

    attr_reader :sectionplane

    def section_face_with_sectionplane
      point_from_edge_LUT = {}
      point_from_vertex_LUT = {}

      @startpoint = nil
      @vertex2D_LUT = {}

      for face in @faces
        next unless face.class == Sketchup::Face

        # next if face.hidden?   #fix support question Tom Kaneko about hidden face to section two walls glued together.
        pts = Skalp::Set.new
        for edge in face.edges

          # ["eval:116:in `block (2 levels) in section_face_with_sectionplane'", "eval:102:in `each'", "eval:102:in `block in section_face_with_sectionplane'"
          # , "eval:99:in `each'", "eval:99:in `section_face_with_sectionplane'", "eval:45:in `calculate'", "eval:23:in `initialize'", "eval:112:in `new'",
          # "eval:112:in `update_section_result'", "eval:224:in `calculate_section'", "eval:230:in `get_section_results'", "eval:241:in `block in get_section_results'",
          # "eval:239:in `each'", "eval:239:in `get_section_results'", "eval:241:in `block in get_section_results'", "eval:239:in `each'", "eval:239:in
          # `get_section_results'", "eval:241:in `block in get_section_results'", "eval:239:in `each'", "eval:239:in `get_section_results'", "eval:241:in
          # `block in get_section_results'", "eval:239:in `each'", "eval:239:in `get_section_results'", "eval:89:in `get_section2Ds'", "eval:31:in `create_section'",
          # "eval:25:in `update'", "eval:82:in `calculate_section'", "eval:3:in `ccA'", "eval:81:in `select_action'", "eval:81:in

          next unless edge.class == Sketchup::Edge
          next unless edge.start.class == Sketchup::Vertex # check for strange SU behaviour
          next unless edge.end.class == Sketchup::Vertex # check for strange SU behaviour

          if point_from_vertex_LUT[edge.start]
            pts << point_from_vertex_LUT[edge.start]
            next
          end

          if point_from_vertex_LUT[edge.end]
            pts << point_from_vertex_LUT[edge.end]
            next
          end

          if point_from_edge_LUT[edge]
            pts << point_from_edge_LUT[edge]
          else
            line = [@transformation * edge.start.position, @transformation * edge.end.position]
            pt = Geom.intersect_line_plane(line, @plane)

            if pt == @transformation * edge.start.position
              point_from_vertex_LUT[edge.start] = pt.to_a
              pts << point_from_vertex_LUT[edge.start]
              next
            end

            if pt == @transformation * edge.end.position
              point_from_vertex_LUT[edge.end] = pt.to_a
              pts << point_from_vertex_LUT[edge.end]
              next
            end

            if pointOnEdge(pt, line)
              pts << pt.to_a
              point_from_edge_LUT[edge] = pt.to_a
            end
          end
        end

        pts = points_sort(pts.to_a) if pts

        if pts && pts.size > 2
          for n in 0..(pts.size - 2)

            p1 = transform_point_by_transformation(pts[n], @section_transformation)
            p2 = transform_point_by_transformation(pts[n + Skalp.num], @section_transformation)

            calculate_startpoint(p1) if n == 0
            calculate_startpoint(p2) if n == pts.size - 2

            pmid = Skalp.midpoint(pts[n], pts[n + Skalp.num])

            face_classify_point = face.classify_point(@transformation.inverse * pmid)
            if [Sketchup::Face::PointInside, Sketchup::Face::PointOnVertex, Sketchup::Face::PointOnEdge].include?(face_classify_point)
              set_neigbours(p1, p2)
            end
          end

        elsif pts && pts.size == 2
          p1 = transform_point_by_transformation(pts.first, @section_transformation)
          p2 = transform_point_by_transformation(pts.last, @section_transformation)
          calculate_startpoint(p1)
          calculate_startpoint(p2)

          set_neigbours(p1, p2)
        end
      end
    end

    def calculate_startpoint(p1)
      if @startpoint
        @startpoint = p1 if p1.x < @startpoint.x
      else
        @startpoint = p1
      end
    end

    def set_neigbours(p1, p2)
      if @vertex2D_LUT[p1]
        @vertex2D_LUT[p1].add(p2)
      else
        vertex2D = Vertex2D.new(p1)
        vertex2D.add(p2)
        @vertices2D << vertex2D
        @vertex2D_LUT[p1] = vertex2D
      end

      if @vertex2D_LUT[p2]
        @vertex2D_LUT[p2].add(p1)
      else
        vertex2D = Vertex2D.new(p2)
        vertex2D.add(p1)
        @vertices2D << vertex2D
        @vertex2D_LUT[p2] = vertex2D
      end
    end

    def get_startpoint
      @startpoint = nil
      for vertex2D in @vertices2D
        if @startpoint
          @startpoint = vertex2D.point if vertex2D.point.x < @startpoint.x
        else
          @startpoint = vertex2D.point
        end
      end
    end

    def sort_loops_out_of_points
      return unless @num_version

      until @vertices2D.empty?
        count = 1

        vertices = Skalp::Set.new
        sorted_vertices_points = []
        vertices_points = []
        newloop = Loop.new

        center_vertex = @vertex2D_LUT[@startpoint]
        return unless center_vertex

        next_vertex = @vertex2D_LUT[center_vertex.get_start_direction]
        start_vertex = center_vertex
        next_start_vertex = next_vertex

        begin
          vertices << center_vertex
          vertices_points << center_vertex.point
          sorted_vertices_points << center_vertex.point
          newloop.add_line(Line.new(center_vertex.point, next_vertex.point))
          prev_point = center_vertex.point
          center_vertex = next_vertex
          next_vertex = @vertex2D_LUT[center_vertex.next_point(prev_point)]
        end until ((start_vertex.point == center_vertex.point) && (next_vertex.point == next_start_vertex.point))

        if newloop.size > 2 && !newloop.open?
          @loops << newloop
        else
          newloop = nil
        end

        @vertices2D -= vertices

        for vertex in @vertices2D
          vertex.remove_neighbours(vertices_points)
        end

        newloop.finish_loop(sorted_vertices_points) if newloop && !newloop.open?

        next if @vertices2D.empty?

        @startpoint = nil

        until @vertices2D.empty? || (@startpoint && @vertex2D_LUT[@startpoint].neighbours.size > 0)
          get_startpoint
          @vertices2D.delete(@vertex2D_LUT[@startpoint]) if @vertex2D_LUT[@startpoint].neighbours.size == 0
        end
      end
    end

    def clean_vertices(vertices_to_remove)
    end
  end

  class Polygons
    attr_reader :polygons

    def initialize(loop_collection)
      @loop_collection = loop_collection
      @polygons = []
      create_polygons
    end

    def inspect
      "#<#{self.class}:#{object_id} @polygons=#{@polygons.size}>"
    end

    private

    def create_polygons
      # find parent loops
      for loop_to_process in @loop_collection
        next if loop_to_process.nosurface

        loops = @loop_collection - [loop_to_process]
        for loop in loops
          next if loop.nosurface

          loop_to_process.add_parent(loop) if loop_to_process.inside?(loop)
        end
      end

      # if number parents = odd then loop is outerloop
      for loop in @loop_collection
        next if loop.nosurface

        next unless loop.parents.length.even?

        polygon = Polygon.new(loop)
        @polygons << polygon
        for innerloop in @loop_collection
          next if innerloop.nosurface

          if innerloop.parents.include?(loop) && (innerloop.parents.length == (loop.parents.length + 1))
            polygon.add_innerloop(innerloop)
          end
        end
      end
    end
  end

  class Polygon
    include Skalp

    def initialize(outerloop)
      @outerloop = outerloop
      @innerloops = []
      @vertices = []
      @poly_array = []
      @hatch = "Skalp default"
      @layer = Skalp.active_model.skpModel.layers[0]
      @hidden = false
    end

    def inspect
      "#<#{self.class}:#{object_id} @outerloop=#{@outerloop}>"
    end

    attr_reader :innerloops, :outerloop

    def each_line(&block)
      loops = [@outerloop] + @innerloops

      return loops.collect { |loop| loop.each_line } unless block_given?

      loops.collect { |loop| loop.each_line(&block) }
    end

    def vertices
      @outerloop.vertices # vereenvoudigde versie zonder innerloops
    end

    def to_a
      return @poly_array unless @poly_array.empty?

      sub_poly = []
      @outerloop.vertices.each do |vertex|
        sub_poly << [vertex.x, vertex.y]
      end
      @poly_array << sub_poly

      @innerloops.each do |loop|
        sub_poly = []
        loop.vertices.each do |vertex|
          sub_poly << [vertex.x, vertex.y]
        end
        @poly_array << sub_poly
      end

      @poly_array
    end

    def mesh
      return unless @outerloop

      @outerloop.reverse! unless @outerloop.ccw?
      mesh_outerloop = @outerloop.dup
      mesh_innerloops = @innerloops.dup

      while mesh_innerloops != []
        innerloop = find_loop_with_highest_x(mesh_innerloops)
        connectionline = find_connectionline_between_outerloop_and_a_given_innerloop(mesh_outerloop, innerloop) # startpoint is on outerloop, endpoint on innerloop
        if connectionline
          mesh_outerloop = merge_outerloop_with_innerloop(mesh_outerloop, innerloop, connectionline)
          mesh_innerloops.delete(innerloop)
        end
      end

      mesh = []

      for line in mesh_outerloop.lines
        mesh << line.startpoint
      end

      mesh
    end

    def add_innerloop(innerloop)
      @innerloops << innerloop
    end

    def merge_outerloop_with_innerloop(outerloop, innerloop, connectionline)
      return outerloop unless innerloop && connectionline

      connectionline_reverse = connectionline.dup.reverse!
      outerloop.reverse! unless outerloop.ccw?
      innerloop.reverse! if innerloop.ccw?

      merged_loop = Loop.new
      insert_edge = outerloop.find_insert_edge(connectionline)

      for edge in outerloop.edges
        merged_loop.add_connectionline(edge)
        next unless insert_edge == edge

        merged_loop.add_connectionline(connectionline)
        for innerloop_edge in innerloop.sorted_edges(connectionline.endpoint)
          merged_loop.add_connectionline(innerloop_edge)
        end
        merged_loop.add_connectionline(connectionline_reverse)
      end

      merged_loop
    end

    ################################ ALGORITHM
    def find_connectionline_between_outerloop_and_a_given_innerloop(outerloop, innerloop)
      connectionline = nil
      m = innerloop.max_x_point # 1. Zoek de innerpolygoon met de maximum x-waarde en neem van de deze polygoon het punt met de maximum x-waarde. Dit is punt M.
      i = find_intersection_ray_with_outerloop(outerloop, m) # 2. Snij de ray welke start vanuit het punt gevonden in (1) met richting x met alle zijde van de outerpolygoon en vind zo het dichst gelegen I zichtbare punt tot M op deze ray
      return unless i

      if outerloop.contains_point(i.first)
        # if outerloop.vertices.include?(i.first) then   				# 3. Als I een hoekpunt is van de outerpolygoon, dan hebben we onze verbindingslijn gevonden namelijk MI en stopt het algorithme
        connectionline = Line.new(i.first.to_a, m)
      else
        p = i.last.max_x_point # 4. Anders is I een punt liggend op het lijnstuk van de outerloop. Neem van dit lijnstuk het begin- of eindpunt met de grootste x-waarde van dit lijnstuk. Dit punt is P.
        reflex_points_in_triangle = find_reflex_points_in_triangle(outerloop, m, i.first, p) # 5. Zoek in de reflex punten van de outerloop (uitgezonderd P, indien deze reflex zou zijn). Indien al deze punten volledig buiten de driehoek MIP liggen, dan is MP de verbindingslijn en stopt het algorithme.
        if reflex_points_in_triangle == []
          connectionline = Line.new(p, m)
        elsif reflex_points_in_triangle.length == 1
          connectionline = Line.new(reflex_points_in_triangle.first, m) # 6. Anders, minstens ��n reflex punt ligt in MIP. Zoek nu het punt R, uit deze punten, dat de kleinste hoek geeft tss de ray en MR. De MR met de kleinste hoek is de gezochte verbindingslijn en ons algorithme stop.
        else
          points_with_smallest_angle = find_points_with_smallest_angle(reflex_points_in_triangle, m, i)
          if points_with_smallest_angle.length == 1
            connectionline = Line.new(points_with_smallest_angle.first, m)
          else
            connectionline = Line.new(closest_point_to_m(points_with_smallest_angle, m), m) # Indien er meerdere punten zijn welke dezelfde kleinste hoek opleveren, is het punt welk het dichtste bij M ligt het te zoeken punt.
          end
        end
      end
      connectionline.type = 3
      connectionline
    end

    # subfunctions algorithm
    def find_intersection_ray_with_outerloop(outerloop, m)
      ray = [m, Geom::Vector3d.new(1, 0, 0)]
      intersection_result = nil
      pointsfound = []
      for edge in outerloop.edges
        next unless edge.max_x_point.x >= m.x

        sectionPt = Geom.intersect_line_line(ray,
                                             [Geom::Point3d.new(edge.startpoint.x, edge.startpoint.y, edge.startpoint.z),
                                              Geom::Point3d.new(edge.endpoint.x, edge.endpoint.y, edge.endpoint.z)])
        next if sectionPt.nil?

        if pointOnEdge(sectionPt, [to_point(edge.startpoint), to_point(edge.endpoint)])
          intersection_result = [sectionPt, edge]
          pointsfound << intersection_result
        end
      end
      # dichtste punt zoeken

      points = []
      for p in pointsfound
        points << p.first
      end
      cp = closest_point_to_m(points, m)

      for p in pointsfound
        if p.first == cp
          intersection_result = p
          break
        end
      end

      intersection_result
    end

    def find_reflex_points_in_triangle(outerloop, m, i, p)
      triangle = [m, i, p]
      points_inside_triangle = []
      reflex_vertices = outerloop.reflex_vertices - [p]
      reflex_vertices.each do |vertex|
        points_inside_triangle << vertex if Geom.point_in_polygon_2D(vertex, triangle, true)
      end
      points_inside_triangle
    end

    def closest_point_to_m(points_with_smallest_angle, m)
      closest_point = nil
      for pt in points_with_smallest_angle
        if closest_point.nil?
          closest_point = pt
        elsif m.distance(pt) < m.distance(closest_point)
          # closest_point = pt if distance_between_points(m, pt) < distance_between_points(m, closest_point)
          closest_point = pt
        end
      end
      closest_point
    end

    def find_loop_with_highest_x(loops)
      loop_with_highest_x = nil

      for loop in loops
        if loop_with_highest_x.nil?
          loop_with_highest_x = loop
        elsif loop.max_x_point.x > loop_with_highest_x.max_x_point.x
          loop_with_highest_x = loop
        end
      end
      loop_with_highest_x
    end

    def find_points_with_smallest_angle(reflex_points_in_triangle, m, i)
      smallest_angle = nil
      points = []
      for reflex_point in reflex_points_in_triangle
        angle = angle_3_points(i.first, m, reflex_point) # in case this should ever fail: recreate and add a new angle_3_points methode based on commit 10 januari 2014 11:41:05 CET
        if smallest_angle.nil?
          smallest_angle = angle
          points << reflex_point
        elsif angle < smallest_angle
          smallest_angle = angle
          points = []
          points << reflex_point
        elsif angle == smallest_angle
          points << reflex_point
        end
      end
      points
    end
    ################################
  end

  class Vertex2D
    attr_accessor :point, :neighbours

    def initialize(point)
      @point = point
      @neighbours = []
      @vector = Geom::Vector3d.new(1, 0, 0)
      @startvector = Geom::Vector3d.new(0, -1, 0)
      @sorted = true
      @angle_check = {}
      @angle_check_start = {}
    end

    def remove_neighbours(vertices_points)
      @neighbours -= vertices_points
    end

    def add(point)
      @neighbours << point
      @sorted = false if @neighbours.size > 2
    end

    def next_point(prev_point)
      sort unless @sorted
      @neighbours[@neighbours.index(prev_point) - 1]
    end

    def get_start_direction
      start_next_point = @neighbours.sort do |neighbour1, neighbour2|
        start_angle(neighbour2) <=> start_angle(neighbour1)
      end
      start_next_point.last
    end

    def sort
      @neighbours.sort! { |neighbour1, neighbour2| angle(neighbour2) <=> angle(neighbour1) }
      @sorted = true
    end

    def angle(neighbour)
      vector2 = Geom::Vector3d.new(neighbour.x - @point.x, neighbour.y - @point.y, 0.0)
      angle = @vector.angle_between vector2
      direction = @vector * vector2
      angle = 360.degrees - angle if direction.z < 0.0
      angle
    end

    def start_angle(neighbour)
      vector2 = Geom::Vector3d.new(neighbour.x - @point.x, neighbour.y - @point.y, 0.0)
      angle = @startvector.angle_between vector2
      direction = @startvector * vector2
      angle = 360.degrees - angle if direction.z < 0.0
      angle
    end
  end

  class Loop
    include Skalp

    attr_accessor :polygon_parent, :is_outerloop, :is_innerloop, :handle

    @count = 0
    class << self
      attr_accessor :count
    end

    def initialize
      @handle = nil
      @loop_of_lines = []
      @edges = @loop_of_lines # later op kuisen
      @reflex_vertices = []
      @convex_vertices = []
      @vertices = []
      @max_x_point = nil
      @parents = []
      @collinear_points = []
      self.class.count += 1
      @double_surface = 0.0
    end

    def last
      @edges.last
    end

    def open?
      @double_surface.abs == 0.0
    end

    def closed?
      !open?
    end

    def size
      @edges.size
    end

    def add_line(line)
      @loop_of_lines << line
      add_surface(line)
    end

    def add_connectionline(line)
      if @loop_of_lines == []
        @loop_of_lines << line
      elsif points_equal?(@loop_of_lines.last.endpoint,
                          line.startpoint) || points_equal?(@loop_of_lines.last.endpoint, line.endpoint)
        line.reverse! if points_equal?(@loop_of_lines.last.endpoint, line.endpoint)
        @loop_of_lines << line
        if points_equal?(line.endpoint, @loop_of_lines.first.startpoint)
          loop_of_lines_to_points
          sort_reflex_convex
        end
      elsif points_equal?(@loop_of_lines.first.startpoint,
                          line.startpoint) || points_equal?(@loop_of_lines.first.startpoint, line.endpoint)
        line.reverse! if points_equal?(@loop_of_lines.first.startpoint, line.startpoint)
        @loop_of_lines.unshift line
        if points_equal?(line.startpoint, @loop_of_lines.last.endpoint)
          loop_of_lines_to_points
          sort_reflex_convex
        end
      end
    end

    def finish_loop(vertices_points)
      @vertices = vertices_points
      sort_reflex_convex

      n = 0
      while @vertices.last == @vertices[1] && n < @vertices.size
        n += 1
        @vertices.rotate!
        @loop_of_lines.rotate!
      end
    end

    def add_surface(line)
      @double_surface += ((line.startpoint.x * line.endpoint.y) - (line.endpoint.x * line.startpoint.y)) # /2.0  for real surface
    end

    def surface
      @double_surface / 2.0
    end

    def nosurface
      return true if surface < 0.000000001 && surface > -0.000000001

      false
    end

    def inspect
      "#<#{self.class}:#{object_id} @vertices=#{@vertices.size}>"
    end

    def reverse!
      @vertices.reverse!
      @loop_of_lines.reverse!
      for line in @loop_of_lines
        line.reverse!
      end
    end

    attr_reader :parents, :vertices, :edges, :reflex_vertices

    def longest_edge(step = false)
      max_edge = nil
      @edges.each do |edge|
        next unless edge.is_a?(Sketchup::Edge) || edge.is_a?(Skalp::Line)

        max_edge ||= edge
        max_edge = edge if edge.length > max_edge.length
      end
      max_edge
    end

    def index(edge = nil)
      if edge.nil?
        @edges.index
      else
        @edges.index(edge)
      end
    end

    def ccw?
      loop_ccw?(self)
    end

    def contains_point(pt)
      vertices.any? { |v| points_equal?(v, pt) }
    end

    def find_insert_edge(connectionline)
      outer_edges = []
      connection_edges = []
      for edge in @edges

        if points_equal?(edge.startpoint,
                         connectionline.startpoint) || points_equal?(edge.endpoint, connectionline.startpoint)
          if edge.type == 4
            connection_edges << edge
          elsif edge.type != 3
            outer_edges << edge
          end
        end
      end
      startedge = if points_equal?(outer_edges[0].endpoint,
                                   connectionline.startpoint)
                    outer_edges[0]
                  else
                    outer_edges[1]
                  end
      connection_edge_with_angle = {}

      for edge in connection_edges
        connection_edge_with_angle[edge] = angle_3_points(startedge.startpoint, startedge.endpoint, edge.endpoint)
      end

      connection_angle = angle_3_points(startedge.startpoint, startedge.endpoint, connectionline.endpoint)
      connection_edge_with_angle[connectionline] = connection_angle
      connection_edge_with_angle[startedge] = 0
      sorted_edges_array = connection_edge_with_angle.sort { |a, b| a[1] <=> b[1] }
      sorted_edges_array[sorted_edges_array.index([connectionline, connection_angle]) - 1].first
    end

    def sorted_edges(startpoint)
      sorted_edges = @edges.dup

      size = sorted_edges.size
      n = 0

      until points_equal?(sorted_edges.first.startpoint, startpoint) || n > size
        sorted_edges << sorted_edges.shift
        n += 1
      end

      sorted_edges
    end

    def lines
      @loop_of_lines
    end

    def each_line(&)
      return @loop_of_lines.each unless block_given?

      @loop_of_lines.each(&)
    end

    def loop_of_lines_to_points
      for l in @loop_of_lines
        @vertices << l.startpoint
      end
    end

    def inside?(loop)
      test = true
      for v in vertices
        unless Geom.point_in_polygon_2D(v, loop.vertices, true)
          test = false
          break
        end
      end
      test
    end

    def add_parent(parent)
      @parents << parent
    end

    def max_x_point
      Skalp.max_x_point(@vertices)
    end

    def sort_reflex_convex
      return unless @vertices.length > 3

      for i in 0..@vertices.length - 1
        if ccw(@vertices.last, @vertices.first, @vertices[1])
          @reflex_vertices << @vertices.first
        else
          @convex_vertices << @vertices.first
        end
        @vertices << @vertices.shift
      end
    end
  end

  class Line
    include Skalp

    attr_accessor :startpoint, :endpoint, :type # type:{0=>new basic line, 1=>basic line, 2=>construction line, 3=>connection line, 4=>reversed connection line}

    TOLERANCE = 0.001 unless defined? TOLERANCE

    def initialize(startpoint, endpoint)
      @startpoint = startpoint
      @endpoint = endpoint
      @type = 0
    end

    def other_point(point)
      point == @startpoint ? endpoint : startpoint
    end

    def ==(other)
      (Skalp.points_equal?(@startpoint, other.startpoint) && Skalp.points_equal?(@endpoint, other.endpoint)) ||
        (Skalp.points_equal?(@startpoint, other.endpoint) && Skalp.points_equal?(@endpoint, other.startpoint))
    end

    alias eql? ==

    def hash
      pt1_hash_str = "#{(startpoint.x.to_f / TOLERANCE).to_i}#{(startpoint.y.to_f / TOLERANCE).to_i}#{(startpoint.z.to_f / TOLERANCE).to_i}"
      pt2_hash_str = "#{(endpoint.x.to_f / TOLERANCE).to_i}#{(endpoint.y.to_f / TOLERANCE).to_i}#{(endpoint.z.to_f / TOLERANCE).to_i}"

      if pt1_hash_str < pt2_hash_str
        (pt1_hash_str + pt2_hash_str).to_i
      else
        (pt2_hash_str + pt1_hash_str).to_i
      end
    end

    def reverse!
      @startpoint, @endpoint = @endpoint, @startpoint
      if @type == 3
        @type = 4
      else
        @type == 4 ? @type = 3 : true
      end
      self
    end

    def to_a
      [@startpoint, @endpoint]
    end

    # TODO: callers in Skalp nakijken of dit mag ipv wat hierboven staat
    def to_a
      [[@startpoint.x, @startpoint.y, @startpoint.z], [@endpoint.x, @endpoint.y, @endpoint.z]]
    end

    def inspect
      "#{self} #{to_a}"
    end

    def max_x_point
      Skalp.max_x_point(to_a)
    end

    def length
      @startpoint.distance(@endpoint)
    end

    def angle
      x = @endpoint.x - @startpoint.x
      y = @endpoint.y - @startpoint.y
      Math.atan2(y, x)
    end
  end # Line

  class Point
    include Skalp

    TOLERANCE = 0.001 unless defined? TOLERANCE

    @@points = {}
    @@index = 0

    attr_accessor :point, :edge

    def initialize(point)
      @point = point
      @point << 0.0 if @point.size == 2 # if point is a 2D point
    end

    def set_index
      return if @@points.include?(self)

      @@index += 1
      @@points[self] = @@index
    end

    def index
      @@points[@point]
    end

    def self.points
      @@points
    end

    def x
      @point[0]
    end

    def y
      @point[1]
    end

    def z
      @point[2]
    end

    def ==(other)
      if other.class == self.class
        (other.x - x).abs < TOLERANCE &&
          (other.y - y).abs < TOLERANCE &&
          (other.z - z).abs < TOLERANCE &&
          (((other.x - x)**2) + ((other.y - y)**2) + ((other.z - z)**2)) < TOLERANCE
      else
        false
      end
    end

    alias eql? ==

    def hash
      "#{(x.to_f / TOLERANCE).to_i}#{(y.to_f / TOLERANCE).to_i}#{(z.to_f / TOLERANCE).to_i}".to_i
    end

    def to_a
      [x, y, z]
    end

    def inspect
      "#{self} #{to_a}"
    end
  end
end
