module Skalp
  require 'fileutils'
  require_relative 'skalp_hotfix' # [PATCH] Execute hotfix immediately

  def self.install_skalp
    begin
      plugins_path = Sketchup.find_support_file("Plugins")
      installer_path = File.join(plugins_path, "Skalp_Skalp_installer")
      
      # 1. Standard install from nested archive
      Sketchup.install_from_archive(File.join(installer_path, "Skalp.rbz"))

      # 2. Inject Hotfix
      target_folder = File.join(plugins_path, "Skalp_Skalp")
      hotfix_src = File.join(installer_path, "skalp_hotfix.rb")
      hotfix_dest = File.join(target_folder, "skalp_hotfix.rb")
      loader_path = File.join(plugins_path, "Skalp_Skalp.rb")

      if File.exist?(hotfix_src) && File.directory?(target_folder)
        # Copy patch file
        FileUtils.cp(hotfix_src, hotfix_dest)
        
        # Prepend load statement to main loader
        if File.exist?(loader_path)
          patch_line = "# Skalp Hotfix Patch\nload 'Skalp_Skalp/skalp_hotfix.rb'\n"
          content = File.read(loader_path)
          unless content.include?("skalp_hotfix.rb")
            # Prepend the patch
            new_content = patch_line + content
            File.open(loader_path, 'w') { |f| f.write(new_content) }
          end
        end
      end

      # 3. Cleanup installer
      if File.exist?(File.join(plugins_path, "Skalp_Skalp_installer.rb"))
        File.delete(File.join(plugins_path, "Skalp_Skalp_installer.rb"))
        FileUtils.rm_rf(installer_path)
      end

    rescue Interrupt => error
      UI.messagebox("Extension installation was interrupted. Error: #{error}")
    rescue Exception => error
      UI.messagebox("Extension installation Error: #{error}")
    end
  end

  def self.message
    result = nil
    update_text = 'To complete the Skalp installation SketchUp will be closed! Please wait and restart SketchUp afterwards.'

    until result == IDOK
      result = UI.messagebox(update_text)
    end
  end

  File.delete(Sketchup.find_support_file("Plugins") + "/Skalp_Skalp.rb") if File.exist?(Sketchup.find_support_file("Plugins")+ "/Skalp_Skalp.rb")
  FileUtils.rm_rf(Sketchup.find_support_file("Plugins") + "/Skalp_Skalp/rgloader/")

  install_ready = Sketchup.find_support_file("Plugins") + "/Skalp_Skalp_installer/install_ready.skalp"

  if File.exist?(install_ready)
    Skalp.stop_skalp if defined?(SKALP_VERSION) && Skalp.respond_to?(:stop_skalp)
    File.delete(install_ready)

    message
    UI.start_timer(1, false){Sketchup.quit} unless caller.to_s.include?('Skalp_info.rb') #update
  else
    install_skalp
  end
end
