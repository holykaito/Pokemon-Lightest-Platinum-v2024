#===============================================================================
# ICE RING - Casting animation
# Pokemon Essentials v21.1
#===============================================================================
module KaitoIceRingAnimation
  DURATION = 2.8

  def self.clamp(value)
    return [[value, 0.0].max, 1.0].min
  end

  def self.ease(value)
    value = clamp(value)
    return value * value * (3.0 - 2.0 * value)
  end

  # Small drawing helpers; no external graphics required.
  def self.line(bitmap, x1, y1, x2, y2, color, width = 1)
    dx = x2 - x1
    dy = y2 - y1
    steps = [dx.abs, dy.abs, 1].max.ceil
    steps.times do |i|
      t = i.to_f / steps
      bitmap.fill_rect(
        (x1 + dx * t).round - width / 2,
        (y1 + dy * t).round - width / 2,
        width, width, color
      )
    end
  end

  def self.glint(bitmap, x, y, size, alpha)
    return if size <= 0 || alpha <= 0
    color = Color.new(225, 255, 255, alpha.to_i)
    line(bitmap, x - size, y, x + size, y, color)
    line(bitmap, x, y - size, x, y + size, color)
    bitmap.fill_rect(x.to_i - 1, y.to_i - 1, 3, 3, color)
  end

  def self.crystal(bitmap, x, y, height, alpha)
    return if height <= 0 || alpha <= 0
    width = [height * 0.28, 2].max
    tip_y = y - height

    height.ceil.times do |i|
      progress = i / [height, 1.0].max
      half = width * Math.sin(progress * Math::PI)
      bitmap.fill_rect(
        (x - half).round, (tip_y + i).round,
        [(half * 2).round, 1].max, 1,
        Color.new(85, 180, 235, (alpha * 0.72).to_i)
      )
    end

    edge = Color.new(195, 245, 255, alpha.to_i)
    line(bitmap, x, tip_y, x - width, y - height * 0.45, edge)
    line(bitmap, x - width, y - height * 0.45, x, y, edge)
    line(bitmap, x, tip_y, x + width, y - height * 0.45, edge)
    line(bitmap, x + width, y - height * 0.45, x, y, edge)
    line(bitmap, x, tip_y, x, y,
         Color.new(245, 255, 255, alpha.to_i))
  end

  def self.play(scene, battle, user)
    return if !scene.respond_to?(:sprites)
    return if !scene.respond_to?(:viewport)

    opponents = battle.allBattlers.select do |battler|
      !battler.fainted? && battler.opposes?(user.index)
    end
    return if opponents.empty?

    positions = opponents.map do |battler|
      Battle::Scene.pbBattlerPosition(
        battler.index, battle.pbSideSize(battler.index)
      )
    end

    cx = positions.sum { |pos| pos[0] }.to_f / positions.length
    cy = positions.sum { |pos| pos[1] }.to_f / positions.length

    # Wider ring for a side with multiple active Pokemon.
    spread = positions.map { |pos| pos[0] }.minmax
    near_side = opponents.first.index.even?
    rx = (near_side ? 100.0 : 78.0) + (spread[1] - spread[0]) / 2.0
    ry = near_side ? 29.0 : 21.0
    cy -= 3

    pokemon_sprites = opponents.map do |battler|
      scene.sprites["pokemon_#{battler.index}"]
    end.compact
    return if pokemon_sprites.empty?

    layers = []
    begin
      2.times do |i|
        sprite = Sprite.new(scene.viewport)
        layers << sprite
        sprite.bitmap = Bitmap.new(Graphics.width, Graphics.height)
        sprite.z = if i == 0
                     pokemon_sprites.map(&:z).min - 1
                   else
                     pokemon_sprites.map(&:z).max + 1
                   end
      end

      # Local deterministic particles: does not consume battle RNG.
      random = Random.new(7341)
      particles = Array.new(38) do
        [
          random.rand * Math::PI * 2,
          0.3 + random.rand * 0.9,
          random.rand,
          1 + random.rand(3)
        ]
      end

      frames = [(Graphics.frame_rate * DURATION).round, 1].max

      frames.times do |frame|
        t = frame.to_f / frames
        layers.each { |sprite| sprite.bitmap.clear }

        fade = 1.0 - ease((t - 0.80) / 0.20)
        form = ease((t - 0.16) / 0.35)
        radius = 0.82 + form * 0.18

        # Two luminous arcs grow in opposite directions.
        128.times do |i|
          angle = i * Math::PI * 2 / 128
          distance = [angle, Math::PI * 2 - angle].min
          next if distance > form * Math::PI

          x = cx + Math.cos(angle) * rx * radius
          y = cy + Math.sin(angle) * ry * radius
          next_angle = angle + Math::PI * 2 / 128
          nx = cx + Math.cos(next_angle) * rx * radius
          ny = cy + Math.sin(next_angle) * ry * radius
          bitmap = layers[Math.sin(angle) < 0 ? 0 : 1].bitmap

          alpha = (210 * fade).to_i
          line(bitmap, x, y, nx, ny,
               Color.new(75, 175, 255, (alpha * 0.22).to_i), 9)
          line(bitmap, x, y, nx, ny,
               Color.new(110, 220, 255, (alpha * 0.65).to_i), 4)
          line(bitmap, x, y, nx, ny,
               Color.new(230, 255, 255, alpha), 2)
        end

        # Ice crystals rise successively around the completed ring.
        18.times do |i|
          angle = i * Math::PI * 2 / 18
          growth = ease((t - 0.36 - i * 0.008) / 0.17)
          next if growth <= 0

          x = cx + Math.cos(angle) * rx
          y = cy + Math.sin(angle) * ry
          height = (13 + (i * 7 % 17)) * growth
          height *= 0.8 if !near_side
          bitmap = layers[Math.sin(angle) < 0 ? 0 : 1].bitmap
          crystal(bitmap, x, y, height, 235 * fade)

          # A moving highlight travels around the ice.
          sweep = (t - 0.53) * 3.0
          shine = 1.0 - ((i / 18.0 - sweep).abs / 0.10)
          if shine > 0 && t > 0.53
            glint(bitmap, x, y - height, 5 * shine, 255 * shine * fade)
          end
        end

        # Low drifting frost, followed by rising snow dust.
        particles.each_with_index do |particle, i|
          angle, radial, phase, size = particle
          angle += t * (i.even? ? 0.8 : -0.6)
          x = cx + Math.cos(angle) * rx * radial
          y = cy + Math.sin(angle) * ry * radial
          lift = t > 0.70 ? ease((t - 0.70) / 0.30) * 35 : 0
          y -= lift + Math.sin(t * 8 + phase * 6) * 5

          alpha = 100 * ease(t / 0.15) * fade
          bitmap = layers[Math.sin(angle) < 0 ? 0 : 1].bitmap
          bitmap.fill_rect(
            x.round, y.round, size * 2, size,
            Color.new(180, 230, 255, alpha.to_i)
          )
          glint(bitmap, x, y, size + 1, alpha) if i % 5 == 0
        end

        Graphics.update
        Input.update
        scene.pbUpdate
      end
    ensure
      layers.each do |sprite|
        next if sprite.disposed?
        bitmap = sprite.bitmap
        sprite.dispose
        bitmap.dispose if bitmap && !bitmap.disposed?
      end
    end
  end
end

#===============================================================================
# Call the animation when Ice Ring is used.
# No aliases or changes to the hazard's gameplay effects.
#===============================================================================
class Battle::Move::AddIceRingToFoeSide
  def pbShowAnimation(id, user, targets, hitNum = 0, showAnimation = true)
    return if !showAnimation
    return if !@battle.showAnims
    KaitoIceRingAnimation.play(@battle.scene, @battle, user)
  end
end