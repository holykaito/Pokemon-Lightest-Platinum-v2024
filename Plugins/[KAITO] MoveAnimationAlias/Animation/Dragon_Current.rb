# Dragon Current - Pokemon Essentials v21.1
# Two-turn pixel animation: hitNum 1 = dive; hitNum 0 = strike + vortex.
# Install in an existing plugin folder. No external images or PBS edits.
# Does not change underwater invulnerability, trapping, damage or duration.
# Animated Pokemon System keeps handling vanishMode after pbShowAnimation.
module DragonCurrentVisual
  DIVE_SECONDS = 1.65
  STRIKE_SECONDS = 2.45

  def self.line(b,x1,y1,x2,y2,width,c)
    steps = [(x2-x1).abs.round,(y2-y1).abs.round,1].max
    (0..steps).each do |i|
      p = i.to_f/steps
      b.fill_rect((x1+(x2-x1)*p).round-width/2,(y1+(y2-y1)*p).round-width/2,width,width,c)
    end
  end

  def self.polygon(b,points,c)
    low,high = points.map { |p| p[1] }.minmax
    (low..high).each do |y|
      xs = []
      points.each_with_index do |p,i|
        q = points[(i+1)%points.length]
        next unless (p[1]<=y && q[1]>y) || (q[1]<=y && p[1]>y)
        xs << p[0]+(y-p[1]).to_f*(q[0]-p[0])/(q[1]-p[1])
      end
      xs.sort.each_slice(2) { |l,r| b.fill_rect(l.ceil,y,[r.floor-l.ceil+1,1].max,1,c) if r }
    end
  end

  def self.ellipse(b,cx,cy,rx,ry,c)
    (-ry..ry).each do |y|
      dx = (rx*Math.sqrt([1-y*y.to_f/(ry*ry),0].max)).floor
      b.fill_rect(cx-dx,cy+y,dx*2+1,1,c)
    end
  end

  def self.ring
    b = Bitmap.new(192,192)
    [67,70,74,78].each do |r|
      360.times do |i|
        next if (i/24+r)%4 == 0
        a = i*Math::PI/180
        c = case r
            when 67 then Color.new(55,75,155,200)
            when 70 then Color.new(62,158,220,220)
            when 74 then Color.new(152,235,248,225)
            else Color.new(226,253,255,145)
            end
        b.fill_rect((96+Math.cos(a)*r).round,(96+Math.sin(a)*r).round,3,3,c)
      end
    end
    b
  end

  def self.pool
    b = Bitmap.new(192,80)
    8.downto(1) do |i|
      ellipse(b,96,40,60+i*3,14+i,Color.new(52,128,194,6))
    end
    ellipse(b,96,40,65,19,Color.new(38,75,133,155))
    ellipse(b,96,40,50,13,Color.new(36,40,98,160))
    b
  end

  def self.drop
    b = Bitmap.new(24,32)
    polygon(b,[[12,1],[7,13],[4,20],[7,27],[14,29],[20,22],[18,15]],Color.new(78,174,227,210))
    polygon(b,[[12,7],[8,18],[8,23],[12,24],[14,17]],Color.new(214,251,255,235))
    b
  end

  def self.funnel
    b = Bitmap.new(192,160)
    polygon(b,[[18,12],[174,12],[156,44],[140,72],[124,109],[114,148],
               [78,148],[68,109],[52,72],[36,44]],Color.new(43,114,178,105))
    polygon(b,[[27,17],[44,26],[62,66],[78,103],[85,141],[78,139],
               [68,109],[52,72],[36,44]],Color.new(109,213,235,95))
    polygon(b,[[163,18],[153,40],[134,74],[119,114],[111,145],
               [106,141],[114,105],[126,69],[144,30]],Color.new(150,237,250,85))
    b
  end

  def self.dragon
    b = Bitmap.new(120,88)
    polygon(b,[[8,53],[27,28],[48,25],[37,4],[64,25],[76,14],[79,33],
               [99,42],[115,43],[112,57],[88,61],[71,77],[36,71]],Color.new(52,85,162,225))
    polygon(b,[[16,52],[34,34],[57,33],[49,14],[69,35],[76,26],[78,42],
               [99,47],[109,47],[105,53],[83,53],[65,67],[38,63]],Color.new(91,201,227,240))
    polygon(b,[[23,50],[39,38],[64,39],[78,48],[62,57],[40,55]],Color.new(186,247,250,235))
    line(b,77,42,89,45,3,Color.new(247,242,166,255))
    line(b,88,55,105,52,2,Color.new(239,254,255,235))
    b
  end

  module SceneHooks
    def pbAnimation(moveID,user,targets,hitNum = 0)
      return super unless moveID == :DRAGONCURRENT
      return if @battle && !@battle.showAnims
      target = targets.is_a?(Array) ? targets[0] : targets
      attacker = user && @sprites["pokemon_#{user.index}"]
      defender = target && @sprites["pokemon_#{target.index}"]
      return super unless attacker && !attacker.disposed? && attacker.bitmap
      diving = hitNum == 1
      return super if !diving && (!defender || defender.disposed? || !defender.bitmap)
      pbDragonCurrentVisual(attacker,defender,user.index,diving)
    end

    def pbDragonCurrentVisual(original,defender,user_index,diving)
      sprites,bitmaps = [],[]
      was_visible = original.visible
      target_visible = defender.visible if defender
      shadow = @sprites["shadow_#{user_index}"]
      shadow_visible = shadow.visible if shadow
      begin
        @briefMessage = false
        make = proc do |b,ox,oy,z|
          s = Sprite.new(@viewport)
          sprites << s
          s.bitmap,s.ox,s.oy,s.z = b,ox,oy,z
          s
        end
        copy = proc do |src,z|
          b = src.bitmap.clone
          bitmaps << b
          s = make.call(b,src.ox,src.oy,z)
          s.src_rect.set(src.src_rect.x,src.src_rect.y,src.src_rect.width,src.src_rect.height)
          s.zoom_x,s.zoom_y,s.mirror = src.zoom_x,src.zoom_y,src.mirror
          s.tone,s.color = src.tone.clone,src.color.clone
          s
        end
        actor = copy.call(original,20_015)
        foe = copy.call(defender,20_014) if !diving
        original.visible = false
        defender.visible = false if foe
        shadow.visible = false if shadow
        sx,sy = original.x.to_f,original.y.to_f
        cx = sx+(original.src_rect.width/2.0-original.ox)*original.zoom_x
        cy = sy+(original.src_rect.height/2.0-original.oy)*original.zoom_y
        tx = defender ? defender.x.to_f : cx
        ty = defender ? defender.y.to_f : sy
        target_center_y = defender ? ty+(defender.src_rect.height/2.0-defender.oy)*defender.zoom_y : cy
        direction = tx>=cx ? 1 : -1
        ring_b,pool_b,drop_b,dragon_b = DragonCurrentVisual.ring,DragonCurrentVisual.pool,
          DragonCurrentVisual.drop,DragonCurrentVisual.dragon
        funnel_b = DragonCurrentVisual.funnel
        bitmaps.concat([ring_b,pool_b,drop_b,dragon_b,funnel_b])
        shade_b = Bitmap.new(Graphics.width,Graphics.height)
        shade_b.fill_rect(0,0,Graphics.width,Graphics.height,Color.new(12,26,58))
        bitmaps << shade_b
        shade = make.call(shade_b,0,0,19_990)
        pool = make.call(pool_b,96,40,20_000)
        funnel = make.call(funnel_b,96,148,20_008)
        rings = Array.new(5) do
          s = make.call(ring_b,96,96,20_020)
          s.blend_type = 1
          s
        end
        drops = Array.new(40) { make.call(drop_b,12,20,20_025) }
        serpent = make.call(dragon_b,60,44,20_026)
        serpent.mirror = direction<0
        trail = Array.new(14) { make.call(drop_b,12,20,20_010) }
        frames = [(Graphics.frame_rate*(diving ? DragonCurrentVisual::DIVE_SECONDS : DragonCurrentVisual::STRIKE_SECONDS)).round,2].max
        history = []
        frames.times do |f|
          t = f.to_f/(frames-1)
          fade = [[t/0.14,(1-t)/0.18,1].min,0].max
          shade.opacity = (fade*82).round
          if diving
            funnel.visible = false
            depth = [[(t-0.25)/0.48,0].max,1].min
            actor.x = sx+Math.sin(t*12)*4*(1-depth)
            actor.y = sy+depth*original.src_rect.height*original.zoom_y
            actor.src_rect.height = [(original.src_rect.height*(1-depth)).round,1].max
            actor.opacity = depth>=1 ? 0 : 255
            pool.x,pool.y = cx,sy
            pool.zoom_x = 0.5+t*0.7
            pool.zoom_y = 0.7
            pool.opacity = (fade*210).round
            rings.each_with_index do |s,i|
              p = (t*1.7+i*0.19)%1
              s.x,s.y = cx,sy-2
              s.zoom_x = 0.25+p*1.0
              s.zoom_y = s.zoom_x*0.28
              s.angle = Math.sin(t*4+i)*3
              s.opacity = (fade*(1-p)*210).round
            end
            serpent.visible = false
            trail.each { |s| s.visible = false }
            drops.each_with_index do |s,i|
              a = i*2.399+t*7
              r = (15+i%5*8)*(0.5+0.5*Math.sin(t*Math::PI))
              p = (t*1.6+i*0.137)%1
              s.x = cx+Math.cos(a)*r
              s.y = sy+Math.sin(a)*r*0.25-Math.sin(p*Math::PI)*(18+i%4*9)
              s.zoom_x = s.zoom_y = 0.15+i%3*0.08
              s.opacity = (fade*Math.sin(p*Math::PI)*215).round
              s.z = Math.sin(a)>0 ? 20_025 : 20_005
            end
          else
            # Approach underground, erupt, then pull the foe into a funnel.
            run = [[t/0.34,0].max,1].min
            impact = [[(t-0.34)/0.20,0].max,1].min
            vortex = [[(t-0.49)/0.41,0].max,1].min
            funnel.visible = t>=0.40
            funnel.x,funnel.y = tx,ty+14
            funnel.zoom_x = 0.90
            funnel.zoom_y = 0.65*[[(t-0.40)/0.15,0].max,1].min
            funnel.opacity = (fade*210).round
            x = cx+(tx-cx)*run
            water_y = sy+(ty-sy)*run
            pool.x,pool.y = x,water_y
            pool.zoom_x = 0.70+impact*0.60
            pool.zoom_y = 0.85
            pool.opacity = (fade*230).round
            actor.src_rect.height = original.src_rect.height
            if t<0.30
              actor.opacity = 0
              actor.x,actor.y = sx,sy
            elsif t<0.53
              p = (t-0.30)/0.23
              actor.opacity = (p*255).round
              actor.x = sx+(tx-sx)*p
              actor.y = sy+(target_center_y-sy)*p-Math.sin(p*Math::PI)*43
            else
              p = [[(t-0.53)/0.35,0].max,1].min
              e = p*p*(3-2*p)
              actor.opacity = 255
              actor.x,actor.y = tx+(sx-tx)*e,target_center_y+(sy-target_center_y)*e
            end
            serpent.visible = t>=0.20 && t<0.58
            serpent.x = x
            serpent.y = water_y-impact*75
            serpent.zoom_x = serpent.zoom_y = 0.65+impact*0.25
            serpent.angle = direction*18
            serpent.opacity = t<0.45 ? (fade*240).round : ([1-(t-0.45)/0.13,0].max*240).round
            history.unshift([serpent.x,serpent.y])
            history.pop if history.length>18
            trail.each_with_index do |s,i|
              point = history[[i+1,history.length-1].min]
              s.x = point[0]+Math.sin(t*25-i)*8
              s.y = point[1]+i*3
              s.zoom_x = s.zoom_y = 0.7-i*0.035
              s.angle = t*300+i*20
              s.opacity = serpent.visible ? (200-i*10) : 0
            end
            foe.x,foe.y = defender.x,defender.y
            foe.zoom_x,foe.zoom_y = defender.zoom_x,defender.zoom_y
            if t>=0.49 && t<0.91
              a = vortex*Math::PI*5
              radius = Math.sin(vortex*Math::PI)*15
              foe.x = tx+Math.cos(a)*radius
              foe.y = ty+Math.sin(a)*radius*0.3+Math.sin(vortex*Math::PI)*13
              foe.angle = Math.sin(a)*9
              shrink = 1-Math.sin(vortex*Math::PI)*0.13
              foe.zoom_x,foe.zoom_y = defender.zoom_x*shrink,defender.zoom_y*shrink
            else
              foe.angle = 0
            end
            rings.each_with_index do |s,i|
              s.x = x+Math.sin(t*13+i)*3
              if t<0.40
                s.y = water_y
                s.zoom_x = 0.35+i*0.12
              else
                s.y = ty+5-i*(10+impact*2)
                s.zoom_x = 0.35+i*0.16
              end
              s.zoom_y = s.zoom_x*0.30
              s.angle = Math.sin(t*5+i)*4
              s.opacity = (fade*(190-i*10)).round
              s.z = i.even? ? 20_022 : 20_005
            end
            drops.each_with_index do |s,i|
              a = i*2.399+t*15
              layer = i%5
              if t<0.40
                radius = 15+layer*7
                s.x = x+Math.cos(a)*radius
                s.y = water_y+Math.sin(a)*radius*0.25-Math.sin(t*11+i).abs*12
              else
                radius = 20+layer*9
                s.x = tx+Math.cos(a)*radius
                s.y = ty+7-layer*13+Math.sin(a)*radius*0.26
              end
              s.zoom_x = s.zoom_y = 0.14+layer*0.045
              s.angle = -a*180/Math::PI
              s.opacity = (fade*(180+35*Math.sin(i+t*15))).round
              s.z = Math.sin(a)>0 ? 20_025 : 20_006
            end
          end
          pbUpdate
        end
      ensure
        original.visible = was_visible if original && !original.disposed?
        defender.visible = target_visible if defender && !defender.disposed?
        shadow.visible = shadow_visible if shadow && !shadow.disposed?
        sprites.reverse_each { |s| s.dispose unless s.disposed? }
        bitmaps.each { |b| b.dispose unless b.disposed? }
      end
    end
  end
end
Battle::Scene.prepend(DragonCurrentVisual::SceneHooks)
