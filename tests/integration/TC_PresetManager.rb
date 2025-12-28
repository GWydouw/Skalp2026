# frozen_string_literal: true

require "testup/testcase"
require "fileutils"
require "json"
require_relative "test_helper"

module JtHyperbolicCurves
  module Tests
    class TC_PresetManager < TestUp::TestCase
      def setup
        # Backup original file if exists
        @original_file_path = JtHyperbolicCurvesUI::PresetManager::PRESETS_FILE
        @backup_path = "#{@original_file_path}.bak"

        FileUtils.cp(@original_file_path, @backup_path) if File.exist?(@original_file_path)

        # Start fresh
        FileUtils.rm_f(@original_file_path)

        # Create a dummy wrapper instance
        model = Sketchup.active_model
        defs = model.definitions

        # Create a dummy definition for the wrapper
        @wrapper_def = defs.add("JtHyperbolicCurves_TestWrapper_Def_#{Time.now.to_i}")
        entities = @wrapper_def.entities
        entities.add_cpoint([0, 0, 0])

        # Create an instance of it
        @wrapper = model.entities.add_instance(@wrapper_def, Geom::Transformation.new)
        begin
          @wrapper.name = JtHyperbolicCurves::Configs::WRAPPER_DEF_NAME
        rescue StandardError
          @wrapper.name = "JtHyperbolicCurves_Wrapper"
        end

        # CRITICAL: Mark it as a wrapper so ModelStore.find_all_wrapper_instances finds it
        @wrapper.set_attribute(JtHyperbolicCurvesUI::DICT_NAME, "is_wrapper", true)
      end

      def teardown
        # Cleanup file
        FileUtils.rm_f(@original_file_path)

        # Restore backup
        FileUtils.mv(@backup_path, @original_file_path) if File.exist?(@backup_path)

        # Remove test wrapper instance
        return unless @wrapper&.valid?

          Sketchup.active_model.entities.erase_entities(@wrapper)
      end

      def test_save_and_file_creation
        preset_name = "TestPreset_A"
        # Mock config snapshot
        snapshot = {
          parameters: { test_param: 123 },
          ranges: {},
          component_names: {}
        }

        result = JtHyperbolicCurvesUI::PresetManager.save_preset(@wrapper, preset_name, snapshot)

        assert(result[:success], "Save should return success. Error: #{result[:error]}")
        assert(File.exist?(@original_file_path), "Presets file should be created")

        content = File.read(@original_file_path)
        assert(content.include?(preset_name), "File content should include the preset name")
      end

      def test_load_from_file_simulation
        # Manually write a preset to file that is NOT in wrapper
        file_only_preset = {
          preset_name: "FileOnly",
          created_at: Time.now.iso8601,
          modified_at: Time.now.iso8601,
          parameters: { p: 1 },
          ranges: {},
          component_names: {}
        }

        # Use send to access private method or just rely on public API if possible.
        # Since load_from_file is private, we might need to bypass or test public side effects.
        # But for test purposes, let's use send to set up state.
        current_list = JtHyperbolicCurvesUI::PresetManager.send(:load_from_file)
        current_list << file_only_preset
        JtHyperbolicCurvesUI::PresetManager.send(:save_to_file, current_list)

        # Verify it appears in list_presets (which triggers sync)
        presets = JtHyperbolicCurvesUI::PresetManager.list_presets(@wrapper)
        assert(presets.include?("FileOnly"), "Preset from file should appear in list")
      end

      def test_synchronization_collision
        # 1. Create Preset "Collision" in File (Value A)
        val_a = { p: "A" }
        preset_a = {
          preset_name: "Collision",
          created_at: Time.now.iso8601,
          modified_at: Time.now.iso8601,
          parameters: val_a
        }
        JtHyperbolicCurvesUI::PresetManager.send(:save_to_file, [preset_a])

        # 2. Create Preset "Collision" in Wrapper (Value B)
        val_b = { p: "B" }
        preset_b = preset_a.dup
        preset_b[:parameters] = val_b

        attr_dict = JtHyperbolicCurvesUI::PresetManager::PRESET_DICT
        @wrapper.set_attribute(attr_dict, "Collision", preset_b.to_json)

        # 3. Trigger Sync via list_presets
        list = JtHyperbolicCurvesUI::PresetManager.list_presets(@wrapper)

        # 4. Expect "Collision" and "Collision #1" (renamed duplicate)
        assert(list.include?("Collision"), "Original name should exist")
        assert(list.any? { |n| n.start_with?("Collision #") }, "Renamed duplicate should exist")
      end

      def test_global_presets_no_wrappers
        # 1. Clear Wrappers for this specific test
        # We need to ensure NO wrappers exist. teardown handles current @wrapper,
        # but let's be explicit here or momentarily hide it.
        # Actually teardown runs AFTER this. So @wrapper exists.
        # We should delete it for this test.
        Sketchup.active_model.entities.erase_entities(@wrapper) if @wrapper&.valid?
        @wrapper = nil # Prevent double delete in teardown

        # Ensure file is empty/fresh
        FileUtils.rm_f(@original_file_path)

        # 2. Create File Preset
        preset = { preset_name: "GlobalOnly", parameters: {} }
        JtHyperbolicCurvesUI::PresetManager.send(:save_to_file, [preset])

        # 3. List
        list = JtHyperbolicCurvesUI::PresetManager.list_global_presets

        # 4. Expect presence
        assert(list.include?("GlobalOnly"), "Global presets should list file presets")
      end

      def test_global_presets_with_wrappers
        # 1. Preset in File
        preset_f = { preset_name: "FromFile", parameters: { x: 1 } }
        JtHyperbolicCurvesUI::PresetManager.send(:save_to_file, [preset_f])

        # 2. Preset in Wrapper
        preset_w = { preset_name: "FromWrapper", parameters: { x: 2 } }
        attr_dict = JtHyperbolicCurvesUI::PresetManager::PRESET_DICT
        @wrapper.set_attribute(attr_dict, "FromWrapper", preset_w.to_json)

        # 3. List Global
        list = JtHyperbolicCurvesUI::PresetManager.list_global_presets

        # 4. Expect Both
        assert(list.include?("FromFile"), "Should include file preset")
        assert(list.include?("FromWrapper"), "Should include wrapper preset")
      end
    end
  end
end
