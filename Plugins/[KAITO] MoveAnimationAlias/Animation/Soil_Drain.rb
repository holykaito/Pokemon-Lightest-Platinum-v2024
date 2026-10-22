# Soil Drain - Pokemon Essentials v21.1.
# Install in Plugins/[KAITO] Plugin/ and recompile. Move ID SOILDRAIN.
# Cracked earth, heaving soil plates and braided mineral energy absorption.
# Presentation only: damage and healing are handled by the original move.
module SoilDrainVisual
  VERSION = "1.0"
  MOVE_IDS = [:SOILDRAIN]
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
      drop=Bitmap.new(16,16);a<<drop
      16.times do |y|
        16.times do |x|
          r=((x-7.5)**2+(y-7.5)**2)/56.25;next if r>1
          alpha=((1-r)**2*220).round
          drop.fill_rect(x,y,1,1,Color.new(242,181,76,alpha)) if alpha>0
        end
      end
      drop.fill_rect(6,6,4,4,Color.new(255,244,162,255))
      trail=Bitmap.new(28,8);a<<trail
      26.times do |x|
        alpha=(Math.sin(x/25.0*Math::PI)*145).round
        trail.fill_rect(x+1,2,1,4,Color.new(177,147,58,alpha))
        trail.fill_rect(x+1,3,1,2,Color.new(255,221,126,alpha))
      end
      petal=Bitmap.new(36,34);a<<petal
      polygon(petal,[[3,13],[10,3],[26,2],[33,13],[28,29],[12,33],[2,24]],Color.new(67,44,34,250))
      polygon(petal,[[3,13],[10,3],[26,2],[33,13],[21,19],[10,19]],Color.new(165,118,67,255))
      polygon(petal,[[10,20],[21,20],[28,16],[25,28],[12,31]],Color.new(111,75,46,255))
      line(petal,10,5,19,9,2,Color.new(211,164,90,230))
      ring=Bitmap.new(128,128);a<<ring
      160.times do |i|
        ang=i*Math::PI/80
        ring.fill_rect((64+Math.cos(ang)*54).round,(64+Math.sin(ang)*54).round,2,2,Color.new(202,219,113,180))
      end
      glint=Bitmap.new(16,16);a<<glint
      polygon(glint,[[8,0],[10,6],[15,8],[10,10],[8,15],[6,10],[0,8],[6,6]],Color.new(229,239,139,230))
      glint.fill_rect(6,6,4,4,Color.new(255,250,203,255))
      halo=Bitmap.new(128,128);a<<halo
      128.times do |y|
        128.times do |x|
          r=((x-63.5)**2+(y-63.5)**2)/4000.0;next if r>1
          alpha=((1-r)**3*80).round
          halo.fill_rect(x,y,1,1,Color.new(190,205,87,alpha)) if alpha>0
        end
      end
      flower=Bitmap.new(224,96);a<<flower
      polygon(flower,[[8,48],[24,20],[65,7],[134,4],[190,19],[215,43],[206,72],[163,89],[86,91],[30,77]],Color.new(66,45,31,150))
      polygon(flower,[[17,46],[40,24],[88,14],[144,13],[190,30],[202,53],[177,74],[117,81],[57,71]],Color.new(119,85,44,100))
      9.times do |i|
        angle=i*Math::PI*2/9+0.2
        pts=[[112,48],[112+Math.cos(angle)*26,48+Math.sin(angle)*12],
             [112+Math.cos(angle+0.13)*56,48+Math.sin(angle+0.13)*25],
             [112+Math.cos(angle-0.07)*96,48+Math.sin(angle-0.07)*39]]
        pts.each_cons(2) do |p,q|
          line(flower,*p,*q,5,Color.new(41,28,22,220))
          line(flower,*p,*q,2,Color.new(235,164,65,195))
        end
        p=pts[2];q=[p[0]+Math.cos(angle+0.7)*23,p[1]+Math.sin(angle+0.7)*14]
        line(flower,*p,*q,2,Color.new(194,126,51,160))
      end
      veil=Bitmap.new(Graphics.width,Graphics.height);a<<veil
      veil.fill_rect(0,0,Graphics.width,Graphics.height,Color.new(36,31,29,255))
      a
    rescue
      a.each { |b|b.dispose unless b.disposed? };raise
    end
  end
  CUES = [[0.06,["PRSFX- Earth Power","PRSFX- Sand Tomb"],65,85],
          [0.23,["PRSFX- Sand Tomb","PRSFX- Absorb1"],48,110],
          [0.39,["PRSFX- Giga Drain1","PRSFX- Absorb1"],60,110],
          [0.63,["PRSFX- Giga Drain2","PRSFX- Absorb2"],58,115],
          [0.83,["PRSFX- Shore Up","PRSFX- Absorb2"],46,120]]
  def self.path(p,cx,cy,sx,sy,lane)
    dx,dy=sx-cx,sy-cy;length=[Math.sqrt(dx*dx+dy*dy),1].max
    arc=Math.sin(p*Math::PI)
    twist=Math.sin(p*Math::PI*4+lane*Math::PI*2/3)*arc*14
    [cx+dx*p-dy/length*twist,cy+dy*p+arc*28+dx/length*twist]
  end
  def self.sound(cue)
    _,names,volume,pitch=cue
    names.each do |name|
      next unless [".wav",".ogg",".mp3"].any? { |ext|File.file?("Audio/SE/Anim/#{name}#{ext}") }
      pbSEPlay("Anim/#{name}",volume,pitch);break
    end
  end
  module SceneHooks
    def pbAnimation(moveID,user,targets,hitNum=0)
      return super unless SoilDrainVisual::MOVE_IDS.include?(moveID)
      return if @battle && !@battle.showAnims
      return if @soil_drain_boxes
      entries=(targets.is_a?(Array) ? targets : [targets]).compact.select { |b|b.respond_to?(:index) }
      return super if entries.empty?
      entries=entries.uniq { |b|b.index }.select do |b|
        s=@sprites && @sprites["pokemon_#{b.index}"]
        s && !s.disposed? && s.bitmap && s.visible && s.opacity>0 &&
          !(b.respond_to?(:isCommander?) && b.isCommander?) &&
          !(s.respond_to?(:vanishMode) && s.vanishMode>0)
      end
      return if entries.empty?
      pbSoilDrainVisual(user,entries)
    end
    def pbSoilDrainHideHP
      return unless @soil_drain_boxes && @sprites
      @sprites.each do |key,s|
        next unless key.to_s.start_with?("dataBox_") && s && !s.disposed?
        @soil_drain_boxes[s.object_id]||=[s,s.visible];s.visible=false
      end
    end
    def pbGraphicsUpdate
      pbSoilDrainHideHP if @soil_drain_boxes
      super
    end
    def pbSoilDrainVisual(user,targets)
      sprites,bitmaps,hidden=[],[],{}
      @soil_drain_boxes={}
      begin
        @briefMessage=false;pbSoilDrainHideHP
        bitmaps.concat(SoilDrainVisual.assets)
        drop_b,trail_b,petal_b,ring_b,glint_b,halo_b,flower_b,veil_b=bitmaps
        make=proc do |b,ox,oy,z|
          s=Sprite.new(@viewport);sprites<<s;s.bitmap,s.ox,s.oy,s.z=b,ox,oy,z;s.opacity=0;s
        end
        veil=make.call(veil_b,0,0,20_000)
        user_src=user && user.respond_to?(:index) && @sprites["pokemon_#{user.index}"]
        user_src=nil if user_src && (user_src.disposed? || !user_src.bitmap)
        first=@sprites["pokemon_#{targets[0].index}"]
        sx=user_src ? user_src.x+(user_src.src_rect.width/2.0-user_src.ox)*user_src.zoom_x : Graphics.width-first.x
        sy=user_src ? user_src.y+(user_src.src_rect.height*0.55-user_src.oy)*user_src.zoom_y : Graphics.height*0.55
        arrival=make.call(halo_b,64,64,20_004);arrival.x,arrival.y=sx,sy
        bloom=make.call(ring_b,64,64,20_012);bloom.x,bloom.y=sx,sy
        receive_rings=Array.new(3) {make.call(ring_b,64,64,20_010)}
        receive_glints=Array.new(16) {make.call(glint_b,10,10,20_020)}
        groups=targets.map do |b|
          src=@sprites["pokemon_#{b.index}"]
          cx=src.x+(src.src_rect.width/2.0-src.ox)*src.zoom_x
          cy=src.y+(src.src_rect.height*0.55-src.oy)*src.zoom_y
          {cx:cx,cy:cy,ground:src.y+(src.src_rect.height-src.oy)*src.zoom_y,flower:make.call(flower_b,112,48,20_002),halo:make.call(halo_b,64,64,20_005),
           drops:Array.new(66) {make.call(drop_b,8,8,20_016)},
           trails:Array.new(66) {make.call(trail_b,14,4,20_011)},
           petals:Array.new(16) {make.call(petal_b,18,17,20_018)},
           sparks:Array.new(18) {make.call(glint_b,10,10,20_017)}}
        end
        frames=[(Graphics.frame_rate*SoilDrainVisual::DURATION).round,2].max;cue_index=0
        frames.times do |f|
          t=f.to_f/(frames-1)
          while cue_index<SoilDrainVisual::CUES.size && t>=SoilDrainVisual::CUES[cue_index][0]
            SoilDrainVisual.sound(SoilDrainVisual::CUES[cue_index]);cue_index+=1
          end
          envelope=[t/0.15,(1-t)/0.16,1.0].min;veil.opacity=(envelope*67).round
          absorb=[[(t-0.48)/0.40,0].max,1].min
          arrival.opacity=(Math.sin(absorb*Math::PI)*190).round
          arrival.zoom_x=arrival.zoom_y=0.8+absorb*0.65
          bloom.opacity=(Math.sin(absorb*Math::PI)*150).round
          bloom.angle=-t*75;bloom.zoom_x=bloom.zoom_y=0.38+absorb*0.65
          receive_rings.each_with_index do |s,i|
            p=(t-0.56-i*0.10)/0.22
            s.x,s.y=sx,sy;s.zoom_x=s.zoom_y=0.25+[p,0].max*0.85
            s.opacity=p>=0 && p<=1 ? (Math.sin(p*Math::PI)*170).round : 0
          end
          receive_glints.each_with_index do |s,i|
            p=(t-0.53-i%4*0.065)/0.25;a=i*2.399
            s.x=sx+Math.cos(a)*(10+[p,0].max*48)
            s.y=sy+Math.sin(a)*(10+[p,0].max*32)-[p,0].max*20
            s.zoom_x=s.zoom_y=0.18+i%4*0.09;s.angle=i*17+t*80
            s.opacity=p>=0 && p<=1 ? (Math.sin(p*Math::PI)*235).round : 0
          end
          groups.each do |g|
            cx,cy=g.values_at(:cx,:cy)
            extract=[[(t-0.04)/0.69,0].max,1].min
            flower=g[:flower];flower.x,flower.y=cx,g[:ground]+4;flower.angle=0
            flower.zoom_x=flower.zoom_y=0.8+Math.sin(extract*Math::PI)*0.32
            flower.opacity=(Math.sin(extract*Math::PI)**0.5*235).round
            halo=g[:halo];halo.x,halo.y=cx,cy;halo.zoom_x=halo.zoom_y=1.05
            halo.opacity=(Math.sin(extract*Math::PI)*125).round
            g[:drops].each_with_index do |s,i|
              start=0.20+(i/3)*0.019;lane=i%3
              p=(t-start)/0.30
              if p>=0 && p<=1
                x,y=SoilDrainVisual.path(p,cx,cy+(g[:ground]-cy)*(1-p)*0.65,sx,sy,lane)
                x2,y2=SoilDrainVisual.path([p+0.01,1.001].min,cx,cy,sx,sy,lane)
                s.x,s.y=x,y
                # Rotate the pointed end into the direction of suction.
                s.angle=-Math.atan2(y2-y,x2-x)*180/Math::PI-90
                size=0.34+(i%5)*0.085
                s.zoom_x=size;s.zoom_y=size*(1.18+Math.sin(p*Math::PI)*0.3)
                s.opacity=([p/0.12,(1-p)/0.08,1].min*255).round
              else;s.opacity=0;end
            end
            g[:trails].each_with_index do |s,i|
              lane=i%3;p=(i/3)/21.0
              x,y=SoilDrainVisual.path(p,cx,cy+(g[:ground]-cy)*(1-p)*0.65,sx,sy,lane)
              x2,y2=SoilDrainVisual.path(p+0.015,cx,cy,sx,sy,lane)
              wave=[[(t-0.17-p*0.30)/0.12,0].max,1].min
              tail=[[(0.87-t)/0.14,0].max,1].min
              s.x,s.y=x,y;s.angle=-Math.atan2(y2-y,x2-x)*180/Math::PI
              s.zoom_x=0.35;s.zoom_y=0.38
              s.opacity=(wave*tail*(45+Math.sin(t*32-p*14+lane)*22)).round
            end
            g[:petals].each_with_index do |s,i|
              p=(t-0.07-i%4*0.025)/0.49
              if p>=0 && p<=1
                a=i*Math::PI*2/16;radius=48+i%3*14
                rise=Math.sin(p*Math::PI)
                s.x=cx+Math.cos(a)*radius*(1-p*0.55)
                s.y=g[:ground]+Math.sin(a)*radius*0.30-rise*(20+i%4*9)
                s.angle=Math.sin(p*Math::PI)*(i.even? ? 18 : -18)
                s.zoom_x=s.zoom_y=(0.42+i%4*0.10)*(1-p*0.25)
                s.opacity=([p/0.15,(1-p)/0.20,1].min*245).round
              else;s.opacity=0;end
            end
            g[:sparks].each_with_index do |s,i|
              p=(t-0.08-i%6*0.055)/0.27;a=i*2.399
              r=(1-[p,0].max)*(25+i%4*10)
              s.x=cx+Math.cos(a)*r;s.y=cy+Math.sin(a)*r*0.8
              s.zoom_x=s.zoom_y=0.15+i%3*0.08;s.angle=i*17
              s.opacity=p>=0 && p<=1 ? (Math.sin(p*Math::PI)*220).round : 0
            end
          end
          pbUpdate
        end
      ensure
        boxes=@soil_drain_boxes;@soil_drain_boxes=nil
        boxes.each_value { |s,v|s.visible=v if s && !s.disposed? } if boxes
        sprites.reverse_each { |s|s.dispose unless s.disposed? }
        bitmaps.each { |b|b.dispose unless b.disposed? }
      end
    end
  end
end
Battle::Scene.prepend(SoilDrainVisual::SceneHooks)
