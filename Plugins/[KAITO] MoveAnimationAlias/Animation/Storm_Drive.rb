# Storm Drive - Pokemon Essentials v21.1
# Install this single .rb in an existing plugin folder, then recompile.
# TwoTurnMove sends hitNum=1 for charge, hitNum=0 for attack.
# Visuals only: no changes to rain, Power Herb, damage or turn mechanics.
module StormDriveVisual
  MOVE_ID = :STORMDRIVE
  CHARGE_SECONDS = 1.95
  ATTACK_SECONDS = 1.40

  def self.ellipse(b, cx, cy, rx, ry, c)
    (-ry..ry).each do |y|
      half = (rx * Math.sqrt([1 - y * y.to_f / (ry * ry), 0].max)).floor
      b.fill_rect(cx - half, cy + y, half * 2 + 1, 1, c)
    end
  end

  def self.line(b, x1, y1, x2, y2, width, c)
    steps = [(x2 - x1).abs, (y2 - y1).abs, 1].max
    (0..steps).each do |i|
      p = i.to_f / steps
      x = (x1 + (x2 - x1) * p).round
      y = (y1 + (y2 - y1) * p).round
      b.fill_rect(x - width / 2, y - width / 2, width, width, c)
    end
  end

  def self.bolt
    b = Bitmap.new(112, 208)
    points = (0..10).map { |i| [56 + ((i * 37) % 47) - 23, 8 + i * 19] }
    [11, 6, 2].each do |width|
      color = case width
              when 11 then Color.new(67, 139, 255, 80)
              when 6 then Color.new(104, 213, 255, 210)
              else Color.new(255, 252, 211, 255)
              end
      points.each_cons(2) { |a, z| line(b, a[0], a[1], z[0], z[1], width, color) }
    end
    line(b, points[4][0], points[4][1], 96, 130, 3, Color.new(255, 214, 80, 230))
    line(b, 96, 130, 79, 159, 2, Color.new(255, 249, 210, 255))
    b
  end

  def self.ring
    b = Bitmap.new(192, 192)
    [67, 73, 78].each do |r|
      360.times do |i|
        next if r == 78 && i % 60 > 39
        a = i * Math::PI / 180
        x = (96 + Math.cos(a) * r).round
        y = (96 + Math.sin(a) * r).round
        b.fill_rect(x, y, 3, 3, Color.new(104, 215, 255, r == 73 ? 230 : 100))
      end
    end
    b
  end

  def self.cloud
    b = Bitmap.new(320, 112)
    8.downto(1) do |j|
      [[66, 62, 43, 16], [124, 42, 57, 27], [185, 51, 64, 22], [256, 65, 45, 15]].each do |x,y,rx,ry|
        ellipse(b, x, y, rx + j, ry + j, Color.new(17, 25, 49, 13))
      end
    end
    b
  end

  def self.glow
    b = Bitmap.new(160, 160)
    32.downto(1) { |i| ellipse(b, 80, 80, i * 2 + 6, i * 2 + 6, Color.new(63, 177, 255, 4)) }
    ellipse(b, 80, 80, 18, 18, Color.new(220, 248, 255, 180))
    b
  end

  def self.spark
    b = Bitmap.new(24, 24)
    line(b, 12, 1, 12, 23, 2, Color.new(255, 225, 103, 240))
    line(b, 1, 12, 23, 12, 2, Color.new(255, 248, 195, 255))
    b
  end

  module SceneHooks
    def pbAnimation(moveID, user, targets, hitNum = 0)
      return super unless moveID == StormDriveVisual::MOVE_ID
      return if @battle && !@battle.showAnims
      target = targets.is_a?(Array) ? targets[0] : targets
      attacker = user && @sprites["pokemon_#{user.index}"]
      defender = target && @sprites["pokemon_#{target.index}"]
      return super unless attacker && !attacker.disposed? && attacker.bitmap
      charging = hitNum == 1
      return super if !charging && (!defender || defender.disposed? || !defender.bitmap)
      pbStormDriveVisual(attacker, defender, user.index, charging)
    end

    def pbStormDriveVisual(attacker, defender, user_index, charging)
      sprites, bitmaps = [], []
      visible = attacker.visible
      old_tx, old_ty = defender.x, defender.y if defender
      shadow = @sprites["shadow_#{user_index}"]
      old_shadow = shadow.visible if shadow
      begin
        @briefMessage = false
        center_y = (attacker.src_rect.height / 2.0 - attacker.oy) * attacker.zoom_y
        center_x = (attacker.src_rect.width / 2.0 - attacker.ox) * attacker.zoom_x
        sx, sy = attacker.x.to_f, attacker.y.to_f
        cx, cy = sx + center_x, sy + center_y
        tx = defender ? defender.x + (defender.src_rect.width / 2.0 - defender.ox) * defender.zoom_x : cx
        ty = defender ? defender.y + (defender.src_rect.height / 2.0 - defender.oy) * defender.zoom_y : cy
        make = proc do |bitmap, ox, oy, z|
          s = Sprite.new(@viewport)
          sprites << s
          s.bitmap = bitmap
          s.ox, s.oy, s.z = ox, oy, z
          s
        end
        shade_b = Bitmap.new(Graphics.width, Graphics.height)
        shade_b.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(5, 13, 32))
        flash_b = Bitmap.new(Graphics.width, Graphics.height)
        flash_b.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(181, 226, 255))
        bolt_b, ring_b = StormDriveVisual.bolt, StormDriveVisual.ring
        cloud_b, glow_b, spark_b = StormDriveVisual.cloud, StormDriveVisual.glow, StormDriveVisual.spark
        bitmaps.concat([shade_b, flash_b, bolt_b, ring_b, cloud_b, glow_b, spark_b])
        shade = make.call(shade_b, 0, 0, 19_990)
        flash = make.call(flash_b, 0, 0, 20_040)
        glow = make.call(glow_b, 80, 80, 20_005)
        glow.blend_type = 1
        clouds = Array.new(3) { make.call(cloud_b, 160, 56, 20_000) }
        bolts = Array.new(5) do
          s = make.call(bolt_b, 56, 198, 20_025)
          s.blend_type = 1
          s
        end
        rings = Array.new(4) do
          s = make.call(ring_b, 96, 96, 20_020)
          s.blend_type = 1
          s
        end
        sparks = Array.new(24) do
          s = make.call(spark_b, 12, 12, 20_030)
          s.blend_type = 1
          s
        end
        actor = nil
        echoes = []
        unless charging
          actor_b = attacker.bitmap.clone
          bitmaps << actor_b
          ([0] + [1, 2, 3, 4]).each do |i|
            s = make.call(actor_b, attacker.ox, attacker.oy, i == 0 ? 20_015 : 20_010 - i)
            s.src_rect.set(attacker.src_rect.x, attacker.src_rect.y, attacker.src_rect.width, attacker.src_rect.height)
            s.zoom_x, s.zoom_y, s.mirror = attacker.zoom_x, attacker.zoom_y, attacker.mirror
            s.tone = attacker.tone.clone
            if i == 0
              s.opacity = attacker.opacity
              s.color = attacker.color.clone
              actor = s
            else
              s.color = Color.new(64, 195, 255, 170)
              echoes << s
            end
          end
          attacker.visible = false
          shadow.visible = false if shadow
        end
        duration = charging ? StormDriveVisual::CHARGE_SECONDS : StormDriveVisual::ATTACK_SECONDS
        frames = [(Graphics.frame_rate * duration).round, 2].max
        history = []
        frames.times do |f|
          t = f.to_f / (frames - 1)
          fade = [[t / 0.15, (1 - t) / 0.20, 1].min, 0].max
          shade.opacity = (fade * (charging ? 155 : 115)).round
          if charging
            x, y = cx, cy
            glow.x, glow.y = x, y
            glow.zoom_x = glow.zoom_y = 0.7 + t * 0.65
            glow.opacity = (fade * (100 + 45 * Math.sin(t * 35))).round
            clouds.each_with_index do |s, i|
              s.x = cx + (i - 1) * 90 + Math.sin(t * 5 + i) * 18
              s.y = [cy - 120, 40].max + i * 9
              s.opacity = (fade * 215).round
            end
            rings.each_with_index do |s, i|
              p = (t * 1.5 + i * 0.25) % 1.0
              s.x = cx + Math.sin(p * 6.28) * 7
              s.y = cy + 45 - p * 125
              s.zoom_x = 0.25 + (1 - p) * 0.7
              s.zoom_y = s.zoom_x * 0.30
              s.angle = Math.sin(t * 4) * 12
              s.opacity = (Math.sin(p * Math::PI) * fade * 215).round
            end
            bolts.each_with_index do |s, i|
              s.x = cx + Math.sin(i * 2.2 + t * 12) * 45 * (1 - t * 0.7)
              s.y = cy + 18
              s.angle = (i - 2) * 9
              s.zoom_x = 0.6
              s.zoom_y = 0.65 + i * 0.03
              pulse = ((t * 17 + i * 0.27) % 1) < 0.24
              s.opacity = pulse ? (fade * 235).round : 0
            end
            flash.opacity = (t > 0.30 && t < 0.80 && (t * 12) % 1 < 0.07) ? 45 : 0
          else
            # The duplicated sprite's centre reaches the defender's centre.
            if t < 0.14
              p = t / 0.14
              x = cx - (tx >= cx ? 1 : -1) * p * 18
              y = cy
            elsif t < 0.53
              p = (t - 0.14) / 0.39
              e = p * p
              x = cx + (tx - cx) * e
              y = cy + (ty - cy) * e - Math.sin(p * Math::PI) * 20
            elsif t < 0.73
              x, y = tx, ty
            else
              p = (t - 0.73) / 0.27
              e = p * p * (3 - 2 * p)
              x, y = tx + (cx - tx) * e, ty + (cy - ty) * e
            end
            actor.x, actor.y = x - center_x, y - center_y
            history.unshift([actor.x, actor.y])
            history.pop if history.length > 18
            echoes.each_with_index do |s, i|
              p = history[[(i + 1) * 2, history.length - 1].min]
              s.x, s.y = p
              s.opacity = (t >= 0.14 && t < 0.56) ? 115 - i * 22 : 0
            end
            clouds.each { |s| s.visible = false }
            impact = (t - 0.53) / 0.29
            flash.opacity = impact >= 0 && impact < 0.17 ? ((1 - impact / 0.17) * 125).round : 0
            glow.x, glow.y = x, y
            glow.zoom_x = glow.zoom_y = impact >= 0 && impact <= 1 ? 1.2 + impact * 2.2 : 1.1
            glow.opacity = t < 0.53 ? (fade * 215).round : (impact <= 1 ? ((1 - impact) * 220).round : 0)
            rings.each_with_index do |s, i|
              if t < 0.53
                p = [[(t - 0.14) / 0.39, 0].max, 1].min
                s.x, s.y = x - (tx - cx) * (i * 0.045), y - (ty - cy) * (i * 0.045)
                s.zoom_x, s.zoom_y = 0.5 + i * 0.12, 0.30 + i * 0.08
                s.angle = -Math.atan2(ty - cy, tx - cx) * 180 / Math::PI + 90
                s.opacity = (fade * (170 - i * 25)).round
              else
                s.x, s.y = tx, ty
                s.zoom_x = s.zoom_y = 0.25 + [impact, 0].max * (1.5 + i * 0.40)
                s.angle = i * 17 + t * 90
                s.opacity = impact <= 1 ? ((1 - impact) * (200 - i * 25)).round : 0
              end
            end
            bolts.each_with_index do |s, i|
              if t < 0.53
                s.x, s.y = x, y
                s.angle = -Math.atan2(ty - cy, tx - cx) * 180 / Math::PI + 90 + (i - 2) * 5
                s.zoom_x, s.zoom_y = 0.40, 0.9 + i * 0.08
                s.opacity = t >= 0.14 && (f + i) % 3 != 0 ? 200 : 0
              else
                s.x, s.y = tx, ty
                s.angle = i * 72 + t * 30
                s.zoom_x = 0.45
                s.zoom_y = 0.3 + [impact, 0].max * 0.8
                s.opacity = impact <= 1 && (f + i) % 3 != 0 ? ((1 - impact) * 240).round : 0
              end
            end
            if defender && impact >= 0 && impact <= 1
              defender.x = old_tx + Math.sin(impact * Math::PI * 12) * 8 * (1 - impact)
              defender.y = old_ty + Math.cos(impact * Math::PI * 10) * 3 * (1 - impact)
            elsif defender
              defender.x, defender.y = old_tx, old_ty
            end
          end
          sparks.each_with_index do |s, i|
            a = i * 2.399 + t * (charging ? 6 : 2)
            r = charging ? (1 - t) * (65 + i % 5 * 9) + 12 : 22 + i % 4 * 7
            if !charging && t >= 0.53
              p = [[(t - 0.53) / 0.35, 0].max, 1].min
              r = 12 + p * (65 + i % 5 * 16)
              s.opacity = ((1 - p) * 255).round
              s.x, s.y = tx + Math.cos(a) * r, ty + Math.sin(a) * r
            else
              s.x, s.y = x + Math.cos(a) * r, y + Math.sin(a) * r * 0.7
              s.opacity = (fade * (140 + 75 * Math.sin(i + t * 25))).round
            end
            s.zoom_x = s.zoom_y = 0.20 + i % 4 * 0.10
            s.angle = t * 120 + i * 20
          end
          pbUpdate
        end
      ensure
        attacker.visible = visible unless attacker.disposed?
        shadow.visible = old_shadow if shadow && !shadow.disposed?
        defender.x, defender.y = old_tx, old_ty if defender && !defender.disposed?
        sprites.reverse_each { |s| s.dispose unless s.disposed? }
        bitmaps.each { |b| b.dispose unless b.disposed? }
      end
    end
  end
end
Battle::Scene.prepend(StormDriveVisual::SceneHooks)
