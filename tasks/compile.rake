# frozen_string_literal: true

require "fileutils"

namespace :compile do
  desc "Compile all C-extensions and the external application using CMake"
  task :build do
    puts "🛠️ Starting CMake Build Pipeline..."
    
    build_dir = File.join(Config::PROJECT_ROOT, "BUILDS", "cmake_build")
    FileUtils.mkdir_p(build_dir)
    
    Dir.chdir(build_dir) do
      # 1. Configure
      system("cmake ../..") or raise "❌ CMake configuration failed"

      # 2. Build
      system("cmake --build . --parallel") or raise "❌ CMake build failed"
      
      puts "\n📦 Installing binaries to SOURCE/Skalp_Skalp2026/..."
      
      # 3. Detect and copy products
      # SkalpC stays in SOURCE/Skalp_Skalp2026/
      # External App goes to SOURCE/Skalp_Skalp2026/lib_mac/ (or lib_win)
      
      dest_base = File.join(Config::PROJECT_ROOT, "SOURCE", "Skalp_Skalp2026")
      lib_dir = File.join(dest_base, "lib")
      
      FileUtils.mkdir_p(dest_base)
      FileUtils.mkdir_p(lib_dir)

      Dir.glob("**/*.{bundle,so,dll,dylib,exe}").each do |binary|
        name = File.basename(binary)
        
        if name.include?("SkalpC")
          dest = File.join(dest_base, name)
          FileUtils.rm_rf(dest)
          FileUtils.cp_r(binary, dest)
          puts "   ✅ Installed SkalpC -> #{dest}"
        elsif name.include?("Skalp_external_application")
          if OS.mac?
            # On Mac, we extract the executable from the bundle to match Skalp's expected structure
            executable = File.join(binary, "Contents", "MacOS", "Skalp_external_application")
            dest = File.join(lib_dir, "Skalp")
            if File.exist?(executable)
              FileUtils.rm_f(dest)
              FileUtils.cp(executable, dest)
              puts "   ✅ Installed App Executable -> #{dest}"
            end
          else
            dest = File.join(lib_dir, "Skalp.exe")
            FileUtils.rm_f(dest)
            FileUtils.cp(binary, dest)
            puts "   ✅ Installed App Executable -> #{dest}"
          end
        end
      end
    end
  end

  desc "Clean compilation artifacts"
  task :clean do
    build_dir = File.join(Config::PROJECT_ROOT, "BUILDS", "cmake_build")
    FileUtils.rm_rf(build_dir) if File.exist?(build_dir)
    
    # Clean binaries from SOURCE
    Dir.glob("SOURCE/Skalp_Skalp2026/*.{bundle,so,dll}").each { |f| FileUtils.rm_f(f) }
    FileUtils.rm_rf("SOURCE/Skalp_Skalp2026/lib_mac")
    FileUtils.rm_rf("SOURCE/Skalp_Skalp2026/lib_win")
    puts "🧹 Cleaned all build artifacts."
  end
end

desc "Fast Development Build: Compile C components (SkalpC + Application)"
task "dev:cpp" do
  puts "🚀 Preparing Fast C-Extension & App Development Mode..."
  Rake::Task["compile:build"].invoke
  puts "\n✅ Ready! Run SketchUp with local binaries built and installed."
end
