module Skalp
  def self.guid
    val = begin
      RGLoader.get_const("GUID")
    rescue StandardError
      nil
    end
    val || Sketchup.read_default("Skalp", "guid") || "DEV_GUID_12345"
  end

  def self.license_type # FULL / TRIAL / EDU
    val = begin
      (File.exist?(Sketchup.find_support_file("Plugins") + "/Skalp_Skalp2026/Skalp.lic") ? RGLoader.get_const("LICENSE_TYPE") : nil)
    rescue StandardError
      nil
    end
    val || "FULL"
  end

  def self.trial_expire_date
    val = begin
      RGLoader.get_const("SKALP_TRIAL_EXPIRE")
    rescue StandardError
      nil
    end
    val || (Time.now + (30 * 24 * 60 * 60)).strftime("%m/%d/%Y")
  end

  def self.user_email
    val = begin
      RGLoader.get_const("EMAIL")
    rescue StandardError
      nil
    end
    val || "dev@skalp.com"
  end

  def self.user_name
    val = begin
      RGLoader.get_const("USERNAME")
    rescue StandardError
      nil
    end
    val || "Dev User"
  end

  def self.user_company
    val = begin
      RGLoader.get_const("COMPANY")
    rescue StandardError
      nil
    end
    val || "Skalp Dev Mode"
  end

  def self.encoder
    RGLoader.get_const("encoder")
  rescue StandardError
    "DevEncoder"
  end

  def self.loader_version
    RGLoader.get_const("version")
  rescue StandardError
    "3.2"
  end

  def self.encoder_date
    RGLoader.get_const("encode_date")
  rescue StandardError
    Time.now.to_s
  end

  def self.license_date
    val = begin
      (File.exist?(Sketchup.find_support_file("Plugins") + "/Skalp_Skalp2026/Skalp.lic") ? RGLoader.get_const("license_date") : nil)
    rescue StandardError
      nil
    end
    val || Time.now.to_s
  end

  def self.expire_date
    val = begin
      (File.exist?(Sketchup.find_support_file("Plugins") + "/Skalp_Skalp2026/Skalp.lic") ? RGLoader.get_const("expire_date") : nil)
    rescue StandardError
      nil
    end
    val || (Time.now + (365 * 24 * 60 * 60)).to_s
  end
end
