require 'Matrix'
filepath = File.dirname(__FILE__)
require filepath + "/chunky_png/lib/chunky_png.rb"
require "base64"
require 'fileutils'
require 'pp'

x = Time.now

#dir = File.join(File.dirname(__FILE__),"resources/hatchpats")
#FileUtils.mkdir(dir) unless File.exist?(dir)

def encode(a)
  a_encode = Base64.encode64(a)
  a_encode.gsub!("\n", "")
  "\"" + a_encode + "\""
end

# DEZE NIET OMZETTEN VOOR RELEASE (ENKEL DEVELOP)
filename = "Skalp_hatchpatterns_INSPECT.rb"
a = ""
File.open(filename, 'r') do |f1|
  while line = f1.gets
    a += line
  end
end
#eval(a)
#eval(Base64.decode64(encode(a)))

# FOR RELEASE
filenames = ["Skalp_hatch_lib.rb", "Skalp_hatchtile.rb", "Skalp_hatch_class.rb", "Skalp_hatchdefinition_class.rb", "Skalp_hatchline_class.rb", "Skalp_hatchpatterns_main.rb"]
a = ""
filenames.each { |file|
  File.open(file, 'r') do |f1|
    while line = f1.gets
      a += line
    end
  end
}
eval(a)
#eval(Base64.decode64(encode(a)))

puts 'TOTALTIME:'
puts Time.now - x
=begin
require 'digest'

# Get SHA256 Hash of a file
puts Digest::SHA256.hexdigest File.read "#{$jeroenfile}"
# Get MD5 Hash of a file
puts Digest::MD5.hexdigest File.read "#{$jeroenfile}"
# Get MD5 Hash of a string
puts Digest::SHA256.hexdigest "Hello World"

# Get SHA256 Hash of a string using update
sha256 = Digest::SHA256.new
sha256.update "Hello"
sha256.update " World"
puts sha256.hexdigest

puts Digest::SHA256.hexdigest File.read "Skalp_hatchtile.rb"
puts Digest::SHA256.hexdigest File.read "SkalpC.bundle"
=end

=begin

pick maximum:

array.max_by {|e| e.my_value}

array.max_by do |element|
  element.field
end

array.max_by(&:field)

my_array.max {|a,b| a.attr <=> b.attr }

=end
