# Deep Breathing - Pokemon Essentials v21.1. Move ID DEEPBREATHING.
# Install in Plugins/[KAITO] Plugin/ and recompile.
# Inhale -> stillness -> exhale / golden focus. Self animation only.
# Presentation only: original move handles Speed and critical-hit changes.
module DeepBreathingVisual
  VERSION = "1.0"
  MOVE_IDS = [:DEEPBREATHING]
  DURATION = 2.25
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





  def self.glow(size,rgb,alpha)
    b=Bitmap.new(size,size);half=(size-1)/2.0
    begin
      size.times do |y|
        size.times do |x|
          r=((x-half)**2+(y-half)**2)/(half*half);next if r>1
          a=((Math.exp(-r*4)-Math.exp(-4))/(1-Math.exp(-4))*alpha).round
          b.fill_rect(x,y,1,1,Color.new(*rgb,a)) if a>0
        end
      end
      b
    rescue
      b.dispose unless b.disposed?;raise
    end
  end
  def self.assets
    a=[]
    begin
      wind=Bitmap.new(112,40);a<<wind
      3.times do |lane|
        points=Array.new(60) do |i|
          p=i/59.0
          [3+p*104,20+Math.sin(p*Math::PI*1.5+lane*0.4)*8+(lane-1)*5]
        end
        points.each_cons(2).with_index do |(p,q),i|
          alpha=(Math.sin(i/58.0*Math::PI)*[80,185,100][lane]).round
          line(wind,*p,*q,1,Color.new(209,244,241,alpha))
        end
      end
      a<<glow(64,[207,241,231],90)
      a<<glow(14,[255,225,151],235)
      a<<glow(96,[255,220,143],65)
      ring=Bitmap.new(144,144);a<<ring
      180.times do |i|
        ang=i*Math::PI/90
        ring.fill_rect((72+Math.cos(ang)*63).round,(72+Math.sin(ang)*63).round,2,2,Color.new(226,242,218,190))
      end
      dash=Bitmap.new(8,32);a<<dash
      polygon(dash,[[4,0],[6,8],[5,25],[4,31],[2,23],[2,9]],Color.new(240,189,96,200))
      line(dash,4,5,4,25,1,Color.new(255,249,197,255))
      star=Bitmap.new(16,16);a<<star
      polygon(star,[[8,0],[10,6],[15,8],[10,10],[8,15],[6,10],[0,8],[6,6]],Color.new(255,228,158,230))
      star.fill_rect(6,6,4,4,Color.new(255,252,224,255))
      veil=Bitmap.new(Graphics.width,Graphics.height);a<<veil
      veil.fill_rect(0,0,Graphics.width,Graphics.height,Color.new(22,33,35,255))
      a
    rescue
      a.each { |b|b.dispose unless b.disposed? };raise
    end
  end
  CUES = [[0.07,["PRSFX- Stockpile","PRSFX- Calm Mind"],42,85],
          [0.49,["PRSFX- Meditate","PRSFX- Calm Mind"],45,105],
          [0.70,["PRSFX- Focus Energy","PRSFX- Bulk Up1"],58,115]]
  def self.sound(cue)
    _,names,volume,pitch=cue
    names.each do |name|
      next unless [".wav",".ogg",".mp3"].any? { |ext|File.file?("Audio/SE/Anim/#{name}#{ext}") }
      pbSEPlay("Anim/#{name}",volume,pitch);break
    end
  end
  module SceneHooks
    def pbAnimation(moveID,user,targets,hitNum=0)
      return super unless DeepBreathingVisual::MOVE_IDS.include?(moveID)
      return if @battle && !@battle.showAnims
      return if @deep_breathing_boxes
      targets=[user] if user && user.respond_to?(:index)
      entries=(targets.is_a?(Array) ? targets : [targets]).compact.select { |b|b.respond_to?(:index) }
      return super if entries.empty?
      entries=entries.uniq { |b|b.index }.select do |b|
        s=@sprites && @sprites["pokemon_#{b.index}"]
        s && !s.disposed? && s.bitmap &&
          !(b.respond_to?(:isCommander?) && b.isCommander?) &&
          !(s.respond_to?(:vanishMode) && s.vanishMode>0)
      end
      return if entries.empty?
      pbDeepBreathingVisual(user,entries)
    end
    def pbDeepBreathingHideHP
      return unless @deep_breathing_boxes && @sprites
      @sprites.each do |key,s|
        next unless key.to_s.start_with?("dataBox_") && s && !s.disposed?
        @deep_breathing_boxes[s.object_id]||=[s,s.visible];s.visible=false
      end
    end
    def pbGraphicsUpdate
      pbDeepBreathingHideHP if @deep_breathing_boxes
      super
    end
    def pbDeepBreathingVisual(user,targets)
      sprites,bitmaps,hidden=[],[],{}
      @deep_breathing_boxes={}
      begin
        @briefMessage=false;pbDeepBreathingHideHP
        bitmaps.concat(DeepBreathingVisual.assets)
        wind_b,puff_b,mote_b,halo_b,ring_b,dash_b,star_b,veil_b=bitmaps
        make=proc do |b,ox,oy,z|
          s=Sprite.new(@viewport);sprites<<s;s.bitmap,s.ox,s.oy,s.z=b,ox,oy,z;s.opacity=0;s
        end
        veil=make.call(veil_b,0,0,20_000)
        groups=targets.map do |b|
          src=@sprites["pokemon_#{b.index}"]
          cx=src.x+(src.src_rect.width/2.0-src.ox)*src.zoom_x
          cy=src.y+(src.src_rect.height*0.50-src.oy)*src.zoom_y
          size=[[(src.src_rect.height*src.zoom_y+35)/150.0,0.75].max,1.2].min
          bmp=src.bitmap.clone;bitmaps<<bmp;copy=make.call(bmp,src.ox,src.oy,20_006)
          copy.src_rect.set(src.src_rect.x,src.src_rect.y,src.src_rect.width,src.src_rect.height)
          copy.x,copy.y=src.x,src.y;copy.zoom_x,copy.zoom_y=src.zoom_x,src.zoom_y
          copy.mirror,copy.visible,copy.opacity=src.mirror,src.visible,src.opacity
          copy.color=src.color.clone;copy.tone=src.tone.clone if src.respond_to?(:tone)
          hidden[src.object_id]=[src,src.visible];src.visible=false
          {copy:copy,x:src.x,y:src.y,ox:src.ox,zx:src.zoom_x,zy:src.zoom_y,color:src.color.clone,
           cx:cx,cy:cy,size:size,ground:src.y+(src.src_rect.height-src.oy)*src.zoom_y,
           halo:make.call(halo_b,48,48,20_004),
           wind:Array.new(10) {make.call(wind_b,56,20,20_012)},
           breath:Array.new(6) {make.call(puff_b,32,32,20_011)},
           motes:Array.new(32) {make.call(mote_b,7,7,20_014)},
           dashes:Array.new(18) {make.call(dash_b,4,16,20_015)},
           stars:Array.new(8) {make.call(star_b,8,8,20_016)},
           rings:Array.new(2) {make.call(ring_b,72,72,20_010)}}
        end
        frames=[(Graphics.frame_rate*DeepBreathingVisual::DURATION).round,2].max;cue_index=0
        frames.times do |f|
          t=f.to_f/(frames-1)
          while cue_index<DeepBreathingVisual::CUES.size && t>=DeepBreathingVisual::CUES[cue_index][0]
            DeepBreathingVisual.sound(DeepBreathingVisual::CUES[cue_index]);cue_index+=1
          end
          env=[t/0.14,(1-t)/0.18,1].min;veil.opacity=(env*48).round
          inhale=t<0.46 ? Math.sin(t/0.46*Math::PI/2) : (t<0.62 ? 1 : [1-(t-0.62)/0.26,0].max)
          groups.each do |g|
            cx,cy,size=g.values_at(:cx,:cy,:size)
            copy=g[:copy]
            copy.zoom_x=g[:zx]*(1+inhale*0.022);copy.zoom_y=g[:zy]*(1+inhale*0.030)
            # Keep the body centre steady horizontally and its feet planted.
            copy.x=g[:x]-(cx-g[:x])*inhale*0.022
            copy.y=g[:y]
            focus=t>=0.62 ? Math.sin([[(t-0.62)/0.34,0].max,1].min*Math::PI) : 0
            copy.color=focus>0 ? Color.new(255,230,163,(focus*55).round) : g[:color]
            halo=g[:halo];halo.x,halo.y=cx,cy
            halo.zoom_x=size*(0.65+inhale*0.40+focus*0.40);halo.zoom_y=halo.zoom_x*1.15
            halo.opacity=(env*(inhale*80+focus*110)).round
            g[:wind].each_with_index do |s,i|
              if t<0.47
                p=(t-0.04-i%5*0.04)/0.26;side=i.even? ? -1 : 1
                r=(1-[[p,0].max,1].min)*82*size
                s.x=cx+side*r;s.y=cy+(i%5-2)*9*size+Math.sin([p,0].max*Math::PI)*8
                s.mirror=side>0;s.angle=side*(i%3-1)*9
                s.zoom_x=0.38+([p,0].max)*0.14;s.zoom_y=0.55
                s.opacity=p>=0 && p<=1 ? (Math.sin(p*Math::PI)*195).round : 0
              else
                p=(t-0.63-i%5*0.018)/0.25;a=i*Math::PI/5
                r=15+[p,0].max*65*size
                s.x=cx+Math.cos(a)*r;s.y=cy+Math.sin(a)*r*0.7
                s.angle=-a*180/Math::PI;s.zoom_x=0.36+[p,0].max*0.25;s.zoom_y=0.40
                s.opacity=p>=0 && p<=1 ? ((1-p)*140).round : 0
              end
            end
            g[:breath].each_with_index do |s,i|
              p=(t-0.63-i*0.023)/0.26
              side=cx<Graphics.width*0.5 ? 1 : -1
              s.x=cx+side*(12+[p,0].max*42);s.y=cy-14-[p,0].max*18+(i%2)*5
              s.zoom_x=(0.15+[p,0].max*0.55)*size;s.zoom_y=s.zoom_x*0.70
              s.opacity=p>=0 && p<=1 ? (Math.sin(p*Math::PI)*125).round : 0
            end
            g[:motes].each_with_index do |s,i|
              if t<0.55
                p=(t-0.02-i%8*0.027)/0.30;a=i*2.399
                r=(1-[[p,0].max,1].min)*(35+i%4*13)*size
                s.x=cx+Math.cos(a)*r;s.y=cy+Math.sin(a)*r*0.8
              else
                p=(t-0.64-i%4*0.022)/0.28;a=i*2.399
                r=10+[p,0].max*(20+i%4*14)*size
                s.x=cx+Math.cos(a)*r;s.y=cy+Math.sin(a)*r*0.7-[p,0].max*28
              end
              s.zoom_x=s.zoom_y=0.17+i%4*0.055
              s.opacity=p>=0 && p<=1 ? (Math.sin(p*Math::PI)*205).round : 0
            end
            g[:dashes].each_with_index do |s,i|
              p=(t-0.68-i%6*0.023)/0.22
              s.x=cx+(i%7-3)*12*size;s.y=g[:ground]-10-[p,0].max*(55+i%4*12)*size
              s.zoom_x=0.55;s.zoom_y=0.32+i%3*0.10
              s.opacity=p>=0 && p<=1 ? (Math.sin(p*Math::PI)*210).round : 0
            end
            g[:stars].each_with_index do |s,i|
              p=(t-0.66-i%4*0.03)/0.23;a=i*Math::PI/4
              s.x=cx+Math.cos(a)*(24+i%3*9)*size;s.y=cy+Math.sin(a)*(24+i%3*9)*size
              s.zoom_x=s.zoom_y=0.20+i%3*0.07;s.angle=i*29
              s.opacity=p>=0 && p<=1 ? (Math.sin(p*Math::PI)**2*225).round : 0
            end
            g[:rings].each_with_index do |s,i|
              p=(t-[0.12,0.67][i])/[0.40,0.25][i]
              s.x=cx;s.y=g[:ground]
              s.zoom_x=size*(i==0 ? 1.3-[[p,0].max,1].min*0.7 : 0.6+[p,0].max*0.9)
              s.zoom_y=s.zoom_x*0.23
              s.opacity=p>=0 && p<=1 ? (Math.sin(p*Math::PI)*145).round : 0
            end
          end
          hidden.each_value { |s,_|s.visible=false unless s.disposed? };pbUpdate
        end
      ensure
        boxes=@deep_breathing_boxes;@deep_breathing_boxes=nil
        boxes.each_value { |s,v|s.visible=v if s && !s.disposed? } if boxes
        hidden.each_value { |s,v|s.visible=v if s && !s.disposed? }
        sprites.reverse_each { |s|s.dispose unless s.disposed? }
        bitmaps.each { |b|b.dispose unless b.disposed? }
      end
    end
  end
end
Battle::Scene.prepend(DeepBreathingVisual::SceneHooks)
