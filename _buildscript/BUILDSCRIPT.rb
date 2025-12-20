module Skalp_Buildscript
  #TODO debugger, keep data files and only rebuild and copy C files

  starttijd = Time.now
  @filepath = File.dirname(__FILE__)
  require 'base64'
  require 'fileutils'
  require 'net/http'
  require 'zip' #gem install rubyzip
  require_relative "buildscript_methods.rb"
  require_relative "buildscript_xcode.rb"

  @fast_build = ARGV.first == 'fastbuild'
  @internal = ARGV.first == 'internal'
  @version_type = ARGV.first
  @debugger = ARGV[1] == 'debugger'
  @windows = ARGV[2] == 'windows'
  @rebuild_C = ARGV[0] == 'rebuild_C'

  SKALP_BUILD_DATE = Time.now.strftime('%d %B %Y')

  #Get sourcetree path
  @skalp_path = ENV['SKALPDEV'] + '/'
  @skalp_path_source = @skalp_path + "_src/"

  @export_path = @skalp_path + 'SUEX_Skalp/SkalpC/src/'
  @c_path = @skalp_path + 'SUEX_Skalp/Build/'
  @application_path = @skalp_path + 'Skalp_external_application/'
  @build_path = @skalp_path + 'Buildversion/'
  @skalp_sketchup_path = File.expand_path('~') + '/Library/Application Support/SketchUp 2026/SketchUp/Plugins/Skalp_Skalp/'

  clean_xcode

  if @rebuild_C
    build_xcode
    copy_xcode

    puts "*** REBUILD FINISHED! at #{Time.now.strftime("%H:%M:%S")} in #{Time.at(Time.now - starttijd).utc.strftime("%H:%M:%S")} ***"
  else
    delete_data_files

    if @fast_build
      SKALP_VERSION = '2026.0.9999'.freeze
      create_dev_trial_licenses
    else
      path = File.expand_path('~') + '/Dropbox/Skalp/Skalp BUILDS/Skalp_2026_0_'
      ext = '*.rbz'
      skalp_files = Dir[path + ext]

      max_num = 0

      skalp_files.each do |file_name|
        num = file_name.gsub(path, '').gsub(ext, '').to_i
        max_num = num if num > max_num
      end

      new_version_num = max_num + 1

      version_type = case ARGV.first
                     when 'alpha'
                       '%04d_alpha'
                     when 'beta'
                       '%04d_beta'
                     else
                       '%04d'
                     end

      SKALP_VERSION = '2026.0.' + version_type % new_version_num.to_s
    end

    SKALPTRANSLATE_RX = /Skalp\.translate\s?\((["'])(?:(?=(\\?))\2.)*?\1\)/.freeze
    UNIVERSAL_QUOTED_STRING_RX = /(["'])(?:(?=(\\?))\2.)*?\1/.freeze
    TRANSLATE_STRING = /(-*\s*\d*\w\D[^"=;]*)/.freeze
    create_english_translation_file

    #Clean and create build_path
    FileUtils.remove_dir(@build_path, true)
    FileUtils.mkdir(@build_path)
    path = @build_path + 'Skalp_Skalp/'
    FileUtils.mkdir(path)
    create_skalp_rb_file

    @acc_path = @skalp_path_source + 'Skalp_cca_functions/'

    #Clean and create encoder path
    FileUtils.remove_dir(@skalp_path + 'encoder_to/', true)
    FileUtils.mkdir(@skalp_path + 'encoder_to/')
    @input_to_encoder_path = @skalp_path + 'encoder_to/' # puts *.rb source files in here ATTENTION: script fails if directory does not exist
    @result_from_encoder_path = @skalp_path + 'encoder_from/' # get encrypted *.rb files back. ATTENTION: this directory will first be deleted and recreated on the fly

    @temp_files = []

    files, files_not_lic, files_not_lic_rails, files_rbs, one_file = collect_files

    FileUtils.copy(File.join(@skalp_path_source, 'Skalp_lic.rb'), File.join(@input_to_encoder_path, 'Skalp_lic.rb'))
    encode_skalp_lic_error_catching
    FileUtils.copy(File.join(@result_from_encoder_path, 'Skalp_lic.rb'), File.join(@build_path, 'Skalp_Skalp', 'Skalp_lic.rb'))

    FileUtils.copy(File.join(@skalp_path_source, 'Skalp_version.rb'), File.join(@input_to_encoder_path, 'Skalp_version.rb'))
    encode_skalp_version_error_catching
    FileUtils.copy(File.join(@result_from_encoder_path, 'Skalp_version.rb'), File.join(@build_path, 'Skalp_Skalp', 'Skalp_version.rb'))

    unless files == []
      files.each do |file|
        FileUtils.copy(File.join(@skalp_path_source, file), File.join(@input_to_encoder_path, file))
      end

      encode

      Dir.foreach(@result_from_encoder_path) do |rb_file|
        next if rb_file == '.' || rb_file == '..'

        convert(rb_file, @result_from_encoder_path)
      end

      Dir.foreach(@acc_path) do |rb_file|
        next if rb_file == '.' || rb_file == '..'

        convert(rb_file, @acc_path)
      end
    end

    @temp_files.each do |file|
      file_to_delete = File.join(@skalp_path_source, file)
      FileUtils.remove_entry(file_to_delete, true)
    end

    unless files_not_lic_rails == []
      files_not_lic_rails.each do |file|
        FileUtils.copy(File.join(@skalp_path_source, file), File.join(@input_to_encoder_path, file))
      end

      encode_no_lic_rails

      Dir.foreach(@result_from_encoder_path) do |rb_file|
        next if rb_file == '.' || rb_file == '..'

        convert(rb_file, @result_from_encoder_path)
      end
    end

    unless files_not_lic == []
      files_not_lic.each do |file|
        FileUtils.copy(File.join(@skalp_path_source, file), File.join(@input_to_encoder_path, file))
      end

      encode_no_lic

      Dir.foreach(@result_from_encoder_path) do |rb_file|
        next if rb_file == '.' || rb_file == '..'

        convert(rb_file, @result_from_encoder_path)
      end
    end

    unless files_rbs == []
      files_rbs.each do |file|
        FileUtils.copy(File.join(@skalp_path_source, file), File.join(@input_to_encoder_path, file))
      end

      encode_rbs
    end

    build_xcode

    unless @fast_build
      so_file = File.join(@c_path, 'windows/SkalpC.so')
      FileUtils.remove_entry(so_file, true)

      exe_file = File.join(@application_path, 'Release_x64/Skalp_external_application.exe')
      FileUtils.remove_entry(exe_file, true)

      puts 'MAKE YOUR BUILD ON VISUAL STUDIO NOW!'

      until File.exist?(so_file) && File.exist?(exe_file) do
        sleep(1.0)
      end
    end

    sleep(10.0)

    skalp_build

    # Make the fastbuild debug ready
    if @debugger
      if @windows
        @skalp_sketchup_path = '/Users/guywydouw/Dropbox/Skalp_windows_debugger/Skalp_Skalp/'
      else
        @skalp_sketchup_path = File.expand_path('~') + '/Library/Application Support/SketchUp 2026/SketchUp/Plugins/Skalp_Skalp/'
      end

      to_copy = files + files_not_lic + files_not_lic_rails + files_rbs + one_file

      to_copy.each do |file|
        next if file == 'Skalp_dialog.rb'
        FileUtils.copy(File.join(@skalp_path_source, file), File.join(@skalp_sketchup_path, file))
      end

      #FileUtils.copy(File.join(@skalp_path_source, "Skalp_lic.rb"), File.join(skalp_sketchup_path, "Skalp_lic.rb"))
      #FileUtils.copy(File.join(@skalp_path_source, "Skalp_version.rb"), File.join(skalp_sketchup_path, "Skalp_version.rb"))

      FileUtils.copy(File.join(@skalp_path_source, "Skalp_debugger_SkalpC.rb"), File.join(@skalp_sketchup_path, "Skalp_debugger_SkalpC.rb"))

      copy_xcode
      puts "DEBUGGER BUILD FINISHED at #{Time.now.strftime("%H:%M:%S")} in #{Time.at(Time.now - starttijd).utc.strftime("%H:%M:%S")}"
    end

    puts "FAST BUILD FINISHED at #{Time.now.strftime("%H:%M:%S")} in #{Time.at(Time.now - starttijd).utc.strftime("%H:%M:%S")}" unless @debugger

    # SIGNING AND WRAPPING SKALP INSTALLER
    unless @fast_build || @internal
      puts; puts 'Continuing: singing and wrapping Skalp Installer...'
      build_version_number = SKALP_VERSION.tr('.', '_')
      skalp_rbz = File.expand_path("~/Dropbox/Skalp/Skalp BUILDS/Skalp_#{build_version_number}_unsigned.rbz")
      skalp_full_rbz = File.expand_path("~/Dropbox/Skalp/Skalp BUILDS/Skalp_#{build_version_number}.rbz")
      intaller_directory = "#{@skalp_path}Skalp_Skalp_installer/"
      skalp_build_name = File.basename(skalp_rbz)
      FileUtils.move(sign_rbz(skalp_rbz), "#{intaller_directory}Skalp_Skalp_installer/Skalp.rbz")

      skalp_installer_build_name = "Skalp_Skalp_installer#{build_version_number}.rbz"
      zipfile_name = File.expand_path("~/Dropbox/Skalp/Skalp BUILDS/#{skalp_installer_build_name}")

      Zip::File.open(zipfile_name, Zip::File::CREATE) do |zipfile|
        Dir[File.join(intaller_directory, '**', '**')].each do |file|
          zipfile.add(file.sub(intaller_directory, ''), file)
        end
      end

      File.delete("#{intaller_directory}Skalp_Skalp_installer/Skalp.rbz") # cleanup installer build, prepare for next build

      FileUtils.move(sign_rbz(zipfile_name), File.expand_path("~/Dropbox/Skalp/Skalp BUILDS/#{skalp_installer_build_name}"))
      File.delete(skalp_rbz)
      FileUtils.move(File.expand_path("~/Dropbox/Skalp/Skalp BUILDS/#{skalp_installer_build_name}"), skalp_full_rbz)

      def self.new_skalp_version_on_server(release_date, version, version_type, su_min, su_max, public = 0)
        uri = URI("http://license.skalp4sketchup.com/register_2_0/new_skalp_version.php?release_date=#{release_date}&version=#{version}&version_type=#{version_type}&min_SU_version=#{su_min}&max_SU_version=#{su_max})&public=#{public}")
        Net::HTTP.get(uri)
      end

      new_skalp_version_on_server(Time.now.strftime('%Y-%m-%d'), SKALP_VERSION.delete('.').to_i, @version_type, 25, 25)

      puts
      puts "*** FULL BUILD FINISHED! at #{Time.now.strftime("%H:%M:%S")} in #{Time.at(Time.now - starttijd).utc.strftime("%H:%M:%S")} ***"
    end

    if @internal
      def self.new_skalp_version_on_server(release_date, version, version_type, su_min, su_max, public = 0)
        uri = URI("http://license.skalp4sketchup.com/register_2_0/new_skalp_version.php?release_date=#{release_date}&version=#{version}&version_type=#{version_type}&min_SU_version=#{su_min}&max_SU_version=#{su_max})&public=#{public}")
        Net::HTTP.get(uri)
      end

      new_skalp_version_on_server(Time.now.strftime('%Y-%m-%d'), SKALP_VERSION.delete('.').to_i, @version_type, 25, 25)

      puts
      puts "*** UNSIGNED BUILD FINISHED! at #{Time.now.strftime("%H:%M:%S")} in #{Time.at(Time.now - starttijd).utc.strftime("%H:%M:%S")} ***"
    end
  end
end
