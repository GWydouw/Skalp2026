# #
# # @skalp_path =  ENV['SKALPDEV'] + '/'
# #
# # Dir.chdir(@skalp_path +"Skalp_external_application/")
# # output = `xcodebuild -target Skalp_external_application`
# # puts output
#
# # require "fileutils"
# #
# # puts File.exists?("/Users/guy/Dropbox/Guy/SourceTree_repo/Skalp/Skalp_external_applicaton/Build/Release/Skalp_external_application")
# #                   "/Users/guy/Dropbox/Guy/SourceTree_repo/Skalp/Skalp_external_application/Build/Release/LayOutAPI.framework"
#
# require "open3"
# require "fileutils"
#
# path = "/Users/guy/Library/Application Support/SketchUp 2016/SketchUp/Plugins/Skalp_Skalp/"
#
# #param1 = temp_dir
# #param2 = array_to_csv(layer_names, ';')
# #command = %Q(#{SKALP_PATH}Skalp_external_application "create_layer_materials" "#{param1}" "#{param2}")
#
# #puts command
#
# #command = %Q(/Users/guy/Library/Application Support/SketchUp 2016/SketchUp/Plugins/Skalp_Skalp/Skalp_external_application "create_layer_materials" "/Users/guy/Library/Application Support/SketchUp 2016/SketchUp/Plugins/Skalp_Skalp/Resources/temp/" "Skalp Pattern Layer - existing;Skalp Pattern Layer - facing brick;Skalp Pattern Layer - mansory;Skalp Pattern Layer - insulation;Skalp Pattern Layer - reinforced concrete;Skalp Pattern Layer - black;Skalp Pattern Layer - white;Skalp Pattern Layer - wood;Skalp Pattern Layer - screed;Skalp Pattern Layer - foamed concrete;Skalp Pattern Layer - prefab concrete;Skalp Pattern Layer - concrete blocks;Skalp Pattern Layer - natural stone;Skalp Pattern Layer - concrete;Skalp Pattern Layer - soil")
#
# #command = %Q(/Users/guy/Library/Application Support/SketchUp 2016/SketchUp/Plugins/Skalp_Skalp/Skalp_external_application)
# #command = %Q(/Users/guy/test/Skalp_external_application)
#
# temp_dir = path + "Resources/temp/"
# param1 = temp_dir
# param2 = "test1;test2;test3"
#
# #file =  "/Users/guy/Dropbox/Guy/SourceTree_repo/Skalp/Skalp_external_application/Build/Products/Debug/Skalp_external_application"
#
# file = "/Users/guy/test/Skalp_external_application"
# function = "create_layer_materials"
#
# puts "File exists: #{File.exists?(file)}"
#
# command = %Q(#{file} "#{function}" "#{param1}" "#{param2}")
#
#
# Open3.popen3(command) do |stdin, stdout, stderr|
#   puts "stout: #{stdout.read}"
#   puts "stin: #{stdin.read}"
#   puts "sterr: #{stderr.read}"
# end

require 'fileutils'
@skalp_path = ENV['SKALPDEV'] + '/'
@application_path = @skalp_path +"Skalp_external_application/"
@build_path = @skalp_path + "Buildversion/"

dir = File.join(@skalp_path, 'SketchUp frameworks/lib_mac/')

'/Users/guy/Dropbox/Guy/SourceTree_repo/Skalp/SketchUp\ frameworks/Iib_mac'


puts dir
puts Dir.exist?(dir)

FileUtils.cp_r(File.join(@skalp_path, 'SketchUp frameworks/lib_mac'), File.join(@build_path, 'Skalp_Skalp', "lib_mac"))
#FileUtils.copy(File.join(@application_path,'Build/Release/Skalp_external_application'), File.join(@build_path, 'Skalp_Skalp', "lib_mac/Skalp"))