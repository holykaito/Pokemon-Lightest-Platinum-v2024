# Undertow - Pokemon Essentials v21.1. Move ID UNDERTOW.
# Install in Plugins/[KAITO] Plugin/ and recompile.
# Steel claw move: one hooked rake with three parallel chrome trails.
# Target-only graphics. Native move handles damage and Defense/Speed reduction.
module UndertowVisual
  VERSION = "1.0"
  MOVE_IDS = [:UNDERTOW]
  DURATION = 1.25
  def self.polygon(b,points,c)
    low,high=points.map { |p|p[1] }.minmax
    (low.floor..high.ceil).each do |y|
      xs=[]
      points.each_with_index do |p,i|
        q=points[(i+1)%points.length]
        next unless (p[1]<=y && q[1]>y) || (q[1]<=y && p[1]>y)
        xs<<p[0]+(y-p[1]).to_f*(q[0]-p[0])/(q[1]-p[1])
      end
      xs.sort.each_slice(2) { |l,r|b.fill_rect(l.ceil,y,[r.floor-l.ceil+1,1].max,1,c) if r }
    end
  end
  def self.line(b,x1,y1,x2,y2,width,c)
    n=[(x2-x1).abs.round,(y2-y1).abs.round,1].max
    (0..n).each do |i|
      p=i.to_f/n
      b.fill_rect((x1+(x2-x1)*p).round-width/2,(y1+(y2-y1)*p).round-width/2,width,width,c)
    end
  end



  def self.assets
    a=[]
    begin
      claw=Bitmap.new(80,240);a<<claw
      [[13,[41,61,81,160]],[8,[81,132,164,205]],[4.5,[181,221,234,245]],[1.4,[252,255,246,255]]].each do |width,col|
        l=[];r=[]
        72.times do |i|
          p=i/71.0;x=24+Math.sin(p*Math::PI)*28+p*8;y=4+p*230
          dx=Math.cos(p*Math::PI)*28*Math::PI+8;dy=230.0
          len=Math.sqrt(dx*dx+dy*dy);nx,ny=-dy/len,dx/len
          half=Math.sin(p*Math::PI)**0.85*width
          l<<[x+nx*half,y+ny*half];r<<[x-nx*half,y-ny*half]
        end
        polygon(claw,l+r.reverse,Color.new(*col))
      end
      chip=Bitmap.new(12,20);a<<chip
      polygon(chip,[[7,0],[11,7],[6,19],[1,13],[2,5]],Color.new(80,123,151,230))
      polygon(chip,[[7,2],[9,7],[4,15],[3,10]],Color.new(216,242,245,250))
      spark=Bitmap.new(16,16);a<<spark
      polygon(spark,[[8,0],[10,6],[15,8],[10,10],[8,15],[6,10],[0,8],[6,6]],Color.new(255,232,162,240))
      spark.fill_rect(6,6,4,4,Color.new(255,255,233,255))
      streak=Bitmap.new(96,8);a<<streak
      polygon(streak,[[0,4],[78,1],[95,4],[78,7]],Color.new(176,223,240,160))
      halo=Bitmap.new(80,80);a<<halo
      80.times do |y|
        80.times do |x|
          r=((x-39.5)**2+(y-39.5)**2)/1560.25;next if r>1
          alpha=((Math.exp(-r*4)-Math.exp(-4))/(1-Math.exp(-4))*70).round
          halo.fill_rect(x,y,1,1,Color.new(123,188,218,alpha)) if alpha>0
        end
      end
      dust=Bitmap.new(64,48);a<<dust
      [[30,24,18],[17,28,13],[45,26,14]].each do |cx,cy,r|
        (-r..r).each do |y|
          half=Math.sqrt(r*r-y*y).floor
          dust.fill_rect(cx-half,cy+y,half*2+1,1,Color.new(133,161,176,65))
        end
      end
      veil=Bitmap.new(Graphics.width,Graphics.height);a<<veil
      veil.fill_rect(0,0,Graphics.width,Graphics.height,Color.new(17,29,39,255))
      a
    rescue
      a.each { |b|b.dispose unless b.disposed? };raise
    end
  end
  CUES = [[0.06,["PRSFX- Metal Claw1","PRSFX- Slash"],67,120],
          [0.19,["PRSFX- Iron Head","PRSFX- Metal Claw2","PRSFX- Slash"],73,110],
          [0.41,["PRSFX- Metal Sound","PRSFX- Iron Defense"],42,135]]
  def self.sound(cue)
    _,names,volume,pitch=cue
    names.each do |name|
      next unless [".wav",".ogg",".mp3"].any? { |ext|File.file?("Audio/SE/Anim/#{name}#{ext}") }
      pbSEPlay("Anim/#{name}",volume,pitch);break
    end
  end
  module SceneHooks
    def pbAnimation(moveID,user,targets,hitNum=0)
      return super unless UndertowVisual::MOVE_IDS.include?(moveID)
      return if @battle && !@battle.showAnims
      return if @undertow_boxes
      entries=(targets.is_a?(Array) ? targets : [targets]).compact.select { |b|b.respond_to?(:index) }
      return super if entries.empty?
      entries=entries.uniq { |b|b.index }.select do |b|
        s=@sprites && @sprites["pokemon_#{b.index}"]
        s && !s.disposed? && s.bitmap &&
          !(b.respond_to?(:isCommander?) && b.isCommander?) &&
          !(s.respond_to?(:vanishMode) && s.vanishMode>0)
      end
      return if entries.empty?
      pbUndertowVisual(user,entries)
    end
    def pbUndertowHideHP
      return unless @undertow_boxes && @sprites
      @sprites.each do |key,s|
        next unless key.to_s.start_with?("dataBox_") && s && !s.disposed?
        @undertow_boxes[s.object_id]||=[s,s.visible];s.visible=false
      end
    end
    def pbGraphicsUpdate
      pbUndertowHideHP if @undertow_boxes
      super
    end
    def pbUndertowVisual(user,targets)
      sprites,bitmaps,hidden=[],[],{}
      @undertow_boxes={}
      begin
        @briefMessage=false;pbUndertowHideHP
        bitmaps.concat(UndertowVisual.assets)
        claw_b,chip_b,spark_b,streak_b,halo_b,dust_b,veil_b=bitmaps
        make=proc do |b,ox,oy,z|
          s=Sprite.new(@viewport);sprites<<s;s.bitmap,s.ox,s.oy,s.z=b,ox,oy,z;s.opacity=0;s
        end
        veil=make.call(veil_b,0,0,20_000)
        src=user && user.respond_to?(:index) && @sprites["pokemon_#{user.index}"]
        ux=src && !src.disposed? ? src.x : Graphics.width*0.5
        groups=targets.map do |b|
          target=@sprites["pokemon_#{b.index}"]
          bmp=target.bitmap.clone;bitmaps<<bmp;copy=make.call(bmp,target.ox,target.oy,20_006)
          copy.src_rect.set(target.src_rect.x,target.src_rect.y,target.src_rect.width,target.src_rect.height)
          copy.x,copy.y=target.x,target.y;copy.zoom_x,copy.zoom_y=target.zoom_x,target.zoom_y
          copy.mirror,copy.visible,copy.opacity=target.mirror,target.visible,target.opacity
          copy.color=target.color.clone;copy.tone=target.tone.clone if target.respond_to?(:tone)
          hidden[target.object_id]=[target,target.visible];target.visible=false
          cx=target.x+(target.src_rect.width/2.0-target.ox)*target.zoom_x
          cy=target.y+(target.src_rect.height/2.0-target.oy)*target.zoom_y
          scale=[[(target.src_rect.height*target.zoom_y+60)/220.0,0.70].max,1.06].min
          {cx:cx,cy:cy,x:target.x,y:target.y,copy:copy,color:target.color.clone,scale:scale,
           ground:target.y+(target.src_rect.height-target.oy)*target.zoom_y,
           claws:Array.new(3) {make.call(claw_b,40,120,20_020)},
           echoes:Array.new(3) {make.call(claw_b,40,120,20_017)},
           chips:Array.new(24) {make.call(chip_b,6,10,20_026)},
           sparks:Array.new(24) {make.call(spark_b,8,8,20_028)},
           streaks:Array.new(8) {make.call(streak_b,0,4,20_023)},
           dust:Array.new(6) {make.call(dust_b,32,24,20_010)},
           halo:make.call(halo_b,40,40,20_008)}
        end
        frames=[(Graphics.frame_rate*UndertowVisual::DURATION).round,2].max;cue_index=0
        frames.times do |f|
          t=f.to_f/(frames-1)
          while cue_index<UndertowVisual::CUES.size && t>=UndertowVisual::CUES[cue_index][0]
            UndertowVisual.sound(UndertowVisual::CUES[cue_index]);cue_index+=1
          end
          env=[t/0.09,(1-t)/0.22,1].min;veil.opacity=(env*57).round
          groups.each do |g|
            cx,cy,scale=g.values_at(:cx,:cy,:scale)
            direction=cx>=ux ? 1 : -1
            g[:claws].each_with_index do |s,i|
              p=(t-0.07-i*0.027)/0.31
              sweep=[[p,0].max,1].min
              s.x=cx+(i-1)*22*scale+direction*(sweep-0.40)*24*scale
              s.y=cy+(i-1)*4*scale-(sweep-0.40)*38*scale
              s.angle=direction*(-43);s.mirror=direction<0
              s.zoom_x=scale*0.75;s.zoom_y=scale*(0.78+[[p/0.18,0].max,1].min*0.25)
              s.opacity=p>=0 && p<=1 ? ((1-p)**0.55*255).round : 0
              e=g[:echoes][i];e.x,e.y=s.x-direction*5,s.y+7;e.angle=s.angle;e.mirror=s.mirror
              e.zoom_x,e.zoom_y=s.zoom_x*0.7,s.zoom_y
              e.opacity=p>=0 && p<=1 ? ((1-p)*65).round : 0
            end
            impact=[[(t-0.17)/0.42,0].max,1].min
            active=t>=0.17 && t<0.59
            tug=active ? Math.sin(impact*Math::PI)*11 : 0
            g[:copy].x=g[:x]-direction*tug*0.55+Math.sin(f*2.7)*(active ? (1-impact)*3 : 0)
            g[:copy].y=g[:y]+tug*0.65
            g[:copy].angle=active ? -direction*Math.sin(impact*Math::PI)*3 : 0
            g[:copy].color=t>=0.17 && t<0.28 ? Color.new(213,237,249,((0.28-t)/0.11*130).round) : g[:color]
            halo=g[:halo];halo.x,halo.y=cx,cy
            halo.zoom_x=halo.zoom_y=0.5+impact*1.5
            halo.opacity=active ? ((1-impact)*200).round : 0
            g[:chips].each_with_index do |s,i|
              p=(t-0.19-i%3*0.018)/0.43;a=i*2.399
              r=8+[p,0].max*(35+i%5*14)*scale
              s.x=cx+Math.cos(a)*r;s.y=cy+Math.sin(a)*r*0.66+[p,0].max**2*35
              s.zoom_x=s.zoom_y=0.20+i%4*0.08;s.angle=i*23+[p,0].max*150
              s.opacity=p>=0 && p<=1 ? ((1-p)**0.6*240).round : 0
            end
            g[:sparks].each_with_index do |s,i|
              p=(t-0.17-i%4*0.024)/0.24;a=i*2.399
              r=4+[p,0].max*(30+i%4*16)
              s.x=cx+Math.cos(a)*r;s.y=cy+Math.sin(a)*r*0.8
              s.zoom_x=s.zoom_y=0.10+i%3*0.07;s.angle=i*19
              s.opacity=p>=0 && p<=1 ? (Math.sin(p*Math::PI)**0.7*245).round : 0
            end
            g[:streaks].each_with_index do |s,i|
              p=(t-0.18)/0.18;a=i*Math::PI/4+0.2
              s.x,s.y=cx,cy;s.angle=-a*180/Math::PI
              s.zoom_x=0.25+[p,0].max*0.45;s.zoom_y=0.25
              s.opacity=p>=0 && p<=1 ? ((1-p)*170).round : 0
            end
            g[:dust].each_with_index do |s,i|
              p=(t-0.20-i%3*0.018)/0.32;side=i.even? ? 1 : -1
              s.x=cx+side*(10+[p,0].max*42);s.y=g[:ground]-3-[p,0].max*7
              s.zoom_x=0.22+[p,0].max*0.65;s.zoom_y=s.zoom_x*0.5
              s.opacity=p>=0 && p<=1 ? (Math.sin(p*Math::PI)*110).round : 0
            end
          end
          hidden.each_value { |s,_|s.visible=false unless s.disposed? };pbUpdate
        end
      ensure
        boxes=@undertow_boxes;@undertow_boxes=nil
        boxes.each_value { |s,v|s.visible=v if s && !s.disposed? } if boxes
        hidden.each_value { |s,v|s.visible=v if s && !s.disposed? }
        sprites.reverse_each { |s|s.dispose unless s.disposed? }
        bitmaps.each { |b|b.dispose unless b.disposed? }
      end
    end
  end
end
Battle::Scene.prepend(UndertowVisual::SceneHooks)
