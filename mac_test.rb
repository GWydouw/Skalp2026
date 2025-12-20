def self.address
    mac_addr = []
    regex = Regexp.compile('(..[:-]){5}..')

    temp_path = Sketchup.find_support_file("Plugins")+"/"
    tempfile = File.join(temp_path, 'temp.txt')

    puts tempfile

    File.open(tempfile, 'r', :encoding => Encoding::find("filesystem")) do |file|
      lines = file.grep(regex)

      lines.each do |line|
        mac_from_line = line.strip[-17, 17]
        next unless mac_from_line
        mac_addr << mac_from_line.upcase().gsub(/-/, ':')
      end
    end

    #File.unlink(tempfile)

    mac_address = mac_addr

    cleaned_mac = []

    for mac in mac_address do
      check_mac = mac.gsub(':', '').gsub('-', '').gsub('.', '').gsub('0', '')
      cleaned_mac << mac unless check_mac == 'E'
    end

    mac_address = cleaned_mac
    mac_address.empty? ? [''] : mac_address

  puts "@mac_address2: #{mac_address}"
end
