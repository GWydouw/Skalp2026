desc "Embed Ruby source into C++ headers (Base64)"
task embed: [:build_dirs] do
  require "base64"
  require "yaml"

  puts "🔮 Embedding Ruby source into C++..."

  # Configuration
  RUBY_SRC_DIR = "SOURCE/skalp"
  CPP_SRC_DIR = "ce_src_skalpc/src"
  CONFIG_FILE = "embed.yml"
  
  unless File.exist?(CONFIG_FILE)
    abort("❌ configuration file '#{CONFIG_FILE}' not found. Please create it to define file mappings.")
  end

  config = YAML.load_file(CONFIG_FILE)
  FileUtils.mkdir_p(CPP_SRC_DIR)

  config.each do |data_filename, source_files|
    # Ensure source_files is an array
    source_files = [source_files] unless source_files.is_a?(Array)
    
    data_path = File.join(CPP_SRC_DIR, data_filename)
    puts "   -> Processing #{data_filename} (combines #{source_files.length} files)..."

    # 1. Combine Content
    combined_content = ""
    source_files.each do |rb_filename|
      rb_path = File.join(RUBY_SRC_DIR, rb_filename)
      if File.exist?(rb_path)
        combined_content += File.read(rb_path)
        combined_content += "\n" # Ensure separation
      else
        puts "      ⚠️  Warning: Source file not found: #{rb_filename}"
      end
    end

    next if combined_content.empty?

    # 2. Encode (Strict + remove newlines)
    encoded = Base64.strict_encode64(combined_content)
    
    # 3. Chunking (Safe size 500)
    chunk_size = 500
    chunks = encoded.scan(/.{1,#{chunk_size}}/)
    
    # 4. Build C++ Code
    c_code = ""
    first = true
    
    chunks.each do |chunk|
      if first
        c_code += "std::string(\"#{chunk}\")"
        first = false
      else
        c_code += " + \"#{chunk}\""
      end
    end
    
    c_code += ";"

    # 5. Write to .data file
    File.write(data_path, c_code)
  end
  puts "✅ Embedding complete."
end

task :compile_prep => :embed
