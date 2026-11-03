#===============================================================================
# STARLIGHT RECITAL - Ban hoa tau anh sao
# Pokemon Essentials v21.1 / KAITO Animation Core
# Install: Plugins/[KAITO] MoveAnimationAlias/Animation/Starlight_Recital.rb
# Visual only: HP recovery and status curing remain handled by the move.
#===============================================================================
module KaitoStarlightRecitalVisual
  DURATION = 3.15

  def self.star(a, color)
    a.bitmap(32, 32) do |b|
      a.polygon(b, [[16, 0], [20, 11], [32, 16], [20, 20],
                    [16, 32], [12, 20], [0, 16], [12, 11]], color)
      a.polygon(b, [[16, 7], [18, 14], [25, 16], [18, 18],
                    [16, 25], [14, 18], [7, 16], [14, 14]],
                Color.new(255, 255, 246, 245))
    end
  end

  def self.note(a)
    a.bitmap(34, 42) do |b|
      # Quaver: an oval head, upward stem and a small curved flag.
      a.polygon(b, [[4, 28], [9, 23], [19, 21], [21, 27],
                    [16, 33], [7, 35], [3, 32]],
                Color.new(249, 201, 255, 255))
      a.polygon(b, [[6, 29], [11, 25], [18, 24], [17, 28],
                    [11, 32], [6, 32]], Color.new(255, 250, 255, 240))
      b.fill_rect(19, 5, 3, 23, Color.new(246, 211, 255, 255))
      a.polygon(b, [[20, 5], [26, 9], [31, 17], [28, 23],
                    [26, 17], [22, 13]], Color.new(234, 168, 255, 240))
    end
  end

  def self.glow(a)
    a.bitmap(104, 104) do |b|
      104.times do |y|
        104.times do |x|
          r = Math.sqrt((x - 51.5)**2 + (y - 51.5)**2) / 52.0
          next if r > 1.0
          alpha = ((1.0 - r)**2 * 180).to_i
          b.set_pixel(x, y, Color.new(255, 213, 250, alpha))
        end
      end
    end
  end
end

