ENV['GEMRC'] ="#{RbConfig::TOPDIR}/lib/ruby/.gemrc"
ENV['GEM_PATH'] = "#{RbConfig::TOPDIR}/lib/ruby/gems/#{RbConfig::CONFIG['ruby_version']}"
Gem.paths = ENV