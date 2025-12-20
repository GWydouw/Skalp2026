require 'bigdecimal'


def float_lcm(num1, num2) # geeft kleinste gemeen veelvoud van twee getallen terug als float. Input: zowel integers als floats of een combinatie
  puts
  puts "float_lcm(#{num1},#{num2})"
  number1 = num1
  number2 = num2
  if number1 == 0
    puts "hier"
    puts number2.abs
    return number2.abs
  elsif number2 == 0
    puts "2de nummer is nul"
    return number1
  else
    #LCM( (a/b) , (c/d) ) = LCM(a,c)/HCF(b,d)
    number1 = phinkrational(number1)
    number2 = phinkrational(number2)

    a = number1.numerator
    b =number1.denominator
    c =number2.numerator
    d =number2.denominator
    result = Rational(a.lcm(c), b.gcd(d))
    puts "a/b: #{a}/#{b}, c/d: #{c}/#{d}"
    puts "breukresult: #{a.to_f/b.to_f}, #{c.to_f/d.to_f}"
    puts "LCM(#{a},#{c}): #{a.lcm(c)}, HCF(#{b},#{d}): #{b.gcd(d)}"
    puts "LCM / HCF = KGV: #{result}"
    return result.to_f #OPGELET, mag deze .to_f weg?
  end

end

def phinkrational(num) #finds smallest sufficiently correct rational by increasing decimal accuracy until rationalize returns an equal value
                       #ATTENTION! Math.cos -9..9 and 171..-171 degrees => 1 (same issue by symmetry for sin 81..99 and -81..-99)
  a, b = 1, 2       #just to start with a != b
  exponent = 0
  until (a == b)
    exponent += 1
    tolerance1 = 10**-(exponent)
    a = num.rationalize(tolerance1)
    tolerance2 = 10**-(exponent+1)
    b = num.rationalize(tolerance2)
  end
  return a
end
# TEST phinkrational
#phinkrational(Math.cos(45 * Math::PI / 180))
#hoek = BigDecimal.new((Math.cos(45 * Math::PI / 180)),11).to_f
#phinkrational(hoek)
#puts "verschil: #{phinkrational(hoek)-phinkrational(0.707)}"
#TEST float_lcm
p float_lcm(0.3, 0.25)
p float_lcm(0.3333333, 0.25)
p float_lcm(0.25, 1.25)
p float_lcm(0.707, 1.414)
p float_lcm(707, 1414)
p float_lcm(707.0, 1414.0)

def get_decimal_length(num) #requires strings, floats or integers
  num = num.to_f.to_s
  result = (num.to_s).split(".")
  result[1].length
end

def max(number1, number2)
  (number1 <= number2) ? number2 : number1
end

def get_max_dec_length(nums1, nums2)
  max(get_decimal_length(nums1), get_decimal_length(nums2))
end

def tolerance_from_dec_length(num)
  10**-num
end

def tolerance_from_number(num) #requires strings, floats or integers, returns significant tolerance as a rational
                               #puts 10**-(get_decimal_length(num)+1)
  10**-(get_decimal_length(num))
end

#p tolerance_from_number(1.32)

#bigdec1 = BigDecimal.new(num)





=begin
sum = 0
for i in (1..10000)
  sum = sum + 0.0001
end
print sum
puts
puts "#######"


sum = BigDecimal.new("0")
for i in (1..10000)
  sum = sum + BigDecimal.new("0.0001")
end
print sum
puts
=end
