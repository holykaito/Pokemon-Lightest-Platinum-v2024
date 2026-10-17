# Ravine Terrain cast + persistent ravine battlefield - Pokemon Essentials v21.1.
# Install in Plugins/[KAITO] Plugin/ and recompile. No external graphics.
# Requires the existing Ravine Terrain gameplay plugin; this file changes visuals only.
# Move: RAVINETERRAIN. Field: Ravine (or RavineTerrain). Common: RavineTerrain.
# Cast hides/restores HP and plays existing SE/Anim sounds. Ambient stays quiet.
module RavineTerrainVisual
  VERSION = "2.0"
  CAST_SECONDS = 2.15
  TERRAIN_IDS = [:Ravine,:RavineTerrain]
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
  def self.ridge(variant)
    b=Bitmap.new(112,72)
    top=[[7,24],[32,8+variant*3],[72,7],[102,23],[89,40],[50,47],[17,42]]
    polygon(b,top.map { |x,y|[x,y+14] },Color.new(44,57,65,180))
    polygon(b,[[17,42],[50,47],[89,40],[89,54],[51,64],[17,56]],Color.new(69,80,80,220))
    polygon(b,top,Color.new(124+variant*6,138+variant*4,133+variant*3,180))
    polygon(b,[[7,24],[32,8+variant*3],[72,7],[55,22],[20,33]],Color.new(173,183,162,155))
    line(b,7,24,32,8+variant*3,1,Color.new(208,217,192,210))
    line(b,32,8+variant*3,72,7,1,Color.new(193,207,187,190))
    [[22,48,49,55],[49,55,85,47],[24,53,50,60],[50,60,83,52]].each { |p|line(b,*p,1,Color.new(147,149,123,110)) }
    line(b,66,13,57,29,1,Color.new(76,91,91,140))
    line(b,57,29,69,36,1,Color.new(76,91,91,140))
    b
  end
  def self.rift(variant)
    b=Bitmap.new(256,160)
    back=[[9,52],[35,35],[60,40],[86,20],[113,28],[143,14],[169,26],[198,20],[222,37],[244,46]]
    front=[[237,80],[214,88],[193,103],[162,101],[142,119],[114,110],[86,124],[58,108],[32,110],[14,84]]
    # Distinct broken banks; a broad opening replaces the narrow linear cut.
    back=back.each_with_index.map { |(x,y),i|[x,y+((i+variant)%3-1)*4] }
    opening=back+front
    polygon(b,opening.map { |x,y|[128+(x-128)*1.035,78+(y-78)*1.09].map(&:round) },Color.new(130,144,127,175))
    polygon(b,opening,Color.new(20,34,46,245))
    # Tall rear wall descends into darkness, with individually shaded rock facets.
    6.times do |band|
      t0=band/6.0;t1=(band+1)/6.0
      upper=back.map { |x,y|[(x+(128-x)*t0*0.14).round,(y+44*t0).round] }
      lower=back.map { |x,y|[(x+(128-x)*t1*0.14).round,(y+44*t1).round] }
      back.each_cons(2).with_index do |_,i|
        shade=((i+variant)%3)*6
        c=Color.new(88-band*10+shade,108-band*12+shade,108-band*10+shade,240)
        polygon(b,[upper[i],upper[i+1],lower[i+1],lower[i]],c)
      end
    end
    # Isolated vertical fractures and projecting shelves establish cliff height.
    [1,3,5,7,8].each do |i|
      x,y=back[i]
      line(b,x,y+5,x+(128-x)*0.12,y+33,1,Color.new(33,51,58,185))
      line(b,x+2,y+7,x+(128-x)*0.08+2,y+20,1,Color.new(131,151,137,125))
    end
    [[58,60,88,65],[109,49,137,54],[167,55,194,59]].each do |p|
      line(b,*p,2,Color.new(105,125,115,145))
    end
    # Uneven front lip hides the foot of the wall, leaving the core in shadow.
    front.each_cons(2).with_index do |(p,q),i|
      line(b,*p,*q,4,Color.new(47,66,69,230))
      line(b,p[0],p[1]+2,q[0],q[1]+2,2,Color.new(153,167,144,190))
    end
    back.each_cons(2).with_index do |(p,q),i|
      line(b,*p,*q,2,Color.new(175,189,163,205)) unless (i+variant)%3==0
    end
    b
  end
  def self.abyss_mist(variant)
    b=Bitmap.new(256,160)
    (63..112).each do |y|
      (49..208).step(2) do |x|
        dx=(x-130)/65.0
        dy=(y-88-Math.sin(x*0.045+variant)*4)/13.0
        d=Math.exp(-dx*dx-dy*dy)
        b.fill_rect(x,y,2,1,Color.new(125,162,164,(d*43).round))
      end
    end
    b
  end
  def self.wind_bitmap(phase)
    b=Bitmap.new(192,96)
    3.times do |j|
      last=nil
      150.times do |i|
        u=i/149.0
        a=u*Math::PI*2.4+phase*Math::PI/5+j*0.35
        r=45*(1-u)+7
        x=109+Math.cos(a)*r+(u-0.5)*50
        y=50+Math.sin(a)*r*0.45-u*14+j*6
        alpha=(Math.sin(u*Math::PI)*(j==1 ? 200 : 125)).round
        if last
          line(b,*last,x,y,3,Color.new(127,188,194,(alpha*0.25).round))
          line(b,*last,x,y,1,Color.new(223,244,234,alpha))
        end
        last=[x,y]
      end
    end
    # Thin trailing lines connect the curl to the cross-field wind.
    2.times do |j|
      last=nil
      92.times do |x|
        y=62+j*7+Math.sin(x*0.034+phase*0.3)*5
        alpha=(Math.sin(x/91.0*Math::PI)*90).round
        line(b,*last,x+3,y,1,Color.new(195,222,214,alpha)) if last
        last=[x+3,y]
      end
    end
    b
  end
  def self.assets
    floor=Bitmap.new(256,192);bed=Bitmap.new(256,192)
    192.times do |y|
      depth=[[(y/192.0-0.12)/0.54,0].max,1].min
      floor.fill_rect(0,y,256,1,Color.new(109,140,139,(depth*depth*(3-2*depth)*255).round))
      next if y<28
      256.times do |x|
        v=Math.sin(x*0.07+y*0.065)*Math.cos(y*0.10-x*0.036)
        rgb=v>0 ? [140,151,128] : [57,80,88]
        bed.fill_rect(x,y,1,1,Color.new(*rgb,(v.abs*depth*39).round))
      end
    end
    haze=Bitmap.new(192,48)
    24.times do |row|
      48.times do |col|
        x,y=col*4,row*2
        v=Math.exp(-((x-90)/66.0)**2-((y-25-Math.sin(x*0.04)*3)/11.0)**2)
        haze.fill_rect(x,y,4,2,Color.new(176,199,182,(v*36).round))
      end
    end
    pebble=Bitmap.new(16,18)
    polygon(pebble,[[5,2],[12,4],[14,10],[8,15],[2,11],[1,6]],Color.new(65,83,87,235))
    polygon(pebble,[[5,2],[12,4],[8,9],[1,6]],Color.new(174,189,166,245))
    line(pebble,4,3,10,4,1,Color.new(215,223,194,235))
    [floor,bed,haze,pebble,ridge(0),ridge(1),ridge(2),rift(0),rift(1),rift(2),*Array.new(4) { |phase|wind_bitmap(phase) },abyss_mist(0),abyss_mist(1),abyss_mist(2)]
  end
  def self.play_se(second=false)
    names=second ? ["PRSFX- Tailwind","PRSFX- Wind"] : ["PRSFX- Whirlwind","PRSFX- Gust"]
    names.each do |name|
      next unless [".wav",".ogg",".mp3"].any? { |ext|File.file?("Audio/SE/Anim/#{name}#{ext}") }
      pbSEPlay("Anim/#{name}",second ? 48 : 72,second ? 95 : 100)
      break
    end
  end
  class Layer
    def initialize(hash,viewport)
      @hash,@viewport=hash,viewport;@sprites,@bitmaps,@keys=[],[],[]
      @age,@alpha=0.0,0.0;@disposed=false
      begin
        @bitmaps.concat(RavineTerrainVisual.assets)
        floor,bed,haze,pebble=@bitmaps[0,4]
        @floor=make(floor,0,0,2);@bed=make(bed,0,0,3)
        [@floor,@bed].each { |s|s.zoom_x,s.zoom_y=Graphics.width/256.0,Graphics.height/192.0 }
        @rifts=Array.new(3) { |i|make(@bitmaps[7+i],128,80,4) }
        @abyss_mist=Array.new(3) { |i|make(@bitmaps[14+i],128,80,5) }
        @ridges=Array.new(16) { |i|make(@bitmaps[4+i%3],56,58,5) }
        @haze=Array.new(6) {make(haze,96,24,6)}
        @winds=Array.new(9) {make(@bitmaps[10],96,48,7)}
        @pebbles=Array.new(48) {make(pebble,8,9,8)}
      rescue
        dispose;raise
      end
    end
    def make(bitmap,ox,oy,z)
      s=Sprite.new(@viewport);@sprites<<s
      s.bitmap,s.ox,s.oy,s.z=bitmap,ox,oy,z;s.opacity=0
      key="ravine_terrain_visual_#{object_id}_#{@keys.length}"
      @keys<<key;@hash[key]=s;s
    end
    def position(i,w,h)
      x=(Math.sin(i*127.1+2.7)*43758.5453)%1.0
      depth=(Math.sin(i*91.7+4.3)*43758.5453)%1.0
      [w*(0.025+x*0.95),h*(0.25+depth*0.73),depth]
    end
    def update(active,cast,pulse,animate)
      dt=1.0/[Graphics.frame_rate,1].max
      @age+=dt if animate || cast
      @alpha=[[@alpha+((active || cast) ? dt*3.2 : -dt*3.2),0].max,1].min
      w,h=Graphics.width.to_f,Graphics.height.to_f;sx,sy=w/512.0,h/384.0
      crest=cast ? Math.sin(cast*Math::PI) : 0.0
      spread=cast ? [[cast/0.58,0].max,1].min : 1.0
      shared_tint=defined?(TerrainFloorTint::COLOURS) && RavineTerrainVisual::TERRAIN_IDS.any? { |id|TerrainFloorTint::COLOURS.key?(id) }
      @floor.opacity=shared_tint ? 0 : (@alpha*(70+crest*15)).round
      @bed.opacity=(@alpha*spread*180).round
      @rifts.each_with_index do |s,i|
        s.x=w*[0.24,0.76,0.32][i]
        s.y=h*(0.31+i*0.265)
        s.zoom_x=sx*(1.07+i*0.12)
        s.zoom_y=sy*(0.61+i*0.075)*spread
        s.mirror=i.odd?
        s.angle=[-10,12,-7][i]
        s.opacity=(@alpha*spread*210).round
        fog=@abyss_mist[i]
        fog.x=s.x+Math.sin(@age*0.7+i)*3*sx
        fog.y=s.y+Math.cos(@age*0.6+i)*1.5*sy
        fog.zoom_x,fog.zoom_y=s.zoom_x,s.zoom_y
        fog.mirror,fog.angle=s.mirror,s.angle
        fog.opacity=(@alpha*spread*(135+Math.sin(@age*0.9+i)*40)).round
      end
      @ridges.each_with_index do |s,i|
        x,y,depth=position(i,w,h)
        reveal=cast ? [[(cast-depth*0.08-i%3*0.02)/0.57,0].max,1].min : 1.0
        s.x,s.y=x,y-(cast ? Math.sin(reveal*Math::PI)*8*sy : 0)
        s.zoom_x,s.zoom_y=sx*(0.43+depth*0.37),sy*(0.35+depth*0.30)
        s.mirror=i.odd?;s.angle=Math.sin(i*2.3)*5
        s.opacity=(@alpha*reveal*185).round
      end
      @haze.each_with_index do |s,i|
        p=(@age*(0.045+i%3*0.01)+i*0.173)%1.0
        s.x=-140*sx+p*(w+280*sx)
        s.y=h*(0.25+i%4*0.22)+Math.sin(@age*0.65+i)*4*sy
        s.zoom_x,s.zoom_y=sx*1.9,sy*(0.42+i%3*0.10)
        s.opacity=(@alpha*spread*Math.sin(p*Math::PI)*(80+crest*95+pulse*15)).round
      end
      @winds.each_with_index do |s,i|
        p=(@age*(0.10+i%3*0.015)+i*0.173)%1.0
        s.x=-135*sx+p*(w+270*sx)
        s.y=h*(0.21+(i*0.219)%0.73)+Math.sin(@age*1.1+i)*8*sy
        s.bitmap=@bitmaps[10+((@age*6).floor+i)%4]
        s.zoom_x,s.zoom_y=sx*(0.75+i%3*0.24),sy*(0.50+i%3*0.10)
        s.angle=i.even? ? -8 : 6
        s.opacity=(@alpha*spread*Math.sin(p*Math::PI)*(180+crest*65+pulse*10)).round
      end
      @pebbles.each_with_index do |s,i|
        p=(@age*(0.28+i%4*0.055)+i*0.61803398875)%1.0
        x,y,depth=position(i,w,h)
        a=p*Math::PI*2+i*2.399
        s.x=x+Math.cos(a)*(8+i%3*4)*sx+p*12*sx
        s.y=y-p*(12+crest*30)*sy+Math.sin(a)*3*sy
        size=i%7==0 ? 0.55+depth*0.20 : 0.16+i%4*0.06
        s.zoom_x,s.zoom_y=sx*size,sy*size
        s.angle=@age*(i.even? ? 55 : -70)+i*29
        s.opacity=(@alpha*spread*Math.sin(p*Math::PI)*(125+crest*70)).round
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
      return super unless moveID==:RAVINETERRAIN
      @ravine_terrain_visual_requested=true
      # pbStartTerrain calls Common:RavineTerrain after setting the field; cast once.
    end
    def pbCommonAnimationExists?(name)
      return true if ["ravineterrain"].include?(name.to_s.gsub(/[^a-z]/i,"").downcase)
      super
    end
    def pbCommonAnimation(name,user=nil,target=nil)
      key=name.to_s.gsub(/[^a-z]/i,"").downcase
      return super unless ["ravineterrain"].include?(key)
      requested=@ravine_terrain_visual_requested
      @ravine_terrain_visual_requested=false
      return if @battle && !@battle.showAnims
      return if @ravine_terrain_visual_cast
      kind=:Ravine
      full=requested || @ravine_terrain_visual_last_cast!=kind
      duration=full ? RavineTerrainVisual::CAST_SECONDS : 0.24
      boxes=full ? {} : nil
      @ravine_terrain_visual_boxes=boxes
      begin
        if full
          pbRavineTerrainVisualHideHP
          RavineTerrainVisual.play_se
        end
        second=false
        @ravine_terrain_visual_cast_kind=kind
        frames=[(Graphics.frame_rate*duration).round,2].max
        frames.times do |f|
          p=f.to_f/(frames-1)
          @ravine_terrain_visual_cast=p if full
          @ravine_terrain_visual_pulse=full ? 0 : Math.sin(p*Math::PI)
          if full && !second && p>=0.48
            RavineTerrainVisual.play_se(true)
            second=true
          end
          pbUpdate
        end
        @ravine_terrain_visual_last_cast=kind if RavineTerrainVisual.active?(@battle)
      ensure
        @ravine_terrain_visual_cast=nil
        @ravine_terrain_visual_cast_kind=nil
        @ravine_terrain_visual_pulse=0
        @ravine_terrain_visual_boxes=nil
        boxes.each_value { |s,v|s.visible=v if s && !s.disposed? } if boxes
      end
    end
    def pbRavineTerrainVisualHideHP
      return unless @ravine_terrain_visual_boxes && @sprites
      @sprites.each do |key,s|
        next unless key.to_s.start_with?("dataBox_") && s && !s.disposed?
        @ravine_terrain_visual_boxes[s.object_id]||=[s,s.visible]
        s.visible=false
      end
    end
    def pbGraphicsUpdate
      if @sprites && @viewport && !@viewport.disposed? && @battle
        active=RavineTerrainVisual.active?(@battle)
        if active || @ravine_terrain_visual_cast || @ravine_terrain_visual_layer
          @ravine_terrain_visual_layer||=RavineTerrainVisual::Layer.new(@sprites,@viewport)
          @ravine_terrain_visual_layer.update(active,@ravine_terrain_visual_cast,@ravine_terrain_visual_pulse.to_f,@battle.showAnims)
          if !active && !@ravine_terrain_visual_cast && @ravine_terrain_visual_layer.faded?
            @ravine_terrain_visual_layer.dispose
            @ravine_terrain_visual_layer=nil
          end
        end
        @ravine_terrain_visual_last_cast=nil if !active && !@ravine_terrain_visual_cast
        pbRavineTerrainVisualHideHP
      end
      super
    end
    def pbDisposeSprites
      if @ravine_terrain_visual_layer
        @ravine_terrain_visual_layer.dispose
        @ravine_terrain_visual_layer=nil
      end
      super
    end
  end
end
Battle::Scene.prepend(RavineTerrainVisual::SceneHooks)
