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
      # External App goes to SOURCE/Skalp_Skalp2026/lib/

      dest_base = File.join(Config::PROJECT_ROOT, "SOURCE", "Skalp_Skalp2026")
      lib_dir = File.join(dest_base, "lib")

      FileUtils.mkdir_p(dest_base)
      FileUtils.mkdir_p(lib_dir)

      # On Mac/Linux, executables may have no extension. On Windows, they have .exe.
      # We look for Skalp (Mac/Linux) or Skalp.exe (Windows) or Skalp_external_application
      Dir.glob("**/{Skalp,Skalp.exe,SkalpC.bundle,SkalpC.so,SkalpC.dll}").each do |binary|
        name = File.basename(binary)

        if name.start_with?("SkalpC")
          dest = File.join(dest_base, name)
          FileUtils.rm_rf(dest)
          FileUtils.cp_r(binary, dest)
          puts "   ✅ Installed SkalpC -> #{dest}"
        elsif ["Skalp", "Skalp.exe"].include?(name)
          dest = File.join(lib_dir, name)
          FileUtils.rm_f(dest)
          FileUtils.cp(binary, dest)
          puts "   ✅ Installed App Executable -> #{dest}"
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
