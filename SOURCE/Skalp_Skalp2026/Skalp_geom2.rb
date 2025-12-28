module Skalp
  extend self

  def midpoint(p1, p2)
    mid = Geom::Point3d.new
    mid.x = (p2.x + p1.x)/2.0
    mid.y = (p2.y + p1.y)/2.0
    mid.z = (p2.z + p1.z)/2.0
    mid
  end

  def sum(array)
    array.inject(0) { |accum, i| accum + i }
  end

  def mean(array)
    sum(array) / array.length.to_f
  end

  def sample_variance(array)
    m = mean(array)
    sum = array.inject(0) { |accum, i| accum + (i - m) ** 2 }
    sum.abs / (array.length - 1).to_f
  end

  def standard_deviation(array)
    Math.sqrt(sample_variance(array))
  end

  def points_sort(points_array)
    x=[]
    y=[]
    z=[]

    for point in points_array
      x << point[0]
      y << point[1]
      z << point[2]
    end

    x_var = standard_deviation(x)
    y_var = standard_deviation(y)
    z_var = standard_deviation(z)

    case
      when x_var >= y_var && x_var > z_var
        points_array.sort!
      when y_var > x_var && y_var >= z_var
        points_array.sort! { |x, y| y[1] <=> x[1] }
      when z_var >= x_var && z_var > y_var
        points_array.sort! { |x, y| y[2] <=> x[2] }
    end
  end

  def remove_equal_points(points_array)
    sorted_array = points_sort(points_array)
    uniq_points = []
    for n in 0..sorted_array.size-2 do
      uniq_points << sorted_array[n] unless Skalp.points_equal?(sorted_array[n], sorted_array[n+1])
    end
    uniq_points << sorted_array.last
    return uniq_points
  end

  # moved to C-extension
  #def ccw(pt1, pt2, pt3)

  def loop_ccw?(loop)
    v = loop.vertices
    n = v.size
    totalarea = v[0].x * (v[1].y - v[n-1].y)
    i = 1
    while i < n-1 do
      totalarea += v[i].x * (v[i + 1].y - v[i - 1].y)
      i += 1
    end
    totalarea += v[n-1].x * (v[0].y - v[n-2].y)
    totalarea *= 0.5
    totalarea > 0
  rescue
    true
  end

  def points_equal?(pt1, pt2)
    tol = 0.001
    (pt1.x - pt2.x).abs < tol &&
        (pt1.y - pt2.y).abs < tol &&
        (pt1.z - pt2.z).abs < tol &&
        ((pt1.x - pt2.x)**2 + (pt1.y - pt2.y)**2 + (pt1.z - pt2.z)**2) < tol
  end

  def collinear(p1, p2, p3)
    p3.on_line? [p1, p2]
  end

  #angle_3_points: java reference implementation  http://stackoverflow.com/questions/3057448/angle-between-3-vertices
  #returns signed angle BAC in radians [PI..-PI], depending on whether BAC goes clockwise or counterclockwise
  def angle_3_points(ptC, ptA, ptB)
    ba_x = ptB.x - ptA.x
    ba_y = ptB.y - ptA.y

    ca_x = ptC.x - ptA.x
    ca_y = ptC.y - ptA.y

    dot = ba_x * ca_x + ba_y * ca_y
    pcross = ba_x * ca_y - ba_y * ca_x

    angle = Math.atan2(pcross, dot)
  end

  def pointOnEdge(pt, line) #mogelijke optimalisatie: te vervangen door iets op basis van parametervergelijking lijnstuk  (1-t)*pt1 + t*pt2 <=> 0
    if pt != nil
      pt1 = line[0]
      pt2 = line[1]

      d1 = pt1.distance pt2
      d2 = pt.distance pt1
      d3 = pt.distance pt2

      if d2 > d1 || d3 > d1 then
        return false
      else
        return true
      end
    else
      return false
    end
  end

  def to_point(pt)
    Geom::Point3d.new(pt.x, pt.y, pt.z)
  end

  # deprecated, use SketchUp api instead
  def distance_between_points(pt1, pt2)
    Math.sqrt((pt2.x-pt1.x)**2 + (pt2.y-pt1.y)**2 + (pt2.z-pt1.z)**2)
  end

  # deprecated, use SketchUp api instead
  def distance_between_point_and_plane(pt, plane)
    x1 = pt.x
    y1 = pt.y
    z1 = pt.z
    a = plane.to_a[0]
    b = plane.to_a[1]
    c = plane.to_a[2]
    d = plane.to_a[3]

    ((a*x1) + (b*y1) + (c*z1) + d)/Math::sqrt(a**2 + b**2 + c**2)
  end

  # http://ndu2009algebra.blogspot.be/2011/05/mirroring-point-on-3d-plane.html
  # arguments:
  # a Sketchup::Point3d and an Array of 4 numbers
  # returns:
  # a mirrored point as a Sketchup::Point3d
  def mirror_point_on_3d_plane(point, plane)
    require 'Matrix'
    normal = Geom::Vector3d.new(plane[0], plane[1], plane[2]).normalize!
    point_on_plane = Geom::Point3d.new(0.0, 0.0, 0.0).project_to_plane plane
    k = point_on_plane.x * normal.x + point_on_plane.y * normal.y + point_on_plane.z * normal.z # dot product
    matrix = Matrix[
        [1 - 2 * normal.x**2, -2 * normal.x * normal.y, -2 * normal.x * normal.z, 2 * normal.x * k],
        [-2 * normal.y * normal.x, 1 - 2 * normal.y**2, -2 * normal.y * normal.z, 2 * normal.y * k],
        [-2 * normal.z * normal.x, -2 * normal.z * normal.y, 1 - 2 * normal.z**2, 2 * normal.z * k],
        [0.0, 0.0, 0.0, 1.0]
    ].transpose # switch from column major to row major order (= flip matrix along diagonal)
    mirror = Geom::Transformation.new(matrix.to_a.flatten)
    mirror * point #is equivalent to point.transform(mirror), returns a Sketchup::Point3D
  end

  def max_x_point(points)
    points.max_by { |vertex| vertex.x }
  end

  def transform_point_by_transformation(pt, transformation)
    tpt = Geom::Point3d.new(pt[0], pt[1], pt[2])
    tpt = transformation * tpt
    tpt.to_a
  end

  def transformation_to_2D(plane)
    global_zaxis = Geom::Vector3d.new(0, 0, 1)

    origin = Geom::Point3d.new(-plane[0]*plane[3], -plane[1]*plane[3], -plane[2]*plane[3])
    #z_height = origin.z
    zaxis = Geom::Vector3d.new(-plane[0], -plane[1], -plane[2]) # OK! deze 3 punten mogen ook van teken veranderen, kwestie van keuze normaalvector uiteindelijke groep

    if zaxis.parallel? global_zaxis then
      if zaxis.samedirection? global_zaxis then #IDENTIEKE Z ASSEN, TEGENGESTELDE RICHTING!
        xaxis = Geom::Vector3d.new(1, 0, 0) #hint:spiegelen door x en y te wisselen of cross om te draaien.
        yaxis = zaxis.cross xaxis #cross omdraaien inverteert richting resulterende vector
      else #IDENTIEKE Z ASSEN, ZELFDE RICHTING!
        xaxis = Geom::Vector3d.new(1, 0, 0)
        yaxis = zaxis.cross xaxis #cross omdraaien inverteert richting resulterende vector
      end
    else
      xaxis = global_zaxis.cross zaxis #cross omdraaien inverteert richting resulterende vector
      yaxis = zaxis.cross xaxis #cross omdraaien inverteert richting resulterende vector
    end

    transformation = Geom::Transformation.axes origin, xaxis, yaxis, zaxis
    transformation.invert!
  end

  def transform_point(pt, transformation)
    tpt = Geom::Point3d.new(pt[0], pt[1], pt[2])
    tpt = transformation * tpt
    return tpt.to_a
  end

  def transform_line(line, transformation)
    pt1 = line[0].transform(transformation)
    pt2 = Geom::Point3d.new(line[0].x + line[1].x, line[0].y+ line[1].y, line[0].z+ line[1].z).transform(transformation)
    return [pt1, pt2]
  end

  def side(pt, plane)
    s = plane[0] * pt[0] + plane[1] * pt[1] + plane[2] * pt[2] + plane[3]

    if s < 0.0
      return -1
    elsif s > 0.0
      return 1
    else
      return 0
    end
  end

  def reverse_plane(sectionplane)
    plane = sectionplane.get_plane
    normal = Geom::Vector3d.new plane[0], plane[1], plane[2]
    normal.reverse!
    sectionplane.set_plane([normal.x, normal.y, normal.z, -plane[3]])
  end

  def get_up_vector(plane)
    global_zaxis = Geom::Vector3d.new(0, 0, 1)
    zaxis = Geom::Vector3d.new(-plane[0], -plane[1], -plane[2]) # OK! deze 3 punten mogen ook van teken veranderen, kwestie van keuze normaalvector uiteindelijke groep

    if zaxis.parallel? global_zaxis
      if zaxis.samedirection? global_zaxis #IDENTIEKE Z ASSEN, TEGENGESTELDE RICHTING!
        xaxis = Geom::Vector3d.new(1, 0, 0) #hint:spiegelen door x en y te wisselen of cross om te draaien.
        yaxis = zaxis.cross xaxis #cross omdraaien inverteert richting resulterende vector
      else #IDENTIEKE Z ASSEN, ZELFDE RICHTING!
        xaxis = Geom::Vector3d.new(1, 0, 0)
        yaxis = zaxis.cross xaxis #cross omdraaien inverteert richting resulterende vector
      end
    else
      xaxis = global_zaxis.cross zaxis #cross omdraaien inverteert richting resulterende vector
      yaxis = zaxis.cross xaxis #cross omdraaien inverteert richting resulterende vector
    end

    yaxis
  end
end
