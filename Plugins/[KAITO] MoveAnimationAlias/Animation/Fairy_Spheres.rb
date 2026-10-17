# Fairy Spheres - Pokemon Essentials v21.1
# Put in an existing plugin folder. No external images/audio or PBS edits.
# Each engine hit plays ONE projectile. Only hitNum 0 includes the charge-up.
module FairySpheresVisual
  MOVE_IDS = [:FAIRYSPHERES, :FAIRYSPHERE]
  FIRST_DURATION = 1.15
  REPEAT_DURATION = 0.60

  def self.disc(b, cx, cy, r, color)
    (-r..r).each do |dy|
      dx = Math.sqrt([r * r - dy * dy, 0].max).floor
      b.fill_rect(cx - dx, cy + dy, dx * 2 + 1, 1, color)
    end
  end

  def self.orb
    b = Bitmap.new(80, 80)
    18.downto(1) do |i|
      disc(b, 40, 40, 18 + i, Color.new(239, 119, 218, 5))
    end
    disc(b, 40, 40, 19, Color.new(153, 104, 211, 240))
    disc(b, 39, 38, 17, Color.new(237, 164, 230, 255))
    disc(b, 37, 36, 13, Color.new(255, 212, 244, 255))
    disc(b, 34, 32, 8, Color.new(255, 240, 253, 255))
    disc(b, 33, 30, 4, Color.new(255, 255, 255, 255))
    disc(b, 47, 47, 3, Color.new(217, 183, 255, 240))
    b
  end

  def self.star
    b = Bitmap.new(32, 32)
    13.times do |i|
      width = [1, ((13 - i) / 3.0).round].max
      c = Color.new(255, 223, 251, 250 - i * 8)
      b.fill_rect(16 - width, 16 - i, width * 2 + 1, 1, c)
      b.fill_rect(16 - width, 16 + i, width * 2 + 1, 1, c)
      b.fill_rect(16 - i, 16 - width, 1, width * 2 + 1, c)
      b.fill_rect(16 + i, 16 - width, 1, width * 2 + 1, c)
    end
    b
  end

  def self.ring
    b = Bitmap.new(128, 128)
    [42, 44, 47].each do |r|
      360.times do |i|
        a = i * Math::PI / 180
        x, y = (64 + Math.cos(a) * r).round, (64 + Math.sin(a) * r).round
        b.fill_rect(x, y, 2, 2, Color.new(255, 178, 233, r == 44 ? 240 : 110))
      end
    end
    b
  end

  def self.point(p, sx, sy, mx, my, tx, ty)
    q = 1 - p
    [q * q * sx + 2 * q * p * mx + p * p * tx,
     q * q * sy + 2 * q * p * my + p * p * ty]
  end

  module SceneHooks
    def pbAnimation(moveID, user, targets, hitNum = 0)
      return super unless FairySpheresVisual::MOVE_IDS.include?(moveID)
      return if @battle && !@battle.showAnims
      target = targets.is_a?(Array) ? targets[0] : targets
      attacker = user && @sprites["pokemon_#{user.index}"]
      defender = target && @sprites["pokemon_#{target.index}"]
      return super unless attacker && defender && !attacker.disposed? &&
                          !defender.disposed? && attacker.bitmap && defender.bitmap
      pbFairySpheresVisual(attacker, defender, hitNum)
    end

    def pbFairySpheresVisual(attacker, defender, hit_num)
      sprites, bitmaps = [], []
      old_x = defender.x
      begin
        @briefMessage = false
        sx = attacker.x + (attacker.src_rect.width / 2.0 - attacker.ox) * attacker.zoom_x
        sy = attacker.y + (attacker.src_rect.height / 2.0 - attacker.oy) * attacker.zoom_y
        tx = defender.x + (defender.src_rect.width / 2.0 - defender.ox) * defender.zoom_x
        ty = defender.y + (defender.src_rect.height / 2.0 - defender.oy) * defender.zoom_y
        direction = tx >= sx ? 1 : -1
        sx += direction * 30
        mx = (sx + tx) / 2.0
        my = (sy + ty) / 2.0 + (hit_num.even? ? -75 : 28)
        first = hit_num == 0
        duration = first ? FairySpheresVisual::FIRST_DURATION : FairySpheresVisual::REPEAT_DURATION
        charge = first ? 0.43 : 0.0
        travel = first ? 0.44 : 0.36
        orb_bitmap = FairySpheresVisual.orb
        star_bitmap = FairySpheresVisual.star
        ring_bitmap = FairySpheresVisual.ring
        bitmaps.concat([orb_bitmap, star_bitmap, ring_bitmap])
        make_sprite = proc do |bitmap, ox, oy, z|
          s = Sprite.new(@viewport)
          sprites << s
          s.bitmap = bitmap
          s.ox, s.oy, s.z = ox, oy, z
          s
        end
        orb = make_sprite.call(orb_bitmap, 40, 40, 20_010)
        trails = Array.new(7) { make_sprite.call(orb_bitmap, 40, 40, 20_000) }
        satellites = Array.new(4) { make_sprite.call(orb_bitmap, 40, 40, 20_005) }
        stars = Array.new(14) do
          s = make_sprite.call(star_bitmap, 16, 16, 20_020)
          s.blend_type = 1
          s
        end
        ring = make_sprite.call(ring_bitmap, 64, 64, 20_015)
        ring.blend_type = 1
        glow = make_sprite.call(orb_bitmap, 40, 40, 20_016)
        glow.blend_type = 1
        frames = [(Graphics.frame_rate * duration).round, 2].max
        frames.times do |f|
          seconds = f.to_f / (frames - 1) * duration
          p = [[(seconds - charge) / travel, 0].max, 1].min
          charging = first && seconds < charge
          impact = (seconds - charge - travel) / (duration - charge - travel)
          x, y = FairySpheresVisual.point(p, sx, sy, mx, my, tx, ty)
          orb.x, orb.y = x, y
          orb.visible = impact < 0
          orb.zoom_x = orb.zoom_y = charging ? 0.35 + seconds / charge * 0.65 : 1.0
          orb.opacity = 255
          satellites.each_with_index do |s, i|
            s.visible = charging
            next unless charging
            c = seconds / charge
            a = i * Math::PI / 2 + c * Math::PI * 2
            radius = 48 * (1 - c) + 8
            s.x = sx + Math.cos(a) * radius
            s.y = sy + Math.sin(a) * radius * 0.65
            s.zoom_x = s.zoom_y = 0.40
            s.opacity = (Math.sin(c * Math::PI) * 210).round
          end
          trails.each_with_index do |s, i|
            lag = p - (i + 1) * 0.048
            s.visible = !charging && lag >= 0 && impact < 0.28
            next unless s.visible
            s.x, s.y = FairySpheresVisual.point([lag, 1].min, sx, sy, mx, my, tx, ty)
            s.zoom_x = s.zoom_y = 0.45 - i * 0.045
            s.opacity = ((150 - i * 17) * (impact < 0 ? 1 : 1 - impact / 0.28)).round
          end
          ring.visible = impact >= 0
          ring.x, ring.y = tx, ty
          ring.zoom_x = ring.zoom_y = 0.25 + [impact, 0].max * 1.0
          ring.opacity = impact >= 0 ? ((1 - impact) * 210).round : 0
          glow.visible = impact >= 0
          glow.x, glow.y = tx, ty
          glow.zoom_x = glow.zoom_y = 1.1 + [impact, 0].max * 1.5
          glow.opacity = impact >= 0 ? ((1 - impact) ** 2 * 200).round : 0
          stars.each_with_index do |s, i|
            if impact < 0
              a = i * 2.399 + seconds * 3
              radius = charging ? 35 + i % 4 * 8 : 16 + i % 3 * 5
              s.x = x + Math.cos(a) * radius
              s.y = y + Math.sin(a) * radius * 0.7
              s.opacity = (95 + 80 * Math.sin(seconds * 12 + i)).round
              s.zoom_x = s.zoom_y = 0.20 + i % 3 * 0.10
            else
              a = i * Math::PI * 2 / stars.length + hit_num * 0.5
              radius = 12 + impact * (48 + i % 4 * 13)
              s.x = tx + Math.cos(a) * radius
              s.y = ty + Math.sin(a) * radius - impact * 12
              s.opacity = ((1 - impact) * 255).round
              s.zoom_x = s.zoom_y = (0.35 + i % 3 * 0.13) * (1 - impact * 0.6)
            end
            s.angle = seconds * 100 + i * 18
          end
          defender.x = impact >= 0 ? old_x + direction * Math.sin(impact * Math::PI * 4) * 3 * (1 - impact) : old_x
          pbUpdate
        end
      ensure
        defender.x = old_x if defender && !defender.disposed?
        sprites.reverse_each { |s| s.dispose unless s.disposed? }
        bitmaps.each { |b| b.dispose unless b.disposed? }
      end
    end
  end
end
Battle::Scene.prepend(FairySpheresVisual::SceneHooks)
