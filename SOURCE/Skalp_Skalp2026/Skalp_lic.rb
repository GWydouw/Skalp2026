module Skalp
  def self.guid
    RGLoader::get_const("GUID")
  end

  def self.license_type #FULL / TRIAL / EDU
    RGLoader::get_const("LICENSE_TYPE") if File.exist?(Sketchup.find_support_file("Plugins")+"/Skalp_Skalp2026/Skalp.lic")
  end

  def self.trial_expire_date
    RGLoader::get_const("SKALP_TRIAL_EXPIRE")
  end

  def self.user_email
    RGLoader::get_const("EMAIL")
  end

  def self.user_name
    RGLoader::get_const("USERNAME")
  end

  def self.user_company
    RGLoader::get_const("COMPANY")
  end

  def self.encoder
    RGLoader::get_const("encoder")
  end

  def self.loader_version
    RGLoader::get_const("version")
  end

  def self.encoder_date
    RGLoader::get_const("encode_date")
  end

  def self.license_date
    RGLoader::get_const("license_date") if File.exist?(Sketchup.find_support_file("Plugins")+"/Skalp_Skalp2026/Skalp.lic")
  end

  def self.expire_date
    RGLoader::get_const("expire_date") if File.exist?(Sketchup.find_support_file("Plugins")+"/Skalp_Skalp2026/Skalp.lic")
  end
end