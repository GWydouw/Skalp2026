module Skalp
  require "Sketchup"
  require "fileutils"

  PLUGIN_PATH = Sketchup.find_support_file("Plugins")

  def self.maintenance_renewal_date(guid)
    return "" unless Sketchup.is_online

    uri = URI("http://#{LICENSE_SERVER}/maintenance/maintenance_renewal_date.php?id=#{guid}")
    Net::HTTP.get(uri)
  end

  def self.maintenance_check(version = SKALP_VERSION.gsub(".", "").to_i, id = Skalp.guid)
    return true unless Sketchup.is_online

    uri = URI("http://#{LICENSE_SERVER}/maintenance/maintenance.php?id=#{id}&version=#{version}")
    check = Net::HTTP.get(uri)

    maintenance_expired = "Your Skalp Maintenance and Support has expired! Do you want to renew your Skalp Maintenance to run this Skalp version?"
    if check == "1"
      true
    elsif check == "0"
      result = UI.messagebox(maintenance_expired, MB_YESNO)
      buy_maintenance(Skalp.guid) if result == IDYES
      false
    elsif check == "-1"
      result = UI.messagebox(maintenance_expired, MB_YESNO)
      buy_maintenance(Skalp.guid) if result == IDYES
      false
    else
      false
    end
  rescue StandardError
    true
  end

  def self.buy_maintenance(guid)
    uri = URI("http://#{LICENSE_SERVER}/maintenance/seats.php?id=#{guid}")
    seats = Net::HTTP.get(uri).to_i

    # TODO: choose the correct product for number of seats
    case seats <=> 1
      # zero seats available
    when -1
      UI.messagebox("#{Skalp.translate('Zero seats available on your license. Please contact Skalp support.')}",
                    MB_OK)

      # single seat license
    when 0
      UI.openURL("https://sites.fastspring.com/Skalp_Skalp2026/product/buy_maintenance?referrer=#{guid}")

      # multi seat license
    when 1
      UI.openURL("https://sites.fastspring.com/Skalp_Skalp2026/product/buy_maintenance_plus?referrer=#{guid}")
    else
      # error handling
    end
  rescue StandardError
    UI.messagebox("You need an internet connection to buy Maintenance.")
  end

  def self.version_manager(guid)
    uri = URI("http://#{LICENSE_SERVER}/version_manager/?id=#{guid}&su_version=#{SKETCHUP_VERSION}")
    version_url = Net::HTTP.get(uri).split(";")
    version_url[0]
  end

  def self.new_version
    @uninstall = false
    update_needed = false
    if Sketchup.is_online
      your_version = SKALP_VERSION.gsub(".", "").gsub("_beta", "").to_i
      version = last_version

      if version.to_i == 1
        Sketchup.write_default("Skalp", "uptodate", true)

        uri = URI("http://#{LICENSE_SERVER}/version_manager/?id=#{Skalp.guid}&su_version=#{SKETCHUP_VERSION}")
        version_url = Net::HTTP.get(uri).split(";")
        newest_version = version_url[0].to_i

        update_needed = true if your_version < newest_version
      elsif version.to_i == 2
        if File.exist?(Sketchup.find_support_file("Plugins") + "/Skalp_Skalp2026/Skalp.lic")
          FileUtils.remove_entry(Sketchup.find_support_file("Plugins") + "/Skalp_Skalp2026/Skalp.lic",
                                 true)
        end
        Sketchup.write_default("Skalp", "uptodate", false)
        message1
      elsif version.to_i == 0
        Sketchup.write_default("Skalp", "uptodate", false)
        message1
      elsif version.to_i == -1
        if File.exist?(Sketchup.find_support_file("Plugins") + "/Skalp_Skalp2026/Skalp.lic")
          FileUtils.remove_entry(Sketchup.find_support_file("Plugins") + "/Skalp_Skalp2026/Skalp.lic",
                                 true)
        end
        Sketchup.write_default("Skalp", "uptodate", false)
        message1
      else
        Sketchup.write_default("Skalp", "uptodate", true)
      end
    end
    update_needed
  rescue StandardError
    false
  end

  def self.last_version
    id = Sketchup.read_default("Skalp", "id")
    uri = URI("http://#{LICENSE_SERVER}/versioncheck_3_0/?id=#{Skalp.guid}&hid=#{id}&version=#{SKALP_VERSION}&locale=#{Sketchup.get_locale}&su_version=#{SKETCHUP_VERSION}")
    Net::HTTP.get(uri)
  rescue StandardError
    "1"
  end

  def self.deactivate
    unless File.exist?(Sketchup.find_support_file("Plugins") + "/Skalp_Skalp2026/Skalp.lic")
      UI.messagebox("#{Skalp.translate('Skalp is already deactivated on this computer.')}", MB_OK)
      return
    end

    Sketchup.require("Skalp_Skalp2026/Skalp_lic.rb")

    if license_type == "TRIAL"
      UI.messagebox("#{Skalp.translate("You can't deactivate a Skalp trial License.")}")
      return
    end

    guid = Sketchup.read_default("Skalp", "guid")

    deactivate_text =
      Skalp.translate("Are you sure you want to deactivate your Skalp License on this computer?") + "\n\n" +
      Skalp.translate("You can (re)activate Skalp on another computer using your License Activation Code:") + "\n\n" +
      "#{guid}\n\n"

    result = UI.messagebox(Skalp.translate(deactivate_text), MB_YESNO)
    return unless result == 6

    uri = URI("http://#{LICENSE_SERVER}/register_2_0/deactivate.php?mac=#{get_activation_mac}&guid=#{guid}")
    if Net::HTTP.get(uri)
      stop_skalp(true) if @status == 1
      remove_license
      Sketchup.write_default("Skalp", "guid", nil)
      Sketchup.write_default("Skalp", "id", nil)
      Sketchup.write_default("Skalp", "uptodate", nil)
      @skalp_toolbar.hide
    else
      UI.messagebox("#{Skalp.translate('Error deactivating License, please contact')} #{SKALP_SUPPORT}")
    end
  end

  def self.reset_activations(user_guid)
    require "net/http"

    remove_license
    Sketchup.write_default("Skalp", "guid", nil)
    Sketchup.write_default("Skalp", "id", nil)
    Sketchup.write_default("Skalp", "uptodate", nil)

    uri = URI("http://#{LICENSE_SERVER}/register_2_0/reset_activations.php?guid=#{user_guid}")
    Net::HTTP.get(uri)
  end

  def self.get_activation_mac
    id = Sketchup.read_default("Skalp", "id")

    for mac in macs
      return mac if mac2id(mac) == id
    end

    nil
  end

  def self.uninstall(update = false)
    @info_dialog.close if @info_dialog

    if update
      result = 6
    else
      result = UI.messagebox(Skalp.translate("Are you sure you want to uninstall Skalp?"), MB_YESNO)
      deactivate
      clean_registry
    end

    return false unless result == 6

    if @status == 1
      stop_skalp(true)
    elsif @skalp_toolbar
      @skalp_toolbar.hide
    end
    uninstall_status = 1

    # delete subdirs except resources
    FileUtils.remove_dir(PLUGIN_PATH + "/Skalp_Skalp2026/html", true)
    FileUtils.remove_dir(PLUGIN_PATH + "/Skalp_Skalp2026/chunky_png", true)

    # delete resources/strings
    FileUtils.remove_dir(PLUGIN_PATH + "/Skalp_Skalp2026/resources/strings", true)

    # delete files
    FileUtils.remove_entry(PLUGIN_PATH + "/Skalp_Skalp2026/LICENSE.txt", true)
    FileUtils.remove_entry(PLUGIN_PATH + "/Skalp_Skalp2026/Skalp_geom.rbs", true)
    FileUtils.remove_entry(PLUGIN_PATH + "/Skalp_Skalp2026/Skalp_geom.rb", true)
    FileUtils.remove_entry(PLUGIN_PATH + "/Skalp_Skalp2026/Skalp_log.txt", true)
    FileUtils.remove_entry(PLUGIN_PATH + "/Skalp_Skalp2026/Skalp_lib.rbs", true)
    FileUtils.remove_entry(PLUGIN_PATH + "/Skalp_Skalp2026/Skalp_geom2.rb", true)
    FileUtils.remove_entry(PLUGIN_PATH + "/Skalp_Skalp2026/Skalp_lib2.rb", true)
    FileUtils.remove_entry(PLUGIN_PATH + "/Skalp_Skalp2026/Skalp_loader.rb", true)
    FileUtils.remove_entry(PLUGIN_PATH + "/Skalp_Skalp2026/Skalp_observers.rb", true)
    FileUtils.remove_entry(PLUGIN_PATH + "/Skalp_Skalp2026/Skalp_preferences.rb", true)
    FileUtils.remove_entry(PLUGIN_PATH + "/Skalp_Skalp2026/Skalp_update.rb", true)
    FileUtils.remove_entry(PLUGIN_PATH + "/Skalp_Skalp2026/Skalp_translator.rb", true)
    FileUtils.remove_entry(PLUGIN_PATH + "/Skalp_Skalp2026/Skalp_version.rb", true)
    FileUtils.remove_entry(PLUGIN_PATH + "/Skalp_Skalp2026/Skalp_UI.rb", true)
    FileUtils.remove_entry(PLUGIN_PATH + "/Skalp_Skalp2026/Skalp_isolate.rbs", true)
    FileUtils.remove_entry(PLUGIN_PATH + "/Skalp_Skalp2026/Skalp_info.rb", true)
    FileUtils.remove_entry(PLUGIN_PATH + "/Skalp_Skalp2026/Skalp_lib.rb", true)
    FileUtils.remove_entry(PLUGIN_PATH + "/Skalp_Skalp2026/Skalp_lic.rb", true)
    FileUtils.remove_entry(PLUGIN_PATH + "/Skalp_Skalp2026/Skalp_Skalp2026.hash", true)

    # delete Skalp.rb
    FileUtils.remove_entry(PLUGIN_PATH + "/Skalp_Skalp2026.rb", true)

    uninstall_status = 2

    # delete C-extensions
    # FileUtils.remove_dir(PLUGIN_PATH + '/Skalp_Skalp2026/rgloader_old', true)
    # FileUtils.mv(PLUGIN_PATH + '/Skalp_Skalp2026/rgloader', PLUGIN_PATH + '/Skalp_Skalp2026/rgloader_old')
    #
    # FileUtils.remove_entry(PLUGIN_PATH + '/Skalp_Skalp2026/SkalpC_old.bundle',true) if File.exist?(PLUGIN_PATH + '/Skalp_Skalp2026/SkalpC_old.bundle')
    # FileUtils.remove_entry(PLUGIN_PATH + '/Skalp_Skalp2026/SkalpC_old.so',true) if File.exist?(PLUGIN_PATH + '/Skalp_Skalp2026/SkalpC_old.so')
    #
    # File.rename(PLUGIN_PATH + '/Skalp_Skalp2026/SkalpC.bundle', PLUGIN_PATH + '/Skalp_Skalp2026/SkalpC_old.bundle' )
    # File.rename(PLUGIN_PATH + '/Skalp_Skalp2026/SkalpC.so', PLUGIN_PATH + '/Skalp_Skalp2026/SkalpC_old.so' )
    true
  rescue StandardError
    if uninstall_status < 2
      UI.messagebox(
        "#{Skalp.translate('Sorry, automatic uninstall failed.')} #{Skalp.translate('Please uninstall Skalp manually.')}", MB_OK
      )
    end
    false
  end

  private

  def self.clean_registry
    Sketchup.write_default("Skalp", "guid", nil)
    Sketchup.write_default("Skalp", "id", nil)
    Sketchup.write_default("Skalp", "uptodate", nil)
    Sketchup.write_default("Skalp", "encoderError", nil)
    Sketchup.write_default("Skalp", "tolerance", nil)
    Sketchup.write_default("Skalp", "drawing_scale", nil)
    Sketchup.write_default("Skalp", "license_version", nil)

    # layer dialog
    Sketchup.write_default("Skalp", "Layers dialog - width", nil)
    Sketchup.write_default("Skalp", "Layers dialog - height", nil)
    Sketchup.write_default("Skalp", "Layers dialog - x", nil)
    Sketchup.write_default("Skalp", "Layers dialog - y", nil)

    # export
    Sketchup.write_default("Skalp_export", "section_layer", nil)
    Sketchup.write_default("Skalp_export", "section_suffix", nil)
    Sketchup.write_default("Skalp_export", "fill_suffix", nil)
    Sketchup.write_default("Skalp_export", "hatch_suffix", nil)
    Sketchup.write_default("Skalp_export", "forward_layer", nil)
    Sketchup.write_default("Skalp_export", "forward_suffix", nil)
    Sketchup.write_default("Skalp_export", "forward_color", nil)
    Sketchup.write_default("Skalp_export", "rear_layer", nil)
    Sketchup.write_default("Skalp_export", "rear_suffix", nil)
    Sketchup.write_default("Skalp_export", "rear_color", nil)
    Sketchup.write_default("Skalp_export", "fileformat", nil)
    Sketchup.write_default("Skalp_export", "where", nil)
  end
end
