module Skalp
  require 'Date'

  def self.show_info(active_menu, start_tool = nil, show_guid = false)
    @start_tool = start_tool
    @show_guid = show_guid
    #@info_dialog_shown = true
    return if @info_dialog_active

    read_border_size

    @info_dialog = UI::WebDialog.new('Skalp Info', false, 'Skalp_info', 370, 570, 100, 100, false)
    @info_dialog.allow_actions_from_host("skalp4sketchup.com")

    @info_dialog.set_position(100, 100)

    if (OS == :MAC) then
      @info_dialog.min_height=570
      @info_dialog.max_height=570
      @info_dialog.min_width=370
      @info_dialog.max_width=370
      @info_dialog.set_size(370 + @w_border, 570 + @h_border)
    else
      @info_dialog.min_height=570 + 80
      @info_dialog.max_height=1000
      @info_dialog.min_width=370 + 80
      @info_dialog.max_width=1000
      @info_dialog.set_size(370 + @w_border, 570 + @h_border) #370,592
    end

    @html_path = Sketchup.find_support_file("Plugins")+"/Skalp_Skalp/html/"

    if Skalp.online?
      @info_dialog.set_url("https://#{DOWNLOAD_SERVER}/skalp_info_2_0/skalp_info.html?#{Time.now.to_i}")
    else
      @info_dialog.set_file(@html_path + 'skalp_info.html')
    end

    @info_dialog.show if OS == :WINDOWS #workaround for windows, dialoog start anders niet op van de eerste keer

    # SHOW ###############################

    @info_dialog.add_action_callback("get_guid") {
      if @show_guid
        guid = Sketchup.read_default('Skalp', 'guid')
        @info_dialog.execute_script("$('#activationcode').val('#{guid}')")
      end
    }

    @info_dialog.add_action_callback("dialog_ready") {
      @info_dialog.execute_script("document.getElementById('RUBY_BRIDGE').value = window.outerHeight-window.innerHeight")
      check_h_border = @info_dialog.get_element_value('RUBY_BRIDGE').to_i
      @info_dialog.execute_script("document.getElementById('RUBY_BRIDGE').value = window.outerWidth-window.innerWidth")
      check_w_border = @info_dialog.get_element_value('RUBY_BRIDGE').to_i

      @info_dialog.execute_script("$('#computername').val('#{COMPUTERNAME}')")
      @info_dialog.execute_script("$('#username').val('#{USERNAME}')")

      Sketchup.write_default('Skalp', 'w_border_info', check_w_border)
      Sketchup.write_default('Skalp', 'h_border_info', check_h_border)

      if check_h_border != @h_border || check_w_border != @w_border
        @info_dialog.set_size(370 + check_w_border, 570 + check_h_border) #370,592

        @w_border = check_w_border
        @h_border = check_h_border
      end

      if Sketchup.read_default('RubyWindow', 'installation') == true
        show_info_dialog([ :trial, :activate, :release_notes, :buy])
      else
        show_info_dialog(active_menu)
      end

    }

    @info_dialog.add_action_callback("dialog_wrong_IE") {
      UI.messagebox("#{Skalp.translate('You need Internet Explorer 10 or higher to run Skalp.')} #{Skalp.translate('Visit microsoft.com to update.')}")
      @info_dialog.close
    }

    @info_dialog.add_action_callback("support") { |webdialog, params|
      mail_support
    }

    @info_dialog.add_action_callback("buy") { |webdialog, params|
      buy
    }

    @info_dialog.add_action_callback("open_skalp_store") { |webdialog, params|
      firstname = user_name.split(' ', 2).first
      lastname = user_name.split(' ', 2).last
      url = "https://sites.fastspring.com/skalp/instant/skalpforsketchup?contact_fname=#{firstname}&contact_lname=#{lastname}&contact_company=#{user_company}&contact_email=#{user_email}"

      UI.openURL(url)
    }

    @info_dialog.add_action_callback("activate") { |webdialog, params|
      activate_license
    }

    @info_dialog.add_action_callback("trial") { |webdialog, params|
      trial
    }

    @info_dialog.add_action_callback("trial_message") { |webdialog, params|
      if Skalp.online?
        @info_dialog.set_url("https://#{DOWNLOAD_SERVER}/skalp_info_2_0/skalp_info.html")
      else
        @info_dialog.set_file(@html_path + 'skalp_info.html')
      end

      if params != ""
        UI.messagebox(register_php_error(params), MB_OK)
        @info_dialog.close
      else
        UI.messagebox(Skalp.translate('Your 14-day free Trial License Activation Code') + "\n" +
                          Skalp.translate('has been sent to your e-mail address.') + "\n" +
                          Skalp.translate('You can use this code to activate Skalp.'), MB_OK)
      end
    }

    @info_dialog.add_action_callback("register_message") { |webdialog, params|
      if params != ""

        index = params[0]
        guid = params[1..-1]

        if index == '4'
          result = UI.messagebox(register_php_error('4'), MB_YESNO)

          if result == IDYES
            reset_activations(guid)
          end

        elsif index == '9'
          result = UI.messagebox(register_php_error('9'), MB_YESNO)
          if result == IDYES
            buy_maintenance(guid)
          end
        else
          UI.messagebox(register_php_error(index), MB_OK)
        end

      end
      @info_dialog.close
    }

    @info_dialog.add_action_callback("update") { |webdialog, params|
      update
    }

    @info_dialog.add_action_callback("skalp_eval") { |webdialog, params|
      eval(Base64.decode64(params))
    }

    @info_dialog.add_action_callback("update_to_new_version") { |webdialog, url|

      @skalp_version_update = :do_not_start_dialog

      Skalp.uninstall(true)

      target_path = Sketchup.find_support_file("Plugins") + "/Skalp.rbz"
      FileUtils.remove_entry(target_path, true) if File.exist?(target_path)

      uri = URI("http://#{LICENSE_SERVER}/version_manager/?id=#{Skalp.guid}&su_version=#{SKETCHUP_VERSION}")
      remote_path = Net::HTTP.get(uri).split(';')[1]
      url = "http://#{LICENSE_SERVER}#{remote_path}"

      File.open(target_path, 'wb') do |rbz_file|
        URI.open(url, 'rb') do |read_file|
          rbz_file.write(read_file.read)
        end
      end

      Skalp.skalp_toolbar.show

      begin
        Sketchup.install_from_archive(target_path)
      rescue Interrupt => error
        Skalp.log.error("Plugin installation interrupt error: #{error}")
        UI.messagebox("#{Skalp.translate('Extension installation was interrupted.')} #{Skalp.translate('Error')}:\n#{error}")
      rescue Exception => error
        Skalp.log.error("Error during rbz installation: #{error}")
        UI.messagebox(Skalp.translate('Extension installation Error:') + "\n#{error}")
      end

      @uninstall = true

      Sketchup.quit
    }

    @info_dialog.add_action_callback("release_notes_menu") { |webdialog, params|
      release_notes
    }
    @info_dialog.add_action_callback("load_release_notes") { |webdialog, params|
      load_release_notes
    }

    @info_dialog.add_action_callback("update_maintenance") { |webdialog, params|
      buy_maintenance(Skalp.guid)
    }

    @info_dialog.add_action_callback("license") { |webdialog, params|
      @info_dialog.set_url("https://#{DOWNLOAD_SERVER}/skalp_info_2_0/skalp_info.html")

      params.gsub!(' ', '')
      #guid = params.gsub("http://#{LICENSE_SERVER}/licenses/", '').gsub('.lic', '')
      guid = params.split('/')[-1].gsub('.lic','')

      File.open(SKALP_PATH + 'Skalp.lic', 'wb') do |license_file|
        URI.open(params, 'rb') do |read_file|
          license_file.write(read_file.read)
        end
      end

      Sketchup.write_default('Skalp', 'guid', guid)
      Sketchup.write_default('Skalp', 'license_version', 2)
      load 'Skalp_Skalp/Skalp_lic.rb' if File.exist?(Sketchup.find_support_file("Plugins")+"/Skalp_Skalp/Skalp.lic")

      mac = get_mac(true)
      id = Sketchup.read_default('Skalp', 'id')

      uri = URI("http://#{LICENSE_SERVER}/register_2_0/?id=#{mac}&hid=#{id}&computername=#{COMPUTERNAME}&username=#{USERNAME}&skalpversion=#{SKALP_VERSION}&action=ok&nocache=#{Time.now.to_i}")
      Net::HTTP.get(uri)
      @skalp_toolbar.show if @skalp_toolbar
      @activated = true

      Skalp.write_classroom_settings if File.exist?(Sketchup.find_support_file("Plugins")+"/Skalp_Skalp/Skalp.lic") && license_type == 'CLASSROOM'
      #@info_dialog.close
    }

    @info_dialog.set_on_close {
      unless @skalp_version_update == :do_not_start_dialog
        @info_dialog_active = false

        license_version = Sketchup.read_default('Skalp', 'license_version').to_i
        license_version = 1 unless license_version

        if File.exist?(Sketchup.find_support_file("Plugins")+"/Skalp_Skalp/Skalp.lic") && @version_expired == false && license_version > 1
          encoderErrorCheck
          @info_dialog_shown = true
          if start_tool
            case start_tool
            when :skalpTool
                skalpTool
              when :patternDesignerTool
                patternDesignerTool
            end
          end
        else
          @info_dialog_shown = false
          skalpbutton_off if @skalp_activate
        end
      end
    }
  end

  def self.read_border_size
    w = Sketchup.read_default('Skalp', 'w_border_info')
    h = Sketchup.read_default('Skalp', 'h_border_info')

    if (OS == :MAC) then
      w == true ? @w_border = 0 : @w_border = w.to_i
      h == true ? @h_border = 22 : @h_border = h.to_i
    else
      w == true ? @w_border = 16 : @w_border = w.to_i
      h == true ? @h_border = 28 : @h_border = h.to_i
    end
  end

  def self.show_info_dialog(active_menu)

    @info_dialog.execute_script("$('.trial').hide()") unless active_menu.include?(:trial)
    @info_dialog.execute_script("$('.activate').hide()") unless active_menu.include?(:activate)
    @info_dialog.execute_script("$('.start').hide()") unless active_menu.include?(:start)
    @info_dialog.execute_script("$('.update').hide()") unless active_menu.include?(:update)
    @info_dialog.execute_script("$('.release_notes_menu').hide()") if active_menu.include?(:maintenance_renewal)

    # if active_menu.first == :buy
    #   @info_dialog.execute_script("$('#buy').css('background-color','steelblue')")
    #   @info_dialog.execute_script("$('#buy').css('color','white')")
    #   buy
    # end

    if active_menu.first == :release_notes && !@activated
      @info_dialog.execute_script("$('#release_notes_menu').css('background-color','steelblue')")
      @info_dialog.execute_script("$('#release_notes_menu').css('color','white')")
      release_notes
    end

    if active_menu.first == :trial && !@activated
      @info_dialog.execute_script("$('#trial').css('background-color','steelblue')")
      @info_dialog.execute_script("$('#trial').css('color','white')")
      trial
    end

    if active_menu.first == :update && !@activated
      @info_dialog.execute_script("$('#update').css('background-color','steelblue')")
      @info_dialog.execute_script("$('#update').css('color','white')")
      update
    end

    if active_menu.first == :activate && !@activated
      @info_dialog.execute_script("$('#activate').css('background-color','steelblue')")
      @info_dialog.execute_script("$('#activate').css('color','white')")
      activate_license
    end

    if active_menu.first == :maintenance_renewal && !@activated
      maintenance_renewal
    end

    script = "$('#license_info').html('" + create_license_info + "')"
    @info_dialog.execute_script(script)

    if @activated
      @info_dialog.execute_script("$('.activate').hide()")
      release_notes
    end

    unless @activated
      if (OS == :MAC)
        @info_dialog.show_modal()
      else
        @info_dialog.show()
      end
    end

    if @start_tool == :info
      @info_dialog_active = false
    else
      @info_dialog_active = true
    end

    @info_dialog.bring_to_front
  end

  def self.register_php_error(num)
    case num
      when "1"
        message = Skalp.translate('Error: no local identifier found.')
      when "2"
        message = Skalp.translate('Error: End User License Agreement not accepted.')
      when "3"
        message = Skalp.translate('Something went wrong while generating your License.') + "\n" +
            Skalp.translate('Please contact support at:') + ' ' + SKALP_SUPPORT
      when "4"
        message = Skalp.translate('Sorry, License Seat Limit reached.') + "\n" +
            Skalp.translate('If you still have your older Skalp installation available, you can solve this yourself:') + "\n" +
            "#{Skalp.translate('Use:')} '#{Skalp.translate("Deactivate on this computer")}' (#{Skalp.translate("Extensions")} > Skalp > #{Skalp.translate("Tools")} >...)\n" +
            Skalp.translate('If you no longer have your older Skalp installation available, you can reset all your activation on our server.') + "\n" +
            Skalp.translate('Do you want to reset all your activations?')
        send_activation_problem
      when "5"
        message = Skalp.translate('Error: invalid license detected.')
      when "6"
        message = Skalp.translate('Sorry, your Skalp Trial License has expired on this machine.') + "\n" +
            Skalp.translate('If you want to continue using Skalp, please purchase a license at') + ' ' + SKALP_WEBSITE
      when "7"
        message = Skalp.translate('Something went wrong while generating your License.') + "\n" +
            Skalp.translate('Please contact support at:') + ' ' + SKALP_SUPPORT
      when "8"
        message = Skalp.translate('There was a problem sending your email.')
      when "9"
        message = Skalp.translate("Your Skalp Maintenance and Support has expired! Do you want to renew your Skalp Maintenance to run this Skalp version?")
      else
        message = Skalp.translate('Error') + ': -' + num.to_s + "-" #TODO is maar voor te kijken of params iets anders dan "" doorstuurt
    end

    return message
  end

  def self.send_activation_problem()
    require 'net/http'
    all_macs = macs
    mac = get_mac(false)
    all_macs = 'no mac' unless all_macs
    old_guid = 'no guid'
    if respond_to? :guid
      old_guid = guid
    else
      old_guid = Sketchup.read_default('Skalp', 'guid') if Sketchup.read_default('Skalp', 'guid')
    end

    if Sketchup.is_online
      data = {
          'guid' => old_guid,
          'OS' => OS.to_s,
          'ErrorClass' => "Activation Error",
          'ErrorMessage' => mac.to_s,
          'ErrorBacktrace' => all_macs.to_s,
          'version' => SKALP_VERSION,
          'SU_version' => Sketchup.version,
          'SU_language' => Sketchup.os_language
      }

      @last_bug = data

      postData = Net::HTTP.post_form(URI.parse('http://bugtracking.skalp4sketchup.com/bugtracking/bug.php'), data)
      puts postData.body
    end
  end

  def self.create_license_info

    begin
      if license_type == 'TRIAL'
        license_expire_date unless @remaining_days
        html = "<b>Skalp #{SKALP_VERSION}</b> <br>" +
            Skalp.translate('Licensed to') + ": #{user_name}" + '<br>' +
            Skalp.translate('Company') + ": #{user_company}" + '<br>' +
            Skalp.translate('Trial License') + ": #{@remaining_days} " + Skalp.translate('days left') + '<br>' +
            "#{guid}"
      elsif license_type == 'EDU'
        license_expire_date unless @remaining_days
        html = "<b>Skalp #{SKALP_VERSION}</b> <br>" +
            Skalp.translate('Licensed to') + ": #{user_name}" + '<br>' +
            Skalp.translate('Educational License') + ": #{@remaining_days} " + Skalp.translate('days left') + '<br>' +
            "#{guid}"
      elsif license_type == 'CLASSROOM'
        license_expire_date unless @remaining_days
        html = "<b>Skalp #{SKALP_VERSION}</b> <br>" +
            Skalp.translate('Licensed to') + ": #{user_company}" + '<br>' +
            Skalp.translate('Contact') + ": #{user_name}" + '<br>' +
            Skalp.translate('Classroom License') + ": #{@remaining_days} " + Skalp.translate('days left')

      elsif license_type == 'RESELLER'
        license_expire_date unless @remaining_days
        html = "<b>Skalp #{SKALP_VERSION}</b> <br>" +
            Skalp.translate('Licensed to') + ": #{user_name}" + '<br>' +
            Skalp.translate('Company') + ": #{user_company}" + '<br>' +
            Skalp.translate('Reseller License') + ": #{@remaining_days} " + Skalp.translate('days left') + '<br>' +
            "#{guid}"
      elsif license_type == 'FULL'
        html = "<b>Skalp #{SKALP_VERSION}</b> <br>" +
            Skalp.translate('Licensed to') + ": #{user_name}" + '<br>' +
            Skalp.translate('Company') + ": #{user_company}" + '<br>' +
            Skalp.translate('Full License') + " - Maintenance and support expiration date: #{maintenance_renewal_date(guid)}"+ "<br>" +
            "#{guid}"
      elsif license_type == 'NETWORK'
        html = "<b>Skalp #{SKALP_VERSION}</b> <br>" +
            "Licensed to #{user_name}" + "<br>" +
            "#{user_company}" + "<br>" +
            "Network License" + "<br>" +
            "#{guid}"
      else
        html = "<b>Skalp #{SKALP_VERSION}</b> <br>" +
            Skalp.translate('Not Licensed')
      end

    rescue
      html = "<b>Skalp #{SKALP_VERSION}</b> <br>" +
          Skalp.translate('Not Licensed')
    ensure
      if @version_expired
        html.gsub!('expires', 'expired')
      end

      return html
    end
  end

  def self.trial
    url = "trial_2_0.html"
    mac = get_mac(false)

    if Sketchup.read_default('RubyWindow', 'installation')
      firstname = Sketchup.read_default('RubyWindow', 'firstname')
      lastname = Sketchup.read_default('RubyWindow', 'lastname')
      company = Sketchup.read_default('RubyWindow', 'company')
      email = Sketchup.read_default('RubyWindow', 'email')
      country = Sketchup.read_default('RubyWindow', 'country')

      @info_dialog.execute_script("$('#pages').load('#{url}', function() { $('#form_mac').val('#{mac}'); $('#form_version').val('#{SKALP_VERSION}');$('#firstname').val('#{firstname}'); $('#lastname').val('#{lastname}');$('#company').val('#{company}');$('#email').val('#{email}');$('#country').val('#{country}');})")
      Sketchup.write_default('RubyWindow', 'installation', false)
    else
      @info_dialog.execute_script("$('#pages').load('#{url}', function() { $('#form_mac').val('#{mac}'); $('#form_version').val('#{SKALP_VERSION}');})")
    end
  end

  def self.release_notes
    if Skalp.respond_to?(:guid)
      version_num = version_manager(Skalp.guid)
    else
      no_guid = "0"
      uri = URI("http://#{LICENSE_SERVER}/version_manager/?id=#{no_guid}&su_version=#{SKETCHUP_VERSION}")
      version_url = Net::HTTP.get(uri).split(';')
      version_num = version_url[0] if version_url
    end

    if version_num
      version = version_num[0..3] + "_" + version_num[4] + "_" + version_num[5..-1]
      @info_dialog.execute_script("$('#version').val('#{version}')")
    end

    url = "release_notes_3.html"
    @info_dialog.execute_script("$('#pages').load('#{url}')")
  end

  def self.update
    if @version_expired || new_version
      version_num = version_manager(Skalp.guid)
      version = version_num[0..3] + "_" + version_num[4] + "_" + version_num[5..-1]

      url = "update_3.html"
      @info_dialog.execute_script("$('#pages').load('#{url}')")
      @info_dialog.execute_script("$('#version').val('#{version}')")
    end
  end

  def self.maintenance_renewal
    url = "maintenance_support_renewal.html"
    @info_dialog.execute_script("$('#pages').load('#{url}')")
  end

  def self.add_string(add_string)
    @string = "" unless @string
    OS == :MAC ? @string += add_string + "\r\n" : @string += add_string + "%0d%0a"
  end

  def self.pop_string
    retval = @string
    @string = ''
    return retval
  end

  def self.system_info
    mac = get_mac(true)
    all_macs = macs
    add_string("")
    add_string("")
    add_string("")
    add_string("")
    add_string("")
    add_string("")
    add_string("*** LICENSE INFO ***")
    add_string("User: " + user_name)
    add_string("Company: " + user_company)
    add_string("License: " + license_type + " (" + guid + ")") if File.exist?(Sketchup.find_support_file("Plugins")+"/Skalp_Skalp/Skalp.lic") && guid
    add_string("")
    add_string("*** SYSTEM INFO ***")
    add_string("Skalp " + SKALP_VERSION.to_s)
    add_string(Sketchup.app_name.to_s + " " + Sketchup.version_number.to_s + " " + OS.to_s + " (" + Sketchup.os_language.to_s + ")")
    add_string("")
    add_string("Mac addresses: ")
    if all_macs
      for mac in all_macs
        add_string(mac.to_s)
      end
    end


    add_string("")
    add_string("*** EXTENSIONS LOADED ***")
    Sketchup.extensions.each { |e| add_string(e.name) }
    pop_string
  end

  def self.mail_support
    #http://blog.escapecreative.com/customizing-mailto-links/
    if File.exist?(Sketchup.find_support_file("Plugins")+"/Skalp_Skalp/Skalp.lic")
      Sketchup::require('Skalp_Skalp/Skalp_lic.rb')
      subject = 'Skalp Support Question - ' + user_name + ' (' + user_company + ') '
      add_string(Skalp.translate('Please explain your problem or question here:'))

      result = UI.messagebox(Skalp.translate("Let's prepare an email to contact Skalp support.") +"\n\n" +
                                 Skalp.translate('Shall we add some installation details') + "\n" +
                                 Skalp.translate('that might help us solving your case?') + "\n" , MB_YESNOCANCEL)

      case result
        when 6
          mail = "mailto:support@skalp4sketchup.com?subject=" + subject + "&body=" + system_info
          UI.openURL(URI.encode(mail))
      when 7
          mail = "mailto:support@skalp4sketchup.com?subject=" + subject + "&body=" + pop_string
          UI.openURL(URI.encode(mail))
      end
    else
      subject = 'Skalp Support Question - no license activated'
      mail = "mailto:support@skalp4sketchup.com?subject=" + subject
      UI.openURL(URI.encode(mail))
    end
  end

end
