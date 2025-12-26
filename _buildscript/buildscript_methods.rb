module Skalp_Buildscript
  def self.create_skalp_rb_file
    text = File.read(@skalp_path_source + 'Skalp.rb')
    text.gsub!('#SKALPVERSION#', SKALP_VERSION)
    text.gsub!('#SKALPBUILDDATE#', SKALP_BUILD_DATE)

    if @internal || @fast_build
      if @debugger
        text.gsub!('#SKALPDEBUGGER#', 'SKALPDEBUGGER = true')
      else
        text.gsub!('#SKALPDEBUGGER#', 'SKALPDEBUGGER = false')
      end
      text.gsub!('#SKETCHUPDEBUG#', 'Sketchup.debug_mode = true')
      text.gsub!('#SKALPDEBUG#', 'DEBUG = true')
      text.gsub!('#SKALPCONSOLE#', 'SKETCHUP_CONSOLE.show')
    else
      text.gsub!('#SKETCHUPDEBUG#', '')
      text.gsub!('#SKALPDEBUG#', '')
      text.gsub!('#SKALPDEBUGGER#', 'SKALPDEBUGGER = false')
      text.gsub!('#SKALPCONSOLE#', '')
    end

    File.open(@build_path + 'Skalp_Skalp.rb', 'w:UTF-8') { |file| file.puts text }
  end
  def self.collect_files
    files_rbs = []

    files_not_lic = []
    files_not_lic << 'Skalp_geom2.rb'
    files_not_lic << 'Skalp_lib2.rb'
    files_not_lic << 'Skalp_loader.rb'
    files_not_lic << 'Skalp_preferences.rb'
    files_not_lic << 'Skalp_observers.rb'
    files_not_lic << 'Skalp_translator.rb'
    files_not_lic << 'Skalp_translator.rb'
    files_not_lic << 'Skalp_UI.rb'
    files_not_lic << 'Skalp_update.rb'
    files_not_lic << 'Skalp_info.rb'
    files_not_lic << 'Skalp_paintbucket.rb'
    files_not_lic << 'Skalp_material_dialog.rb'
    files_not_lic << 'Skalp_cad_converter.rb'
    files_not_lic << 'Skalp_white_mode.rb'
    #files_not_lic << 'Skalp_overlay.rb'
    files_not_lic << 'Skalp_dwg_export_dialog.rb'
    files_not_lic << 'Skalp_API.rb'
    #files_not_lic << 'Skalp_lines.rb'
    #files_not_lic << 'Skalp_sectiongroup.rb'
    files_not_lic << 'Skalp_box_section.rb'
    files_not_lic << 'Skalp_box_section_tool.rb'

    files_not_lic_rails = []
    files_not_lic_rails << 'Skalp_license.rb'
    files_not_lic_rails << 'macaddr.rb'

    files = []
    files << 'Skalp_start.rb'
    files << 'Skalp_hatch_lib.rb'
    files << 'Skalp_hatchtile.rb'
    files << 'Skalp_hatch_class.rb'
    files << 'Skalp_hatchdefinition_class.rb'
    files << 'Skalp_hatchline_class.rb'
    files << 'Skalp_hatchpatterns_main.rb'
    files << 'Skalp_converter.rb'
    files << 'Skalp_tree.rb'
    files << 'Skalp_layer.rb'
    files << 'Skalp_page.rb'
    files << 'Skalp_visibility.rb'
    files << 'Skalp_section2D.rb'
    files << 'Skalp_sectionplane.rb'
    files << 'Skalp_section.rb'
    files << 'Skalp_model.rb'
    files << 'Skalp_materials.rb'
    files << 'Skalp_algorithm.rb'
    files << 'Skalp_control_center.rb'
    files << 'Skalp_pages_undoredo.rb'
    files << 'Skalp_dxf.rb'
    files << 'Skalp_memory_attributes.rb'
    files << 'Skalp_fog.rb'
    files << 'Skalp_isolate.rb'
    files << 'Skalp_dashed_lines.rb'
    files << 'Skalp_hiddenlines.rb'
    files << 'Skalp_multipolygon.rb'

    one_file = []
    one_file << 'Skalp_style_settings.rb'
    one_file << 'Skalp_webdialog.rb'
    one_file << 'Skalp_section_dialog.rb'
    one_file << 'Skalp_hatch_dialog.rb'
    one_file << 'Skalp_tile_size.rb'
    one_file << 'Skalp_style_rules.rb'
    one_file << 'Skalp_rendering_options.rb'
    one_file << 'Skalp_export_import_materials.rb'
    one_file << 'Skalp_scenes2images.rb'

    combine(one_file, 'Skalp_dialog.rb')

    files << 'Skalp_dialog.rb'
    @temp_files << 'Skalp_dialog.rb'

    return files, files_not_lic, files_not_lic_rails, files_rbs, one_file
  end
  def self.create_dev_trial_licenses
    @devlicpath = ENV['SKALPDEV'] + '/' + 'dev_trial_license_files/'
    cmd = "./make_dev_licenses.sh \"#{@devlicpath}\""
    retval = `#{cmd}`
    puts retval
  end

  def self.get_translate_strings(line)
    # input e.g. a line
    # line = %q^To Skalp.translate("day's date VOORBEELD1 met inch vermeld") is: 1019"dit is een test voor woordeSkalp.translate ('day"s date met VOORBEEL 2 inch vermeld')dit is andere brol() en Skalp gezever "test'" en nog iets "test"^

    translate_matches = []
    line.scan(SKALPTRANSLATE_RX) { translate_matches << $LAST_MATCH_INFO }
    translate_matches.map! { |gotcha| gotcha.to_s.match(UNIVERSAL_QUOTED_STRING_RX).to_s }
  end

  def self.create_english_translation_file
    # TODO: translation of webdialogs!!!

    all_words = []
    string_file = @skalp_path_source + 'resources/strings/en-US/skalp.strings'

    file = File.open(string_file, 'w:UTF-8')

    Dir.foreach(@skalp_path_source) do |rb_file|
      title_text = false

      next if rb_file == '.' || rb_file == '..'
      next if rb_file.include?('.rbs')
      next unless rb_file.include?('.rb')

      File.readlines(@skalp_path_source + rb_file).each do |line|
        strings = get_translate_strings(line)

        strings.each do |en_string|
          unless title_text
            file.puts "// #{rb_file.gsub('.rb', '')} ////////////////////////////////////////////"
            title_text = true
          end

          unless all_words.include?(en_string)
            file.puts %("#{en_string[1..-2]}" = "#{en_string[1..-2]}";)
            all_words << en_string
          end
        end
      end
    end

    file.close

    Dir.foreach(@skalp_path_source + 'resources/strings/') do |language|
      next if language == '.' || language == '..' || language == 'en-US' || language == '.DS_Store' || language == 'translation.csv'

      update_translation_file(language)
    end

    # create CSV translation file
    create_translation_csv
  end

  def self.create_translation_csv
    translation_file = File.open(@skalp_path_source + 'resources/strings/translation.csv', 'w:UTF-8')

    # Get all translated strings for each language
    languages = {}
    Dir.foreach(@skalp_path_source + 'resources/strings/') do |language|
      next if language == '.' || language == '..' || language == '.DS_Store' || language == 'translation.csv'

      string_file = @skalp_path_source + 'resources/strings/' + language + '/skalp.strings'
      languages[language] = File.readlines(string_file)
    end

    # Define language titles
    line = 'en-US'
    languages.each_key do |language|
      next if language == 'en-US'

      line = line + ';' + language.to_s
    end
    translation_file.puts line

    (0..languages['en-US'].size - 1).each do |n|
      if languages['en-US'][n][0] == '/'
        translation_file.puts languages['en-US'][n]
        next
      else
        line = languages['en-US'][n].scan(TRANSLATE_STRING)[0]
        next unless line

        line = line[0]
        languages.each_key do |language|
          next if language == 'en-US'

          other_language = languages[language][n]
          # puts other_language

          if other_language
            other_language = other_language.scan(TRANSLATE_STRING)[1]
            other_language = other_language ? other_language[0] : ''
          else
            other_language = ''
          end

          line = line + ';' + other_language.to_s
        end
        translation_file.puts line
      end
    end
  end

  def self.update_translation_file(language)
    file = @skalp_path_source + 'resources/strings/' + language + '/skalp.strings'

    translations = {}

    File.readlines(file).each do |line|
      next if line[0] == '/' || line[0] == ''

      result = line.scan(TRANSLATE_STRING)
      next unless result
      next if result == []

      translations[result[0][0]] = result[1][0] if result[1]
    end

    language_file = File.open(file, 'w:UTF-8')
    string_file = @skalp_path + 'resources/strings/en-US/skalp.strings'
    File.readlines(string_file).each do |line|
      if line[0] == '/' || line[0] == ''
        language_file.puts line
      else
        result = line.scan(TRANSLATE_STRING)[0]
        next unless result

        if translations[result[0]]
          language_file.puts %("#{result[0]}" = "#{translations[result[0]]}";)
        else
          language_file.puts %("#{result[0]}" = "";)
        end
      end
    end
    language_file.close
  end

  def self.combine(files_to_combine, filename)
    combined_file = @skalp_path_source + filename

    File.open(combined_file, 'w:UTF-8') do |mergedFile|
      files_to_combine.each do |file|
        File.readlines(@skalp_path_source + file).each { |line| mergedFile << line }
      end
    end
  end

  def self.convert(filename, path)
    File.open(path + filename, 'r') do |f1|
      a = ''

      while line = f1.gets
        a += line
      end

      a_encode = Base64.encode64(a)
      a_encode.delete!("\n")

      c_code = ''

      first = true

      until a_encode.empty?

        b = a_encode.slice!(0, 500)

        if first
          c_code += ' std::string("' + b + '")'
          first = false
        else
          c_code += ' + "' + b + '"'
        end
      end

      c_code += ';'

      data_filename = filename.gsub('.rb', '.data')
      File.open(@export_path + data_filename, 'w:UTF-8') { |file| file.write(c_code) }
    end
  end

  def self.encode
    # to an from encoder
    cmd = "./rb2rbe.sh \"#{@result_from_encoder_path}\" \"#{@input_to_encoder_path}\""
    retval = `#{cmd}`
    puts retval
  end

  def self.encode_skalp_lic_error_catching
    # to an from encoder
    cmd = "./rb2rbe_skalp_lic_error_catching.sh \"#{@result_from_encoder_path}\" \"#{@input_to_encoder_path}\""
    retval = `#{cmd}`
    puts retval
  end

  def self.encode_no_lic
    # to an from encoder
    cmd = "./rb2rbe_no_lic.sh #{SKALP_VERSION} \"#{@result_from_encoder_path}\" \"#{@input_to_encoder_path}\""
    retval = `#{cmd}`
    puts retval
  end

  def self.encode_skalp_version_error_catching
    # to an from encoder
    cmd = "./rb2rbe_skalp_version_error_catching.sh #{SKALP_VERSION} \"#{@result_from_encoder_path}\" \"#{@input_to_encoder_path}\""
    retval = `#{cmd}`
    puts retval
  end

  def self.encode_no_lic_rails
    # to an from encoder
    cmd = "./rb2rbe_no_lic_rails.sh \"#{@result_from_encoder_path}\" \"#{@input_to_encoder_path}\""
    retval = `#{cmd}`
    puts retval
  end

  def self.encode_rbs
    # to an from encoder
    # cmd = "./rb2rbs.sh \"#{@result_from_encoder_path}\" \"#{@input_to_encoder_path}\""
    cmd = "./Scrambler \"#{@skalp_path_source}Skalp_geom2.rb\" \"#{@skalp_path_source}Skalp_lib2.rb\" \"#{@skalp_path_source}Skalp_isolate.rb\""
    retval = `#{cmd}`
    puts retval
  end

  def self.skalp_build
    require 'fileutils'
    require 'rubygems'
    require 'zip' # sudo gem install rubyzip

    # Skalp)
    FileUtils.copy(File.join(@result_from_encoder_path, 'Skalp_geom2.rb'), File.join(@build_path, 'Skalp_Skalp', 'Skalp_geom2.rb'))
    FileUtils.copy(File.join(@result_from_encoder_path, 'Skalp_lib2.rb'), File.join(@build_path, 'Skalp_Skalp', 'Skalp_lib2.rb'))
    FileUtils.copy(File.join(@result_from_encoder_path, 'Skalp_API.rb'), File.join(@build_path, 'Skalp_Skalp', 'Skalp_API.rb'))
    FileUtils.copy(File.join(@result_from_encoder_path, 'Skalp_paintbucket.rb'), File.join(@build_path, 'Skalp_Skalp', 'Skalp_paintbucket.rb'))
    FileUtils.copy(File.join(@result_from_encoder_path, 'Skalp_material_dialog.rb'), File.join(@build_path, 'Skalp_Skalp', 'Skalp_material_dialog.rb'))
    FileUtils.copy(File.join(@result_from_encoder_path, 'Skalp_cad_converter.rb'), File.join(@build_path, 'Skalp_Skalp', 'Skalp_cad_converter.rb'))
    FileUtils.copy(File.join(@result_from_encoder_path, 'Skalp_dwg_export_dialog.rb'), File.join(@build_path, 'Skalp_Skalp', 'Skalp_dwg_export_dialog.rb'))
    FileUtils.copy(File.join(@result_from_encoder_path, 'Skalp_loader.rb'), File.join(@build_path, 'Skalp_Skalp', 'Skalp_loader.rb'))
    FileUtils.copy(File.join(@result_from_encoder_path, 'Skalp_info.rb'), File.join(@build_path, 'Skalp_Skalp', 'Skalp_info.rb'))
    FileUtils.copy(File.join(@result_from_encoder_path, 'Skalp_preferences.rb'), File.join(@build_path, 'Skalp_Skalp', 'Skalp_preferences.rb'))
    FileUtils.copy(File.join(@result_from_encoder_path, 'Skalp_observers.rb'), File.join(@build_path, 'Skalp_Skalp', 'Skalp_observers.rb'))
    FileUtils.copy(File.join(@result_from_encoder_path, 'Skalp_UI.rb'), File.join(@build_path, 'Skalp_Skalp', 'Skalp_UI.rb'))
    FileUtils.copy(File.join(@result_from_encoder_path, 'Skalp_translator.rb'), File.join(@build_path, 'Skalp_Skalp', 'Skalp_translator.rb'))
    FileUtils.copy(File.join(@result_from_encoder_path, 'Skalp_update.rb'), File.join(@build_path, 'Skalp_Skalp', 'Skalp_update.rb'))
    FileUtils.copy(File.join(@result_from_encoder_path, 'Skalp_white_mode.rb'), File.join(@build_path, 'Skalp_Skalp', 'Skalp_white_mode.rb'))
    FileUtils.copy(File.join(@result_from_encoder_path, 'Skalp_box_section.rb'), File.join(@build_path, 'Skalp_Skalp', 'Skalp_box_section.rb'))
    FileUtils.copy(File.join(@result_from_encoder_path, 'Skalp_box_section_tool.rb'), File.join(@build_path, 'Skalp_Skalp', 'Skalp_box_section_tool.rb'))
    #FileUtils.copy(File.join(@result_from_encoder_path, 'Skalp_overlay.rb'), File.join(@build_path, 'Skalp_Skalp', 'Skalp_overlay.rb'))
    
    # Copy icons directory for box section
    icons_source = File.join(@skalp_path, '_src', 'icons')
    icons_dest = File.join(@build_path, 'Skalp_Skalp', 'icons')
    FileUtils.mkdir_p(icons_dest) unless Dir.exist?(icons_dest)
    FileUtils.cp_r(icons_source, File.dirname(icons_dest)) if Dir.exist?(icons_source)

    FileUtils.copy(File.join(@c_path, 'windows/SkalpC.so'), File.join(@build_path, 'Skalp_Skalp', 'SkalpC.win')) unless @fast_build

    FileUtils.copy(File.join(@c_path, 'mac/SkalpC.bundle'), File.join(@build_path, 'Skalp_Skalp', 'SkalpC.mac'))

    require 'shellwords'
    source = Shellwords.escape(File.join(@skalp_path, 'SketchUp frameworks/lib_mac'))
    Dir.mkdir(File.join(@build_path, 'Skalp_Skalp', 'lib_mac'))
    FileUtils.rm_rf(@skalp_path + 'SketchUp frameworks/lib_mac/LayOutAPI.framework')
    FileUtils.rm_rf(@skalp_path + 'SketchUp frameworks/lib_mac/SketchUpAPI.framework')
    FileUtils.mv(File.join(@application_path, 'Build/Products/Release/Skalp_external_application'), File.join(@skalp_path, 'SketchUp frameworks/lib_mac/Skalp'))

    FileUtils.cp_r(@application_path + 'Build/Products/Release/LayOutAPI.framework', @skalp_path + 'SketchUp frameworks/lib_mac/')
    FileUtils.cp_r(@application_path + 'Build/Products/Release/SketchUpAPI.framework', @skalp_path + 'SketchUp frameworks/lib_mac/')

    Dir.chdir(File.join(@build_path, 'Skalp_Skalp', 'lib_mac')) do
      `tar -zcf lib_mac.tar.gz -C #{source} .`
    end

    unless @fast_build
      Dir.mkdir(File.join(@build_path, 'Skalp_Skalp', 'lib_win'))
      Dir.glob(@application_path + 'Release_x64/*.dll') do |file|
        FileUtils.copy(file, @build_path + 'Skalp_Skalp/lib_win/' + File.basename(file))
      end

      FileUtils.copy(File.join(@application_path, 'Release_x64/Skalp_external_application.exe'), File.join(@build_path, 'Skalp_Skalp', 'lib_win/Skalp.exe'))
    end

    path = @build_path + 'Skalp_Skalp/'

    # Skalp/html
    FileUtils.cp_r(Dir[@skalp_path_source + 'html'], path)

    # Skalp/resources
    FileUtils.cp_r(Dir[@skalp_path_source + 'resources'], path)

    # Skalp/rgloader
    FileUtils.cp_r(Dir[@skalp_path_source + 'eval'], path)

    # Skalp/chunky_png
    FileUtils.cp_r(Dir[@skalp_path_source + 'chunky_png'], path)

    # Shellwords
    FileUtils.cp_r(Dir[@skalp_path_source + 'shellwords'], path)

    FileUtils.copy(File.join(@skalp_path_source, 'LICENSE.txt'), File.join(@build_path, 'Skalp_Skalp', 'LICENSE.txt'))

    # make rbz
    unless @fast_build
      directory = @build_path
      zipfile_name = @build_path + "Skalp_#{SKALP_VERSION.tr('.', '_')}.rbz" # TODO: buildversion toevoegen

      Zip::File.open(zipfile_name, Zip::File::CREATE) do |zipfile|
        Dir[File.join(directory, '**', '**')].each do |file|
          zipfile.add(file.sub(directory, ''), file)
        end
      end

      if @internal
        FileUtils.copy(zipfile_name, File.expand_path('~') + "/Dropbox/Skalp/Skalp BUILDS/Skalp_#{SKALP_VERSION.tr('.', '_')}_internal.rbz")
      else
        FileUtils.copy(zipfile_name, File.expand_path('~') + "/Dropbox/Skalp/Skalp BUILDS/Skalp_#{SKALP_VERSION.tr('.', '_')}_unsigned.rbz")
      end

    end

    # COPY TO SKETCHUP
    if @fast_build
      # Sketchup 2023 beta

      plugin_sketchup_path = ''
      skalp_sketchup_path = ''

      if RUBY_PLATFORM.downcase.include?('darwin')
        if @windows
          plugin_sketchup_path = '/Users/guywydouw/Dropbox/Skalp_windows_debugger/'
          skalp_sketchup_path = '/Users/guywydouw/Dropbox/Skalp_windows_debugger/Skalp_Skalp/'
        else
          plugin_sketchup_path = File.expand_path('~') + '/Library/Application Support/SketchUp 2026/SketchUp/Plugins/'
          skalp_sketchup_path = File.expand_path('~') + '/Library/Application Support/SketchUp 2026/SketchUp/Plugins/Skalp_Skalp/'
        end

      end

      FileUtils.remove_dir(skalp_sketchup_path, true)

      sourcetree_skalp_path = @build_path + 'Skalp_Skalp/'
      FileUtils.cp_r(Dir[sourcetree_skalp_path], plugin_sketchup_path)
      # skalp.rb
      FileUtils.copy(File.join(@build_path, 'Skalp_Skalp.rb'), File.join(plugin_sketchup_path, 'Skalp_Skalp.rb'))

      # skalp.lic
      if @include_lic
        lic_file = File.join(@skalp_path, 'dev_license_files/Skalp.lic')
        lic_file = File.join(@skalp_path, 'dev_license_files/Guy.lic') unless File.exist?(lic_file)
        if File.exist?(lic_file)
          FileUtils.copy(lic_file, File.join(skalp_sketchup_path, 'Skalp.lic'))
          puts "License file copied from #{File.basename(lic_file)}"
        else
          puts "Warning: No license file found in dev_license_files/ (Skalp.lic or Guy.lic)"
        end
      end
    end
  end

  def self.sign_rbz(skalp_rbz)
    skalp_rbz_name = File.basename(skalp_rbz)
    new_signed_skalp_rbz = File.expand_path("~/Downloads/#{skalp_rbz_name}")
    File.delete(new_signed_skalp_rbz) if File.exist?(new_signed_skalp_rbz)
    system('open -a safari https://extensions.sketchup.com/en/developer_center/extension_signature')

    puts; puts "Looking for new signed '#{skalp_rbz_name}' in your downloads folder..."
    until File.exist?(new_signed_skalp_rbz) do
      sleep(0.1)
    end
    puts "OK: New Signed '#{skalp_rbz_name}' found."
    new_signed_skalp_rbz
  end

  def self.delete_data_files
    temp_files = []
    Dir.foreach(@export_path) do |data_file|
      next if data_file == '.' || data_file == '..'

      temp_files << data_file if data_file.include?('.data')
    end

    temp_files.each do |file|
      file_to_delete = File.join(@export_path, file)
      FileUtils.remove_entry(file_to_delete, true)
    end
  end
end