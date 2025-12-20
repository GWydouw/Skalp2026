module Skalp
  require 'fileutils'

  def self.install_skalp
    begin
      Sketchup.install_from_archive(Sketchup.find_support_file("Plugins") + "/Skalp_Skalp_installer/Skalp.rbz")

      if File.exist?(Sketchup.find_support_file("Plugins")+ "/Skalp_Skalp_installer.rb")
        File.delete(Sketchup.find_support_file("Plugins")+ "/Skalp_Skalp_installer.rb")
        FileUtils.rm_rf(Sketchup.find_support_file("Plugins")+ "/Skalp_Skalp_installer")
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
    Skalp.stop_skalp if defined?(SKALP_VERSION) == 'constant'
    File.delete(install_ready)

    message
    UI.start_timer(1, false){Sketchup.quit} unless caller.to_s.include?('Skalp_info.rb') #update
  else
    install_skalp
  end
end
