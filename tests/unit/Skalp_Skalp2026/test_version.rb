# frozen_string_literal: true

require_relative "../test_helper"

class TestSkalpVersion < Minitest::Test
  def test_version_constant_exists
    assert defined?(Skalp::VERSION), "Skalp::VERSION should be defined"
  end

  def test_version_format
    assert_match(/^\d+\.\d+\.\d+/, Skalp::VERSION)
  end

  def test_loader_version_match
    # Ensure the loader picked up the correct version
    assert defined?(Skalp::SKALP_VERSION)
    assert_equal Skalp::VERSION, Skalp::SKALP_VERSION
  end
end
