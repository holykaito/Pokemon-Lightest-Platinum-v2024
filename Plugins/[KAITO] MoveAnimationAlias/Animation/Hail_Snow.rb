# Hail / Snowscape + persistent hail or snow - Pokemon Essentials v21.1.
# Add to an existing plugin folder; no PNG/audio/PBS imports.
# Honors Gen 9 HAIL_WEATHER_TYPE (0 hail / 1 snow / 2 mixed). No weather rule changes.
# Install in Plugins/[KAITO] Plugin/ and recompile. One file, no external assets.
# Supports HAIL/SNOWSCAPE, Common:Hail/Snow/Hailstorm and Snow Warning activation.
# Full cast hides/restores databoxes; ambient and turn pulses keep HP visible.
# Existing Audio/SE/Anim files are used only on the initial cast.
module HailSnowWeatherVisual
  VERSION = "1.0"
  CAST_SECONDS = 2.05
  WEATHER_IDS = [:Hail,:Snow,:Hailstorm]
  MOVE_IDS = [:HAIL,:SNOWSCAPE]
  COMMON_NAMES = ["hail","snow","snowscape","hailstorm"]
  def self.mode(weather=nil)
    return :snow if weather==:Snow
    return :mixed if weather==:Hailstorm
    setting=defined?(Settings::HAIL_WEATHER_TYPE) ? Settings::HAIL_WEATHER_TYPE : 0
    return :mixed if setting==2
    setting==1 ? :snow : :hail
  end
  def self.active?(battle)
    battle && battle.field && WEATHER_IDS.include?(battle.field.weather)
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
    wash=Bitmap.new(256,192)
    192.times { |y|wash.fill_rect(0,y,256,1,Color.new(126,158,201,(42-y/192.0*23).round)) }
    cloud=Bitmap.new(160,80)
    40.times do |row|
      80.times do |col|
        x,y=col*2,row*2
        density=0.0
        [[31,40,29,22],[62,27,30,23],[95,34,34,25],[129,44,30,21]].each do |cx,cy,rx,ry|
          density+=Math.exp(-((x-cx)/rx.to_f)**2-((y-cy)/ry.to_f)**2)
        end
        edge=[[x/16.0,(159-x)/16.0,1.0].min,0].max
        cloud.fill_rect(x,y,2,2,Color.new(166,186,211,([density*42,80].min*edge).round))
      end
    end
    flake=Bitmap.new(24,24)
    6.times do |i|
      a=i*Math::PI/3
      x,y=12+Math.cos(a)*9,12+Math.sin(a)*9
      line(flake,12,12,x,y,1,Color.new(232,247,255,235))
      [-1,1].each do |side|
        bx,by=12+Math.cos(a)*5,12+Math.sin(a)*5
        line(flake,bx,by,bx+Math.cos(a+side*0.85)*3,by+Math.sin(a+side*0.85)*3,1,Color.new(194,222,249,210))
      end
    end
    disc(flake,12,12,2,Color.new(250,254,255,245))
    ice=Bitmap.new(20,24)
    polygon(ice,[[9,2],[16,6],[17,15],[10,21],[3,17],[2,8]],Color.new(115,177,221,220))
    polygon(ice,[[9,2],[16,6],[10,12],[2,8]],Color.new(238,251,255,255))
    polygon(ice,[[10,12],[16,6],[17,15],[10,21]],Color.new(168,217,245,245))
    line(ice,3,8,9,4,1,Color.new(255,255,255,245))
    chip=Bitmap.new(12,12)
    polygon(chip,[[6,1],[10,6],[5,10],[2,7]],Color.new(207,239,255,235))
    line(chip,6,2,4,6,1,Color.new(252,255,255,255))
    mist=Bitmap.new(256,64)
    64.times do |y|
      32.times do |j|
        v=Math.exp(-((y-32-Math.sin(j*0.4)*5)/13.0)**2)
        edge=Math.sin((j+0.5)/32.0*Math::PI)
        mist.fill_rect(j*8,y,8,1,Color.new(208,229,247,(v*edge*36).round))
      end
    end
    puff=Bitmap.new(32,20)
    10.times do |row|
      16.times do |col|
        x,y=col*2,row*2
        density=Math.exp(-((x-16)/10.0)**2-((y-11)/5.0)**2)
        puff.fill_rect(x,y,2,2,Color.new(235,247,255,(density*155).round))
      end
    end
    [wash,cloud,flake,ice,chip,mist,puff]
  end
  def self.play_se(second=false,mode=:hail)
    names=if mode==:snow
      second ? ["PRSFX- Powder Snow2","PRSFX- Hail"] : ["PRSFX- Powder Snow1","PRSFX- HailMove"]
    else
      second ? ["PRSFX- Hail","PRSFX- Powder Snow2"] : ["PRSFX- HailMove","PRSFX- Hail"]
    end
    names.each do |name|
      next unless [".wav",".ogg",".mp3"].any? { |ext|File.file?("Audio/SE/Anim/#{name}#{ext}") }
      pbSEPlay("Anim/#{name}",second ? 48 : 75,100)
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
        @bitmaps.concat(HailSnowWeatherVisual.assets)
        wash,cloud,flake,ice,chip,mist,puff=@bitmaps
        @wash=make(wash,0,0,3)
        @wash.zoom_x,@wash.zoom_y=Graphics.width/256.0,Graphics.height/192.0
        @clouds=Array.new(8) {make(cloud,80,40,4)}
        @flakes=Array.new(88) {make(flake,12,12,8)}
        @ice=Array.new(54) {make(ice,10,12,9)}
        @chips=Array.new(48) {make(chip,6,6,9)}
        @puffs=Array.new(16) {make(puff,16,12,6)}
        @mist=Array.new(3) {make(mist,128,32,6)}
      rescue
        dispose
        raise
      end
    end
    def make(bitmap,ox,oy,z)
      s=Sprite.new(@viewport)
      @sprites<<s
      s.bitmap,s.ox,s.oy,s.z=bitmap,ox,oy,z
      key="hail_snow_weather_visual_#{object_id}_#{@keys.length}"
      @keys<<key
      @hash[key]=s
      s
    end
    def update(active,cast,pulse,animate,mode)
      @mode=mode if active || cast || !@mode
      mode=@mode
      dt=1.0/[Graphics.frame_rate,1].max
      @age+=dt if animate || cast
      @alpha=[[@alpha+((active || cast) ? dt*3.2 : -dt*3.2),0].max,1].min
      w,h=Graphics.width.to_f,Graphics.height.to_f
      scale=w/512.0
      crest=cast ? Math.sin(cast*Math::PI) : 0.0
      gather=cast ? [[cast/0.30,0].max,1].min : 1.0
      fall=cast ? [[(cast-0.12)/0.30,0].max,1].min : 1.0
      snow=mode!=:hail
      hail=mode!=:snow
      @wash.opacity=(@alpha*(140+crest*65)).round
      @clouds.each_with_index do |s,i|
        s.x=w*(-0.08+(i%5)*0.28)+Math.sin(@age*0.25+i)*10+(i.even? ? -1 : 1)*(1-gather)*w*0.42
        s.y=h*(0.025+(i/5)*0.095)+Math.sin(@age*0.4+i)*3
        s.zoom_x=scale*(1.28+(i%3)*0.10)
        s.zoom_y=scale*(0.85+(i%2)*0.12)
        s.opacity=(@alpha*gather*(175+crest*55)).round
      end
      @flakes.each_with_index do |s,i|
        p=(@age*(0.13+(i%5)*0.018)+i*0.61803398875)%1.0
        s.x=((i*0.754877666*w+@age*22+Math.sin(@age*1.1+i*2)*22)%(w+52))-26
        s.y=-24+p*(h+48)
        size=scale*(0.17+(i%5)*0.095)
        s.zoom_x=s.zoom_y=size
        s.angle=@age*(i.even? ? 28 : -22)+i*31
        s.z=i%7==0 ? 65 : 8
        s.opacity=snow ? (@alpha*fall*(125+i%4*27+crest*30)).round : 0
      end
      @ice.each_with_index do |s,i|
        p=(@age*(0.85+i%3*0.09)+i*0.61803398875)%1.0
        ground=h*(0.54+(i%4)*0.115)
        x=w*(0.02+(i*0.219)%0.96)
        s.x=x+(1-p)*48
        s.y=-30+p*(ground+30)
        size=scale*(0.24+i%4*0.065)
        s.zoom_x=s.zoom_y=size
        s.angle=i*29+@age*150
        s.z=i%6==0 ? 65 : 9
        s.opacity=hail ? (@alpha*fall*(180+i%3*25)).round : 0
      end
      @chips.each_with_index do |s,i|
        lane=i/3
        p=(@age*(0.85+lane%3*0.09)+lane*0.61803398875)%1.0
        # Burst at each matching hail impact, then fall and dissolve.
        q=p/0.32
        a=(i%3)*1.15+0.35
        side=i%3==0 ? -1 : 1
        s.x=w*(0.02+(lane*0.219)%0.96)+side*Math.cos(a)*q*19*scale
        s.y=h*(0.54+(lane%4)*0.115)-Math.sin(a)*q*25*scale+q*q*22*scale
        s.zoom_x=s.zoom_y=scale*(0.18+lane%3*0.05)*(1-0.35*[q,1].min)
        s.angle=i*71+q*160
        s.opacity=(hail && q<1) ? (@alpha*fall*(1-q)*240).round : 0
      end
      @puffs.each_with_index do |s,i|
        p=(@age*(hail ? 0.85+i%3*0.09 : 0.48)+i*0.61803398875)%1.0
        q=p/0.40
        s.x=w*(0.02+(i*0.219)%0.96)
        s.y=h*(0.54+(i%4)*0.115)-q*2*scale
        s.zoom_x=scale*(0.25+q*0.62)
        s.zoom_y=scale*(0.20+q*0.15)
        s.opacity=q<1 ? (@alpha*fall*(1-q)*(hail ? 180 : 105)).round : 0
      end
      @mist.each_with_index do |s,i|
        s.x=((@age*18+i*w/3)%(w+320*scale))-160*scale
        s.y=h*(0.54+i*0.17)+Math.sin(@age*0.7+i)*4
        s.zoom_x=scale*1.65
        s.zoom_y=0.58
        s.opacity=(@alpha*fall*(140+crest*65+pulse*20)).round
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
      return super unless HailSnowWeatherVisual::MOVE_IDS.include?(moveID)
      @hail_snow_visual_requested=true
      # Cast once from the weather common callback, including Snow Warning.
    end
    def pbCommonAnimationExists?(name)
      return true if HailSnowWeatherVisual::COMMON_NAMES.include?(name.to_s.downcase.gsub(/[^a-z]/,""))
      super
    end
    def pbCommonAnimation(name,user=nil,target=nil)
      key=name.to_s.downcase.gsub(/[^a-z]/,"")
      return super unless HailSnowWeatherVisual::COMMON_NAMES.include?(key)
      requested=@hail_snow_visual_requested
      @hail_snow_visual_requested=false
      return if @battle && !@battle.showAnims
      return if @hail_snow_visual_cast
      kind=HailSnowWeatherVisual.active?(@battle) ? @battle.field.weather : (["snow","snowscape"].include?(key) ? :Snow : (key=="hailstorm" ? :Hailstorm : :Hail))
      mode=HailSnowWeatherVisual.mode(kind)
      signature=[kind,mode]
      full=requested || @hail_snow_visual_last_cast!=signature
      duration=full ? HailSnowWeatherVisual::CAST_SECONDS : 0.24
      boxes=full ? {} : nil
      @hail_snow_visual_boxes=boxes
      begin
        if full
          pbHailSnowVisualHideHP
          HailSnowWeatherVisual.play_se(false,mode)
        end
        second=false
        @hail_snow_visual_cast_kind=kind
        frames=[(Graphics.frame_rate*duration).round,2].max
        frames.times do |f|
          p=f.to_f/(frames-1)
          @hail_snow_visual_cast=p if full
          @hail_snow_visual_pulse=full ? 0 : Math.sin(p*Math::PI)
          if full && !second && p>=0.48
            HailSnowWeatherVisual.play_se(true,mode)
            second=true
          end
          pbUpdate
        end
        @hail_snow_visual_last_cast=signature if HailSnowWeatherVisual.active?(@battle)
      ensure
        @hail_snow_visual_cast=nil
        @hail_snow_visual_cast_kind=nil
        @hail_snow_visual_pulse=0
        @hail_snow_visual_boxes=nil
        boxes.each_value { |s,v|s.visible=v if s && !s.disposed? } if boxes
      end
    end
    def pbHailSnowVisualHideHP
      return unless @hail_snow_visual_boxes && @sprites
      @sprites.each do |key,s|
        next unless key.to_s.start_with?("dataBox_") && s && !s.disposed?
        @hail_snow_visual_boxes[s.object_id]||=[s,s.visible]
        s.visible=false
      end
    end
    def pbGraphicsUpdate
      if @sprites && @viewport && !@viewport.disposed? && @battle
        active=HailSnowWeatherVisual.active?(@battle)
        if active || @hail_snow_visual_cast || @hail_snow_visual_layer
          @hail_snow_visual_layer||=HailSnowWeatherVisual::Layer.new(@sprites,@viewport)
          mode=HailSnowWeatherVisual.mode(@hail_snow_visual_cast_kind || @battle.field.weather)
          @hail_snow_visual_layer.update(active,@hail_snow_visual_cast,@hail_snow_visual_pulse.to_f,@battle.showAnims,mode)
          if !active && !@hail_snow_visual_cast && @hail_snow_visual_layer.faded?
            @hail_snow_visual_layer.dispose
            @hail_snow_visual_layer=nil
          end
        end
        @hail_snow_visual_last_cast=nil if !active && !@hail_snow_visual_cast
        pbHailSnowVisualHideHP
      end
      super
    end
    def pbDisposeSprites
      if @hail_snow_visual_layer
        @hail_snow_visual_layer.dispose
        @hail_snow_visual_layer=nil
      end
      super
    end
  end
end
Battle::Scene.prepend(HailSnowWeatherVisual::SceneHooks)
