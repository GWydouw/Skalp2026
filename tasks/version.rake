namespace :version do
  desc "Register new Skalp version in database via PHP API"
  task :register, [:version_type] do |t, args|
    version_type = args[:version_type] || 'alpha'  # Default to alpha
    
    # Get version from version.rb
    version_file = File.join(Config::SOURCE_DIR, "Skalp_Skalp2026", "version.rb")
    unless File.exist?(version_file)
      puts "❌ version.rb not found"
      next
    end
    
    v_content = File.read(version_file)
    version_match = v_content.match(/VERSION\s*=\s*["']([^"']+)["']/)
    unless version_match
      puts "❌ Could not parse VERSION from version.rb"
      next
    end
    
    version = version_match[1]
    version_number = version.delete('.').to_i
    release_date = Date.today.strftime('%Y-%m-%d')
    su_min = 25
    su_max = 25
    public_flag = 0  # Always 0 for alpha/beta, 1 for release
    
    # Generate download URL
    rbz_filename = "Skalp_#{version.gsub('.', '_')}_#{version_number}.rbz"
    download_url = "/downloads/release/#{rbz_filename}"
    
    puts "📋 Registering version in database:"
    puts "   Version: #{version} (#{version_number})"
    puts "   Type: #{version_type}"
    puts "   Date: #{release_date}"
    puts "   SketchUp: #{su_min}-#{su_max}"
    puts "   Public: #{public_flag}"
    puts "   URL: #{download_url}"
    
    begin
      uri = URI("http://license.skalp4sketchup.com/register_2_0/new_skalp_version.php?release_date=#{release_date}&version=#{version_number}&version_type=#{version_type}&min_SU_version=#{su_min}&max_SU_version=#{su_max}&public=#{public_flag}")
      
      response = Net::HTTP.get(uri)
      puts "✅ Version registered successfully"
      puts "   Response: #{response}" unless response.to_s.strip.empty?
      
      # TODO: Upload RBZ to server
      # rbz_path = File.join(Config::BUILD_DIR, "release", "#{Config::EXTENSION_NAME}_v#{version}.rbz")
      # if File.exist?(rbz_path)
      #   puts "📤 Uploading RBZ to server..."
      #   # sh "scp -P 65432 '#{rbz_path}' 'skalpadmin@license.skalp4sketchup.com:/var/www/downloads/release/#{rbz_filename}'"
      #   puts "   (Server upload not yet implemented)"
      # end
      
    rescue => e
      puts "⚠️  Failed to register version: #{e.message}"
      puts "   (Continuing build anyway...)"
    end
  end
end
