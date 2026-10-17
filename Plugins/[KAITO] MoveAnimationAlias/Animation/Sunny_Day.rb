# Sunny Day + persistent sunshine - Pokemon Essentials v21.1.
# Add to an existing plugin folder; no PNG/audio/PBS imports.
# Replaces SUNNYDAY and Common:Sun/HarshSun. Weather rules remain unchanged.
module SunnyWeatherVisual
  VERSION = "1.0"
  CAST_SECONDS = 1.85
  WEATHER_IDS = [:Sun,:HarshSun]
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
    halo = Bitmap.new(160,160)
    [[72,7],[62,12],[51,20],[41,32],[34,40]].each { |r,a| disc(halo,80,80,r,Color.new(255,206,114,a)) }
    corona = Bitmap.new(160,160)
    16.times do |i|
      a=i*Math::PI/8
      outer=i.even? ? 62 : 52
      pts=[[80+Math.cos(a-0.045)*35,80+Math.sin(a-0.045)*35],
           [80+Math.cos(a)*outer,80+Math.sin(a)*outer],
           [80+Math.cos(a+0.045)*35,80+Math.sin(a+0.045)*35]].map { |p|p.map(&:round) }
      polygon(corona,pts,Color.new(255,218,132,i.even? ? 170 : 125))
    end
    core=Bitmap.new(160,160)
    [[32,[255,181,64,235]],[29,[255,212,108,250]],[24,[255,233,153,255]],[17,[255,246,191,255]]].each do |r,c|
      disc(core,80,80,r,Color.new(*c))
    end
    wash=Bitmap.new(256,192)
    192.times do |y|
      wash.fill_rect(0,y,256,1,Color.new(255,206,114,(20-y/192.0*8).round))
    end
    beams=Array.new(4) do |i|
      b=Bitmap.new(256,192)
      target=[-58,18,105,199][i]
      (32...192).each do |y|
        p=(y-31)/161.0
        x=210+(target-210)*p
        half=1+p*(i.even? ? 20 : 14)
        a=((1-p*0.52)*Math.sin([p*2,1].min*Math::PI/2)*45).round
        b.fill_rect((x-half).round,y,(half*2+1).round,1,Color.new(255,233,164,a))
        b.fill_rect((x-half*0.3).round,y,[1,(half*0.6).round].max,1,Color.new(255,244,196,(a*0.65).round))
      end
      b
    end
    heat=Bitmap.new(256,64)
    3.times do |j|
      last=nil
      120.times do |i|
        x=8+i*2
        y=24+j*8+Math.sin(i/119.0*Math::PI*2.2+j*0.7)*5
        a=(Math.sin(i/119.0*Math::PI)*85).round
        line(heat,*last,x,y,2,Color.new(255,229,172,a)) if last
        last=[x,y]
      end
    end
    spark=Bitmap.new(20,20)
    spark.fill_rect(9,2,2,16,Color.new(255,230,166,170))
    spark.fill_rect(2,9,16,2,Color.new(255,230,166,170))
    spark.fill_rect(8,8,4,4,Color.new(255,252,220,245))
    ring=Bitmap.new(256,256)
    720.times do |i|
      a=i*Math::PI/360
      [[108,Color.new(255,214,121,125)],[112,Color.new(255,246,198,210)]].each do |r,c|
        ring.fill_rect((128+Math.cos(a)*r).round,(128+Math.sin(a)*r).round,2,2,c)
      end
    end
    [halo,corona,core,wash,*beams,heat,spark,ring]
  end
  def self.play_se(second=false)
    names=second ? ["PRSFX- Sunny","PRSFX- Morning Sun"] : ["PRSFX- Sunny Day","Fire/Sunny Day"]
    names.each do |name|
      next unless [".wav",".ogg",".mp3"].any? { |ext|File.file?("Audio/SE/Anim/#{name}#{ext}") }
      pbSEPlay("Anim/#{name}",second ? 50 : 75,100)
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
        @bitmaps.concat(SunnyWeatherVisual.assets)
        halo,corona,core,wash= @bitmaps[0,4]
        @halo,@corona,@core=make(halo,80,80,3),make(corona,80,80,4),make(core,80,80,5)
        @wash=make(wash,0,0,3)
        @wash.zoom_x,@wash.zoom_y=Graphics.width/256.0,Graphics.height/192.0
        @beams=Array.new(4) do |i|
          s=make(@bitmaps[4+i],0,0,4)
          s.zoom_x,s.zoom_y=Graphics.width/256.0,Graphics.height/192.0
          s
        end
        @heat=Array.new(3) { make(@bitmaps[8],128,32,6) }
        @sparks=Array.new(14) { make(@bitmaps[9],10,10,7) }
        @rings=Array.new(2) { make(@bitmaps[10],128,128,6) }
        (@sparks+@rings).each { |s|s.blend_type=1 }
      rescue
        dispose
        raise
      end
    end
    def make(bitmap,ox,oy,z)
      s=Sprite.new(@viewport)
      @sprites<<s
      s.bitmap,s.ox,s.oy,s.z=bitmap,ox,oy,z
      key="sunny_weather_visual_#{object_id}_#{@keys.length}"
      @keys<<key
      @hash[key]=s
      s
    end
    def update(active,cast,pulse,animate,harsh)
      dt=1.0/[Graphics.frame_rate,1].max
      @age+=dt if animate || cast
      @alpha=[[@alpha+((active || cast) ? dt*3.2 : -dt*3.2),0].max,1].min
      w,h=Graphics.width.to_f,Graphics.height.to_f
      scale=w/512.0
      x,y=w*0.82,h*0.16
      crest=cast ? Math.sin(cast*Math::PI) : 0.0
      grow=cast ? 1-(1-[cast/0.36,1].min)**3 : 1.0
      sunscale=scale*(0.76+crest*0.16)*(0.45+grow*0.55)
      [@halo,@corona,@core].each { |s|s.x,s.y=x,y;s.zoom_x=s.zoom_y=sunscale }
      @halo.zoom_x=@halo.zoom_y=sunscale*(1.0+0.025*Math.sin(@age*1.8))
      @corona.angle=@age*4.5
      @halo.opacity=(@alpha*grow*(harsh ? 255 : 225)).round
      @corona.opacity=(@alpha*grow*(145+crest*65+pulse*25)).round
      @core.opacity=(@alpha*grow*235).round
      @wash.opacity=(@alpha*(130+crest*90+pulse*15+(harsh ? 25 : 0))).round
      @beams.each_with_index do |s,i|
        s.x=Math.sin(@age*0.45+i)*4*scale
        s.y=0
        s.opacity=(@alpha*(145+Math.sin(@age*0.65+i)**2*25+crest*65+(harsh ? 15 : 0))).round
      end
      @heat.each_with_index do |s,i|
        s.x=((@age*11+i*w/3)%(w+300*scale))-150*scale
        s.y=h*(0.60+i*0.15)+Math.sin(@age*1.3+i)*4
        s.zoom_x=scale*1.5
        s.zoom_y=0.38
        s.opacity=(@alpha*(cast ? 55+crest*45 : 42+pulse*45+(harsh ? 25 : 0))).round
      end
      @sparks.each_with_index do |s,i|
        p=(@age*0.075+i*0.173)%1.0
        s.x=w*(0.04+(i*0.197)%0.91)+Math.sin(@age*0.6+i)*8
        s.y=h*(0.28+(i%4)*0.16)-p*20
        s.zoom_x=s.zoom_y=scale*(0.11+i%3*0.05)
        s.opacity=(@alpha*Math.sin(p*Math::PI)**2*(cast ? 150 : 65)).round
      end
      @rings.each_with_index do |s,i|
        if cast
          p=[[(cast-0.12-i*0.10)/0.66,0].max,1].min
          size=scale*(0.14+p*3.8)
          s.x,s.y=x,y
          s.zoom_x=s.zoom_y=size
          s.opacity=(@alpha*Math.sin(p*Math::PI)*120).round
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
      return super unless moveID==:SUNNYDAY
      @sunny_visual_requested=true
      # pbStartWeather calls Common:Sun after setting weather. Cast there once.
    end
    def pbCommonAnimationExists?(name)
      return true if ["sun","sunny","sunnyday","harshsun"].include?(name.to_s.downcase)
      super
    end
    def pbCommonAnimation(name,user=nil,target=nil)
      key=name.to_s.downcase
      return super unless ["sun","sunny","sunnyday","harshsun"].include?(key)
      requested=@sunny_visual_requested
      @sunny_visual_requested=false
      return if @battle && !@battle.showAnims
      return if @sunny_visual_cast
      kind=SunnyWeatherVisual.active?(@battle) ? @battle.field.weather : (key=="harshsun" ? :HarshSun : :Sun)
      full=requested || @sunny_visual_last_cast!=kind
      duration=full ? SunnyWeatherVisual::CAST_SECONDS : 0.24
      boxes=full ? {} : nil
      @sunny_visual_boxes=boxes
      begin
        if full
          pbSunnyVisualHideHP
          SunnyWeatherVisual.play_se
        end
        second=false
        @sunny_visual_cast_kind=kind
        frames=[(Graphics.frame_rate*duration).round,2].max
        frames.times do |f|
          p=f.to_f/(frames-1)
          @sunny_visual_cast=p if full
          @sunny_visual_pulse=full ? 0 : Math.sin(p*Math::PI)
          if full && !second && p>=0.48
            SunnyWeatherVisual.play_se(true)
            second=true
          end
          pbUpdate
        end
        @sunny_visual_last_cast=kind if SunnyWeatherVisual.active?(@battle)
      ensure
        @sunny_visual_cast=nil
        @sunny_visual_cast_kind=nil
        @sunny_visual_pulse=0
        @sunny_visual_boxes=nil
        boxes.each_value { |s,v|s.visible=v if s && !s.disposed? } if boxes
      end
    end
    def pbSunnyVisualHideHP
      return unless @sunny_visual_boxes && @sprites
      @sprites.each do |key,s|
        next unless key.to_s.start_with?("dataBox_") && s && !s.disposed?
        @sunny_visual_boxes[s.object_id]||=[s,s.visible]
        s.visible=false
      end
    end
    def pbGraphicsUpdate
      if @sprites && @viewport && !@viewport.disposed? && @battle
        active=SunnyWeatherVisual.active?(@battle)
        if active || @sunny_visual_cast || @sunny_visual_layer
          @sunny_visual_layer||=SunnyWeatherVisual::Layer.new(@sprites,@viewport)
          harsh=(@battle.field.weather==:HarshSun || @sunny_visual_cast_kind==:HarshSun)
          @sunny_visual_layer.update(active,@sunny_visual_cast,@sunny_visual_pulse.to_f,@battle.showAnims,harsh)
          if !active && !@sunny_visual_cast && @sunny_visual_layer.faded?
            @sunny_visual_layer.dispose
            @sunny_visual_layer=nil
          end
        end
        @sunny_visual_last_cast=nil if !active && !@sunny_visual_cast
        pbSunnyVisualHideHP
      end
      super
    end
    def pbDisposeSprites
      if @sunny_visual_layer
        @sunny_visual_layer.dispose
        @sunny_visual_layer=nil
      end
      super
    end
  end
end
Battle::Scene.prepend(SunnyWeatherVisual::SceneHooks)
