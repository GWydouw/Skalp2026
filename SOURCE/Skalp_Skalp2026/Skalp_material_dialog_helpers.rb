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

      Skalp.inputbox_custom(["New Name"], ["#{material_name} copy"], "Duplicate Material") do |new_name|
        return unless new_name && new_name[0].to_s.strip != ""

        new_name = new_name[0].to_s.strip

        if json_data.any? { |info| info["name"] == new_name }
          UI.messagebox("Material '#{new_name}' already exists.")
          next
        end

        new_pattern = pattern_info.dup
        new_pattern["name"] = new_name
        json_data << new_pattern

        old_thumb = File.join(CACHE_DIR, "#{library_name}", "#{material_name}.png")
        new_thumb = File.join(CACHE_DIR, "#{library_name}", "#{new_name}.png")
        FileUtils.cp(old_thumb, new_thumb) if File.exist?(old_thumb)

        File.write(json_path, JSON.pretty_generate(json_data))
        Skalp::Material_dialog.create_thumbnails(library_name)
      end
    end

    def self.rename_library(old_name)
      return if old_name.include?("in model") # Protect internal names

      Skalp.inputbox_custom(["New Library Name"], [old_name], "Rename Library") do |new_name|
        return unless new_name && new_name[0].to_s.strip != ""

        new_name = new_name[0].to_s.strip
        next if new_name == old_name

        old_path = File.join(Skalp::MATERIAL_PATH, "#{old_name}.json")
        new_path = File.join(Skalp::MATERIAL_PATH, "#{new_name}.json")

        old_cache = File.join(CACHE_DIR, old_name)
        new_cache = File.join(CACHE_DIR, new_name)

        if File.exist?(new_path)
          UI.messagebox("Library '#{new_name}' already exists.")
          next
        end

        File.rename(old_path, new_path) if File.exist?(old_path)
        File.rename(old_cache, new_cache) if File.exist?(old_cache)

        @active_library = new_name
        Skalp::Material_dialog.load_libraries # Reload list
        Skalp::Material_dialog.active_library = new_name # Force update active
        if Skalp::Material_dialog.materialdialog
          Skalp::Material_dialog.materialdialog.execute_script("library('#{new_name}')")
        end
        Skalp::Material_dialog.create_thumbnails(new_name)
      end
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
