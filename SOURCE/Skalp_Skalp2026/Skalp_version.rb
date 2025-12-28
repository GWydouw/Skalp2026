module Skalp
  def self.expire_date
    RGLoader::get_const("SKALP_EXPIRE")
  end
end