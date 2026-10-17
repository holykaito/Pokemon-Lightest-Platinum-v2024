# Colosseum Terrain cast + persistent colosseum battlefield - Pokemon Essentials v21.1.
# Install in Plugins/[KAITO] Plugin/ and recompile. No external graphics.
# Requires the existing Colosseum Terrain gameplay plugin; this file changes visuals only.
# Move: COLOSSEUMTERRAIN. Field: Colosseum (or ColosseumTerrain). Common: ColosseumTerrain.
# Cast hides/restores HP and plays existing SE/Anim sounds. Ambient stays quiet.
module ColosseumTerrainVisual
  VERSION = "1.1"
  CAST_SECONDS = 2.15
  TERRAIN_IDS = [:Colosseum,:ColosseumTerrain]
  def self.active?(battle)
    battle && battle.field && TERRAIN_IDS.include?(battle.field.terrain)
  end
  def self.line(b,x1,y1,x2,y2,width,c)
    n = [(x2-x1).abs.round,(y2-y1).abs.round,1].max
    (0..n).each do |i|
      p = i.to_f/n
      b.fill_rect((x1+(x2-x1)*p).round-width/2,(y1+(y2-y1)*p).round-width/2,width,width,c)
    end
  end
  def self.disc(b,cx,cy,r,c)
    (-r..r).each do |dy|
      dx = Math.sqrt(r*r-dy*dy).floor
      b.fill_rect(cx-dx,cy+dy,dx*2+1,1,c)
    end
  end
  def self.polygon(b,points,c)
    low,high = points.map { |p|p[1] }.minmax
    (low..high).each do |y|
      xs=[]
      points.each_with_index do |p,i|
        q=points[(i+1)%points.length]
        next unless (p[1]<=y && q[1]>y) || (q[1]<=y && p[1]>y)
        xs<<p[0]+(y-p[1]).to_f*(q[0]-p[0])/(q[1]-p[1])
      end
      xs.sort.each_slice(2) { |l,r| b.fill_rect(l.ceil,y,[r.floor-l.ceil+1,1].max,1,c) if r }
    end
  end
  def self.slab(variant)
    b=Bitmap.new(80,48)
    top=[[8,12],[57,5+variant],[73,17],[62,34],[13,37],[3,26]]
    polygon(b,top.map { |x,y|[x,y+6] },Color.new(62,43,34,165))
    polygon(b,top,Color.new(151+variant*9,112+variant*8,78+variant*6,195))
    polygon(b,[[8,12],[57,5+variant],[66,14],[14,21]],Color.new(207,166,113,125))
    line(b,8,12,57,5+variant,1,Color.new(245,206,148,220))
    line(b,8,12,3,26,1,Color.new(227,184,130,180))
    line(b,13,37,62,34,2,Color.new(77,53,37,175))
    line(b,42,12,36,23,1,Color.new(92,65,45,145))
    line(b,36,23,41,31,1,Color.new(92,65,45,145))
    14.times do |i|
      x=12+(i*17)%47;y=16+(i*11)%15
      b.fill_rect(x,y,2,1,Color.new(234,192,135,75))
    end
    b
  end
  def self.assets
    floor=Bitmap.new(256,192)
    bed=Bitmap.new(256,192)
    192.times do |y|
      depth=[[(y/192.0-0.12)/0.55,0].max,1].min
      floor.fill_rect(0,y,256,1,Color.new(177,111,67,(depth*depth*(3-2*depth)*255).round))
      next if y<28
      256.times do |x|
        noise=Math.sin(x*0.13+y*0.23)*Math.sin(x*0.032-y*0.075)
        bed.fill_rect(x,y,1,1,Color.new(126,88,59,(noise.abs*depth*30).round))
      end
    end
    arena=Bitmap.new(256,256)
    [[79,108,20],[109,121,24]].each do |inner,outer,count|
      count.times do |i|
        start=i*Math::PI*2/count+0.018
        finish=(i+1)*Math::PI*2/count-0.018
        outer_arc=(0..5).map { |j|a=start+(finish-start)*j/5.0;[(128+Math.cos(a)*outer).round,(128+Math.sin(a)*outer).round] }
        inner_arc=(0..5).map { |j|a=finish-(finish-start)*j/5.0;[(128+Math.cos(a)*inner).round,(128+Math.sin(a)*inner).round] }
        shade=i%3*10
        polygon(arena,outer_arc+inner_arc,Color.new(170+shade,121+shade,77+shade,160))
        (outer_arc+inner_arc+[outer_arc[0]]).each_cons(2) do |p,q|
          line(arena,*p,*q,1,Color.new(239,191,128,190))
        end
      end
    end
    # Broken inner scoring lines radiate outward through the arena floor.
    12.times do |i|
      a=i*Math::PI/6
      points=[[Math.cos(a)*29,Math.sin(a)*29],[Math.cos(a+0.04)*49,Math.sin(a+0.04)*49],[Math.cos(a)*75,Math.sin(a)*75]].map { |x,y|[128+x,128+y] }
      points.each_cons(2) { |p,q|line(arena,*p,*q,1,Color.new(238,170,83,125)) }
    end
    dust=Bitmap.new(160,48)
    24.times do |row|
      40.times do |col|
        x,y=col*4,row*2
        v=Math.exp(-((x-80)/54.0)**2-((y-27-Math.sin(x*0.045)*3)/10.0)**2)
        dust.fill_rect(x,y,4,2,Color.new(213,173,120,(v*43).round))
      end
    end
    chip=Bitmap.new(12,14)
    polygon(chip,[[5,1],[10,5],[9,10],[3,12],[1,7]],Color.new(102,73,48,225))
    polygon(chip,[[5,1],[10,5],[5,7],[1,7]],Color.new(230,187,126,245))
    spark=Bitmap.new(8,20)
    18.times do |y|
      alpha=(Math.sin(y/17.0*Math::PI)*220).round
      spark.fill_rect(3,y+1,2,1,Color.new(255,207,118,alpha))
    end
    ring=Bitmap.new(128,128)
    360.times do |i|
      next if i%30>23
      a=i*Math::PI/180
      ring.fill_rect((64+Math.cos(a)*52).round,(64+Math.sin(a)*52).round,2,2,Color.new(251,197,111,205))
    end
    [floor,bed,arena,dust,chip,spark,ring,slab(0),slab(1),slab(2)]
  end
  def self.play_se(second=false)
    names=second ? ["PRSFX- Bulk Up1","PRSFX- Focus Energy"] : ["PRSFX- Rock Tomb","PRSFX- Ancient Power1"]
    names.each do |name|
      next unless [".wav",".ogg",".mp3"].any? { |ext|File.file?("Audio/SE/Anim/#{name}#{ext}") }
      pbSEPlay("Anim/#{name}",second ? 55 : 72,second ? 95 : 90)
      break
    end
  end
  class Layer
    def initialize(hash,viewport)
      @hash,@viewport=hash,viewport
      @sprites,@bitmaps,@keys=[],[],[]
      @age,@alpha=0.0,0.0
      @disposed=false
      begin
        @bitmaps.concat(ColosseumTerrainVisual.assets)
        floor,bed,arena,dust,chip,spark,ring=@bitmaps[0,7]
        @floor=make(floor,0,0,2);@bed=make(bed,0,0,3)
        [@floor,@bed].each { |s|s.zoom_x,s.zoom_y=Graphics.width/256.0,Graphics.height/192.0 }
        @arena=make(arena,128,128,4)
        @slabs=Array.new(32) { |i|make(@bitmaps[7+i%3],40,24,5) }
        @dust=Array.new(8) {make(dust,80,24,7)}
        @chips=Array.new(36) {make(chip,6,7,9)}
        @sparks=Array.new(24) {make(spark,4,10,8)}
        @rings=Array.new(3) {make(ring,64,64,7)}
      rescue
        dispose
        raise
      end
    end
    def make(bitmap,ox,oy,z)
      s=Sprite.new(@viewport);@sprites<<s
      s.bitmap,s.ox,s.oy,s.z=bitmap,ox,oy,z;s.opacity=0
      key="colosseum_terrain_visual_#{object_id}_#{@keys.length}"
      @keys<<key;@hash[key]=s;s
    end
    def update(active,cast,pulse,animate)
      dt=1.0/[Graphics.frame_rate,1].max
      @age+=dt if animate || cast
      @alpha=[[@alpha+((active || cast) ? dt*3.2 : -dt*3.2),0].max,1].min
      w,h=Graphics.width.to_f,Graphics.height.to_f
      sx,sy=w/512.0,h/384.0
      crest=cast ? Math.sin(cast*Math::PI) : 0.0
      spread=cast ? [[cast/0.55,0].max,1].min : 1.0
      shared_tint=defined?(TerrainFloorTint::COLOURS) && ColosseumTerrainVisual::TERRAIN_IDS.any? { |id|TerrainFloorTint::COLOURS.key?(id) }
      @floor.opacity=shared_tint ? 0 : (@alpha*(75+crest*20)).round
      @bed.opacity=(@alpha*spread*190).round
      @arena.x,@arena.y=w*0.5,h*0.59
      @arena.zoom_x,@arena.zoom_y=sx*(2.45+crest*0.05),sy*1.38
      @arena.opacity=(@alpha*spread*(205+crest*35)).round
      @slabs.each_with_index do |s,i|
        row=i/4;depth=row/7.0
        x=w*(0.03+(i%4)*0.32+(row.odd? ? 0.07 : -0.03))
        y=h*(0.22+depth*0.74)+Math.sin(i*2.4)*3*sy
        reveal=cast ? [[(cast-i%4*0.025-depth*0.08)/0.53,0].max,1].min : 1.0
        lift=cast ? Math.sin(reveal*Math::PI)*(10+depth*10)*sy : 0
        s.x,s.y=x,y-lift
        s.zoom_x=sx*(0.60+depth*0.44)
        s.zoom_y=sy*(0.40+depth*0.40)
        s.mirror=i.odd?;s.angle=Math.sin(i*2.1)*5
        s.opacity=(@alpha*reveal*(120+depth*45)).round
      end
      @dust.each_with_index do |s,i|
        s.x=((@age*(8+i%3*3)+i*w/5)%(w+220*sx))-110*sx
        s.y=h*(0.25+i%4*0.22)+Math.sin(@age*0.5+i)*2*sy
        s.zoom_x,s.zoom_y=sx*(1.5+i%2*0.3),sy*(0.38+i%3*0.08)
        s.opacity=(@alpha*spread*(55+crest*145+pulse*15)).round
      end
      @chips.each_with_index do |s,i|
        p=cast ? [[(cast-0.14-i%6*0.025)/0.60,0].max,1].min : 1.0
        x=w*(0.025+(i*0.197)%0.95)
        y=h*(0.24+(i%5)*0.17)
        s.x=x+Math.sin(i*2.399)*p*22*sx
        s.y=y-Math.sin(p*Math::PI)*(18+i%4*9)*sy
        size=0.25+i%4*0.065
        s.zoom_x,s.zoom_y=sx*size,sy*size
        s.angle=i*31+p*160
        s.opacity=cast ? (@alpha*Math.sin(p*Math::PI)*225).round : 0
      end
      @sparks.each_with_index do |s,i|
        p=(@age*0.32+i*0.61803398875)%1.0
        s.x=w*(0.02+(i*0.219)%0.96)+Math.sin(i)*p*7*sx
        s.y=h*(0.25+i%4*0.22)-p*(10+crest*28)*sy
        s.zoom_x,s.zoom_y=sx*0.55,sy*(0.22+i%3*0.12)
        s.opacity=(@alpha*spread*Math.sin(p*Math::PI)**3*(35+crest*170+pulse*20)).round
      end
      @rings.each_with_index do |s,i|
        if cast
          p=[[(cast-i*0.12)/0.66,0].max,1].min
          size=sx*(0.15+p*6)
          s.x,s.y=w*0.5,h*0.59
          s.zoom_x,s.zoom_y=size,size*0.46*sy/sx
          s.opacity=(@alpha*Math.sin(p*Math::PI)*210).round
        else
          s.opacity=0
        end
      end
    end
    def faded?;@alpha<=0.0;end
    def dispose
      return if @disposed
      @disposed=true
      @keys.each { |key|@hash.delete(key) }
      @sprites.reverse_each { |s|s.dispose unless s.disposed? }
      @bitmaps.each { |b|b.dispose unless b.disposed? }
    end
  end
  module SceneHooks
    def pbAnimation(moveID,user,targets,hitNum=0)
      return super unless moveID==:COLOSSEUMTERRAIN
      @colosseum_terrain_visual_requested=true
      # pbStartTerrain calls Common:ColosseumTerrain after setting the field; cast once.
    end
    def pbCommonAnimationExists?(name)
      return true if ["colosseumterrain"].include?(name.to_s.gsub(/[^a-z]/i,"").downcase)
      super
    end
    def pbCommonAnimation(name,user=nil,target=nil)
      key=name.to_s.gsub(/[^a-z]/i,"").downcase
      return super unless ["colosseumterrain"].include?(key)
      requested=@colosseum_terrain_visual_requested
      @colosseum_terrain_visual_requested=false
      return if @battle && !@battle.showAnims
      return if @colosseum_terrain_visual_cast
      kind=:Colosseum
      full=requested || @colosseum_terrain_visual_last_cast!=kind
      duration=full ? ColosseumTerrainVisual::CAST_SECONDS : 0.24
      boxes=full ? {} : nil
      @colosseum_terrain_visual_boxes=boxes
      begin
        if full
          pbColosseumTerrainVisualHideHP
          ColosseumTerrainVisual.play_se
        end
        second=false
        @colosseum_terrain_visual_cast_kind=kind
        frames=[(Graphics.frame_rate*duration).round,2].max
        frames.times do |f|
          p=f.to_f/(frames-1)
          @colosseum_terrain_visual_cast=p if full
          @colosseum_terrain_visual_pulse=full ? 0 : Math.sin(p*Math::PI)
          if full && !second && p>=0.48
            ColosseumTerrainVisual.play_se(true)
            second=true
          end
          pbUpdate
        end
        @colosseum_terrain_visual_last_cast=kind if ColosseumTerrainVisual.active?(@battle)
      ensure
        @colosseum_terrain_visual_cast=nil
        @colosseum_terrain_visual_cast_kind=nil
        @colosseum_terrain_visual_pulse=0
        @colosseum_terrain_visual_boxes=nil
        boxes.each_value { |s,v|s.visible=v if s && !s.disposed? } if boxes
      end
    end
    def pbColosseumTerrainVisualHideHP
      return unless @colosseum_terrain_visual_boxes && @sprites
      @sprites.each do |key,s|
        next unless key.to_s.start_with?("dataBox_") && s && !s.disposed?
        @colosseum_terrain_visual_boxes[s.object_id]||=[s,s.visible]
        s.visible=false
      end
    end
    def pbGraphicsUpdate
      if @sprites && @viewport && !@viewport.disposed? && @battle
        active=ColosseumTerrainVisual.active?(@battle)
        if active || @colosseum_terrain_visual_cast || @colosseum_terrain_visual_layer
          @colosseum_terrain_visual_layer||=ColosseumTerrainVisual::Layer.new(@sprites,@viewport)
          @colosseum_terrain_visual_layer.update(active,@colosseum_terrain_visual_cast,@colosseum_terrain_visual_pulse.to_f,@battle.showAnims)
          if !active && !@colosseum_terrain_visual_cast && @colosseum_terrain_visual_layer.faded?
            @colosseum_terrain_visual_layer.dispose
            @colosseum_terrain_visual_layer=nil
          end
        end
        @colosseum_terrain_visual_last_cast=nil if !active && !@colosseum_terrain_visual_cast
        pbColosseumTerrainVisualHideHP
      end
      super
    end
    def pbDisposeSprites
      if @colosseum_terrain_visual_layer
        @colosseum_terrain_visual_layer.dispose
        @colosseum_terrain_visual_layer=nil
      end
      super
    end
  end
end
Battle::Scene.prepend(ColosseumTerrainVisual::SceneHooks)