KaitoAnimation.register(
  :STARLIGHTRECITAL,
  duration: KaitoStarlightRecitalVisual::DURATION,
  require_target: false,
  setup: proc do |a|
    a.sound_at(0.05, ["PRSFX- Relic Song1"], 60, 115)
    a.sound_at(0.73, ["PRSFX- Relic Song2"], 65, 112)
    a.sound_at(1.50, ["PRSFX- Heal Bell"], 64, 125)
    a.sound_at(2.03, ["PRSFX- Floral Healing2", "PRSFX- Healing Pulse"], 65, 110)

    sx, sy = a.center(a.user)
    source = a.battler_sprite(a.user)
    floor = source.y + (source.src_rect.height - source.oy) * source.zoom_y
    a[:sx], a[:sy], a[:floor] = sx, sy, floor

    # A soft violet evening veil, not a completely opaque scene change.
    veil = a.bitmap(Graphics.width, Graphics.height) do |b|
      b.fill_rect(0, 0, b.width, b.height, Color.new(35, 24, 68))
    end
    a[:veil] = a.sprite(veil, z: 20_000, centered: false)

    note_b = KaitoStarlightRecitalVisual.note(a)
    star_b = KaitoStarlightRecitalVisual.star(a, Color.new(255, 216, 146, 245))
    pink_b = KaitoStarlightRecitalVisual.star(a, Color.new(244, 173, 252, 245))
    glow_b = KaitoStarlightRecitalVisual.glow(a)
    ring_b = a.ring(56, Color.new(255, 217, 245, 225), 3)
    fine_b = a.ring(39, Color.new(255, 246, 207, 235), 2)

    # Five curved lines form a floating musical staff behind the singer.
    staff_b = a.bitmap(190, 88) do |b|
      5.times do |line|
        184.times do |x|
          y = (20 + line * 10 + Math.sin(x * 0.030) * 7).round
          b.fill_rect(x + 3, y, 2, 1, Color.new(255, 219, 248, 155))
        end
      end
    end
    a[:staff] = a.sprite(staff_b, z: 20_013)
    a[:notes] = Array.new(13) { a.sprite(note_b, z: 20_030) }
    a[:waves] = Array.new(3) { a.sprite(ring_b, z: 20_022) }
    a[:singer_glow] = a.sprite(glow_b, z: 20_014)

    # UserAndAllies can already include the user. Deduplicate by battler index.
    battlers = ([a.user] + a.targets).compact.uniq { |b| b.index }
    a[:groups] = battlers.filter_map do |b|
      pos = a.center(b)
      next unless pos
      x, y = pos
      src = a.battler_sprite(b)
      height = src.src_rect.height * src.zoom_y.abs
      width = src.src_rect.width * src.zoom_x.abs
      body = a.copy(b, hide_original: true, z: 20_020)
      next unless body

      {
        user: b.index == a.user.index,
        x: x, y: y,
        rx: [[width * 0.48, 32].max, 73].min,
        ry: [[height * 0.43, 30].max, 74].min,
        body: body,
        bx: body.x, by: body.y,
        angle: body.angle,
        color: body.color.clone,
        glow: a.sprite(glow_b, z: 20_016),
        crown: a.sprite(star_b, z: 20_034),
        rings: Array.new(2) { a.sprite(ring_b, z: 20_028) },
        fine: a.sprite(fine_b, z: 20_032),
        flying: Array.new(7) { a.sprite(note_b, z: 20_035) },
        falling: Array.new(25) do |i|
          a.sprite(i.even? ? star_b : pink_b, z: 20_037)
        end,
        rising: Array.new(18) { a.sprite(star_b, z: 20_036) }
      }
    end
  end
) do |a, _t|
  sec = a.seconds
  sx, sy, floor = a[:sx], a[:sy], a[:floor]
  fade_in = a.clamp(sec / 0.36)
  fade_out = a.clamp((3.15 - sec) / 0.49)
  a[:veil].opacity = (fade_in * fade_out * 80).to_i

  #=============================================================================
  # 1. OPENING: music appears and circles the singer.
  #=============================================================================
  score_in = a.clamp((sec - 0.08) / 0.43)
  score_out = a.clamp((1.65 - sec) / 0.40)
  staff = a[:staff]
  staff.x, staff.y = sx, sy - 72 - score_in * 8
  staff.zoom_x = 0.64 + score_in * 0.25
  staff.zoom_y = 0.60
  staff.opacity = (score_in * score_out * 185).to_i

  glow = a[:singer_glow]
  glow.x, glow.y = sx, sy
  glow.zoom_x = 0.65 + Math.sin(sec * 5).abs * 0.12
  glow.zoom_y = glow.zoom_x
  glow.opacity = (score_in * score_out * 135).to_i

  a[:notes].each_with_index do |n, i|
    q = (sec - 0.16 - i % 5 * 0.045) / 1.20
    p = a.clamp(q)
    theta = i * 2.399 + sec * 2.25
    radius = 24 + i % 4 * 12
    n.x = sx + Math.cos(theta) * radius * (0.75 + p * 0.28)
    n.y = sy - 12 + Math.sin(theta) * radius * 0.52 - p * 20
    n.angle = -22 + Math.sin(theta) * 20
    n.zoom_x = n.zoom_y = 0.28 + i % 3 * 0.085
    n.opacity = q.between?(0.0, 1.0) ?
      (Math.sin(p * Math::PI) * 245).to_i : 0
  end

  a[:waves].each_with_index do |w, i|
    q = (sec - 0.38 - i * 0.25) / 0.86
    p = a.clamp(q)
    w.x, w.y = sx, floor - 4
    w.zoom_x = 0.32 + p * 1.10
    w.zoom_y = w.zoom_x * 0.30
    w.opacity = q.between?(0.0, 1.0) ?
      (Math.sin(p * Math::PI) * 220).to_i : 0
  end

  #=============================================================================
  # 2. REFRAIN: notes spread from the singer to user and allies.
  # 3. HEAL: descending starlight and warm rings envelop each recipient.
  #=============================================================================
  a[:groups].each_with_index do |g, gi|
    x, y = g[:x], g[:y]
    rx, ry = g[:rx], g[:ry]
    start = 0.94 + gi * 0.06
    heal = a.clamp((sec - 1.55 - gi * 0.07) / 0.28)
    end_glow = a.clamp((3.08 - sec) / 0.55)

    g[:flying].each_with_index do |n, i|
      q = (sec - start - i * 0.080) / 0.73
      p = a.clamp(q)
      bend = Math.sin(p * Math::PI)
      tx = x + Math.sin(i * 2.399) * rx * 0.34
      ty = y - 9 + Math.cos(i * 2.399) * ry * 0.28
      n.x = a.lerp(sx, tx, p) + bend * Math.sin(i * 1.8) * 34
      n.y = a.lerp(sy - 18, ty, p) - bend * (36 + i % 3 * 14)
      n.angle = -18 + p * 32
      n.zoom_x = n.zoom_y = 0.22 + i % 3 * 0.12
      n.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 230).to_i : 0
    end

    g[:glow].x, g[:glow].y = x, y
    g[:glow].zoom_x = 0.85 + heal * 0.44
    g[:glow].zoom_y = 0.95 + heal * 0.30
    g[:glow].opacity = (heal * end_glow * 175).to_i

    crown = g[:crown]
    crown.x, crown.y = x, y - ry - 24
    crown.zoom_x = crown.zoom_y = 0.20 + heal * 1.02
    crown.angle = sec * 27
    crown.opacity = (heal * a.clamp((2.46 - sec) / 0.38) * 220).to_i

    g[:rings].each_with_index do |r, i|
      q = (sec - 1.78 - gi * 0.07 - i * 0.22) / 0.79
      p = a.clamp(q)
      r.x, r.y = x, y + ry * 0.55
      r.zoom_x = (rx / 56.0) * (0.55 + p * 1.25)
      r.zoom_y = r.zoom_x * 0.43
      r.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 225).to_i : 0
    end

    fine = g[:fine]
    q = (sec - 1.61 - gi * 0.07) / 0.85
    p = a.clamp(q)
    fine.x, fine.y = x, y
    fine.zoom_x = (rx / 39.0) * (0.66 + p * 0.65)
    fine.zoom_y = (ry / 39.0) * (0.66 + p * 0.65)
    fine.opacity = q.between?(0.0, 1.0) ?
      (Math.sin(p * Math::PI) * 170).to_i : 0

    # The stars fall from above, then disappear inside the healing aura.
    g[:falling].each_with_index do |s, i|
      q = (sec - 1.37 - gi * 0.06 - i % 8 * 0.063) /
          (0.87 + i % 3 * 0.08)
      p = a.clamp(q)
      theta = i * 2.399
      s.x = x + Math.cos(theta) * (rx * 0.50 + i % 5 * 8) +
            Math.sin(p * 3 + i) * 4
      s.y = y - ry - 85 + p * (ry + 90) + Math.sin(theta) * 9
      s.angle = i * 29 + p * 64
      s.zoom_x = s.zoom_y = 0.15 + i % 4 * 0.09
      s.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 245).to_i : 0
    end

    # A lighter upward afterglow suggests both HP and status restoration.
    g[:rising].each_with_index do |s, i|
      q = (sec - 2.02 - gi * 0.07 - i % 6 * 0.050) / 0.76
      p = a.clamp(q)
      theta = i * 2.399
      s.x = x + Math.cos(theta) * (rx * 0.38 + p * 20)
      s.y = y + ry * 0.55 - p * (ry * 1.3 + 32)
      s.angle = i * 30 + p * 68
      s.zoom_x = s.zoom_y = 0.12 + i % 3 * 0.075
      s.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 220).to_i : 0
    end

    body = g[:body]
    if g[:user]
      sing = a.clamp((sec - 0.20) / 0.24) *
             a.clamp((1.48 - sec) / 0.30)
      body.x = g[:bx] + Math.sin(sec * 6.0) * sing * 5
      body.angle = g[:angle] + Math.sin(sec * 6.0) * sing * 3
    end
    body.y = g[:by] - Math.sin(a.clamp((sec - 1.61) / 1.22) * Math::PI) *
             heal * 4
    body.color = heal > 0 ?
      Color.new(255, 235, 255, (heal * end_glow * 100).to_i) : g[:color]
  end
end
