# Lurk - Pokemon Essentials v21.1 / DBK Animated Pokemon System.
# Install in Plugins/[KAITO] Plugin/ and recompile. Move ID LURK.
# hitNum 1 = disappear; hitNum 0 = ambush. Engine owns vanishMode between turns.
# Presentation only: no damage, protection, invulnerability or battler effect hooks.
module LurkVisual
  VERSION = "1.0"
  MOVE_IDS = [:LURK]
  CHARGE_DURATION = 2.05
  ATTACK_DURATION = 2.45
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
      pool=Bitmap.new(192,96);a<<pool
      (2..42).step(2).to_a.reverse.each do |r|
        (-r..r).each do |y|
          half=(Math.sqrt(r*r-y*y)*2.1).floor
          p=1-r/44.0
          pool.fill_rect(96-half,48+y,half*2+1,1,Color.new((60-p*43).round,(27-p*17).round,(85-p*53).round,(90+p*150).round))
        end
      end
      120.times do |i|
        ang=i*Math::PI/60
        pool.fill_rect((96+Math.cos(ang)*87).round,(48+Math.sin(ang)*39).round,3,1,Color.new(168,82,192,190))
      end
      mist=Bitmap.new(64,64);a<<mist
      64.times do |y|
        64.times do |x|
          r=((x-31.5)**2+(y-31.5)**2)/992.25;next if r>1
          alpha=((Math.exp(-r*4)-Math.exp(-4))/(1-Math.exp(-4))*150).round
          mist.fill_rect(x,y,1,1,Color.new(56,27,76,alpha)) if alpha>0
        end
      end
      cut=Bitmap.new(96,272);a<<cut
      [[15,[20,9,32,235]],[8,[120,47,139,240]],[3.4,[238,139,210,250]],[1.2,[255,233,234,255]]].each do |width,col|
        l=[];r=[]
        72.times do |i|
          p=i/71.0;x=38+Math.sin(p*Math::PI)*24;y=5+p*261
          half=Math.sin(p*Math::PI)**0.75*width
          l<<[x-half,y];r<<[x+half,y]
        end
        polygon(cut,l+r.reverse,Color.new(*col))
      end
      rift=Bitmap.new(96,224);a<<rift
      l=[];r=[]
      20.times do |i|
        p=i/19.0;x=48+Math.sin(i*2.3)*5;y=4+p*216
        half=Math.sin(p*Math::PI)*(14+i%3*3)
        l<<[x-half,y];r<<[x+half,y]
      end
      polygon(rift,l+r.reverse,Color.new(14,7,25,250))
      [l,r].each { |path|path.each_cons(2) { |p,q|line(rift,*p,*q,2,Color.new(183,94,190,215)) } }
      spark=Bitmap.new(12,18);a<<spark
      polygon(spark,[[6,0],[10,7],[6,17],[2,10]],Color.new(168,75,174,235))
      spark.fill_rect(5,5,2,5,Color.new(255,181,224,245))
      ring=Bitmap.new(160,160);a<<ring
      160.times do |i|
        ang=i*Math::PI/80
        ring.fill_rect((80+Math.cos(ang)*70).round,(80+Math.sin(ang)*70).round,2,2,Color.new(189,102,189,190))
      end
      streak=Bitmap.new(192,12);a<<streak
      polygon(streak,[[0,6],[167,1],[191,6],[167,11]],Color.new(47,19,66,210))
      line(streak,22,6,183,6,2,Color.new(182,83,172,150))
      veil=Bitmap.new(Graphics.width,Graphics.height);a<<veil
      veil.fill_rect(0,0,Graphics.width,Graphics.height,Color.new(13,9,24,255))
      a
    rescue
      a.each { |b|b.dispose unless b.disposed? };raise
    end
  end
  CHARGE_CUES = [[0.08,["PRSFX- Shadow Force1","PRSFX- Phantom Force1","PRSFX- Ominous Wind"],60,80],
                [0.36,["PRSFX- Shadow Sneak1","PRSFX- Shadow Force1"],65,90],
                [0.68,["PRSFX- Phantom Force2","PRSFX- Shadow Force2"],58,75]]
  ATTACK_CUES = [[0.12,["PRSFX- Shadow Sneak1","PRSFX- Shadow Force1"],65,80],
                [0.28,["PRSFX- Shadow Force2","PRSFX- Phantom Force2"],75,90],
                [0.46,["PRSFX- Night Slash2","PRSFX- Slash"],90,85],
                [0.56,["PRSFX- Dark Pulse1","PRSFX- Shadow Claw"],78,80]]
  def self.sound(cue)
    _,names,volume,pitch=cue
    names.each do |name|
      next unless [".wav",".ogg",".mp3"].any? { |ext|File.file?("Audio/SE/Anim/#{name}#{ext}") }
      pbSEPlay("Anim/#{name}",volume,pitch);break
    end
  end
  module SceneHooks
    def pbAnimation(moveID,user,targets,hitNum=0)
      return super unless LurkVisual::MOVE_IDS.include?(moveID)
      return if @battle && !@battle.showAnims
      return if @lurk_boxes
      actor=user && user.respond_to?(:index) && @sprites && @sprites["pokemon_#{user.index}"]
      return super unless actor && !actor.disposed? && actor.bitmap
      return if user.respond_to?(:isCommander?) && user.isCommander?
      entries=(targets.is_a?(Array) ? targets : [targets]).compact.select { |b|b.respond_to?(:index) }
      return pbLurkVisual(user,[],true) if hitNum==1 && entries.empty?
      return super if entries.empty?
      entries=entries.uniq { |b|b.index }.select do |b|
        s=@sprites && @sprites["pokemon_#{b.index}"]
        s && !s.disposed? && s.bitmap &&
          !(b.respond_to?(:isCommander?) && b.isCommander?) &&
          !(s.respond_to?(:vanishMode) && s.vanishMode>0)
      end
      return if entries.empty?
      pbLurkVisual(user,entries,hitNum==1)
    end
    def pbLurkHideHP
      return unless @lurk_boxes && @sprites
      @sprites.each do |key,s|
        next unless key.to_s.start_with?("dataBox_") && s && !s.disposed?
        @lurk_boxes[s.object_id]||=[s,s.visible];s.visible=false
      end
    end
    def pbGraphicsUpdate
      pbLurkHideHP if @lurk_boxes
      super
    end
    def pbLurkVisual(user,targets,charging)
      sprites,bitmaps,hidden=[],[],{}
      @lurk_boxes={}
      begin
        @briefMessage=false;pbLurkHideHP
        bitmaps.concat(LurkVisual.assets)
        pool_b,mist_b,cut_b,rift_b,spark_b,ring_b,streak_b,veil_b=bitmaps
        make=proc do |b,ox,oy,z|
          s=Sprite.new(@viewport);sprites<<s;s.bitmap,s.ox,s.oy,s.z=b,ox,oy,z;s.opacity=0;s
        end
        snapshot=proc do |src,z,force=false|
          bmp=src.bitmap.clone;bitmaps<<bmp;copy=make.call(bmp,src.ox,src.oy,z)
          copy.src_rect.set(src.src_rect.x,src.src_rect.y,src.src_rect.width,src.src_rect.height)
          copy.x,copy.y=src.x,src.y;copy.zoom_x,copy.zoom_y=src.zoom_x,src.zoom_y
          copy.mirror=src.mirror;copy.visible=force ? true : src.visible
          copy.opacity=force && src.opacity==0 ? 255 : src.opacity
          copy.color=src.color.clone;copy.tone=src.tone.clone if src.respond_to?(:tone)
          hidden[src.object_id]||=[src,src.visible];src.visible=false;copy
        end
        original=@sprites["pokemon_#{user.index}"]
        actor=snapshot.call(original,20_015,!charging)
        ax,ay=original.x,original.y
        acx=ax+(original.src_rect.width/2.0-original.ox)*original.zoom_x
        acy=ay+(original.src_rect.height/2.0-original.oy)*original.zoom_y
        foot=ay+(original.src_rect.height-original.oy)*original.zoom_y
        base_opacity=actor.opacity
        shadow=@sprites["shadow_#{user.index}"]
        hidden[shadow.object_id]=[shadow,shadow.visible] if shadow && !shadow.disposed?
        veil=make.call(veil_b,0,0,20_000)
        pool=make.call(pool_b,96,48,20_010);pool.x,pool.y=acx,foot-3
        smoke=Array.new(20) {make.call(mist_b,32,32,20_021)}
        charge_motes=Array.new(36) {make.call(spark_b,6,9,20_023)}
        ghosts=Array.new(3) do
          ghost=snapshot.call(original,20_013,true)
          ghost.color=Color.new(59,17,81,220);ghost
        end
        groups=targets.map do |b|
          src=@sprites["pokemon_#{b.index}"]
          copy=b.index==user.index ? nil : snapshot.call(src,20_012)
          cx=src.x+(src.src_rect.width/2.0-src.ox)*src.zoom_x
          cy=src.y+(src.src_rect.height/2.0-src.oy)*src.zoom_y
          {cx:cx,cy:cy,x:src.x,y:src.y,copy:copy,color:src.color.clone,
           rift:make.call(rift_b,48,112,20_014),
           cuts:Array.new(3) {make.call(cut_b,48,136,20_028)},
           motes:Array.new(64) {make.call(spark_b,6,9,20_030)},
           smoke:Array.new(14) {make.call(mist_b,32,32,20_024)},
           streaks:Array.new(14) {make.call(streak_b,0,6,20_011)},
           ring:make.call(ring_b,80,80,20_026)}
        end
        cues=charging ? LurkVisual::CHARGE_CUES : LurkVisual::ATTACK_CUES
        duration=charging ? LurkVisual::CHARGE_DURATION : LurkVisual::ATTACK_DURATION
        frames=[(Graphics.frame_rate*duration).round,2].max;cue_index=0
        frames.times do |f|
          t=f.to_f/(frames-1)
          while cue_index<cues.size && t>=cues[cue_index][0]
            LurkVisual.sound(cues[cue_index]);cue_index+=1
          end
          env=[t/0.16,(1-t)/0.18,1].min;veil.opacity=(env*(charging ? 110 : 145)).round
          if charging
            sink=[[(t-0.20)/0.52,0].max,1].min
            actor.x=ax+Math.sin(t*22)*sink*2;actor.y=ay+sink*28
            actor.zoom_y=original.zoom_y*(1-sink*0.64)
            actor.opacity=(base_opacity*(1-sink)**1.6).round
            actor.color=Color.new(42,15,65,(sink*210).round)
            pool.zoom_x=0.35+Math.sin(t*Math::PI)*1.0;pool.zoom_y=0.18+Math.sin(t*Math::PI)*0.46
            pool.opacity=(env*(1-sink*0.28)*245).round
            ghosts.each { |s|s.opacity=0 }
          else
            pool.opacity=0
            gx,gy=groups[0].values_at(:cx,:cy)
            direction=gx>=acx ? 1 : -1
            emerge=[[(t-0.22)/0.18,0].max,1].min
            thrust=[[(t-0.40)/0.13,0].max,1].min
            offset=direction*(78-emerge*18-thrust*55)
            actor.x=gx+(ax-acx)+offset;actor.y=gy+(ay-acy)
            actor.opacity=t>=0.22 && t<0.76 ? (emerge*[[(0.76-t)/0.16,0].max,1].min*base_opacity).round : 0
            actor.color=t<0.40 ? Color.new(47,15,68,((1-emerge)*210).round) : original.color.clone
            if t>=0.86
              actor.x,actor.y=ax,ay;actor.opacity=(((t-0.86)/0.14)*base_opacity).round
            end
            ghosts.each_with_index do |s,i|
              s.x=actor.x+direction*(i+1)*16;s.y=actor.y+(i-1)*3
              s.opacity=t>=0.22 && t<0.60 ? (actor.opacity*(0.30-i*0.07)).round : 0
            end
          end
          smoke.each_with_index do |s,i|
            p=(t*1.3+i*0.057)%1;a=i*2.399
            s.x=acx+Math.cos(a)*(20+p*34);s.y=foot-p*(45+i%4*14)
            s.zoom_x=0.4+p*0.85;s.zoom_y=0.5+p*0.8
            s.opacity=charging ? (Math.sin(p*Math::PI)*env*190).round : 0
          end
          charge_motes.each_with_index do |s,i|
            p=(t*1.25+i*0.049)%1;a=i*2.399+t*2
            s.x=acx+Math.cos(a)*(1-p)*66;s.y=foot-(1-p)*(20+i%5*13)
            s.zoom_x=s.zoom_y=0.28+i%3*0.13;s.angle=i*31+t*90
            s.opacity=charging ? (Math.sin(p*Math::PI)*env*200).round : 0
          end
          groups.each do |g|
            next if charging
            cx,cy=g.values_at(:cx,:cy)
            direction=cx>=acx ? 1 : -1
            rift=g[:rift];rift.x,rift.y=cx+direction*42,cy
            rift.zoom_x=0.35+Math.sin([[(t-0.12)/0.60,0].max,1].min*Math::PI)*0.65
            rift.zoom_y=0.9;rift.angle=direction*(-13)
            rift.opacity=t>=0.12 && t<0.72 ? (Math.sin((t-0.12)/0.60*Math::PI)*245).round : 0
            intensity=t>=0.46 && t<0.70 ? (1-(t-0.46)/0.24) : 0
            if g[:copy]
              g[:copy].x=g[:x]+Math.sin(f*2.5)*intensity*8
              g[:copy].y=g[:y]+Math.cos(f*2.7)*intensity*3
              g[:copy].color=intensity>0 ? Color.new(246,177,224,(intensity*155).round) : g[:color]
            end
            g[:cuts].each_with_index do |s,i|
              p=(t-0.44-i*0.036)/0.22
              s.x=cx+(i-1)*21;s.y=cy+(i-1)*7
              s.angle=direction*(i==1 ? 44 : -43)
              s.zoom_x=i==1 ? 1.3 : 0.8;s.zoom_y=i==1 ? 1.14 : 0.93
              s.opacity=p>=0 && p<=1 ? ((1-p)**0.55*255).round : 0
            end
            g[:motes].each_with_index do |s,i|
              p=(t-0.46-i%5*0.012)/0.39;a=i*2.399
              r=10+[p,0].max*(65+i%6*18)
              s.x=cx+Math.cos(a)*r;s.y=cy+Math.sin(a)*r*0.76+[p,0].max**2*25
              s.zoom_x=s.zoom_y=0.25+i%4*0.12;s.angle=i*31+[p,0].max*160
              s.opacity=p>=0 && p<=1 ? ((1-p)**0.7*245).round : 0
            end
            g[:smoke].each_with_index do |s,i|
              p=(t-0.26-i%3*0.026)/0.50;a=i*2.399
              s.x=cx+Math.cos(a)*(15+[p,0].max*85)
              s.y=cy+Math.sin(a)*(10+[p,0].max*45)-[p,0].max*25
              s.zoom_x=s.zoom_y=0.5+[p,0].max*1.25
              s.opacity=p>=0 && p<=1 ? (Math.sin(p*Math::PI)*170).round : 0
            end
            g[:streaks].each_with_index do |s,i|
              a=i*Math::PI/7
              p=(t-0.34)/0.25
              r=180-[[p,0].max,1].min*165
              s.x=cx+Math.cos(a)*r;s.y=cy+Math.sin(a)*r*0.70
              s.angle=-a*180/Math::PI+180;s.zoom_x=0.38+i%3*0.12;s.zoom_y=0.45
              s.opacity=p>=0 && p<=1 ? (Math.sin(p*Math::PI)*190).round : 0
            end
            ring=g[:ring];p=(t-0.48)/0.22
            ring.x,ring.y=cx,cy;ring.zoom_x=ring.zoom_y=0.2+[p,0].max*1.7
            ring.opacity=p>=0 && p<=1 ? ((1-p)*185).round : 0
          end
          hidden.each_value { |s,_|s.visible=false unless s.disposed? };pbUpdate
        end
      ensure
        boxes=@lurk_boxes;@lurk_boxes=nil
        boxes.each_value { |s,v|s.visible=v if s && !s.disposed? } if boxes
        hidden.each_value { |s,v|s.visible=v if s && !s.disposed? }
        sprites.reverse_each { |s|s.dispose unless s.disposed? }
        bitmaps.each { |b|b.dispose unless b.disposed? }
      end
    end
  end
end
Battle::Scene.prepend(LurkVisual::SceneHooks)
