#INSPECTIE
def self.inspection(hatches)
  begin
    puts 'INSPECTIE'
    for item in hatches do
      #puts "ingelezen: hatchnaam: #{item.hatchdefinition.name} / beschrijving: #{item.hatchdefinition.description}"
      #/ beschrijving:\n#{item.hatchdefinition.originaldefinition}
      #ap item
      #ap item.get_hatchlines
      tel = 0
      for n in item.hatchdefinition.hatchlines
        tel += 1 if n.hatchlineoverflow

      end


    end
    puts "#{hatches.size} defintions processed"
  end
end

def self.testing
=begin
      puts "TESTING...."
      #puts "_____________1_________________"
      hatchtile = HatchTile.new(15, 15)
      hatchtile.linethickness = 1
      #line1 = Line2D.new(Point2D.new(0, 5.0), Point2D.new(6, 10))

      #edge = hatchtile.intersect(line1)
      #puts edge
      #puts "_____________2_________________"
      #line2 = Line2D.new(Point2D.new(-1, -1), Point2D.new(16, 16))
      #edge2 = hatchtile.intersect(line2)
      #puts edge2
      puts "_____________3_________________"
      p1 = Point2D.new(-8, -0)
      p2 = Point2D.new(-2.0, -2.0)
      p1.rotate(radians(90), p2)
      puts "punt na rotate:#{p1}"
      e = Edge2D.new(p1, p2)
      puts e
      e.rotate!(radians(90), Point2D.new(3, 3))
      puts e
      tf = Transformation2D.new.translate!(5.0, -5.0)
      #puts tf
      e.transform!(tf)
      puts e

      line3 = Line2D.new(Point2D.new(-15, -50), Point2D.new(2000, 20))
      val3 = hatchtile.direction_to(line3)
      val = line3.side?(Point2D.new(2, 65))
      val2 = Point2D.new(2, 65).side?(line3)
      puts val3
      #ht = HatchTile.new
      #puts ht.inspect
      #puts t.inspect
      #t.translate!(50,50)
      #p.transform! t
      #puts p
=end

  line3 = Line2D.new(Point2D.new(-15, -50), Point2D.new(2000, 20))
  puts line3.inspect
  line3.dup
  tf = Transformation2D.new.translate!(5.0, -5.0)
  line3.transform!(tf)
  puts line3.inspect
  #radangle = 60 * Math::PI / 180 #radians
  #t.rotate!(radians(60))
  #t.scale!(1000000)
  #puts t.inspect
  #p.transform! t
  #puts p
  #puts '_________________'
  #vector = Vector2D.new(radians(135))
  #line = Line2D.new(Point2D.new(1,1),vector)
  #puts line.inspect

  #radangle = 60 * Math::PI / 180 #radians
  #puts t.inspect
  #t.rotate!(radangle)
  #puts t.inspect
  #puts p
  ##p.transform!(t)
  #puts p
  #png = ChunkyPNG::Image.new(100, 100, ChunkyPNG::Color::WHITE)
  p1= Point2D.new(5, 5)
  p2= Point2D.new(50, 55)
  p3= Point2D.new(50, 5)
  p4= Point2D.new(5, 95)
  p5= Point2D.new(50, 55)
  p6= Point2D.new(95, 95)

  #ChunkyPNG::Color::PREDEFINED_COLORS[:red]
  test_png2 = ChunkyPNG::Image.new(100, 100, ChunkyPNG::Color::WHITE)
  png3 = ChunkyPNG::Image.new(100, 100, ChunkyPNG::Color.rgba(40, 80, 150, 0))

  #png.circle_float(Point2D.new(15,15), 20, ChunkyPNG::Color::BLACK, 15) #TODO pass a color

  test_png2.circle_float(Point2D.new(40, 55), 20, ChunkyPNG::Color::PREDEFINED_COLORS[:blue], 15)
  test_png2.circle_float(Point2D.new(30, 30), 20, ChunkyPNG::Color::PREDEFINED_COLORS[:yellow], 15) #TODO pass a color
  test_png2.line_float(p3.x, p3.y, p4.x, p4.y, stroke_color = ChunkyPNG::Color::WHITE, inclusive = true)
  test_png2.line_float(p1.x, p1.y, p2.x, p2.y, stroke_color = ChunkyPNG::Color::BLACK, inclusive = true)
  test_png2.line_float(p5.x, p5.y, p6.x, p6.y, stroke_color = ChunkyPNG::Color::BLACK, inclusive = true)

  #png.circle_float(Point2D.new(70,70), 20, ChunkyPNG::Color::BLACK, 15) #TODO pass a color
  #png.circle_float(Point2D.new(100,100), 20, ChunkyPNG::Color::BLACK, 15) #TODO pass a color
  test_png2.save(File.expand_path('~') + "/Desktop/hatchtextures/cirkel.png",
                 constraints = {:best_compression => true, :interlace => false})

end
#testing