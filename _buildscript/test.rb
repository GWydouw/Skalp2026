#def get_exploded_entities(temp_dir, height, index_array, scale_array, perspective_array, target_array, rear_view)
  require "open3"
  require "shellwords"

  class Hiddenlines_data
    attr_accessor :index, :target, :lines

    def initialize(index)
      @index = index
      @target = []
      @lines = []
    end

    def add_line(line)
      @lines << line
    end
  end

  path = Shellwords::escape(ENV['SKALPDEV'] + '/Skalp_external_application/Build/Products/Release/Skalp_external_application')


  # command1 = %Q(#{path} "setup_reversed_scene" "/Users/guy/Library/Application Support/SketchUp 2016/SketchUp/Plugins/Skalp_Skalp/temp.skp" "-1|0|6|7|9" "323.1698621198036,91.7955208304802,-863.4776291413001|323.1698621198036,91.7955208304802,-1433.0263992638945|323.1698621198036,91.7955208304802,-1363.3438274182517|323.1698621198036,91.7955208304802,-1545.014759091057|323.1698621198038,1718.2327768066143,-7.448818897637222" "323.1698621198036,91.7955208304802,57.047244094488136|323.1698621198036,91.7955208304802,57.047244094488136|323.1698621198036,91.7955208304802,57.047244094488136|323.1698621198036,91.7955208304802,-18.287401574803198|323.1698621198036,150.03383133582832,-7.448818897637906" "1.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,57.125984251968454,1.0|1.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,57.125984251968454,1.0|1.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,57.125984251968454,1.0|1.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,-18.208661417322883,1.0|1.0,-1.2001669633176243e-16,0.0,0.0,-5.239079554513076e-32,-4.365292259029257e-16,1.0,0.0,-1.2001669633176243e-16,-1.0,-4.365292259029257e-16,0.0,1.7997114641353547e-14,149.95509117834806,6.545977987228694e-14,1.0" "skalp_live_sectiongroup|f543911f-b359-40b4-8669-ddca7aaca4a6|17b252e3-8484-4ef2-b360-96096b5f3622|8a41d57d-7055-4514-ad03-905b40daddcb|0a2ab39f-a9ea-4f0e-b930-d1de35ef6bd4" "0.0,1.0,0.0|0.0,1.0,0.0|0.0,1.0,0.0|0.0,1.0,0.0|-5.239079554513076e-32,-4.365292259029257e-16,1.0" "1378.9279915400987")
  # Open3.popen3(command1)   do |stdin, stdout, stderr|
  #    stdout.read
  # end

  #sleep(3.0)
  #path = Shellwords::escape(SKALP_PATH + "lib/")
  #command = %Q(#{path}Skalp "get_exploded_entities" "#{temp_dir}" "#{height}" "#{array_to_string_array(index_array)}" "#{array_to_string_array(scale_array)}" "#{array_to_string_array(perspective_array)}" "#{point_array_to_string_array(target_array)}" "#{rear_view.to_s}")



  command =  %Q(#{path} "get_exploded_entities" "/Users/guy/Library/Application Support/SketchUp 2016/SketchUp/Plugins/Skalp_Skalp/temp.skp" "6.809939556749496" "-1" "0.009816361293378168" "false" "46.394800724066044,261.79239117589077,3.019790509137806" "-1.0")

  exploded_lines = []
  hiddenline_data = nil

  Open3.popen3(command) do |stdin, stdout, stderr|
    stdout.each_line do |line|
      type = line[0,3]
      data = line[3..-1]

      puts type
      puts data

      case type
        when '*I*'
          hiddenline_data = Hiddenlines_data.new(data)
        when '*T*'
          hiddenline_data.target = eval(data)
        when '*L*'
          hiddenline_data.add_line(eval(data))
        when '*E*'
          exploded_lines << hiddenline_data
      end
    end
  end

exploded_lines.each do   |data|
  data.lines.each do |line|
    puts line.inspect
  end
end


  #return exploded_lines
#end
