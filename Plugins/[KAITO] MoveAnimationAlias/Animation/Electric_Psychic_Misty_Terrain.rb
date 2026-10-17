# Electric / Psychic / Misty Terrain - Pokemon Essentials v21.1.
# Add alongside Grassy Terrain, Cursed Terrain and Terrain_Floor_Tint.rb.
# Procedural pixel effects only: no PNG/audio/PBS imports. Gameplay is unchanged.
# Each common terrain animation casts once; the field layer remains until it ends.
module TerrainTrioVisual
  VERSION = "1.0"
  CAST_SECONDS = 1.95
  MOVES = { :ELECTRICTERRAIN=>:Electric, :PSYCHICTERRAIN=>:Psychic, :MISTYTERRAIN=>:Misty }
  NAMES = { "electricterrain"=>:Electric, "psychicterrain"=>:Psychic, "mistyterrain"=>:Misty }
  COLOURS = {
    :Electric=>[[173,123,35],[255,211,87],[255,251,205]],
    :Psychic=>[[111,65,158],[215,151,235],[255,226,254]],
    :Misty=>[[179,111,157],[239,184,214],[255,241,245]]
  }
  FLOOR_COLOURS = { :Electric=>[238,192,57], :Psychic=>[159,99,204], :Misty=>[233,150,192] }
  def self.line(b,x1,y1,x2,y2,width,c)
    n = [(x2-x1).abs.round,(y2-y1).abs.round,1].max
    (0..n).each do |i|
      p = i.to_f/n
      b.fill_rect((x1+(x2-x1)*p).round-width/2,(y1+(y2-y1)*p).round-width/2,width,width,c)
    end
  end
  def self.polygon(b,points,c)
    low,high = points.map { |p|p[1] }.minmax
    (low..high).each do |y|
      xs = []
      points.each_with_index do |p,i|
        q = points[(i+1)%points.length]
        next unless (p[1]<=y && q[1]>y) || (q[1]<=y && p[1]>y)
        xs << p[0]+(y-p[1]).to_f*(q[0]-p[0])/(q[1]-p[1])
      end
      xs.sort.each_slice(2) { |l,r| b.fill_rect(l.ceil,y,[r.floor-l.ceil+1,1].max,1,c) if r }
    end
  end
  def self.floor(kind)
    b = Bitmap.new(256,192)
    rgb = FLOOR_COLOURS[kind]
    192.times do |y|
      p = [[(y/192.0-0.38)/0.43,0].max,1].min
      b.fill_rect(0,y,256,1,Color.new(*rgb,(p*p*(3-2*p)*64).round))
    end
    b
  end
  def self.assets(kind)
    dark,light,white = COLOURS[kind]
    ground = Bitmap.new(128,96)
    particle = Bitmap.new(32,32)
    beam = Bitmap.new(256,80)
    ring = Bitmap.new(256,256)
    720.times do |i|
      a = i*Math::PI/360
      [[108,Color.new(*light,145)],[112,Color.new(*white,220)]].each do |r,c|
        ring.fill_rect((128+Math.cos(a)*r).round,(128+Math.sin(a)*r).round,2,2,c)
      end
    end
    case kind
    when :Electric
      paths = [[[2,56],[22,56],[31,39],[49,39],[58,58],[80,58],[91,37],[126,37]],
               [[8,16],[28,16],[40,31],[66,31],[78,13],[111,13]],
               [[24,93],[36,74],[58,74],[69,59],[88,59],[99,78],[124,78]]]
      paths.each do |pts|
        pts.each_cons(2) do |p,q|
          line(ground,*p,*q,4,Color.new(*dark,80))
          line(ground,*p,*q,2,Color.new(*light,210))
          line(ground,*p,*q,1,Color.new(*white,210))
        end
      end
      [[31,39],[80,58],[66,31],[36,74]].each do |x,y|
        ground.fill_rect(x-3,y-3,6,6,Color.new(*light,150))
        ground.fill_rect(x-1,y-1,2,2,Color.new(*white,255))
      end
      polygon(particle,[[17,1],[7,15],[16,15],[10,30],[27,10],[18,11],[24,1]],Color.new(*light,245))
      polygon(particle,[[18,5],[12,13],[19,13],[15,21],[22,12],[17,13]],Color.new(*white,255))
      points = [[2,48],[35,48],[51,26],[77,37],[103,13],[134,29],[159,18],[188,39],[215,27],[253,27]]
      points.each_cons(2) do |p,q|
        line(beam,*p,*q,5,Color.new(*light,45))
        line(beam,*p,*q,2,Color.new(*light,220))
        line(beam,*p,*q,1,Color.new(*white,245))
      end
    when :Psychic
      [24,35,43].each do |r|
        360.times do |i|
          next if r==35 && i%45>29
          a = i*Math::PI/180
          ground.fill_rect((64+Math.cos(a)*r).round,(48+Math.sin(a)*r).round,2,2,Color.new(*light,r==43 ? 160 : 210))
        end
      end
      [[64,7],[105,48],[64,89],[23,48]].each { |x,y| polygon(ground,[[x,y-4],[x+4,y],[x,y+4],[x-4,y]],Color.new(*white,235)) }
      polygon(particle,[[16,2],[28,16],[16,30],[4,16]],Color.new(*dark,190))
      polygon(particle,[[16,5],[25,16],[16,27],[7,16]],Color.new(*light,245))
      polygon(particle,[[16,8],[16,24],[10,16]],Color.new(*white,245))
      3.times do |j|
        last = nil
        120.times do |i|
          x = 8+i*2
          y = 37+Math.sin(i/119.0*Math::PI*2+j*0.4)*16+j*4
          line(beam,*last,x,y,2,Color.new(*light,(Math.sin(i/119.0*Math::PI)*180).round)) if last
          last = [x,y]
        end
      end
    when :Misty
      96.times do |y|
        8.times do |j|
          x = j*16
          v = Math.exp(-((y-48-Math.sin(j*0.8)*7)/23.0)**2)
          ground.fill_rect(x,y,16,1,Color.new(*light,(v*36).round))
        end
      end
      polygon(particle,[[4,16],[10,5],[22,5],[28,13],[20,24],[9,25]],Color.new(*light,220))
      polygon(particle,[[7,15],[12,8],[22,7],[20,15]],Color.new(*white,235))
      80.times do |y|
        16.times do |j|
          v = Math.exp(-((y-39-Math.sin(j*0.65)*10)/14.0)**2)
          edge = Math.sin((j+0.5)/16.0*Math::PI)**0.6
          beam.fill_rect(j*16,y,16,1,Color.new(*white,(v*edge*50).round))
        end
      end
    end
    spark = Bitmap.new(20,20)
    spark.fill_rect(9,2,2,16,Color.new(*light,185))
    spark.fill_rect(2,9,16,2,Color.new(*light,185))
    spark.fill_rect(8,8,4,4,Color.new(*white,245))
    [floor(kind),ground,particle,beam,ring,spark]
  end
  def self.play_se(kind,secondary=false)
    names = case kind
            when :Electric then secondary ? ["PRSFX- Electric Terrain2"] : ["PRSFX- Electric Terrain"]
            when :Psychic then secondary ? ["PRSFX- Psychic Terrain2","PRSFX- Psychic Terrain3"] : ["PRSFX- Psychic Terrain1"]
            when :Misty then secondary ? [] : ["PRSFX- Misty Terrain"]
            end
    names.each do |name|
      next unless [".wav",".ogg",".mp3"].any? { |ext| File.file?("Audio/SE/Anim/#{name}#{ext}") }
      pbSEPlay("Anim/#{name}",secondary ? 55 : 75,100)
      break
    end
  end
  class Layer
    attr_reader :kind
    def initialize(hash,viewport,kind)
      @hash,@viewport,@kind = hash,viewport,kind
      @sprites,@bitmaps,@keys = [],[],[]
      @age,@alpha = 0.0,0.0
      @disposed = false
      begin
        @bitmaps.concat(TerrainTrioVisual.assets(kind))
        floor,ground,particle,beam,ring,spark = @bitmaps
        @floor = make(floor,0,0,2)
        @floor.zoom_x,@floor.zoom_y = Graphics.width/256.0,Graphics.height/192.0
        @ground = Array.new(kind==:Misty ? 16 : 20) { make(ground,64,48,4) }
        @particles = Array.new(18) { make(particle,16,16,8) }
        @beams = Array.new(kind==:Misty ? 6 : 4) { make(beam,128,40,6) }
        @rings = Array.new(3) { make(ring,128,128,5) }
        @sparks = Array.new(16) { make(spark,10,10,9) }
        (@rings+@sparks).each { |s| s.blend_type=1 }
      rescue
        dispose
        raise
      end
    end
    def make(bitmap,ox,oy,z)
      s = Sprite.new(@viewport)
      @sprites << s
      s.bitmap,s.ox,s.oy,s.z = bitmap,ox,oy,z
      key = "terrain_trio_#{object_id}_#{@keys.length}"
      @keys << key
      @hash[key] = s
      s
    end
    def update(active,cast,pulse,animate,origin)
      dt = 1.0/[Graphics.frame_rate,1].max
      @age += dt if animate || cast
      @alpha = [[@alpha+((active || cast) ? dt*4 : -dt*4),0].max,1].min
      w,h = Graphics.width.to_f,Graphics.height.to_f
      scale = w/512.0
      source = origin ? origin[0] : w*0.25
      foot = origin ? origin[1] : h*0.76
      crest = cast ? Math.sin(cast*Math::PI) : 0.0
      tint_exists = defined?(TerrainFloorTint::COLOURS) && TerrainFloorTint::COLOURS.key?(@kind)
      @floor.visible = !tint_exists
      @floor.opacity = (@alpha*(cast ? [cast/0.35,1].min : 1)*255).round
      @ground.each_with_index do |s,i|
        row,col = i/5,i%5
        x = w*(0.06+col*0.225)+(row.odd? ? w*0.035 : 0)
        y = h*(0.47+row*0.13)+Math.sin(i*2.2)*5
        delay = (x-source).abs/w*0.28+row*0.035
        grow = cast ? [[(cast-delay)/0.26,0].max,1].min : 1.0
        size = scale*(0.55+row*0.18)
        s.x,s.y = x,y
        s.zoom_x,s.zoom_y = size,size*(0.25+row*0.025)*grow
        if @kind==:Electric
          flicker = Math.sin(@age*8+i*2.1)**8
          s.opacity = (@alpha*grow*(65+flicker*95+crest*45+pulse*25)).round
        elsif @kind==:Psychic
          s.opacity = (@alpha*grow*(62+Math.sin(@age*1.9+i)**2*45+crest*55)).round
          s.zoom_x *= 0.91+0.09*Math.sin(@age*1.4+i)
        else
          s.x += Math.sin(@age*0.55+i)*18
          s.zoom_x *= 1.45
          s.zoom_y *= 2.9
          s.opacity = (@alpha*grow*(165+crest*65)).round
        end
      end
      @particles.each_with_index do |s,i|
        p = (@age*(@kind==:Electric ? 0.23 : 0.09)+i*0.137)%1.0
        s.x = w*(0.025+(i*0.173)%0.95)+Math.sin(@age*0.7+i)*14
        if cast
          a = i*2.399+cast*(@kind==:Electric ? 2.8 : 1.7)
          r = cast*w*0.73
          s.x = source+Math.cos(a)*r+cast*w*0.22
          s.y = h*0.64+Math.sin(a)*r*0.25-cast*55
        else
          s.y = h*(0.49+(i%4)*0.11)-p*(@kind==:Psychic ? 42 : 20)
        end
        size = scale*(0.20+i%3*0.075)
        size *= @kind==:Electric ? 0.85 : 1.0
        s.zoom_x = s.zoom_y = size
        s.angle = @kind==:Electric ? (i%2)*12 : @age*(@kind==:Misty ? 18 : 25)+i*31
        ambient = @kind==:Electric ? (Math.sin(@age*11+i)>0.78 ? 135 : 0) : 105
        s.opacity = (@alpha*(cast ? crest*(180+35*(i%2)) : Math.sin(p*Math::PI)*ambient)).round
      end
      @beams.each_with_index do |s,i|
        if cast
          s.x = source+(cast*1.55-0.30)*w-i*47*scale
          s.y = h*(0.48+(i%4)*0.13)
          s.opacity = (@alpha*crest*(@kind==:Misty ? 245 : 190)).round
        else
          s.x = ((@age*(@kind==:Misty ? 10 : 16)+i*w/@beams.size)%(w+300*scale))-150*scale
          s.y = h*(0.48+(i%4)*0.13)+Math.sin(@age*0.6+i)*4
          if @kind==:Electric
            flash = Math.sin(@age*3.2+i*2.5)>0.975 ? 150 : 0
            s.opacity = (@alpha*(flash+pulse*70)).round
          else
            s.opacity = (@alpha*(@kind==:Misty ? 145 : 35+pulse*55)).round
          end
        end
        s.zoom_x = scale*(@kind==:Misty ? 1.6 : 1.25)
        s.zoom_y = @kind==:Misty ? 0.85 : 0.55
      end
      @rings.each_with_index do |s,i|
        if cast
          p = [[(cast-i*0.12)/0.68,0].max,1].min
          size = 0.10+p*w/112.0
          s.x,s.y = source,foot-4
          s.zoom_x,s.zoom_y = size,size*0.28
          s.opacity = (@alpha*Math.sin(p*Math::PI)*(@kind==:Misty ? 125 : 200)).round
        elsif @kind==:Psychic
          p = (@age*0.20+i/3.0)%1.0
          size = scale*(0.45+p*1.8)
          s.x,s.y = w*(0.22+i*0.29),h*(0.59+i%2*0.22)
          s.zoom_x,s.zoom_y = size,size*0.26
          s.opacity = (@alpha*Math.sin(p*Math::PI)*95).round
        else
          s.opacity = 0
        end
      end
      @sparks.each_with_index do |s,i|
        p = (@age*0.18+i*0.173)%1.0
        s.x = w*(0.025+(i*0.197)%0.96)+Math.sin(@age+i)*6
        s.y = h*(0.50+i%4*0.11)-p*20
        s.zoom_x = s.zoom_y = scale*(0.12+i%3*0.06)
        s.opacity = (@alpha*Math.sin(p*Math::PI)**2*(cast ? 200 : 85)).round
      end
    end
    def faded?; @alpha<=0.0; end
    def dispose
      return if @disposed
      @disposed = true
      @keys.each { |key| @hash.delete(key) }
      @sprites.reverse_each { |s| s.dispose unless s.disposed? }
      @bitmaps.each { |b| b.dispose unless b.disposed? }
    end
  end
  module SceneHooks
    def pbAnimation(moveID,user,targets,hitNum=0)
      kind = TerrainTrioVisual::MOVES[moveID]
      return super unless kind
      s = user && @sprites["pokemon_#{user.index}"]
      @terrain_trio_origin = s ? [s.x.to_f,s.y.to_f] : nil
      @terrain_trio_requested = kind
      # The engine calls Common:*Terrain after setting the actual field.
    end
    def pbCommonAnimationExists?(name)
      key = name.to_s.gsub(/[^a-z]/i,"").downcase
      return true if TerrainTrioVisual::NAMES[key]
      super
    end
    def pbCommonAnimation(name,user=nil,target=nil)
      key = name.to_s.gsub(/[^a-z]/i,"").downcase
      kind = TerrainTrioVisual::NAMES[key]
      return super unless kind
      requested = @terrain_trio_requested==kind
      @terrain_trio_requested = nil
      if @battle && !@battle.showAnims
        @terrain_trio_origin = nil
        return
      end
      return if @terrain_trio_cast_kind
      full = requested || @terrain_trio_last_cast!=kind
      s = user && user.respond_to?(:index) && @sprites["pokemon_#{user.index}"]
      @terrain_trio_origin ||= s ? [s.x.to_f,s.y.to_f] : nil
      duration = full ? TerrainTrioVisual::CAST_SECONDS : 0.24
      boxes = full ? {} : nil
      @terrain_trio_boxes = boxes
      begin
        if full
          pbTerrainTrioHideHP
          TerrainTrioVisual.play_se(kind)
        end
        second = false
        frames = [(Graphics.frame_rate*duration).round,2].max
        frames.times do |f|
          p = f.to_f/(frames-1)
          @terrain_trio_cast_kind = kind if full
          @terrain_trio_cast_progress = p if full
          @terrain_trio_pulse = full ? 0 : Math.sin(p*Math::PI)
          if full && !second && p>=0.48
            TerrainTrioVisual.play_se(kind,true)
            second = true
          end
          pbUpdate
        end
        if @battle && @battle.field && @battle.field.terrain==kind
          @terrain_trio_last_cast = kind
        end
      ensure
        @terrain_trio_cast_kind = nil
        @terrain_trio_cast_progress = nil
        @terrain_trio_pulse = 0
        @terrain_trio_origin = nil
        @terrain_trio_boxes = nil
        boxes.each_value { |s,v| s.visible=v if s && !s.disposed? } if boxes
      end
    end
    def pbTerrainTrioHideHP
      return unless @terrain_trio_boxes && @sprites
      @sprites.each do |key,s|
        next unless key.to_s.start_with?("dataBox_") && s && !s.disposed?
        @terrain_trio_boxes[s.object_id] ||= [s,s.visible]
        s.visible = false
      end
    end
    def pbGraphicsUpdate
      if @sprites && @viewport && !@viewport.disposed? && @battle
        field = @battle.field && @battle.field.terrain
        active = TerrainTrioVisual::COLOURS.key?(field) ? field : nil
        @terrain_trio_layers ||= {}
        [active,@terrain_trio_cast_kind].compact.uniq.each do |kind|
          @terrain_trio_layers[kind] ||= TerrainTrioVisual::Layer.new(@sprites,@viewport,kind)
        end
        @terrain_trio_layers.keys.each do |kind|
          layer = @terrain_trio_layers[kind]
          cast = @terrain_trio_cast_kind==kind ? @terrain_trio_cast_progress : nil
          layer.update(active==kind,cast,@terrain_trio_pulse.to_f,@battle.showAnims,@terrain_trio_origin)
          if active!=kind && !cast && layer.faded?
            layer.dispose
            @terrain_trio_layers.delete(kind)
          end
        end
        @terrain_trio_last_cast = nil if !active && !@terrain_trio_cast_kind
        pbTerrainTrioHideHP
      end
      super
    end
    def pbDisposeSprites
      if @terrain_trio_layers
        @terrain_trio_layers.each_value(&:dispose)
        @terrain_trio_layers.clear
      end
      super
    end
  end
end
Battle::Scene.prepend(TerrainTrioVisual::SceneHooks)
