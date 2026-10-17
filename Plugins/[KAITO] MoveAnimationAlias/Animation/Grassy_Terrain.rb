# Grassy Terrain - Pokemon Essentials v21.1
# Procedural pixel art, no PNGs or PBS edits. Put in an existing plugin folder.
# Replaces the move and common terrain animations, adds a persistent meadow.
# The existing engine still controls terrain duration, healing and damage.
module GrassyTerrainVisual
  CAST_SECONDS = 1.90

  def self.polygon(b, points, c)
    low,high = points.map { |p| p[1] }.minmax
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

  def self.line(b,x1,y1,x2,y2,width,c)
    count = [(x2-x1).abs.round,(y2-y1).abs.round,1].max
    (0..count).each do |i|
      p = i.to_f/count
      b.fill_rect((x1+(x2-x1)*p).round-width/2,(y1+(y2-y1)*p).round-width/2,width,width,c)
    end
  end

  def self.floor
    b = Bitmap.new(256,192)
    192.times do |y|
      a = y < 78 ? 8 : [14+(y-78)*0.65,86].min.round
      b.fill_rect(0,y,256,1,Color.new(42,105,47,a))
    end
    b
  end

  def self.grass
    b = Bitmap.new(40,32)
    polygon(b,[[18,31],[10,18],[4,12],[10,14],[18,22],[15,9],[17,2],
               [21,13],[23,25],[28,12],[36,7],[31,18],[26,31]],Color.new(42,110,58,215))
    polygon(b,[[19,29],[13,17],[17,22],[18,8],[20,17],[21,29]],Color.new(119,196,79,235))
    polygon(b,[[24,29],[28,17],[33,12],[29,23],[27,29]],Color.new(161,216,101,215))
    b
  end

  def self.leaf
    b = Bitmap.new(32,24)
    polygon(b,[[3,18],[7,8],[16,3],[29,3],[25,14],[16,20]],Color.new(93,175,78,225))
    polygon(b,[[6,16],[16,5],[26,5],[18,12]],Color.new(190,225,116,235))
    line(b,4,20,25,6,1,Color.new(226,242,165,200))
    b
  end

  def self.spark
    b = Bitmap.new(16,16)
    b.fill_rect(7,1,2,14,Color.new(250,247,180,190))
    b.fill_rect(1,7,14,2,Color.new(250,247,180,190))
    b.fill_rect(6,6,4,4,Color.new(255,255,231,245))
    b
  end

  def self.wind
    b = Bitmap.new(256,80)
    3.times do |j|
      last = nil
      100.times do |i|
        x = 5+i*2
        y = (38+Math.sin(i/99.0*Math::PI*1.4+j*0.2)*12+j*6).round
        if last
          line(b,last[0],last[1],x,y,2,Color.new(196,239,150,(Math.sin(i/100.0*Math::PI)*140).round))
        end
        last = [x,y]
      end
    end
    b
  end

  class Layer
    def initialize(hash,viewport)
      @hash,@viewport = hash,viewport
      @sprites,@bitmaps,@keys = [],[],[]
      @alpha,@age = 0.0,0.0
      @settled,@disposed = false,false
      begin
        floor,grass,leaf,spark,wind = GrassyTerrainVisual.floor,GrassyTerrainVisual.grass,
          GrassyTerrainVisual.leaf,GrassyTerrainVisual.spark,GrassyTerrainVisual.wind
        @bitmaps.concat([floor,grass,leaf,spark,wind])
        @floor = make(floor,0,0,2)
        @floor.zoom_x,@floor.zoom_y = Graphics.width/256.0,Graphics.height/192.0
        @grass = Array.new(24) { make(grass,20,30,4) }
        @leaves = Array.new(14) { make(leaf,16,12,7) }
        @lights = Array.new(14) do
          s = make(spark,8,8,8)
          s.blend_type = 1
          s
        end
        @wind = Array.new(3) do
          s = make(wind,128,40,6)
          s.blend_type = 1
          s
        end
      rescue
        dispose
        raise
      end
    end

    def make(bitmap,ox,oy,z)
      s = Sprite.new(@viewport)
      @sprites << s
      s.bitmap,s.ox,s.oy,s.z = bitmap,ox,oy,z
      key = "grassy_terrain_visual_#{object_id}_#{@keys.length}"
      @keys << key
      @hash[key] = s
      s
    end

    def update(active,cast,pulse,animate,origin)
      dt = 1.0/[Graphics.frame_rate,1].max
      @age += dt if animate || cast
      @alpha = [[@alpha+((active || cast) ? dt*4 : -dt*4),0].max,1].min
      w,h = Graphics.width.to_f,Graphics.height.to_f
      source = origin ? origin[0] : w*0.25
      @floor.opacity = (@alpha*(cast && !@settled ? [cast/0.65,1].min : 1)*255).round
      @grass.each_with_index do |s,i|
        row,col = i/6,i%6
        x = w*(0.035+col*0.19)+(row.odd? ? 10 : 0)
        y = h*(0.48+row*0.105)+Math.sin(i*2.2)*5
        growth = 1.0
        if cast && !@settled
          delay = (x-source).abs/w*0.32+row*0.035
          p = [[(cast-delay)/0.32,0].max,1].min
          growth = 1-(1-p)**3
        end
        scale = w/512.0*(0.47+row*0.19)
        s.x,s.y = x,y
        s.zoom_x = scale
        s.zoom_y = scale*growth
        s.angle = Math.sin(@age*2+i*0.8)*4
        s.opacity = (@alpha*(140+row*22+pulse*20)).round
      end
      @leaves.each_with_index do |s,i|
        if cast
          a = i*2.399+cast*5
          spread = 20+cast*w*0.55
          s.x = source+Math.cos(a)*spread+cast*w*0.26
          s.y = h*0.62+Math.sin(a)*spread*0.35-cast*65
          s.opacity = (@alpha*Math.sin(cast*Math::PI)*210).round
        else
          p = (@age*0.065+i*0.137)%1
          s.x = w*(1.15-p*1.30)+Math.sin(@age+i)*9
          s.y = h*(0.20+(i%4)*0.14)+Math.sin(p*6.28+i)*16
          s.opacity = (@alpha*Math.sin(p*Math::PI)*130).round
        end
        s.zoom_x = s.zoom_y = w/512.0*(0.28+(i%3)*0.09)
        s.angle = @age*32+i*28
        s.z = 7
      end
      @lights.each_with_index do |s,i|
        p = (@age*0.13+i*0.173)%1
        s.x = w*(0.04+(i*0.197)%0.94)+Math.sin(@age+i)*9
        s.y = h*(0.54+(i%3)*0.12)-p*27
        s.zoom_x = s.zoom_y = 0.14+(i%3)*0.08
        s.opacity = (@alpha*Math.sin(p*Math::PI)**2*(cast ? 195 : 100)).round
      end
      @wind.each_with_index do |s,i|
        if cast
          s.x = source+(cast*1.5-0.25)*w-i*55
          s.opacity = (@alpha*Math.sin(cast*Math::PI)*200).round
        else
          s.x = ((@age*18+i*w/3)%(w+280))-140
          s.opacity = (@alpha*(35+pulse*65)).round
        end
        s.y = h*(0.47+i*0.16)
        s.zoom_x = w/512.0*1.25
        s.zoom_y = 0.60
      end
      @settled = true if active && !cast
    end

    def faded?; @alpha <= 0; end
    def dispose
      return if @disposed
      @disposed = true
      @keys.each { |key| @hash.delete(key) }
      @sprites.reverse_each { |s| s.dispose unless s.disposed? }
      @bitmaps.each { |b| b.dispose unless b.disposed? }
    end
  end

  module SceneHooks
    def pbAnimation(moveID,user,targets,hitNum = 0)
      return super unless moveID == :GRASSYTERRAIN
      # pbStartTerrain calls Common:GrassyTerrain immediately after this.
      # Run the replacement there once, also supporting Grassy Surge.
      s = user && @sprites["pokemon_#{user.index}"]
      @grassy_visual_origin = s ? [s.x.to_f,s.y.to_f] : nil
      @grassy_visual_cast_requested = true
    end

    def pbCommonAnimation(name,user = nil,target = nil)
      return super unless name.to_s.gsub(/[^a-z]/i,"").downcase == "grassyterrain"
      return if @battle && !@battle.showAnims
      full = @grassy_visual_cast_requested || !@grassy_visual_layer || !@grassy_visual_seen_active
      @grassy_visual_cast_requested = false
      duration = full ? GrassyTerrainVisual::CAST_SECONDS : 0.26
      frames = [(Graphics.frame_rate*duration).round,2].max
      begin
        frames.times do |f|
          p = f.to_f/(frames-1)
          @grassy_visual_cast = p if full
          @grassy_visual_pulse = Math.sin(p*Math::PI)
          pbUpdate
        end
      ensure
        @grassy_visual_cast = nil
        @grassy_visual_pulse = 0
        @grassy_visual_origin = nil
      end
    end

    def pbGraphicsUpdate
      if @sprites && @viewport && !@viewport.disposed? && @battle
        active = @battle.field && @battle.field.terrain == :Grassy
        if active || @grassy_visual_cast || @grassy_visual_layer
          @grassy_visual_layer ||= GrassyTerrainVisual::Layer.new(@sprites,@viewport)
          @grassy_visual_layer.update(active,@grassy_visual_cast,@grassy_visual_pulse.to_f,
                                      @battle.showAnims,@grassy_visual_origin)
          if !active && !@grassy_visual_cast && @grassy_visual_layer.faded?
            @grassy_visual_layer.dispose
            @grassy_visual_layer = nil
          end
        end
        @grassy_visual_seen_active = active
      end
      super
    end

    def pbDisposeSprites
      if @grassy_visual_layer
        @grassy_visual_layer.dispose
        @grassy_visual_layer = nil
      end
      super
    end
  end
end
Battle::Scene.prepend(GrassyTerrainVisual::SceneHooks)
