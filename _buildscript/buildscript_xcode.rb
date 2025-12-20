module Skalp_Buildscript
  def self.build_xcode
    clean_xcode

    Dir.chdir(@skalp_path + 'SUEX_Skalp/SkalpC/')

    output = `xcodebuild -target Ruby_2_5_x86_64`
    puts output

    puts "************* SkalpC BUILD FINISHED *************"

    FileUtils.rm_rf(@application_path + 'Build/Products/Release/LayOutAPI.framework')
    FileUtils.rm_rf(@application_path + 'Build/Products/Release/SketchUpAPI.framework')

    Dir.chdir(@application_path)
    output = `xcodebuild -target Skalp_external_application`
    puts output

    puts "************* Skalp External Application BUILD FINISHED *************"
  end

  def self.clean_xcode
    FileUtils.rm(File.join(@c_path, 'mac/SkalpC.bundle'), force:true)
  end
  def self.copy_xcode
    FileUtils.rm(File.join(@skalp_sketchup_path, 'SkalpC.bundle'), force:true)
    FileUtils.copy(File.join(@c_path, 'mac/SkalpC.bundle'), File.join(@skalp_sketchup_path, 'SkalpC.bundle'))
  end
end
