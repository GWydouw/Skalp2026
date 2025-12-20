unless File.file?("./test")
  teigha_name = case Sketchup.platform
                  when :platform_win
                    'Teigha File Converter for Mac OS X'
                  when :platform_osx
                    'Teigha File Converter for Windows'
                  else
                    'Teigha File Converter for [your platform]'
                end

  UI.messagebox("Oops, minor issue:\n'Teigha File Converter' needed, but not found.\n\nPlease DOWNLOAD and INSTALL this free program from:\nwww.opendesign.com/guestfiles/teigha_file_converter\n\nWe will open the download page for you. Look for:\n'#{teigha_name}'")
  UI.openURL('http://download.skalp4sketchup.com/downloads/teigha/')
  UI.messagebox("Before proceeding, please make sure\nyou have succesfully installed\n'Teigha File Converter'.\n\nGreat! Almost done...\nOn the next dialog, now browse to your\n'Teigha File Converter' Installation Directory.")

  #self.teigha_path
  teighapath= UI.select_directory(
      title: "Select Teigha File Converter Installation Directory",
      directory: "/Applications/"
  )  #TODO check validity of self.teigha_path
  puts teighapath
end


teigha_name = case Sketchup.platform
                when :platform_win
puts '1'
                  'Teigha File Converter for Mac OS X'
                when :platform_osx
puts '2'
                  'Teigha File Converter for Windows'
                else
                  'Teigha File Converter for [your platform]'
              end


allapps = `mdfind 'kMDItemContentType==com.apple.application-bundle'`
allapps.include?('TeighaFileConverter.app')
lines = allapps.lines.map(&:chomp)