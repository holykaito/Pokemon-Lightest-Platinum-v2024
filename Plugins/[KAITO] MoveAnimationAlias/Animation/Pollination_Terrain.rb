# Pollination Terrain cast + persistent pollination battlefield - Pokemon Essentials v21.1.
# Install in Plugins/[KAITO] Plugin/ and recompile. No external graphics.
# Requires the existing Pollination Terrain gameplay plugin; this file changes visuals only.
# Move: POLLINATIONTERRAIN. Field: Pollination (or PollinationTerrain). Common: PollinationTerrain.
# Cast hides/restores HP and plays existing SE/Anim sounds. Ambient stays quiet.
module PollinationTerrainVisual
  VERSION = "1.0"
  CAST_SECONDS = 2.10
  TERRAIN_IDS = [:Pollination,:PollinationTerrain]
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
  def self.flower_cluster(variant)
    b=Bitmap.new(64,72)
    colours=[[255,231,143],[248,179,128],[241,203,232]]
    [[17,30,7],[35,17,8],[49,38,6]].each_with_index do |(x,y,r),j|
      line(b,32,68,x,y+3,2,Color.new(80,131,63,235))
      polygon(b,[[28,58],[15,48],[21,61],[30,64]],Color.new(122,163,71,220))
      polygon(b,[[33,52],[46,43],[41,57],[32,61]],Color.new(157,181,85,220))
      5.times do |k|
        a=k*Math::PI*2/5-0.6
        px=(x+Math.cos(a)*r*0.7).round;py=(y+Math.sin(a)*r*0.7).round
        disc(b,px,py,(r*0.45).round,Color.new(*colours[(variant+j)%3],245))
        b.fill_rect(px-1,py-1,2,2,Color.new(255,246,198,170))
      end
      disc(b,x,y,3,Color.new(188,124,47,255))
      disc(b,x,y-1,2,Color.new(255,214,81,255))
      b.fill_rect(x,y-2,1,1,Color.new(255,250,187,255))
    end
    b
  end
  def self.bee_bitmap(phase)
    b=Bitmap.new(32,28)
    # Two wing poses, a striped abdomen, round head and fine antennae.
    [[12,phase==0 ? 7 : 13],[20,phase==0 ? 6 : 12]].each do |x,y|
      disc(b,x,y,5,Color.new(215,238,218,160))
      line(b,x-2,y-2,x+2,y+1,1,Color.new(250,252,227,200))
    end
    polygon(b,[[7,16],[10,12],[19,12],[23,16],[19,20],[10,20]],Color.new(237,188,68,245))
    [11,16].each { |x|b.fill_rect(x,13,2,6,Color.new(109,86,43,235)) }
    disc(b,24,15,4,Color.new(114,92,50,245))
    b.fill_rect(25,13,2,2,Color.new(249,247,206,250))
    line(b,23,12,22,8,1,Color.new(104,92,51,220))
    line(b,25,12,27,9,1,Color.new(104,92,51,220))
    line(b,8,16,4,16,1,Color.new(106,84,43,225))
    b
  end
  def self.assets
    floor=Bitmap.new(256,192);bed=Bitmap.new(256,192)
    192.times do |y|
      depth=[[(y/192.0-0.13)/0.55,0].max,1].min
      floor.fill_rect(0,y,256,1,Color.new(181,171,77,(depth*depth*(3-2*depth)*255).round))
      next if y<30
      256.times do |x|
        v=Math.sin(x*0.053+y*0.073+Math.sin(y*0.031))*Math.cos(y*0.09-x*0.03)
        rgb=v>0 ? [186,166,71] : [72,122,64]
        bed.fill_rect(x,y,1,1,Color.new(*rgb,(v.abs*depth*48).round))
      end
    end
    cloud=Bitmap.new(192,64)
    32.times do |row|
      48.times do |col|
        x,y=col*4,row*2
        d=Math.exp(-((x-90)/64.0)**2-((y-32-Math.sin(x*0.04)*5)/15.0)**2)
        cloud.fill_rect(x,y,4,2,Color.new(244,215,115,(d*40).round))
      end
    end
    pollen=Bitmap.new(12,12)
    disc(pollen,6,6,4,Color.new(255,205,77,65))
    disc(pollen,6,6,2,Color.new(255,220,110,235))
    pollen.fill_rect(5,4,2,2,Color.new(255,249,190,255))
    petal=Bitmap.new(12,18)
    polygon(petal,[[5,1],[10,5],[9,11],[4,17],[2,11],[2,5]],Color.new(251,210,151,225))
    line(petal,5,3,5,12,1,Color.new(255,241,199,220))
    patch=Bitmap.new(128,64)
    32.times do |row|
      64.times do |col|
        x,y=col*2,row*2
        d=Math.exp(-((x-64)/48.0)**2-((y-32)/19.0)**2)
        v=Math.sin(x*0.17+y*0.21)
        patch.fill_rect(x,y,2,2,Color.new(115+(v*20).round,147+(v*15).round,66,(d*75).round))
      end
    end
    gust=Bitmap.new(160,40)
    3.times do |j|
      last=nil
      145.times do |i|
        p=i/144.0
        x=i+7;y=19+Math.sin(p*Math::PI*1.7+j)*5+j*3
        alpha=(Math.sin(p*Math::PI)*85).round
        line(gust,*last,x,y,1,Color.new(255,231,155,alpha)) if last
        last=[x,y]
      end
    end
    [floor,bed,cloud,pollen,petal,patch,gust,flower_cluster(0),flower_cluster(1),flower_cluster(2),bee_bitmap(0),bee_bitmap(1)]
  end
  def self.play_se(second=false)
    names=second ? ["PRSFX- Pollen Puff2","PRSFX- Sweet Scent"] : ["PRSFX- Pollen Puff1","PRSFX- Silver Wind"]
    names.each do |name|
      next unless [".wav",".ogg",".mp3"].any? { |ext|File.file?("Audio/SE/Anim/#{name}#{ext}") }
      pbSEPlay("Anim/#{name}",second ? 48 : 72,100)
      break
    end
  end
  class Layer
    def initialize(hash,viewport)
      @hash,@viewport=hash,viewport;@sprites,@bitmaps,@keys=[],[],[]
      @age,@alpha=0.0,0.0;@disposed=false
      begin
        @bitmaps.concat(PollinationTerrainVisual.assets)
        floor,bed,cloud,pollen,petal,patch,gust=@bitmaps[0,7]
        @floor=make(floor,0,0,2);@bed=make(bed,0,0,3)
        [@floor,@bed].each { |s|s.zoom_x,s.zoom_y=Graphics.width/256.0,Graphics.height/192.0 }
        @patches=Array.new(18) {make(patch,64,32,4)}
        @flowers=Array.new(24) { |i|make(@bitmaps[7+i%3],32,68,5) }
        @clouds=Array.new(7) {make(cloud,96,32,6)}
        @pollen=Array.new(100) {make(pollen,6,6,8)}
        @petals=Array.new(20) {make(petal,6,9,8)}
        @gusts=Array.new(7) {make(gust,80,20,7)}
        @bees=Array.new(8) {make(@bitmaps[10],16,14,9)}
      rescue
        dispose;raise
      end
    end
    def make(bitmap,ox,oy,z)
      s=Sprite.new(@viewport);@sprites<<s
      s.bitmap,s.ox,s.oy,s.z=bitmap,ox,oy,z;s.opacity=0
      key="pollination_terrain_visual_#{object_id}_#{@keys.length}"
      @keys<<key;@hash[key]=s;s
    end
    def position(i,w,h)
      x=(Math.sin(i*127.1+2.7)*43758.5453)%1.0
      depth=(Math.sin(i*91.7+4.3)*43758.5453)%1.0
      [w*(0.03+x*0.94),h*(0.29+depth*0.69),depth]
    end
    def update(active,cast,pulse,animate)
      dt=1.0/[Graphics.frame_rate,1].max
      @age+=dt if animate || cast
      @alpha=[[@alpha+((active || cast) ? dt*3.2 : -dt*3.2),0].max,1].min
      w,h=Graphics.width.to_f,Graphics.height.to_f;sx,sy=w/512.0,h/384.0
      crest=cast ? Math.sin(cast*Math::PI) : 0.0
      spread=cast ? [[cast/0.58,0].max,1].min : 1.0
      shared_tint=defined?(TerrainFloorTint::COLOURS) && PollinationTerrainVisual::TERRAIN_IDS.any? { |id|TerrainFloorTint::COLOURS.key?(id) }
      @floor.opacity=shared_tint ? 0 : (@alpha*(64+crest*15)).round
      @bed.opacity=(@alpha*spread*185).round
      @patches.each_with_index do |s,i|
        x,y,depth=position(i,w,h)
        s.x,s.y=x,y
        s.zoom_x,s.zoom_y=sx*(0.85+depth*0.50),sy*(0.55+depth*0.35)
        s.opacity=(@alpha*spread*180).round
      end
      @flowers.each_with_index do |s,i|
        x,y,depth=position(i,w,h)
        reveal=cast ? [[(cast-depth*0.07-i%3*0.025)/0.58,0].max,1].min : 1.0
        size=0.34+depth*0.37+i%3*0.025
        s.x,s.y=x,y
        s.zoom_x,s.zoom_y=sx*size,sy*size*reveal
        s.angle=Math.sin(@age*1.45+i)*3
        s.mirror=i.odd?
        s.opacity=(@alpha*reveal*225).round
      end
      @clouds.each_with_index do |s,i|
        p=(@age*(0.025+i%3*0.007)+i*0.173)%1.0
        s.x=-150*sx+p*(w+300*sx)
        s.y=h*(0.24+i%4*0.22)+Math.sin(@age*0.65+i)*6*sy
        s.zoom_x,s.zoom_y=sx*(1.6+i%2*0.25),sy*(0.50+i%3*0.12)
        s.opacity=(@alpha*spread*Math.sin(p*Math::PI)*(110+crest*100+pulse*20)).round
      end
      @pollen.each_with_index do |s,i|
        p=(@age*(0.065+i%5*0.012)+i*0.61803398875)%1.0
        depth=(i*0.197)%1.0
        s.x=-15*sx+p*(w+30*sx)+Math.sin(@age*1.6+i)*9*sx
        base=h*(0.16+depth*0.80)
        s.y=base+Math.sin(@age*(0.8+i%3*0.2)+i*2.1)*12*sy-crest*18*sy
        size=0.20+i%4*0.075
        s.zoom_x,s.zoom_y=sx*size,sy*size
        s.opacity=(@alpha*spread*Math.sin(p*Math::PI)*(125+i%3*30+crest*35)).round
      end
      @petals.each_with_index do |s,i|
        p=(@age*(0.09+i%3*0.018)+i*0.173)%1.0
        s.x=-20*sx+p*(w+40*sx)
        s.y=h*(0.19+(i*0.219)%0.76)+Math.sin(@age*1.3+i)*14*sy
        size=0.21+i%3*0.06
        s.zoom_x=sx*size*(0.70+Math.sin(@age*3+i)*0.25);s.zoom_y=sy*size
        s.angle=@age*(i.even? ? 55 : -45)+i*31
        s.opacity=(@alpha*spread*Math.sin(p*Math::PI)*(150+crest*40)).round
      end
      @gusts.each_with_index do |s,i|
        p=(@age*0.12+i*0.137)%1.0
        s.x=-110*sx+p*(w+220*sx);s.y=h*(0.25+i%4*0.21)
        s.zoom_x,s.zoom_y=sx*(0.8+i%3*0.2),sy*0.32
        s.opacity=(@alpha*spread*Math.sin(p*Math::PI)*(85+crest*100)).round
      end
      @bees.each_with_index do |s,i|
        x,y,depth=position((i*3+2)%24,w,h)
        a=@age*(0.75+i%3*0.13)+i*2.399
        s.x=x+Math.cos(a)*(27+i%3*7)*sx
        s.y=y-(22+depth*13)*sy+Math.sin(a*1.5)*10*sy
        size=0.45+depth*0.20
        s.zoom_x,s.zoom_y=sx*size,sy*size
        s.mirror=Math.sin(a)>0
        s.bitmap=@bitmaps[10+((@age*12).floor+i)%2]
        s.angle=Math.sin(a)*9
        s.opacity=(@alpha*spread*195).round
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
      return super unless moveID==:POLLINATIONTERRAIN
      @pollination_terrain_visual_requested=true
      # pbStartTerrain calls Common:PollinationTerrain after setting the field; cast once.
    end
    def pbCommonAnimationExists?(name)
      return true if ["pollinationterrain"].include?(name.to_s.gsub(/[^a-z]/i,"").downcase)
      super
    end
    def pbCommonAnimation(name,user=nil,target=nil)
      key=name.to_s.gsub(/[^a-z]/i,"").downcase
      return super unless ["pollinationterrain"].include?(key)
      requested=@pollination_terrain_visual_requested
      @pollination_terrain_visual_requested=false
      return if @battle && !@battle.showAnims
      return if @pollination_terrain_visual_cast
      kind=:Pollination
      full=requested || @pollination_terrain_visual_last_cast!=kind
      duration=full ? PollinationTerrainVisual::CAST_SECONDS : 0.24
      boxes=full ? {} : nil
      @pollination_terrain_visual_boxes=boxes
      begin
        if full
          pbPollinationTerrainVisualHideHP
          PollinationTerrainVisual.play_se
        end
        second=false
        @pollination_terrain_visual_cast_kind=kind
        frames=[(Graphics.frame_rate*duration).round,2].max
        frames.times do |f|
          p=f.to_f/(frames-1)
          @pollination_terrain_visual_cast=p if full
          @pollination_terrain_visual_pulse=full ? 0 : Math.sin(p*Math::PI)
          if full && !second && p>=0.48
            PollinationTerrainVisual.play_se(true)
            second=true
          end
          pbUpdate
        end
        @pollination_terrain_visual_last_cast=kind if PollinationTerrainVisual.active?(@battle)
      ensure
        @pollination_terrain_visual_cast=nil
        @pollination_terrain_visual_cast_kind=nil
        @pollination_terrain_visual_pulse=0
        @pollination_terrain_visual_boxes=nil
        boxes.each_value { |s,v|s.visible=v if s && !s.disposed? } if boxes
      end
    end
    def pbPollinationTerrainVisualHideHP
      return unless @pollination_terrain_visual_boxes && @sprites
      @sprites.each do |key,s|
        next unless key.to_s.start_with?("dataBox_") && s && !s.disposed?
        @pollination_terrain_visual_boxes[s.object_id]||=[s,s.visible]
        s.visible=false
      end
    end
    def pbGraphicsUpdate
      if @sprites && @viewport && !@viewport.disposed? && @battle
        active=PollinationTerrainVisual.active?(@battle)
        if active || @pollination_terrain_visual_cast || @pollination_terrain_visual_layer
          @pollination_terrain_visual_layer||=PollinationTerrainVisual::Layer.new(@sprites,@viewport)
          @pollination_terrain_visual_layer.update(active,@pollination_terrain_visual_cast,@pollination_terrain_visual_pulse.to_f,@battle.showAnims)
          if !active && !@pollination_terrain_visual_cast && @pollination_terrain_visual_layer.faded?
            @pollination_terrain_visual_layer.dispose
            @pollination_terrain_visual_layer=nil
          end
        end
        @pollination_terrain_visual_last_cast=nil if !active && !@pollination_terrain_visual_cast
        pbPollinationTerrainVisualHideHP
      end
      super
    end
    def pbDisposeSprites
      if @pollination_terrain_visual_layer
        @pollination_terrain_visual_layer.dispose
        @pollination_terrain_visual_layer=nil
      end
      super
    end
  end
end
Battle::Scene.prepend(PollinationTerrainVisual::SceneHooks)
