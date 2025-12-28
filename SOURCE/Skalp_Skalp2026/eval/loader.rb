# RubyEncoder v3 loader
_d = File.expand_path(File.dirname(__FILE__))

if RUBY_PLATFORM.include?('darwin')
  f = _d + '/rgloader32.darwin'
else
  f = _d + '/rgloader32.mingw.x64'
end

$LOADED_FEATURES.reject!{|p| p.start_with?(f)}
require(f)

if !defined?(RGLoader) then 
  raise LoadError, "The RubyEncoder loader is not installed. Please visit the http://www.rubyencoder.com/loaders/ RubyEncoder site to download the required loader for '"+_p[1]+"' and unpack it into '"+_d+"' directory to run this protected script."
end



