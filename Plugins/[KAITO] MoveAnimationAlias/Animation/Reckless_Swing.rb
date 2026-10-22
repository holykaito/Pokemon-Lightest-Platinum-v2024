# Reckless Swing - Pokemon Essentials v21.1. Move ID RECKLESSSWING.
# Install in Plugins/[KAITO] Plugin/ and recompile.
# Heavy dark sweep, impact pause, knockback and visible recovery from the swing.
# Presentation only: native move owns damage, accuracy and recoil HP loss.
module RecklessSwingVisual
  VERSION = "1.0"
  MOVE_IDS = [:RECKLESSSWING]
  DURATION = 2.15
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
      swing=Bitmap.new(320,192);a<<swing
      [[30,[19,12,27,235]],[22,[57,24,48,240]],[13,[125,50,77,235]],[5,[214,128,143,240]],[1.5,[255,224,206,250]]].each do |width,col|
        l=[];r=[]
        96.times do |i|
          p=i/95.0;x=8+p*304;y=151-Math.sin(p*Math::PI)*103-p*39
          dx=304.0;dy=-Math.cos(p*Math::PI)*103*Math::PI-39
          len=Math.sqrt(dx*dx+dy*dy);nx,ny=-dy/len,dx/len
          half=Math.sin(p*Math::PI)**0.65*width
          l<<[x+nx*half,y+ny*half];r<<[x-nx*half,y-ny*half]
        end
        polygon(swing,l+r.reverse,Color.new(*col))
      end
      burst=Bitmap.new(176,176);a<<burst
      outline=Array.new(32) do |i|
        ang=i*Math::PI/16;r=i.even? ? 67+i%5*3 : 18+i%3*4
        [88+Math.cos(ang)*r,88+Math.sin(ang)*r]
      end
      [[1.0,[35,16,37,220]],[0.73,[156,66,92,235]],[0.38,[255,211,180,250]]].each do |size,col|
        polygon(burst,outline.map { |x,y|[88+(x-88)*size,88+(y-88)*size] },Color.new(*col))
      end
      chip=Bitmap.new(20,32);a<<chip
      polygon(chip,[[11,0],[18,10],[13,24],[4,31],[1,17]],Color.new(69,36,62,245))
      polygon(chip,[[11,2],[15,11],[8,23],[4,25],[6,13]],Color.new(205,117,141,240))
      line(chip,10,5,9,16,1,Color.new(255,213,199,240))
      dust=Bitmap.new(72,56);a<<dust
      [[34,26,23],[18,31,15],[52,29,17],[36,16,14]].each do |cx,cy,r|
        (-r..r).each do |y|
          half=Math.sqrt(r*r-y*y).floor
          dust.fill_rect(cx-half,cy+y,half*2+1,1,Color.new(120,94,104,85))
        end
      end
      ring=Bitmap.new(192,128);a<<ring
      180.times do |i|
        ang=i*Math::PI/90
        ring.fill_rect((96+Math.cos(ang)*88).round,(64+Math.sin(ang)*54).round,3,2,Color.new(224,161,177,200))
      end
      streak=Bitmap.new(160,12);a<<streak
      polygon(streak,[[0,6],[131,1],[159,6],[131,11]],Color.new(43,19,42,210))
      line(streak,25,6,149,6,2,Color.new(174,82,116,180))
      veil=Bitmap.new(Graphics.width,Graphics.height);a<<veil
      veil.fill_rect(0,0,Graphics.width,Graphics.height,Color.new(23,11,26,255))
      flash=Bitmap.new(Graphics.width,Graphics.height);a<<flash
      flash.fill_rect(0,0,Graphics.width,Graphics.height,Color.new(255,212,195,255))
      a
    rescue
      a.each { |b|b.dispose unless b.disposed? };raise
    end
  end
  CUES = [[0.07,["PRSFX- Hone Claws","PRSFX- Bulk Up1"],58,75],
          [0.30,["PRSFX- Brutal Swing2","PRSFX- Night Slash1"],80,75],
          [0.44,["PRSFX- Giga Impact2","PRSFX- Giga Impact1"],95,70],
          [0.58,["PRSFX- Rock Smash","PRSFX- Crunch"],70,75]]
  def self.sound(cue)
    _,names,volume,pitch=cue
    names.each do |name|
      next unless [".wav",".ogg",".mp3"].any? { |ext|File.file?("Audio/SE/Anim/#{name}#{ext}") }
      pbSEPlay("Anim/#{name}",volume,pitch);break
    end
  end
  module SceneHooks
    def pbAnimation(moveID,user,targets,hitNum=0)
      return super unless RecklessSwingVisual::MOVE_IDS.include?(moveID)
      return if @battle && !@battle.showAnims
      return if @reckless_swing_boxes
      entries=(targets.is_a?(Array) ? targets : [targets]).compact.select { |b|b.respond_to?(:index) }
      return super if entries.empty?
      entries=entries.uniq { |b|b.index }.select do |b|
        s=@sprites && @sprites["pokemon_#{b.index}"]
        s && !s.disposed? && s.bitmap &&
          !(b.respond_to?(:isCommander?) && b.isCommander?) &&
          !(s.respond_to?(:vanishMode) && s.vanishMode>0)
      end
      return if entries.empty?
      pbRecklessSwingVisual(user,entries)
    end
    def pbRecklessSwingHideHP
      return unless @reckless_swing_boxes && @sprites
      @sprites.each do |key,s|
        next unless key.to_s.start_with?("dataBox_") && s && !s.disposed?
        @reckless_swing_boxes[s.object_id]||=[s,s.visible];s.visible=false
      end
    end
    def pbGraphicsUpdate
      pbRecklessSwingHideHP if @reckless_swing_boxes
      super
    end
    def pbRecklessSwingVisual(user,targets)
      sprites,bitmaps,hidden=[],[],{}
      @reckless_swing_boxes={}
      view_state=(@viewport && @viewport.respond_to?(:ox)) ? [@viewport.ox,@viewport.oy] : nil
      begin
        @briefMessage=false;pbRecklessSwingHideHP
        bitmaps.concat(RecklessSwingVisual.assets)
        swing_b,burst_b,chip_b,dust_b,ring_b,streak_b,veil_b,flash_b=bitmaps
        make=proc do |b,ox,oy,z|
          s=Sprite.new(@viewport);sprites<<s;s.bitmap,s.ox,s.oy,s.z=b,ox,oy,z;s.opacity=0;s
        end
        snapshot=proc do |src,z|
          bmp=src.bitmap.clone;bitmaps<<bmp;s=make.call(bmp,src.ox,src.oy,z)
          s.src_rect.set(src.src_rect.x,src.src_rect.y,src.src_rect.width,src.src_rect.height)
          s.x,s.y=src.x,src.y;s.zoom_x,s.zoom_y=src.zoom_x,src.zoom_y
          s.mirror,s.visible,s.opacity=src.mirror,src.visible,src.opacity
          s.color=src.color.clone;s.tone=src.tone.clone if src.respond_to?(:tone)
          hidden[src.object_id]||=[src,src.visible];src.visible=false;s
        end
        src=user && user.respond_to?(:index) && @sprites["pokemon_#{user.index}"]
        src=nil if src && (src.disposed? || !src.bitmap)
        actor=nil;ghosts=[]
        if src && !targets.any? { |b|b.index==user.index }
          actor=snapshot.call(src,20_013);ax,ay=src.x,src.y
          acx=ax+(src.src_rect.width/2.0-src.ox)*src.zoom_x
          acy=ay+(src.src_rect.height/2.0-src.oy)*src.zoom_y
          ghosts=Array.new(3) do
            g=snapshot.call(src,20_011);g.color=Color.new(48,19,45,220);g
          end
          shadow=@sprites["shadow_#{user.index}"]
          hidden[shadow.object_id]=[shadow,shadow.visible] if shadow && !shadow.disposed?
        end
        veil=make.call(veil_b,0,0,20_000);flash=make.call(flash_b,0,0,20_040)
        groups=targets.map do |b|
          target=@sprites["pokemon_#{b.index}"];copy=snapshot.call(target,20_012)
          cx=target.x+(target.src_rect.width/2.0-target.ox)*target.zoom_x
          cy=target.y+(target.src_rect.height/2.0-target.oy)*target.zoom_y
          scale=[[(target.src_rect.height*target.zoom_y+100)/230.0,0.90].max,1.18].min
          {cx:cx,cy:cy,x:target.x,y:target.y,scale:scale,copy:copy,color:target.color.clone,
           ground:target.y+(target.src_rect.height-target.oy)*target.zoom_y,
           swing:make.call(swing_b,160,70,20_025),echo:make.call(swing_b,160,70,20_021),
           burst:make.call(burst_b,88,88,20_029),
           chips:Array.new(64) {make.call(chip_b,10,16,20_031)},
           dust:Array.new(14) {make.call(dust_b,36,28,20_028)},
           streaks:Array.new(12) {make.call(streak_b,0,6,20_024)},
           rings:Array.new(3) {make.call(ring_b,96,64,20_026)}}
        end
        frames=[(Graphics.frame_rate*RecklessSwingVisual::DURATION).round,2].max;cue_index=0
        frames.times do |f|
          real_t=f.to_f/(frames-1)
          # A short visual hold gives the contact weight without pausing scene updates.
          t=if real_t<0.44;real_t
            elsif real_t<0.49;0.44
            else;0.44+(real_t-0.49)*0.56/0.51;end
          while cue_index<RecklessSwingVisual::CUES.size && t>=RecklessSwingVisual::CUES[cue_index][0]
            RecklessSwingVisual.sound(RecklessSwingVisual::CUES[cue_index]);cue_index+=1
          end
          env=[real_t/0.14,(1-real_t)/0.18,1].min
          veil.opacity=(env*(80+(t>=0.44 ? 30 : 0))).round
          p=(t-0.44)/0.32;intensity=p>=0 && p<=1 ? (1-p)**1.4 : 0
          flash.opacity=real_t>=0.44 && real_t<0.49 ? (((0.49-real_t)/0.05)*90).round : 0
          shake=intensity*10
          if view_state
            @viewport.ox=view_state[0]+(Math.sin(f*2.5)*shake).round
            @viewport.oy=view_state[1]+(Math.cos(f*2.9)*shake*0.60).round
          end
          if actor
            gx,gy=groups[0].values_at(:cx,:cy);direction=gx>=acx ? 1 : -1
            wind=t<0.26 ? Math.sin(t/0.26*Math::PI)*-12 : 0
            lunge=if t<0.26;0
                  elsif t<0.44;(t-0.26)/0.18
                  elsif t<0.61;1
                  else;[1-(t-0.61)/0.29,0].max;end
            actor.x=ax+direction*wind+(gx-acx)*0.40*lunge
            actor.y=ay+(gy-acy)*0.13*lunge
            actor.angle=direction*(t<0.26 ? Math.sin(t/0.26*Math::PI)*8 : -Math.sin(lunge*Math::PI/2)*7)
            if t>=0.64 && t<0.88
              recoil=Math.sin((t-0.64)/0.24*Math::PI)
              actor.x-=direction*recoil*9;actor.y+=recoil*3
            end
            ghosts.each_with_index do |g,i|
              g.x=actor.x-direction*(i+1)*14;g.y=actor.y
              g.angle=actor.angle;g.opacity=t>=0.29 && t<0.60 ? (75-i*18) : 0
            end
          end
          groups.each do |g|
            cx,cy,scale=g.values_at(:cx,:cy,:scale)
            direction=actor ? (cx>=acx ? 1 : -1) : 1
            q=(t-0.32)/0.30
            sweep=g[:swing];sweep.x=cx+direction*([q,0].max-0.35)*58*scale
            sweep.y=cy+([q,0].max-0.35)*8*scale;sweep.angle=direction*(-8);sweep.mirror=direction<0
            sweep.zoom_x=scale*(0.75+[[q/0.22,0].max,1].min*0.52);sweep.zoom_y=scale*1.0
            sweep.opacity=q>=0 && q<=1 ? ((1-q)**0.40*255).round : 0
            echo=g[:echo];echo.x,echo.y=sweep.x-direction*12,sweep.y+8
            echo.zoom_x,echo.zoom_y=sweep.zoom_x*1.03,sweep.zoom_y*0.90
            echo.angle=sweep.angle;echo.mirror=sweep.mirror
            echo.opacity=q>=0 && q<=1 ? ((1-q)*75).round : 0
            burst=g[:burst];burst.x,burst.y=cx,cy
            burst.zoom_x=scale*(0.28+[[p,0].max,1].min*1.8);burst.zoom_y=burst.zoom_x*0.82;burst.angle=13
            burst.opacity=p>=0 && p<=1 ? ((1-p)**1.8*235).round : 0
            knock=t>=0.44 ? Math.sin([[p,0].max,1].min*Math::PI)*19 : 0
            g[:copy].x=g[:x]+direction*knock+Math.sin(f*2.7)*intensity*6
            g[:copy].y=g[:y]-knock*0.28
            g[:copy].angle=-direction*intensity*5
            g[:copy].color=intensity>0 ? Color.new(255,199,197,(intensity*150).round) : g[:color]
            g[:chips].each_with_index do |s,i|
              q=(t-0.44-i%5*0.012)/0.43;a=i*2.399
              r=10+[q,0].max*(80+i%6*22)*scale
              s.x=cx+Math.cos(a)*r+direction*[q,0].max*25
              s.y=cy+Math.sin(a)*r*0.66+[q,0].max**2*55
              s.zoom_x=scale*(0.20+i%5*0.09);s.zoom_y=s.zoom_x
              s.angle=i*31+[q,0].max*190
              s.opacity=q>=0 && q<=1 ? ((1-q)**0.6*245).round : 0
            end
            g[:dust].each_with_index do |s,i|
              q=(t-0.45-i%3*0.022)/0.44
              side=i.even? ? 1 : -1
              s.x=cx+side*(15+[q,0].max*(60+i%4*25))*scale
              s.y=g[:ground]-8-[q,0].max*(12+i%3*11)
              s.zoom_x=0.3+[q,0].max*1.6;s.zoom_y=s.zoom_x*0.64
              s.opacity=q>=0 && q<=1 ? (Math.sin(q*Math::PI)*190).round : 0
            end
            g[:streaks].each_with_index do |s,i|
              q=(t-0.44)/0.19;a=i*Math::PI/6+0.1
              s.x,s.y=cx,cy;s.angle=-a*180/Math::PI
              s.zoom_x=0.4+[q,0].max*(0.9+i%3*0.2);s.zoom_y=0.5
              s.opacity=q>=0 && q<=1 ? ((1-q)*185).round : 0
            end
            g[:rings].each_with_index do |s,i|
              q=(t-0.44-i*0.06)/0.24
              s.x=cx;s.y=i==0 ? cy : g[:ground]
              s.zoom_x=scale*(0.3+[q,0].max*2.0);s.zoom_y=s.zoom_x*(i==0 ? 0.8 : 0.35)
              s.opacity=q>=0 && q<=1 ? ((1-q)**0.7*195).round : 0
            end
          end
          hidden.each_value { |s,_|s.visible=false unless s.disposed? };pbUpdate
        end
      ensure
        @viewport.ox,@viewport.oy=view_state if view_state
        boxes=@reckless_swing_boxes;@reckless_swing_boxes=nil
        boxes.each_value { |s,v|s.visible=v if s && !s.disposed? } if boxes
        hidden.each_value { |s,v|s.visible=v if s && !s.disposed? }
        sprites.reverse_each { |s|s.dispose unless s.disposed? }
        bitmaps.each { |b|b.dispose unless b.disposed? }
      end
    end
  end
end
Battle::Scene.prepend(RecklessSwingVisual::SceneHooks)
