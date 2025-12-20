# Skalp Patterns - plugin for SketchUp.
#
# Creates tilable png textures for use in SketchUp and Layout. Imports pattern definitions
# from standard ACAD.PAT pattern files.
#
# @author Skalp (C) 2014

module Skalp
  module SkalpHatch

    class Point2D #floats
      attr_accessor :x, :y

      def initialize(x = 0.0, y = x)
        @x = x.to_f
        @y = y.to_f
      end

      def transform!(hatch_transformation)
        t = hatch_transformation.transformationmatrix
        cx = t[0, 0] * @x + t[0, 1] * @y + t[0, 2]
        cy = t[1, 0] * @x + t[1, 1] * @y + t[1, 2]
        cw = t[2, 0] * @x + t[2, 1] * @y + t[2, 2]
        @x = cx / cw
        @y = cy / cw
        self
      end

      # rotates this point around a given point, or around origin by default
      def rotate(rad_angle, point = Point2D.new) #ugly, but it works!
        tt = Transformation2D.new
        tt.translate!(-point.x, -point.y)
        self.transform!(tt)
        rt = Transformation2D.new
        rt.rotate!(rad_angle)
        self.transform!(rt)
        tt.inverse!
        self.transform!(tt)
        self
      end

      def distance(point)
        x1, y1, x2, y2 = x, y, point.x, point.y
        # hypotenuse == sqrt(x**2+y**2)
        Math.hypot(x2-x1, y2-y1)
      end

      # returns:  1 for line to the left of this point
      #          -1 for line to the right of this point
      #           0 for point collinear to this line
      def side?(line) #Line2D
        line.side?(self)
      end

      def pointsequal?(point)
        t = 1.0e-5 #TODO smaller tolerance 1.0e-9 , original: 1.0e-5
        (@x - point.x).abs < t && (@y - point.y).abs < t
      end

      alias_method :eql?, :pointsequal?

      def dup
        Point2D.new(@x, @y)
      end

      def to_s
        "(#{@x},#{@y})"
      end
    end #Point2D

    class Line2D
      attr_accessor :p1, :p2, :m, :q
      attr_reader :p_on_x, :p_on_y

      def initialize(p1, arg) #def initialize(p1 = Point2D.new(0.0, 0.0), arg)
        @p1 = p1 || Point2D.new(0.0, 0.0)
        case arg
          when Point2D
            @p2 = arg
            raise ArgumentError, "2 points defining a Line2D cannot be the same #{@p1}, #{@p2}" if pointsequal?
          when ChunkyPNG::Point
            @p2 = arg
            raise ArgumentError, '2 points defining a Line2D cannot be the same (Chunky::Point)' if pointsequal?
          when Vector2D
            @p2 = Point2D.new(p1.x + arg.x, p1.y + arg.y)
            raise ArgumentError, '2 points defining a Line2D cannot be the same (Vector2D)' if pointsequal?
          else
            @p2 = Point2D.new(1.0, 1.0)
            raise ArgumentError, '2 points defining a Line2D cannot be the same (arg invalid)' if pointsequal?
        end
      end

      def update_pts_on_axes
        if pointsequal?
          raise ArgumentError, 'ILLEGAL POINTSEQUAL IN LINE2D'
        end

        if x_eql? # line || Y-axis
          @p_on_x = Point2D.new(p1.x, 0.0)
          @p_on_y = nil
          @m = 1.0
          @q = p1.x

        elsif y_eql? # line || X-axis
          @p_on_y = Point2D.new(0.0, p1.y)
          @p_on_x = nil
          @m = 0.0
          @q = p1.y

        else # oblique line
          @m = (@p2.y-@p1.y)/(@p2.x-@p1.x)
          @q = @p1.y - m * @p1.x
          @p_on_y = Point2D.new(0.0, q)
          @p_on_x = Point2D.new(@p1.x - @p1.y / m, 0.0)
        end
      end

      def p_on_x
        update_pts_on_axes
        @p_on_x
      end

      def p_on_y
        update_pts_on_axes
        @p_on_y
      end

      def pointsequal?
        x_eql? && y_eql?
      end

      alias_method :eql?, :pointsequal?

      def ==(other)
        self.p1.x == other.p1.x && self.p1.y == other.p1.y && self.p2.x == other.p2.x && self.p2.y == other.p2.y
      end

      def x_eql?
        t = 1.0e-9
        (@p1.x - @p2.x).abs < t
      end

      def y_eql?
        t = 1.0e-9
        (@p1.y - @p2.y).abs < t
      end

      # returns:  1 for point to the right of line
      #          -1 for point to the left of line
      #           0 for point collinear to this line
      def side?(p3) #Point2D, or something that responds to .x and .y
        0 <=> (@p2.x - @p1.x) * (p3.y - @p1.y) - (@p2.y - @p1.y) * (p3.x - @p1.x)
      end

      def intersect(line)
        x1, y1, x2, y2, x3, y3, x4, y4 = @p1.x, @p1.y, @p2.x, @p2.y, line.p1.x, line.p1.y, line.p2.x, line.p2.y

        return if ((x1-x2) * (y3-y4) - (y1-y2) * (x3-x4)) == 0 # lines are ||

        x5 = ((x1*y2 - y1*x2) * (x3-x4) - (x1-x2) * (x3*y4 - y3*x4)) / ((x1-x2) * (y3-y4) - (y1-y2) * (x3-x4)) #TODO round
        y5 = ((x1*y2 - y1*x2) * (y3-y4) - (y1-y2) * (x3*y4 - y3*x4)) / ((x1-x2) * (y3-y4) - (y1-y2) * (x3-x4)) #TODO round
        Point2D.new(x5, y5)
      end

      def parallel?(line)
        x1, y1, x2, y2, x3, y3, x4, y4 = @p1.x, @p1.y, @p2.x, @p2.y, line.p1.x, line.p1.y, line.p2.x, line.p2.y
        ((x1-x2) * (y3-y4) - (y1-y2) * (x3-x4)) == 0 #CROSS
      end

      def transform!(hatch_transformation)
        @p1.transform!(hatch_transformation)
        @p2.transform!(hatch_transformation)
        #update_pts_on_axes
        self
      end

      # rotates this Line2D around a given point, or around origin by default
      def rotate!(rad_angle, point = Point2D.new) #ugly, but it works!
        tt = Transformation2D.new
        tt.translate!(-point.x, -point.y)
        self.p1.transform!(tt)
        self.p2.transform!(tt)
        rt = Transformation2D.new
        rt.rotate!(rad_angle)
        self.p1.transform!(rt)
        self.p2.transform!(rt)
        tt.inverse!
        self.p1.transform!(tt)
        self.p2.transform!(tt)
        #update_pts_on_axes
        self
      end

      def distance?(point)
        #float CrossProduct(const Vector2D & v1, const Vector2D & v2) const
        # {
        #    return (v1.X*v2.Y) - (v1.Y*v2.X);
        #}
        #
        #((x1-x2) * (y3-y4) - (y1-y2) * (x3-x4))
      end


      def dup
        Line2D.new(@p1.dup, @p2.dup)
      end

      def to_s
        update_pts_on_axes
        "Line2D: [#{p1},#{p2}] equation: y = #{m}x + #{q} , Point2D on X axis: #{@p_on_x},Point2D on Y axis: #{@p_on_y}"
      end

    end #Line2D

    class Edge2D < Line2D

      #defined by parametric equation
      #for all points on segment, following equation holds:
      # x = x1 + (x2 - x1) * p
      # y = y1 + (y2 - y1) * p
      # p = (x - x1) / (x2 - x1) = (y - y1) / (y2 - y1)
      #Where p is a number in [0..1]
      def point_on_edge?(point)
        return false if !point
        p = position_on_edge?(point)
        t = 0.1e-6
        0.0 - t <= p && p <= 1.0 + t
      end

      def position_on_edge?(point)
        squared_length = (p2.x - p1.x)**2 + (p2.y - p1.y)**2
        dot_product = (point.x - p1.x) * (p2.x - p1.x) + (point.y - p1.y)*(p2.y - p1.y)
        dot_product / squared_length
      end

      def dup
        Edge2D.new(@p1.dup, @p2.dup)
      end

      def to_s
        update_pts_on_axes
        "Edge2D: [#{p1},#{p2}] equation: y = #{m}x + #{q} , Point2D on X axis: #{@p_on_x},Point2D on Y axis: #{@p_on_y}"
      end
    end

    class Vector2D

      def initialize(arg = Point2D.new(1.0, 0.0), startpoint = Point2D.new(0.0, 0.0))
        @startpoint = startpoint
        case arg
          when Point2D
            @arrow_point = arg
          else # supposed to be an angle in radians
            raise 'Vector2D argument error, should be Point2D, Float or Integer' if arg == nil
            @arrow_point = Point2D.new(Math.cos(arg), Math.sin(arg))
          #precision = 20     #OPMERKING juiste waarde nog te zoeken, misschien 10?
          #Math.cos(arg) #.round(precision).to_f      #OPMERKING ONNAUWKEURIG ROND 90 !!!
          #Math.sin(arg) #.round(precision).to_f      #OPMERKING ONNAUWKEURIG ROND 0  !!!
        end
        @endpoint = Point2D.new(@startpoint.x + @arrow_point.x, @startpoint.x + @arrow_point.y)
      end

      def x=(x)
        @arrow_point.x = x
        @endpoint.x = startpoint.x + @x
      end

      def x
        @arrow_point.x
      end

      def y=(y)
        @arrow_point.y = y
        @endpoint.y = startpoint.y + @y
      end

      def y
        @arrow_point.y
      end

      def define_by_point=(point)
        case point
          when Point2D
            @arrow_point.x, @arrow_point.y = point.x, point.y
          when Array
            if point.size == 2
              @arrow_point.x, @arrow_point.y = point.first, point.last
            end
        end

        @endpoint.x = startpoint.x + @arrow_point.x
        @endpoint.y = startpoint.y + @arrow_point.y
        point
      end

      def startpoint=(startpoint)
        @endpoint.x = @x + startpoint.x
        @endpoint.y = @y + startpoint.y
        @startpoint = startpoint
      end

      def startpoint
        @startpoint
      end

      def endpoint=(endpoint)
        @startpoint.x = endpoint.x - @x
        @startpoint.y = endpoint.y - @y
        @endpoint = endpoint
      end

      def endpoint
        @endpoint
      end

      def dot(vector2D)
        x0, y0= vector2D.x, vector2D.y
        x * x0 + y * y0
      end

      def -(vector2D)
        Vector2D.new(Point2D.new(x - vector2D.x, y - vector2D.y))
      end

      alias_method :minus, :-

      def +(vector2D)
        Vector2D.new(Point2D.new(x + vector2D.x, y + vector2D.y))
      end

      alias_method :plus, :+

      def *(t)
        x *= t
        y *= t
        self
      end

      def to_array
        [@x, @y]
      end

      def angle
        Math.atan2(y, x)
      end

      def transform!(hatch_transformation)
        @p1.transform!(hatch_transformation)
        @p2.transform!(hatch_transformation)
        #update_pts_on_axes
        self
      end

    end #Vector2D

    class Transformation2D
      include SkalpHatch
      attr_accessor :transformationmatrix

      def initialize(homogenousmatrix3by3 = Matrix[[1, 0, 0], [0, 1, 0], [0, 0, 1]])
        @transformationmatrix = homogenousmatrix3by3
      end

      def *(object) #Transformation2D
        if object.class == Transformation2D
          @transformationmatrix *= object.transformationmatrix
          self
        else
          puts "transformation not yet implemented for #{object.class}, argument ignored for now"
          self
        end
      end

      def **(exponent) #exponent.class == integer
        @transformationmatrix = @transformationmatrix **= exponent
        self
      end

      def inverse!
        @transformationmatrix = @transformationmatrix.inverse
        self
      end

      def inverse
        Transformation2D.new(@transformationmatrix.inverse)
      end

      def rotate!(rad_angle) #in radials, around origin
        tm = Transformation2D.new.transformationmatrix
        tempmatrix = *tm #needs temporary conversion because Matrix class is immutable
        tempmatrix[0][0] = Math.cos(rad_angle)
        tempmatrix[0][1] = -Math.sin(rad_angle)
        tempmatrix[1][0] = Math.sin(rad_angle)
        tempmatrix[1][1] = Math.cos(rad_angle)
        @transformationmatrix *= Matrix[*tempmatrix]
        self
      end

      #returns a new rotation transformation object
      def rotation(rad_angle) #in radials, around origin
        rotation_transformation = Transformation2D.new
        tm = rotation_transformation.transformationmatrix
        tempmatrix = *tm #needs temporary conversion because Matrix class is immutable
        tempmatrix[0][0] = Math.cos(rad_angle)
        tempmatrix[0][1] = -Math.sin(rad_angle)
        tempmatrix[1][0] = Math.sin(rad_angle)
        tempmatrix[1][1] = Math.cos(rad_angle)
        rotation_transformation.transformationmatrix = Matrix[*tempmatrix]
        rotation_transformation
      end

      def translate!(x, y=x)
        tm = Transformation2D.new.transformationmatrix
        tempmatrix = *tm #needs temporary conversion because Matrix class is immutable
        tempmatrix[0][2] = x
        tempmatrix[1][2] = y
        @transformationmatrix *= Matrix[*tempmatrix]
        self
      end

      #returns a new translation transformation object
      def translation(x, y=x)
        translation_transformation = Transformation2D.new
        tm = translation_transformation.transformationmatrix
        tempmatrix = *tm #needs temporary conversion because Matrix class is immutable
        tempmatrix[0][2] = x
        tempmatrix[1][2] = y
        @transformationmatrix = Matrix[*tempmatrix]
        translation_transformation.transformationmatrix = Matrix[*tempmatrix]
        translation_transformation
      end

      # scale around origin
      def scale!(factor_x, factor_y = factor_x)
        translation_transformation = Transformation2D.new
        tm = translation_transformation.transformationmatrix
        tempmatrix = *tm #needs temporary conversion because Matrix class is immutable
        tempmatrix[0][0] = factor_x
        tempmatrix[1][1] = factor_y
        @transformationmatrix *= Matrix[*tempmatrix]
        self
      end

      # returns a new scaling transformation object
      def scaling(factor_x, factor_y = factor_x) #uniform scale around origin
        translation_transformation = Transformation2D.new
        tm = translation_transformation.transformationmatrix
        tempmatrix = *tm #needs temporary conversion because Matrix class is immutable
        tempmatrix[0][0] = factor_x
        tempmatrix[1][1] = factor_y
        @transformationmatrix = Matrix[*tempmatrix]
        translation_transformation.transformationmatrix = Matrix[*tempmatrix]
        translation_transformation
      end

      def to_s
        "#{Transformation2D}, #{@transformationmatrix}"
      end
    end #class Transformation2D

  end #module SkalpHatch
end #module Skalp