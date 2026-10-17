# Sandy Terrain cast + persistent sandy battlefield - Pokemon Essentials v21.1.
# Install in Plugins/[KAITO] Plugin/ and recompile. No external graphics.
# Requires the existing Sandy Terrain gameplay plugin; this file changes visuals only.
# Move: SANDYTERRAIN. Field: Sandy (or SandyTerrain). Common: SandyTerrain.
# Cast hides/restores HP and plays existing SE/Anim sounds. Ambient stays quiet.
module SandyTerrainVisual
  VERSION = "2.0"
  CAST_SECONDS = 2.00
  TERRAIN_IDS = [:Sandy,:SandyTerrain]
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
  def self.assets
    floor=Bitmap.new(256,192)
    192.times do |y|
      p=[[(y/192.0-0.38)/0.43,0].max,1].min
      floor.fill_rect(0,y,256,1,Color.new(224,185,114,(p*p*(3-2*p)*255).round))
    end
    dune=dune_bitmap(0)
    dust=Bitmap.new(192,48)
    24.times do |row|
      48.times do |col|
        x,y=col*4,row*2
        d=Math.exp(-((x-74)/65.0)**2-((y-25-Math.sin(x*0.035)*3)/10.0)**2)
        edge=Math.sin((col+0.5)/48.0*Math::PI)
        dust.fill_rect(x,y,4,2,Color.new(230,201,144,(d*edge*45).round))
      end
    end
    grain=Bitmap.new(8,8)
    grain.fill_rect(2,3,4,3,Color.new(177,131,69,205))
    grain.fill_rect(2,2,3,2,Color.new(248,219,156,240))
    grain.fill_rect(3,2,1,1,Color.new(255,241,199,245))
    ripple=Bitmap.new(128,128)
    360.times do |i|
      a=i*Math::PI/180
      [[49,135],[52,65]].each do |r,alpha|
        ripple.fill_rect((64+Math.cos(a)*r).round,(64+Math.sin(a)*r).round,2,2,Color.new(247,215,148,alpha))
      end
    end
    # Perspective ripples and grain: baked once, never redrawn every frame.
    bed=Bitmap.new(256,192)
    (85...192).each do |y|
      depth=(y-85)/107.0
      256.times do |x|
        phase=y/(3.1+depth*1.8)+Math.sin(x*0.024+y*0.015)*1.3+Math.sin(x*0.058-y*0.023)*0.30
        v=Math.sin(phase*Math::PI*2)
        alpha=((v.abs**7)*(16+depth*35)).round
        rgb=v>0 ? [252,223,161] : [144,100,49]
        bed.fill_rect(x,y,1,1,Color.new(*rgb,alpha)) if alpha>3
        seed=(x*374761393+y*668265263)%2147483647
        if seed%29==0
          shade=seed%3==0 ? [130,91,48] : [255,231,177]
          bed.fill_rect(x,y,1,1,Color.new(*shade,(18+depth*40).round))
        end
      end
    end
    flow=Bitmap.new(160,32)
    3.times do |j|
      last=nil
      150.times do |x|
        y=10+j*4+Math.sin(x/149.0*Math::PI*2+j*0.5)*3
        alpha=(Math.sin(x/149.0*Math::PI)**1.5*145).round
        line(flow,*last,x+5,y,1,Color.new(255,226,159,alpha)) if last
        last=[x+5,y]
      end
    end
    [floor,dune,dust,grain,ripple,bed,dune_bitmap(1),dune_bitmap(2),flow]
  end
  def self.dune_bitmap(variant)
    b=Bitmap.new(192,64)
    192.times do |x|
      u=x/191.0
      envelope=Math.sin(u*Math::PI)**0.7
      ridge=18+Math.sin(u*Math::PI*(1.3+variant*0.25)+variant)*7+Math.sin(u*Math::PI*3.3+variant)*2
      # Soft leeward shadow, warm windward face and a thin sunlit crest.
      40.times do |j|
        alpha=(Math.exp(-(j/14.0)**2)*envelope*115).round
        b.fill_rect(x,(ridge+j).round,1,1,Color.new(151,107,56,alpha))
      end
      9.times do |j|
        alpha=((1-j/9.0)*envelope*110).round
        b.fill_rect(x,(ridge-j-1).round,1,1,Color.new(238,198,124,alpha))
      end
      b.fill_rect(x,ridge.round,1,1,Color.new(255,229,171,(envelope*215).round))
      3.times do |j|
        yy=ridge+5+j*5+Math.sin(u*12+variant+j)*1.5
        b.fill_rect(x,yy.round,1,1,Color.new(248,211,143,(envelope*(60-j*12)).round))
      end
    end
    b
  end
  def self.play_se(second=false)
    names=second ? ["PRSFX- Sand Tomb","PRSFX- Sand Attack"] : ["PRSFX- Sand Attack","PRSFX- Sandstorm"]
    names.each do |name|
      next unless [".wav",".ogg",".mp3"].any? { |ext|File.file?("Audio/SE/Anim/#{name}#{ext}") }
      pbSEPlay("Anim/#{name}",second ? 48 : 72,second ? 95 : 100)
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
        @bitmaps.concat(SandyTerrainVisual.assets)
        floor,dune,dust,grain,ripple,bed,variant_a,variant_b,flow=@bitmaps
        @floor=make(floor,0,0,2)
        @floor.zoom_x,@floor.zoom_y=Graphics.width/256.0,Graphics.height/192.0
        @bed=make(bed,0,0,3)
        @bed.zoom_x,@bed.zoom_y=Graphics.width/256.0,Graphics.height/192.0
        variants=[dune,variant_a,variant_b]
        @dunes=Array.new(21) { |i|make(variants[(i*7+i/3)%3],96,24,4) }
        @flows=Array.new(12) {make(flow,80,16,7)}
        @dust=Array.new(6) {make(dust,96,24,6)}
        @grains=Array.new(72) {make(grain,4,4,8)}
        @rings=Array.new(4) {make(ripple,64,64,7)}
        @wave=make(dust,96,24,9)
      rescue
        dispose
        raise
      end
    end
    def make(bitmap,ox,oy,z)
      s=Sprite.new(@viewport)
      @sprites<<s
      s.bitmap,s.ox,s.oy,s.z=bitmap,ox,oy,z
      s.opacity=0
      key="sandy_terrain_visual_#{object_id}_#{@keys.length}"
      @keys<<key
      @hash[key]=s
      s
    end
    def update(active,cast,pulse,animate)
      dt=1.0/[Graphics.frame_rate,1].max
      @age+=dt if animate || cast
      @alpha=[[@alpha+((active || cast) ? dt*3.2 : -dt*3.2),0].max,1].min
      w,h=Graphics.width.to_f,Graphics.height.to_f
      sx,sy=w/512.0,h/384.0
      crest=cast ? Math.sin(cast*Math::PI) : 0.0
      spread=cast ? [[cast/0.54,0].max,1].min : 1.0
      shared_tint=defined?(TerrainFloorTint::COLOURS) && SandyTerrainVisual::TERRAIN_IDS.any? { |id|TerrainFloorTint::COLOURS.key?(id) }
      @floor.opacity=shared_tint ? 0 : (@alpha*(78+crest*16)).round
      @bed.opacity=(@alpha*spread*(200+crest*40)).round
      @dunes.each_with_index do |s,i|
        row=i/3
        depth=row/6.0
        jitter=Math.sin(i*2.399)
        s.x=w*((i%3)*0.36+0.09+jitter*0.07)+Math.sin(@age*0.17+i)*4*sx
        s.y=h*(0.49+depth*0.45)+jitter*6*sy
        s.zoom_x=sx*(0.85+depth*0.65+(i%3)*0.12)
        s.zoom_y=sy*(0.40+depth*0.70)
        s.mirror=i.odd?
        reveal=cast ? [[(spread-depth*0.34)/0.58,0].max,1].min : 1.0
        s.opacity=(@alpha*reveal*(170+depth*45+crest*30)).round
      end
      @flows.each_with_index do |s,i|
        p=(@age*(0.11+i%3*0.023)+i*0.173)%1.0
        depth=(i*0.381966)%1.0
        s.x=-110*sx+p*(w+220*sx)
        s.y=h*(0.53+depth*0.43)+Math.sin(@age+i)*2*sy
        s.zoom_x=sx*(0.65+depth*0.7)
        s.zoom_y=sy*(0.20+depth*0.25)
        s.opacity=(@alpha*spread*Math.sin(p*Math::PI)*(140+crest*85+pulse*25)).round
      end
      @dust.each_with_index do |s,i|
        s.x=((@age*(12+i%3*3)+i*w/4)%(w+260*sx))-130*sx
        s.y=h*(0.51+i%3*0.19)+Math.sin(@age*0.7+i)*3*sy
        s.zoom_x=sx*(1.6+i%2*0.3)
        s.zoom_y=sy*(0.32+i%3*0.10)
        s.opacity=(@alpha*spread*(100+crest*90+pulse*25)).round
      end
      @grains.each_with_index do |s,i|
        p=(@age*(0.14+i%4*0.025)+i*0.61803398875)%1.0
        depth=(i*0.197)%1.0
        s.x=-18*sx+p*(w+36*sx)
        floor=h*(0.50+depth*0.48)
        lift=Math.sin(p*Math::PI)*(3+i%4*2+crest*17)*sy
        s.y=floor-lift+Math.sin(@age*2+i)*2*sy
        size=0.22+depth*0.30+i%3*0.045
        s.zoom_x,s.zoom_y=sx*size,sy*size
        s.angle=@age*45+i*31
        s.opacity=(@alpha*spread*Math.sin(p*Math::PI)*(125+i%3*35+crest*30)).round
      end
      @rings.each_with_index do |s,i|
        if cast
          p=[[(cast-i*0.10)/0.68,0].max,1].min
          size=sx*(0.15+p*4.6)
          s.x=w*(i.even? ? 0.26 : 0.74)
          s.y=h*(i.even? ? 0.80 : 0.56)
          s.zoom_x,s.zoom_y=size,size*0.25*sy/sx
          s.opacity=(@alpha*Math.sin(p*Math::PI)*180).round
        else
          s.opacity=0
        end
      end
      if cast
        p=[[(cast-0.08)/0.80,0].max,1].min
        @wave.x=-w*0.35+p*w*1.7
        @wave.y=h*(0.53+p*0.34)
        @wave.zoom_x,@wave.zoom_y=sx*3.5,sy*1.1
        @wave.opacity=(@alpha*Math.sin(p*Math::PI)*240).round
      else
        @wave.opacity=0
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
      return super unless moveID==:SANDYTERRAIN
      @sandy_terrain_visual_requested=true
      # pbStartTerrain calls Common:SandyTerrain after setting the field; cast once.
    end
    def pbCommonAnimationExists?(name)
      return true if ["sandyterrain"].include?(name.to_s.gsub(/[^a-z]/i,"").downcase)
      super
    end
    def pbCommonAnimation(name,user=nil,target=nil)
      key=name.to_s.gsub(/[^a-z]/i,"").downcase
      return super unless ["sandyterrain"].include?(key)
      requested=@sandy_terrain_visual_requested
      @sandy_terrain_visual_requested=false
      return if @battle && !@battle.showAnims
      return if @sandy_terrain_visual_cast
      kind=:Sandy
      full=requested || @sandy_terrain_visual_last_cast!=kind
      duration=full ? SandyTerrainVisual::CAST_SECONDS : 0.24
      boxes=full ? {} : nil
      @sandy_terrain_visual_boxes=boxes
      begin
        if full
          pbSandyTerrainVisualHideHP
          SandyTerrainVisual.play_se
        end
        second=false
        @sandy_terrain_visual_cast_kind=kind
        frames=[(Graphics.frame_rate*duration).round,2].max
        frames.times do |f|
          p=f.to_f/(frames-1)
          @sandy_terrain_visual_cast=p if full
          @sandy_terrain_visual_pulse=full ? 0 : Math.sin(p*Math::PI)
          if full && !second && p>=0.48
            SandyTerrainVisual.play_se(true)
            second=true
          end
          pbUpdate
        end
        @sandy_terrain_visual_last_cast=kind if SandyTerrainVisual.active?(@battle)
      ensure
        @sandy_terrain_visual_cast=nil
        @sandy_terrain_visual_cast_kind=nil
        @sandy_terrain_visual_pulse=0
        @sandy_terrain_visual_boxes=nil
        boxes.each_value { |s,v|s.visible=v if s && !s.disposed? } if boxes
      end
    end
    def pbSandyTerrainVisualHideHP
      return unless @sandy_terrain_visual_boxes && @sprites
      @sprites.each do |key,s|
        next unless key.to_s.start_with?("dataBox_") && s && !s.disposed?
        @sandy_terrain_visual_boxes[s.object_id]||=[s,s.visible]
        s.visible=false
      end
    end
    def pbGraphicsUpdate
      if @sprites && @viewport && !@viewport.disposed? && @battle
        active=SandyTerrainVisual.active?(@battle)
        if active || @sandy_terrain_visual_cast || @sandy_terrain_visual_layer
          @sandy_terrain_visual_layer||=SandyTerrainVisual::Layer.new(@sprites,@viewport)
          @sandy_terrain_visual_layer.update(active,@sandy_terrain_visual_cast,@sandy_terrain_visual_pulse.to_f,@battle.showAnims)
          if !active && !@sandy_terrain_visual_cast && @sandy_terrain_visual_layer.faded?
            @sandy_terrain_visual_layer.dispose
            @sandy_terrain_visual_layer=nil
          end
        end
        @sandy_terrain_visual_last_cast=nil if !active && !@sandy_terrain_visual_cast
        pbSandyTerrainVisualHideHP
      end
      super
    end
    def pbDisposeSprites
      if @sandy_terrain_visual_layer
        @sandy_terrain_visual_layer.dispose
        @sandy_terrain_visual_layer=nil
      end
      super
    end
  end
end
Battle::Scene.prepend(SandyTerrainVisual::SceneHooks)
