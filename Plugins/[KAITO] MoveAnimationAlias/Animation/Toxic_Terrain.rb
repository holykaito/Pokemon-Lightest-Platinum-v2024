# Toxic Terrain cast + persistent poisoned battlefield - Pokemon Essentials v21.1.
# Install in Plugins/[KAITO] Plugin/ and recompile. No external graphics.
# Requires the existing Toxic Terrain gameplay plugin; this file changes visuals only.
# Move: TOXICTERRAIN. Field: Toxic (or ToxicTerrain). Common: ToxicTerrain.
# Cast hides/restores HP and plays existing SE/Anim sounds. Ambient stays quiet.
module ToxicTerrainVisual
  VERSION = "1.0"
  CAST_SECONDS = 2.15
  TERRAIN_IDS = [:Toxic,:ToxicTerrain]
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
  def self.puddle(variant)
    b=Bitmap.new(128,64)
    64.times do |y|
      128.times do |x|
        dx,dy=(x-64)/57.0,(y-32)/23.0
        a=Math.atan2(dy,dx)
        edge=1+Math.sin(a*4+variant)*0.15+Math.cos(a*7+variant*2)*0.07
        r=Math.sqrt(dx*dx+dy*dy)/edge
        next if r>1
        swirl=Math.sin(x*0.075+y*0.17+Math.sin(y*0.15+variant)*2)
        if r>0.88
          lit=Math.sin(a*3+variant)>0.2
          rgb=lit ? [169,217,83] : [83,39,112]
          alpha=((1-r)/0.12*210).round
        else
          rgb=[91+(swirl*17).round,39+(swirl*9).round,124+(swirl*21).round]
          alpha=(177+swirl*13).round
        end
        b.fill_rect(x,y,1,1,Color.new(*rgb,alpha))
        if r<0.78 && swirl>0.955
          b.fill_rect(x,y,1,1,Color.new(181,221,83,115))
        end
      end
    end
    b
  end
  def self.assets
    floor=Bitmap.new(256,192)
    bed=Bitmap.new(256,192)
    192.times do |y|
      depth=[[(y/192.0-0.39)/0.45,0].max,1].min
      floor.fill_rect(0,y,256,1,Color.new(113,56,143,(depth*depth*(3-2*depth)*255).round))
      next if y<86
      256.times do |x|
        v=Math.sin(x*0.040+y*0.065+Math.sin(x*0.02)*2)*Math.cos(y*0.14-x*0.012)
        rgb=v>0 ? [133,59,163] : [56,24,80]
        bed.fill_rect(x,y,1,1,Color.new(*rgb,(v.abs*depth*66).round))
        seed=(x*73856093+y*19349663)%2147483647
        bed.fill_rect(x,y,1,1,Color.new(187,210,85,(depth*45).round)) if seed%37==0
      end
    end
    8.times do |j|
      last=nil
      120.times do |i|
        x=i*2+5
        y=95+j*12+Math.sin(i*0.045+j)*4+Math.sin(i*0.12+j*2)*2
        alpha=(Math.sin(i/119.0*Math::PI)*54).round
        line(bed,*last,x,y,2,Color.new(52,21,73,alpha)) if last
        line(bed,*last,x,y,1,Color.new(176,209,87,(alpha*0.75).round)) if last
        last=[x,y]
      end
    end
    mist=Bitmap.new(192,48)
    24.times do |row|
      48.times do |col|
        x,y=col*4,row*2
        v=Math.exp(-((x-83)/68.0)**2-((y-25-Math.sin(x*0.03)*3)/10.0)**2)
        mist.fill_rect(x,y,4,2,Color.new(172,112,191,(v*46).round))
      end
    end
    bubble=Bitmap.new(20,22)
    disc(bubble,10,12,7,Color.new(64,24,93,245))
    disc(bubble,10,11,5,Color.new(153,70,187,250))
    bubble.fill_rect(6,7,4,2,Color.new(224,242,153,255))
    bubble.fill_rect(5,9,2,2,Color.new(196,234,116,240))
    pop=Bitmap.new(32,24)
    [[16,20,6,10],[16,20,26,10],[16,20,15,5],[16,20,3,18],[16,20,29,18]].each do |p|
      line(pop,*p,1,Color.new(174,210,82,245))
    end
    [[5,7],[25,7],[14,2]].each { |x,y|disc(pop,x,y,1,Color.new(208,239,131,245)) }
    ripple=Bitmap.new(96,96)
    360.times do |i|
      a=i*Math::PI/180
      next if i%110>92
      [34,39].each do |r|
        ripple.fill_rect((48+Math.cos(a)*r).round,(48+Math.sin(a)*r).round,2,1,Color.new(193,223,102,r==34 ? 220 : 90))
      end
    end
    gas=Bitmap.new(44,64)
    3.times do |j|
      last=nil
      52.times do |i|
        p=i/51.0
        x=22+Math.sin(p*Math::PI*2.3+j*1.6)*(4+p*7)
        y=59-i
        alpha=(Math.sin(p*Math::PI)*(j==1 ? 160 : 100)).round
        line(gas,*last,x,y,3,Color.new(108,53,140,(alpha*0.55).round)) if last
        line(gas,*last,x,y,1,Color.new(188,116,211,alpha)) if last
        last=[x,y]
      end
    end
    [floor,bed,mist,bubble,pop,ripple,gas,puddle(0),puddle(1),puddle(2)]
  end
  def self.play_se(second=false)
    names=second ? ["PRSFX- Poison Gas","PRSFX- Toxic2"] : ["PRSFX- Sludge Wave","PRSFX- Toxic1"]
    names.each do |name|
      next unless [".wav",".ogg",".mp3"].any? { |ext|File.file?("Audio/SE/Anim/#{name}#{ext}") }
      pbSEPlay("Anim/#{name}",second ? 48 : 72,second ? 90 : 95)
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
        @bitmaps.concat(ToxicTerrainVisual.assets)
        floor,bed,mist,bubble,pop,ripple,gas=@bitmaps[0,7]
        @floor=make(floor,0,0,2)
        @bed=make(bed,0,0,3)
        [@floor,@bed].each { |s|s.zoom_x,s.zoom_y=Graphics.width/256.0,Graphics.height/192.0 }
        @pools=Array.new(18) { |i|make(@bitmaps[7+i%3],64,32,4) }
        @mist=Array.new(6) {make(mist,96,24,6)}
        @bubbles=Array.new(24) {make(bubble,10,19,8)}
        @pops=Array.new(24) {make(pop,16,20,8)}
        @ripples=Array.new(24) {make(ripple,48,48,7)}
        @vents=Array.new(12) {make(gas,22,60,7)}
        @rings=Array.new(4) {make(ripple,48,48,7)}
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
      key="toxic_terrain_visual_#{object_id}_#{@keys.length}"
      @keys<<key
      @hash[key]=s
      s
    end
    def pool_position(i,w,h)
      depth=(i/3)/5.0
      stagger=(i/3).odd? ? 0.055 : -0.025
      [w*(0.10+(i%3)*0.37+stagger+Math.sin(i*2.399)*0.065),h*(0.52+depth*0.44+Math.cos(i*1.73)*0.014),depth]
    end
    def update(active,cast,pulse,animate)
      dt=1.0/[Graphics.frame_rate,1].max
      @age+=dt if animate || cast
      @alpha=[[@alpha+((active || cast) ? dt*3.2 : -dt*3.2),0].max,1].min
      w,h=Graphics.width.to_f,Graphics.height.to_f
      sx,sy=w/512.0,h/384.0
      crest=cast ? Math.sin(cast*Math::PI) : 0.0
      spread=cast ? [[cast/0.58,0].max,1].min : 1.0
      shared_tint=defined?(TerrainFloorTint::COLOURS) && ToxicTerrainVisual::TERRAIN_IDS.any? { |id|TerrainFloorTint::COLOURS.key?(id) }
      @floor.opacity=shared_tint ? 0 : (@alpha*(85+crest*20)).round
      @bed.opacity=(@alpha*spread*200).round
      @pools.each_with_index do |s,i|
        x,y,depth=pool_position(i,w,h)
        reveal=cast ? [[(spread-depth*0.26)/0.66,0].max,1].min : 1.0
        size=0.75+depth*0.70+(i%3)*0.08
        s.x,s.y=x,y
        s.zoom_x=sx*size*(0.98+Math.sin(@age*0.8+i)*0.02)*reveal
        s.zoom_y=sy*size*(0.68+Math.sin(@age*0.7+i)*0.025)*reveal
        s.mirror=i.odd?
        s.angle=Math.sin(i*2.1)*4
        s.opacity=(@alpha*reveal*(225+crest*25)).round
      end
      @mist.each_with_index do |s,i|
        s.x=((@age*(7+i%3*2)+i*w/4)%(w+250*sx))-125*sx
        s.y=h*(0.53+i%3*0.18)+Math.sin(@age*0.6+i)*4*sy
        s.zoom_x,s.zoom_y=sx*(1.6+i%2*0.3),sy*(0.42+i%3*0.1)
        s.opacity=(@alpha*spread*(95+crest*65+pulse*15)).round
      end
      @bubbles.each_with_index do |s,i|
        x,y,depth=pool_position(i%18,w,h)
        x+=Math.sin(i*1.7)*20*sx
        y+=Math.cos(i*2.2)*5*sy
        p=(@age*(0.25+i%3*0.04)+i*0.61803398875)%1.0
        size=0.35+depth*0.33+i%3*0.075
        inflate=[p/0.72,1].min
        s.x,s.y=x,y-Math.sin(inflate*Math::PI/2)*(10+crest*12)*sy
        s.zoom_x=sx*size*(0.5+inflate*0.7)
        s.zoom_y=sy*size*(0.4+inflate*0.9)
        s.opacity=p<0.72 ? (@alpha*spread*Math.sin(inflate*Math::PI/2)*240).round : 0
        pop=@pops[i]
        q=(p-0.72)/0.28
        pop.x,pop.y=x,y-(9+crest*12)*sy
        pop.zoom_x,pop.zoom_y=sx*size*(1+[q,0].max),sy*size*(1+[q,0].max)
        pop.opacity=p>=0.72 ? (@alpha*spread*(1-q)*235).round : 0
        r=@ripples[i]
        q=[[(p-0.66)/0.34,0].max,1].min
        r.x,r.y=x,y
        r.zoom_x=sx*(0.10+q*0.50+depth*0.20)
        r.zoom_y=r.zoom_x*0.23*sy/sx
        r.opacity=(@alpha*spread*Math.sin(q*Math::PI)*185).round
      end
      @vents.each_with_index do |s,i|
        x,y,depth=pool_position((i*5)%18,w,h)
        p=(@age*0.23+i*0.173)%1.0
        size=0.40+depth*0.36
        s.x=x+Math.sin(@age+i)*6*sx
        s.y=y-p*12*sy
        s.zoom_x=sx*size*(0.85+p*0.30)
        s.zoom_y=sy*size*(0.8+p*0.4)
        s.mirror=i.odd?
        s.opacity=(@alpha*spread*Math.sin(p*Math::PI)*(165+crest*65)).round
      end
      @rings.each_with_index do |s,i|
        if cast
          p=[[(cast-i*0.10)/0.68,0].max,1].min
          size=sx*(0.15+p*5.7)
          s.x,s.y=w*(i.even? ? 0.26 : 0.74),h*(i.even? ? 0.80 : 0.56)
          s.zoom_x,s.zoom_y=size,size*0.25*sy/sx
          s.opacity=(@alpha*Math.sin(p*Math::PI)*180).round
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
      return super unless moveID==:TOXICTERRAIN
      @toxic_terrain_visual_requested=true
      # pbStartTerrain calls Common:ToxicTerrain after setting the field; cast once.
    end
    def pbCommonAnimationExists?(name)
      return true if ["toxicterrain"].include?(name.to_s.gsub(/[^a-z]/i,"").downcase)
      super
    end
    def pbCommonAnimation(name,user=nil,target=nil)
      key=name.to_s.gsub(/[^a-z]/i,"").downcase
      return super unless ["toxicterrain"].include?(key)
      requested=@toxic_terrain_visual_requested
      @toxic_terrain_visual_requested=false
      return if @battle && !@battle.showAnims
      return if @toxic_terrain_visual_cast
      kind=:Toxic
      full=requested || @toxic_terrain_visual_last_cast!=kind
      duration=full ? ToxicTerrainVisual::CAST_SECONDS : 0.24
      boxes=full ? {} : nil
      @toxic_terrain_visual_boxes=boxes
      begin
        if full
          pbToxicTerrainVisualHideHP
          ToxicTerrainVisual.play_se
        end
        second=false
        @toxic_terrain_visual_cast_kind=kind
        frames=[(Graphics.frame_rate*duration).round,2].max
        frames.times do |f|
          p=f.to_f/(frames-1)
          @toxic_terrain_visual_cast=p if full
          @toxic_terrain_visual_pulse=full ? 0 : Math.sin(p*Math::PI)
          if full && !second && p>=0.48
            ToxicTerrainVisual.play_se(true)
            second=true
          end
          pbUpdate
        end
        @toxic_terrain_visual_last_cast=kind if ToxicTerrainVisual.active?(@battle)
      ensure
        @toxic_terrain_visual_cast=nil
        @toxic_terrain_visual_cast_kind=nil
        @toxic_terrain_visual_pulse=0
        @toxic_terrain_visual_boxes=nil
        boxes.each_value { |s,v|s.visible=v if s && !s.disposed? } if boxes
      end
    end
    def pbToxicTerrainVisualHideHP
      return unless @toxic_terrain_visual_boxes && @sprites
      @sprites.each do |key,s|
        next unless key.to_s.start_with?("dataBox_") && s && !s.disposed?
        @toxic_terrain_visual_boxes[s.object_id]||=[s,s.visible]
        s.visible=false
      end
    end
    def pbGraphicsUpdate
      if @sprites && @viewport && !@viewport.disposed? && @battle
        active=ToxicTerrainVisual.active?(@battle)
        if active || @toxic_terrain_visual_cast || @toxic_terrain_visual_layer
          @toxic_terrain_visual_layer||=ToxicTerrainVisual::Layer.new(@sprites,@viewport)
          @toxic_terrain_visual_layer.update(active,@toxic_terrain_visual_cast,@toxic_terrain_visual_pulse.to_f,@battle.showAnims)
          if !active && !@toxic_terrain_visual_cast && @toxic_terrain_visual_layer.faded?
            @toxic_terrain_visual_layer.dispose
            @toxic_terrain_visual_layer=nil
          end
        end
        @toxic_terrain_visual_last_cast=nil if !active && !@toxic_terrain_visual_cast
        pbToxicTerrainVisualHideHP
      end
      super
    end
    def pbDisposeSprites
      if @toxic_terrain_visual_layer
        @toxic_terrain_visual_layer.dispose
        @toxic_terrain_visual_layer=nil
      end
      super
    end
  end
end
Battle::Scene.prepend(ToxicTerrainVisual::SceneHooks)
