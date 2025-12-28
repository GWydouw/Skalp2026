module Skalp
  module Material_dialog
    def self.duplicate_material_in_library(library_name, material_name)
      json_path = File.join(Skalp::MATERIAL_PATH, "#{library_name}.json")
      return unless File.exist?(json_path)

      json_data = begin
        JSON.parse(File.read(json_path))
      rescue StandardError
        []
      end
      pattern_info = json_data.find { |info| info["name"] == material_name }
      return unless pattern_info

      new_name = UI.inputbox(["New Name"], ["#{material_name} copy"], "Duplicate Material")
      return unless new_name && new_name[0] != ""

      new_name = new_name[0]

      if json_data.any? { |info| info["name"] == new_name }
        UI.messagebox("Material '#{new_name}' already exists.")
        return
      end

      new_pattern = pattern_info.dup
      new_pattern["name"] = new_name
      json_data << new_pattern

      # Should we generate a new thumbnail?
      # The thumbnail is based on the texture/color.
      # Since it's a duplicate, we can copy the thumbnail too if it exists.
      old_thumb = File.join(CACHE_DIR, "#{library_name}", "#{material_name}.png")
      new_thumb = File.join(CACHE_DIR, "#{library_name}", "#{new_name}.png")
      FileUtils.cp(old_thumb, new_thumb) if File.exist?(old_thumb)

      File.write(json_path, JSON.pretty_generate(json_data))
    end

    def self.rename_library(old_name)
      return if old_name.include?("in model") # Protect internal names

      new_name = UI.inputbox(["New Library Name"], [old_name], "Rename Library")
      return unless new_name && new_name[0] != ""

      new_name = new_name[0]
      return if new_name == old_name

      old_path = File.join(Skalp::MATERIAL_PATH, "#{old_name}.json")
      new_path = File.join(Skalp::MATERIAL_PATH, "#{new_name}.json")

      old_cache = File.join(CACHE_DIR, old_name)
      new_cache = File.join(CACHE_DIR, new_name)

      if File.exist?(new_path)
        UI.messagebox("Library '#{new_name}' already exists.")
        return
      end

      # Rename JSON
      File.rename(old_path, new_path) if File.exist?(old_path)

      # Rename Cache Dir
      File.rename(old_cache, new_cache) if File.exist?(old_cache)

      @active_library = new_name
      new_name
    end

    def self.delete_library(library_name)
      return if library_name.include?("in model")

      result = UI.messagebox("Are you sure you want to delete library '#{library_name}'?", MB_YESNO)
      return if result == IDNO

      path = File.join(Skalp::MATERIAL_PATH, "#{library_name}.json")
      cache_dir = File.join(CACHE_DIR, library_name)

      File.delete(path) if File.exist?(path)
      FileUtils.rm_rf(cache_dir) if File.exist?(cache_dir)

      @active_library = "Skalp materials in model"
      true
    end
  end
end
