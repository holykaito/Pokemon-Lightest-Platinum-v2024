# Rain Dance + persistent rainfall - Pokemon Essentials v21.1.
# Add to an existing plugin folder; no PNG/audio/PBS imports.
# Replaces RAINDANCE and Common:Rain/HeavyRain. Weather rules remain unchanged.
module RainWeatherVisual
  VERSION = "1.0"
  CAST_SECONDS = 1.95
  WEATHER_IDS = [:Rain,:HeavyRain]
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
    192.times do |y|
      wash.fill_rect(0,y,256,1,Color.new(49,76,111,(47-y/192.0*29).round))
    end
    cloud=Bitmap.new(160,80)
    # Sample a continuous cloud density mask instead of overlapping disc rims.
    40.times do |row|
      80.times do |col|
        x,y=col*2,row*2
        density=0.0
        [[31,40,29,22],[62,27,30,23],[95,34,34,25],[129,44,30,21]].each do |cx,cy,rx,ry|
          density+=Math.exp(-((x-cx)/rx.to_f)**2-((y-cy)/ry.to_f)**2)
        end
        edge=[[x/16.0,(159-x)/16.0,1.0].min,0].max
        alpha=([density*43,78].min*edge).round
        shade=(y/80.0*10).round
        cloud.fill_rect(x,y,2,2,Color.new(58+shade,76+shade,102+shade,alpha))
      end
    end
    rain=Bitmap.new(14,64)
    56.times do |y|
      p=y/55.0
      x=(10-p*7).round
      a=(Math.sin(p*Math::PI)*185).round
      rain.fill_rect(x,y+4,2,1,Color.new(151,206,234,(a*0.55).round))
      rain.fill_rect(x,y+4,1,1,Color.new(216,242,253,a))
    end
    ripple=Bitmap.new(64,64)
    360.times do |i|
      a=i*Math::PI/180
      [[22,Color.new(146,202,229,120)],[24,Color.new(210,238,249,205)]].each do |r,c|
        ripple.fill_rect((32+Math.cos(a)*r).round,(32+Math.sin(a)*r).round,2,2,c)
      end
    end
    splash=Bitmap.new(32,24)
    [[16,22,7,10],[16,22,24,9],[16,22,16,5],[13,22,3,17],[19,22,29,17]].each do |p|
      line(splash,*p,1,Color.new(201,235,249,220))
    end
    splash.fill_rect(6,6,3,3,Color.new(219,245,255,230))
    splash.fill_rect(23,5,3,3,Color.new(219,245,255,230))
    mist=Bitmap.new(256,64)
    64.times do |y|
      16.times do |j|
        v=Math.exp(-((y-32-Math.sin(j*0.7)*5)/12.0)**2)
        edge=Math.sin((j+0.5)/16.0*Math::PI)
        mist.fill_rect(j*16,y,16,1,Color.new(164,196,215,(v*edge*28).round))
      end
    end
    [wash,cloud,rain,ripple,splash,mist]
  end
  def self.play_se(second=false)
    names=second ? ["PRSFX- Rain","PRSFX- Water Sport"] : ["PRSFX- Rain Dance","Water/Rain Dance"]
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
        @bitmaps.concat(RainWeatherVisual.assets)
        wash,cloud,rain,ripple,splash,mist=@bitmaps
        @wash=make(wash,0,0,3)
        @wash.zoom_x,@wash.zoom_y=Graphics.width/256.0,Graphics.height/192.0
        @clouds=Array.new(8) {make(cloud,80,40,4)}
        @rain=Array.new(100) {make(rain,7,32,8)}
        @ripples=Array.new(18) {make(ripple,32,32,5)}
        @splashes=Array.new(20) {make(splash,16,22,9)}
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
      key="rain_weather_visual_#{object_id}_#{@keys.length}"
      @keys<<key
      @hash[key]=s
      s
    end
    def update(active,cast,pulse,animate,heavy)
      dt=1.0/[Graphics.frame_rate,1].max
      @age+=dt if animate || cast
      @alpha=[[@alpha+((active || cast) ? dt*3.2 : -dt*3.2),0].max,1].min
      w,h=Graphics.width.to_f,Graphics.height.to_f
      scale=w/512.0
      crest=cast ? Math.sin(cast*Math::PI) : 0.0
      gather=cast ? [[cast/0.30,0].max,1].min : 1.0
      downpour=cast ? [[(cast-0.13)/0.25,0].max,1].min : 1.0
      @wash.opacity=(@alpha*(160+crest*50+(heavy ? 25 : 0))).round
      @clouds.each_with_index do |s,i|
        side=i.even? ? -1 : 1
        x=w*(-0.08+(i%5)*0.28)+Math.sin(@age*0.19+i)*8
        s.x=x+side*(1-gather)*w*0.42
        s.y=h*(0.035+(i/5)*0.085)+Math.sin(@age*0.35+i)*3
        s.zoom_x=scale*(1.20+(i%3)*0.12)
        s.zoom_y=scale*(0.85+(i%2)*0.12)
        s.opacity=(@alpha*gather*(heavy ? 230 : 185)).round
      end
      limit=heavy ? 100 : 68+(crest*20).round
      @rain.each_with_index do |s,i|
        p=(@age*(heavy ? 1.08 : 0.86)+i*0.61803398875)%1.0
        lane=(i*0.754877666)%1.0
        s.x=lane*(w+70)-35+(1-p)*42
        s.y=-48+p*(h+96)
        size=scale*(0.31+(i%4)*0.085)
        s.zoom_x=scale*(i%5==0 ? 0.80 : 0.55)
        s.zoom_y=size*(1+crest*0.30)
        s.z=i%6==0 ? 65 : 8
        s.opacity=i<limit ? (@alpha*downpour*(115+(i%4)*22+crest*35)).round : 0
      end
      @ripples.each_with_index do |s,i|
        p=(@age*0.63+i*0.137)%1.0
        x=w*(0.03+(i*0.197)%0.94)
        y=h*(0.50+(i%4)*0.125)+Math.sin(i*2.2)*4
        size=scale*(0.25+p*0.65)*(0.70+(i%4)*0.13)
        s.x,s.y=x,y
        s.zoom_x,s.zoom_y=size,size*0.24
        s.opacity=(@alpha*downpour*Math.sin(p*Math::PI)*(heavy ? 175 : 140)).round
      end
      @splashes.each_with_index do |s,i|
        p=(@age*1.25+i*0.173)%1.0
        s.x=w*(0.02+(i*0.219)%0.96)
        s.y=h*(0.52+(i%4)*0.117)+Math.sin(i*1.7)*5
        s.zoom_x=scale*(0.30+i%3*0.075)*(0.7+p*0.3)
        s.zoom_y=scale*(0.30+i%3*0.075)*Math.sin(p*Math::PI)
        s.opacity=(@alpha*downpour*Math.sin(p*Math::PI)**3*(heavy ? 225 : 180)).round
      end
      @mist.each_with_index do |s,i|
        s.x=((@age*10+i*w/3)%(w+320*scale))-160*scale
        s.y=h*(0.56+i*0.17)+Math.sin(@age*0.6+i)*3
        s.zoom_x=scale*1.65
        s.zoom_y=0.52
        s.opacity=(@alpha*downpour*(125+crest*55+pulse*25+(heavy ? 25 : 0))).round
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
      return super unless moveID==:RAINDANCE
      @rain_visual_requested=true
      # pbStartWeather calls Common:Rain after setting weather. Cast there once.
    end
    def pbCommonAnimationExists?(name)
      return true if ["rain","raindance","heavyrain"].include?(name.to_s.downcase)
      super
    end
    def pbCommonAnimation(name,user=nil,target=nil)
      key=name.to_s.downcase
      return super unless ["rain","raindance","heavyrain"].include?(key)
      requested=@rain_visual_requested
      @rain_visual_requested=false
      return if @battle && !@battle.showAnims
      return if @rain_visual_cast
      kind=RainWeatherVisual.active?(@battle) ? @battle.field.weather : (key=="heavyrain" ? :HeavyRain : :Rain)
      full=requested || @rain_visual_last_cast!=kind
      duration=full ? RainWeatherVisual::CAST_SECONDS : 0.24
      boxes=full ? {} : nil
      @rain_visual_boxes=boxes
      begin
        if full
          pbRainVisualHideHP
          RainWeatherVisual.play_se
        end
        second=false
        @rain_visual_cast_kind=kind
        frames=[(Graphics.frame_rate*duration).round,2].max
        frames.times do |f|
          p=f.to_f/(frames-1)
          @rain_visual_cast=p if full
          @rain_visual_pulse=full ? 0 : Math.sin(p*Math::PI)
          if full && !second && p>=0.48
            RainWeatherVisual.play_se(true)
            second=true
          end
          pbUpdate
        end
        @rain_visual_last_cast=kind if RainWeatherVisual.active?(@battle)
      ensure
        @rain_visual_cast=nil
        @rain_visual_cast_kind=nil
        @rain_visual_pulse=0
        @rain_visual_boxes=nil
        boxes.each_value { |s,v|s.visible=v if s && !s.disposed? } if boxes
      end
    end
    def pbRainVisualHideHP
      return unless @rain_visual_boxes && @sprites
      @sprites.each do |key,s|
        next unless key.to_s.start_with?("dataBox_") && s && !s.disposed?
        @rain_visual_boxes[s.object_id]||=[s,s.visible]
        s.visible=false
      end
    end
    def pbGraphicsUpdate
      if @sprites && @viewport && !@viewport.disposed? && @battle
        active=RainWeatherVisual.active?(@battle)
        if active || @rain_visual_cast || @rain_visual_layer
          @rain_visual_layer||=RainWeatherVisual::Layer.new(@sprites,@viewport)
          heavy=(@battle.field.weather==:HeavyRain || @rain_visual_cast_kind==:HeavyRain)
          @rain_visual_layer.update(active,@rain_visual_cast,@rain_visual_pulse.to_f,@battle.showAnims,heavy)
          if !active && !@rain_visual_cast && @rain_visual_layer.faded?
            @rain_visual_layer.dispose
            @rain_visual_layer=nil
          end
        end
        @rain_visual_last_cast=nil if !active && !@rain_visual_cast
        pbRainVisualHideHP
      end
      super
    end
    def pbDisposeSprites
      if @rain_visual_layer
        @rain_visual_layer.dispose
        @rain_visual_layer=nil
      end
      super
    end
  end
end
Battle::Scene.prepend(RainWeatherVisual::SceneHooks)
