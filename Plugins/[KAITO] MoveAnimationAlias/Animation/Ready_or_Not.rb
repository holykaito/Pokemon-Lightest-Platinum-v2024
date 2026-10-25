# Ready or Not - Pokemon Essentials v21.1 / DBK Animated Pokemon System.
# Install: Plugins/[KAITO] MoveAnimationAlias/Animation/Ready_or_Not.rb
# READYORNOT: hitNum 1 = hide, hitNum 0 = attack.
# Visuals only. The move script owns hiding between turns, damage and flinching.
# No external graphics required. Existing animation sounds are optional.
module ReadyOrNotVisual
  VERSION = "1.0"
  MOVE_ID = :READYORNOT
  CHARGE_DURATION = 1.65
  ATTACK_DURATION = 1.25

  def self.clamp(value)
    [[value, 0.0].max, 1.0].min
  end

  def self.polygon(bitmap, points, color)
    low, high = points.map { |p| p[1] }.minmax
    (low.floor..high.ceil).each do |y|
      xs = []
      points.each_with_index do |p, i|
        q = points[(i + 1) % points.length]
        next unless (p[1] <= y && q[1] > y) || (q[1] <= y && p[1] > y)
        xs << p[0] + (y - p[1]).to_f * (q[0] - p[0]) / (q[1] - p[1])
      end
      xs.sort.each_slice(2) do |left, right|
        next unless right
        bitmap.fill_rect(left.ceil, y, [right.floor - left.ceil + 1, 1].max, 1, color)
      end
    end
  end

  def self.assets
    result = []
    begin
      star = Bitmap.new(112,112); result << star
      points = Array.new(16) do |i|
        a = i * Math::PI / 8
        r = i.even? ? (i % 4 == 0 ? 51 : 39) : 15
        [56 + Math.cos(a)*r, 56 + Math.sin(a)*r]
      end
      [[1.0,[178,109,37,235]],[0.80,[255,205,90,255]],
       [0.48,[255,255,235,255]]].each do |scale, color|
        polygon(star, points.map { |x,y| [56+(x-56)*scale,56+(y-56)*scale] }, Color.new(*color))
      end
      ring = Bitmap.new(144,144); result << ring
      240.times do |i|
        a = i * Math::PI / 120
        ring.fill_rect((72+Math.cos(a)*64).round,(72+Math.sin(a)*64).round,3,3,Color.new(255,226,151,230))
      end
      mote = Bitmap.new(12,12); result << mote
      polygon(mote,[[6,0],[8,4],[11,6],[8,8],[6,11],[4,8],[0,6],[4,4]],Color.new(255,241,195,255))
      puff = Bitmap.new(56,56); result << puff
      56.times do |y|
        56.times do |x|
          r = ((x-27.5)**2+(y-27.5)**2)/756.25
          next if r >= 1
          puff.fill_rect(x,y,1,1,Color.new(255,239,206,((1-r)**2*150).round))
        end
      end
      signal = Bitmap.new(16,34); result << signal
      polygon(signal,[[2,1],[14,1],[11,23],[5,23]],Color.new(255,217,104,255))
      signal.fill_rect(5,27,6,6,Color.new(255,250,224,255))
      result
    rescue
      result.each { |b| b.dispose unless b.disposed? }
      raise
    end
  end

  CHARGE_CUES = [
    [0.08,["PRSFX- Mind Reader","PRSFX- Lock On"],48,115],
    [0.53,["PRSFX- Double Team","PRSFX- Agility"],62,120]
  ]
  ATTACK_CUES = [
    [0.05,["PRSFX- Quick Attack","PRSFX- Agility"],62,120],
    [0.34,["PRSFX- Body Slam","PRSFX- Tackle"],82,110]
  ]
  def self.sound(cue)
    cue[1].each do |name|
      next unless [".wav",".ogg",".mp3"].any? { |ext| File.file?("Audio/SE/Anim/#{name}#{ext}") }
      pbSEPlay("Anim/#{name}",cue[2],cue[3])
      break
    end
  end

  module SceneHooks
    def pbAnimation(moveID,user,targets,hitNum=0)
      return super unless moveID == ReadyOrNotVisual::MOVE_ID
      return if @battle && !@battle.showAnims
      return if @ready_or_not_boxes
      src = user && user.respond_to?(:index) && @sprites && @sprites["pokemon_#{user.index}"]
      return super unless pbReadyOrNotSpriteValid(src)
      return if user.respond_to?(:isCommander?) && user.isCommander?
      charging = (hitNum == 1)
      entries = (targets.is_a?(Array) ? targets : [targets]).compact
      entries = entries.select { |b| b.respond_to?(:index) && b.index != user.index }
      entries = entries.uniq { |b| b.index }.select do |b|
        s = @sprites["pokemon_#{b.index}"]
        pbReadyOrNotSpriteValid(s) && s.visible && s.opacity > 0 &&
          !(b.respond_to?(:isCommander?) && b.isCommander?) &&
          !(s.respond_to?(:vanishMode) && s.vanishMode > 0)
      end
      return super if !charging && entries.empty?
      pbReadyOrNotVisual(user,entries,charging)
    end

    def pbReadyOrNotSpriteValid(s)
      s && !s.disposed? && s.bitmap && !s.bitmap.disposed? &&
        s.src_rect.width > 0 && s.src_rect.height > 0
    end

    def pbReadyOrNotHideHP
      return unless @ready_or_not_boxes && @sprites
      @sprites.each do |key,s|
        next unless key.to_s.start_with?("dataBox_") && s && !s.disposed?
        @ready_or_not_boxes[s.object_id] ||= [s,s.visible]
        s.visible = false
      end
    end

    def pbGraphicsUpdate
      pbReadyOrNotHideHP if @ready_or_not_boxes
      super
    end

    def pbReadyOrNotVisual(user,targets,charging)
      sprites,bitmaps,hidden = [],[],{}
      @ready_or_not_boxes = {}
      begin
        @briefMessage = false
        pbReadyOrNotHideHP
        bitmaps.concat(ReadyOrNotVisual.assets)
        star_b,ring_b,mote_b,puff_b,signal_b = bitmaps
        make = proc do |bmp,ox,oy,z|
          s = Sprite.new(@viewport); sprites << s
          s.bitmap,s.ox,s.oy,s.z = bmp,ox,oy,z
          s.opacity = 0
          s
        end
        # Copy only the displayed frame; keep its exact scale and origin.
        snapshot = proc do |src,z,force|
          rect = src.src_rect
          bmp = Bitmap.new(rect.width,rect.height); bitmaps << bmp
          bmp.blt(0,0,src.bitmap,rect)
          s = make.call(bmp,src.ox,src.oy,z)
          s.x,s.y,s.zoom_x,s.zoom_y = src.x,src.y,src.zoom_x,src.zoom_y
          s.angle,s.mirror = src.angle,src.mirror
          s.color,s.tone = src.color.clone,src.tone.clone
          s.visible = force || src.visible
          s.opacity = force && src.opacity == 0 ? 255 : src.opacity
          hidden[src.object_id] ||= [src,src.visible]
          src.visible = false
          s
        end
        src = @sprites["pokemon_#{user.index}"]
        ax,ay = src.x,src.y
        acx = ax+(src.src_rect.width/2.0-src.ox)*src.zoom_x
        acy = ay+(src.src_rect.height/2.0-src.oy)*src.zoom_y
        was_hidden = !src.visible || src.opacity == 0 ||
          (src.respond_to?(:vanishMode) && src.vanishMode > 0)
        actor = snapshot.call(src,20_015,!charging)
        base_opacity = actor.opacity
        shadow = @sprites["shadow_#{user.index}"]
        hidden[shadow.object_id] = [shadow,shadow.visible] if shadow && !shadow.disposed?
        signals = Array.new(3) { make.call(signal_b,8,34,20_024) }
        motes = Array.new(28) { make.call(mote_b,6,6,20_028) }
        puffs = Array.new(10) { make.call(puff_b,28,28,20_021) }
        ring = make.call(ring_b,72,72,20_025)
        groups = charging ? [] : targets.map do |b|
          target = @sprites["pokemon_#{b.index}"]
          copy = snapshot.call(target,20_014,false)
          { :x=>target.x, :y=>target.y,
            :cx=>target.x+(target.src_rect.width/2.0-target.ox)*target.zoom_x,
            :cy=>target.y+(target.src_rect.height/2.0-target.oy)*target.zoom_y,
            :copy=>copy, :color=>target.color.clone,
            :star=>make.call(star_b,56,56,20_030),
            :ring=>make.call(ring_b,72,72,20_027),
            :motes=>Array.new(20) { make.call(mote_b,6,6,20_031) } }
        end
        duration = charging ? ReadyOrNotVisual::CHARGE_DURATION : ReadyOrNotVisual::ATTACK_DURATION
        cues = charging ? ReadyOrNotVisual::CHARGE_CUES : ReadyOrNotVisual::ATTACK_CUES
        frames = [(Graphics.frame_rate*duration).round,2].max
        cue_index = 0
        frames.times do |f|
          t = f.to_f/(frames-1)
          while cue_index < cues.size && t >= cues[cue_index][0]
            ReadyOrNotVisual.sound(cues[cue_index]); cue_index += 1
          end
          if charging
            fade = ReadyOrNotVisual.clamp((t-0.48)/0.30)
            actor.opacity = (base_opacity*(1-fade)).round
            actor.x = ax+Math.sin(t*20)*fade*5
            signals.each_with_index do |s,i|
              q = (t-0.04-i*0.14)/0.24
              s.x = acx+(i-1)*23; s.y = acy-src.src_rect.height*src.zoom_y*0.45-12
              s.opacity = q >= 0 && q <= 1 ? (Math.sin(q*Math::PI)*255).round : 0
            end
            cx,cy = acx,acy
            p = (t-0.51)/0.43
          else
            cx,cy = groups[0].values_at(:cx,:cy)
            direction = cx >= acx ? 1 : -1
            # Emerge beside the target, jab once, then fade home.
            appear = ReadyOrNotVisual.clamp(t/0.18)
            jab = ReadyOrNotVisual.clamp((t-0.18)/0.16)
            if t < 0.62
              actor.x = cx+(ax-acx)-direction*(64-jab*34)
              actor.y = cy+(ay-acy)
              actor.opacity = (base_opacity*appear*ReadyOrNotVisual.clamp((0.62-t)/0.18)).round
            else
              actor.x,actor.y = ax,ay
              actor.opacity = was_hidden ? 0 : (base_opacity*ReadyOrNotVisual.clamp((t-0.76)/0.24)).round
            end
            p = (t-0.04)/0.30
            groups.each do |g|
              q = (t-0.34)/0.39
              v = ReadyOrNotVisual.clamp(q)
              intensity = q >= 0 && q <= 1 ? 1-v : 0
              hit = g[:star]
              hit.x,hit.y = g[:cx],g[:cy]
              hit.zoom_x = hit.zoom_y = 0.40+v*0.95
              hit.angle = -12+v*24
              hit.opacity = (intensity**1.5*255).round
              halo = g[:ring]; halo.x,halo.y = g[:cx],g[:cy]
              halo.zoom_x = halo.zoom_y = 0.20+v*1.15
              halo.opacity = (intensity*210).round
              knock = Math.sin(v*Math::PI)*10
              g[:copy].x = g[:x]+direction*knock+Math.sin(t*130)*intensity*3
              g[:copy].y = g[:y]-knock*0.25
              g[:copy].color = intensity > 0 ? Color.new(255,240,183,(intensity*100).round) : g[:color]
              g[:motes].each_with_index do |s,i|
                a = i*2.399; r = 8+v*(38+i%5*12)
                s.x = g[:cx]+Math.cos(a)*r
                s.y = g[:cy]+Math.sin(a)*r*0.72+v*v*16
                s.angle = i*29+v*100
                s.opacity = (intensity*230).round
              end
            end
          end
          v = ReadyOrNotVisual.clamp(p)
          envelope = p >= 0 && p <= 1 ? Math.sin(v*Math::PI) : 0
          ring.x,ring.y = cx,cy
          ring.zoom_x = ring.zoom_y = 0.2+v*0.8
          ring.opacity = (envelope*190).round
          puffs.each_with_index do |s,i|
            a = i*Math::PI/5; r = 8+v*(35+i%3*10)
            s.x = cx+Math.cos(a)*r; s.y = cy+Math.sin(a)*r*0.65
            s.zoom_x = s.zoom_y = 0.4+v*0.7
            s.opacity = (envelope*165).round
          end
          motes.each_with_index do |s,i|
            a = i*2.399; r = 12+v*(45+i%4*11)
            s.x = cx+Math.cos(a)*r; s.y = cy+Math.sin(a)*r*0.75-v*14
            s.angle = i*31+v*90
            s.opacity = (envelope*215).round
          end
          hidden.each_value { |s,_| s.visible = false unless s.disposed? }
          pbUpdate
        end
      ensure
        boxes = @ready_or_not_boxes; @ready_or_not_boxes = nil
        boxes.each_value { |s,v| s.visible = v unless s.disposed? } if boxes
        hidden.each_value { |s,v| s.visible = v unless s.disposed? }
        sprites.reverse_each { |s| s.dispose unless s.disposed? }
        bitmaps.each { |b| b.dispose unless b.disposed? }
      end
    end
  end
end
Battle::Scene.prepend(ReadyOrNotVisual::SceneHooks)
