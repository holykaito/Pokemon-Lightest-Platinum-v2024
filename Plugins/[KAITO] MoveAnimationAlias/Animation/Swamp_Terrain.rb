# Swamp Terrain cast + persistent marsh battlefield - Pokemon Essentials v21.1.
# Install in Plugins/[KAITO] Plugin/ and recompile. No external graphics.
# Requires the existing Swamp Terrain gameplay plugin; this file changes visuals only.
# Move: SWAMPTERRAIN. Field: Swamp (or SwampTerrain). Common: SwampTerrain.
# Cast hides/restores HP and plays existing SE/Anim sounds. Ambient stays quiet.
module SwampTerrainVisual
  VERSION = "1.1"
  CAST_SECONDS = 2.10
  TERRAIN_IDS = [:Swamp,:SwampTerrain]
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
        dx,dy=(x-64)/59.0,(y-32)/25.0
        a=Math.atan2(dy,dx)
        edge=1+Math.sin(a*3+variant)*0.10+Math.cos(a*5+variant*2)*0.045
        r=Math.sqrt(dx*dx+dy*dy)/edge
        next if r>1
        noise=Math.sin(x*0.13+y*0.26+variant)*Math.sin(y*0.21-x*0.07)
        if r>0.90
          rgb=[87,91,48];alpha=((1-r)/0.10*175).round
        elsif r>0.80
          rgb=y<32 ? [160,177,93] : [48,64,33];alpha=190
        else
          rgb=[44+(noise*8).round,100+(noise*10).round,73+(noise*6).round]
          alpha=(154+noise*22).round
        end
        b.fill_rect(x,y,1,1,Color.new(*rgb,alpha))
      end
    end
    3.times do |j|
      48.times do |k|
        x=25+k
        y=22+j*6+Math.sin(k*0.065+variant+j)*2
        alpha=(Math.sin(k/47.0*Math::PI)*110).round
        b.fill_rect(x,y.round,1,1,Color.new(192,215,148,alpha))
      end
    end
    b
  end
  def self.assets
    floor=Bitmap.new(256,192)
    bed=Bitmap.new(256,192)
    192.times do |y|
      depth=[[(y/192.0-0.39)/0.45,0].max,1].min
      floor.fill_rect(0,y,256,1,Color.new(108,127,72,(depth*depth*(3-2*depth)*255).round))
      next if y<86
      256.times do |x|
        v=Math.sin(x*0.040+y*0.065+Math.sin(x*0.02)*2)*Math.cos(y*0.14-x*0.012)
        rgb=v>0 ? [146,133,78] : [61,88,63]
        bed.fill_rect(x,y,1,1,Color.new(*rgb,(v.abs*depth*66).round))
        seed=(x*73856093+y*19349663)%2147483647
        bed.fill_rect(x,y,1,1,Color.new(175,161,105,(depth*45).round)) if seed%37==0
      end
    end
    mist=Bitmap.new(192,48)
    24.times do |row|
      48.times do |col|
        x,y=col*4,row*2
        v=Math.exp(-((x-83)/68.0)**2-((y-25-Math.sin(x*0.03)*3)/10.0)**2)
        mist.fill_rect(x,y,4,2,Color.new(169,190,152,(v*38).round))
      end
    end
    bubble=Bitmap.new(20,22)
    disc(bubble,10,12,7,Color.new(45,77,37,235))
    disc(bubble,10,11,5,Color.new(153,178,87,245))
    bubble.fill_rect(6,7,4,2,Color.new(234,241,175,255))
    bubble.fill_rect(5,9,2,2,Color.new(214,229,154,225))
    pop=Bitmap.new(32,24)
    [[16,20,6,10],[16,20,26,10],[16,20,15,5],[16,20,3,18],[16,20,29,18]].each do |p|
      line(pop,*p,1,Color.new(185,211,117,240))
    end
    [[5,7],[25,7],[14,2]].each { |x,y|disc(pop,x,y,1,Color.new(195,205,135,230)) }
    ripple=Bitmap.new(96,96)
    360.times do |i|
      a=i*Math::PI/180
      next if i%110>92
      [34,39].each do |r|
        ripple.fill_rect((48+Math.cos(a)*r).round,(48+Math.sin(a)*r).round,2,1,Color.new(199,223,154,r==34 ? 225 : 105))
      end
    end
    reeds=Bitmap.new(44,48)
    [[20,44,9,15],[22,44,19,6],[23,44,33,11],[18,44,5,28],[24,44,39,25]].each_with_index do |p,i|
      line(reeds,*p,2,Color.new(41,77,33,240))
      line(reeds,p[0],p[1],p[2]+1,p[3],1,Color.new(163,188,87,245))
      reeds.fill_rect(p[2]-1,p[3]-3,3,6,Color.new(112,94,53,225)) if i==1 || i==2
    end
    [floor,bed,mist,bubble,pop,ripple,reeds,puddle(0),puddle(1),puddle(2)]
  end
  def self.play_se(second=false)
    names=second ? ["PRSFX- Bubble","PRSFX- Mud Sport2"] : ["PRSFX- Muddy Water","PRSFX- Mud Sport1"]
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
        @bitmaps.concat(SwampTerrainVisual.assets)
        floor,bed,mist,bubble,pop,ripple,reeds=@bitmaps[0,7]
        @floor=make(floor,0,0,2)
        @bed=make(bed,0,0,3)
        [@floor,@bed].each { |s|s.zoom_x,s.zoom_y=Graphics.width/256.0,Graphics.height/192.0 }
        @pools=Array.new(18) { |i|make(@bitmaps[7+i%3],64,32,4) }
        @mist=Array.new(6) {make(mist,96,24,6)}
        @bubbles=Array.new(24) {make(bubble,10,19,8)}
        @pops=Array.new(24) {make(pop,16,20,8)}
        @ripples=Array.new(24) {make(ripple,48,48,7)}
        @reeds=Array.new(12) {make(reeds,22,44,6)}
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
      key="swamp_terrain_visual_#{object_id}_#{@keys.length}"
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
      shared_tint=defined?(TerrainFloorTint::COLOURS) && SwampTerrainVisual::TERRAIN_IDS.any? { |id|TerrainFloorTint::COLOURS.key?(id) }
      @floor.opacity=shared_tint ? 0 : (@alpha*(86+crest*18)).round
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
        s.opacity=(@alpha*spread*(75+crest*55+pulse*15)).round
      end
      @bubbles.each_with_index do |s,i|
        x,y,depth=pool_position(i%18,w,h)
        x+=Math.sin(i*1.7)*20*sx
        y+=Math.cos(i*2.2)*5*sy
        p=(@age*(0.25+i%3*0.04)+i*0.61803398875)%1.0
        size=0.28+depth*0.30+i%3*0.07
        inflate=[p/0.72,1].min
        s.x,s.y=x,y-Math.sin(inflate*Math::PI/2)*6*sy
        s.zoom_x=sx*size*(0.5+inflate*0.7)
        s.zoom_y=sy*size*(0.4+inflate*0.9)
        s.opacity=p<0.72 ? (@alpha*spread*Math.sin(inflate*Math::PI/2)*240).round : 0
        pop=@pops[i]
        q=(p-0.72)/0.28
        pop.x,pop.y=x,y-5*sy
        pop.zoom_x,pop.zoom_y=sx*size*(1+[q,0].max),sy*size*(1+[q,0].max)
        pop.opacity=p>=0.72 ? (@alpha*spread*(1-q)*235).round : 0
        r=@ripples[i]
        q=[[(p-0.66)/0.34,0].max,1].min
        r.x,r.y=x,y
        r.zoom_x=sx*(0.10+q*0.50+depth*0.20)
        r.zoom_y=r.zoom_x*0.23*sy/sx
        r.opacity=(@alpha*spread*Math.sin(q*Math::PI)*185).round
      end
      @reeds.each_with_index do |s,i|
        x,y,depth=pool_position((i*5)%18,w,h)
        s.x,s.y=x+(i.even? ? -1 : 1)*(35+depth*18)*sx,y+7*sy
        size=0.32+depth*0.28
        s.zoom_x,s.zoom_y=sx*size,sy*size*spread
        s.angle=Math.sin(@age*1.2+i)*3
        s.mirror=i.odd?
        s.opacity=(@alpha*spread*215).round
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
      return super unless moveID==:SWAMPTERRAIN
      @swamp_terrain_visual_requested=true
      # pbStartTerrain calls Common:SwampTerrain after setting the field; cast once.
    end
    def pbCommonAnimationExists?(name)
      return true if ["swampterrain"].include?(name.to_s.gsub(/[^a-z]/i,"").downcase)
      super
    end
    def pbCommonAnimation(name,user=nil,target=nil)
      key=name.to_s.gsub(/[^a-z]/i,"").downcase
      return super unless ["swampterrain"].include?(key)
      requested=@swamp_terrain_visual_requested
      @swamp_terrain_visual_requested=false
      return if @battle && !@battle.showAnims
      return if @swamp_terrain_visual_cast
      kind=:Swamp
      full=requested || @swamp_terrain_visual_last_cast!=kind
      duration=full ? SwampTerrainVisual::CAST_SECONDS : 0.24
      boxes=full ? {} : nil
      @swamp_terrain_visual_boxes=boxes
      begin
        if full
          pbSwampTerrainVisualHideHP
          SwampTerrainVisual.play_se
        end
        second=false
        @swamp_terrain_visual_cast_kind=kind
        frames=[(Graphics.frame_rate*duration).round,2].max
        frames.times do |f|
          p=f.to_f/(frames-1)
          @swamp_terrain_visual_cast=p if full
          @swamp_terrain_visual_pulse=full ? 0 : Math.sin(p*Math::PI)
          if full && !second && p>=0.48
            SwampTerrainVisual.play_se(true)
            second=true
          end
          pbUpdate
        end
        @swamp_terrain_visual_last_cast=kind if SwampTerrainVisual.active?(@battle)
      ensure
        @swamp_terrain_visual_cast=nil
        @swamp_terrain_visual_cast_kind=nil
        @swamp_terrain_visual_pulse=0
        @swamp_terrain_visual_boxes=nil
        boxes.each_value { |s,v|s.visible=v if s && !s.disposed? } if boxes
      end
    end
    def pbSwampTerrainVisualHideHP
      return unless @swamp_terrain_visual_boxes && @sprites
      @sprites.each do |key,s|
        next unless key.to_s.start_with?("dataBox_") && s && !s.disposed?
        @swamp_terrain_visual_boxes[s.object_id]||=[s,s.visible]
        s.visible=false
      end
    end
    def pbGraphicsUpdate
      if @sprites && @viewport && !@viewport.disposed? && @battle
        active=SwampTerrainVisual.active?(@battle)
        if active || @swamp_terrain_visual_cast || @swamp_terrain_visual_layer
          @swamp_terrain_visual_layer||=SwampTerrainVisual::Layer.new(@sprites,@viewport)
          @swamp_terrain_visual_layer.update(active,@swamp_terrain_visual_cast,@swamp_terrain_visual_pulse.to_f,@battle.showAnims)
          if !active && !@swamp_terrain_visual_cast && @swamp_terrain_visual_layer.faded?
            @swamp_terrain_visual_layer.dispose
            @swamp_terrain_visual_layer=nil
          end
        end
        @swamp_terrain_visual_last_cast=nil if !active && !@swamp_terrain_visual_cast
        pbSwampTerrainVisualHideHP
      end
      super
    end
    def pbDisposeSprites
      if @swamp_terrain_visual_layer
        @swamp_terrain_visual_layer.dispose
        @swamp_terrain_visual_layer=nil
      end
      super
    end
  end
end
Battle::Scene.prepend(SwampTerrainVisual::SceneHooks)
