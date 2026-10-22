# Rip and Tear - Pokemon Essentials v21.1.
# Install in Plugins/[KAITO] Plugin/ and recompile. Move ID: RIPANDTEAR.
# Procedural claw graphics, existing SE/Anim sounds, automatic HP hiding.
# Presentation only: no damage, Bleed, recoil or stat calculation hooks.
module RipAndTearVisual
  VERSION = "1.0"
  MOVE_IDS = [:RIPANDTEAR]
  DURATION = 2.38
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
  def self.claw
    b=Bitmap.new(80,272)
    [[12,Color.new(60,9,24,235)],[8,Color.new(184,26,47,245)],[4,Color.new(248,103,104,250)],[1.6,Color.new(255,240,217,255)]].each do |width,c|
      left=[];right=[]
      72.times do |i|
        p=i/71.0;x=32+Math.sin(p*Math::PI)*21;y=5+p*262
        half=Math.sin(p*Math::PI)**0.75*width
        left<<[x-half,y];right<<[x+half,y]
      end
      polygon(b,left+right.reverse,c)
    end
    b
  end
  def self.rend
    b=Bitmap.new(192,256)
    [-1,0,1].each do |lane|
      outline=[];other=[]
      18.times do |i|
        p=i/17.0
        x=96+lane*33+Math.sin(p*11+lane)*6+(p-0.5)*24
        y=7+p*241
        width=Math.sin(p*Math::PI)*(5+(i%3)*2)
        outline<<[x-width,y];other<<[x+width,y]
      end
      polygon(b,outline+other.reverse,Color.new(33,5,17,240))
      [outline,other].each_with_index do |path,edge|
        path.each_cons(2) do |p,q|
          line(b,*p,*q,2,Color.new(edge==0 ? 234 : 132,edge==0 ? 61 : 18,edge==0 ? 74 : 41,230))
        end
      end
    end
    b
  end
  def self.line(b,x1,y1,x2,y2,width,c)
    n=[(x2-x1).abs.round,(y2-y1).abs.round,1].max
    (0..n).each do |i|
      p=i.to_f/n
      b.fill_rect((x1+(x2-x1)*p).round-width/2,(y1+(y2-y1)*p).round-width/2,width,width,c)
    end
  end
  def self.assets
    owned=[]
    begin
      owned<<claw;owned<<rend
      shard=Bitmap.new(20,36);owned<<shard
      polygon(shard,[[11,1],[16,12],[12,21],[5,34],[3,22],[7,13]],Color.new(132,16,40,245))
      polygon(shard,[[11,3],[13,13],[9,21],[5,28],[7,17]],Color.new(251,104,102,245))
      shard.fill_rect(10,7,1,5,Color.new(255,231,200,245))
      streak=Bitmap.new(160,12);owned<<streak
      154.times do |x|
        a=(Math.sin(x/153.0*Math::PI)**0.7*185).round
        streak.fill_rect(x+3,5,1,2,Color.new(224,133,131,a))
        streak.fill_rect(x+3,6,1,1,Color.new(255,217,184,(a*0.70).round))
      end
      burst=Bitmap.new(128,128);owned<<burst
      pts=Array.new(32) do |i|
        a=i*Math::PI/16;r=i.even? ? 51+(i%6)*2 : 9+(i%3)*3
        [64+Math.cos(a)*r,64+Math.sin(a)*r]
      end
      polygon(burst,pts,Color.new(211,41,61,200))
      polygon(burst,pts.map { |x,y|[64+(x-64)*0.70,64+(y-64)*0.70] },Color.new(255,219,183,245))
      veil=Bitmap.new(Graphics.width,Graphics.height);owned<<veil
      veil.fill_rect(0,0,Graphics.width,Graphics.height,Color.new(16,7,14,255))
      flash=Bitmap.new(Graphics.width,Graphics.height);owned<<flash
      flash.fill_rect(0,0,Graphics.width,Graphics.height,Color.new(255,211,184,255))
      owned
    rescue
      owned.each { |b|b.dispose unless b.disposed? };raise
    end
  end
  CUES = [[0.09,["PRSFX- Hone Claws","PRSFX- Fury Attack"],55,80],
          [0.28,["PRSFX- Fury Swipes","Fury Swipes"],75,100],
          [0.43,["PRSFX- Slash","Slash"],75,95],
          [0.56,["PRSFX- Crush Claw","PRSFX- Dragon Claw"],78,90],
          [0.72,["PRSFX- Crunch","PRSFX- Crush Claw"],82,85]]
  def self.sound(cue)
    _,names,volume,pitch=cue
    names.each do |name|
      next unless [".wav",".ogg",".mp3"].any? { |ext|File.file?("Audio/SE/Anim/#{name}#{ext}") }
      pbSEPlay("Anim/#{name}",volume,pitch);break
    end
  end
  module SceneHooks
    def pbAnimation(moveID,user,targets,hitNum=0)
      return super unless RipAndTearVisual::MOVE_IDS.include?(moveID)
      return if @battle && !@battle.showAnims
      return if @rip_and_tear_boxes
      entries=(targets.is_a?(Array) ? targets : [targets]).compact.select { |b|b.respond_to?(:index) }
      return super if entries.empty?
      entries=entries.uniq { |b|b.index }.select do |b|
        s=@sprites && @sprites["pokemon_#{b.index}"]
        s && !s.disposed? && s.bitmap &&
          !(b.respond_to?(:isCommander?) && b.isCommander?) &&
          !(s.respond_to?(:vanishMode) && s.vanishMode>0)
      end
      return if entries.empty?
      pbRipAndTearVisual(user,entries)
    end
    def pbRipAndTearHideHP
      return unless @rip_and_tear_boxes && @sprites
      @sprites.each do |key,s|
        next unless key.to_s.start_with?("dataBox_") && s && !s.disposed?
        @rip_and_tear_boxes[s.object_id]||=[s,s.visible];s.visible=false
      end
    end
    def pbGraphicsUpdate
      pbRipAndTearHideHP if @rip_and_tear_boxes
      super
    end
    def pbRipAndTearVisual(user,targets)
      sprites,bitmaps,hidden=[],[],{}
      @rip_and_tear_boxes={}
      begin
        @briefMessage=false;pbRipAndTearHideHP
        bitmaps.concat(RipAndTearVisual.assets)
        claw_b,rend_b,shard_b,streak_b,burst_b,veil_b,flash_b=bitmaps
        make=proc do |b,ox,oy,z,blend=0|
          s=Sprite.new(@viewport);sprites<<s
          s.bitmap,s.ox,s.oy,s.z,s.blend_type=b,ox,oy,z,blend;s.opacity=0;s
        end
        snapshot=proc do |source|
          b=source.bitmap.clone;bitmaps<<b
          s=make.call(b,source.ox,source.oy,20_002)
          s.src_rect.set(source.src_rect.x,source.src_rect.y,source.src_rect.width,source.src_rect.height)
          s.x,s.y=source.x,source.y;s.zoom_x,s.zoom_y=source.zoom_x,source.zoom_y
          s.mirror=source.mirror;s.color=source.color.clone;s.tone=source.tone.clone if source.respond_to?(:tone)
          s.visible=source.visible
          s.opacity=source.opacity
          hidden[source.object_id]||=[source,source.visible];source.visible=false;s
        end
        veil=make.call(veil_b,0,0,20_000)
        flash=make.call(flash_b,0,0,20_020)
        groups=targets.map do |b|
          src=@sprites["pokemon_#{b.index}"];copy=snapshot.call(src)
          cx=src.x+(src.src_rect.width/2.0-src.ox)*src.zoom_x
          cy=src.y+(src.src_rect.height/2.0-src.oy)*src.zoom_y
          scale=[[(src.src_rect.height*src.zoom_y+100)/245.0,0.73].max,1.15].min
          {copy:copy,x:src.x,y:src.y,cx:cx,cy:cy,scale:scale,color:src.color.clone,
           claws:Array.new(17) {make.call(claw_b,40,136,20_012)},
           rends:Array.new(2) {make.call(rend_b,96,128,20_010)},
           shards:Array.new(40) {make.call(shard_b,10,18,20_015)},
           streaks:Array.new(20) {make.call(streak_b,80,6,20_004)},
           burst:make.call(burst_b,64,64,20_014)}
        end
        actor_source=user && user.respond_to?(:index) && @sprites["pokemon_#{user.index}"]
        actor=nil
        if actor_source && !actor_source.disposed? && actor_source.bitmap && !targets.any? { |b|b.index==user.index }
          actor=snapshot.call(actor_source)
          ax,ay=actor.x,actor.y
          shadow=@sprites["shadow_#{user.index}"]
          if shadow && !shadow.disposed?
            hidden[shadow.object_id]=[shadow,shadow.visible];shadow.visible=false
          end
        end
        cue_index=0
        frames=[(Graphics.frame_rate*RipAndTearVisual::DURATION).round,2].max
        frames.times do |f|
          t=f.to_f/(frames-1)
          while cue_index<RipAndTearVisual::CUES.size && t>=RipAndTearVisual::CUES[cue_index][0]
            RipAndTearVisual.sound(RipAndTearVisual::CUES[cue_index]);cue_index+=1
          end
          envelope=[t/0.14,(1-t)/0.18,1.0].min
          veil.opacity=(envelope*(105+Math.sin(t*Math::PI)*25)).round
          final=[[(t-0.72)/0.23,0].max,1].min
          flash.opacity=t>=0.72 && t<0.77 ? ((1-(t-0.72)/0.05)*105).round : 0
          if actor
            anticipation=t<0.18 ? Math.sin(t/0.18*Math::PI)*-9 : 0
            lunge= t>=0.18 && t<0.32 ? Math.sin((t-0.18)/0.14*Math::PI)*0.18 : 0
            gx,gy=groups[0][:cx],groups[0][:cy]
            actor.x=ax+(gx-ax)*lunge+(gx>=ax ? 1 : -1)*anticipation
            actor.y=ay+(gy-ay)*lunge+(anticipation.abs*0.35)
          end
          groups.each do |g|
            cx,cy,scale=g.values_at(:cx,:cy,:scale)
            strikes=[0.28,0.43,0.56,0.72]
            intensity=strikes.map { |start|p=(t-start)/0.11;p>=0 && p<=1 ? (1-p) : 0 }.max
            shake=intensity*(t>=0.72 ? 11 : 6)
            g[:copy].x=g[:x]+Math.sin(t*147)*shake
            g[:copy].y=g[:y]+Math.cos(t*117)*shake*0.45
            g[:copy].color=intensity>0 ? Color.new(255,216,192,(intensity*155).round) : g[:color]
            g[:claws].each_with_index do |s,i|
              set=i<9 ? i/3 : 3
              lane=i<9 ? i%3 : (i-9)%4
              start=strikes[set];duration=set==3 ? 0.20 : 0.14
              p=(t-start)/duration
              if p>=0 && p<=1
                angle=[-42,47,-31,43][set]
                angle=(i-9)/4==0 ? -43 : 43 if set==3
                spread=(lane-(set==3 ? 1.5 : 1))*28*scale
                s.x=cx+spread+(p-0.5)*24*scale*(set.odd? ? -1 : 1)
                s.y=cy+(lane-1)*7*scale+(p-0.5)*55*scale
                s.angle=angle
                growth=[p/0.20,1].min
                s.zoom_x=scale*(set==3 ? 1.25 : 0.80)
                s.zoom_y=scale*(set==3 ? 1.28 : 0.88)*(0.55+growth*0.45)
                s.opacity=((1-p)**0.48*255).round
              else;s.opacity=0;end
            end
            g[:rends].each_with_index do |s,i|
              p=(t-0.72)/0.24
              s.x,s.y=cx+(i==0 ? -14 : 14)*scale,cy
              s.angle=i==0 ? -43 : 43
              s.zoom_x,s.zoom_y=scale*(0.80+[p,0].max*0.22),scale*1.1
              s.opacity=p>=0 && p<=1 ? ((1-p)**0.45*230).round : 0
            end
            burst=g[:burst];burst.x,burst.y=cx,cy
            burst.zoom_x=burst.zoom_y=scale*(0.20+final*1.8)
            burst.angle=17
            burst.opacity=(Math.sin(final*Math::PI)*200).round
            g[:shards].each_with_index do |s,i|
              start=i<20 ? 0.43 : 0.72
              p=[[(t-start)/0.23,0].max,1].min
              a=i*2.399
              r=(6+p*(100+i%5*16))*scale
              s.x=cx+Math.cos(a)*r;s.y=cy+Math.sin(a)*r*0.76+p*p*20
              s.angle=i*31+p*160
              size=scale*(0.24+i%4*0.09)
              s.zoom_x,s.zoom_y=size,size*(0.65+p*0.5)
              s.opacity=(Math.sin(p*Math::PI)*(1-p*0.3)*245).round
            end
            g[:streaks].each_with_index do |s,i|
              a=i*Math::PI*2/20
              p=(t*2.3+i*0.137)%1.0
              r=210-p*170
              s.x=cx+Math.cos(a)*r;s.y=cy+Math.sin(a)*r*0.75
              s.angle=-a*180/Math::PI
              s.zoom_x=0.30+i%3*0.13;s.zoom_y=0.45
              s.opacity=(envelope*Math.sin(p*Math::PI)*(t<0.72 ? 100 : 160)*(1-final)).round
            end
          end
          hidden.each_value { |s,_|s.visible=false unless s.disposed? }
          pbUpdate
        end
      ensure
        boxes=@rip_and_tear_boxes;@rip_and_tear_boxes=nil
        boxes.each_value { |s,v|s.visible=v if s && !s.disposed? } if boxes
        hidden.each_value { |s,v|s.visible=v if s && !s.disposed? }
        sprites.reverse_each { |s|s.dispose unless s.disposed? }
        bitmaps.each { |b|b.dispose unless b.disposed? }
      end
    end
  end
end
Battle::Scene.prepend(RipAndTearVisual::SceneHooks)
