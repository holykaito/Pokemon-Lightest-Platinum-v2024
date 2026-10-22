# Nectar Siphon - Pokemon Essentials v21.1.
# Install in Plugins/[KAITO] Plugin/ and recompile. Move ID NECTARSIPHON.
# Amber nectar extraction, braided suction streams, soft absorption bloom.
# Presentation only: damage and healing are handled by the original move.
module NectarSiphonVisual
  VERSION = "1.0"
  MOVE_IDS = [:NECTARSIPHON]
  DURATION = 2.50
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
      drop=Bitmap.new(24,34);a<<drop
      polygon(drop,[[12,1],[15,9],[21,19],[22,25],[18,31],[10,33],[3,28],[2,21],[7,11]],Color.new(138,74,30,245))
      polygon(drop,[[12,4],[16,15],[20,22],[18,28],[11,30],[5,26],[5,20]],Color.new(245,170,49,255))
      polygon(drop,[[11,8],[14,16],[17,22],[15,26],[10,27],[7,23],[8,18]],Color.new(255,217,99,255))
      drop.fill_rect(8,18,3,6,Color.new(255,249,197,255));drop.fill_rect(11,16,2,3,Color.new(255,249,197,230))
      trail=Bitmap.new(28,8);a<<trail
      26.times do |x|
        alpha=(Math.sin(x/25.0*Math::PI)*135).round
        trail.fill_rect(x+1,2,1,4,Color.new(227,140,52,alpha))
        trail.fill_rect(x+1,3,1,2,Color.new(255,225,133,alpha))
      end
      petal=Bitmap.new(20,30);a<<petal
      polygon(petal,[[10,1],[16,6],[18,14],[13,24],[7,29],[3,20],[2,11],[5,4]],Color.new(217,106,126,235))
      polygon(petal,[[9,3],[14,7],[15,14],[9,24],[6,25],[5,14]],Color.new(255,192,157,250))
      line(petal,9,8,8,24,1,Color.new(255,230,179,220))
      ring=Bitmap.new(128,128);a<<ring
      160.times do |i|
        ang=i*Math::PI/80
        ring.fill_rect((64+Math.cos(ang)*54).round,(64+Math.sin(ang)*54).round,2,2,Color.new(250,201,107,205))
      end
      glint=Bitmap.new(20,20);a<<glint
      polygon(glint,[[10,0],[12,7],[19,10],[12,12],[10,19],[7,12],[0,10],[7,7]],Color.new(255,232,158,240))
      glint.fill_rect(8,8,4,4,Color.new(255,255,224,255))
      halo=Bitmap.new(128,128);a<<halo
      (5..60).step(5).to_a.reverse.each do |r|
        alpha=((1-r/65.0)*16).round
        (-r..r).each do |y|
          half=Math.sqrt(r*r-y*y).floor
          halo.fill_rect(64-half,64+y,half*2+1,1,Color.new(241,196,79,alpha))
        end
      end
      flower=Bitmap.new(144,144);a<<flower
      6.times do |i|
        a0=i*Math::PI/3
        pts=Array.new(24) do |j|
          p=j*Math::PI/12
          radial=23+Math.cos(p)*27;side=Math.sin(p)*12
          [72+Math.cos(a0)*radial-Math.sin(a0)*side,72+Math.sin(a0)*radial+Math.cos(a0)*side]
        end
        polygon(flower,pts,Color.new(242,158+i%2*22,130,105))
      end
      100.times do |i|
        ang=i*Math::PI/50
        flower.fill_rect((72+Math.cos(ang)*19).round,(72+Math.sin(ang)*19).round,2,2,Color.new(255,225,135,210))
      end
      veil=Bitmap.new(Graphics.width,Graphics.height);a<<veil
      veil.fill_rect(0,0,Graphics.width,Graphics.height,Color.new(36,31,29,255))
      a
    rescue
      a.each { |b|b.dispose unless b.disposed? };raise
    end
  end
  CUES = [[0.08,["PRSFX- Sweet Scent","PRSFX- Pollen Puff1"],48,105],
          [0.25,["PRSFX- Absorb1","PRSFX- Giga Drain1"],60,115],
          [0.48,["PRSFX- Absorb2","PRSFX- Leech Life1"],55,120],
          [0.69,["PRSFX- Giga Drain2","PRSFX- Absorb2"],58,120],
          [0.84,["PRSFX- Synthesis","PRSFX- Morning Sun"],48,125]]
  def self.path(p,cx,cy,sx,sy,lane)
    dx,dy=sx-cx,sy-cy;length=[Math.sqrt(dx*dx+dy*dy),1].max
    arc=Math.sin(p*Math::PI)
    twist=Math.sin(p*Math::PI*4+lane*Math::PI*2/3)*arc*10
    [cx+dx*p-dy/length*twist,cy+dy*p-arc*44+dx/length*twist]
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
      return super unless NectarSiphonVisual::MOVE_IDS.include?(moveID)
      return if @battle && !@battle.showAnims
      return if @nectar_siphon_boxes
      entries=(targets.is_a?(Array) ? targets : [targets]).compact.select { |b|b.respond_to?(:index) }
      return super if entries.empty?
      entries=entries.uniq { |b|b.index }.select do |b|
        s=@sprites && @sprites["pokemon_#{b.index}"]
        s && !s.disposed? && s.bitmap &&
          !(b.respond_to?(:isCommander?) && b.isCommander?) &&
          !(s.respond_to?(:vanishMode) && s.vanishMode>0)
      end
      return if entries.empty?
      pbNectarSiphonVisual(user,entries)
    end
    def pbNectarSiphonHideHP
      return unless @nectar_siphon_boxes && @sprites
      @sprites.each do |key,s|
        next unless key.to_s.start_with?("dataBox_") && s && !s.disposed?
        @nectar_siphon_boxes[s.object_id]||=[s,s.visible];s.visible=false
      end
    end
    def pbGraphicsUpdate
      pbNectarSiphonHideHP if @nectar_siphon_boxes
      super
    end
    def pbNectarSiphonVisual(user,targets)
      sprites,bitmaps,hidden=[],[],{}
      @nectar_siphon_boxes={}
      begin
        @briefMessage=false;pbNectarSiphonHideHP
        bitmaps.concat(NectarSiphonVisual.assets)
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
        bloom=make.call(flower_b,72,72,20_012);bloom.x,bloom.y=sx,sy
        receive_rings=Array.new(3) {make.call(ring_b,64,64,20_010)}
        receive_glints=Array.new(16) {make.call(glint_b,10,10,20_020)}
        groups=targets.map do |b|
          src=@sprites["pokemon_#{b.index}"]
          cx=src.x+(src.src_rect.width/2.0-src.ox)*src.zoom_x
          cy=src.y+(src.src_rect.height*0.55-src.oy)*src.zoom_y
          {cx:cx,cy:cy,flower:make.call(flower_b,72,72,20_006),halo:make.call(halo_b,64,64,20_005),
           drops:Array.new(42) {make.call(drop_b,12,17,20_016)},
           trails:Array.new(66) {make.call(trail_b,14,4,20_011)},
           petals:Array.new(12) {make.call(petal_b,10,15,20_018)},
           sparks:Array.new(18) {make.call(glint_b,10,10,20_017)}}
        end
        frames=[(Graphics.frame_rate*NectarSiphonVisual::DURATION).round,2].max;cue_index=0
        frames.times do |f|
          t=f.to_f/(frames-1)
          while cue_index<NectarSiphonVisual::CUES.size && t>=NectarSiphonVisual::CUES[cue_index][0]
            NectarSiphonVisual.sound(NectarSiphonVisual::CUES[cue_index]);cue_index+=1
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
            flower=g[:flower];flower.x,flower.y=cx,cy;flower.angle=t*65
            flower.zoom_x=flower.zoom_y=0.35+Math.sin(extract*Math::PI)*0.42
            flower.opacity=(Math.sin(extract*Math::PI)*185).round
            halo=g[:halo];halo.x,halo.y=cx,cy;halo.zoom_x=halo.zoom_y=1.05
            halo.opacity=(Math.sin(extract*Math::PI)*125).round
            g[:drops].each_with_index do |s,i|
              start=0.17+(i/3)*0.027;lane=i%3
              p=(t-start)/0.30
              if p>=0 && p<=1
                x,y=NectarSiphonVisual.path(p,cx,cy,sx,sy,lane)
                x2,y2=NectarSiphonVisual.path([p+0.01,1.001].min,cx,cy,sx,sy,lane)
                s.x,s.y=x,y
                # Rotate the pointed end into the direction of suction.
                s.angle=-Math.atan2(y2-y,x2-x)*180/Math::PI-90
                size=0.29+(i%5)*0.065
                s.zoom_x=size;s.zoom_y=size*(1.18+Math.sin(p*Math::PI)*0.3)
                s.opacity=([p/0.12,(1-p)/0.08,1].min*255).round
              else;s.opacity=0;end
            end
            g[:trails].each_with_index do |s,i|
              lane=i%3;p=(i/3)/21.0
              x,y=NectarSiphonVisual.path(p,cx,cy,sx,sy,lane)
              x2,y2=NectarSiphonVisual.path(p+0.015,cx,cy,sx,sy,lane)
              wave=[[(t-0.17-p*0.30)/0.12,0].max,1].min
              tail=[[(0.87-t)/0.14,0].max,1].min
              s.x,s.y=x,y;s.angle=-Math.atan2(y2-y,x2-x)*180/Math::PI
              s.zoom_x=0.35;s.zoom_y=0.38
              s.opacity=(wave*tail*(45+Math.sin(t*32-p*14+lane)*22)).round
            end
            g[:petals].each_with_index do |s,i|
              start=0.10+i%4*0.04;p=(t-start)/0.42
              if p>=0 && p<=1
                a=i*2.399;r=Math.sin(p*Math::PI)*(35+i%3*14)
                s.x=cx+Math.cos(a+p)*r;s.y=cy+Math.sin(a+p)*r*0.7-p*16
                s.angle=i*31+p*150;s.zoom_x=0.25+i%3*0.08;s.zoom_y=s.zoom_x*0.8
                s.opacity=(Math.sin(p*Math::PI)*210).round
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
        boxes=@nectar_siphon_boxes;@nectar_siphon_boxes=nil
        boxes.each_value { |s,v|s.visible=v if s && !s.disposed? } if boxes
        sprites.reverse_each { |s|s.dispose unless s.disposed? }
        bitmaps.each { |b|b.dispose unless b.disposed? }
      end
    end
  end
end
Battle::Scene.prepend(NectarSiphonVisual::SceneHooks)
