#-------------------------------------------------------------------------------
# Name        :   Skalp for SketchUp
# Description :   Professional Cross Sections and Hatch Patterns inside SketchUp
# Version     :   2026.0.0001
# Date        :   07 march 2025
#-------------------------------------------------------------------------------
# Copyright 2014-2026, Skalp

# Error in combination with Enscape3D
# Adding or changing layer triggers a layer observer of Enscape which create the LayerHelperClass with an eval from
# a C-extension and for some reason this creation happen not on time when it is triggerd from the Skalp extensiion
#
# Solution is to trigger the Enscape layer observer before Skalp is started
#
if defined?(Enscape) && !defined?(Enscape::LayerHelperClass)
  status = Sketchup.active_model.layers["Layer0"].visible?
  Sketchup.active_model.layers["Layer0"].visible = !status
  Sketchup.active_model.layers["Layer0"].visible = status
end

require "sketchup"
require "langhandler"
require "etc"
require "socket"

module Skalp
  def self.remove_wrong_rgloader
    $LOADED_FEATURES.select { |i| i.include?("rgloader") }.each do |path|
      next if path.include?("Skalp_Skalp2026")

      $LOADED_FEATURES.delete path
      defined?(RGLoader) && Object.send(:remove_const, :RGLoader)
      if File.exist?(Sketchup.find_support_file("Plugins") + "/Skalp_Skalp2026/Skalp.lic")
        load "Skalp_Skalp2026/Skalp_lic.rb"
      end
    end
  end

  attr_reader :skalp_extension

  SKALP_PATH = Sketchup.find_support_file("Plugins") + "/Skalp_Skalp2026/"
  # Load Version
  require_relative "Skalp_Skalp2026/version"

  SKALP_VERSION = Skalp::VERSION
  SKALP_MAJOR_VERSION = SKALP_VERSION.split(".")[0] + "." + SKALP_VERSION.split(".")[1]
  SKALP_SUPPORT = "support@skalp4sketchup.com".freeze
  SKALP_WEBSITE = "www.skalp4sketchup.com".freeze
  SKETCHUP_VERSION = if Sketchup.version[0..0].to_i == 9
                       Sketchup.version[0..1].to_i - 70
                     else
                       Sketchup.version[0..1].to_i
                     end

  SU_USER_PATH = Dir.getwd
  COMPUTERNAME = Socket.gethostname
  USERNAME = Etc.getlogin
  OS = RUBY_PLATFORM.include?("darwin") ? :MAC : :WINDOWS
  @version_required = 26
  @version_max = 26

  # Standard Loader
  Sketchup.require "Skalp_Skalp2026/Skalp_translator"

  options = {
    custom_path: Sketchup.find_support_file("Plugins") + "/Skalp_Skalp2026/resources/strings/",
    debug: false
  }

  language = Sketchup.read_default("Skalp", "language")
  language ||= "en-US"
  @translator = Translator.new("skalp.strings", options, language)

  def self.translate(string)
    translated = @translator.get(string)
    if !translated.nil? && translated != ""
      translated
    else
      string
    end
  end

  # --- Skalp Development Mode ---
  DEV_LOADER = File.join(__dir__, "Skalp_Skalp2026", "dev_loader.rb")
  DEV_MODE = File.exist?(DEV_LOADER)

  if DEV_MODE
    # puts ">>> Skalp Development Mode: Active"
    begin
      require DEV_LOADER
      # puts ">>> DevLoader required successfully"

      if defined?(Skalp) && Skalp.respond_to?(:load_development_mode)
        # puts ">>> Calling Skalp.load_development_mode..."
        Skalp.load_development_mode
      else
        puts "!!! ERROR: Skalp.load_development_mode not defined!"
        puts "    defined?(Skalp) = #{defined?(Skalp)}"
        puts "    Skalp.respond_to?(:load_development_mode) = #{begin
          Skalp.respond_to?(:load_development_mode)
        rescue StandardError
          'ERROR'
        end}"
      end
    rescue StandardError => e
      puts "!!! DevLoader Error: #{e.class}: #{e.message}"
      puts e.backtrace.first(10).join("\n")
    end
  end

  def self.check_username
    test_path = __dir__
    test_path == test_path.encode("utf-8")
  end

  def self.check_IE_version
    require "win32/registry"
    begin
      # IEX10, IEX11
      Win32::Registry::HKEY_LOCAL_MACHINE.open('Software\Microsoft\Internet Explorer',
                                               Win32::Registry::KEY_QUERY_VALUE) do |reg|
        ie_version = reg["svcVersion"].to_s.split(".").first.to_i
      end
    rescue StandardError
      # IEX8, IEX9
      Win32::Registry::HKEY_LOCAL_MACHINE.open('Software\Microsoft\Internet Explorer',
                                               Win32::Registry::KEY_QUERY_VALUE) do |reg|
        ie_version = reg["Version"].to_s.split(".").first.to_i
      end
    end

    @ie_check = !(ie_version < 10)
  rescue StandardError
    @ie_check = true
  ensure
    load_extension
  end

  def self.load_extension
    return if defined?(DEV_MODE) && DEV_MODE

    if @ie_check == false
      UI.messagebox("#{Skalp.translate('You need Internet Explorer 10 or higher to run Skalp.')} #{Skalp.translate('Visit microsoft.com to update.')}")
    else
      @skalp_extension = SketchupExtension.new "Skalp", "Skalp_Skalp2026/Skalp_loader.rb"
      @skalp_extension.version = SKALP_VERSION

      @skalp_extension.copyright = "2014-2022, Skalp"
      @skalp_extension.creator = "Skalp"
      @skalp_extension.description =
        Skalp.translate("Create Stunning Live Section Cuts.") + " " +
        Skalp.translate("Import and tweak standard CAD Pattern files.") + " (*.pat) " +
        Skalp.translate("Use Skalp Styles to tweak Section Cut representations.") + " " +
        Skalp.translate("Keep plans and elevations up to date in Layout.") + " " +
        Skalp.translate("Export 2D Section Cuts to DXF.") + " " +
        Skalp.translate("More info:") + " " + SKALP_WEBSITE
      Sketchup.register_extension @skalp_extension, true
    end
  end

  if SKETCHUP_VERSION.to_f < @version_required
    UI.messagebox("#{Skalp.translate('You need Sketchup')} 20#{@version_required} #{Skalp.translate('or higher to run Skalp.')} #{Skalp.translate('Visit sketchup.com to upgrade.')}")
  elsif SKETCHUP_VERSION.to_i > @version_max
    message = "Skalp version #{SKALP_MAJOR_VERSION} only works with SketchUp 20#{@version_required}-20#{@version_max}. Please install the correct SketchUp version or download the correct Skalp version from our website at www.skalp4sketchup.com \n\nIf you have more questions about Skalp requirements, please contact us at support@skalp4sketchup.com"

    UI.messagebox(message)
  else
    require "fileutils"
    require "SecureRandom"

    SecureRandom.uuid # Workaround for very slow fist sectionplane ADD on windows

    skalplic = File.join(SKALP_PATH, "Skalp.lic")
    if File.exist?(skalplic)
      File.size?(skalplic) || FileUtils.remove_entry(skalplic) # remove Skalp.lic if the file is empty.
    end

    if File.exist?(Sketchup.find_support_file("Plugins") + "/Skalp.rb")
      FileUtils.remove_entry(Sketchup.find_support_file("Plugins") + "/Skalp.rb",
                             true)
    end

    require "extensions"

    @ie_check = true

    if OS == :WINDOWS
      if check_username
        check_IE_version
      else
        message =
          Skalp.translate("Sketchup Extension Error") + "\n" +
          Skalp.translate("Skalp cannot run because your Windows User Profile path contains special or foreign language characters such as ç, é, à,...") + "\n" +
          Skalp.translate("Sketchup's Ruby cannot load files from such a path.") + "\n\n" +
          Skalp.translate("Currently you can work around this issue as follows:") + "\n" +
          Skalp.translate("1. Create a new user on your computer without any special characters in it's name.") + "\n" +
          Skalp.translate("2. Login as this new user and install / run SketchUp.") + "\n" +
          Skalp.translate("3. Optional: After creating this new User Profile, you may change your user name back to your real name including any special characters (ç, é, à,...).") + " " + "\n"
        Skalp.translate("When renaming a user, Windows will NOT change the actual User Profile path itself, so everything keeps working.") + "\n\n" +
          Skalp.translate("We do understand this is not an elegant solution, as you end up with either 2 user accounts, switching back and forth, or having to move a lot of stuff to the new User Profile manually.") + "\n\n" +
          Skalp.translate("For windows 7, Microsoft also explains how to change your existing User Profile here:") + "\n\n" +
          "http://social.technet.microsoft.com/wiki/contents/articles/19834.how-to-rename-a-windows-7-user-account-and-related-profile-folder.aspx"

        UI.messagebox(message, MB_MULTILINE, "SKALP")
      end
    else
      load_extension
    end
  end
end
# end
