module Skalp
  require 'open-uri'
  require 'net/http'
  require 'base64'

  def self.online?(message=false)
    if Sketchup.is_online
      return true
    else
      UI.messagebox('You need an internet connection to activate Skalp', MB_OK) if message
      return false
    end
  end

  def self.activate_license

    Sketchup.write_default('Skalp', 'uptodate', true) if Sketchup.read_default('Skalp', 'uptodate') == '' || Sketchup.read_default('Skalp', 'uptodate') == nil
    begin
      id = Sketchup.read_default('Skalp', 'id')
      if id then
        mac = get_activation_mac
        unless mac
          mac = get_mac(true)
          id = Sketchup.read_default('Skalp', 'id')
        end
      else
        mac = get_mac(true)
        id = Sketchup.read_default('Skalp', 'id')
      end

      unless mac && mac.size == 17
        UI.messagebox("Error: Can't find a correct MAC address. Please contact Skalp support.")
      end

      url = URI::DEFAULT_PARSER.escape("../register_2_0/?id=#{mac}&hid=#{id}&skalpversion=#{SKALP_VERSION}&computername=#{COMPUTERNAME}&username=#{USERNAME}&action=ok&nocache=#{Time.now.to_i}")

      @info_dialog.execute_script("$('#pages').load('#{url}')")
    end if online?(true)
  end

  def self.write_license(lic_url)

    lic_url.gsub!(' ', '')
    guid = lic_url.gsub("http://#{LICENSE_SERVER}/licenses/", '').gsub('.lic', '')

    File.open(SKALP_PATH + 'Skalp.lic', 'wb') do |license_file|
      open(lic_url, 'rb') do |read_file|
        license_file.write(read_file.read)
      end
    end

    Sketchup.write_default('Skalp', 'license_version', 2)
    load 'Skalp_Skalp/Skalp_lic.rb' if File.exist?(Sketchup.find_support_file("Plugins")+"/Skalp_Skalp/Skalp.lic")

    mac = get_mac(true)
    id = Sketchup.read_default('Skalp', 'id')
    uri = URI("http://#{LICENSE_SERVER}/register_2_0/?id=#{mac}&hid=#{id}&computername=#{COMPUTERNAME}&username=#{USERNAME}&skalpversion=#{SKALP_VERSION}&action=ok&nocache=#{Time.now.to_i}")
    Net::HTTP.get(uri)

    Sketchup.write_default('Skalp', 'uptodate', true)
    @activated = true
  end

  def self.login_network
    uri = URI("http://#{LICENSE_SERVER}/register_2_0/register.php")
    id = Sketchup.read_default('Skalp', 'id')
    result = Net::HTTP.post_form(uri, 'activationcode' => "#{Sketchup.read_default('Skalp', 'guid')}", 'eula_accepted' => '1', 'localId' => "#{get_activation_mac}", 'hId' => "#{id}", 'type' => 'floating')

    if result
      write_license(result.body)
    else
      UI.messagebox("#{Skalp.translate('Error')} #{Skalp.translate('login network license')}, #{Skalp.translate('please contact')} support@skalp4sketchup.com")
    end
  end

  def self.check_license_type_on_server(guid)
    return 'offline' unless Sketchup.is_online
    uri = URI("http://#{LICENSE_SERVER}/register_2_0/check_license_type.php?guid=#{guid}")
    return Net::HTTP.get(uri)
  rescue
    # ignored
  end

  def self.translate64(string)
    Base64.decode64(string)
  end
end

