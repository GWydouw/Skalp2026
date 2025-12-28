# RubyEncoder v3 loader
_d = __dir__

f = if RUBY_PLATFORM.include?("darwin")
      _d + "/rgloader32.darwin"
    else
      _d + "/rgloader32.mingw.x64"
    end

$LOADED_FEATURES.reject! { |p| p.start_with?(f) }
# [DevMode Fix] Change to plugin root so RGLoader can find Skalp.lic
Dir.chdir(File.dirname(_d)) do
  require(f)
end

unless defined?(RGLoader)
  raise LoadError,
        "The RubyEncoder loader is not installed. Please visit the http://www.rubyencoder.com/loaders/ RubyEncoder site to download the required loader for '" + _p[1] + "' and unpack it into '" + _d + "' directory to run this protected script."
end
