#currently in development

def self.make_license_manually
  #to an from encoder
  guid = "test"
  email = "test@test.com"
  username = "Jeroen Theuns"
  company = "Tester"
  mac = "macadress"

  cmd = "./manual_licgen.sh \"#{guid}\" \"#{email}\" \"#{username}\" \"#{company}\" \"#{mac}\""   #need to implement arguments here
  retval = %x[#{cmd}]
  puts retval
end
make_license_manually

# clean out all skalp registry keys
def wipe_skalp
  Sketchup.write_default('Skalp','uptodate', nil)
  Sketchup.write_default('Skalp', 'id', nil) #hashmac, wordt gebruikt om bij originele activatie gebruikte mac op te zoeken (mac op zelfde toestel kan veranderen)
  Sketchup.write_default('Skalp', 'guid', nil)
  Sketchup.write_default("Skalp", "encoderError", nil)
  Sketchup.write_default('Skalp', 'trial', nil)
  Sketchup.write_default('Skalp', 'tolerance', nil)
  Sketchup.write_default('Skalp', 'drawing_scale', nil)
  Sketchup.write_default('Skalp','Layers dialog - width', nil)
  Sketchup.write_default('Skalp', 'license_version', nil)
end

