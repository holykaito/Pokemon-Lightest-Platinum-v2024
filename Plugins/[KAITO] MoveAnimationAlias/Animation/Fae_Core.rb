# Fae Core v3 - Pokemon Essentials v21.1. Move ID FAECORE.
# Install in Plugins/[KAITO] Plugin/ and recompile; replace the old version.
# Pure particles: luminous dust condenses on charge, then blossoms into a fairy nova.
# hitNum 1 = charge, hitNum 0 = attack. No trapping, damage or stat hooks.
module FaeCoreVisual
  VERSION = "3.0"
  MOVE_IDS = [:FAECORE]
  CHARGE_DURATION = 2.65
  ATTACK_DURATION = 3.30
  # Pixel soft glow, with no opaque rim or geometric shell.
  def self.glow(size,rgb,alpha)
    b=Bitmap.new(size,size)
    begin
      centre=(size-1)/2.0
      size.times do |y|
        size.times do |x|
          r=((x-centre)**2+(y-centre)**2)/(centre*centre)
          next if r>1
          a=((Math.exp(-r*4.8)-Math.exp(-4.8))/(1-Math.exp(-4.8))*alpha).round
          next if a<1
          hot=[1-r*5,0].max
          col=rgb.map { |c|(c+(255-c)*hot*0.65).round }
          b.fill_rect(x,y,1,1,Color.new(*col,a))
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
      [[255,146,211],[255,221,162],[202,163,255]].each { |c|a<<glow(24,c,245) }
      star=Bitmap.new(16,16);a<<star
      (0..14).each do |i|
        strength=(1-(i-7).abs/8.0)
        star.fill_rect(7,i,2,1,Color.new(255,237,249,(strength*235).round))
        star.fill_rect(i,7,1,2,Color.new(255,237,249,(strength*235).round))
      end
      star.fill_rect(6,6,4,4,Color.new(255,251,233,255))
      tail=Bitmap.new(28,8);a<<tail
      26.times do |x|
        6.times do |y|
          alpha=(Math.sin((x+1)/27.0*Math::PI)**0.65*Math.sin((y+1)/7.0*Math::PI)*150).round
          tail.fill_rect(x+1,y+1,1,1,Color.new(255,193,230,alpha))
        end
      end
      [[255,131,201],[206,148,255],[255,220,166]].each { |c|a<<glow(96,c,82) }
      veil=Bitmap.new(Graphics.width,Graphics.height);a<<veil
      veil.fill_rect(0,0,Graphics.width,Graphics.height,Color.new(24,14,39,255))
      flash=Bitmap.new(Graphics.width,Graphics.height);a<<flash
      flash.fill_rect(0,0,Graphics.width,Graphics.height,Color.new(255,226,241,255))
      a
    rescue
      a.each { |b|b.dispose unless b.disposed? };raise
    end
  end
  CHARGE_CUES = [[0.06,["PRSFX- Fairy Lock","PRSFX- Calm Mind"],65,85],
                 [0.35,["PRSFX- Geomancy","PRSFX- Moonblast1"],65,90],
                 [0.72,["PRSFX- Geomancy","PRSFX- Moonblast2"],75,85]]
  ATTACK_CUES = [[0.04,["PRSFX- Moonblast1","PRSFX- Psychic"],70,75],
                 [0.24,["PRSFX- Geomancy","PRSFX- Moonblast2"],80,90],
                 [0.38,["PRSFX- Explosion","PRSFX- Dazzling Gleam","PRSFX- Moonblast2"],95,75],
                 [0.65,["PRSFX- Fairy Wind","PRSFX- Dazzling Gleam"],75,85]]
  def self.sound(cue)
    _,names,volume,pitch=cue
    names.each do |name|
      next unless [".wav",".ogg",".mp3"].any? { |ext|File.file?("Audio/SE/Anim/#{name}#{ext}") }
      pbSEPlay("Anim/#{name}",volume,pitch);break
    end
  end
  module SceneHooks
    def pbAnimation(moveID,user,targets,hitNum=0)
      return super unless FaeCoreVisual::MOVE_IDS.include?(moveID)
      return if @battle && !@battle.showAnims
      return if @fae_core_boxes
      entries=(targets.is_a?(Array) ? targets : [targets]).compact.select { |b|b.respond_to?(:index) }
      return super if entries.empty?
      entries=entries.uniq { |b|b.index }.select do |b|
        s=@sprites && @sprites["pokemon_#{b.index}"]
        s && !s.disposed? && s.bitmap &&
          !(b.respond_to?(:isCommander?) && b.isCommander?) &&
          !(s.respond_to?(:vanishMode) && s.vanishMode>0)
      end
      return if entries.empty?
      pbFaeCoreVisual(user,entries,hitNum==1)
    end
    def pbFaeCoreHideHP
      return unless @fae_core_boxes && @sprites
      @sprites.each do |key,s|
        next unless key.to_s.start_with?("dataBox_") && s && !s.disposed?
        @fae_core_boxes[s.object_id]||=[s,s.visible];s.visible=false
      end
    end
    def pbGraphicsUpdate
      pbFaeCoreHideHP if @fae_core_boxes
      super
    end
    def pbFaeCoreVisual(user,targets,charging)
      sprites,bitmaps,hidden=[],[],{}
      @fae_core_boxes={}
      view_state=(@viewport && @viewport.respond_to?(:ox)) ? [@viewport.ox,@viewport.oy] : nil
      begin
        @briefMessage=false;pbFaeCoreHideHP
        bitmaps.concat(FaeCoreVisual.assets)
        make=proc do |b,ox,oy,z,blend=0|
          s=Sprite.new(@viewport);sprites<<s;s.bitmap,s.ox,s.oy,s.z=b,ox,oy,z
          s.blend_type=blend;s.opacity=0;s
        end
        veil=make.call(bitmaps[8],0,0,20_000)
        flash=make.call(bitmaps[9],0,0,20_040)
        ambient=Array.new(36) { |i|make.call(bitmaps[i%3],12,12,20_004)}
        groups=targets.map do |b|
          src=@sprites["pokemon_#{b.index}"]
          cx=src.x+(src.src_rect.width/2.0-src.ox)*src.zoom_x
          cy=src.y+(src.src_rect.height/2.0-src.oy)*src.zoom_y
          copy=nil
          unless charging
            bmp=src.bitmap.clone;bitmaps<<bmp;copy=make.call(bmp,src.ox,src.oy,20_006)
            copy.src_rect.set(src.src_rect.x,src.src_rect.y,src.src_rect.width,src.src_rect.height)
            copy.x,copy.y=src.x,src.y;copy.zoom_x,copy.zoom_y=src.zoom_x,src.zoom_y
            copy.mirror,copy.visible,copy.opacity=src.mirror,src.visible,src.opacity
            copy.color=src.color.clone;copy.tone=src.tone.clone if src.respond_to?(:tone)
            hidden[src.object_id]=[src,src.visible];src.visible=false
          end
          {cx:cx,cy:cy,x:src.x,y:src.y,copy:copy,color:src.color.clone,
           motes:Array.new(400) { |i|make.call(bitmaps[i%3],12,12,20_014)},
           tails:Array.new(80) {make.call(bitmaps[4],14,4,20_011)},
           glints:Array.new(24) {make.call(bitmaps[3],8,8,20_018)},
           dust:Array.new(21) { |i|make.call(bitmaps[5+i%3],48,48,20_009,1)}}
        end
        cues=charging ? FaeCoreVisual::CHARGE_CUES : FaeCoreVisual::ATTACK_CUES
        duration=charging ? FaeCoreVisual::CHARGE_DURATION : FaeCoreVisual::ATTACK_DURATION
        frames=[(Graphics.frame_rate*duration).round,2].max;cue_index=0
        w,h=Graphics.width.to_f,Graphics.height.to_f
        diagonal=Math.sqrt(w*w+h*h);screen_scale=[w/512.0,h/384.0].min
        frames.times do |f|
          t=f.to_f/(frames-1)
          while cue_index<cues.size && t>=cues[cue_index][0]
            FaeCoreVisual.sound(cues[cue_index]);cue_index+=1
          end
          fade=[[(1-t)/0.20,0].max,1].min
          appear=[t/0.12,1].min
          blast=[[(t-0.38)/0.62,0].max,1].min
          veil.opacity=(appear*fade*(charging ? 115 : 145)).round
          flash.opacity=!charging && t>=0.38 && t<0.48 ? ((1-(t-0.38)/0.10)*155).round : 0
          shake=!charging && t>=0.38 ? (1-blast)**2*9 : 0
          if view_state
            @viewport.ox=view_state[0]+(Math.sin(f*2.4)*shake).round
            @viewport.oy=view_state[1]+(Math.cos(f*2.7)*shake*0.55).round
          end
          ambient.each_with_index do |s,i|
            s.x=(i*137.51+t*(i.even? ? 12 : -12))%w
            s.y=((i*83.23)-t*32)%h
            s.zoom_x=s.zoom_y=(0.12+i%4*0.055)*screen_scale
            s.opacity=(appear*fade*(0.4+Math.sin(t*7+i).abs*0.6)*130).round
          end
          groups.each do |g|
            cx,cy=g.values_at(:cx,:cy)
            packed=charging ? 1-(1-t)**2 : 1
            compression=charging ? 0 : [t/0.38,1].min
            g[:motes].each_with_index do |s,i|
              lane=i%3;seed=i*2.399963
              if charging || t<0.38
                # Overlapping orbits form a porous nucleus, surrounded by inward spirals.
                if i<160
                  a=seed+t*(2.4+lane*0.65)
                  radius=(4+((i*37)%161)/160.0*66)*(charging ? 0.25+packed*0.75 : 1-compression**2*0.84)
                  z=Math.sin(seed*1.7+t*3)
                  x=cx+Math.cos(a)*radius
                  y=cy+Math.sin(a)*radius*(0.62+0.20*z)
                  opacity=appear*fade*(170+z*50)
                else
                  q=charging ? (t*1.65+i*0.047)%1 : [[t/0.38+(i%13)*0.014,0].max,1].min
                  a=seed-q*2.4
                  radius=(1-q)**1.35*(diagonal*0.55)+8
                  x=cx+Math.cos(a)*radius;y=cy+Math.sin(a)*radius*0.72
                  opacity=Math.sin(q*Math::PI)**0.45*appear*fade*225
                end
                size=(0.30+i%6*0.095)*(i<160 ? 0.85+packed*0.25 : 0.8)
              else
                # Successive particle fronts travel at different speeds; there is no solid shell.
                start=0.38+(i%7)*0.012
                q=(t-start)/(0.49+(i%5)*0.025)
                q0=[[q,0].max,1].min
                a=seed+Math.sin(q0*3+lane)*q0*0.48
                reach=(230+(i*47)%510)*screen_scale
                radius=4+q0**0.72*reach
                curl=Math.sin(q0*8+i)*q0*15
                x=cx+Math.cos(a)*radius-Math.sin(a)*curl
                y=cy+Math.sin(a)*radius*0.78+Math.cos(a)*curl+q0*q0*48
                opacity=q>=0 && q<=1 ? (1-q0)**0.48*fade*250 : 0
                size=(0.32+i%7*0.12)*(1-q0*0.35)
              end
              s.x,s.y=x,y;s.zoom_x=s.zoom_y=size*screen_scale
              s.opacity=opacity.round;s.angle=0
              if i<80
                tail=g[:tails][i]
                tail.x,tail.y=x,y
                theta=Math.atan2(y-cy,x-cx)
                tail.angle=-theta*180/Math::PI
                tail.zoom_x=(charging || t<0.38) ? 0.24 : 0.32+(1-blast)*0.85
                tail.zoom_y=0.25+i%3*0.08
                tail.opacity=(opacity*((charging || t<0.38) ? 0.28 : 0.52)).round
              end
            end
            g[:dust].each_with_index do |s,i|
              a=i*2.399+t*0.45
              if charging || t<0.38
                r=(12+i%4*8)*(charging ? packed : 1-compression*0.88)
                s.x=cx+Math.cos(a)*r;s.y=cy+Math.sin(a)*r*0.7
                size=(0.45+i%3*0.18)*(charging ? packed : 1-compression*0.75)
                s.opacity=(appear*fade*(charging ? 70 : 85)).round
              else
                q=(t-0.38-i%3*0.018)/0.57;q0=[[q,0].max,1].min
                r=q0**0.65*(65+i%5*39)
                s.x=cx+Math.cos(a)*r;s.y=cy+Math.sin(a)*r*0.70+q0*q0*25
                size=0.5+q0*(2.1+i%3*0.45)
                s.opacity=q>=0 && q<=1 ? ((1-q0)**1.5*fade*190).round : 0
              end
              if !charging && t>=0.38 && i<3
                q=[[(t-0.38)/0.45,0].max,1].min
                s.x,s.y=cx,cy;size=0.65+q*5.2
                s.opacity=((1-q)**1.8*fade*170).round
              end
              s.zoom_x=size*screen_scale;s.zoom_y=s.zoom_x*0.85
            end
            g[:glints].each_with_index do |s,i|
              a=i*2.399+t*1.5
              q=(t*1.7+i*0.073)%1
              r=(charging || t<0.38) ? (15+q*45)*(1-compression*0.86) : 20+blast*(80+i%6*42)
              s.x=cx+Math.cos(a)*r;s.y=cy+Math.sin(a)*r*0.8
              s.zoom_x=s.zoom_y=(0.18+i%3*0.08)*screen_scale
              s.angle=i*17+t*70
              s.opacity=(Math.sin(q*Math::PI)**3*appear*fade*((charging || t<0.38) ? 185 : (1-blast)*230)).round
            end
            if g[:copy]
              g[:copy].x=g[:x]+Math.sin(f*2.3)*shake*0.45
              g[:copy].y=g[:y]+Math.cos(f*2.7)*shake*0.25
              g[:copy].color=t>=0.38 && t<0.64 ? Color.new(255,222,244,((0.64-t)/0.26*150).round) : g[:color]
            end
          end
          hidden.each_value { |s,_|s.visible=false unless s.disposed? };pbUpdate
        end
      ensure
        @viewport.ox,@viewport.oy=view_state if view_state
        boxes=@fae_core_boxes;@fae_core_boxes=nil
        boxes.each_value { |s,v|s.visible=v if s && !s.disposed? } if boxes
        hidden.each_value { |s,v|s.visible=v if s && !s.disposed? }
        sprites.reverse_each { |s|s.dispose unless s.disposed? }
        bitmaps.each { |b|b.dispose unless b.disposed? }
      end
    end
  end
end
Battle::Scene.prepend(FaeCoreVisual::SceneHooks)
