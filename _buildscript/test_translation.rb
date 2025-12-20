SKALPTRANSLATE_RX = /Skalp\.translate\s?\((["'])(?:(?=(\\?))\2.)*?\1\)/
UNIVERSAL_QUOTED_STRING_RX = /(["'])(?:(?=(\\?))\2.)*?\1/
TRANSLATE_STRING = /(-*\s*\d*\w\D[^"=;]*)/

def self.get_translate_strings(line) #2
  # input e.g. a line
  #line = %q^To Skalp.translate("day's date VOORBEELD1 met inch vermeld") is: 1019"dit is een test voor woordeSkalp.translate ('day"s date met VOORBEEL 2 inch vermeld')dit is andere brol() en Skalp gezever "test'" en nog iets "test"^

  translate_matches = []
  line.scan(SKALPTRANSLATE_RX){ translate_matches << $~ }
  translate_matches.map! {|gotcha| gotcha.to_s.match(UNIVERSAL_QUOTED_STRING_RX).to_s}
end


def self.create_english_translation_file #1
  #TODO translation of webdialogs!!!

  all_words = []
  string_file = @skalp_path + "resources/strings/en-US/skalp.strings"

  file = File.open(string_file,'w:UTF-8')

  Dir.foreach(@skalp_path) do |rb_file|
    title_text = false

    next if rb_file == '.' || rb_file == '..'
    next if rb_file.include?(".rbs")
    next unless rb_file.include?(".rb")

    File.readlines(@skalp_path + rb_file).each do |line|
      strings = get_translate_strings(line)

      strings.each do |en_string|
        unless title_text
          file.puts "// #{rb_file.gsub('.rb', '')} ////////////////////////////////////////////"
          title_text = true
        end

        unless all_words.include?(en_string)
          file.puts %Q^"#{en_string[1..-2]}" = "#{en_string[1..-2]}";^
          all_words << en_string
        end
      end
    end
  end

  file.close

  Dir.foreach(@skalp_path + "resources/strings/") do |language|
    next if language == '.' || language == '..' || language == 'en-US'  || language == '.DS_Store' || language == 'translation.csv'
    update_translation_file(language)
  end

  #create CSV translation file
  create_translation_csv

end

def self.create_translation_csv #4
  translation_file = File.open(@skalp_path + "resources/strings/translation.csv", 'w:UTF-8')

  #Get all translated strings for each language
  languages = {}
  Dir.foreach(@skalp_path + "resources/strings/") do |language|
    next if language == '.' || language == '..' || language == '.DS_Store' || language == 'translation.csv'
    string_file = @skalp_path + 'resources/strings/' + language + '/skalp.strings'
    languages[language] = File.readlines(string_file)
  end

  #Define language titles
  line = 'en-US'
  languages.each_key do |language|
    next if language == 'en-US'
    line = line + ';' + language.to_s
  end
  translation_file.puts line

  for n in 0..languages['en-US'].size-1
    if languages['en-US'][n][0] == '/'
      translation_file.puts languages['en-US'][n]
      next
    else
      line = languages['en-US'][n].scan(TRANSLATE_STRING)[0]
      next unless line

      line = line[0]
      languages.each_key do |language|
        next if language == 'en-US'

        other_language = languages[language][n]
        #puts other_language

        if other_language
          other_language = other_language.scan(TRANSLATE_STRING)[1]
          other_language ? other_language = other_language[0] : other_language = ""
        else
          other_language = ""
        end

        line = line + ';' + other_language.to_s
      end
      translation_file.puts line
    end
  end
end

def self.update_translation_file(language) #3
  file = @skalp_path + 'resources/strings/' + language + '/skalp.strings'

  translations = {}

  File.readlines(file).each do |line|
    next if line[0] == '/' || line[0] == ''
    result = line.scan(TRANSLATE_STRING)
    next unless result
    next if result == []
    if result[1]
      translations[result[0][0]] = result[1][0]
    end
  end

  language_file = File.open(file, 'w:UTF-8')
  string_file = @skalp_path + "resources/strings/en-US/skalp.strings"
  File.readlines(string_file).each do |line|

    if line[0] == '/' || line[0] == ''
      language_file.puts line
    else
      result = line.scan(TRANSLATE_STRING)[0]
      next unless result
      if translations[result[0]]
        language_file.puts %Q^"#{result[0]}" = "#{translations[result[0]]}";^
      else
        language_file.puts %Q^"#{result[0]}" = "";^
      end
    end
  end
  language_file.close
end

create_english_translation_file
