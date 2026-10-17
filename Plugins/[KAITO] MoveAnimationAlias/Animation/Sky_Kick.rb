# Sky Kick animation - Pokemon Essentials v21.1
# Place this .rb in an existing plugin folder, e.g. Plugins/[KAITO] Plugin/.
# No PNG, sound file, PBS change or animation editor import is needed.
module SkyKickVisual
  MOVE_ID = :SKYKICK
  DURATION = 1.65

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
      b.fill_rect(x + 15, 24 - h, 1, h * 2, Color.new(80, 202, 255, x * 1.6))
      b.fill_rect(x + 15, 22, 1, 4, Color.new(225, 250, 255, x * 2))
    end
    disc(b, 135, 24, 10, Color.new(215, 248, 255, 230))
    b
  end

  def self.burst
    b = Bitmap.new(192, 192)
    32.downto(1) do |r|
      disc(b, 96, 96, r + 12, Color.new(85, 198, 255, 4))
    end
    12.times do |i|
      a = i * Math::PI / 6
      64.times do |r|
        x = (96 + Math.cos(a) * r).round
        y = (96 + Math.sin(a) * r).round
        size = r < 24 ? 5 : 3
        b.fill_rect(x, y, size, size, Color.new(178, 237, 255, 255 - r * 3))
      end
    end
    disc(b, 96, 96, 19, Color.new(240, 253, 255, 255))
    b
  end

  module SceneHooks
    def pbAnimation(moveID, user, targets, hitNum = 0)
      return super unless moveID == SkyKickVisual::MOVE_ID
      return if @battle && !@battle.showAnims
      target = targets.is_a?(Array) ? targets[0] : targets
      attacker = user && @sprites["pokemon_#{user.index}"]
      defender = target && @sprites["pokemon_#{target.index}"]
      return super unless attacker && defender && attacker.bitmap && defender.bitmap
      pbSkyKickVisual(attacker, defender, user.index)
    end

    def pbSkyKickVisual(attacker, defender, user_index)
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
        veil.bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(10, 30, 52))
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
        peak_y = [sy, ty].min - Graphics.height * 0.40
        streak_bitmap = SkyKickVisual.streak
        burst_bitmap = SkyKickVisual.burst
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
        history = []
        frames = [(Graphics.frame_rate * SkyKickVisual::DURATION).round, 2].max
        frames.times do |f|
          t = f.to_f / (frames - 1)
          if t < 0.32
            p = t / 0.32
            ease = 1 - (1 - p) ** 2
            x = sx + (peak_x - sx) * ease
            y = sy + (peak_y - sy) * ease
          elsif t < 0.62
            p = (t - 0.32) / 0.30
            x = peak_x + (tx - peak_x) * p * p
            y = peak_y + (ty - peak_y) * p * p
          elsif t < 0.75
            x, y = tx, ty
          else
            p = (t - 0.75) / 0.25
            ease = p * p * (3 - 2 * p)
            x = tx + (sx - tx) * ease
            y = ty + (sy - ty) * ease - Math.sin(p * Math::PI) * 22
          end
          actor.x, actor.y = x, y
          veil.opacity = (55 * Math.sin(t * Math::PI)).round
          history.unshift([x, y - attacker.src_rect.height * attacker.zoom_y * 0.35])
          history.pop if history.length > 12
          trails.each_with_index do |s, i|
            point = history[[i + 1, history.length - 1].min]
            newer = history[[i, history.length - 1].min]
            s.x, s.y = point
            s.angle = -Math.atan2(newer[1] - point[1], newer[0] - point[0]) * 180 / Math::PI
            s.zoom_x = 0.35 + (9 - i) * 0.045
            s.zoom_y = 0.35 + (9 - i) * 0.025
            s.opacity = (t < 0.62) ? (160 - i * 16) : 0
          end
          impact = (t - 0.62) / 0.19
          burst.visible = impact >= 0 && impact <= 1
          if burst.visible
            burst.zoom_x = burst.zoom_y = 0.45 + impact * 1.15
            burst.opacity = ((1 - impact) * 255).round
            defender.x = original_target_x + Math.sin(impact * Math::PI * 8) * 7 * (1 - impact)
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
Battle::Scene.prepend(SkyKickVisual::SceneHooks)
