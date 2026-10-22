# Clay Dart - Essentials v21.1. Install in Plugins/[KAITO] Plugin/; recompile.
# Move ID CLAYDART. Pure presentation; existing damage and type rules unchanged.
# Clay fragments compress into a rifled dart, spiral launch, granular impact.
module ClayDartVisual
  VERSION = "1.0"
  MOVE_IDS = [:CLAYDART]
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
      dart=Bitmap.new(168,56);a<<dart
      polygon(dart,[[5,18],[40,11],[92,15],[110,2],[164,28],[110,53],[92,40],[40,44],[5,37],[25,28]],Color.new(82,48,33,255))
      polygon(dart,[[15,19],[48,15],[110,21],[110,7],[157,27],[51,27],[30,24]],Color.new(219,158,95,255))
      polygon(dart,[[27,29],[109,29],[155,29],[112,46],[106,36],[48,39]],Color.new(155,85,48,255))
      polygon(dart,[[70,25],[116,20],[155,28],[113,33],[70,30]],Color.new(255,221,153,245))
      5.times do |i|
        x=33+i*14
        polygon(dart,[[x,15],[x+7,16],[x+18,38],[x+11,39]],Color.new(104,55,33,230))
        line(dart,x+2,15,x+13,37,2,Color.new(240,183,115,255))
      end
      shard=Bitmap.new(28,34);a<<shard
      polygon(shard,[[3,12],[14,2],[25,10],[23,26],[9,32],[2,23]],Color.new(120,64,41,255))
      polygon(shard,[[3,12],[14,2],[25,10],[12,18]],Color.new(226,164,103,255))
      polygon(shard,[[3,12],[12,18],[9,32],[2,23]],Color.new(182,107,62,255))
      speck=Bitmap.new(8,8);a<<speck
      speck.fill_rect(2,1,4,6,Color.new(183,106,61,240));speck.fill_rect(2,1,3,2,Color.new(255,204,127,255))
      ring=Bitmap.new(112,112);a<<ring
      140.times do |i|
        theta=i*Math::PI*2/140
        ring.fill_rect((56+Math.cos(theta)*48).round,(56+Math.sin(theta)*48).round,3,3,Color.new(243,183,110,190))
      end
      impact=Bitmap.new(160,160);a<<impact
      pts=Array.new(32) { |i|ang=i*Math::PI/16;r=i.even? ? 62+i%5*3 : 16+i%3*4;[80+Math.cos(ang)*r,80+Math.sin(ang)*r] }
      polygon(impact,pts,Color.new(135,73,43,240))
      polygon(impact,pts.map { |x,y|[80+(x-80)*0.73,80+(y-80)*0.73] },Color.new(237,168,87,245))
      polygon(impact,pts.map { |x,y|[80+(x-80)*0.36,80+(y-80)*0.36] },Color.new(255,236,180,255))
      puff=Bitmap.new(64,64);a<<puff
      6.times do |i|
        r=14+i%3*3;cx=32+Math.cos(i*2.4)*12;cy=32+Math.sin(i*2.4)*10
        (-r..r).each do |y|
          h=Math.sqrt(r*r-y*y).floor
          puff.fill_rect((cx-h).round,(cy+y).round,h*2+1,1,Color.new(179,120,76,80))
        end
      end
      veil=Bitmap.new(Graphics.width,Graphics.height);a<<veil
      veil.fill_rect(0,0,Graphics.width,Graphics.height,Color.new(40,28,21,255))
      a
    rescue
      a.each { |b|b.dispose unless b.disposed? };raise
    end
  end
  CUES = [[0.08,["PRSFX- Sand Tomb","PRSFX- Sand Attack"],48,110],
          [0.28,["PRSFX- Rock Polish","PRSFX- Rock Tomb"],60,125],
          [0.43,["PRSFX- Thousand Arrows2","PRSFX- Rock Blast"],76,115],
          [0.67,["PRSFX- Rock Blast","PRSFX- Rock Smash"],85,105],
          [0.73,["PRSFX- Mud Shot","PRSFX- Rock Tomb"],58,90]]
  def self.sound(cue)
    _,names,volume,pitch=cue
    names.each do |name|
      next unless [".wav",".ogg",".mp3"].any? { |ext|File.file?("Audio/SE/Anim/#{name}#{ext}") }
      pbSEPlay("Anim/#{name}",volume,pitch);break
    end
  end
  module SceneHooks
    def pbAnimation(moveID,user,targets,hitNum=0)
      return super unless ClayDartVisual::MOVE_IDS.include?(moveID)
      return if @battle && !@battle.showAnims
      return if @clay_dart_boxes
      entries=(targets.is_a?(Array) ? targets : [targets]).compact.select { |b|b.respond_to?(:index) }
      return super if entries.empty?
      entries=entries.uniq { |b|b.index }.select do |b|
        s=@sprites && @sprites["pokemon_#{b.index}"]
        s && !s.disposed? && s.bitmap &&
          !(b.respond_to?(:isCommander?) && b.isCommander?) &&
          !(s.respond_to?(:vanishMode) && s.vanishMode>0)
      end
      return if entries.empty?
      pbClayDartVisual(user,entries)
    end
    def pbClayDartHideHP
      return unless @clay_dart_boxes && @sprites
      @sprites.each do |key,s|
        next unless key.to_s.start_with?("dataBox_") && s && !s.disposed?
        @clay_dart_boxes[s.object_id]||=[s,s.visible];s.visible=false
      end
    end
    def pbGraphicsUpdate
      pbClayDartHideHP if @clay_dart_boxes
      super
    end
    def pbClayDartVisual(user,targets)
      sprites,bitmaps,hidden=[],[],{}
      @clay_dart_boxes={}
      begin
        @briefMessage=false;pbClayDartHideHP
        bitmaps.concat(ClayDartVisual.assets)
        dart_b,shard_b,speck_b,ring_b,impact_b,puff_b,veil_b=bitmaps
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
        groups=targets.map do |b|
          target=@sprites["pokemon_#{b.index}"];copy=snapshot.call(target)
          cx=target.x+(target.src_rect.width/2.0-target.ox)*target.zoom_x
          cy=target.y+(target.src_rect.height*0.55-target.oy)*target.zoom_y
          dx,dy=cx-sx,cy-sy
          angle=-Math.atan2(dy,dx)*180/Math::PI
          {copy:copy,x:target.x,y:target.y,color:target.color.clone,cx:cx,cy:cy,angle:angle,
           dart:make.call(dart_b,84,28,20_015),echoes:Array.new(5) {make.call(dart_b,84,28,20_008)},
           grains:Array.new(34) {make.call(speck_b,4,4,20_016)},
           gather:Array.new(16) {make.call(shard_b,14,17,20_010)},
           burst:make.call(impact_b,80,80,20_020),
           shards:Array.new(28) {make.call(shard_b,14,17,20_021)},
           dust:Array.new(8) {make.call(puff_b,32,32,20_023)},
           rings:Array.new(3) {make.call(ring_b,56,56,20_018)}}
        end
        frames=[(Graphics.frame_rate*ClayDartVisual::DURATION).round,2].max;cue_index=0
        frames.times do |f|
          t=f.to_f/(frames-1)
          while cue_index<ClayDartVisual::CUES.size && t>=ClayDartVisual::CUES[cue_index][0]
            ClayDartVisual.sound(ClayDartVisual::CUES[cue_index]);cue_index+=1
          end
          veil.opacity=([t/0.15,(1-t)/0.20,1].min*60).round
          actor.x=ax-(groups[0][:cx]>=sx ? 1 : -1)*Math.sin([[(t-0.41)/0.15,0].max,1].min*Math::PI)*6 if actor
          groups.each do |g|
            cx,cy=g.values_at(:cx,:cy);dx,dy=cx-sx,cy-sy
            dist=[Math.sqrt(dx*dx+dy*dy),1].max;nx,ny=-dy/dist,dx/dist
            p=[[(t-0.43)/0.24,0].max,1].min
            # Single projectile; echoes and spiral grains are its motion trail.
            dart=g[:dart];dart.angle=g[:angle];dart.x=sx+dx*p;dart.y=sy+dy*p
            form=[[(t-0.24)/0.19,0].max,1].min
            dart.zoom_x=0.18+form*0.68;dart.zoom_y=0.20+form*0.66
            dart.opacity=t>=0.24 && t<0.67 ? (form*255).round : 0
            g[:gather].each_with_index do |s,i|
              q=[[(t-0.04-i%4*0.02)/0.35,0].max,1].min
              a=i*2.399+q*3.8;r=(1-q)*(35+i%4*9)
              s.x=sx+Math.cos(a)*r;s.y=sy+Math.sin(a)*r*0.75+(1-q)**2*28
              s.zoom_x=s.zoom_y=0.20+i%3*0.05;s.angle=i*29+q*180
              s.opacity=t<0.43 ? (Math.sin(q*Math::PI)**0.5*245).round : 0
            end
            g[:echoes].each_with_index do |s,i|
              q=(t-0.43-i*0.018)/0.24
              s.x=sx+dx*q;s.y=sy+dy*q;s.angle=g[:angle]
              s.zoom_x=0.70-i*0.07;s.zoom_y=0.59-i*0.06
              s.opacity=t>=0.43 && t<0.69 && q>=0 && q<1 ? (75-i*11) : 0
            end
            g[:grains].each_with_index do |s,i|
              q=(t-0.43)/0.24-i*0.014
              a=i*1.7+t*35;r=9+Math.sin(i)*4
              s.x=sx+dx*q+nx*Math.cos(a)*r;s.y=sy+dy*q+ny*Math.cos(a)*r
              s.zoom_x=s.zoom_y=0.50+i%3*0.22;s.angle=i*51
              s.opacity=t>=0.43 && t<0.74 && q>=0 && q<=1 ? 200 : 0
            end
            impact=[[(t-0.67)/0.30,0].max,1].min
            shake=t>=0.67 ? (1-impact)*7 : 0
            g[:copy].x=g[:x]+Math.sin(f*2.4)*shake
            g[:copy].y=g[:y]+Math.cos(f*2.7)*shake*0.4
            g[:copy].color=t>=0.67 && t<0.73 ? Color.new(255,208,131,((0.73-t)/0.06*135).round) : g[:color]
            burst=g[:burst];burst.x,burst.y=cx,cy;burst.angle=g[:angle]
            burst.zoom_x=burst.zoom_y=0.25+impact*1.25
            burst.opacity=t>=0.67 ? ((1-impact)**2*245).round : 0
            g[:shards].each_with_index do |s,i|
              a=i*2.399;r=(15+impact*(65+i%5*12))
              s.x=cx+Math.cos(a)*r;s.y=cy+Math.sin(a)*r*0.75+impact*impact*55
              s.zoom_x=s.zoom_y=0.18+i%4*0.09;s.angle=i*29+impact*190
              s.opacity=t>=0.67 ? ((1-impact)**0.6*255).round : 0
            end
            g[:dust].each_with_index do |s,i|
              a=i*Math::PI/4;r=impact*(35+i%3*15)
              s.x=cx+Math.cos(a)*r;s.y=cy+Math.sin(a)*r*0.65+impact*18
              s.zoom_x=s.zoom_y=0.30+impact*(0.9+i%3*0.2)
              s.opacity=t>=0.67 ? (Math.sin(impact*Math::PI)*125).round : 0
            end
            g[:rings].each_with_index do |s,i|
              start=i==0 ? 0.40 : 0.67+(i-1)*0.035
              q=(t-start)/(i==0 ? 0.18 : 0.23)
              s.x,s.y=i==0 ? [sx,sy] : [cx,cy]
              s.angle=g[:angle];s.zoom_x=0.12+[q,0].max*0.65;s.zoom_y=0.45+[q,0].max*1.10
              s.opacity=q>=0 && q<=1 ? ((1-q)*190).round : 0
            end
          end
          hidden.each_value { |s,_|s.visible=false unless s.disposed? };pbUpdate
        end
      ensure
        boxes=@clay_dart_boxes;@clay_dart_boxes=nil
        boxes.each_value { |s,v|s.visible=v if s && !s.disposed? } if boxes
        hidden.each_value { |s,v|s.visible=v if s && !s.disposed? }
        sprites.reverse_each { |s|s.dispose unless s.disposed? }
        bitmaps.each { |b|b.dispose unless b.disposed? }
      end
    end
  end
end
Battle::Scene.prepend(ClayDartVisual::SceneHooks)
