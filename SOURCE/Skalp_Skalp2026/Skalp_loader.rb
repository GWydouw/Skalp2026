module Skalp
  require "sketchup"
  require "fileutils"
  require "base64"
  require "logger"

  DEBUG = true unless defined? DEBUG

  LICENSE_SERVER = "license.skalp4sketchup.com" # "license.skalp4sketchup.com"
  DOWNLOAD_SERVER = "license.skalp4sketchup.com"

  # centralized to avoid issues with translation mismatches due to typos in the code:
  NO_ACTIVE_SECTION_PLANE = Skalp.translate("no active Section Plane")

  # Missing method implementation to fix blank pattern column
  def self.create_thumbnail(pattern_info, w = 81, h = 27)
    # Return existing blob if present - REMOVED to allow regeneration
    # return pattern_info[:png_blob] if pattern_info[:png_blob]

    require "Skalp_Skalp2026/Skalp_hatch"

    begin
      hatch = Skalp::SkalpHatch::Hatch.new
      pattern = pattern_info[:pattern]
      unless pattern
        puts "Skalp Debug: No pattern found in info."
        return nil
      end

      hatch_def = nil
      if pattern.is_a?(String)
        # Try to find existing definition by name
        found = Skalp::SkalpHatch.hatchdefs.find { |d| d.name == pattern }
        if found
          hatch_def = found
        else
          puts "Skalp Debug: Pattern '#{pattern}' not found in loaded definitions."
          # Fallback attempt?
        end
      elsif pattern.is_a?(Array)
        hatch_def = Skalp::SkalpHatch::HatchDefinition.new(pattern, false)
      end

      return nil unless hatch_def

      hatch.add_hatchdefinition(hatch_def)

      printscale = if Skalp.respond_to?(:dialog) && Skalp.dialog && Skalp.dialog.respond_to?(:drawing_scale)
                     Skalp.dialog.drawing_scale.to_f
                   else
                     50
                   end

      # Debug unit conversion
      user_x_val = pattern_info[:user_x]
      # puts "Skalp Debug: user_x raw: #{user_x_val}"
      converted_x = Skalp.unit_string_to_inch(user_x_val)
      # puts "Skalp Debug: user_x converted: #{converted_x}"
      # puts "Skalp Debug: user_x converted: #{converted_x}"

      result = hatch.create_png({
                                  type: :thumbnail,
                                  gauge: false,
                                  width: w,
                                  height: h,
                                  line_color: pattern_info[:line_color],
                                  fill_color: pattern_info[:fill_color],
                                  pen: Skalp::PenWidth.new(pattern_info[:pen], pattern_info[:space]).to_inch,
                                  section_cut_width: pattern_info[:section_cut_width].to_f,
                                  resolution: 72,
                                  print_scale: printscale,
                                  zoom_factor: 0.444,
                                  user_x: converted_x,
                                  space: pattern_info[:space],
                                  section_line_color: pattern_info[:section_line_color] || "rgb(0,0,0)"
                                })
      if result
        # puts "Skalp Debug: Thumb created successfully, size: #{result.size}"
      else
        puts "Skalp Debug: Thumb creation returned nil"
      end
      result
    rescue StandardError => e
      puts "Skalp Debug: Error in create_thumbnail: #{e.message}"
      puts e.backtrace.join("\n")
      nil
    end
  end

  def self.insert_version_check_code
    code = <<~EOF
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
      UI.messagebox("Your model '\#{File.basename(model.path)}' was saved with a newer Skalp version. Please install Skalp \#{version} or higher to edit this model. Skalp will be stopped now.")
      exit_skalp
      end
    EOF

    Sketchup.active_model.set_attribute("Skalp", "version_check",
                                        "eval(eval(%Q(Base64.decode64('#{Base64.encode64(code).gsub!("\n", '')}'))))")
  end

  # API to update custom objects from other extensions
  def self.object_updated(entity)
    if Skalp.status == 1 && [Sketchup::Group, Sketchup::ComponentInstance].include?(entity.class)

      entity.definition.instances.each do |instance|
        entities = instance.parent.entities

        data = {
          action: :removed_element,
          entities: entities,
          entity_id: instance
        }
        Skalp.models[Sketchup.active_model].controlCenter.add_to_queue(data)

        data = {
          action: :add_element,
          entities: entities,
          entity: instance
        }
        Skalp.models[Sketchup.active_model].controlCenter.add_to_queue(data) if instance.valid?
      end
    end
  rescue StandardError
    # to ensure this doesn't crash Skalp
  end

  def self.set_pattern_info_attribute(material, pattern_info)
    Skalp.active_model.start("Skalp - set pattern info")
    material.set_attribute("Skalp", "pattern_info",
                           "eval(Sketchup.active_model.get_attribute('Skalp', 'version_check').to_s);#{pattern_info}")
    Skalp.active_model.commit
  end

  def self.remove_license
    return unless File.exist?(Sketchup.find_support_file("Plugins") + "/Skalp_Skalp2026/Skalp.lic")

    FileUtils.remove_entry(Sketchup.find_support_file("Plugins") + "/Skalp_Skalp2026/Skalp.lic",
                           true)
  end

  def self.read_classroom_settings
    guid = Sketchup.read_default("Skalp", "guid")
    id = Sketchup.read_default("Skalp", "id")

    return if guid && id

    classroom_file = SKALP_PATH + "classroom_settings"

    return unless File.exist?(classroom_file)

    lines = []
    File.open(classroom_file, "r").each do |line|
      lines << line
    end

    guid = lines[0].unpack1("u")
    id = lines[1]

    Sketchup.write_default("Skalp", "guid", guid)
    Sketchup.write_default("Skalp", "id", id.to_i)
    Sketchup.write_default("Skalp", "license_version", 2)
    Sketchup.write_default("Skalp", "tolerance2", "0.0394")
  end

  def self.write_classroom_settings
    return unless license_type == "CLASSROOM"

    classroom_file = SKALP_PATH + "classroom_settings"

    return if File.exist?(classroom_file)

    guid = Sketchup.read_default("Skalp", "guid")
    id = Sketchup.read_default("Skalp", "id")

    return unless guid && id

    file = File.open(classroom_file, "w")
    file.write([guid].pack("u"))
    file.write(id)
    file.close
  end

  read_classroom_settings if File.exist?(SKALP_PATH + "classroom_settings")

  if File.exist?(Sketchup.find_support_file("Plugins") + "/Skalp_Skalp2026/Skalp.lic") && (Sketchup.read_default("Skalp",
                                                                                                                 "guid").nil? || Sketchup.read_default(
                                                                                                                   "Skalp", "id"
                                                                                                                 ).nil?)
    remove_license
  end

  if File.exist?(Sketchup.find_support_file("Plugins") + "/Skalp_Skalp2026/Skalp_geom.rbs")
    FileUtils.remove_entry(Sketchup.find_support_file("Plugins") + "/Skalp_Skalp2026/Skalp_geom.rbs",
                           true)
  end
  if File.exist?(Sketchup.find_support_file("Plugins") + "/Skalp_Skalp2026/Skalp_lib.rbs")
    FileUtils.remove_entry(Sketchup.find_support_file("Plugins") + "/Skalp_Skalp2026/Skalp_lib.rbs",
                           true)
  end
  if File.exist?(Sketchup.find_support_file("Plugins") + "/Skalp_Skalp2026/Skalp_isolate.rbs")
    FileUtils.remove_entry(Sketchup.find_support_file("Plugins") + "/Skalp_Skalp2026/Skalp_isolate.rbs",
                           true)
  end

  Sketchup.require "Skalp_Skalp2026/Skalp_info"
  Sketchup.require "Skalp_Skalp2026/Skalp_progress_dialog"

  @log = Logger.new(SKALP_PATH + "Skalp_log.txt")
  @log.level = Logger::INFO

  @log = Logger.new(SKALP_PATH + "Skalp_log.txt")
  @log.level = Logger::INFO

  # DIRECT EMBED of Diagnostics because require failed in build
  def self.diagnose
    model = Sketchup.active_model
    puts "=== SKALP DIAGNOSTICS (Embedded) ==="
    puts "Timestamp: #{Time.now}"
    puts "Model: #{model.title}"
    puts "Skalp.create_thumbnail defined? #{Skalp.respond_to?(:create_thumbnail)}"

    # Check simple thumbnail generation
    begin
      test_info = { name: "Test", pattern: "ANSI31", png_blob: nil, user_x: "1", pen: "0.1",
                    space: "0.1" }
      res = Skalp.create_thumbnail(test_info)
      puts "Test Thumbnail Generation: #{res ? 'SUCCESS (' + res.size.to_s + ' bytes)' : 'FAILED (returned nil)'}"
    rescue StandardError => e
      puts "Test Thumbnail Generation ERROR: #{e.message}"
    end

    puts "\n--- SECTION RESULT GROUP ---"
    if Skalp.active_model && Skalp.active_model.section_result_group
      srg = Skalp.active_model.section_result_group
      puts "SRG Visibility: #{srg.visible?} | Layer: #{srg.layer.name} | Hidden: #{srg.hidden?}"
      srg.entities.each do |g|
        next unless g.is_a?(Sketchup::Group) || g.is_a?(Sketchup::ComponentInstance)

        name = g.name
        name = g.definition.name + " (" + g.name + ")" if g.is_a?(Sketchup::ComponentInstance) && g.definition
        puts "  > #{g.class.name.split('::').last}: #{name} | Layer: #{g.layer.name} | Visible: #{g.visible?} | Hidden: #{g.hidden?}"
      end
    else
      puts "No Section Result Group found."
    end
    puts "===================================="
    nil
  end

  # Remove the dynamic require that failed
  # match_diag = Dir.glob(SKALP_PATH + 'Skalp_diagnostics.r*') ...

  @log.info("Skalp version: " + SKALP_VERSION)
  @log.info("Sketchup version: " + Sketchup.version)

  EXPIRE_DATE = Time.new(2030, 12, 31) # TODO: set beta expire date

  @log.info("OS: " + RUBY_PLATFORM + " " + Sketchup.os_language)

  def self.encoderError(code)
    case code
    when 3
      guid = Sketchup.read_default("Skalp", "guid")

      deactivation_text =
        "Skalp #{Skalp.translate('needs to be reactivated.')} (#{Skalp.translate('system change detected')})" + "\n\n" +
        Skalp.translate("Please copy your License Activation Code:") + "\n#{guid}\n" +
        Skalp.translate("Paste this code into the Skalp Info Dialog and reactivate.") + "\n\n"

      UI.messagebox(deactivation_text, MB_OK)
      auto_deactivate(guid)
    else
      Sketchup.write_default("Skalp", "encoderError", code)
    end
    result = UI.messagebox(Skalp.translate("SketchUp will close now.") + "\n" +
                               Skalp.translate("Do you want to save your model first?"), MB_YESNO)
    Sketchup.send_action "saveDocument:" if result == 6
    exit!
  end

  def auto_deactivate(guid, clean = true)
    id = Sketchup.read_default("Skalp", "id")

    remove_license

    uri = URI("http://#{LICENSE_SERVER}/register_2_0/deactivate.php?hid=#{id}&guid=#{guid}")
    if Net::HTTP.get(uri)
      Sketchup.write_default("Skalp", "guid", nil) if clean
      Sketchup.write_default("Skalp", "id", nil) if clean
    else
      UI.messagebox("#{Skalp.translate('Error while deactivating License. Please contact')} #{SKALP_SUPPORT}")
    end
  end

  def self.encoderErrorCheck
    encoderError = Sketchup.read_default("Skalp", "encoderError")
    encoderError ||= 9999

    if encoderError == 9999
      Sketchup.require "Skalp_Skalp2026/Skalp_version"
      if File.exist?(Sketchup.find_support_file("Plugins") + "/Skalp_Skalp2026/Skalp.lic")
        Sketchup.require "Skalp_Skalp2026/Skalp_lic"
      end
      false
    else
      @log.error("encoderError: " + encoderError.to_s)
      case encoderError
      when 3 # wrong mac
        remove_license
        # FileUtils.remove_entry(Sketchup.find_support_file("Plugins")+"/Skalp.rb", true) if File.exist?(Sketchup.find_support_file("Plugins")+"/Skalp.rb")
        Sketchup.write_default("Skalp", "encoderError", 9999)
      when 9 # expired
        if Time.now > EXPIRE_DATE # beta version expired
          Sketchup.write_default("Skalp", "encoderError", 9999)
          install_new_version
        else
          if File.exist?(Sketchup.find_support_file("Plugins") + "/Skalp.rb")
            FileUtils.remove_entry(Sketchup.find_support_file("Plugins") + "/Skalp.rb",
                                   true)
          end
          Sketchup.write_default("Skalp", "encoderError", 9999)
          remove_license
        end
      else
        UI.messagebox("#{Skalp.translate('Error')}: Skalp encoder #{encoderError}. " +
                          Skalp.translate("Try to restart SketchUp 2 times to solve this problem.") + " \n" +
                          Skalp.translate("If this does not solve the problem, please contact") + " #{SKALP_SUPPORT}")

        Sketchup.write_default("Skalp", "encoderError", 9999)
      end
      true
    end
  end

  def self.iscarnet_check
    iscarnet = false
    if File.exist?(Sketchup.find_support_file("Plugins") + "/iscarnet_dibac.rb") || File.exist?(Sketchup.find_support_file("Plugins") + "/iscarnet_ss.rb")
      extensions = Sketchup.extensions
      for extension in extensions
        unsupported =
          (Skalp.translate("Disclaimer: Running Skalp and") + " #{extension.name} " +
          Skalp.translate("concurrently is unsupported at this time and may yield unexpected results.") + "\n") <<
          (Skalp.translate("Skalp will not be able to show section results whenever a") + " #{extension.name} ") <<
          (Skalp.translate("is already shown in the same location.") + "\n\n") <<
          Skalp.translate("Proceed loading Skalp at your own risk?")
        if extension.name == "SolidSection" # || extension.name == 'Dibac'
          if extension.loaded?
            # iscarnet = true
            concurrent_text =
              ("#{extension.name} " + Skalp.translate("extension detected.") + "\n\n") <<
              (Skalp.translate("Sorry, running Skalp and") + " #{extension.name} " +
                Skalp.translate("concurrently will yield unexpected results.") + "\n") <<
              (Skalp.translate("In order to run Skalp as intended, we have to advise you to uncheck") + " '#{extension.name}" + "' ") <<
              (Skalp.translate("from the SketchUp Preferences Extensions manager.") + "\n\n") <<
              Skalp.translate("Would you like us to do this for you now?")
            if UI.messagebox(concurrent_text, MB_YESNO) == IDYES
              extension.uncheck
              restart_text =
                ("#{extension.name} " + Skalp.translate("is uninstalled.") + "\n") <<
                (Skalp.translate("A SketchUp restart is needed to effectuate this change.") + "\n\n") <<
                (Skalp.translate("SketchUp will be closed.") + "\n") <<
                Skalp.translate("You will be asked to save your model if necessary.")
              UI.messagebox(restart_text, MB_OK)
              Sketchup.quit
            elsif UI.messagebox(unsupported, MB_YESNO) == IDNO

              iscarnet = true
            end
          end
        elsif extension.name == "Dibac" && Sketchup.read_default("Dibac", "SolidSection") == true
          # iscarnet = true
          concurrent_text =
            ("#{extension.name} " + Skalp.translate("extension detected.") + "\n\n") <<
            (Skalp.translate("Sorry, running Skalp and") + " #{extension.name} " +
              Skalp.translate("concurrently will yield unexpected results.") + "\n") <<
            (Skalp.translate("In order to run Skalp as intended, we will disable the SolidSection function from ") + " '#{extension.name}" + "' " + "\n\n") <<
            Skalp.translate("Would you like us to do this for you now?")
          if UI.messagebox(concurrent_text, MB_YESNO) == IDYES
            Sketchup.write_default("Dibac", "SolidSection", false)
            restart_text =
              (Skalp.translate("SolidSection is disabled.") + "\n") <<
              (Skalp.translate("A SketchUp restart is needed to effectuate this change.") + "\n\n") <<
              (Skalp.translate("SketchUp will be closed.") + "\n") <<
              Skalp.translate("You will be asked to save your model if necessary.")
            UI.messagebox(restart_text, MB_OK)
            Sketchup.quit
          elsif UI.messagebox(unsupported, MB_YESNO) == IDNO
            iscarnet = true
          end
        end
      end
    end
    iscarnet
  end

  # Restore incorrect application of Set shim in global space:
  # Set = Sketchup::Set
  # Workaround for:
  # I suppose one of the following plugins is guilty on NOT wrapping Set = Sketchup::Set in a module.
  # cfr mail Thomas Thomassen 15 augustus 2015
  def sketchup_set_class_repair
    return unless Set && Sketchup::Set

    return unless Set == Sketchup::Set

    set_rb_file = File.join($LOAD_PATH.find { |path| File.exist?(File.join(path, "set.rb")) }, "set.rb")
    item = $LOADED_FEATURES.find { |feature| feature == set_rb_file }
    $LOADED_FEATURES.delete(item)

    unless item
      Skalp.send_info("BrokenSetClassError",
                      ":sketchup_set_class_repair called by method: #{caller_locations(1, 1)[0].label}", "COULD NOT FIX: Set = Sketchup::Set (detected non-Skalp incorrect application in global space)")
      return
    end
    Object.send(:remove_const, :Set)
    Object.send(:remove_const, :SortedSet)

    Skalp.send_info("FIXED BrokenSetClassError",
                    ":sketchup_set_class_repair called by method: #{caller_locations(1, 1)[0].label}", "FIXED: Set = Sketchup::Set (detected non-Skalp incorrect application in global space)")
  end

  if Time.now > EXPIRE_DATE
    @version_expired = true

    # STUB missing methods for expired state
    def self.online?
      Sketchup.is_online
    end

    def self.new_version
      false
    end

    encoderErrorCheck
    show_info([:update])
  else

    @version_expired = false

    def self.load_default_pat_file
      FileUtils.mkdir(SKALP_PATH + "resources/styles/") unless File.directory?(SKALP_PATH + "resources/styles/")
      FileUtils.mkdir(SKALP_PATH + "resources/materials/") unless File.directory?(SKALP_PATH + "resources/materials/")
      unless File.directory?(SKALP_PATH + "resources/layermappings/")
        FileUtils.mkdir(SKALP_PATH + "resources/layermappings/")
      end
      return if File.exist?(SKALP_PATH + "resources/hatchpats/skalp.pat")

      FileUtils.mkdir(SKALP_PATH + "resources/hatchpats/") unless File.directory?(SKALP_PATH + "resources/hatchpats/")
      FileUtils.copy(File.join(SKALP_PATH, "skalp.resources"),
                     File.join(SKALP_PATH, "resources/hatchpats/", "skalp.pat"))
    end

    def self.rename_C
      File.rename(SKALP_PATH + "SkalpC.so", SKALP_PATH + "SkalpC_old.so") if File.exist?(SKALP_PATH + "SkalpC.so")
      if File.exist?(SKALP_PATH + "SkalpC.bundle")
        File.rename(SKALP_PATH + "SkalpC.bundle",
                    SKALP_PATH + "SkalpC_old.bundle")
      end
    rescue StandardError
      UI.messagebox("#{Skalp.translate("Some files are locked by the OS and can't be renamed.")} #{Skalp.translate('Please restart your computer.')}")
      false # TODO: check return value
    end

    def self.rename_old_C
      if File.exist?(SKALP_PATH + "SkalpC_old.so")
        File.rename(SKALP_PATH + "SkalpC_old.so",
                    SKALP_PATH + "SkalpC_old2.so")
      end
      if File.exist?(SKALP_PATH + "SkalpC_old.bundle")
        File.rename(SKALP_PATH + "SkalpC_old.bundle",
                    SKALP_PATH + "SkalpC_old2.bundle")
      end
    rescue StandardError
      UI.messagebox("#{Skalp.translate("Some old files are locked by the OS and can't be renamed.")} #{Skalp.translate('Please restart your computer.')}")
      false # TODO: check return value
    end

    def self.install_C
      # delete old C-extension
      begin
        FileUtils.remove_entry(SKALP_PATH + "SkalpC_old2.so", true) if File.exist?(SKALP_PATH + "SkalpC_old2.so")
        if File.exist?(SKALP_PATH + "SkalpC_old2.bundle")
          FileUtils.remove_entry(SKALP_PATH + "SkalpC_old2.bundle",
                                 true)
        end
      rescue StandardError
        UI.messagebox("Some old2 files are locked by the OS and can't be removed. Please reboot your computer!")
        return false # TODO: check return value
      end

      begin
        FileUtils.remove_entry(SKALP_PATH + "SkalpC_old.so", true) if File.exist?(SKALP_PATH + "SkalpC_old.so")
        FileUtils.remove_entry(SKALP_PATH + "SkalpC_old.bundle", true) if File.exist?(SKALP_PATH + "SkalpC_old.bundle")
      rescue StandardError
        rename_old_C
      end

      # #remove delete or rename c-extensions
      begin
        if File.exist?(SKALP_PATH + "SkalpC.so") && File.exist?(SKALP_PATH + "SkalpC.win")
          FileUtils.remove_entry(SKALP_PATH + "SkalpC.so",
                                 true)
        end
        if File.exist?(SKALP_PATH + "SkalpC.bundle") && File.exist?(SKALP_PATH + "SkalpC.mac")
          FileUtils.remove_entry(SKALP_PATH + "SkalpC.bundle",
                                 true)
        end
      rescue StandardError
        rename_C
      end

      # copy C_ext to correct name

      unless File.exist?(SKALP_PATH + "SkalpC.so") || File.exist?(SKALP_PATH + "SkalpC.bundle")

        if File.exist?(SKALP_PATH + "SkalpC.win")
          FileUtils.copy(File.join(SKALP_PATH, "SkalpC.win"),
                         File.join(SKALP_PATH, "SkalpC.so"))
        end
        if File.exist?(SKALP_PATH + "SkalpC.mac")
          FileUtils.copy(File.join(SKALP_PATH, "SkalpC.mac"),
                         File.join(SKALP_PATH, "SkalpC.bundle"))
        end

        if OS == :WINDOWS && File.exist?(SKALP_PATH + "SkalpC.so")
          FileUtils.remove_entry(SKALP_PATH + "SkalpC.win", true) if File.exist?(SKALP_PATH + "SkalpC.win")
          FileUtils.remove_entry(SKALP_PATH + "SkalpC.mac", true) if File.exist?(SKALP_PATH + "SkalpC.mac")
        end

        if OS == :MAC && File.exist?(SKALP_PATH + "SkalpC.bundle")
          FileUtils.remove_entry(SKALP_PATH + "SkalpC.win", true) if File.exist?(SKALP_PATH + "SkalpC.win")
          FileUtils.remove_entry(SKALP_PATH + "SkalpC.mac", true) if File.exist?(SKALP_PATH + "SkalpC.mac")
        end
      end

      # copy Skalp external application to correct name
      if Dir.exist?(SKALP_PATH + "lib_mac") || Dir.exist?(SKALP_PATH + "lib_win")
        begin
          FileUtils.remove_dir(SKALP_PATH + "lib", true)
          if OS == :WINDOWS
            FileUtils.mv(SKALP_PATH + "lib_win", SKALP_PATH + "lib")
            FileUtils.remove_dir(SKALP_PATH + "lib_mac", true)
          else
            Dir.chdir(SKALP_PATH + "lib_mac") { `tar -zxf lib_mac.tar.gz; rm lib_mac.tar.gz; mv ../lib_mac ../lib` }
            FileUtils.remove_dir(SKALP_PATH + "lib_mac", true)
            FileUtils.remove_dir(SKALP_PATH + "lib_win", true)
          end
        rescue StandardError
          UI.messagebox("#{Skalp.translate("Some old directories are locked by the OS and can't be deleted.")} #{Skalp.translate('Please restart your computer.')}")
        end
      end

      begin
        # Old: eval(Base64.decode64("cmVxdWlyZSAnU2thbHBfU2thbHAvU2thbHBDJw==")) -> require 'Skalp_Skalp/SkalpC'
        # New for 2026:
        require "Skalp_Skalp2026/SkalpC"

        # Load Ruby implementation of C-methods if Debugging OR DevMode (to override legacy C-code)
        if (defined?(SKALPDEBUGGER) && SKALPDEBUGGER) || (defined?(DEV_MODE) && DEV_MODE)
          require "Skalp_Skalp2026/Skalp_debugger_SkalpC"
        end

        puts ">>> SkalpC loaded successfully"
      rescue LoadError => e
        begin
          # Try absolute path as fallback
          skalpc_path = File.join(File.dirname(__FILE__), "SkalpC.so")
          require skalpc_path
          puts ">>> SkalpC loaded successfully (absolute path)"
        rescue LoadError => e2
          puts "⚠️  SkalpC not available (development mode):"
          puts "   Relative: #{e.message}"
          puts "   Absolute: #{e2.message}"
          puts "   Run 'rake dev:cpp' to compile C-extension."
        end
      end

      true
    end

    IMAGE_PATH = Sketchup.find_support_file("Plugins") + "/Skalp_Skalp2026/html/icons/"
    THUMBNAIL_PATH = Sketchup.find_support_file("Plugins") + "/Skalp_Skalp2026/html/thumbnails/"
    FileUtils.mkdir(THUMBNAIL_PATH) unless Dir.exist?(THUMBNAIL_PATH)

    @webdialog_require = false

    begin
      Sketchup.require "SecureRandom"
      require "Matrix"
    rescue StandardError
      message =
        Skalp.translate("SketchUp 2014 encountered a problem loading the Ruby standard Library when you have opened SketchUp by double clicking a SketchUp file instead of starting SketchUp from it's application icon.") +
        Skalp.translate("This is fixed in SketchUp 2014's latest maintenance release.") + " " +
        Skalp.translate("Close and restart SketchUp by double clicking it's application icon instead.")
      UI.messagebox(message)
    end

    Sketchup.require "Skalp_Skalp2026/chunky_png/lib/chunky_png"
    Dir.chdir(SU_USER_PATH)

    result = install_C
    raise "install_C error" unless result

    # [DevMode] Re-apply aliases because SkalpC might have overwritten them with legacy C-implementations
    if defined?(DEV_MODE) && DEV_MODE && Skalp.respond_to?(:skalp_require_run_debug)
      Skalp.module_eval do
        class << self
          alias_method :skalp_requires, :skalp_requires_debug
          alias_method :skalp_require_dialog, :skalp_require_dialog_debug
          alias_method :skalp_require_isolate, :skalp_require_isolate_debug
          alias_method :skalp_require_hatch_lib, :skalp_require_hatch_lib_debug
          alias_method :skalp_require_hatchtile, :skalp_require_hatchtile_debug
          alias_method :skalp_require_hatch_class, :skalp_require_hatch_class_debug
          alias_method :skalp_require_hatchdefinition_class, :skalp_require_hatchdefinition_class_debug
          alias_method :skalp_require_hatchline_class, :skalp_require_hatchline_class_debug
          alias_method :skalp_require_hatchpatterns_main, :skalp_require_hatchpatterns_main_debug
          alias_method :skalp_require_license, :skalp_require_license_debug
          alias_method :skalp_require_run, :skalp_require_run_debug
        end
      end
      puts ">>> [DevMode] Restored Ruby overrides for SkalpC methods"
    end

    if RUBY_PLATFORM.downcase.include?("arm64")
      %w[27 32].each do |ver|
        next unless File.exist?(SKALP_PATH + "eval/rgloader#{ver}.darwin.arm64.bundle")

        if File.exist?(SKALP_PATH + "eval/rgloader#{ver}.darwin.bundle")
          FileUtils.remove_entry(SKALP_PATH + "eval/rgloader#{ver}.darwin.bundle",
                                 true)
        end
        File.rename(SKALP_PATH + "eval/rgloader#{ver}.darwin.arm64.bundle",
                    SKALP_PATH + "eval/rgloader#{ver}.darwin.bundle")
      end
    end

    load_default_pat_file

    # Stub for skalp_require_license (normally in encoded Skalp_lic.rb or SkalpC)
    unless respond_to?(:skalp_require_license)
      def self.skalp_require_license
        puts ">>> [DevMode] Using license stub (real license checking disabled)"
        true
      end
    end

    # Stub for get_mac (normally in SkalpC)
    unless respond_to?(:get_mac)
      def self.get_mac(arg = nil)
        "DEV_MAC_ADDRESS"
      end
    end

    # Stub for check_license_type_on_server (normally in SkalpC)
    unless respond_to?(:check_license_type_on_server)
      def self.check_license_type_on_server(arg = nil)
        puts ">>> [DevMode] License server check bypassed"
        true
      end
    end

    skalp_require_license

    require "Skalp_Skalp2026/Skalp_preferences"
    require "Skalp_Skalp2026/Skalp_observers"
    require "Skalp_Skalp2026/Skalp_html_inputbox"
    require "Skalp_Skalp2026/Skalp_box_section"
    require "Skalp_Skalp2026/Skalp_box_section_tool"
    require "Skalp_Skalp2026/Skalp_UI"
    require "Skalp_Skalp2026/Skalp_lib2"
    require "Skalp_Skalp2026/Skalp_geom2"
    require "Skalp_Skalp2026/Skalp_material_dialog"
    require "Skalp_Skalp2026/Skalp_paintbucket"
    require "Skalp_Skalp2026/Skalp_dwg_export_dialog"
    require "Skalp_Skalp2026/Skalp_cad_converter"
    require "Skalp_Skalp2026/Skalp_white_mode"

    result = get_mac(false)

    raise "get_mac error" if result.nil? || result == ""

    Dir.chdir(SU_USER_PATH)

    class << self
      attr_accessor :models, :model_collection, :active_model, :page_change, # :page_switched,
                    :dxf_export, :live_section_ON, :sectionplane_active, :scene_style_nested, :style_update,
                    :dialog, :hatch_dialog, :materialSelector, :status, :string, :dialog_loading, :layers_dialog, :selectTool, :skalpTool_active, :log,
                    :clipper, :clipperOffset, :block_observers, :skalp_layout_export, :skalp_dwg_export,
                    :observer_check, :observer_check_result, :info_dialog, :info_dialog_active, :skalp_activate, :skalp_toolbar, :skalp_dwg_export, :set_bugtracking,
                    :isolate_UI_loaded, :new_pattern_layer_list, :timer_started, :converter_started,
                    :new_sectionplane, :block_color_by_layer, :skalp_paint, :skalp_paint_tool, :progress_dialog

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
    @status = 0 # 0 not loaded, 1 loaded, 2 startup
    # @n = 0

    skalp_require_isolate if File.exist?(Sketchup.find_support_file("Plugins") + "/Skalp_Skalp2026/Skalp.lic")

    @model_collection = [] # keep track off all open models in SketchUp
    @model_collection << Sketchup.active_model unless @model_collection.include?(Sketchup.active_model)

    Sketchup.write_default("Skalp", "rearview_update", true)
    Sketchup.write_default("Skalp", "rearview_display", true)
    Sketchup.write_default("Skalp", "lineweights_update", true)
    Sketchup.write_default("Skalp", "lineweights_display", true)

    @skalp_observer = SkalpAppObserver.new
    Sketchup.add_observer(@skalp_observer)

    # Load pattern definitions during startup so thumbnails can be generated by name
    UI.start_timer(0.5, false) { Skalp::SkalpHatch.load_hatch if defined?(Skalp::SkalpHatch) }

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
      @last_error = ""
      @unloaded = true
      @models = {}
      Sketchup.remove_observer(@skalp_observer) if @skalp_observer
      @skalp_observer = nil
    rescue NotImplementedError # 'NotImplementedError: There is no tool manager' in SketchUp.remove_observer
    end

    def self.activate_model(skpModel)
      puts ">>> [DEBUG] activate_model called for: #{begin
        skpModel.title
      rescue StandardError
        'unknown'
      end} (object_id: #{skpModel.object_id})"
      return unless skpModel
      return if skpModel.get_attribute("Skalp", "CreateSection") == false
      return if @unloaded

      # CRITICAL FIX: Don't re-activate if already active
      if @models && @models[skpModel]
        puts ">>> [DEBUG] Model ALREADY ACTIVATED, returning early"
        return
      end

      # puts ">>> [DEBUG] Model NOT in @models, creating new instance..."
      puts ">>> [DEBUG] @models keys: #{@models ? @models.keys.map { |m| m.object_id }.join(', ') : 'nil'}"
      @models[skpModel] = Model.new(skpModel)
      # puts ">>> [DEBUG] Model created successfully, loading observers..."
      @models[skpModel].load_observers
      # puts ">>> [DEBUG] Observers loaded, checking dialog..."

      # Check for legacy model data after activation is complete (before dialog check)
      check_legacy_model(skpModel)

      return unless Skalp.dialog

      # puts ">>> [DEBUG] Dialog exists, updating..."

      Skalp.dialog.update_styles(skpModel)
      Skalp.dialog.update(1)
      # puts ">>> [DEBUG] activate_model COMPLETED"
    end

    # Check if model was saved with older Skalp version and offer to update
    def self.check_legacy_model(skpModel)
      return unless skpModel && skpModel.valid?

      needs_update = false

      # Check version attribute - current version starts with "202"
      current_prefix = begin
        Skalp::SKALP_VERSION[0..2]
      rescue StandardError
        "202"
      end
      saved_version = skpModel.get_attribute("Skalp", "version")

      # If model has Skalp data but version is different or missing
      if skpModel.get_attribute("Skalp",
                                "CreateSection") && (saved_version.nil? || saved_version[0..2] != current_prefix)
        needs_update = true
      end

      # Also check for legacy rear view components
      unless needs_update
        legacy_def = skpModel.definitions.find { |d| !d.deleted? && d.name =~ /^Skalp - .*rear view/i }
        needs_update = true if legacy_def
      end

      return unless needs_update

      # Use timer to let UI settle before showing dialog
      UI.start_timer(1.0, false) do
        msg = Skalp.translate("Skalp detected this model was saved with an older version.") + "\n" +
              Skalp.translate("To fix alignment and rear view issues, a full update is recommended.") + "\n\n" +
              Skalp.translate("Update all scenes now? (This might take a while)")

        result = UI.messagebox(msg, MB_YESNO)
        if result == IDYES
          skModel = @models[skpModel]
          skModel ||= Skalp.active_model
          skModel.update_all_pages(false, true, Skalp.translate("Legacy Model Update")) if skModel
        end
      end
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

      Sketchup.status_text = "#{Skalp.translate('Skalp is restarting...')}"
      stop_skalp
      start_skalp
      Sketchup.status_text = "#{Skalp.translate('Skalp restart succeeded.')}"
    end

    def self.errors(e)
      puts ">>> [DEBUG] Skalp.errors called with: #{e.class}: #{e.message}"
      puts ">>> [DEBUG] Backtrace: #{e.backtrace.first(3).join(' | ')}"
      return if e.message.to_s == "reference to deleted Pages" # error bij afsluiten model

      if e.class == TypeError
        errormessage = "TypeError: "
        errormessage += e.message.to_s
        errormessage += e.backtrace.inspect
        @log.error("TypeError: #{e}")
        @log.error(e.message)
        @log.error(e.backtrace.inspect)
      elsif e.class == NoMethodError
        errormessage = "NoMethodError: "
        errormessage += e.message.to_s
        errormessage += e.backtrace.inspect
        @log.error("NoMethodError: #{e}")
        @log.error(e.message)
        @log.error(e.backtrace.inspect)
      else
        errormessage = "StandardError: "
        errormessage += e.message.to_s
        errormessage += e.backtrace.inspect
        @log.error("StandardError: #{e}")
        @log.error(e.message)
        @log.error(e.backtrace.inspect)
      end
      send_bug(e)

      reboot_skalp
    end

    def self.bugtracking=(status = true)
      Sketchup.write_default("Skalp", "noBugtracking", status)
    end

    def self.bugtracking
      Sketchup.read_default("Skalp", "noBugtracking")
    end

    def self.message1
      unless @showed == true
        timer_started = false
        UI.start_timer(rand(9), false) do
          unless timer_started
            timer_started = true
            UI.messagebox(
              translate64("VGhlcmUgaXMgYSBwcm9ibGVtIHdpdGggeW91ciBsaWNlbnNlLiBQbGVhc2UgY29udGFjdCBzdXBwb3J0QHNrYWxwNHNrZXRjaHVwLmNvbQ=="), MB_OK
            )
          end
        end
      end
      @showed = true
    end

    def self.message2
      message = "#{Skalp.translate('Your license could not be saved automatically.')} #{Skalp.translate('Please contact')} #{SKALP_SUPPORT}"
      UI.messagebox(message, MB_OK)
    end

    def self.startup_check(start_tool = nil)
      require "Date"

      return if iscarnet_check

      license_version = Sketchup.read_default("Skalp", "license_version").to_i
      license_version ||= 1

      if license_version < 2 && File.exist?(Sketchup.find_support_file("Plugins") + "/Skalp_Skalp2026/Skalp.lic")
        UI.messagebox(Skalp.translate("The License system has been updated.") + "\n" +
                          Skalp.translate("Skalp needs to be reactivated using your original License Activation Code.") + "\n\n" +
                          Skalp.translate("The 'activate' section on the Info Dialog will now show.") + "\n" +
                          Skalp.translate("Your current License Activation Code is filled in automatically.") + "\n " +
                          Skalp.translate("Please accept the EULA and click on") + "\n" +
                          "'#{Skalp.translate('ACTIVATE SKALP')}'", MB_OK)
        show_info([:activate], start_tool, true)
        return
      end

      return if Sketchup.read_default("Skalp",
                                      "license_version").to_i < 2 && File.exist?(Sketchup.find_support_file("Plugins") + "/Skalp_Skalp2026/Skalp.lic")

      # check if network version?
      guid = Sketchup.read_default("Skalp", "guid")
      if guid && !File.exist?(Sketchup.find_support_file("Plugins") + "/Skalp_Skalp2026/Skalp.lic") && (check_license_type_on_server(guid) == "network")
        login_network
        puts "load observer"
        Sketchup.add_observer(SkalpLicenseObserver.new)
      end

      # Skalp already started
      if @info_dialog_shown && start_tool != :info
        @info_dialog.bring_to_front if @info_dialog_active
        if start_tool == :skalpTool
          if File.exist?(Sketchup.find_support_file("Plugins") + "/Skalp_Skalp2026/Skalp.lic")
            skalpTool if maintenance_check
            return
          end
        elsif File.exist?(Sketchup.find_support_file("Plugins") + "/Skalp_Skalp2026/Skalp.lic")
          patternDesignerTool if maintenance_check
          return
        end
      end

      # Encoder error?
      return if encoderErrorCheck

      # Version expired?
      if Time.now > EXPIRE_DATE
        install_new_version
        return
      end

      # License?
      if start_tool == :info
        if File.exist?(Sketchup.find_support_file("Plugins") + "/Skalp_Skalp2026/Skalp.lic")
          Sketchup.write_default("Skalp", "trial", SKALP_MAJOR_VERSION) if license_type == "TRIAL"
          if new_version
            if license_type == "TRIAL"
              show_info(%i[update activate release_notes buy], start_tool)
            else
              show_info(%i[update release_notes buy], start_tool)
            end
          elsif license_type == "TRIAL"
            show_info(%i[activate release_notes buy], start_tool)
          else
            show_info(%i[release_notes buy], start_tool)
          end
        elsif Sketchup.read_default("Skalp", "trial").to_f >= SKALP_MAJOR_VERSION.to_f
          show_info(%i[activate release_notes buy], start_tool)
        else
          show_info(%i[activate trial release_notes buy], start_tool)
        end
      elsif File.exist?(Sketchup.find_support_file("Plugins") + "/Skalp_Skalp2026/Skalp.lic")
        Sketchup.write_default("Skalp", "trial", SKALP_MAJOR_VERSION) if license_type == "TRIAL"
        # License expired?
        if %w[FULL NETWORK].include?(license_type)
          # Full license
          # new version
          if new_version
            show_info(%i[update buy], start_tool)
          elsif maintenance_check
            renewal_date = maintenance_renewal_date(guid)
            renewal_date = Date.today.to_s if renewal_date == ""

            if Time.parse(renewal_date) < Time.parse((Date.today + 15).to_s)
              show_info([:maintenance_renewal], start_tool)
            else
              start_skalp_tool(start_tool)
            end
          end
        else
          license_expire_date
          if @remaining_days < 0
            remove_license
            startup_check(start_tool)
            return
          end
          # new version
          if new_version
            show_info(%i[update activate buy], start_tool)
          else
            show_info(%i[release_notes activate buy], start_tool)
          end
        end
      else
        # already had trial
        Sketchup.write_default("Skalp", "trial", "1.0") if Sketchup.read_default("Skalp", "trial") == true
        if Sketchup.read_default("Skalp", "trial").to_f >= SKALP_MAJOR_VERSION.to_f
          show_info(%i[activate release_notes buy], start_tool)
        elsif Sketchup.read_default("RubyWindow", "installation")
          show_info(%i[trial activate release_notes buy], start_tool)
        else
          show_info(%i[activate trial release_notes buy], start_tool)
        end
      end
    end
  end

  def self.start_skalp_tool(start_tool)
    return unless start_tool

    case start_tool
    when :skalpTool
      skalpTool
    when :patternDesignerTool
      patternDesignerTool
    end
  end

  def self.license_expire_date
    trial_exp_date = Date.strptime(trial_expire_date, "%m/%d/%Y")
    today = Date.today
    @remaining_days = trial_exp_date.mjd - today.mjd
  end

  def install_new_version
    UI.messagebox("#{Skalp.translate('This Skalp version is too old.')} #{Skalp.translate('Please install a newer Skalp version.')}") # TODO: verdere implementatie
  end

  require "Skalp_Skalp2026/Skalp_update"

rescue RuntimeError => e
  @skalp_toolbar.hide
end

# alias_method_chain
# Provides a way to 'sneak into and spoof'TM original Sketchup API methods :)
# http://erniemiller.org/2011/02/03/when-to-use-alias_method_chain/
# example use case:
# sketchup_page = Sketchup.active_model.pages.add('test')
# sketchup_page.set_attribute('t','u','z')
# sketchup_page.get_attribute('t','u')

# alias_method_chain
# Provides a way to 'sneak into and spoof'TM original Sketchup API methods :)
# http://erniemiller.org/2011/02/03/when-to-use-alias_method_chain/
# example use case:
# sketchup_page = Sketchup.active_model.pages.add('test')
# sketchup_page.set_attribute('t','u','z')
# sketchup_page.get_attribute('t','u')
#
# module Skalp
#   class << self
#
#     module Method_spoofer
#       @white_list = ["commit","start","create_status_on_undo_stack", "stack_redo", "stack_undo", "block in save_attributes","force_start", "onToolStateChanged", "show_status", "read_from_model", "save_to_model"]
#       class << self; attr_reader :white_list; end
#
#       def self.included(base)
#         base.class_eval do
#           #alias_method :set_attribute_without_method_spoofer, :set_attribute
#           #alias_method :set_attribute, :set_attribute_with_method_spoofer
#           #alias_method :get_attribute_without_method_spoofer, :get_attribute
#           #alias_method :get_attribute, :get_attribute_with_method_spoofer
#           #alias_method :rendering_options_without_method_spoofer, :rendering_options
#           #alias_method :rendering_options, :rendering_options_with_method_spoofer
#           #alias_method :test_without_method_spoofer, :[]=
#           #alias_method :[]=, :test_with_method_spoofer
#           alias_method :active_model_without_method_spoofer, :active_model
#           alias_method :active_model, :active_model_with_method_spoofer
#         end
#       end
#
#       def set_attribute_with_method_spoofer(*params)
#         unless Method_spoofer.white_list.include?(caller_locations(1,1)[0].label)
#           puts "ATTENTION: old :set_attribute called by method: #{caller_locations(1,1)[0].label}"
#           puts caller
#           2.times {UI.beep; sleep(0.1)}
#         end
#         set_attribute_without_method_spoofer(*params)
#       end
#
#       def get_attribute_with_method_spoofer(*params)
#         unless Method_spoofer.white_list.include?(caller_locations(1,1)[0].label)
#           puts "ATTENTION: old :get_attribute called by method: #{caller_locations(1,1)[0].label}"
#           puts caller
#           2.times {UI.beep; sleep(0.1)}
#         end
#         get_attribute_without_method_spoofer(*params)
#       end
#
#       def rendering_options_with_method_spoofer(*params)
#         puts '************* rendering options called'
#         puts "params: #{params.inspect}"
#         puts caller
#
#         rendering_options_without_method_spoofer(*params)
#       end
#       def test_with_method_spoofer(*params)
#         #if  params.include?('RenderMode')
#         puts '************* rendering options called'
#         puts "params: #{params.inspect}"
#         puts caller
#         #end
#         test_without_method_spoofer(*params)
#       end
#       def active_model_with_method_spoofer(*params)
#         #if  params.include?('RenderMode')
#         puts "active_model spoofer via: #{caller_locations(1,1)[0].label}"
#         if Sketchup.active_model.rendering_options["RenderMode"] == 2
#           puts '*******'
#           puts 'RenderMode == 2 (spoofer)'
#           puts caller
#           puts '*******'
#         end
#
#         #end
#         active_model_without_method_spoofer(*params)
#       end
#     end
#     include Method_spoofer
#   end
# end
#
# if 1 #SKALP_VERSION == '9.9.9999'
#   #Sketchup::Page.send :include, Skalp::Method_spoofer
#   #Sketchup::Model.send :include, Skalp::Method_spoofer
#   #Sketchup::RenderingOptions.send :include, Skalp::Method_spoofer
#   #Skalp.send :include, Skalp::Method_spoofer
# end
# Startup Debug Info
puts ">>> Skalp Loaded: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')} - Build: #10"
