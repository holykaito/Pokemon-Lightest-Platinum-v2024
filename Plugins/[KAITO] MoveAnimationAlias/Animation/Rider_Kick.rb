# Rider Kick animation - Pokemon Essentials v21.1
# Place this .rb in an existing plugin folder, e.g. Plugins/[KAITO] Plugin/.
# No PNG, sound file, PBS change or animation editor import is needed.
module RiderKickVisual
  MOVE_ID = :RIDERKICK
  DURATION = 2.25

  def self.disc(b, x, y, radius, color)
    (-radius..radius).each do |dy|
      dx = Math.sqrt([radius * radius - dy * dy, 0].max).floor
      b.fill_rect(x - dx, y + dy, dx * 2 + 1, 1, color)
    end
  end

  def self.streak
    b = Bitmap.new(160, 48)
    120.times do |x|
      h = [1, (x / 9.0).round].max
      b.fill_rect(x + 15, 24 - h, 1, h * 2, Color.new(45, 233, 112, (x * 1.6).round))
      b.fill_rect(x + 15, 22, 1, 4, Color.new(231, 255, 163, x * 2))
    end
    disc(b, 135, 24, 10, Color.new(215, 255, 156, 230))
    b
  end

  def self.burst
    b = Bitmap.new(192, 192)
    32.downto(1) do |r|
      disc(b, 96, 96, r + 12, Color.new(255, 151, 35, 4))
    end
    12.times do |i|
      a = i * Math::PI / 6
      64.times do |r|
        x = (96 + Math.cos(a) * r).round
        y = (96 + Math.sin(a) * r).round
        size = r < 24 ? 5 : 3
        b.fill_rect(x, y, size, size, Color.new(255, 188, 65, 255 - r * 3))
      end
    end
    disc(b, 96, 96, 19, Color.new(255, 255, 206, 255))
    b
  end

  # All graphics are built once per playback, then disposed in ensure.
  def self.polygon(b, points, color)
    min_y, max_y = points.map { |p| p[1] }.minmax
    (min_y..max_y).each do |y|
      hits = []
      points.each_with_index do |p, i|
        q = points[(i + 1) % points.length]
        next unless (p[1] <= y && q[1] > y) || (q[1] <= y && p[1] > y)
        hits << p[0] + (y - p[1]).to_f * (q[0] - p[0]) / (q[1] - p[1])
      end
      hits.sort.each_slice(2) do |left, right|
        next unless right
        b.fill_rect(left.ceil, y, [right.floor - left.ceil + 1, 1].max, 1, color)
      end
    end
  end

  def self.ring
    b = Bitmap.new(192, 192)
    [68, 79, 84].each do |r|
      360.times do |i|
        next if r == 84 && i % 45 > 28
        a = i * Math::PI / 180
        x, y = (96 + Math.cos(a) * r).round, (96 + Math.sin(a) * r).round
        b.fill_rect(x - 1, y - 1, 3, 3, Color.new(87, 255, 136, r == 68 ? 240 : 145))
      end
    end
    b
  end

  def self.emblem
    b = Bitmap.new(112, 112)
    green = Color.new(104, 255, 142, 215)
    polygon(b, [[54, 18], [29, 5], [39, 30], [54, 41]], green)
    polygon(b, [[58, 18], [83, 5], [73, 30], [58, 41]], green)
    polygon(b, [[52, 44], [20, 29], [25, 64], [49, 78]], green)
    polygon(b, [[60, 44], [92, 29], [87, 64], [63, 78]], green)
    polygon(b, [[37, 84], [56, 100], [75, 84], [56, 90]], green)
    b
  end

  def self.boot
    b = Bitmap.new(120, 80)
    polygon(b, [[15, 19], [48, 17], [71, 38], [104, 43], [114, 53],
                [110, 66], [60, 66], [37, 53], [15, 50]], Color.new(50, 219, 99, 220))
    polygon(b, [[23, 25], [44, 24], [66, 45], [102, 48], [107, 55],
                [64, 56], [41, 44], [23, 44]], Color.new(223, 255, 162, 245))
    b.fill_rect(61, 61, 47, 4, Color.new(255, 202, 71, 255))
    b
  end

  module SceneHooks
    def pbAnimation(moveID, user, targets, hitNum = 0)
      return super unless moveID == RiderKickVisual::MOVE_ID
      return if @battle && !@battle.showAnims
      target = targets.is_a?(Array) ? targets[0] : targets
      attacker = user && @sprites["pokemon_#{user.index}"]
      defender = target && @sprites["pokemon_#{target.index}"]
      return super unless attacker && defender && attacker.bitmap && defender.bitmap
      pbRiderKickVisual(attacker, defender, user.index)
    end

    def pbRiderKickVisual(attacker, defender, user_index)
      objects = []
      owned_bitmaps = []
      original_visible = attacker.visible
      original_target_x = defender.x
      shadow = @sprites["shadow_#{user_index}"]
      shadow_visible = shadow.visible if shadow
      begin
        @briefMessage = false
        # Use the battle's own viewport, with effect sprites above its battlers.
        veil = Sprite.new(@viewport)
        objects << veil
        veil.bitmap = Bitmap.new(Graphics.width, Graphics.height)
        owned_bitmaps << veil.bitmap
        veil.bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(4, 24, 17))
        veil.z = 19_990
        actor = Sprite.new(@viewport)
        objects << actor
        actor.bitmap = attacker.bitmap.clone
        owned_bitmaps << actor.bitmap
        actor.src_rect.set(attacker.src_rect.x, attacker.src_rect.y,
                           attacker.src_rect.width, attacker.src_rect.height)
        actor.ox = attacker.ox
        actor.oy = attacker.oy
        actor.zoom_x = attacker.zoom_x
        actor.zoom_y = attacker.zoom_y
        actor.mirror = attacker.mirror
        actor.tone = attacker.tone.clone
        actor.color = attacker.color.clone
        actor.opacity = attacker.opacity
        actor.z = 20_010
        attacker.visible = false
        shadow.visible = false if shadow
        sx, sy = attacker.x.to_f, attacker.y.to_f
        tx = defender.x.to_f
        ty = defender.y - defender.src_rect.height * defender.zoom_y * 0.45
        direction = tx >= sx ? 1 : -1
        peak_x = sx - direction * Graphics.width * 0.08
        peak_y = [[sy, ty].min - Graphics.height * 0.32, 58].max
        streak_bitmap = RiderKickVisual.streak
        burst_bitmap = RiderKickVisual.burst
        owned_bitmaps.concat([streak_bitmap, burst_bitmap])
        trails = Array.new(9) do
          s = Sprite.new(@viewport)
          objects << s
          s.bitmap = streak_bitmap
          s.ox = 135
          s.oy = 24
          s.z = 20_000
          s.blend_type = 1
          s
        end
        burst = Sprite.new(@viewport)
        objects << burst
        burst.bitmap = burst_bitmap
        burst.ox = burst.oy = 96
        burst.x, burst.y = tx, ty
        burst.z = 20_020
        burst.blend_type = 1
        ring_bitmap = RiderKickVisual.ring
        emblem_bitmap = RiderKickVisual.emblem
        boot_bitmap = RiderKickVisual.boot
        owned_bitmaps.concat([ring_bitmap, emblem_bitmap, boot_bitmap])
        rings = Array.new(2) do
          r = Sprite.new(@viewport)
          objects << r
          r.bitmap = ring_bitmap
          r.ox = r.oy = 96
          r.z = 20_015
          r.blend_type = 1
          r
        end
        crest = Sprite.new(@viewport)
        objects << crest
        crest.bitmap = emblem_bitmap
        crest.ox = crest.oy = 56
        crest.z = 20_020
        crest.blend_type = 1
        boot = Sprite.new(@viewport)
        objects << boot
        boot.bitmap = boot_bitmap
        boot.ox, boot.oy = 108, 54
        boot.z = 20_018
        boot.blend_type = 1
        kick_angle = -Math.atan2(ty - peak_y, tx - peak_x) * 180 / Math::PI
        history = []
        frames = [(Graphics.frame_rate * RiderKickVisual::DURATION).round, 2].max
        frames.times do |f|
          t = f.to_f / (frames - 1)
          if t < 0.20
            x, y = sx, sy
          elsif t < 0.40
            p = (t - 0.20) / 0.20
            ease = 1 - (1 - p) ** 2
            x = sx + (peak_x - sx) * ease
            y = sy + (peak_y - sy) * ease
          elsif t < 0.48
            x, y = peak_x, peak_y
          elsif t < 0.69
            p = (t - 0.48) / 0.21
            x = peak_x + (tx - peak_x) * p * p
            y = peak_y + (ty - peak_y) * p * p
          elsif t < 0.83
            x, y = tx, ty
          else
            p = (t - 0.83) / 0.17
            ease = p * p * (3 - 2 * p)
            x = tx + (sx - tx) * ease
            y = ty + (sy - ty) * ease - Math.sin(p * Math::PI) * 22
          end
          actor.x, actor.y = x, y
          veil.opacity = (105 * Math.sin(t * Math::PI)).round
          charging = t < 0.20
          crest.visible = charging
          crest.x, crest.y = sx, sy - attacker.src_rect.height * attacker.zoom_y - 33
          crest.opacity = charging ? (220 * Math.sin(t / 0.20 * Math::PI)).round : 0
          crest.zoom_x = crest.zoom_y = 0.8
          actor.angle = (t >= 0.48 && t < 0.83) ? direction * 12 : 0
          boot.visible = t >= 0.48 && t < 0.76
          boot.x, boot.y = x + direction * 10, y - 5
          boot.angle = kick_angle
          boot.zoom_x = boot.zoom_y = 0.7
          boot.opacity = t < 0.69 ? 235 : [(1 - (t - 0.69) / 0.07) * 235, 0].max.round
          rings.each_with_index do |r, i|
            if charging
              p = t / 0.20
              r.visible = true
              r.x, r.y = sx, sy - attacker.src_rect.height * attacker.zoom_y * 0.45
              r.zoom_x = r.zoom_y = 1.0 - p * 0.65 + i * 0.13
              r.angle = t * 450 * (i == 0 ? 1 : -1)
              r.opacity = (180 * Math.sin(p * Math::PI)).round
            elsif t >= 0.48 && t < 0.69
              p = (t - 0.48) / 0.21
              r.visible = true
              r.x = peak_x + (tx - peak_x) * (0.35 + i * 0.30)
              r.y = peak_y + (ty - peak_y) * (0.35 + i * 0.30) - 12
              r.zoom_x, r.zoom_y = 0.55 + p * 0.25, 0.3 + p * 0.15
              r.angle = kick_angle + 90
              r.opacity = (150 * Math.sin(p * Math::PI)).round
            elsif t >= 0.69 && t < 0.88
              p = (t - 0.69) / 0.19
              r.visible = true
              r.x, r.y = tx, ty
              r.zoom_x = r.zoom_y = 0.3 + p * (1.3 + i * 0.4)
              r.angle = p * 120
              r.opacity = ((1 - p) * 180).round
            else
              r.visible = false
            end
          end
          history.unshift([x, y - attacker.src_rect.height * attacker.zoom_y * 0.35])
          history.pop if history.length > 12
          trails.each_with_index do |s, i|
            point = history[[i + 1, history.length - 1].min]
            newer = history[[i, history.length - 1].min]
            s.x, s.y = point
            s.angle = -Math.atan2(newer[1] - point[1], newer[0] - point[0]) * 180 / Math::PI
            s.zoom_x = 0.35 + (9 - i) * 0.045
            s.zoom_y = 0.35 + (9 - i) * 0.025
            s.opacity = (t >= 0.20 && t < 0.69) ? (185 - i * 18) : 0
          end
          impact = (t - 0.69) / 0.19
          burst.visible = impact >= 0 && impact <= 1
          if burst.visible
            burst.zoom_x = burst.zoom_y = 0.45 + impact * 1.15
            burst.opacity = ((1 - impact) * 255).round
            defender.x = original_target_x + Math.sin(impact * Math::PI * 8) * 10 * (1 - impact)
          else
            defender.x = original_target_x
          end
          pbUpdate
        end
      ensure
        attacker.visible = original_visible if attacker && !attacker.disposed?
        defender.x = original_target_x if defender && !defender.disposed?
        shadow.visible = shadow_visible if shadow && !shadow.disposed?
        objects.reverse_each { |s| s.dispose unless s.disposed? }
        owned_bitmaps.each { |b| b.dispose unless b.disposed? }
      end
    end
  end
end
Battle::Scene.prepend(RiderKickVisual::SceneHooks)
