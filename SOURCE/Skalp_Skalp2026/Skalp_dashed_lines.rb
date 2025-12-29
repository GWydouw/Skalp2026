module Skalp
  class DashedMesh
    attr_accessor :loop_points, :testing
    attr_reader :scale, :step, :dot, :space, :mesh

    def initialize(component_definition)
      @mesh = Geom::PolygonMesh.new
      @component_entities = component_definition.entities
      @component_entities.clear!
      @total_line_length = 0
      get_scale
      linestyle_essentials
    end

    # a safety measure to avoid drawing too many or too small dashes causing SketchUp to choke.
    def dashing_overflow_protection(total_line_length)
      return unless total_line_length && total_line_length > 0.0

      proportion = @dot / @step

      maximum_number_of_dashes = 20_000
      if total_line_length / @step > maximum_number_of_dashes # estimated number of dashes is too large: limit to 20000 dashes
        @step = total_line_length / maximum_number_of_dashes
        @dot = proportion * step
      end

      smallest_acceptable_length = 0.003937 # +/- 0.1mm
      return unless @dot < smallest_acceptable_length

      @dot = smallest_acceptable_length
      @step = @dot / proportion
    end

    def linestyle_essentials
      @dot = @space = 0.07874 * @scale # 0.07874" == 2mm
      @step = @dot + @space

      factor = (Math.sqrt(5) - 1) / 2
      @dot = factor * @step
      @space = (1 - factor) * @step
    end

    def get_scale
      scale = if Skalp.active_model
                Skalp.dialog.drawing_scale.to_f
              else
                5.0
              end
      @scale = scale
    end

    def add_line(p1, p3)
      p2 = Geom::Point3d.linear_combination(0.0, p1, 1.0, p3)
      points = [p1, p2, p3]
      points.map! { |pt| index = @mesh.add_point(pt) }
      @mesh.add_polygon(*points)
    end

    def add_loop_points(points)
      @loop_points += points # unless @loop_points.size > 15
    end

    def add_mesh(layer = nil)
      @component_entities.fill_from_mesh(@mesh)
      # @component_entities.each {|e| e.layer = layer} if layer
      add_cpoints if @testing
    end

    def add_cpoints
      @loop_points.each do |point|
        @component_entities.add_cpoint(point)
        @component_entities.add_text(" #{counter}", point)
      end
      # @grp.entities.add_cpoint(@line.first)
      # @grp.entities.add_cpoint(@line[1])
      # @grp.entities.add_cpoint(@line.last)
    end

    def counter
      @count += 1
    end

    def add_numbered_cpoints=(bool)
      @count = 0
      @loop_points = []
      @testing = bool
    end
  end

  class PolyLines
    include Enumerable

    attr_reader :all_curves, :lines, :total_line_length

    def initialize
      @polylines = []
      @all_curves = []
    end

    def fill_from_layout(lines)
      @line_hash = {}
      @lines = lines
      fill_lookup(lines)
      sorted_lines
      initialize
      @sorted_lines.each do |points|
        @polylines << Skalp::PolyLine.new(points)
        @all_curves += @polylines.last.curves
      end
    end

    def deleted?
      @polylines.empty?
    end

    def each_curve(&)
      return @all_curves.each unless block_given?

      @all_curves.each(&)
    end

    def each(&)
      return @polylines.each unless block_given?

      @polylines.each(&)
    end

    private

    def sorted_lines
      return @sorted_lines if @sorted_lines

      @sorted_lines = []
      @line_hash.each_key do |key|
        values = @line_hash[key]
        next if values == []

        values.each { |value| @sorted_lines << find_connecting_lines(key, value) }
      end
      @polylines = @sorted_lines
    end

    def fill_lookup(lines)
      lines.each do |line|
        start_point = line[0]
        end_point = line[1]
        line.define_singleton_method(:length) do
          Geom::Point3d.new(start_point).distance(Geom::Point3d.new(end_point))
        end
        @total_line_length ||= 0
        @total_line_length += line.length

        convert_line_to_hash_structure(end_point, start_point)
        convert_line_to_hash_structure(start_point, end_point)
      end
    end

    def convert_line_to_hash_structure(end_point, start_point)
      if @line_hash[start_point]
        values = @line_hash[start_point]
        unless values.include?(end_point)
          values << end_point
          @line_hash[start_point] = values
        end
      else
        @line_hash[start_point] = [end_point]
      end
    end

    def find_connecting_lines(start_point, end_point)
      connectingline = []
      connectingline << start_point
      connectingline << end_point

      # forward search
      grab_forward_connected_lines(connectingline, start_point, end_point)

      # reverse search
      connectingline.reverse!
      # start_point = connectingline[-2]
      # end_point = connectingline[-1]
      convert_line_to_hash_structure(end_point, start_point)
      convert_line_to_hash_structure(start_point, end_point)
      grab_forward_connected_lines(connectingline, end_point, start_point)

      connectingline
    end

    def grab_forward_connected_lines(connectingline, start_point, end_point)
      begin
        result = next_point(start_point, end_point)
        remove_value_for_key(start_point, end_point)
        remove_value_for_key(end_point, start_point)
        if result
          if result[1] == :straight_on
            connectingline.pop # throw out collinear point
          end

          connectingline << result[0]
          start_point = end_point
          end_point = result[0]
        end
      end while result
    end

    def remove_value_for_key(key, value)
      values = @line_hash[key]
      return unless values

      values -= [value]
      @line_hash[key] = values
    end

    def next_point(start_point, end_point)
      values = @line_hash[end_point]
      return nil if values == []

      if values.size > 1
        next_point_and_best_angle = []
        next_point_and_best_angle = get_most_straight_on_point(start_point, end_point, values,
                                                               next_point_and_best_angle)
        # check if looking backwards points to original startpoint
        next_point = next_point_and_best_angle[0]

        controle = []
        controle = get_most_straight_on_point(next_point.dup, end_point, values, controle)
        if controle[0] != start_point
          # TERMINATE THIS LINE
          return nil
        end

        angle = next_point_and_best_angle[1]

      else
        next_point = values[0]
        angle = (Skalp.angle_3_points(start_point, end_point, next_point).abs - Math::PI).abs
      end

      return nil if start_point == next_point

      [next_point, angle == 0.0 ? :straight_on : :include] # adds skip flag when collinear so we can skip the middle point later on
    end

    def get_most_straight_on_point(start_point, end_point, values, next_point_and_best_angle)
      values.each do |next_point|
        next if next_point == start_point

        angle = (Skalp.angle_3_points(start_point, end_point, next_point).abs - Math::PI).abs # TODO: angle for 3D points!!!
        if next_point_and_best_angle == []
          next_point_and_best_angle = [next_point, angle]
        elsif angle < next_point_and_best_angle[1]
          next_point_and_best_angle = [next_point, angle]
        end
      end
      next_point_and_best_angle
    end
  end

  class PolyLine
    attr_reader :points

    def initialize(points)
      return unless points.size > 1

      @points = points
      @curve_hashes = split_to_curves(points)
    end

    def make_dashes(mesh)
      @mesh = mesh
      @curve_hashes.each { |line| PolyLineDasher.new(line, @mesh) }
    end

    def make_lines(mesh)
      @mesh = mesh
      @curve_hashes.each { |line| PolyLineDasher.new(line, @mesh) }
    end

    def curves
      return @curves if @curves

      @curves = @curve_hashes.map { |curve_hash| curve_hash[:points] }
    end

    def split_to_curves(points)
      return [{ points: points }] unless points.size > 2

      @lines = []
      line = {}
      line[:points] = []
      line[:points] << points[0]

      points.each_cons(3) do |triplet|
        angle = Skalp.angle_3_points(*triplet)
        line[:points] << triplet[1]
        smooth = (angle.abs >= Math::PI * 3 / 4) # 2.618 radians == +- 150 degrees
        @mesh.add_loop_points([triplet[1]]) if @mesh && @mesh.testing && !smooth

        next if smooth

        @lines << line
        line = {}
        line[:points] = []
        line[:points] << triplet[1]
      end

      line[:points] << points[-1]
      line[:closed_and_smooth] =
        (line[:points][0] == line[:points][-1]) && Skalp.angle_3_points(line[:points][-2], line[:points][0],
                                                                        line[:points][1]).abs >= Math::PI * 3 / 4
      @lines << line
      @lines
    end

    def each(&)
      if block_given?
        @lines.each(&)
      else
        @lines.each
      end
    end

    def counter
      @count ||= 0
      @count += 1
    end
  end

  class PolyLineDasher
    def initialize(polyline, mesh)
      return unless polyline[:points].size >= 2

      @step = mesh.step
      @dot = mesh.dot
      @space = mesh.space

      @mesh = mesh
      @line = polyline[:points]

      # @mesh.add_loop_points([line.first, line.last]) if mesh.testing
      @mesh.add_loop_points(polyline[:points]) if mesh.testing # TODO: disable this

      @edge_lengths = []
      @lines = []
      @line.each_cons(2) do |edge|
        distance_between_points = distance_between_points(Geom::Point3d.new(*edge[0]), Geom::Point3d.new(*edge[1]))
        @edge_lengths << distance_between_points
        @lines << { startpoint: edge[0], endpoint: edge[1], length: distance_between_points,
                    dashes: [] }
        @length = @edge_lengths.inject(0, :+)
      end

      @positions = []
      @edge_lengths.inject(0) do |sum, edge_length|
        @positions << (sum + edge_length)
        sum + edge_length
      end
      for i in 0..@lines.size - 1
        @lines[i][:domain] = [(@positions[i] - @lines[i][:length]) / @length, @positions[i] / @length]
      end

      @dashes = []
      polyline[:closed_and_smooth] ? circle_dasher : open_curve_dasher
      dashes_to_lines
      draw_dashes
      # end
    end

    private

    def open_curve_dasher
      if @length < @step
        short_curve_dasher # TODO: draw_short_segment
      else
        @number_of_lines = (@length / @step).ceil

        shift = (((@step * @number_of_lines) - @space) - @length) / 2
        # puts "shift: #{shift}"
        @first_length = (@dot - shift)
        @shift = (@step - shift)

        collect_dash_points

        # puts "@length: #{@length}"
        # puts "@step: #{@step}"
        # puts "@number_of_lines: #{@number_of_lines}"
        # puts "@space: #{@space}"
        # puts "@first_length: #{@first_length}"
        # puts "@dot: #{@dot}"
        # puts "@shift:#{@shift}"
        # puts "collect_dash_points: #{@dashes}"
        # pp @dashes
      end
    end

    # method that spreads dashes equally around a closed loop.
    def circle_dasher
      # TODO: small_circle_dasher
      @number_of_lines = ((@length + @space) / @step).round
      @step = @length / @number_of_lines
      @dot = (@dot / (@dot + @space)) * @step
      @space = @step - @dot

      pt1 = @dot / 2
      pt2 = @dot * 3 / 2

      @number_of_lines.times do
        @dashes << [pt1 / @length, pt2 / @length]
        pt1 += @step
        pt2 += @step
      end
    end

    def short_curve_dasher
      if @length >= @dot
        t = (((0.125 * @length) - (0.125 * @dot)) / (@step - @dot)) + 0.375
        @dashes << [0.0, t]
      else
        @dashes << [0.0, 1.0]
      end
    end

    def collect_dash_points
      @dashes << [0.0, @first_length / @length]
      pt1 = @shift
      pt2 = pt1 + @dot
      @number_of_lines -= 2
      @number_of_lines.times do
        @dashes << [pt1 / @length, pt2 / @length]
        pt1 += @step
        pt2 += @step
      end
      @dashes << [pt1 / @length, 1.0]
    end

    def draw_dashes
      @lines.each do |line|
        line[:dashes].each do |dash|
          pt1 = Geom::Point3d.linear_combination(1 - dash.first, line[:startpoint].to_a, dash.first,
                                                 line[:endpoint].to_a)
          pt2 = Geom::Point3d.linear_combination(1 - dash.last, line[:startpoint].to_a, dash.last, line[:endpoint].to_a)
          @mesh.add_line pt1, pt2
        end
      end
    end

    def dashes_to_lines
      carry_dash = false
      n = 0
      @dashes.each do |dash|
        for i in (n..@lines.size - 1)
          line = @lines[i]
          if carry_dash
            if carry_dash.last <= line[:domain].last # carry_dash in domain
              line[:dashes] << localize(carry_dash, line)
              carry_dash = false
              n = i
              break
            elsif carry_dash.first >= line[:domain].first && carry_dash.last > line[:domain].last # carry_dash starts in domain but overflows
              line[:dashes] << localize([carry_dash.first, line[:domain].last], line)
              carry_dash = [line[:domain].last, carry_dash.last]
            elsif carry_dash.first < line[:domain].first && carry_dash.last > line[:domain].last # carry_dash starts before domain but overflows
              line[:dashes] << localize([line[:domain].first, line[:domain].last], line)
              carry_dash = [line[:domain].last, carry_dash.last]
            end
          end
          next if dash.first >= line[:domain].last || dash.last <= line[:domain].first # dash outside domain

          if dash.first >= line[:domain].first && dash.last <= line[:domain].last # dash in domain
            line[:dashes] << localize([dash.first, dash.last], line)
            n = i
            break
          elsif dash.first >= line[:domain].first && dash.last > line[:domain].last # dash starts in domain but overflows
            line[:dashes] << localize([dash.first, line[:domain].last], line)
            carry_dash = [line[:domain].last, dash.last]
          end
        end
      end
    end

    def localize(dash, line)
      domain_length = line[:domain].last - line[:domain].first
      [(dash.first - line[:domain].first) / domain_length, (dash.last - line[:domain].first) / domain_length]
    end

    # tested, this is faster than SketchUp point.distance(point)
    def distance_between_points(pt1, pt2)
      Math.sqrt(((pt2.x - pt1.x)**2) + ((pt2.y - pt1.y)**2) + ((pt2.z - pt1.z)**2))
    end
  end

  # TESTING
  if SKALP_VERSION[-4..-1] == "9999"

    define_method("testing_dashed_polyline") do
      definition = Sketchup.active_model.definitions.add("dashed_polyline_test")
      instance = Sketchup.active_model.entities.add_instance(definition, Geom::Transformation.new)
      mesh = Skalp::DashedMesh.new(instance.definition)
      # mesh.add_numbered_cpoints = true
      hello_world = line_stings_from_model_text("Hello World!")
      circle = [[[3.214697847761802e-16, 5.25, 0.0], [1.358799986788235, 5.071110588017608, 0.0],
                 [2.6250000000000004, 4.546633369868303, 0.0], [3.7123106012293747, 3.7123106012293743, 0.0], [4.546633369868303, 2.6249999999999996, 0.0], [5.071110588017609, 1.3587999867882339, 0.0], [5.25, 0.0, 0.0], [5.071110588017607, -1.3587999867882379, 0.0], [4.546633369868301, -2.625000000000002, 0.0], [3.7123106012293743, -3.712310601229375, 0.0], [2.624999999999996, -4.546633369868305, 0.0], [1.3587999867882314, -5.071110588017609, 0.0], [-9.644093543285407e-16, -5.25, 0.0], [-1.3587999867882377, -5.071110588017607, 0.0], [-2.625000000000002, -4.546633369868301, 0.0], [-3.7123106012293765, -3.7123106012293725, 0.0], [-4.546633369868304, -2.6249999999999987, 0.0], [-5.071110588017609, -1.3587999867882319, 0.0], [-5.25, 6.429395695523604e-16, 0.0], [-5.071110588017608, 1.3587999867882354, 0.0], [-4.546633369868302, 2.6250000000000018, 0.0], [-3.7123106012293743, 3.7123106012293747, 0.0], [-2.6249999999999987, 4.546633369868304, 0.0], [-1.3587999867882332, 5.071110588017609, 0.0], [3.214697847761802e-16, 5.25, 0.0]]]
      circle2 = [[[6.578699972574244, 21.671528493955407, 0.0], [6.00784841378455, 20.10312672632025, 0.0],
                  [4.562401526081553, 19.268597576605618, 0.0], [2.9186999725742435, 19.55842650872138, 0.0], [1.845849977856628, 20.836999344240777, 0.0], [1.8458499778566284, 22.50605764367004, 0.0], [2.918699972574245, 23.78463047918944, 0.0], [4.562401526081555, 24.074459411305195, 0.0], [6.007848413784551, 23.239930261590562, 0.0], [6.578699972574244, 21.671528493955407, 0.0]]]
      # hello_world = hello_world[-2..-2]
      problematic_piece = [[[-13.455783952739276, 10.842548817137871, 0.06],
                            [-13.607926501556445, 10.741834735526506, 0.06],
                            [-13.670624848423119, 10.657384965495604, 0.06]]]
      point_loops = hello_world + circle + circle2
      # point_loops = text_to_modelfaces("Hello World!")
      # point_loops = [point_loops[0][5..7]]
      point_loops.each { |points| Skalp::PolyLine.new(points) }
      t = Geom::Transformation.new([0.0, 0.0, -0.3])
      Sketchup.active_model.entities.grep(Sketchup::Group) { |grp| grp.transform!(t) if grp.name == "Skalp_test_group" }
      mesh.add_mesh
    end

    define_method("line_stings_from_model_text") do |text| # = "Hello World"|
      require "pp"
      Sketchup.active_model.entities.grep(Sketchup::Group) { |grp| grp.erase! if grp.name == "Skalp_test_group" }
      group = Sketchup.active_model.entities.add_group
      group.name = "Skalp_test_group"
      group.entities.add_3d_text(text, TextAlignLeft, "SignPainter", true, false, 8.0, 0.0, 0.0, true, 0.0)
      t = Geom::Transformation.new([-20.0, 10.0, 10.0])
      line_strings = group.entities.grep(Sketchup::Face) { |face| face.loops.map! { |loop| loop.vertices.map! { |v| (t * v.position.to_a).to_a } } }
      group.erase!
      line_strings.flatten(1)
    end
    # line_stings_from_model_text("X")

    define_method("linestrings_to_edges") do |line_strings|
      edges = []
      line_strings.each { |linestring| linestring.each_cons(2) { |edge| edges << edge } }
      edges
    end

    define_method("test_dashedpolyline") do
      require "pp"
      t = Time.now
      Sketchup.active_model.start_operation("test_dashedpolyline", true)
      1.times do
        testing_dashed_polyline
      end
      Sketchup.active_model.commit_operation
    end

    # test_dashedpolyline

    define_method("test_polylines") do
      time = Time.now
      lines = PolyLines.new
      lines.fill_from_layout(Skalp.linestrings_to_edges(Skalp.line_stings_from_model_text("888888888888888888888888888")))
      # lines.fill_from_layout([[[-18.20648691750491, 13.698742504284075], [-18.143272759897776, 13.919992055909045]]])
      definitions = Sketchup.active_model.definitions
      new_name = definitions.unique_name("test_dashedpolyline")
      rear_view_definition = Sketchup.active_model.definitions.add(new_name)
      sectiongroup = Sketchup.active_model.entities.add_group
      sectiongroup.name = "test"
      rear_view = sectiongroup.entities.add_instance(rear_view_definition, Geom::Transformation.new)
      rear_view.name = "Skalp - #{Skalp.translate('rear view')}"
      lines.export_to_sketchup(rear_view.definition)
      # lines.sorted_lines
      # lines.sorted_lines
      # lines = lines.sorted_lines
      # pp lines.each {|e| pp e}
    end
    # test_polylines
  end
end
