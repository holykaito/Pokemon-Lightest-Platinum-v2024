# Pixie Slash - Pokemon Essentials v21.1. Move ID PIXIESLASH.
# Install in Plugins/[KAITO] Plugin/ and recompile.
# A sweeping fairy blade with a sharp white edge, rose afterglow and pixie dust.
# Target-only diagonal slash; no projectile or user movement.
# Presentation only: original move handles contact, damage and critical hits.
module PixieSlashVisual
  VERSION = "1.1"
  MOVE_IDS = [:PIXIESLASH]
  DURATION = 1.05
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
      blade=Bitmap.new(256,128);a<<blade
      [[15,[169,56,133,100]],[9,[235,101,181,190]],[4.6,[255,194,223,245]],[1.7,[255,251,225,255]]].each do |width,col|
        left=[];right=[]
        80.times do |i|
          p=i/79.0;x=12+p*231;y=102-Math.sin(p*Math::PI)*74-p*20
          dx=231.0;dy=-Math.cos(p*Math::PI)*74*Math::PI-20
          length=Math.sqrt(dx*dx+dy*dy);nx,ny=-dy/length,dx/length
          thick=Math.sin(p*Math::PI)**0.85*width
          left<<[x+nx*thick,y+ny*thick];right<<[x-nx*thick,y-ny*thick]
        end
        polygon(blade,left+right.reverse,Color.new(*col))
      end
      star=Bitmap.new(20,20);a<<star
      polygon(star,[[10,0],[12,7],[19,10],[12,12],[10,19],[7,12],[0,10],[7,7]],Color.new(255,209,236,240))
      star.fill_rect(8,8,4,4,Color.new(255,252,222,255))
      mote=Bitmap.new(12,12);a<<mote
      12.times do |y|
        12.times do |x|
          r=((x-5.5)**2+(y-5.5)**2)/30.25;next if r>1
          alpha=((Math.exp(-r*4)-Math.exp(-4))/(1-Math.exp(-4))*240).round
          mote.fill_rect(x,y,1,1,Color.new(255,183,221,alpha))
        end
      end
      petal=Bitmap.new(18,30);a<<petal
      polygon(petal,[[8,1],[15,7],[16,15],[10,27],[5,29],[2,19],[1,10]],Color.new(218,116,180,225))
      polygon(petal,[[8,3],[12,8],[12,16],[6,25],[4,18],[4,10]],Color.new(255,218,226,245))
      halo=Bitmap.new(96,96);a<<halo
      96.times do |y|
        96.times do |x|
          r=((x-47.5)**2+(y-47.5)**2)/2256.25;next if r>1
          alpha=((Math.exp(-r*4)-Math.exp(-4))/(1-Math.exp(-4))*55).round
          halo.fill_rect(x,y,1,1,Color.new(255,169,220,alpha)) if alpha>0
        end
      end
      streak=Bitmap.new(128,8);a<<streak
      polygon(streak,[[0,4],[108,1],[127,4],[108,7]],Color.new(255,219,230,170))
      veil=Bitmap.new(Graphics.width,Graphics.height);a<<veil
      veil.fill_rect(0,0,Graphics.width,Graphics.height,Color.new(36,20,37,255))
      a
    rescue
      a.each { |b|b.dispose unless b.disposed? };raise
    end
  end
  CUES = [[0.44,["PRSFX- Psycho Cut","PRSFX- Slash"],65,125],
          [0.45,["PRSFX- Slash","PRSFX- Psycho Cut"],78,125],
          [0.59,["PRSFX- Fairy Wind","PRSFX- Dazzling Gleam"],45,135]]
  def self.sound(cue)
    _,names,volume,pitch=cue
    names.each do |name|
      next unless [".wav",".ogg",".mp3"].any? { |ext|File.file?("Audio/SE/Anim/#{name}#{ext}") }
      pbSEPlay("Anim/#{name}",volume,pitch);break
    end
  end
  module SceneHooks
    def pbAnimation(moveID,user,targets,hitNum=0)
      return super unless PixieSlashVisual::MOVE_IDS.include?(moveID)
      return if @battle && !@battle.showAnims
      return if @pixie_slash_boxes
      entries=(targets.is_a?(Array) ? targets : [targets]).compact.select { |b|b.respond_to?(:index) }
      return super if entries.empty?
      entries=entries.uniq { |b|b.index }.select do |b|
        s=@sprites && @sprites["pokemon_#{b.index}"]
        s && !s.disposed? && s.bitmap &&
          !(b.respond_to?(:isCommander?) && b.isCommander?) &&
          !(s.respond_to?(:vanishMode) && s.vanishMode>0)
      end
      return if entries.empty?
      pbPixieSlashVisual(user,entries)
    end
    def pbPixieSlashHideHP
      return unless @pixie_slash_boxes && @sprites
      @sprites.each do |key,s|
        next unless key.to_s.start_with?("dataBox_") && s && !s.disposed?
        @pixie_slash_boxes[s.object_id]||=[s,s.visible];s.visible=false
      end
    end
    def pbGraphicsUpdate
      pbPixieSlashHideHP if @pixie_slash_boxes
      super
    end
    def pbPixieSlashVisual(user,targets)
      sprites,bitmaps,hidden=[],[],{}
      @pixie_slash_boxes={}
      begin
        @briefMessage=false;pbPixieSlashHideHP
        bitmaps.concat(PixieSlashVisual.assets)
        blade_b,star_b,mote_b,petal_b,halo_b,streak_b,veil_b=bitmaps
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
        groups=targets.map do |b|
          target=@sprites["pokemon_#{b.index}"];copy=snapshot.call(target)
          cx=target.x+(target.src_rect.width/2.0-target.ox)*target.zoom_x
          cy=target.y+(target.src_rect.height*0.5-target.oy)*target.zoom_y
          scale=[[(target.src_rect.height*target.zoom_y+70)/210.0,0.72].max,1.08].min
          {copy:copy,x:target.x,y:target.y,color:target.color.clone,cx:cx,cy:cy,scale:scale,
           blade:make.call(blade_b,128,48,20_020),echo:make.call(blade_b,128,48,20_017),
           halo:make.call(halo_b,48,48,20_009),
           motes:Array.new(70) {make.call(mote_b,6,6,20_024)},
           petals:Array.new(14) {make.call(petal_b,9,15,20_025)},
           stars:Array.new(16) {make.call(star_b,10,10,20_027)},
           rays:Array.new(8) {make.call(streak_b,0,4,20_019)}}
        end
        frames=[(Graphics.frame_rate*PixieSlashVisual::DURATION).round,2].max;cue_index=0
        frames.times do |f|
          t=0.43+0.57*f.to_f/(frames-1)
          while cue_index<PixieSlashVisual::CUES.size && t>=PixieSlashVisual::CUES[cue_index][0]
            PixieSlashVisual.sound(PixieSlashVisual::CUES[cue_index]);cue_index+=1
          end
          veil.opacity=([t/0.12,(1-t)/0.20,1].min*52).round
          groups.each do |g|
            cx,cy,scale=g.values_at(:cx,:cy,:scale)
            direction=cx>=sx ? 1 : -1
            p=(t-0.45)/0.26
            blade=g[:blade];blade.x=cx+direction*([p,0].max-0.35)*30*scale
            blade.y=cy-([p,0].max-0.35)*15*scale
            blade.angle=direction*(-36);blade.mirror=direction<0
            blade.zoom_x=scale*(0.65+[[p/0.18,0].max,1].min*0.50);blade.zoom_y=scale*1.05
            blade.opacity=p>=0 && p<=1 ? ((1-p)**0.65*255).round : 0
            q=(t-0.48)/0.24
            echo=g[:echo];echo.x,echo.y=blade.x,blade.y;echo.angle=blade.angle;echo.mirror=direction<0
            echo.zoom_x=scale*1.12;echo.zoom_y=scale*0.70
            echo.opacity=q>=0 && q<=1 ? ((1-q)*80).round : 0
            halo=g[:halo];halo.x,halo.y=cx,cy;halo.zoom_x=halo.zoom_y=0.7+[[p,0].max,1].min*2.1
            halo.opacity=p>=0 && p<=1 ? ((1-p)*200).round : 0
            shake=p>=0 && p<=1 ? (1-p)*5 : 0
            g[:copy].x=g[:x]+Math.sin(f*2.7)*shake;g[:copy].y=g[:y]+Math.cos(f*2.3)*shake*0.3
            g[:copy].color=t>=0.45 && t<0.55 ? Color.new(255,215,235,((0.55-t)/0.10*125).round) : g[:color]
            g[:motes].each_with_index do |s,i|
              q=(t-0.46-i%7*0.008)/0.42;a=i*2.399
              r=8+[q,0].max*(40+i%6*15)
              along=(i%11-5)*9*scale
              s.x=cx+along+Math.cos(a)*r*scale
              s.y=cy-along*0.55+Math.sin(a)*r*scale*0.65+[q,0].max**2*32
              s.zoom_x=s.zoom_y=0.20+i%4*0.09
              s.opacity=q>=0 && q<=1 ? ((1-q)**0.5*245).round : 0
            end
            g[:petals].each_with_index do |s,i|
              q=(t-0.49-i%4*0.012)/0.43;a=i*2.399
              r=10+[q,0].max*(35+i%4*19)
              s.x=cx+Math.cos(a)*r;s.y=cy+Math.sin(a)*r*0.6+[q,0].max**2*45
              s.zoom_x=0.20+i%3*0.08;s.zoom_y=s.zoom_x*1.10;s.angle=i*23+[q,0].max*150
              s.opacity=q>=0 && q<=1 ? (Math.sin(q*Math::PI)**0.6*220).round : 0
            end
            g[:stars].each_with_index do |s,i|
              q=(t-0.48-i%4*0.028)/0.25;a=i*2.399;r=10+[q,0].max*65
              s.x=cx+Math.cos(a)*r;s.y=cy+Math.sin(a)*r*0.7
              s.zoom_x=s.zoom_y=0.15+i%3*0.10;s.angle=i*31+t*90
              s.opacity=q>=0 && q<=1 ? (Math.sin(q*Math::PI)**2*240).round : 0
            end
            g[:rays].each_with_index do |s,i|
              q=(t-0.45)/0.12;a=i*Math::PI/4+0.3
              s.x,s.y=cx,cy;s.angle=-a*180/Math::PI
              s.zoom_x=0.3+[q,0].max*0.45;s.zoom_y=0.35
              s.opacity=q>=0 && q<=1 ? ((1-q)*145).round : 0
            end
          end
          hidden.each_value { |s,_|s.visible=false unless s.disposed? };pbUpdate
        end
      ensure
        boxes=@pixie_slash_boxes;@pixie_slash_boxes=nil
        boxes.each_value { |s,v|s.visible=v if s && !s.disposed? } if boxes
        hidden.each_value { |s,v|s.visible=v if s && !s.disposed? }
        sprites.reverse_each { |s|s.dispose unless s.disposed? }
        bitmaps.each { |b|b.dispose unless b.disposed? }
      end
    end
  end
end
Battle::Scene.prepend(PixieSlashVisual::SceneHooks)
