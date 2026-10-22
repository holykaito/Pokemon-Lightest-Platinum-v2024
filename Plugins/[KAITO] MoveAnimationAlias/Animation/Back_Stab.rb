# Back Stab - Pokemon Essentials v21.1. Move ID BACKSTAB.
# Install in Plugins/[KAITO] Plugin/ and recompile.
# Fast rear ambush: dark afterimages, a single piercing flash, shadow fallout.
# Preserves the user's pre-existing vanish state. Presentation only.
module BackStabVisual
  VERSION = "1.0"
  MOVE_IDS = [:BACKSTAB]
  DURATION = 1.40
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
      thrust=Bitmap.new(184,32);a<<thrust
      polygon(thrust,[[2,16],[139,2],[181,16],[139,30]],Color.new(35,12,45,220))
      polygon(thrust,[[20,16],[143,8],[179,16],[143,24]],Color.new(185,51,110,235))
      polygon(thrust,[[39,16],[148,13],[179,16],[148,19]],Color.new(255,219,224,255))
      burst=Bitmap.new(128,128);a<<burst
      pts=Array.new(24) do |i|
        ang=i*Math::PI/12;r=i.even? ? 41+i%5*4 : 9+i%3*3
        [64+Math.cos(ang)*r,64+Math.sin(ang)*r]
      end
      polygon(burst,pts,Color.new(104,30,83,190))
      polygon(burst,pts.map { |x,y|[64+(x-64)*0.52,64+(y-64)*0.52] },Color.new(252,187,216,245))
      particle=Bitmap.new(10,18);a<<particle
      polygon(particle,[[5,0],[9,6],[5,17],[1,10]],Color.new(155,54,124,235))
      line(particle,5,3,5,11,1,Color.new(255,173,204,240))
      smoke=Bitmap.new(48,48);a<<smoke
      48.times do |y|
        48.times do |x|
          r=((x-23.5)**2+(y-23.5)**2)/552.25;next if r>1
          alpha=((Math.exp(-r*4)-Math.exp(-4))/(1-Math.exp(-4))*145).round
          smoke.fill_rect(x,y,1,1,Color.new(49,23,65,alpha)) if alpha>0
        end
      end
      streak=Bitmap.new(144,10);a<<streak
      polygon(streak,[[0,5],[118,1],[143,5],[118,9]],Color.new(51,22,63,210))
      line(streak,19,5,132,5,1,Color.new(189,77,139,180))
      glint=Bitmap.new(20,20);a<<glint
      polygon(glint,[[10,0],[12,8],[19,10],[12,12],[10,19],[8,12],[0,10],[8,8]],Color.new(255,215,233,245))
      veil=Bitmap.new(Graphics.width,Graphics.height);a<<veil
      veil.fill_rect(0,0,Graphics.width,Graphics.height,Color.new(21,10,28,255))
      a
    rescue
      a.each { |b|b.dispose unless b.disposed? };raise
    end
  end
  CUES = [[0.08,["PRSFX- Feint Attack1","PRSFX- Shadow Sneak1"],54,120],
          [0.30,["PRSFX- Night Slash1","PRSFX- Slash"],68,125],
          [0.43,["PRSFX- Shadow Claw2","PRSFX- Night Slash2"],78,110],
          [0.59,["PRSFX- Feint2","PRSFX- Shadow Sneak2"],43,125]]
  def self.sound(cue)
    _,names,volume,pitch=cue
    names.each do |name|
      next unless [".wav",".ogg",".mp3"].any? { |ext|File.file?("Audio/SE/Anim/#{name}#{ext}") }
      pbSEPlay("Anim/#{name}",volume,pitch);break
    end
  end
  module SceneHooks
    def pbAnimation(moveID,user,targets,hitNum=0)
      return super unless BackStabVisual::MOVE_IDS.include?(moveID)
      return if @battle && !@battle.showAnims
      return if @back_stab_boxes
      entries=(targets.is_a?(Array) ? targets : [targets]).compact.select { |b|b.respond_to?(:index) }
      return super if entries.empty?
      entries=entries.uniq { |b|b.index }.select do |b|
        s=@sprites && @sprites["pokemon_#{b.index}"]
        s && !s.disposed? && s.bitmap &&
          !(b.respond_to?(:isCommander?) && b.isCommander?) &&
          !(s.respond_to?(:vanishMode) && s.vanishMode>0)
      end
      return if entries.empty?
      pbBackStabVisual(user,entries)
    end
    def pbBackStabHideHP
      return unless @back_stab_boxes && @sprites
      @sprites.each do |key,s|
        next unless key.to_s.start_with?("dataBox_") && s && !s.disposed?
        @back_stab_boxes[s.object_id]||=[s,s.visible];s.visible=false
      end
    end
    def pbGraphicsUpdate
      pbBackStabHideHP if @back_stab_boxes
      super
    end
    def pbBackStabVisual(user,targets)
      sprites,bitmaps,hidden=[],[],{}
      @back_stab_boxes={}
      begin
        @briefMessage=false;pbBackStabHideHP
        bitmaps.concat(BackStabVisual.assets)
        thrust_b,burst_b,particle_b,smoke_b,streak_b,glint_b,veil_b=bitmaps
        make=proc do |b,ox,oy,z|
          s=Sprite.new(@viewport);sprites<<s;s.bitmap,s.ox,s.oy,s.z=b,ox,oy,z;s.opacity=0;s
        end
        snapshot=proc do |src,z,force=false|
          bmp=src.bitmap.clone;bitmaps<<bmp;s=make.call(bmp,src.ox,src.oy,z)
          s.src_rect.set(src.src_rect.x,src.src_rect.y,src.src_rect.width,src.src_rect.height)
          s.x,s.y=src.x,src.y;s.zoom_x,s.zoom_y=src.zoom_x,src.zoom_y
          s.mirror=src.mirror;s.visible=force ? true : src.visible
          s.opacity=force && src.opacity==0 ? 255 : src.opacity
          s.color=src.color.clone;s.tone=src.tone.clone if src.respond_to?(:tone)
          hidden[src.object_id]||=[src,src.visible];src.visible=false;s
        end
        src=user && user.respond_to?(:index) && @sprites["pokemon_#{user.index}"]
        src=nil if src && (src.disposed? || !src.bitmap)
        actor=nil;ghosts=[]
        if src && !targets.any? { |b|b.index==user.index }
          was_hidden=!src.visible || src.opacity==0 || (src.respond_to?(:vanishMode) && src.vanishMode>0)
          actor=snapshot.call(src,20_016,true)
          ax,ay=src.x,src.y
          acx=ax+(src.src_rect.width/2.0-src.ox)*src.zoom_x
          acy=ay+(src.src_rect.height/2.0-src.oy)*src.zoom_y
          actor_opacity=actor.opacity
          ghosts=Array.new(3) do
            g=snapshot.call(src,20_013,true);g.color=Color.new(52,16,69,220);g
          end
          shadow=@sprites["shadow_#{user.index}"]
          hidden[shadow.object_id]=[shadow,shadow.visible] if shadow && !shadow.disposed?
        end
        veil=make.call(veil_b,0,0,20_000)
        groups=targets.map do |b|
          target=@sprites["pokemon_#{b.index}"];copy=snapshot.call(target,20_011)
          cx=target.x+(target.src_rect.width/2.0-target.ox)*target.zoom_x
          cy=target.y+(target.src_rect.height*0.50-target.oy)*target.zoom_y
          {cx:cx,cy:cy,x:target.x,y:target.y,copy:copy,color:target.color.clone,
           stab:make.call(thrust_b,145,16,20_026),burst:make.call(burst_b,64,64,20_027),
           glint:make.call(glint_b,10,10,20_028),
           particles:Array.new(36) {make.call(particle_b,5,9,20_029)},
           smoke:Array.new(12) {make.call(smoke_b,24,24,20_024)},
           streaks:Array.new(10) {make.call(streak_b,0,5,20_014)}}
        end
        frames=[(Graphics.frame_rate*BackStabVisual::DURATION).round,2].max;cue_index=0
        frames.times do |f|
          t=f.to_f/(frames-1)
          while cue_index<BackStabVisual::CUES.size && t>=BackStabVisual::CUES[cue_index][0]
            BackStabVisual.sound(BackStabVisual::CUES[cue_index]);cue_index+=1
          end
          env=[t/0.12,(1-t)/0.18,1].min;veil.opacity=(env*95).round
          if actor
            gx,gy=groups[0].values_at(:cx,:cy);direction=gx>=acx ? 1 : -1
            halfwidth=src.src_rect.width*src.zoom_x*0.5
            behind=[[gx+direction*66,halfwidth+5].max,Graphics.width-halfwidth-5].min
            if t<0.18
              p=t/0.18;actor.x=ax-direction*p*12;actor.y=ay
              actor.opacity=was_hidden ? 0 : ((1-p)*actor_opacity).round
              actor.mirror=src.mirror
            elsif t<0.70
              p=[[(t-0.18)/0.17,0].max,1].min
              thrust=[[(t-0.35)/0.13,0].max,1].min
              actor.x=behind+(ax-acx)-direction*thrust*42
              actor.y=gy+(ay-acy)
              actor.opacity=(p*[[(0.70-t)/0.15,0].max,1].min*actor_opacity).round
              actor.mirror=!src.mirror
            else
              actor.x,actor.y=ax,ay;actor.mirror=src.mirror
              actor.opacity=was_hidden ? 0 : ([[(t-0.80)/0.20,0].max,1].min*actor_opacity).round
            end
            ghosts.each_with_index do |g,i|
              g.x=actor.x+direction*(i+1)*12;g.y=actor.y+(i-1)*2
              g.mirror=actor.mirror
              g.opacity=t>=0.18 && t<0.53 ? (actor.opacity*(0.26-i*0.06)).round : 0
            end
          end
          groups.each do |g|
            cx,cy=g.values_at(:cx,:cy)
            direction=actor ? (cx>=acx ? 1 : -1) : 1
            p=(t-0.43)/0.22
            stab=g[:stab];stab.x=cx-direction*[[p,0].max,1].min*18;stab.y=cy
            stab.angle=direction>0 ? 180 : 0
            stab.zoom_x=0.65+[[p/0.16,0].max,1].min*0.45;stab.zoom_y=0.78
            stab.opacity=p>=0 && p<=1 ? ((1-p)**0.6*255).round : 0
            burst=g[:burst];burst.x,burst.y=cx,cy
            burst.zoom_x=burst.zoom_y=0.18+[[p,0].max,1].min*0.90;burst.angle=13
            burst.opacity=p>=0 && p<=1 ? ((1-p)**1.6*235).round : 0
            glint=g[:glint];glint.x,glint.y=cx,cy
            glint.zoom_x=0.55;glint.zoom_y=1.2
            glint.opacity=p>=0 && p<=0.5 ? ((1-p*2)*255).round : 0
            intensity=p>=0 && p<=1 ? 1-p : 0
            g[:copy].x=g[:x]-direction*intensity*5+Math.sin(f*2.8)*intensity*3
            g[:copy].y=g[:y]+Math.cos(f*2.2)*intensity*2
            g[:copy].color=intensity>0 ? Color.new(240,174,215,(intensity*125).round) : g[:color]
            g[:particles].each_with_index do |s,i|
              q=(t-0.44-i%4*0.010)/0.37;a=i*2.399
              r=8+[q,0].max*(35+i%5*16)
              s.x=cx+Math.cos(a)*r;s.y=cy+Math.sin(a)*r*0.64+[q,0].max**2*22
              s.zoom_x=s.zoom_y=0.20+i%4*0.10;s.angle=i*29+[q,0].max*150
              s.opacity=q>=0 && q<=1 ? ((1-q)**0.6*230).round : 0
            end
            g[:smoke].each_with_index do |s,i|
              q=(t-0.19-i%4*0.024)/0.46;a=i*2.399
              r=12+[q,0].max*48
              s.x=cx+direction*35+Math.cos(a)*r;s.y=cy+Math.sin(a)*r*0.8-[q,0].max*16
              s.zoom_x=s.zoom_y=0.35+[q,0].max*0.95
              s.opacity=q>=0 && q<=1 ? (Math.sin(q*Math::PI)*145).round : 0
            end
            g[:streaks].each_with_index do |s,i|
              q=(t-0.28)/0.25;a=i*Math::PI/5
              r=140-[[q,0].max,1].min*130
              s.x=cx+Math.cos(a)*r;s.y=cy+Math.sin(a)*r*0.65
              s.angle=-a*180/Math::PI+180;s.zoom_x=0.33+i%3*0.10;s.zoom_y=0.35
              s.opacity=q>=0 && q<=1 ? (Math.sin(q*Math::PI)*170).round : 0
            end
          end
          hidden.each_value { |s,_|s.visible=false unless s.disposed? };pbUpdate
        end
      ensure
        boxes=@back_stab_boxes;@back_stab_boxes=nil
        boxes.each_value { |s,v|s.visible=v if s && !s.disposed? } if boxes
        hidden.each_value { |s,v|s.visible=v if s && !s.disposed? }
        sprites.reverse_each { |s|s.dispose unless s.disposed? }
        bitmaps.each { |b|b.dispose unless b.disposed? }
      end
    end
  end
end
Battle::Scene.prepend(BackStabVisual::SceneHooks)
