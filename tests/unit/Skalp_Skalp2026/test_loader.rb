require_relative "../test_helper"
require_relative "../../../SOURCE/Skalp_Skalp2026/dev_loader"
require "yaml"

module Skalp
  class TestLoader < Minitest::Test
    def setup
      Skalp.load_development_mode
    end

    def test_module_defined
      assert defined?(Skalp), "Skalp module should be defined"
    end

    def test_control_center_loaded
      assert defined?(Skalp::ControlCenter), "Skalp::ControlCenter should be loaded via embed.yml"
    end

    def test_files_exist_in_embed_yml
      # 3 levels up from tests/unit/skalp/
      config_file = File.expand_path("../../../embed.yml", File.dirname(__FILE__))
      assert File.exist?(config_file), "embed.yml must exist at #{config_file}"
      
      config = YAML.load_file(config_file)
      root = File.expand_path("../../../SOURCE/Skalp_Skalp2026", File.dirname(__FILE__))

      config.each do |data, files|
        files = [files] unless files.is_a?(Array)
        files.each do |f|
          path = File.join(root, f)
          assert File.exist?(path), "File #{f} listed in embed.yml does not exist at #{path}!"
        end
      end
    end
  end
end
