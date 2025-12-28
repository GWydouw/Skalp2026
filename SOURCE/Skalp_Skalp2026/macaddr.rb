# frozen_string_literal: true

module Skalp
  def self.send_bug(e = nil)
    return unless Sketchup.active_model
    return if Sketchup.read_default("Skalp", "noBugtracking")

    require "net/http"

    return unless Sketchup.is_online

    data = if e
             {
               "guid" => find_guid,
               "OS" => OS.to_s,
               "ErrorClass" => e.class.to_s,
               "ErrorBacktrace" => e.backtrace.inspect[0...999],
               "ErrorMessage" => e.message.to_s,
               "version" => SKALP_VERSION,
               "SU_version" => Sketchup.version,
               "SU_language" => Sketchup.os_language
             }
           else
             {
               "guid" => find_guid,
               "OS" => OS.to_s,
               "ErrorClass" => "observer Error",
               "ErrorBacktrace" => "",
               "ErrorMessage" => "",
               "version" => SKALP_VERSION,
               "SU_version" => Sketchup.version,
               "SU_language" => Sketchup.os_language
             }
           end

    return if data == @last_bug

    @last_bug = data
    # Async HTTP to prevent UI freeze
    Thread.new do
      Net::HTTP.post_form(URI.parse("http://bugtracking.skalp4sketchup.com/bugtracking/bug.php"), data)
    rescue StandardError
      # Silent fail for telemetry
    end
  end

  def self.find_guid
    if Skalp.respond_to?(:guid)
      return guid
    elsif guid
      user_guid = Sketchup.read_default("Skalp", "guid")
      return user_guid if user_guid && user_guid != ""
    end

    "no guid found"
  end

  def self.send_info(*args)
    return if Sketchup.read_default("Skalp", "noBugtracking")
    return unless SKALP_VERSION.include?("beta") || SKALP_VERSION.include?("alpha") || SKALP_VERSION[-4..-1] == "9999"

    require "net/http"
    return unless Sketchup.is_online

    data = {
      "guid" => guid,
      "OS" => OS.to_s,
      "ErrorClass" => args[0].to_s,
      "ErrorBacktrace" => args[1].to_s,
      "ErrorMessage" => args[2].to_s,
      "version" => SKALP_VERSION,
      "SU_version" => Sketchup.version,
      "SU_language" => Sketchup.os_language
    }

    return if data == @last_bug

    @last_bug = data

    # Async HTTP to prevent UI freeze
    Thread.new do
      Net::HTTP.post_form(URI.parse("http://bugtracking.skalp4sketchup.com/bugtracking/bug.php"), data)
    rescue StandardError
      # Silent fail for telemetry
    end
  end

  module Mac
    def self.address
      return @mac_address if defined? @mac_address

      mac_addresses = RGLoader.get_mac_addresses
      mac_addresses.map!(&:downcase) if Sketchup.platform == :platform_osx
      @mac_address = clean_mac(mac_addresses)
    rescue StandardError
      legacy_address
    end

    def self.legacy_address
      return @mac_address if defined? @mac_address

      if Sketchup.platform == :platform_osx
        regex = /[^:-](?:[0-9A-F][0-9A-F][:-]){5}[0-9A-F][0-9A-F][^:-]/io
        cmds = "/sbin/ifconfig", "/bin/ifconfig", "ifconfig"

        null = test("e", "/dev/null") ? "/dev/null" : "NUL"

        lines = nil
        cmds.each do |cmd|
          stdout = begin
            IO.popen("#{cmd} 2> #{null}", &:readlines)
          rescue StandardError
            next
          end
          next unless stdout && !stdout.empty?

          (lines = stdout) && break
        end

        mac_addr = lines.select { |line| line =~ regex }
        mac_addr.map! { |c| c[regex].strip }

      end

      if Sketchup.platform == :platform_win
        mac_addr = []
        regex = Regexp.compile("(..[:-]){5}..")

        temp_path = File.expand_path(ENV["TMPDIR"] || ENV["TMP"] || ENV.fetch("TEMP", nil))
        tempfile = File.join(temp_path, "temp.txt")

        params = "/c ipconfig.exe /all > " + "\"#{tempfile}\""
        require "win32ole"
        shell = WIN32OLE.new("Shell.Application")
        Dir.chdir(ENV["systemroot"] ? File.join(ENV["systemroot"], "System32") : "") do
          shell.ShellExecute("cmd.exe", params, "", "open", 0)
          # TODO: shell.ShellExecute('cmd.exe', params, '', 'runas', 0) # 'runas' instead of 'open' to use elevated admin rights,
          # causes admin popup warning but ensures ipconfig works
          # on all systems
        end # Dir.chdir restores the original working path on leaving the block

        max = 0

        until max == 50 || (File.exist?(tempfile) && File.readable?(tempfile))
          sleep 0.1
          max += 1
        end

        if max == 50
          if !File.exist?(tempfile)
            UI.messagebox("Skalp Error creating #{tempfile}, file doesn't exist! Please contact support.")
          elsif !File.readable?(tempfile)
            UI.messagebox("Skalp Error creating #{tempfile}, file isn't readable! Please contact support.")
          end
        else
          sleep 0.1 # 1.0

          File.open(tempfile, "r", encoding: Encoding.find("filesystem")) do |file|
            lines = file.grep(regex)

            lines.each do |line|
              mac_from_line = line.strip[-17, 17]
              next unless mac_from_line

              mac_addr << mac_from_line.upcase.tr("-", ":")
            end
          end

          File.unlink(tempfile)
        end
      end

      mac_addr ||= []

      @mac_address = clean_mac(mac_addr)
    rescue StandardError => e
      Skalp.send_info("Bug MAC address")
      Skalp.send_bug(e)
      [""]
    end
    private_class_method :legacy_address

    def self.clean_mac(mac_addr)
      cleaned_mac = []
      mac_addr.each do |mac|
        check_mac = mac.delete(":").delete("-").delete(".").delete("0")
        cleaned_mac << mac unless check_mac == "E"
      end
      cleaned_mac.empty? ? [""] : cleaned_mac

      # Apple appears to be using the same MAC address (ac:de:48:00:11:22) for the "iBridge" interface to the Touch Bar
      # on new MacBook Pro (later 2016). We removed this when releasing Skalp 4.0 prior to any end user activation on Skalp 4.
      # This non unique mac address could lead to license/user collisions on query in the skalp.activation table on both mac and hash_id.
      cleaned_mac.delete("ac:de:48:00:11:22") # modifies original array but returns deleted element(s)
      cleaned_mac
    end
    private_class_method :clean_mac
  end
end
