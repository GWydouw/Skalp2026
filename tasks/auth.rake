desc "Setup authentication for SketchUp Extension Warehouse"
namespace :sign do
  task :auth do
    require "io/console"
    
    auth_dir = File.expand_path("../../tools/sign", __FILE__)
    env_file = File.join(auth_dir, ".env")
    
    FileUtils.mkdir_p(auth_dir)
    
    puts "🔑 Setup SketchUp Extension Warehouse Credentials"
    puts "   These will be stored securely in: #{env_file}"
    puts "   (This file is gitignored)"
    puts ""
    
    print "   Username (email): "
    username = $stdin.gets&.strip
    
    print "   Password: "
    password = $stdin.noecho(&:gets)&.strip
    puts ""
    
    if username.nil? || username.empty? || password.nil? || password.empty?
      abort("❌ No credentials entered.")
    end
    
    File.write(env_file, "EW_USERNAME=#{username}\nEW_PASSWORD=#{password}\n")
    puts "✅ Credentials saved! You can now run 'rake build:release' or 'rake sign:auto'."
  end
end
