module Sketchup
  class MockModel
    def pages; []; end
    def definitions; []; end
    def layers; []; end
    def materials; []; end
    def styles; []; end
    def get_attribute(*args); nil; end
    def set_attribute(*args); true; end
    def path; ""; end
    def title; "Mock Model"; end
  end

  class << self
    def version; "26.0.0"; end
    def read_default(*args); nil; end
    def write_default(*args); true; end
    def find_support_file(filename)
      File.join(File.expand_path("../../mock_support", __FILE__), filename)
    end
    def require(path)
       begin; ::Kernel.require path; rescue LoadError; true; end
    end
    def debug_mode?; true; end
    def os_language; 'en-US'; end
    def active_model; @active_model ||= MockModel.new; end
  end
end

module UI
  def self.messagebox(*args); puts "[MockUI] MessageBox: #{args[0]}"; end
  def self.inputbox(*args); args[1]; end
  def self.show_inspector(*args); end
  def self.menu(*args); MockMenu.new; end
  class MockMenu
    def add_item(*args); end
    def add_submenu(*args); self; end
  end
end

module Geom
  class Point3d
    def initialize(*args); end
  end
  class Transformation
    def self.new(*args); end
  end
end
