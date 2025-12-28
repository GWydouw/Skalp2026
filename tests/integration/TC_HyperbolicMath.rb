# frozen_string_literal: true

require "testup/testcase"
require_relative "test_helper"

module JtHyperbolicCurves
  module Tests
    class TC_HyperbolicMath < TestUp::TestCase
      Point3d = JtHyperbolicCurves::Core::GeometryEngine::Point3d

      def setup
        # Setup code if needed
      end

      def teardown
        # Teardown code if needed
      end

      def test_point_struct
        p1 = Point3d.new(10, 0, 0)
        p2 = Point3d.new(0, 0, 0)
        diff = p1 - p2
        assert_equal(10, diff.x)
        assert_equal(10, diff.length)
      end

      def test_hyperbola_generation
        # Test with standard parameters
        points = JtHyperbolicCurves::Core::GeometryEngine.sample_hyperbola_points(
          ref_height: 300.0,
          step: 20.0,
          x_max: 500.0,
          curve_tol: 0.1,
          x_offset: 0.0,
          y_offset: 0.0,
          z_rotation_deg: 0.0
        )

        assert(points.length > 2, "Should generate points")

        # First point should be at x_intersect (step * 1 + offset)
        # x_int = 20.0, x_offset = 0.0 -> x = 20.0
        first_pt = points.first
        assert_in_delta(20.0, first_pt.x, 0.1)

        # Z calculation check: z = ref_height - (k / x)
        # k = 1 * 20 * 300 = 6000
        # x = 20 -> z = 300 - 300 = 0
        assert_in_delta(0.0, first_pt.z, 0.1)
      end

      def test_offset_calculation
        # Create a simple line along X
        base = [
          Point3d.new(0, 0, 0),
          Point3d.new(10, 0, 0),
          Point3d.new(20, 0, 0)
        ]

        # Tangent is (1, 0, 0) -> Normal in XZ should be (0, 0, 1) or (0, 0, -1)
        # Logic: nx = -tz/len = 0, nz = tx/len = 1
        # Offset +10 along Normal -> (x, y, z+10)

        offset_pts = JtHyperbolicCurves::Core::GeometryEngine.calculate_offset_path(base, 10.0)

        assert_equal(3, offset_pts.length)
        assert_in_delta(10.0, offset_pts[0].z, 0.001)
        assert_in_delta(0.0, offset_pts[0].x, 0.001)
      end
    end
  end
end
