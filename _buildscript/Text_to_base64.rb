module Scramble
  require 'base64'

  def self.text2base64(text)
  text_to_scramble = "text"

  scrambled_text = Base64.encode64(text_to_scramble)
  scrambled_text.gsub!("\n", "")
  puts scrambled_text
  end

  def self.base2text(coded_text)
    text_to_unscramble = coded_text

    unscrambled_text =  Base64.decode64(text_to_unscramble)
    puts unscrambled_text

  end

  #base2text("cmVxdWlyZSAnU2thbHAvU2thbHBDJw==")


  code = %q(module Skalp;skalp_version = SKALP_VERSION.split('.')[0].to_i;model = Skalp.active_model.skpModel;version = model.get_attribute('Skalp_memory_attributes', 'skpModel|skalp_version');if skalp_version < version.split('.')[0].to_i; UI.messagebox("Your model #{model.path} is made with a newer Skalp version, please install Skalp #{version} or higher to edit this model. Sketchup will be closed now, you can save your model(s) before quit.");Sketchup.quit;else;return eval(Sketchup.active_model.materials['Skalp default'].get_attribute('Skalp', 'pattern_info2'));end;end;)
  code64 = Base64.encode64(code)
  puts code64.gsub!("\n", "")



end
