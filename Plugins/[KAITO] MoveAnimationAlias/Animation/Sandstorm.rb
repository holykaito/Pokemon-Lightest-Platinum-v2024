# Sandstorm move + persistent sandstorm weather - Pokemon Essentials v21.1.
# Add to an existing plugin folder; no PNG/audio/PBS imports.
# Replaces SANDSTORM and Common:Sandstorm. Weather rules remain unchanged.
module SandstormWeatherVisual
  VERSION = "1.0"
  CAST_SECONDS = 2.00
  WEATHER_IDS = [:Sandstorm]
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
      wash.fill_rect(0,y,256,1,Color.new(188,142,81,(52-y/192.0*10).round))
    end
    dust=Bitmap.new(256,96)
    48.times do |row|
      64.times do |col|
        x,y=col*4,row*2
        density=0.0
        [[37,52,44,24],[94,35,56,26],[157,49,57,31],[215,57,41,23]].each do |cx,cy,rx,ry|
          density+=Math.exp(-((x-cx)/rx.to_f)**2-((y-cy)/ry.to_f)**2)
        end
        edge=[[x/20.0,(255-x)/20.0,1.0].min,0].max
        a=([density*48,88].min*edge).round
        dust.fill_rect(x,y,4,2,Color.new(202,168,109,a))
      end
    end
    grain=Bitmap.new(12,12)
    grain.fill_rect(4,4,5,4,Color.new(133,99,61,210))
    grain.fill_rect(4,3,4,3,Color.new(229,202,148,240))
    grain.fill_rect(5,3,2,1,Color.new(253,232,186,245))
    chip=Bitmap.new(16,18)
    polygon(chip,[[7,2],[13,6],[12,12],[5,16],[2,9]],Color.new(120,99,73,210))
    polygon(chip,[[7,4],[11,7],[7,11],[4,9]],Color.new(213,186,137,235))
    streak=Bitmap.new(128,32)
    3.times do |j|
      last=nil
      60.times do |i|
        x=5+i*2
        y=11+j*4+Math.sin(i/59.0*Math::PI*1.6+j)*3
        a=(Math.sin(i/59.0*Math::PI)*130).round
        line(streak,*last,x,y,1,Color.new(239,215,170,a)) if last
        last=[x,y]
      end
    end
    vortices=Array.new(4) do |phase|
      b=Bitmap.new(128,96)
      84.times do |i|
        y=6+i
        p=i/83.0
        r=(8+(1-p)*43).round
        x=(64+Math.sin(i*0.16+phase*Math::PI/2)*4).round
        alpha=(Math.sin(p*Math::PI)*58).round
        b.fill_rect(x-r,y,r*2+1,1,Color.new(191,149,88,alpha))
      end
      2.times do |j|
        last=nil
        84.times do |i|
          y=6+i
          radius=8+(1-i/83.0)*43
          a=i*0.20+phase*Math::PI/2+j*Math::PI
          x=64+Math.cos(a)*radius
          yy=y+Math.sin(a)*3
          alpha=(Math.sin(i/83.0*Math::PI)*155).round
          if last
            line(b,*last,x,yy,3,Color.new(148,111,66,(alpha*0.5).round))
            line(b,*last,x,yy,1,Color.new(234,205,152,alpha))
          end
          last=[x,yy]
        end
      end
      b
    end
    [wash,dust,grain,chip,streak,*vortices]
  end
  def self.play_se(second=false)
    names=second ? ["PRSFX- Sand Tomb","PRSFX- Wind"] : ["PRSFX- Sandstorm","PRSFX- Sand Attack"]
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
        @bitmaps.concat(SandstormWeatherVisual.assets)
        wash,dust,grain,chip,streak=@bitmaps[0,5]
        @wash=make(wash,0,0,3)
        @wash.zoom_x,@wash.zoom_y=Graphics.width/256.0,Graphics.height/192.0
        @sheets=Array.new(6) {make(dust,128,48,4)}
        @wave=make(dust,128,48,7)
        @grains=Array.new(86) { |i|make(i%7==0 ? chip : grain,i%7==0 ? 8 : 6,i%7==0 ? 9 : 6,8) }
        @streaks=Array.new(10) {make(streak,64,16,6)}
        @vortices=Array.new(3) {make(@bitmaps[5],64,87,6)}
      rescue
        dispose
        raise
      end
    end
    def make(bitmap,ox,oy,z)
      s=Sprite.new(@viewport)
      @sprites<<s
      s.bitmap,s.ox,s.oy,s.z=bitmap,ox,oy,z
      key="sandstorm_weather_visual_#{object_id}_#{@keys.length}"
      @keys<<key
      @hash[key]=s
      s
    end
    def update(active,cast,pulse,animate)
      dt=1.0/[Graphics.frame_rate,1].max
      @age+=dt if animate || cast
      @alpha=[[@alpha+((active || cast) ? dt*3.2 : -dt*3.2),0].max,1].min
      w,h=Graphics.width.to_f,Graphics.height.to_f
      scale=w/512.0
      crest=cast ? Math.sin(cast*Math::PI) : 0.0
      gather=cast ? [[cast/0.24,0].max,1].min : 1.0
      @wash.opacity=(@alpha*(175+crest*65)).round
      @sheets.each_with_index do |s,i|
        s.x=((@age*(18+i*3)+i*w/5)%(w+380*scale))-190*scale
        s.y=h*(0.10+(i%5)*0.19)+Math.sin(@age*0.7+i)*7
        s.zoom_x=scale*(1.65+i%2*0.25)
        s.zoom_y=0.90+i%3*0.12
        s.z=i==5 ? 65 : 4
        s.opacity=(@alpha*gather*(i==5 ? 45+crest*40 : 155+crest*75+pulse*20)).round
      end
      if cast
        @wave.x=-w*0.48+cast*w*1.92
        @wave.y=h*0.63+Math.sin(cast*Math::PI)*8
        @wave.zoom_x,@wave.zoom_y=scale*2.6,2.05
        @wave.opacity=(@alpha*crest*245).round
      else
        @wave.opacity=0
      end
      @grains.each_with_index do |s,i|
        p=(@age*(0.26+i%5*0.035)+i*0.173)%1.0
        s.x=-35+p*(w+70)
        s.y=h*(0.035+(i*0.197)%0.92)+Math.sin(@age*3+i)*7+(p-0.5)*27
        size=scale*(0.38+i%4*0.085)
        size*=0.83 if i%7==0
        s.zoom_x=s.zoom_y=size
        s.angle=@age*(i%2==0 ? 75 : -65)+i*23
        s.z=i%7==0 ? 65 : 8
        s.opacity=(@alpha*gather*(130+i%4*23+crest*25)).round
      end
      @streaks.each_with_index do |s,i|
        p=(@age*0.32+i*0.137)%1.0
        s.x=-130*scale+p*(w+260*scale)
        s.y=h*(0.13+(i%5)*0.18)+Math.sin(@age+i)*5
        s.zoom_x=scale*(0.85+i%3*0.22)
        s.zoom_y=0.45+i%2*0.12
        s.angle=-3+i%3*2
        s.opacity=(@alpha*gather*Math.sin(p*Math::PI)*(155+crest*65+pulse*20)).round
      end
      @vortices.each_with_index do |s,i|
        p=(@age*0.085+i/3.0)%1.0
        s.bitmap=@bitmaps[5+((@age*8).floor+i)%4]
        s.x=-70*scale+p*(w+140*scale)
        s.y=h*(0.66+(i%2)*0.23)+Math.sin(@age+i)*3
        size=scale*(0.65+crest*0.40+i%2*0.12)
        s.zoom_x,s.zoom_y=size,size*(0.82+i%2*0.10)
        s.opacity=(@alpha*gather*Math.sin(p*Math::PI)*(125+crest*75+pulse*20)).round
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
      return super unless moveID==:SANDSTORM
      @sandstorm_visual_requested=true
      # pbStartWeather calls Common:Sandstorm after setting weather. Cast there once.
    end
    def pbCommonAnimationExists?(name)
      return true if ["sandstorm"].include?(name.to_s.gsub(/[^a-z]/i,"").downcase)
      super
    end
    def pbCommonAnimation(name,user=nil,target=nil)
      key=name.to_s.gsub(/[^a-z]/i,"").downcase
      return super unless ["sandstorm"].include?(key)
      requested=@sandstorm_visual_requested
      @sandstorm_visual_requested=false
      return if @battle && !@battle.showAnims
      return if @sandstorm_visual_cast
      kind=:Sandstorm
      full=requested || @sandstorm_visual_last_cast!=kind
      duration=full ? SandstormWeatherVisual::CAST_SECONDS : 0.24
      boxes=full ? {} : nil
      @sandstorm_visual_boxes=boxes
      begin
        if full
          pbSandstormVisualHideHP
          SandstormWeatherVisual.play_se
        end
        second=false
        @sandstorm_visual_cast_kind=kind
        frames=[(Graphics.frame_rate*duration).round,2].max
        frames.times do |f|
          p=f.to_f/(frames-1)
          @sandstorm_visual_cast=p if full
          @sandstorm_visual_pulse=full ? 0 : Math.sin(p*Math::PI)
          if full && !second && p>=0.48
            SandstormWeatherVisual.play_se(true)
            second=true
          end
          pbUpdate
        end
        @sandstorm_visual_last_cast=kind if SandstormWeatherVisual.active?(@battle)
      ensure
        @sandstorm_visual_cast=nil
        @sandstorm_visual_cast_kind=nil
        @sandstorm_visual_pulse=0
        @sandstorm_visual_boxes=nil
        boxes.each_value { |s,v|s.visible=v if s && !s.disposed? } if boxes
      end
    end
    def pbSandstormVisualHideHP
      return unless @sandstorm_visual_boxes && @sprites
      @sprites.each do |key,s|
        next unless key.to_s.start_with?("dataBox_") && s && !s.disposed?
        @sandstorm_visual_boxes[s.object_id]||=[s,s.visible]
        s.visible=false
      end
    end
    def pbGraphicsUpdate
      if @sprites && @viewport && !@viewport.disposed? && @battle
        active=SandstormWeatherVisual.active?(@battle)
        if active || @sandstorm_visual_cast || @sandstorm_visual_layer
          @sandstorm_visual_layer||=SandstormWeatherVisual::Layer.new(@sprites,@viewport)
          @sandstorm_visual_layer.update(active,@sandstorm_visual_cast,@sandstorm_visual_pulse.to_f,@battle.showAnims)
          if !active && !@sandstorm_visual_cast && @sandstorm_visual_layer.faded?
            @sandstorm_visual_layer.dispose
            @sandstorm_visual_layer=nil
          end
        end
        @sandstorm_visual_last_cast=nil if !active && !@sandstorm_visual_cast
        pbSandstormVisualHideHP
      end
      super
    end
    def pbDisposeSprites
      if @sandstorm_visual_layer
        @sandstorm_visual_layer.dispose
        @sandstorm_visual_layer=nil
      end
      super
    end
  end
end
Battle::Scene.prepend(SandstormWeatherVisual::SceneHooks)
