# Esper Waltz - Pokemon Essentials v21.1. Move ID: ESPERWALTZ.
# Install in Plugins/[KAITO] Plugin/ and recompile.
# Three-beat psychic dance, orbiting silk light, prismatic wave finale.
# Visual beats are NOT additional hits. No damage/stat calculation hooks.
module EsperWaltzVisual
  VERSION = "1.0"
  MOVE_IDS = [:ESPERWALTZ]
  DURATION = 2.65
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
      diamond=Bitmap.new(24,40);a<<diamond
      polygon(diamond,[[12,1],[23,19],[12,39],[1,19]],Color.new(107,64,167,250))
      polygon(diamond,[[12,3],[12,20],[3,19]],Color.new(246,197,255,255))
      polygon(diamond,[[12,3],[21,19],[12,20]],Color.new(181,126,241,255))
      polygon(diamond,[[12,20],[21,19],[12,36]],Color.new(221,160,242,255))
      diamond.fill_rect(10,16,3,7,Color.new(255,241,255,255))
      silk=Bitmap.new(24,10);a<<silk
      22.times do |x|
        alpha=(Math.sin(x/21.0*Math::PI)*200).round
        silk.fill_rect(x+1,2,1,6,Color.new(159,99,224,(alpha*0.45).round))
        silk.fill_rect(x+1,4,1,2,Color.new(255,194,241,alpha))
        silk.fill_rect(x+1,4,1,1,Color.new(255,239,255,(alpha*0.8).round))
      end
      crescent=Bitmap.new(88,136);a<<crescent
      outside=[];inside=[]
      65.times do |i|
        theta=-Math::PI*0.48+i/64.0*Math::PI*0.96
        outside<<[10+Math.cos(theta)*66,68+Math.sin(theta)*63]
        inside<<[10+Math.cos(theta)*47,68+Math.sin(theta)*60]
      end
      polygon(crescent,outside+inside.reverse,Color.new(122,66,190,220))
      outside.each_cons(2) { |p,q|line(crescent,*p,*q,2,Color.new(252,206,255,245)) }
      mid=outside.zip(inside).map { |p,q|[(p[0]+q[0])/2,(p[1]+q[1])/2] }
      mid.each_cons(2) { |p,q|line(crescent,*p,*q,2,Color.new(215,157,255,245)) }
      ring=Bitmap.new(144,144);a<<ring
      180.times do |i|
        theta=i*Math::PI/90
        ring.fill_rect((72+Math.cos(theta)*61).round,(72+Math.sin(theta)*61).round,2,2,Color.new(235,173,255,220))
      end
      star=Bitmap.new(24,24);a<<star
      polygon(star,[[12,0],[14,9],[23,12],[14,14],[12,23],[9,14],[0,12],[9,9]],Color.new(226,182,255,240))
      star.fill_rect(10,10,4,4,Color.new(255,247,255,255))
      halo=Bitmap.new(160,160);a<<halo
      (6..72).step(6).to_a.reverse.each do |r|
        (-r..r).each do |y|
          h=Math.sqrt(r*r-y*y).floor
          halo.fill_rect(80-h,80+y,h*2+1,1,Color.new(168,103,228,((1-r/78.0)*13).round))
        end
      end
      rosette=Bitmap.new(160,160);a<<rosette
      3.times do |lane|
        points=Array.new(121) do |i|
          theta=i*Math::PI/60;r=42+Math.cos(theta*3+lane*Math::PI*2/3)*18
          [80+Math.cos(theta)*r,80+Math.sin(theta)*r]
        end
        points.each_cons(2) { |p,q|line(rosette,*p,*q,2,Color.new(222+lane*10,164+lane*20,252,150)) }
      end
      veil=Bitmap.new(Graphics.width,Graphics.height);a<<veil
      veil.fill_rect(0,0,Graphics.width,Graphics.height,Color.new(25,15,44,255))
      a
    rescue
      a.each { |b|b.dispose unless b.disposed? };raise
    end
  end
  CUES = [[0.07,["PRSFX- Quiver Dance","PRSFX- Calm Mind"],55,110],
          [0.24,["PRSFX- Psybeam","PRSFX- Confusion"],56,115],
          [0.43,["PRSFX- Psybeam","PRSFX- Confusion"],60,125],
          [0.62,["PRSFX- Psychic","PRSFX- Psybeam"],70,105],
          [0.86,["PRSFX- Extrasensory","PRSFX- Psychic"],72,115]]
  def self.sound(cue)
    _,names,volume,pitch=cue
    names.each do |name|
      next unless [".wav",".ogg",".mp3"].any? { |ext|File.file?("Audio/SE/Anim/#{name}#{ext}") }
      pbSEPlay("Anim/#{name}",volume,pitch);break
    end
  end
  module SceneHooks
    def pbAnimation(moveID,user,targets,hitNum=0)
      return super unless EsperWaltzVisual::MOVE_IDS.include?(moveID)
      return if @battle && !@battle.showAnims
      return if @esper_waltz_boxes
      entries=(targets.is_a?(Array) ? targets : [targets]).compact.select { |b|b.respond_to?(:index) }
      return super if entries.empty?
      entries=entries.uniq { |b|b.index }.select do |b|
        s=@sprites && @sprites["pokemon_#{b.index}"]
        s && !s.disposed? && s.bitmap &&
          !(b.respond_to?(:isCommander?) && b.isCommander?) &&
          !(s.respond_to?(:vanishMode) && s.vanishMode>0)
      end
      return if entries.empty?
      pbEsperWaltzVisual(user,entries)
    end
    def pbEsperWaltzHideHP
      return unless @esper_waltz_boxes && @sprites
      @sprites.each do |key,s|
        next unless key.to_s.start_with?("dataBox_") && s && !s.disposed?
        @esper_waltz_boxes[s.object_id]||=[s,s.visible];s.visible=false
      end
    end
    def pbGraphicsUpdate
      pbEsperWaltzHideHP if @esper_waltz_boxes
      super
    end
    def pbEsperWaltzVisual(user,targets)
      sprites,bitmaps,hidden=[],[],{}
      @esper_waltz_boxes={}
      begin
        @briefMessage=false;pbEsperWaltzHideHP
        bitmaps.concat(EsperWaltzVisual.assets)
        diamond_b,silk_b,wave_b,ring_b,star_b,halo_b,rosette_b,veil_b=bitmaps
        make=proc do |b,ox,oy,z|
          s=Sprite.new(@viewport);sprites<<s;s.bitmap,s.ox,s.oy,s.z=b,ox,oy,z;s.opacity=0;s
        end
        snapshot=proc do |src|
          b=src.bitmap.clone;bitmaps<<b;s=make.call(b,src.ox,src.oy,20_002)
          s.src_rect.set(src.src_rect.x,src.src_rect.y,src.src_rect.width,src.src_rect.height)
          s.x,s.y=src.x,src.y;s.zoom_x,s.zoom_y=src.zoom_x,src.zoom_y
          s.mirror,s.visible,s.opacity=src.mirror,src.visible,src.opacity
          s.color=src.color.clone;s.tone=src.tone.clone if src.respond_to?(:tone)
          hidden[src.object_id]||=[src,src.visible];src.visible=false;s
        end
        veil=make.call(veil_b,0,0,20_000)
        src=user && user.respond_to?(:index) && @sprites["pokemon_#{user.index}"]
        src=nil if src && (src.disposed? || !src.bitmap)
        first=@sprites["pokemon_#{targets[0].index}"]
        sx=src ? src.x+(src.src_rect.width/2.0-src.ox)*src.zoom_x : Graphics.width-first.x
        sy=src ? src.y+(src.src_rect.height*0.55-src.oy)*src.zoom_y : Graphics.height*0.5
        actor=nil
        if src && !targets.any? { |b|b.index==user.index }
          actor=snapshot.call(src);ax,ay=actor.x,actor.y
        end
        ribbons=Array.new(72) {make.call(silk_b,12,5,20_008)}
        crystals=Array.new(12) {make.call(diamond_b,12,20,20_012)}
        aura=make.call(halo_b,80,80,20_001)
        dance_seal=make.call(rosette_b,80,80,20_006)
        groups=targets.map do |b|
          target=@sprites["pokemon_#{b.index}"];copy=snapshot.call(target)
          cx=target.x+(target.src_rect.width/2.0-target.ox)*target.zoom_x
          cy=target.y+(target.src_rect.height*0.55-target.oy)*target.zoom_y
          {copy:copy,x:target.x,y:target.y,color:target.color.clone,cx:cx,cy:cy,
           waves:Array.new(3) {make.call(wave_b,44,68,20_016)},
           trail:Array.new(36) {make.call(star_b,12,12,20_014)},
           ring:Array.new(3) {make.call(ring_b,72,72,20_019)},
           sparks:Array.new(30) {make.call(diamond_b,12,20,20_021)},
           seal:make.call(rosette_b,80,80,20_020),halo:make.call(halo_b,80,80,20_005)}
        end
        frames=[(Graphics.frame_rate*EsperWaltzVisual::DURATION).round,2].max;cue_index=0
        frames.times do |f|
          t=f.to_f/(frames-1)
          while cue_index<EsperWaltzVisual::CUES.size && t>=EsperWaltzVisual::CUES[cue_index][0]
            EsperWaltzVisual.sound(EsperWaltzVisual::CUES[cue_index]);cue_index+=1
          end
          env=[t/0.14,(1-t)/0.16,1].min
          dance=[[(t-0.06)/0.64,0].max,1].min
          sway=Math.sin(dance*Math::PI*6)*5
          if actor
            actor.x=ax+sway;actor.y=ay-Math.sin(dance*Math::PI*3).abs*5
            actor.angle=Math.sin(dance*Math::PI*6)*3
          end
          veil.opacity=(env*84).round
          aura.x,aura.y=sx,sy;aura.opacity=(Math.sin(dance*Math::PI)*155).round
          aura.zoom_x=aura.zoom_y=1.1
          dance_seal.x,dance_seal.y=sx,sy+37
          dance_seal.zoom_x=0.95;dance_seal.zoom_y=0.32;dance_seal.angle=0
          dance_seal.opacity=(env*(t<0.70 ? 155 : [(0.90-t)/0.20,0].max*155)).round
          ribbons.each_with_index do |s,i|
            lane=i/24;p=(i%24)/24.0
            theta=p*Math::PI*2+t*9+lane*Math::PI*2/3
            radius=46+Math.sin(t*18+lane)*5
            x=sx+Math.cos(theta)*radius
            y=sy+Math.sin(theta)*radius*0.36+(lane-1)*20
            x2=sx+Math.cos(theta+0.04)*radius
            y2=sy+Math.sin(theta+0.04)*radius*0.36+(lane-1)*20
            s.x,s.y=x,y;s.angle=-Math.atan2(y2-y,x2-x)*180/Math::PI
            s.zoom_x=0.70;s.zoom_y=0.45+lane*0.1
            s.z=Math.sin(theta)<0 ? 20_001 : 20_010
            s.opacity=(env*[[(0.83-t)/0.20,0].max,1].min*(100+Math.sin(theta)*60)).round
          end
          crystals.each_with_index do |s,i|
            theta=i*Math::PI/6+t*5.5;r=57+Math.sin(i+t*16)*5
            s.x=sx+Math.cos(theta)*r;s.y=sy+Math.sin(theta)*r*0.6
            s.zoom_x=s.zoom_y=0.25+i%3*0.08;s.angle=-theta*180/Math::PI+30
            s.opacity=(env*[[(0.78-t)/0.16,0].max,1].min*215).round
          end
          groups.each do |g|
            cx,cy=g.values_at(:cx,:cy);dx,dy=cx-sx,cy-sy
            angle=-Math.atan2(dy,dx)*180/Math::PI
            arrivals=[0.48,0.67,0.86]
            pulse=arrivals.map { |st|p=(t-st)/0.12;p>=0 && p<=1 ? 1-p : 0 }.max
            g[:copy].x=g[:x]+Math.sin(f*2)*pulse*(t>=0.86 ? 5 : 2)
            g[:copy].y=g[:y]-pulse*3
            g[:copy].color=pulse>0 ? Color.new(225,181,255,(pulse*125).round) : g[:color]
            g[:waves].each_with_index do |s,i|
              p=(t-[0.24,0.43,0.62][i])/0.24
              s.x=sx+dx*p;s.y=sy+dy*p-Math.sin(p*Math::PI)*(i==1 ? -14 : 18)
              s.angle=angle;s.zoom_x=0.40+i*0.09;s.zoom_y=0.54+i*0.12
              s.opacity=p>=0 && p<=1 ? (Math.sin(p*Math::PI)**0.25*245).round : 0
            end
            g[:trail].each_with_index do |s,i|
              lane=i/12;delay=(i%12)*0.009
              p=(t-[0.24,0.43,0.62][lane]-delay)/0.24
              q=[[p,0].max,1].min
              twist=Math.sin(q*Math::PI*5+lane*2)*Math.sin(q*Math::PI)*16
              s.x=sx+dx*q;s.y=sy+dy*q+twist
              s.zoom_x=s.zoom_y=0.13+(i%3)*0.07;s.angle=i*19+t*70
              s.opacity=p>=0 && p<=1 ? (Math.sin(p*Math::PI)*180).round : 0
            end
            g[:ring].each_with_index do |s,i|
              p=(t-arrivals[i])/0.14
              s.x,s.y=cx,cy;s.zoom_x=s.zoom_y=0.30+[p,0].max*(i==2 ? 1.25 : 0.70)
              s.opacity=p>=0 && p<=1 ? ((1-p)*230).round : 0
            end
            finish=[[(t-0.86)/0.14,0].max,1].min
            seal=g[:seal];seal.x,seal.y=cx,cy;seal.angle=t*85
            seal.zoom_x=seal.zoom_y=0.40+finish*0.85
            seal.opacity=t>=0.86 ? ((1-finish)**0.65*235).round : 0
            halo=g[:halo];halo.x,halo.y=cx,cy
            halo.zoom_x=halo.zoom_y=1+finish*0.8;halo.opacity=(pulse*180).round
            g[:sparks].each_with_index do |s,i|
              st=arrivals[i/10];p=(t-st)/0.14;a=i*2.399
              radius=10+[p,0].max*(38+i%4*9)
              s.x=cx+Math.cos(a)*radius;s.y=cy+Math.sin(a)*radius*0.8
              s.zoom_x=s.zoom_y=0.15+i%3*0.07;s.angle=i*43+[p,0].max*90
              s.opacity=p>=0 && p<=1 ? (Math.sin(p*Math::PI)*230).round : 0
            end
          end
          hidden.each_value { |s,_|s.visible=false unless s.disposed? };pbUpdate
        end
      ensure
        boxes=@esper_waltz_boxes;@esper_waltz_boxes=nil
        boxes.each_value { |s,v|s.visible=v if s && !s.disposed? } if boxes
        hidden.each_value { |s,v|s.visible=v if s && !s.disposed? }
        sprites.reverse_each { |s|s.dispose unless s.disposed? }
        bitmaps.each { |b|b.dispose unless b.disposed? }
      end
    end
  end
end
Battle::Scene.prepend(EsperWaltzVisual::SceneHooks)
