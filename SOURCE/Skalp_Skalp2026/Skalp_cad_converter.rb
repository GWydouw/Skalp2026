module Skalp
  module Cad_File_Converter
    require "shellwords"

    # Teigha file converter download:
    # https://www.opendesign.com/guestfiles/oda_file_converter
    # Teigha File Converter command line parameters
    # https://www.freecadweb.org/tracker/view.php?id=1103
    class << self
      attr_accessor :teigha_path, :input_path, :output_path, :output_version, :output_file_type, :recurse_input_older, :audit_each_file, :input_file_filter # [optional] Input file filter (default:"*.DWG;*.DXF")
    end

    self.output_version = "ACAD2013" # {"ACAD9","ACAD10","ACAD12", "ACAD13","ACAD14", "ACAD2000","ACAD2004", "ACAD2007","ACAD2010" ,"ACAD2013"}
    self.output_file_type = "DWG" # {"DWG","DXF","DXB"}
    self.recurse_input_older = "0" # Recurse Input Folder {"0","1"}
    self.audit_each_file = "1" # Audit each file # {"0","1"}

    def self.correct_input_path_for_windows(input)
      Pathname.new(input).to_s.gsub("/", "\\").chop!
    end

    def self.files_to_convert?
      path = input_path + "/*.dxf"
      dxf_files = Dir[path]

      return true if dxf_files.size > 0

      false
    end

    def self.convert
      return unless files_to_convert?

      check_teigha

      if Sketchup.platform == :platform_osx
        cmds = [teigha_cmd]
        null = test("e", "/dev/null") ? "/dev/null" : "NUL"
        lines = nil
        cmds.each do |cmd|
          stdout = begin
            IO.popen("#{cmd} 2> #{null}") { |fd| fd.readlines }
          rescue StandardError
            next
          end
          next unless stdout and stdout.size > 0

          lines = stdout and break
        end
      end

      if Sketchup.platform == :platform_win # TODO: untested
        require "win32ole"

        cmd = teigha_cmd

        objStartup = WIN32OLE.connect("winmgmts:\\\\.\\root\\cimv2:Win32_ProcessStartup")
        objConfig = objStartup.SpawnInstance_
        objConfig.ShowWindow = 0 # HIDDEN_WINDOW
        objProcess = WIN32OLE.connect("winmgmts:root\\cimv2:Win32_Process")

        objProcess.Create(cmd, nil, objConfig, nil)
      end
    rescue StandardError
      nil
    end

    def self.install_teigha
      if OS == :MAC
        url = "http://#{LICENSE_SERVER}/downloads/dwg_converter/installer_mac_v2.zip"
        path = SKALP_PATH + "FileConverter/mac/ODAFileConverter.app/Contents/MacOS/ODAFileConverter"
      else
        url = "http://#{LICENSE_SERVER}/downloads/dwg_converter/installer_windows_v2.zip"
        path = SKALP_PATH + "FileConverter/windows/ODAFileConverter.exe"
      end

      return true if File.exist?(path)

      return false unless Sketchup.is_online

      installer = SKALP_PATH + "dwg_converter_installer.zip"

      UI.messagebox("Skalp will now download the DXF/DWG converter installer. Please allow installation.")

      File.open(installer, "wb") do |installer_file|
        URI.open(url, "rb") do |read_file|
          installer_file.write(read_file.read)
        end
      end

      begin
        Sketchup.install_from_archive(installer)
      rescue Interrupt
        UI.messagebox("Skalp need to install the DXF/DWG converter. Please allow installation.")
        retry
      rescue Exception => e
        UI.messagebox("Error installing DXF/DWG converter: #{e}")
        return false
      end

      FileUtils.remove_entry(installer, true) if File.exist?(installer)
      true
    end

    def self.check_teigha
      return if teigha_path && File.file?(teigha_path)

      if Sketchup.platform == :platform_osx
        self.teigha_path = Shellwords.shellescape(SKALP_PATH + "FileConverter/mac/ODAFileConverter.app/Contents/MacOS/ODAFileConverter")
      else
        self.teigha_path = SKALP_PATH + "FileConverter/windows/ODAFileConverter.exe"
      end

      install_teigha unless File.file?(teigha_path)
    end

    def self.inspect_teigha_cmd
      return unless defined?(DEBUG) && DEBUG

      puts "teigha_path: #{teigha_path}",
           "input_path: #{input_path}",
           "output_path: #{output_path}",
           "output_version: #{output_version}",
           "output_file_type: #{output_file_type}",
           "recurse_input_older: #{recurse_input_older}",
           "audit_each_file: #{audit_each_file}"
      puts "totaal teigha_cm:\n#{teigha_cmd}"
    end

    def self.teigha_cmd
      if Sketchup.platform == :platform_win
        require "Skalp_Skalp2026/shellwords/shellwords"

        input_path_win = Shellwords.shellescape(input_path)
        output_path_win = Shellwords.shellescape(output_path)
        path = teigha_path

        cmd = %("#{path}" #{input_path_win} #{output_path_win} "#{output_version}" "#{output_file_type}" "#{recurse_input_older}" "#{audit_each_file}")
        cmd.encode("utf-8")

      else # macOS
        "#{teigha_path} '#{input_path}' '#{output_path}' #{output_version} #{output_file_type} #{recurse_input_older} #{audit_each_file}"
      end
    end
  end
end

# Skalp::Cad_File_Converter.convert

# self.teigha_path = '/Applications/TeighaFileConverter.app/Contents/MacOS/TeighaFileConverter'
