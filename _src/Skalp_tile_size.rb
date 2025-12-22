module Skalp
  class PenWidth
    UNITS = ['pt', 'mm', 'cm', 'm', 'inch', 'feet']

    def initialize(pen, space, dialog = false)
      @space = space.to_sym
      @pen = pen.to_s

      if @space == :modelspace
        unit_processor = Skalp::Tile_size.new

        if is_unitless? && !dialog
          @width_value = @pen.to_f
          @width_string = unit_processor.format_modelunit(@width_value)
        else
          unit_processor.process_string(@pen)
          @width_string = unit_processor.string
          @width_value = unit_processor.value
        end
      else
        if is_unitless?
          @width_value = @pen.to_f
          @width_string = Skalp::inch2pen(@width_value)
        else
          @width_string = @pen
          @width_value = Skalp::mm_or_pts_to_inch(@pen)
        end
      end
    end

    def to_inch
      @width_value
    end

    def to_s
      @width_string
    end

    private

    def is_unitless?
      UNITS.each { |unit| return false if @pen.include?(unit) }
      return true
    end
  end

  class Tile_size
    attr_accessor :gauge
    attr_reader :unit

    def initialize()
      @decimal = Skalp.decimal_separator
      @model_unit = Skalp.model_unit
      @xy = :x
      @gauge = 1

      default_value
    end

    def print_values
      puts '---------------------'
      puts "@gauge: #{@gauge}"
      puts "@xy: #{@xy}"
      puts "@input_string: #{@input_string}"
      puts "@input_value: #{@input_value}"
      puts "@other_string: #{@other_string}"
      puts "@other_value: #{@other_value}"
    end

    def default_value
      if metric?
        calculate('5mm', :x)
      else
        calculate('1/4"', :x)
      end
    end

    def default_model_value
      if metric?
        calculate('20cm', :x)
      else
        calculate('10"', :x)
      end
    end

    def calculate(string, xy)
      @xy = xy
      process_string(string)
      default_value if @input_value == 0 || @input_value == nil
      calculate_other_value
      format_other_value
    rescue
      default_value
    end

    def process_string(string)
      if string == '' || string == nil
        string = '0'
      end

      string.gsub!('feet', "'")
      @input_string = string
      find_unit
      process_string_value
    end

    def gauge= (num)
      @gauge = num.to_f
      calculate_other_value
      format_other_value
    end

    def string
      @input_string
    end

    def value
      @input_value
    end

    def x_string
      (@xy == :x) ? @input_string : @other_string
    end

    def y_string
      (@xy == :y) ? @input_string : @other_string
    end

    def x_value
      (@xy == :x) ? @input_value : @other_value
    end

    def y_value
      (@xy == :y) ? @input_value : @other_value
    end

    def decimal(string)
      if string && string.count(@decimal) > 1
        temp = string.split(@decimal)
        string = temp[0].to_s + @decimal + temp[1].to_s
      end
      string
    end

    def process_string_value
      @input_string.gsub!(',', '.') if @decimal == ','
      @input_string.gsub!(/[^\d+.\/]/, '')

      if @input_string.count('/') > 0
        @rational = true
        temp = @input_string.split('/')
        #@input_string = decimal(temp[0]) + '/' + decimal(temp[1])
        @input_string = temp[0] + '/' + temp[1]
        @input_value = input_to_inch(temp[0].to_f / temp[1].to_f)
      else
        @rational = false
        #@input_string = decimal(@input_string)
        @input_string = @input_string
        @input_value = input_to_inch(@input_string.to_f)
      end

      @input_string = format(@input_value) #@input_string + @unit
    end

    def calculate_other_value
      if @xy == :x
        @other_value = @input_value * @gauge
      else
        @other_value = @input_value / @gauge
      end
    end

    def format(value)
      case @unit
        when 'mm'
          value_string = (value * 25.4).round(1).to_s + 'mm'
        when 'cm'
          value_string = (value * 2.54).round(2).to_s + 'cm'
        when 'm'
          value_string = (value * 0.0254).round(4).to_s + 'm'
        when 'inch'
          value_string = value.round(3).to_s + '"'
        when "feet"
          value_string = (value * (1.0/12.0)).round(4).to_s + "'"
      end
      value_string
    end

    def format_modelunit(value)
      case Skalp.model_unit
        when 'mm'
          value_string = (value * 25.4).round(1).to_s + 'mm'
        when 'cm'
          value_string = (value * 2.54).round(2).to_s + 'cm'
        when 'm'
          value_string = (value * 0.0254).round(4).to_s + 'm'
        when 'inch'
          value_string = value.round(3).to_s + '"'
        when "feet"
          value_string = (value * (1.0/12.0)).round(4).to_s + "'"
      end
      value_string
    end

    def format_other_value
      @other_string = format(@other_value)
    end


    def find_unit
      @metric = false

      @unit = nil
      if @input_string.include?('mm')
        @unit = 'mm'
        @input_string.gsub!('mm', '')
        @metric = true
      end
      if @input_string.include?('cm')
        @unit = 'cm'
        @input_string.gsub!('cm', '')
        @metric = true
      end
      if @input_string.include?('m') && !@input_string.include?('mm') && !@input_string.include?('cm')
        @unit = 'm'
        @input_string.gsub!('m', '')
        @metric = true
      end
      if @input_string.include?('"')
        @unit = 'inch'
        @input_string.gsub!('"', '')
      end
      if @input_string.include?('\'')
        @unit = 'feet'
        @input_string.gsub!('\'', '')
      end

      if @unit == nil then
        @unit = Skalp.model_unit
      end
    end

      def input_to_inch(num)
        case @unit
          when 'mm'
            return num / 25.4
          when 'cm'
            return num / 2.54
          when 'm'
            return num / 0.0254
          when 'inch'
            return num
          when 'feet'
            return num * 12.0
        end
      end

    def metric?
      !(@model_unit == 'inch' || @model_unit == 'feet')
    end
  end
end
