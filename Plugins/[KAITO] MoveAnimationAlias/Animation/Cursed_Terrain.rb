# Cursed Terrain v5 - animated spectral flames - restrained procedural pixel effects.
# Matches the code-drawn move animations; no embedded or external images.
# Pokemon Essentials v21.1. Put this single .rb in an existing plugin folder.
# Supports field IDs :Cursed (custom plugin) and :Ghost (terrain registration).
# Does not create terrain, change duration, damage, abilities or healing rules.
module CursedTerrainVisual
  MOVE_ID = :CURSEDTERRAIN
  CAST_SECONDS = 1.65
  TERRAIN_IDS = [:Cursed, :Ghost, :CursedTerrain]

  def self.active?(battle)
    return false unless battle && battle.field
    return true if TERRAIN_IDS.include?(battle.field.terrain)
    return CursedTerrain.active?(battle) if defined?(CursedTerrain) && CursedTerrain.respond_to?(:active?)
    false
  end

  def self.line(b, x1, y1, x2, y2, width, color)
    steps = [(x2-x1).abs.round, (y2-y1).abs.round, 1].max
    (0..steps).each do |i|
      p = i.to_f / steps
      b.fill_rect((x1+(x2-x1)*p).round-width/2, (y1+(y2-y1)*p).round-width/2, width, width, color)
    end
  end

  def self.ellipse(b, cx, cy, rx, ry, color)
    (-ry..ry).each do |y|
      dx = (rx * Math.sqrt([1-y*y.to_f/(ry*ry), 0].max)).floor
      b.fill_rect(cx-dx, cy+y, dx*2+1, 1, color)
    end
  end

  def self.polygon(b, points, color)
    low, high = points.map { |p| p[1] }.minmax
    (low..high).each do |y|
      xs = []
      points.each_with_index do |p, i|
        q = points[(i+1)%points.length]
        next unless (p[1] <= y && q[1] > y) || (q[1] <= y && p[1] > y)
        xs << p[0]+(y-p[1]).to_f*(q[0]-p[0])/(q[1]-p[1])
      end
      xs.sort.each_slice(2) do |l,r|
        b.fill_rect(l.ceil, y, [r.floor-l.ceil+1,1].max, 1, color) if r
      end
    end
  end

  def self.floor
    b = Bitmap.new(256,192)
    # Continuous full-scene tint: no horizon seam or replacement background.
    128.times do |i|
      edge = ((i-63.5).abs/63.5*13).round
      96.times do |j|
        alpha = (48+j/95.0*62+edge).round
        b.fill_rect(i*2,j*2,2,2,Color.new(38,10,58,alpha))
      end
    end
    b
  end

  def self.scar
    b = Bitmap.new(64,32)
    polygon(b, [[3,16],[15,12],[23,5],[29,13],[40,10],[48,17],
                [61,15],[46,24],[33,19],[17,24]], Color.new(18,8,30,150))
    [[9,16,21,13],[21,13,24,10],[24,10,29,16],[29,16,40,15],
     [40,15,47,20],[47,20,55,18]].each do |p|
      line(b,p[0],p[1],p[2],p[3],3,Color.new(108,50,149,130))
      line(b,p[0],p[1],p[2],p[3],1,Color.new(198,125,234,230))
    end
    b
  end

  def self.mist
    b = Bitmap.new(192,64)
    6.downto(1) do |j|
      [[40,37,28,4],[83,30,37,8],[131,35,38,6],[164,40,20,3]].each do |x,y,rx,ry|
        ellipse(b,x,y,rx+j,ry+j,Color.new(93,48,126,5))
      end
    end
    b
  end

  def self.wisp(frame = 0)
    b = Bitmap.new(64,80)
    bend = [-5,0,6,1][frame%4]
    # Four flame frames, with bending tips and a dark spirit at the centre.
    4.downto(1) do |j|
      ellipse(b,32,43,18+j*2,24+j*2,Color.new(148,65,195,4))
    end
    polygon(b,[[30+bend,3],[28+bend,21],[20,30],[13-bend/2,14],
               [15,39],[7,49],[14,64],[28,74],[43,69],[55,55],
               [48,38],[49+bend,20],[39,34],[34,23]],Color.new(111,53,166,215))
    polygon(b,[[31+bend,14],[27,33],[21,42],[19,31],[18,48],
               [14,52],[22,64],[34,69],[46,59],[46,47],
               [41,37],[39,48],[34,38]],Color.new(199,137,243,235))
    polygon(b,[[29,31],[21,45],[23,60],[33,65],[43,54],[39,40],
               [34,45]],Color.new(25,13,46,235))
    line(b,24,46,29,49,2,Color.new(252,206,255,245))
    line(b,35,49,40,45,2,Color.new(252,206,255,245))
    line(b,17,53,21,60,2,Color.new(240,211,255,225))
    return b
  end

  def self.spirit_position(age,i,w,h)
    phase = i*2.399
    x = w*(0.07+(i*0.217)%0.86)+Math.sin(age*(1.15+(i%3)*0.13)+phase)*(22+(i%3)*10)
    y = h*(0.19+(i%3)*0.23)+Math.sin(age*1.7+phase)*21+Math.cos(age*2.3+i)*6
    [x,y]
  end

  # The original custom module replays the move every end of round. Replace
  # only that visual helper with a short pulse; keep all gameplay methods.
  module FieldPulse
    def play_field_animation(battle)
      return super unless battle && battle.scene.respond_to?(:pbCursedTerrainPulse)
      battle.scene.pbCursedTerrainPulse
      true
    end
  end

  def self.install_field_pulse
    return unless defined?(CursedTerrain) && CursedTerrain.respond_to?(:play_field_animation)
    sc = CursedTerrain.singleton_class
    sc.prepend(FieldPulse) unless sc.ancestors.include?(FieldPulse)
  end

  class Layer
    def initialize(scene_sprites, viewport)
      @scene_sprites, @viewport = scene_sprites, viewport
      @sprites, @bitmaps, @keys = [], [], []
      @age, @alpha = 0.0, 0.0
      @disposed, @settled = false, false
      begin
        floor_b, scar_b = CursedTerrainVisual.floor, CursedTerrainVisual.scar
        mist_b = CursedTerrainVisual.mist
        @wisp_frames = Array.new(4) { |i| CursedTerrainVisual.wisp(i) }
        wisp_b = @wisp_frames[0]
        @bitmaps.concat([floor_b,scar_b,mist_b]+@wisp_frames)
        @tiles = Array.new(16) do |i|
          s = make(floor_b,0,0,2)
          s.src_rect.set(i*16,0,16,192)
          s.x = Graphics.width*i/16.0
          s.zoom_x = Graphics.width/256.0
          s.zoom_y = Graphics.height/192.0
          s
        end
        @scars = Array.new(8) { make(scar_b,32,16,4) }
        @mist = Array.new(12) { make(mist_b,96,32,5) }
        @wisps = Array.new(10) { make(wisp_b,32,44,7) }
        @tails = Array.new(10) do
          Array.new(2) do
            t = make(wisp_b,32,44,6)
            t.blend_type = 1
            t
          end
        end
        @waves = Array.new(6) { make(mist_b,96,32,7) }
      rescue
        dispose
        raise
      end
    end

    def make(bitmap, ox, oy, z)
      s = Sprite.new(@viewport)
      @sprites << s
      s.bitmap,s.ox,s.oy,s.z = bitmap,ox,oy,z
      key = "cursed_terrain_visual_#{object_id}_#{@keys.length}"
      @keys << key
      @scene_sprites[key] = s
      s
    end

    def update(active, cast, pulse, animate, origin = nil)
      dt = 1.0/[Graphics.frame_rate,1].max
      @age += dt if animate || cast
      @alpha = [[@alpha+((active || cast) ? dt*5 : -dt*4),0].max,1].min
      w,h = Graphics.width.to_f,Graphics.height.to_f
      source = origin ? origin[0] : w*0.25
      @tiles.each_with_index do |s,i|
        reveal = 1.0
        if cast && !@settled
          distance = ((i+0.5)*w/16-source).abs/[source,w-source,1].max
          p = [[(cast-distance*0.48)/0.32,0].max,1].min
          reveal = p*p*(3-2*p)
        end
        s.opacity = (@alpha*reveal*255).round
      end
      strength = cast ? [cast/0.5,1].min : 1
      @scars.each_with_index do |s,i|
        row,col = i/4,i%4
        s.x = w*(0.10+col*0.25)+(row == 0 ? 12 : -6)
        s.y = h*(row == 0 ? 0.57 : 0.77)+Math.sin(i*2.4)*9
        s.zoom_x = w/512.0*(row == 0 ? 0.80 : 1.05)
        s.zoom_y = s.zoom_x*(0.75+0.07*Math.sin(@age*2+i))
        s.opacity = (@alpha*strength*(195+35*Math.sin(@age*2.2+i)+pulse*50)).round
      end
      @mist.each_with_index do |s,i|
        row,col = i/3,i%3
        s.x = w*(-0.05+col*0.52)+Math.sin(@age*0.32+i*1.7)*20
        s.y = h*(0.15+row*0.21)+Math.sin(@age*0.5+i)*4
        s.zoom_x = w/512.0*(1.65+row*0.08)
        s.zoom_y = 0.60+row*0.08
        s.opacity = (@alpha*strength*(85+row*8+12*Math.sin(@age+i))).round
      end
      @wisps.each_with_index do |s,i|
        frame = ((@age*8).floor+i)%4
        raw_x,raw_y = CursedTerrainVisual.spirit_position(@age,i,w,h)
        x,y = raw_x,raw_y
        if cast
          travel = 1-(1-[cast/0.70,1].min)**3
          source_y = origin ? origin[1] : h*0.76
          x = source+(x-source)*travel
          y = source_y+(y-source_y)*travel-Math.sin(cast*Math::PI)*(10+i%3*10)
        end
        s.bitmap = @wisp_frames[frame]
        s.x,s.y = x,y
        scale = w/512.0*(0.50+(i%3)*0.12)
        s.zoom_x = scale*(1+0.05*Math.sin(@age*5+i))
        s.zoom_y = scale*(1+0.12*Math.sin(@age*6+i))
        s.angle = Math.sin(@age*1.5+i)*10
        s.opacity = (@alpha*strength*(205+28*Math.sin(@age*4+i))).round
        @tails[i].each_with_index do |tail,j|
          px,py = CursedTerrainVisual.spirit_position(@age-(j+1)*0.10,i,w,h)
          tail.x = x+(px-raw_x)
          tail.y = y+(py-raw_y)+(j+1)*5
          tail.bitmap = @wisp_frames[(frame+j+1)%4]
          tail.zoom_x = scale*(0.70-j*0.17)
          tail.zoom_y = scale*(0.85-j*0.15)
          tail.angle = s.angle+(j+1)*5
          tail.opacity = (@alpha*strength*(65-j*25)).round
        end
      end
      @waves.each_with_index do |s,i|
        s.visible = !!cast
        next unless cast
        row,side = i/2,i%2
        s.x = source+(side == 0 ? -1 : 1)*cast*w*0.85
        s.y = h*(0.19+row*0.23)
        s.zoom_x = w/512.0*(1.3+cast*1.5)
        s.zoom_y = 0.9
        s.opacity = (@alpha*Math.sin(cast*Math::PI)*190).round
      end
      @settled = true if active && !cast
    end

    def faded?; @alpha <= 0; end
    def dispose
      return if @disposed
      @disposed = true
      @keys.each { |k| @scene_sprites.delete(k) }
      @sprites.reverse_each { |s| s.dispose unless s.disposed? }
      @bitmaps.each { |b| b.dispose unless b.disposed? }
    end
  end

  module SceneHooks
    def pbAnimation(moveID, user, targets, hitNum = 0)
      return super unless moveID == CursedTerrainVisual::MOVE_ID
      return if @battle && !@battle.showAnims
      CursedTerrainVisual.install_field_pulse
      caster = user && @sprites["pokemon_#{user.index}"]
      @cursed_visual_origin = caster ? [caster.x.to_f,caster.y.to_f] : nil
      frames = [(Graphics.frame_rate*CursedTerrainVisual::CAST_SECONDS).round, 2].max
      begin
        frames.times do |f|
          @cursed_visual_cast = f.to_f/(frames-1)
          @cursed_visual_pulse = Math.sin(@cursed_visual_cast*Math::PI)
          pbUpdate
        end
      ensure
        @cursed_visual_cast = nil
        @cursed_visual_origin = nil
        @cursed_visual_pulse = 0
      end
    end

    def pbCommonAnimation(name, user = nil, target = nil)
      key = name.to_s.gsub(/[^a-z]/i, "").downcase
      return super unless ["cursedterrain", "cursedterrainfield"].include?(key)
      pbCursedTerrainPulse
    end

    def pbCursedTerrainPulse
      return if @battle && !@battle.showAnims
      frames = [(Graphics.frame_rate*0.28).round, 2].max
      begin
        frames.times do |f|
          @cursed_visual_pulse = Math.sin(f.to_f/(frames-1)*Math::PI)
          pbUpdate
        end
      ensure
        @cursed_visual_pulse = 0
      end
    end

    def pbGraphicsUpdate
      CursedTerrainVisual.install_field_pulse
      if @sprites && @viewport && !@viewport.disposed? && @battle
        active = CursedTerrainVisual.active?(@battle)
        cast = @cursed_visual_cast
        if active || cast || @cursed_visual_layer
          @cursed_visual_layer ||= CursedTerrainVisual::Layer.new(@sprites, @viewport)
          @cursed_visual_layer.update(active, cast, @cursed_visual_pulse.to_f, @battle.showAnims, @cursed_visual_origin)
          if !active && !cast && @cursed_visual_layer.faded?
            @cursed_visual_layer.dispose
            @cursed_visual_layer = nil
          end
        end
      end
      super
    end

    def pbDisposeSprites
      if @cursed_visual_layer
        @cursed_visual_layer.dispose
        @cursed_visual_layer = nil
      end
      super
    end
  end
end
Battle::Scene.prepend(CursedTerrainVisual::SceneHooks)
