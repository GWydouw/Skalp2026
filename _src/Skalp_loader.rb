module Skalp

  require 'sketchup'
  require 'fileutils'
  require 'base64'
  require 'logger'

  DEBUG = true

  LICENSE_SERVER = "license.skalp4sketchup.com" #"license.skalp4sketchup.com"
  DOWNLOAD_SERVER = "license.skalp4sketchup.com"

  # centralized to avoid issues with translation mismatches due to typos in the code:
  NO_ACTIVE_SECTION_PLANE = Skalp.translate('no active Section Plane')

  def self.insert_version_check_code
    code = <<-EOF
def exit_skalp
@status = 0
@dialog.close  if @dialog && @dialog.visible?
@hatch_dialog.close if @hatch_dialog
@hatch_dialog = nil
@clipper = nil
@clipperOffset = nil
if Sketchup.active_model && @models
@models.each_value do |model|
next unless model && model.skpModel.valid?
model.unload_observers
end
end
@active_model = nil
@last_error = ''
@unloaded = true
@models = {}
Sketchup.remove_observer(@skalp_observer) if @skalp_observer
@skalp_observer = nil
Sketchup.active_model.abort_operation
skalpbutton_off
UI.start_timer(0.1,false){SKETCHUP_CONSOLE.clear; Sketchup.active_model.abort_operation}
abort('Skalp is stopped')
end
skalp_version = SKALP_VERSION.split('.')[0].to_i
model = Sketchup.active_model
version = model.get_attribute('Skalp_memory_attributes', 'skpModel|skalp_version')
if skalp_version < 3 #version.split('.')[0].to_i
UI.messagebox("Your model \'\#{File.basename(model.path)}\' was saved with a newer Skalp version. Please install Skalp \#{version} or higher to edit this model. Skalp will be stopped now.")
exit_skalp
end
    EOF

    Sketchup.active_model.set_attribute('Skalp', 'version_check', "eval(eval(%Q(Base64.decode64('#{Base64.encode64(code).gsub!("\n", "")}'))))")
  end

  # API to update custom objects from other extensions
  def self.object_updated(entity)
    if Skalp.status == 1 && (entity.class == Sketchup::Group || entity.class == Sketchup::ComponentInstance)

      entity.definition.instances.each do |instance|
        entities = instance.parent.entities

        data = {
            :action => :removed_element,
            :entities => entities,
            :entity_id => instance
        }
        Skalp.models[Sketchup.active_model].controlCenter.add_to_queue(data)

        data = {
            :action => :add_element,
            :entities => entities,
            :entity => instance
        }
        Skalp.models[Sketchup.active_model].controlCenter.add_to_queue(data) if instance.valid?
      end
    end

  rescue
    #to ensure this doesn't crash Skalp
  end

  def self.set_pattern_info_attribute(material, pattern_info)
    Skalp.active_model.start('Skalp - set pattern info')
    material.set_attribute('Skalp', 'pattern_info', "eval(Sketchup.active_model.get_attribute('Skalp', 'version_check').to_s);#{pattern_info}")
    Skalp.active_model.commit
  end

  def self.remove_license
    FileUtils.remove_entry(Sketchup.find_support_file("Plugins")+"/Skalp_Skalp/Skalp.lic", true) if File.exist?(Sketchup.find_support_file("Plugins")+"/Skalp_Skalp/Skalp.lic")
  end

  def self.read_classroom_settings
    guid = Sketchup.read_default('Skalp', 'guid')
    id = Sketchup.read_default('Skalp', 'id')

    return if guid && id

    classroom_file = SKALP_PATH + 'classroom_settings'

    if File.exist?(classroom_file)
      lines = []
      File.open(classroom_file, 'r').each do |line|
        lines << line
      end

      guid = lines[0].unpack("u")[0]
      id = lines[1]

      Sketchup.write_default('Skalp', 'guid', guid)
      Sketchup.write_default('Skalp', 'id', id.to_i)
      Sketchup.write_default('Skalp', 'license_version', 2)
      Sketchup.write_default('Skalp', 'tolerance2', '0.0394')
    end
  end

  def self.write_classroom_settings
    return unless license_type == 'CLASSROOM'

    classroom_file = SKALP_PATH + 'classroom_settings'

    unless File.exist?(classroom_file)
      guid = Sketchup.read_default('Skalp', 'guid')
      id = Sketchup.read_default('Skalp', 'id')

      if guid && id
        file = File.open(classroom_file, 'w')
        file.write([guid].pack("u"))
        file.write(id)
        file.close
      end
    end
  end

  if File.exist?(SKALP_PATH + 'classroom_settings')
    read_classroom_settings
  end

  if File.exist?(Sketchup.find_support_file("Plugins")+"/Skalp_Skalp/Skalp.lic") && (Sketchup.read_default('Skalp', 'guid') == nil || Sketchup.read_default('Skalp', 'id') == nil)
    remove_license
  end

  FileUtils.remove_entry(Sketchup.find_support_file("Plugins") + '/Skalp_Skalp/Skalp_geom.rbs', true) if File.exist?(Sketchup.find_support_file("Plugins")+ '/Skalp_Skalp/Skalp_geom.rbs')
  FileUtils.remove_entry(Sketchup.find_support_file("Plugins") + '/Skalp_Skalp/Skalp_lib.rbs', true) if File.exist?(Sketchup.find_support_file("Plugins")+ '/Skalp_Skalp/Skalp_lib.rbs')
  FileUtils.remove_entry(Sketchup.find_support_file("Plugins") + '/Skalp_Skalp/Skalp_isolate.rbs', true) if File.exist?(Sketchup.find_support_file("Plugins") + '/Skalp_Skalp/Skalp_isolate.rbs')

  Sketchup::require 'Skalp_Skalp/Skalp_info'

  @log = Logger.new(SKALP_PATH + 'Skalp_log.txt')
  @log.level = Logger::INFO
  @log.info("Skalp version: " + SKALP_VERSION)
  @log.info("Sketchup version: " + Sketchup.version)

  EXPIRE_DATE = Time.new(2025, 12, 31) #TODO set beta expire date

  @log.info("OS: " + RUBY_PLATFORM + " " + Sketchup.os_language)

  def self.encoderError(code)
    case code
      when 3
        guid = Sketchup.read_default('Skalp', 'guid')

        deactivation_text =
            "Skalp #{Skalp.translate("needs to be reactivated.")} (#{Skalp.translate('system change detected')})"+"\n\n" +
                Skalp.translate("Please copy your License Activation Code:")+"\n#{guid}\n" +
                Skalp.translate("Paste this code into the Skalp Info Dialog and reactivate.") + "\n\n"

        UI.messagebox(deactivation_text, MB_OK)
        auto_deactivate(guid)
      else
        Sketchup.write_default("Skalp", "encoderError", code);
    end
    result = UI.messagebox(Skalp.translate("SketchUp will close now.") + "\n" +
                               Skalp.translate("Do you want to save your model first?"), MB_YESNO)
    Sketchup.send_action 'saveDocument:' if result == 6
    exit!
  end

  def auto_deactivate(guid, clean = true)
    id = Sketchup.read_default('Skalp', 'id')

    remove_license

    uri = URI("http://#{LICENSE_SERVER}/register_2_0/deactivate.php?hid=#{id}&guid=#{guid}")
    if Net::HTTP.get(uri)
      Sketchup.write_default('Skalp', 'guid', nil) if clean
      Sketchup.write_default('Skalp', 'id', nil) if clean
    else
      UI.messagebox("#{Skalp.translate("Error while deactivating License. Please contact")} #{SKALP_SUPPORT}")
    end
  end

  def self.encoderErrorCheck
    encoderError = Sketchup.read_default('Skalp', 'encoderError')
    encoderError = 9999 unless encoderError

    if encoderError == 9999
      Sketchup::require 'Skalp_Skalp/Skalp_version'
      Sketchup::require 'Skalp_Skalp/Skalp_lic' if File.exist?(Sketchup.find_support_file("Plugins")+"/Skalp_Skalp/Skalp.lic")
      return false
    else
      @log.error('encoderError: ' + encoderError.to_s)
      case encoderError
        when 3 # wrong mac
          remove_license
          #FileUtils.remove_entry(Sketchup.find_support_file("Plugins")+"/Skalp.rb", true) if File.exist?(Sketchup.find_support_file("Plugins")+"/Skalp.rb")
          Sketchup.write_default('Skalp', 'encoderError', 9999)
        when 9 # expired
          if Time.now()> EXPIRE_DATE #beta version expired
            Sketchup.write_default('Skalp', 'encoderError', 9999)
            install_new_version
          else
            FileUtils.remove_entry(Sketchup.find_support_file("Plugins")+"/Skalp.rb", true) if File.exist?(Sketchup.find_support_file("Plugins")+"/Skalp.rb")
            Sketchup.write_default('Skalp', 'encoderError', 9999)
            remove_license
          end
        else
          UI.messagebox("#{Skalp.translate("Error")}: Skalp encoder #{encoderError}. " +
                            Skalp.translate("Try to restart SketchUp 2 times to solve this problem.")+" \n" +
                            Skalp.translate("If this does not solve the problem, please contact") + " #{SKALP_SUPPORT}")

          Sketchup.write_default('Skalp', 'encoderError', 9999)
      end
      return true
    end
  end

  def self.iscarnet_check
    iscarnet = false
    if File.exist?(Sketchup.find_support_file("Plugins")+"/iscarnet_dibac.rb") || File.exist?(Sketchup.find_support_file("Plugins")+"/iscarnet_ss.rb")
      extensions = Sketchup.extensions
      for extension in extensions
        unsupported =
            Skalp.translate("Disclaimer: Running Skalp and") + " #{extension.name} " +
                Skalp.translate("concurrently is unsupported at this time and may yield unexpected results.") + "\n" <<
                Skalp.translate("Skalp will not be able to show section results whenever a") + " #{extension.name} " <<
                Skalp.translate("is already shown in the same location.") + "\n\n" <<
                Skalp.translate("Proceed loading Skalp at your own risk?")
        if extension.name == 'SolidSection' #|| extension.name == 'Dibac'
          if extension.loaded?
            # iscarnet = true
            concurrent_text =
                "#{extension.name} " + Skalp.translate("extension detected.") + "\n\n" <<
                    Skalp.translate("Sorry, running Skalp and") + " #{extension.name} " +
                        Skalp.translate("concurrently will yield unexpected results.") + "\n" <<
                    Skalp.translate("In order to run Skalp as intended, we have to advise you to uncheck") + " '#{extension.name}" + "' " <<
                    Skalp.translate("from the SketchUp Preferences Extensions manager.") + "\n\n" <<
                    Skalp.translate("Would you like us to do this for you now?")
            if UI.messagebox(concurrent_text, MB_YESNO) == IDYES
              extension.uncheck
              restart_text =
                  "#{extension.name} " + Skalp.translate("is uninstalled.") + "\n" <<
                      Skalp.translate("A SketchUp restart is needed to effectuate this change.") + "\n\n" <<
                      Skalp.translate("SketchUp will be closed.") + "\n" <<
                      Skalp.translate("You will be asked to save your model if necessary.")
              UI.messagebox(restart_text, MB_OK)
              Sketchup.quit
            else

              if UI.messagebox(unsupported, MB_YESNO) == IDNO
                iscarnet = true
              end
            end
          end
        elsif extension.name == 'Dibac' && Sketchup.read_default("Dibac","SolidSection") == true
          # iscarnet = true
          concurrent_text =
              "#{extension.name} " + Skalp.translate("extension detected.") + "\n\n" <<
                  Skalp.translate("Sorry, running Skalp and") + " #{extension.name} " +
                      Skalp.translate("concurrently will yield unexpected results.") + "\n" <<
                  Skalp.translate("In order to run Skalp as intended, we will disable the SolidSection function from ") + " '#{extension.name}" + "' " + "\n\n" <<
                  Skalp.translate("Would you like us to do this for you now?")
          if UI.messagebox(concurrent_text, MB_YESNO) == IDYES
             Sketchup.write_default("Dibac","SolidSection", false)
            restart_text =
                Skalp.translate("SolidSection is disabled.") + "\n" <<
                    Skalp.translate("A SketchUp restart is needed to effectuate this change.") + "\n\n" <<
                    Skalp.translate("SketchUp will be closed.") + "\n" <<
                    Skalp.translate("You will be asked to save your model if necessary.")
            UI.messagebox(restart_text, MB_OK)
            Sketchup.quit
          else
            if UI.messagebox(unsupported, MB_YESNO) == IDNO
              iscarnet = true
            end
          end
        end
      end
    end
    return iscarnet
  end


  # Restore incorrect application of Set shim in global space:
  # Set = Sketchup::Set
  # Workaround for:
  # I suppose one of the following plugins is guilty on NOT wrapping Set = Sketchup::Set in a module.
  # cfr mail Thomas Thomassen 15 augustus 2015
  def sketchup_set_class_repair
    return unless Set && Sketchup::Set
    if Set == Sketchup::Set
      set_rb_file = File.join($LOAD_PATH.find { |path| File.exist?(File.join(path, 'set.rb')) }, 'set.rb')
      item = $LOADED_FEATURES.find { |feature| feature == set_rb_file }
      $LOADED_FEATURES.delete(item)

      unless item
        Skalp.send_info('BrokenSetClassError', ":sketchup_set_class_repair called by method: #{caller_locations(1, 1)[0].label}", 'COULD NOT FIX: Set = Sketchup::Set (detected non-Skalp incorrect application in global space)')
        return
      end
      Object.send(:remove_const, :Set)
      Object.send(:remove_const, :SortedSet)

      require 'set'
      Skalp.send_info('FIXED BrokenSetClassError', ":sketchup_set_class_repair called by method: #{caller_locations(1, 1)[0].label}", 'FIXED: Set = Sketchup::Set (detected non-Skalp incorrect application in global space)')
    end
  end

  if Time.now()> EXPIRE_DATE
    @version_expired = true
    encoderErrorCheck
    show_info([:update])
  else

    @version_expired = false

    def self.load_default_pat_file
      FileUtils.mkdir(SKALP_PATH + "resources/styles/") unless File.directory?(SKALP_PATH + "resources/styles/")
      FileUtils.mkdir(SKALP_PATH + "resources/materials/") unless File.directory?(SKALP_PATH + "resources/materials/")
      FileUtils.mkdir(SKALP_PATH + "resources/layermappings/") unless File.directory?(SKALP_PATH + "resources/layermappings/")
      unless File.exist?(SKALP_PATH + 'resources/hatchpats/skalp.pat')
        FileUtils.mkdir(SKALP_PATH + "resources/hatchpats/") unless File.directory?(SKALP_PATH + "resources/hatchpats/")
        FileUtils.copy(File.join(SKALP_PATH, 'skalp.resources'), File.join(SKALP_PATH, 'resources/hatchpats/', 'skalp.pat'))
      end
    end

    def self.rename_C
      File.rename(SKALP_PATH + 'SkalpC.so', SKALP_PATH + 'SkalpC_old.so') if File.exist?(SKALP_PATH + 'SkalpC.so')
      File.rename(SKALP_PATH + 'SkalpC.bundle', SKALP_PATH + 'SkalpC_old.bundle') if File.exist?(SKALP_PATH + 'SkalpC.bundle')
    rescue
      UI.messagebox("#{Skalp.translate("Some files are locked by the OS and can't be renamed.")} #{Skalp.translate('Please restart your computer.')}")
      return false #TODO check return value
    end

    def self.rename_old_C
      File.rename(SKALP_PATH + 'SkalpC_old.so', SKALP_PATH + 'SkalpC_old2.so') if File.exist?(SKALP_PATH + 'SkalpC_old.so')
      File.rename(SKALP_PATH + 'SkalpC_old.bundle', SKALP_PATH + 'SkalpC_old2.bundle') if File.exist?(SKALP_PATH + 'SkalpC_old.bundle')
    rescue
      UI.messagebox("#{Skalp.translate("Some old files are locked by the OS and can't be renamed.")} #{Skalp.translate('Please restart your computer.')}")
      return false #TODO check return value
    end
    
    def self.install_C
      #delete old C-extension
      begin
        FileUtils.remove_entry(SKALP_PATH + 'SkalpC_old2.so', true) if File.exist?(SKALP_PATH + 'SkalpC_old2.so')
        FileUtils.remove_entry(SKALP_PATH + 'SkalpC_old2.bundle', true) if File.exist?(SKALP_PATH + 'SkalpC_old2.bundle')
      rescue
        UI.messagebox("Some old2 files are locked by the OS and can't be removed. Please reboot your computer!")
        return false #TODO check return value
      end

      begin
        FileUtils.remove_entry(SKALP_PATH + 'SkalpC_old.so', true) if File.exist?(SKALP_PATH + 'SkalpC_old.so')
        FileUtils.remove_entry(SKALP_PATH + 'SkalpC_old.bundle', true) if File.exist?(SKALP_PATH + 'SkalpC_old.bundle')
      rescue
        rename_old_C
      end

      # #remove delete or rename c-extensions
      begin
        FileUtils.remove_entry(SKALP_PATH + 'SkalpC.so', true) if File.exist?(SKALP_PATH + 'SkalpC.so') && File.exist?(SKALP_PATH + 'SkalpC.win')
        FileUtils.remove_entry(SKALP_PATH + 'SkalpC.bundle', true) if File.exist?(SKALP_PATH + 'SkalpC.bundle') && File.exist?(SKALP_PATH + 'SkalpC.mac')
      rescue
        rename_C
      end

      #copy C_ext to correct name

      unless (File.exist?(SKALP_PATH + 'SkalpC.so') || File.exist?(SKALP_PATH + 'SkalpC.bundle'))

        FileUtils.copy(File.join(SKALP_PATH, 'SkalpC.win'), File.join(SKALP_PATH, 'SkalpC.so')) if File.exist?(SKALP_PATH + 'SkalpC.win')
        FileUtils.copy(File.join(SKALP_PATH, 'SkalpC.mac'), File.join(SKALP_PATH, 'SkalpC.bundle')) if File.exist?(SKALP_PATH + 'SkalpC.mac')

        if OS == :WINDOWS && File.exist?(SKALP_PATH + 'SkalpC.so')
          FileUtils.remove_entry(SKALP_PATH + 'SkalpC.win', true) if File.exist?(SKALP_PATH + 'SkalpC.win')
          FileUtils.remove_entry(SKALP_PATH + 'SkalpC.mac', true) if File.exist?(SKALP_PATH + 'SkalpC.mac')
        end

        if OS == :MAC && File.exist?(SKALP_PATH + 'SkalpC.bundle')
          FileUtils.remove_entry(SKALP_PATH + 'SkalpC.win', true) if File.exist?(SKALP_PATH + 'SkalpC.win')
          FileUtils.remove_entry(SKALP_PATH + 'SkalpC.mac', true) if File.exist?(SKALP_PATH + 'SkalpC.mac')
        end
      end

      #copy Skalp external application to correct name
      if (Dir::exist?(SKALP_PATH + 'lib_mac') || Dir::exist?(SKALP_PATH + 'lib_win'))
        begin
          FileUtils.remove_dir(SKALP_PATH + 'lib', true)
          if OS == :WINDOWS then
            FileUtils.mv(SKALP_PATH + "lib_win", SKALP_PATH + "lib")
            FileUtils.remove_dir(SKALP_PATH + 'lib_mac', true)
          else
            Dir.chdir(SKALP_PATH + 'lib_mac') { `tar -zxf lib_mac.tar.gz; rm lib_mac.tar.gz; mv ../lib_mac ../lib` }
            FileUtils.remove_dir(SKALP_PATH + "lib_mac", true)
            FileUtils.remove_dir(SKALP_PATH + "lib_win", true)
          end

        rescue
          UI.messagebox("#{Skalp.translate("Some old directories are locked by the OS and can't be deleted.")} #{Skalp.translate('Please restart your computer.')}")
        end
      end

      eval(Base64.decode64("cmVxdWlyZSAnU2thbHBfU2thbHAvU2thbHBDJw=="))
      require "Skalp_Skalp/Skalp_debugger_SkalpC.rb" if SKALPDEBUGGER

      return true
    end

    IMAGE_PATH = Sketchup.find_support_file("Plugins")+"/Skalp_Skalp/html/icons/"
    THUMBNAIL_PATH = Sketchup.find_support_file("Plugins")+"/Skalp_Skalp/html/thumbnails/"
    FileUtils.mkdir (THUMBNAIL_PATH) unless Dir.exist?(THUMBNAIL_PATH)

    @webdialog_require = false

    begin
      Sketchup::require 'SecureRandom'
      require 'Matrix'
    rescue
      message =
          Skalp.translate("SketchUp 2014 encountered a problem loading the Ruby standard Library when you have opened SketchUp by double clicking a SketchUp file instead of starting SketchUp from it's application icon.") +
              Skalp.translate("This is fixed in SketchUp 2014's latest maintenance release.") + ' ' +
              Skalp.translate("Close and restart SketchUp by double clicking it's application icon instead.")
      UI.messagebox(message)
    end

    Sketchup::require 'Skalp_Skalp/chunky_png/lib/chunky_png'
    Dir.chdir(SU_USER_PATH)

    result = install_C
    raise RuntimeError.new('install_C error') unless result

    if RUBY_PLATFORM.downcase.include?('arm64')
      if File.exist?(SKALP_PATH + 'eval/rgloader27.darwin.arm64.bundle')
        FileUtils.remove_entry(SKALP_PATH + 'eval/rgloader27.darwin.bundle', true) if File.exist?(SKALP_PATH + 'eval/rgloader27.darwin.bundle')
        File.rename(SKALP_PATH + 'eval/rgloader27.darwin.arm64.bundle', SKALP_PATH + 'eval/rgloader27.darwin.bundle') if File.exist?(SKALP_PATH + 'eval/rgloader27.darwin.arm64.bundle')
      end
    end

    load_default_pat_file

    skalp_require_license

    require 'Skalp_Skalp/Skalp_preferences'
    require 'Skalp_Skalp/Skalp_observers'
    require 'Skalp_Skalp/Skalp_UI'
    require 'Skalp_Skalp/Skalp_lib2.rb'
    require 'Skalp_Skalp/Skalp_geom2.rb'
    require 'Skalp_Skalp/Skalp_material_dialog.rb'
    require 'Skalp_Skalp/Skalp_paintbucket.rb'
    require 'Skalp_Skalp/Skalp_dwg_export_dialog.rb'
    require 'Skalp_Skalp/Skalp_cad_converter.rb'
    require 'Skalp_Skalp/Skalp_white_mode.rb'

    result = get_mac(false)

    raise RuntimeError.new('get_mac error') if result.nil? || result == ''

    Dir.chdir(SU_USER_PATH)

    class << self
      attr_accessor :models, :model_collection, :active_model, :page_change, #:page_switched,
                    :dxf_export, :live_section_ON, :sectionplane_active, :scene_style_nested, :style_update,
                    :dialog, :hatch_dialog, :materialSelector, :status, :string, :dialog_loading, :layers_dialog, :selectTool, :skalpTool_active, :log,
                    :clipper, :clipperOffset, :block_observers, :skalp_layout_export, :skalp_dwg_export,
                    :observer_check, :observer_check_result, :info_dialog, :info_dialog_active, :skalp_activate, :skalp_toolbar, :skalp_dwg_export, :set_bugtracking,
                    :isolate_UI_loaded, :new_pattern_layer_list, :timer_started, :converter_started,
                    :new_sectionplane, :block_color_by_layer, :skalp_paint

      attr_reader :transformation_down
    end


    @block_observers = false
    @block_color_by_layer = false
    @isolate_UI_loaded = false
    @observer_check_result = false
    @observer_check = false
    @skalpTool_active = false
    @dialog_loading = false
    @style_update = false
    @unloaded = false
    @dialog = nil
    @status = 0 #0 not loaded, 1 loaded, 2 startup
    #@n = 0

    skalp_require_isolate if File.exist?(Sketchup.find_support_file("Plugins")+"/Skalp_Skalp/Skalp.lic")

    @model_collection = [] #keep track off all open models in SketchUp
    @model_collection << Sketchup.active_model unless @model_collection.include?(Sketchup.active_model)

    Sketchup.write_default('Skalp', 'rearview_update', true)
    Sketchup.write_default('Skalp', 'rearview_display', true)
    Sketchup.write_default('Skalp', 'lineweights_update', true)
    Sketchup.write_default('Skalp', 'lineweights_display', true)

    @skalp_observer = SkalpAppObserver.new
    Sketchup.add_observer(@skalp_observer)

    def self.start_skalp
      skalp_require_run
      run_skalp
    end

    def self.stop_skalp(close_dialog = true)
      Sketchup.active_model.select_tool(nil) if Sketchup.active_model
      @status = 0
      @materialSelector.close if @materialSelector
      @dialog.close if @dialog && @dialog.visible? && close_dialog
      @dialog = nil unless close_dialog
      @hatch_dialog.close if @hatch_dialog
      @hatch_dialog = nil
      @clipper = nil
      @clipperOffset = nil
      if Sketchup.active_model && @models
        @models.each_value do |model|
          next unless model && model.skpModel.valid?
          model.memory_attributes.save_to_model
          model.unload_observers
        end
      end
      @active_model = nil
      @last_error = ''
      @unloaded = true
      @models = {}
      Sketchup.remove_observer(@skalp_observer) if @skalp_observer
      @skalp_observer = nil

    rescue NotImplementedError #'NotImplementedError: There is no tool manager' in SketchUp.remove_observer
    end

    def self.activate_model(skpModel)
      return unless skpModel
      return if skpModel.get_attribute('Skalp', 'CreateSection') == false
      return if @unloaded
      @models[skpModel] = Model.new(skpModel)
      @models[skpModel].load_observers

      return unless Skalp.dialog

      Skalp.dialog.update_styles(skpModel)
      Skalp.dialog.update(1)
    end

    def self.change_active_model(skpModel)
      @active_model = @models[skpModel]
      return unless Skalp.dialog

      Skalp.dialog.active_skpModel = skpModel
      Skalp.page_change = true
      if skpModel.pages && skpModel.pages.selected_page
        Skalp.dialog.update_styles(skpModel.pages.selected_page)
      else
        Skalp.dialog.update_styles(skpModel)
      end

      Skalp.update_layers_dialog

      Skalp.dialog.update(1)
      Skalp.page_change = false
    end

    def self.reboot_skalp
      return unless Sketchup.active_model
      @log.info("reboot Skalp")

      if Skalp.active_model
        Skalp.active_model.skpModel.commit_operation if Skalp.active_model.operation > 0
        Skalp.active_model.observer_active = true
        Skalp.active_model.operation = 0
      end

      return unless Skalp.status == 1
      Sketchup.status_text = "#{Skalp.translate("Skalp is restarting...")}"
      stop_skalp
      start_skalp
      Sketchup.status_text = "#{Skalp.translate("Skalp restart succeeded.")}"
    end

    def self.errors(e)
      return if e.message.to_s == 'reference to deleted Pages' #error bij afsluiten model

      if e.class == TypeError
        errormessage = 'TypeError: '
        errormessage += e.message.to_s
        errormessage += e.backtrace.inspect.to_s
        @log.error("TypeError: #{e}")
        @log.error(e.message)
        @log.error(e.backtrace.inspect)
      elsif e.class == NoMethodError
        errormessage = 'NoMethodError: '
        errormessage += e.message.to_s
        errormessage += e.backtrace.inspect.to_s
        @log.error("NoMethodError: #{e}")
        @log.error(e.message)
        @log.error(e.backtrace.inspect)
      else
        errormessage = 'StandardError: '
        errormessage += e.message.to_s
        errormessage += e.backtrace.inspect.to_s
        @log.error("StandardError: #{e}")
        @log.error(e.message)
        @log.error(e.backtrace.inspect)
      end
      send_bug(e)

      reboot_skalp
    end

    def self.bugtracking=(status = true)
      Sketchup.write_default('Skalp', 'noBugtracking', status)
    end

    def self.bugtracking()
      Sketchup.read_default('Skalp', 'noBugtracking')
    end

    def self.message1
      unless @showed == true
        timer_started = false
        UI.start_timer(rand(9), false) {
          unless timer_started
            timer_started = true
            UI.messagebox(translate64('VGhlcmUgaXMgYSBwcm9ibGVtIHdpdGggeW91ciBsaWNlbnNlLiBQbGVhc2UgY29udGFjdCBzdXBwb3J0QHNrYWxwNHNrZXRjaHVwLmNvbQ=='), MB_OK)
          end
        }
      end
      @showed = true
    end

    def self.message2
      message = "#{Skalp.translate('Your license could not be saved automatically.')} #{Skalp.translate('Please contact')} #{SKALP_SUPPORT}"
      UI.messagebox(message, MB_OK)
    end

    def self.startup_check(start_tool = nil)
      require 'Date'

      return if iscarnet_check

      license_version = Sketchup.read_default('Skalp', 'license_version').to_i
      license_version = 1 unless license_version

      if license_version < 2 && File.exist?(Sketchup.find_support_file("Plugins")+"/Skalp_Skalp/Skalp.lic") then
        UI.messagebox(Skalp.translate("The License system has been updated.") + "\n" +
                          Skalp.translate("Skalp needs to be reactivated using your original License Activation Code.") + "\n\n" +
                          Skalp.translate("The 'activate' section on the Info Dialog will now show.") + "\n" +
                          Skalp.translate("Your current License Activation Code is filled in automatically.") + "\n " +
                          Skalp.translate("Please accept the EULA and click on") + "\n" +
                          "'#{Skalp.translate("ACTIVATE SKALP")}'", MB_OK)
        show_info([:activate], start_tool, true)
        return
      end

      return if Sketchup.read_default('Skalp', 'license_version').to_i < 2 && File.exist?(Sketchup.find_support_file("Plugins")+"/Skalp_Skalp/Skalp.lic")

      #check if network version?
      guid = Sketchup.read_default('Skalp', 'guid')
      if guid && !File.exist?(Sketchup.find_support_file("Plugins")+"/Skalp_Skalp/Skalp.lic")
        if check_license_type_on_server(guid) == 'network'
          login_network
          puts 'load observer'
          Sketchup.add_observer(SkalpLicenseObserver.new)
        end
      end

      #Skalp already started
      if @info_dialog_shown && start_tool != :info
        @info_dialog.bring_to_front if @info_dialog_active
        if start_tool == :skalpTool
          if File.exist?(Sketchup.find_support_file("Plugins")+"/Skalp_Skalp/Skalp.lic")
            skalpTool if maintenance_check
            return
          end
        else
          if File.exist?(Sketchup.find_support_file("Plugins")+"/Skalp_Skalp/Skalp.lic")
            patternDesignerTool if maintenance_check
            return
          end
        end
      end

      #Encoder error?
      return if encoderErrorCheck

      #Version expired?
      if Time.now()> EXPIRE_DATE
        install_new_version
        return
      end

      #License?
      if start_tool == :info
        if File.exist?(Sketchup.find_support_file("Plugins")+"/Skalp_Skalp/Skalp.lic")
          Sketchup.write_default('Skalp', 'trial', SKALP_MAJOR_VERSION) if license_type == 'TRIAL'
          if new_version
            if license_type == 'TRIAL'
              show_info([:update, :activate, :release_notes, :buy], start_tool)
            else
              show_info([:update, :release_notes, :buy], start_tool)
            end
          else
            if license_type == 'TRIAL'
              show_info([:activate, :release_notes, :buy], start_tool)
            else
              show_info([:release_notes, :buy], start_tool)
            end
          end
        else
          if Sketchup.read_default('Skalp', 'trial').to_f >= SKALP_MAJOR_VERSION.to_f
            show_info([:activate, :release_notes, :buy], start_tool)
          else
            show_info([:activate, :trial, :release_notes, :buy], start_tool)
          end
        end
      else
        if File.exist?(Sketchup.find_support_file("Plugins")+"/Skalp_Skalp/Skalp.lic")
          Sketchup.write_default('Skalp', 'trial', SKALP_MAJOR_VERSION) if license_type == 'TRIAL'
          #License expired?
          unless license_type == 'FULL' || license_type == 'NETWORK'
            license_expire_date
            if @remaining_days < 0
              remove_license
              startup_check(start_tool)
              return
            end
            #new version
            if new_version
              show_info([:update, :activate, :buy], start_tool)
            else
              show_info([:release_notes, :activate, :buy], start_tool)
            end
          else
            #Full license
            #new version
            if new_version
              show_info([:update, :buy], start_tool)
            else
              if maintenance_check
                renewal_date = maintenance_renewal_date(guid)
                renewal_date = Date.today().to_s if renewal_date == ''

                if Time.parse(renewal_date) < Time.parse((Date.today()+15).to_s)
                  show_info([:maintenance_renewal], start_tool)
                else
                  start_skalp_tool(start_tool)
                end
              end
            end
          end
        else
          #already had trial
          Sketchup.write_default('Skalp', 'trial', '1.0') if Sketchup.read_default('Skalp', 'trial') == true
          if Sketchup.read_default('Skalp', 'trial').to_f >= SKALP_MAJOR_VERSION.to_f
            show_info([:activate, :release_notes, :buy], start_tool)
          else
            if Sketchup.read_default('RubyWindow', 'installation')
              show_info([:trial, :activate, :release_notes, :buy], start_tool)
            else
              show_info([:activate, :trial, :release_notes, :buy], start_tool)
            end
          end
        end
      end
    end
  end

  def self.start_skalp_tool(start_tool)
    if start_tool
      case start_tool
      when :skalpTool
          skalpTool
        when :patternDesignerTool
          patternDesignerTool
      end
    end
  end

  def self.license_expire_date
    trial_exp_date = Date.strptime(trial_expire_date, '%m/%d/%Y')
    today = Date.today
    @remaining_days = trial_exp_date.mjd - today.mjd
  end

  def install_new_version
    UI.messagebox("#{Skalp.translate('This Skalp version is too old.')} #{Skalp.translate('Please install a newer Skalp version.')}") #TODO verdere implementatie
  end

  require 'Skalp_Skalp/Skalp_update'

rescue RuntimeError => e
  @skalp_toolbar.hide
end

# alias_method_chain
# Provides a way to 'sneak into and spoof'TM original Sketchup API methods :)
# http://erniemiller.org/2011/02/03/when-to-use-alias_method_chain/
#example use case:
# sketchup_page = Sketchup.active_model.pages.add('test')
# sketchup_page.set_attribute('t','u','z')
# sketchup_page.get_attribute('t','u')

# alias_method_chain
# Provides a way to 'sneak into and spoof'TM original Sketchup API methods :)
# http://erniemiller.org/2011/02/03/when-to-use-alias_method_chain/
#example use case:
# sketchup_page = Sketchup.active_model.pages.add('test')
# sketchup_page.set_attribute('t','u','z')
# sketchup_page.get_attribute('t','u')
=begin

module Skalp
  class << self

    module Method_spoofer
      @white_list = ["commit","start","create_status_on_undo_stack", "stack_redo", "stack_undo", "block in save_attributes","force_start", "onToolStateChanged", "show_status", "read_from_model", "save_to_model"]
      class << self; attr_reader :white_list; end

      def self.included(base)
        base.class_eval do
          #alias_method :set_attribute_without_method_spoofer, :set_attribute
          #alias_method :set_attribute, :set_attribute_with_method_spoofer
          #alias_method :get_attribute_without_method_spoofer, :get_attribute
          #alias_method :get_attribute, :get_attribute_with_method_spoofer
          #alias_method :rendering_options_without_method_spoofer, :rendering_options
          #alias_method :rendering_options, :rendering_options_with_method_spoofer
          #alias_method :test_without_method_spoofer, :[]=
          #alias_method :[]=, :test_with_method_spoofer
          alias_method :active_model_without_method_spoofer, :active_model
          alias_method :active_model, :active_model_with_method_spoofer
        end
      end

      def set_attribute_with_method_spoofer(*params)
        unless Method_spoofer.white_list.include?(caller_locations(1,1)[0].label)
          puts "ATTENTION: old :set_attribute called by method: #{caller_locations(1,1)[0].label}"
          puts caller
          2.times {UI.beep; sleep(0.1)}
        end
        set_attribute_without_method_spoofer(*params)
      end

      def get_attribute_with_method_spoofer(*params)
        unless Method_spoofer.white_list.include?(caller_locations(1,1)[0].label)
          puts "ATTENTION: old :get_attribute called by method: #{caller_locations(1,1)[0].label}"
          puts caller
          2.times {UI.beep; sleep(0.1)}
        end
        get_attribute_without_method_spoofer(*params)
      end

      def rendering_options_with_method_spoofer(*params)
        puts '************* rendering options called'
        puts "params: #{params.inspect}"
        puts caller

        rendering_options_without_method_spoofer(*params)
      end
      def test_with_method_spoofer(*params)
        #if  params.include?('RenderMode')
        puts '************* rendering options called'
        puts "params: #{params.inspect}"
        puts caller
        #end
        test_without_method_spoofer(*params)
      end
      def active_model_with_method_spoofer(*params)
        #if  params.include?('RenderMode')
        puts "active_model spoofer via: #{caller_locations(1,1)[0].label}"
        if Sketchup.active_model.rendering_options["RenderMode"] == 2
          puts '*******'
          puts 'RenderMode == 2 (spoofer)'
          puts caller
          puts '*******'
        end

        #end
        active_model_without_method_spoofer(*params)
      end
    end
    include Method_spoofer
  end
end

if 1 #SKALP_VERSION == '9.9.9999'
  #Sketchup::Page.send :include, Skalp::Method_spoofer
  #Sketchup::Model.send :include, Skalp::Method_spoofer
  #Sketchup::RenderingOptions.send :include, Skalp::Method_spoofer
  #Skalp.send :include, Skalp::Method_spoofer
end
=end
