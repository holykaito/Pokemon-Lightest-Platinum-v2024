# Mountain Chunk - Pokemon Essentials v21.1, procedural visuals only.
# Install in Plugins/[KAITO] Plugin/ and recompile. Move ID: MOUNTAINCHUNK.
# Stomp -> rising mountain / launch -> airborne fracture -> heavy landing.
# Does not change damage, flinch, HP or battler mechanics.
module MountainChunkVisual
  VERSION = "1.0"
  MOVE_IDS = [:MOUNTAINCHUNK]
  DURATION = 3.30
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

  def self.rock(w=224,h=196)
    b=Bitmap.new(w,h)
    shape=[[3,190],[19,144],[37,131],[48,90],[75,79],[88,40],[111,5],[136,36],[145,67],[174,82],[183,123],[207,144],[221,190]]
    polygon(b,shape,Color.new(62,48,43,255))
    faces=[[[3,190],[48,90],[75,79],[89,139],[69,190]],
           [[48,90],[88,40],[111,5],[105,100],[89,139]],
           [[111,5],[136,36],[145,67],[105,100]],
           [[105,100],[145,67],[174,82],[159,149],[130,190]],
           [[174,82],[183,123],[207,144],[221,190],[175,190],[159,149]],
           [[89,139],[105,100],[130,190],[69,190]]]
    cols=[[127,102,74],[173,145,104],[211,184,135],[112,88,64],[77,62,51],[151,122,87]]
    faces.each_with_index { |p,i|polygon(b,p,Color.new(*cols[i],255)) }
    [[[111,7],[105,100],[89,139],[69,188]],[[145,68],[134,110],[159,149],[175,189]],[[49,91],[68,119],[89,139]]].each do |p|
      p.each_cons(2) { |a,z|line(b,*a,*z,3,Color.new(42,32,29,255)) }
    end
    42.times do |i|
      x=43+(i*37)%130;y=103+(i*23)%78
      line(b,x,y,x+5+i%9,y-2,1,Color.new(228,197,143,110))
    end
    b
  end
  def self.assets
    a=[]
    begin
      a<<rock
      cracks=Bitmap.new(280,112);a<<cracks
      11.times do |i|
        angle=i*Math::PI*2/11
        pts=Array.new(6) { |j|r=j*23;[140+Math.cos(angle+(j%2)*0.14)*r,56+Math.sin(angle+(j%2)*0.14)*r*0.39] }
        pts.each_cons(2) do |p,q|
          line(cracks,*p,*q,4,Color.new(51,35,26,220))
          line(cracks,p[0],p[1]+2,q[0],q[1]+2,1,Color.new(222,180,111,200))
        end
        p=pts[3];q=[p[0]+Math.cos(angle+0.8)*30,p[1]+Math.sin(angle+0.8)*14]
        line(cracks,*p,*q,2,Color.new(62,42,30,200))
      end
      chip=Bitmap.new(48,52);a<<chip
      polygon(chip,[[4,18],[23,3],[43,13],[46,35],[20,49],[2,36]],Color.new(84,65,48,255))
      polygon(chip,[[4,18],[23,3],[43,13],[26,27]],Color.new(201,168,116,255))
      polygon(chip,[[4,18],[26,27],[20,49],[2,36]],Color.new(145,111,73,255))
      puff=Bitmap.new(80,64);a<<puff
      [[37,31,28],[20,36,17],[56,35,20],[39,19,17]].each do |cx,cy,r|
        (-r..r).each do |y|
          half=Math.sqrt([r*r-y*y,0].max).floor
          puff.fill_rect(cx-half,cy+y,half*2+1,1,Color.new(172,141,103,85))
        end
      end
      ring=Bitmap.new(256,100);a<<ring
      180.times do |i|
        theta=i*Math::PI*2/180;x=128+Math.cos(theta)*122;y=50+Math.sin(theta)*39
        ring.fill_rect(x.round,y.round,4,2,Color.new(235,205,146,220))
      end
      veil=Bitmap.new(Graphics.width,Graphics.height);a<<veil
      veil.fill_rect(0,0,Graphics.width,Graphics.height,Color.new(31,24,20,255))
      flash=Bitmap.new(Graphics.width,Graphics.height);a<<flash
      flash.fill_rect(0,0,Graphics.width,Graphics.height,Color.new(255,232,182,255))
      a
    rescue
      a.each { |b|b.dispose unless b.disposed? };raise
    end
  end
  CUES = [[0.13,["PRSFX- Stomp","PRSFX- Earthquake"],80,75],
          [0.27,["PRSFX- Earth Power","PRSFX- Rock Tomb","PRSFX- Earthquake"],85,75],
          [0.43,["PRSFX- Rock Slide","PRSFX- Rock Tomb"],78,85],
          [0.56,["PRSFX- Rock Smash","PRSFX- Rock Slide"],90,80],
          [0.77,["PRSFX- Earthquake","PRSFX- Rock Tomb"],95,65]]
  def self.sound(cue)
    _,names,volume,pitch=cue
    names.each do |name|
      next unless [".wav",".ogg",".mp3"].any? { |ext|File.file?("Audio/SE/Anim/#{name}#{ext}") }
      pbSEPlay("Anim/#{name}",volume,pitch);break
    end
  end
  module SceneHooks
    def pbAnimation(moveID,user,targets,hitNum=0)
      return super unless MountainChunkVisual::MOVE_IDS.include?(moveID)
      return if @battle && !@battle.showAnims
      return if @mountain_chunk_boxes
      entries=(targets.is_a?(Array) ? targets : [targets]).compact.select { |b|b.respond_to?(:index) }
      return super if entries.empty?
      entries=entries.uniq { |b|b.index }.select do |b|
        s=@sprites && @sprites["pokemon_#{b.index}"]
        s && !s.disposed? && s.bitmap &&
          !(b.respond_to?(:isCommander?) && b.isCommander?) &&
          !(s.respond_to?(:vanishMode) && s.vanishMode>0)
      end
      return if entries.empty?
      pbMountainChunkVisual(user,entries)
    end
    def pbMountainChunkHideHP
      return unless @mountain_chunk_boxes && @sprites
      @sprites.each do |key,s|
        next unless key.to_s.start_with?("dataBox_") && s && !s.disposed?
        @mountain_chunk_boxes[s.object_id]||=[s,s.visible];s.visible=false
      end
    end
    def pbGraphicsUpdate
      pbMountainChunkHideHP if @mountain_chunk_boxes
      super
    end
    def pbMountainChunkVisual(user,targets)
      sprites,bitmaps,hidden=[],[],{}
      @mountain_chunk_boxes={}
      viewport_state=(@viewport && @viewport.respond_to?(:ox)) ? [@viewport.ox,@viewport.oy] : nil
      begin
        @briefMessage=false;pbMountainChunkHideHP
        bitmaps.concat(MountainChunkVisual.assets)
        rock_b,crack_b,chip_b,puff_b,ring_b,veil_b,flash_b=bitmaps
        make=proc do |b,ox,oy,z|
          s=Sprite.new(@viewport);sprites<<s
          s.bitmap,s.ox,s.oy,s.z=b,ox,oy,z;s.opacity=0;s
        end
        snapshot=proc do |src|
          bitmap=src.bitmap.clone;bitmaps<<bitmap
          s=make.call(bitmap,src.ox,src.oy,20_010)
          s.src_rect.set(src.src_rect.x,src.src_rect.y,src.src_rect.width,src.src_rect.height)
          s.x,s.y=src.x,src.y;s.zoom_x,s.zoom_y=src.zoom_x,src.zoom_y
          s.visible,s.mirror,s.opacity=src.visible,src.mirror,src.opacity
          s.color=src.color.clone;s.tone=src.tone.clone if src.respond_to?(:tone)
          hidden[src.object_id]||=[src,src.visible];src.visible=false;s
        end
        veil=make.call(veil_b,0,0,20_000);flash=make.call(flash_b,0,0,20_030)
        groups=targets.map do |b|
          src=@sprites["pokemon_#{b.index}"];copy=snapshot.call(src)
          cx=src.x+(src.src_rect.width/2.0-src.ox)*src.zoom_x
          ground=src.y+(src.src_rect.height-src.oy)*src.zoom_y
          height=src.src_rect.height*src.zoom_y
          lift=[[ground-height*0.86-12,70].max,136].min
          # Fit the launched sprite within the visible scene in either direction.
          scale=lift/186.0
          shadow=@sprites["shadow_#{b.index}"]
          hidden[shadow.object_id]=[shadow,shadow.visible] if shadow && !shadow.disposed?
          {copy:copy,x:src.x,y:src.y,cx:cx,ground:ground,lift:lift,scale:scale,zx:src.zoom_x,zy:src.zoom_y,
           rock:make.call(rock_b,112,190,20_005),cracks:make.call(crack_b,140,56,20_003),
           chips:Array.new(34) {make.call(chip_b,24,26,20_015)},
           dust:Array.new(16) {make.call(puff_b,40,32,20_020)},
           rings:Array.new(3) {make.call(ring_b,128,50,20_018)}}
        end
        actor_src=user && user.respond_to?(:index) && @sprites["pokemon_#{user.index}"]
        actor=nil
        if actor_src && !actor_src.disposed? && actor_src.bitmap && !targets.any? { |b|b.index==user.index }
          actor=snapshot.call(actor_src);ax,ay=actor.x,actor.y
        end
        cue_index=0;frames=[(Graphics.frame_rate*MountainChunkVisual::DURATION).round,2].max
        frames.times do |f|
          t=f.to_f/(frames-1)
          while cue_index<MountainChunkVisual::CUES.size && t>=MountainChunkVisual::CUES[cue_index][0]
            MountainChunkVisual.sound(MountainChunkVisual::CUES[cue_index]);cue_index+=1
          end
          envelope=[t/0.12,(1-t)/0.17,1.0].min
          veil.opacity=(envelope*78).round
          shock=[0.13,0.29,0.56,0.77].each_with_index.map do |start,i|
            p=(t-start)/[0.09,0.11,0.07,0.16][i]
            p>=0 && p<=1 ? (1-p)*[6,5,7,11][i] : 0
          end.max
          if viewport_state
            @viewport.ox=viewport_state[0]+(Math.sin(f*2.4)*shock).round
            @viewport.oy=viewport_state[1]+(Math.cos(f*2.9)*shock*0.65).round
          end
          flash.opacity=([0.56,0.77].map { |start|p=(t-start)/0.035;p>=0 && p<=1 ? (1-p)*90 : 0 }.max).round
          if actor
            jump=t<0.13 ? Math.sin(t/0.13*Math::PI)*9 : 0
            actor.y=ay-jump
          end
          groups.each do |g|
            cx,ground,lift,scale=g.values_at(:cx,:ground,:lift,:scale)
            rise=[[(t-0.25)/0.18,0].max,1].min
            rise=1-(1-rise)**3
            # The mountain launches the target, then breaks while it is airborne.
            up=if t<0.43;rise*lift
               elsif t<0.59;lift+Math.sin((t-0.43)/0.16*Math::PI)*16
               elsif t<0.77;lift*(1-((t-0.59)/0.18)**2)
               else;0;end
            copy=g[:copy];copy.x=g[:x]+Math.sin(f*2.2)*shock*0.35;copy.y=g[:y]-up
            perspective=1-0.10*[up/lift,1].min
            copy.zoom_x=g[:zx]*perspective;copy.zoom_y=g[:zy]*perspective
            copy.angle=t>=0.56 && t<0.77 ? Math.sin((t-0.56)/0.21*Math::PI)*9 : 0
            rock=g[:rock];rock.x,rock.y=cx,ground
            rock.zoom_x=0.95+scale*0.35;rock.zoom_y=scale*[rise,0.001].max
            rock.opacity=t>=0.25 && t<0.56 ? 255 : 0
            crack=g[:cracks];crack.x,crack.y=cx,ground+3
            crack.zoom_x=crack.zoom_y=t>=0.77 ? 1.15 : 0.80
            crack.opacity=t>=0.25 ? ((t<0.77 ? 175 : 245)*[[(1-t)/0.12,0].max,1].min).round : 0
            g[:chips].each_with_index do |s,i|
              start=i<24 ? 0.56 : 0.77
              p=(t-start)/(i<24 ? 0.36 : 0.22)
              if p>=0 && p<=1
                direction=i.even? ? 1 : -1
                distance=(45+i%7*18)*p
                s.x=cx+(i<24 ? (i%6-2.5)*18*scale : 0)+direction*distance
                base=i<24 ? ground-lift*(0.25+(i%6)*0.12) : ground
                s.y=base-(35+i%5*12)*p+145*p*p
                s.zoom_x=s.zoom_y=(i<24 ? 0.34+i%5*0.15 : 0.16+i%3*0.08)*scale
                s.angle=i*37+direction*p*165
                s.opacity=((1-p)**0.5*255).round
              else;s.opacity=0;end
            end
            g[:dust].each_with_index do |s,i|
              start=i<6 ? 0.26 : 0.77;p=(t-start)/(i<6 ? 0.26 : 0.23)
              if p>=0 && p<=1
                direction=i.even? ? 1 : -1
                s.x=cx+direction*(12+p*(65+i%5*19));s.y=ground-5-p*(15+i%4*7)
                size=(0.38+p*1.25)*(0.75+i%3*0.13)
                s.zoom_x=size;s.zoom_y=size*0.72
                s.opacity=(Math.sin(p*Math::PI)**0.6*(i<6 ? 155 : 220)).round
              else;s.opacity=0;end
            end
            g[:rings].each_with_index do |s,i|
              p=(t-[0.26,0.77,0.80][i])/0.17
              s.x,s.y=cx,ground+2
              s.zoom_x=s.zoom_y=0.35+[p,0].max*1.2
              s.opacity=p>=0 && p<=1 ? ((1-p)*220).round : 0
            end
          end
          hidden.each_value { |s,_|s.visible=false unless s.disposed? }
          pbUpdate
        end
      ensure
        if viewport_state
          @viewport.ox,@viewport.oy=viewport_state
        end
        boxes=@mountain_chunk_boxes;@mountain_chunk_boxes=nil
        boxes.each_value { |s,v|s.visible=v if s && !s.disposed? } if boxes
        hidden.each_value { |s,v|s.visible=v if s && !s.disposed? }
        sprites.reverse_each { |s|s.dispose unless s.disposed? }
        bitmaps.each { |b|b.dispose unless b.disposed? }
      end
    end
  end
end
Battle::Scene.prepend(MountainChunkVisual::SceneHooks)
