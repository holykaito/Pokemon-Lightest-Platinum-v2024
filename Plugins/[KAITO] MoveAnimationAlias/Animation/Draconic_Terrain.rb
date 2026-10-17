# Draconic Terrain cast + persistent draconic battlefield - Pokemon Essentials v21.1.
# Install in Plugins/[KAITO] Plugin/ and recompile. No external graphics.
# Requires the existing Draconic Terrain gameplay plugin; this file changes visuals only.
# Move: DRACONICTERRAIN. Field: Draconic (or DraconicTerrain). Common: DraconicTerrain.
# Cast hides/restores HP and plays existing SE/Anim sounds. Ambient stays quiet.
module DraconicTerrainVisual
  VERSION = "4.1"
  CAST_SECONDS = 2.20
  TERRAIN_IDS = [:Draconic,:DraconicTerrain]
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
  def self.aura_bitmap(variant)
    b=Bitmap.new(160,96)
    outlines=[[[9,29],[35,13],[83,7],[133,19],[151,44],[130,71],[82,86],[31,73],[4,51]],
      [[7,38],[34,17],[57,24],[91,8],[137,28],[148,57],[115,80],[75,73],[40,88],[15,64]],
      [[18,24],[61,8],[109,18],[144,39],[133,66],[96,83],[53,77],[9,56]]]
    outline=outlines[variant]
    polygon(b,outline.map { |x,y|[x,y+5] },Color.new(24,18,43,130))
    polygon(b,outline,Color.new(44+variant*5,35+variant*3,72+variant*8,180))
    polygon(b,[[13,30],[36,17],[82,12],[125,22],[99,39],[51,43]],Color.new(88,71,123,100))
    outline.each_cons(2) { |p,q|line(b,*p,*q,1,Color.new(112,101,155,125)) }
    paths=[[[23,32],[54,42],[71,36],[92,51],[126,56]],[[71,36],[77,20],[96,13]],[[92,51],[80,66],[94,78]],[[54,42],[38,59],[31,70]]]
    paths.each do |path|
      path.each_cons(2) do |p,q|
        line(b,*p,*q,6,Color.new(19,14,39,210))
        line(b,*p,*q,3,Color.new(104,62,166,135))
        line(b,*p,*q,1,Color.new(125,173,215,130))
      end
    end
    b
  end
  def self.crystal_bitmap(variant)
    b=Bitmap.new(64,80)
    [[29,6,18,62],[12,29,13,39],[45,23,12,43]].each_with_index do |(x,y,w,h),i|
      y+=variant*3 if i!=0
      polygon(b,[[x,y],[x+w/2,y+9],[x+w/2,y+h-6],[x,y+h],[x-w/2,y+h-8],[x-w/2,y+12]],Color.new(62,43,123,245))
      polygon(b,[[x,y],[x+w/2,y+9],[x+w/2,y+h-6],[x,y+h]],Color.new(100,112,201,240))
      polygon(b,[[x,y],[x-2,y+13],[x-2,y+h-8],[x-w/2,y+h-8],[x-w/2,y+12]],Color.new(141,104,199,225))
      line(b,x,y+3,x,y+h-3,1,Color.new(193,227,255,245))
      line(b,x-w/2,y+12,x,y,1,Color.new(180,170,244,210))
    end
    b
  end
  def self.dragon_ribbon(phase)
    b=Bitmap.new(256,96)
    last=nil
    214.times do |i|
      p=i/213.0
      x=7+i
      y=48+Math.sin(p*Math::PI*2.6+phase*Math::PI/2)*14*(1-p*0.45)
      width=[1,(Math.sin(p*Math::PI)*6).round].max
      alpha=(Math.sin(p*Math::PI/2)*180).round
      if last
        line(b,*last,x,y,width+5,Color.new(86,52,153,(alpha*0.23).round))
        line(b,*last,x,y,width,Color.new(117,112,212,(alpha*0.8).round))
        line(b,*last,x,y,1,Color.new(151,221,245,alpha))
      end
      last=[x,y]
    end
    x,y=last;x=x.round;y=y.round
    # An angular horned crest gives the current a draconic silhouette.
    polygon(b,[[x-4,y-6],[x+7,y-8],[x+19,y-1],[x+12,y+5],[x+2,y+6]],Color.new(122,128,222,200))
    polygon(b,[[x+4,y-5],[x-1,y-18],[x+10,y-8]],Color.new(174,208,250,210))
    polygon(b,[[x-2,y+4],[x+1,y+15],[x+9,y+5]],Color.new(128,172,233,185))
    line(b,x+9,y-3,x+13,y-2,2,Color.new(238,246,255,245))
    line(b,x+13,y+3,x+22,y+1,1,Color.new(188,230,255,220))
    b
  end
  def self.assets
    floor=Bitmap.new(256,192);bed=Bitmap.new(256,192)
    192.times do |y|
      depth=[[(y/192.0-0.12)/0.56,0].max,1].min
      floor.fill_rect(0,y,256,1,Color.new(83,49,129,(depth*depth*(3-2*depth)*255).round))
      next if y<31
      256.times do |x|
        v=Math.sin(x*0.05+y*0.065+Math.sin(y*0.03)*2)*Math.cos(y*0.07-x*0.04)
        rgb=v>0 ? [89,69,145] : [41,31,88]
        bed.fill_rect(x,y,1,1,Color.new(*rgb,(v.abs*depth*43).round))
      end
    end
    mist=Bitmap.new(192,48)
    24.times do |row|
      48.times do |col|
        x,y=col*4,row*2
        v=Math.exp(-((x-87)/67.0)**2-((y-25-Math.sin(x*0.04)*4)/10.0)**2)
        mist.fill_rect(x,y,4,2,Color.new(145,126,207,(v*35).round))
      end
    end
    shard=Bitmap.new(16,20)
    polygon(shard,[[8,1],[13,7],[11,13],[7,18],[3,10]],Color.new(100,82,184,220))
    polygon(shard,[[8,2],[11,7],[7,12],[4,9]],Color.new(172,212,249,235))
    line(shard,8,3,7,8,1,Color.new(228,243,255,250))
    [floor,bed,mist,shard,aura_bitmap(0),aura_bitmap(1),aura_bitmap(2),*Array.new(4) { |phase|dragon_ribbon(phase) },crystal_bitmap(0),crystal_bitmap(1),crystal_bitmap(2)]
  end
  def self.play_se(second=false)
    names=second ? ["PRSFX- Dragon Pulse","PRSFX- Dragon Breath"] : ["PRSFX- Dragon Dance","PRSFX- Dragon Rage"]
    names.each do |name|
      next unless [".wav",".ogg",".mp3"].any? { |ext|File.file?("Audio/SE/Anim/#{name}#{ext}") }
      pbSEPlay("Anim/#{name}",second ? 55 : 72,second ? 90 : 95)
      break
    end
  end
  class Layer
    def initialize(hash,viewport)
      @hash,@viewport=hash,viewport
      @sprites,@bitmaps,@keys=[],[],[]
      @age,@alpha=0.0,0.0;@disposed=false
      begin
        @bitmaps.concat(DraconicTerrainVisual.assets)
        floor,bed,mist,shard=@bitmaps[0,4]
        @floor=make(floor,0,0,2);@bed=make(bed,0,0,3)
        [@floor,@bed].each { |s|s.zoom_x,s.zoom_y=Graphics.width/256.0,Graphics.height/192.0 }
        @plates=Array.new(18) { |i|make(@bitmaps[4+i%3],80,48,4) }
        @mist=Array.new(6) {make(mist,96,24,5)}
        @dragons=Array.new(8) {make(@bitmaps[7],128,48,7)}
        @shards=Array.new(48) {make(shard,8,10,8)}
        @crystals=Array.new(16) { |i|make(@bitmaps[11+i%3],32,72,6) }
        @floatstones=Array.new(6) { |i|make(@bitmaps[4+i%3],80,48,6) }
      rescue
        dispose;raise
      end
    end
    def make(bitmap,ox,oy,z)
      s=Sprite.new(@viewport);@sprites<<s
      s.bitmap,s.ox,s.oy,s.z=bitmap,ox,oy,z;s.opacity=0
      key="draconic_terrain_visual_#{object_id}_#{@keys.length}"
      @keys<<key;@hash[key]=s;s
    end
    def update(active,cast,pulse,animate)
      dt=1.0/[Graphics.frame_rate,1].max
      @age+=dt if animate || cast
      @alpha=[[@alpha+((active || cast) ? dt*3.2 : -dt*3.2),0].max,1].min
      w,h=Graphics.width.to_f,Graphics.height.to_f;sx,sy=w/512.0,h/384.0
      crest=cast ? Math.sin(cast*Math::PI) : 0.0
      spread=cast ? [[cast/0.58,0].max,1].min : 1.0
      shared_tint=defined?(TerrainFloorTint::COLOURS) && DraconicTerrainVisual::TERRAIN_IDS.any? { |id|TerrainFloorTint::COLOURS.key?(id) }
      @floor.opacity=shared_tint ? 0 : (@alpha*(76+crest*20)).round
      @bed.opacity=(@alpha*spread*(175+Math.sin(@age*1.3)*25+crest*45)).round
      @plates.each_with_index do |s,i|
        depth=(Math.sin(i*91.7+4.3)*43758.5453)%1.0
        rise=cast ? Math.sin(spread*Math::PI)*(5+depth*6)*sy : 0
        s.x=w*(0.025+((Math.sin(i*127.1+2.7)*43758.5453)%1.0)*0.95)
        s.y=h*(0.27+depth*0.70)-rise
        s.zoom_x=sx*(0.65+depth*0.55)
        s.zoom_y=sy*(0.34+depth*0.30)
        s.opacity=(@alpha*spread*(175+depth*35+crest*25)).round
        s.mirror=i.odd?
        s.angle=Math.sin(i*2.399)*6
      end
      @crystals.each_with_index do |s,i|
        depth=(Math.sin(i*91.7+4.3)*43758.5453)%1.0
        s.x=w*(0.04+((Math.sin(i*127.1+23.5)*43758.5453)%1.0)*0.92)
        s.y=h*(0.29+depth*0.68)
        size=0.23+depth*0.29+i%3*0.025
        s.zoom_x,s.zoom_y=sx*size,sy*size*spread
        s.mirror=i.odd?
        s.opacity=(@alpha*spread*(165+Math.sin(@age*1.5+i)*25+crest*40)).round
      end
      @floatstones.each_with_index do |s,i|
        depth=(i*0.569840296)%1.0
        s.x=w*(i.even? ? 0.055+i%3*0.035 : 0.945-i%3*0.035)
        s.y=h*(0.26+depth*0.64)-(7+Math.sin(@age*1.3+i)*5)*sy
        size=0.14+depth*0.10
        s.zoom_x,s.zoom_y=sx*size,sy*size*0.8
        s.angle=Math.sin(@age*0.7+i)*8
        s.opacity=(@alpha*spread*190).round
      end
      @mist.each_with_index do |s,i|
        s.x=((@age*(9+i%3*2)+i*w/4)%(w+250*sx))-125*sx
        s.y=h*(0.25+i%3*0.30)+Math.sin(@age*0.65+i)*4*sy
        s.zoom_x,s.zoom_y=sx*1.8,sy*(0.40+i%3*0.1)
        s.opacity=(@alpha*spread*(65+crest*55+pulse*15)).round
      end
      @dragons.each_with_index do |s,i|
        p=(@age*(0.085+i%4*0.015)+i*0.61803398875)%1.0
        forward=i.even?
        s.x=-95*sx+p*(w+190*sx)
        s.x=w-s.x unless forward
        depth=(i*0.569840296)%1.0
        s.y=h*(0.19+depth*0.70)+Math.sin(@age*(0.7+i%3*0.12)+i)*12*sy
        s.bitmap=@bitmaps[7+((@age*7).floor+i)%4]
        size=0.35+i%4*0.04
        s.zoom_x=sx*size
        s.zoom_y=sy*(0.30+i%3*0.045)
        s.mirror=!forward
        s.angle=Math.sin(@age*0.55+i)*7
        s.opacity=(@alpha*spread*Math.sin(p*Math::PI)*(220+crest*25+pulse*10)).round
      end
      @shards.each_with_index do |s,i|
        p=(@age*(0.22+i%3*0.035)+i*0.61803398875)%1.0
        a=i*2.399+@age*0.35
        s.x=w*(0.02+(i*0.219)%0.96)+Math.cos(a)*8*sx
        s.y=h*(0.28+i%5*0.155)-p*(12+crest*28)*sy
        size=0.17+i%4*0.045
        s.zoom_x,s.zoom_y=sx*size,sy*size
        s.angle=Math.sin(a)*25
        s.opacity=(@alpha*spread*Math.sin(p*Math::PI)*(110+crest*100+pulse*15)).round
      end
    end
    def faded?;@alpha<=0.0;end
    def dispose
      return if @disposed
      @disposed=true;@keys.each { |key|@hash.delete(key) }
      @sprites.reverse_each { |s|s.dispose unless s.disposed? }
      @bitmaps.each { |b|b.dispose unless b.disposed? }
    end
  end
  module SceneHooks
    def pbAnimation(moveID,user,targets,hitNum=0)
      return super unless moveID==:DRACONICTERRAIN
      @draconic_terrain_visual_requested=true
      # pbStartTerrain calls Common:DraconicTerrain after setting the field; cast once.
    end
    def pbCommonAnimationExists?(name)
      return true if ["draconicterrain"].include?(name.to_s.gsub(/[^a-z]/i,"").downcase)
      super
    end
    def pbCommonAnimation(name,user=nil,target=nil)
      key=name.to_s.gsub(/[^a-z]/i,"").downcase
      return super unless ["draconicterrain"].include?(key)
      requested=@draconic_terrain_visual_requested
      @draconic_terrain_visual_requested=false
      return if @battle && !@battle.showAnims
      return if @draconic_terrain_visual_cast
      kind=:Draconic
      full=requested || @draconic_terrain_visual_last_cast!=kind
      duration=full ? DraconicTerrainVisual::CAST_SECONDS : 0.24
      boxes=full ? {} : nil
      @draconic_terrain_visual_boxes=boxes
      begin
        if full
          pbDraconicTerrainVisualHideHP
          DraconicTerrainVisual.play_se
        end
        second=false
        @draconic_terrain_visual_cast_kind=kind
        frames=[(Graphics.frame_rate*duration).round,2].max
        frames.times do |f|
          p=f.to_f/(frames-1)
          @draconic_terrain_visual_cast=p if full
          @draconic_terrain_visual_pulse=full ? 0 : Math.sin(p*Math::PI)
          if full && !second && p>=0.48
            DraconicTerrainVisual.play_se(true)
            second=true
          end
          pbUpdate
        end
        @draconic_terrain_visual_last_cast=kind if DraconicTerrainVisual.active?(@battle)
      ensure
        @draconic_terrain_visual_cast=nil
        @draconic_terrain_visual_cast_kind=nil
        @draconic_terrain_visual_pulse=0
        @draconic_terrain_visual_boxes=nil
        boxes.each_value { |s,v|s.visible=v if s && !s.disposed? } if boxes
      end
    end
    def pbDraconicTerrainVisualHideHP
      return unless @draconic_terrain_visual_boxes && @sprites
      @sprites.each do |key,s|
        next unless key.to_s.start_with?("dataBox_") && s && !s.disposed?
        @draconic_terrain_visual_boxes[s.object_id]||=[s,s.visible]
        s.visible=false
      end
    end
    def pbGraphicsUpdate
      if @sprites && @viewport && !@viewport.disposed? && @battle
        active=DraconicTerrainVisual.active?(@battle)
        if active || @draconic_terrain_visual_cast || @draconic_terrain_visual_layer
          @draconic_terrain_visual_layer||=DraconicTerrainVisual::Layer.new(@sprites,@viewport)
          @draconic_terrain_visual_layer.update(active,@draconic_terrain_visual_cast,@draconic_terrain_visual_pulse.to_f,@battle.showAnims)
          if !active && !@draconic_terrain_visual_cast && @draconic_terrain_visual_layer.faded?
            @draconic_terrain_visual_layer.dispose
            @draconic_terrain_visual_layer=nil
          end
        end
        @draconic_terrain_visual_last_cast=nil if !active && !@draconic_terrain_visual_cast
        pbDraconicTerrainVisualHideHP
      end
      super
    end
    def pbDisposeSprites
      if @draconic_terrain_visual_layer
        @draconic_terrain_visual_layer.dispose
        @draconic_terrain_visual_layer=nil
      end
      super
    end
  end
end
Battle::Scene.prepend(DraconicTerrainVisual::SceneHooks)
