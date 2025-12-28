
#-----------------------------------------------------------------------------
# Name        :   Skalp for SketchUp
# Description :   A script that loads Skalp as an extension to SketchUp
# Version     :   #SKALPVERSION#
# Date        :   #SKALPBUILDDATE#
#-----------------------------------------------------------------------------
# Copyright 2014-2026, Skalp

require 'sketchup.rb'

module Skalp
  attr_reader :installer_extension
  require 'extensions.rb'

  def self.load_extension
    @installer_extension = SketchupExtension.new "Skalp installer", "Skalp_Skalp2026_installer/install_Skalp.rb"
    @installer_extension.version = '2026.0'
    @installer_extension.copyright = "2014-2026, Skalp"
    @installer_extension.creator = "Skalp"
    @installer_extension.description = 'Extension to install Skalp'
    Sketchup.register_extension @installer_extension, true
  end

  def self.remove_skalp
    begin
      if File.exist?(Sketchup.find_support_file("Plugins")+ "/Skalp_Skalp2026_installer.rb")
        File.delete(Sketchup.find_support_file("Plugins")+ "/Skalp_Skalp2026_installer.rb")
        FileUtils.rm_rf(Sketchup.find_support_file("Plugins")+ "/Skalp_Skalp2026_installer")
      end

    rescue Interrupt => error
      UI.messagebox("Extension installation was interrupted. Error: #{error}")
    rescue Exception => error
      UI.messagebox("Extension installation Error: #{error}")
    end
  end

  if Sketchup.version[0..0].to_i == 9
    su_version = Sketchup.version[0..1].to_i - 70
  else
    su_version = Sketchup.version[0..1].to_i
  end

  if su_version == 26
    if RUBY_PLATFORM.downcase.include?('arm64')
      message = "Skalp 2026 on Apple M1/M2/M3 is now supported. However you need to allow downloaded apps under System Preferences > Security and Privacy and then Restart SketchUp. (More info see: https://support.apple.com/en-us/HT202491)"
      UI.messagebox(message)
      load_extension
    else
      load_extension
    end
  else
    result = UI.messagebox("This Skalp version can only be installed on SketchUp 2026 and will be removed. Do you want to download the Skalp version for SketchUp 20#{su_version} from our website?", MB_YESNO)
    UI.openURL("http://download.skalp4sketchup.com/downloads/latest/") if result == IDYES
    remove_skalp
  end
end



