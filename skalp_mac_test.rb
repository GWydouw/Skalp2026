def skalp_mac_test
    temp_path = Sketchup.find_support_file("Plugins")+"/"
    tempfile = File.join(temp_path, 'skalp_mac_test.txt')

    params='/c ipconfig.exe /all > '+"\"#{tempfile}\""
    require 'win32ole'
    shell = WIN32OLE.new('Shell.Application')
    Dir.chdir(ENV['systemroot'] ? File.join(ENV['systemroot'], 'System32') : '') do
      shell.ShellExecute('cmd.exe', params, '', 'open', 0)
    end # Dir.chdir restores the original working path on leaving the block
end

skalp_mac_test
