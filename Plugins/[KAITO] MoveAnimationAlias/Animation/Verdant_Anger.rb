#===============================================================================
# VERDANT ANGER - Emerald Cataclysm
# Pokemon Essentials v21.1 / KAITO Animation Core
# Path: Plugins/[KAITO] MoveAnimationAlias/Animation/Verdant_Anger.rb
# Requires: 000_AnimationCore.rb
# Visual only. Damage and Speed reduction remain in the move function.
#===============================================================================

module KaitoVerdantAngerVisual
  def self.glow(a)
    a.bitmap(128, 128) do |b|
      128.times do |y|
        128.times do |x|
          r = Math.sqrt((x - 63.5)**2 + (y - 63.5)**2) / 63.5
          next if r >= 1.0
          alpha = ((1.0 - r)**2 * 188).to_i
          b.set_pixel(x, y, Color.new(102, 255, 147, alpha))
        end
      end
    end
  end

  def self.leaf(a)
    a.bitmap(34, 22) do |b|
      a.polygon(b, [[1, 16], [7, 6], [19, 1], [33, 4],
                    [27, 15], [14, 21]],
                Color.new(16, 113, 46, 255))
      a.polygon(b, [[4, 15], [11, 7], [22, 4], [31, 5],
                    [24, 13], [14, 18]],
                Color.new(100, 218, 77, 250))
      a.polygon(b, [[5, 16], [16, 11], [30, 5],
                    [20, 13], [11, 18]],
                Color.new(220, 255, 154, 225))
    end
  end

  def self.shard(a)
    a.bitmap(22, 42) do |b|
      a.polygon(b, [[11, 0], [19, 12], [14, 38],
                    [8, 42], [3, 23]],
                Color.new(22, 144, 68, 245))
      a.polygon(b, [[11, 3], [14, 13], [11, 34],
                    [8, 37], [7, 23]],
                Color.new(182, 255, 137, 255))
      b.fill_rect(10, 10, 2, 15, Color.new(250, 255, 218, 220))
    end
  end

  def self.spark(a)
    a.bitmap(22, 22) do |b|
      a.polygon(b, [[11, 0], [14, 8], [22, 11], [14, 14],
                    [11, 22], [8, 14], [0, 11], [8, 8]],
                Color.new(178, 255, 116, 240))
      a.polygon(b, [[11, 5], [13, 9], [17, 11], [13, 13],
                    [11, 17], [9, 13], [5, 11], [9, 9]],
                Color.new(250, 255, 225, 255))
    end
  end

  def self.wave(a)
    a.bitmap(252, 138) do |b|
      # Outer jagged shockwave, glowing leafy edges and an intense core.
      a.polygon(b, [
        [0, 70], [34, 48], [58, 56], [83, 28], [109, 42],
        [137, 13], [162, 35], [187, 11], [218, 34],
        [251, 67], [219, 96], [191, 121], [161, 101],
        [136, 132], [108, 99], [77, 113], [54, 89], [28, 95]
      ], Color.new(16, 95, 47, 230))
      a.polygon(b, [
        [5, 69], [42, 53], [67, 61], [90, 39], [115, 51],
        [140, 29], [166, 49], [191, 28], [220, 46],
        [248, 68], [216, 88], [190, 104], [163, 89],
        [137, 113], [106, 84], [80, 98], [52, 80], [28, 86]
      ], Color.new(43, 186, 77, 245))
      a.polygon(b, [
        [15, 68], [55, 60], [84, 66], [115, 58],
        [143, 51], [176, 58], [207, 55], [246, 68],
        [207, 81], [176, 77], [142, 86], [110, 77],
        [82, 79], [51, 75]
      ], Color.new(149, 248, 101, 255))
      a.polygon(b, [
        [34, 69], [83, 68], [124, 65],
        [166, 64], [215, 65], [250, 68],
        [213, 72], [166, 71], [121, 73], [82, 72]
      ], Color.new(246, 255, 208, 250))
    end
  end

  def self.impact(a)
    a.bitmap(168, 168) do |b|
      14.times do |i|
        angle = Math::PI * 2 * i / 14.0
        near = 15 + i % 3 * 4
        far = 70 + i % 4 * 7
        side = 0.11 + i % 2 * 0.04
        a.polygon(b, [
          [84 + Math.cos(angle - side) * near,
           84 + Math.sin(angle - side) * near],
          [84 + Math.cos(angle) * far,
           84 + Math.sin(angle) * far],
          [84 + Math.cos(angle + side) * near,
           84 + Math.sin(angle + side) * near]
        ], i.even? ? Color.new(73, 224, 87, 230) :
                      Color.new(197, 255, 124, 245))
      end
      a.polygon(b, [
        [84, 39], [99, 69], [130, 84], [99, 99],
        [84, 131], [68, 99], [37, 84], [68, 69]
      ], Color.new(226, 255, 166, 245))
      b.fill_rect(77, 77, 14, 14, Color.new(255, 255, 244, 255))
    end
  end
end

KaitoAnimation.register(
  :VERDANTANGER,
  duration: 2.75,
  require_target: true,
  setup: proc do |a|
    a.sound_at(0.04, ["PRSFX- Energy Ball1"], 60, 85)
    a.sound_at(0.37, ["PRSFX- Frenzy Plant1"], 67, 100)
    a.sound_at(0.69, ["PRSFX- Leaf Storm1"], 80, 95)
    a.sound_at(1.30, ["PRSFX- Frenzy Plant2", "PRSFX- Leaf Storm2"], 90, 100)
    a.sound_at(1.58, ["PRSFX- Earth Power"], 72, 113)

    ux, uy = a.center
    a[:ux], a[:uy] = ux, uy
    user_sprite = a.battler_sprite
    body = a.copy(a.user, hide_original: true, z: 20_021)
    a[:user] = body
    a[:user_x], a[:user_y] = body.x, body.y
    a[:user_color] = body.color.clone

    glow_b = KaitoVerdantAngerVisual.glow(a)
    leaf_b = KaitoVerdantAngerVisual.leaf(a)
    shard_b = KaitoVerdantAngerVisual.shard(a)
    spark_b = KaitoVerdantAngerVisual.spark(a)
    wave_b = KaitoVerdantAngerVisual.wave(a)
    blast_b = KaitoVerdantAngerVisual.impact(a)
    ring_b = a.ring(65, Color.new(155, 255, 117, 235), 3)
    ring2_b = a.ring(53, Color.new(227, 255, 167, 245), 2)

    veil_b = a.bitmap(Graphics.width, Graphics.height) do |b|
      b.fill_rect(0, 0, b.width, b.height, Color.new(10, 38, 23))
    end
    a[:veil] = a.sprite(veil_b, z: 19_990, centered: false)

    a[:charge_glow] = a.sprite(glow_b, z: 20_019)
    a[:charge_rings] = Array.new(3) { a.sprite(ring_b, z: 20_024) }
    a[:charge_leaves] = Array.new(24) { a.sprite(leaf_b, z: 20_028) }
    a[:charge_sparks] = Array.new(14) { a.sprite(spark_b, z: 20_029) }

    a[:groups] = a.targets.map do |target|
      tx, ty = a.center(target)
      dx, dy = tx - ux, ty - uy
      length = [Math.sqrt(dx * dx + dy * dy), 1.0].max
      sx, sy = ux + dx / length * 22, uy + dy / length * 15
      foe = a.copy(target, hide_original: true, z: 20_022)

      {
        sx: sx, sy: sy, tx: tx, ty: ty,
        dx: tx - sx, dy: ty - sy,
        angle: -Math.atan2(dy, dx) * 180.0 / Math::PI,
        direction: dx >= 0 ? 1 : -1,
        foe: foe, base_x: foe.x, base_y: foe.y,
        foe_color: foe.color.clone,
        waves: Array.new(3) { a.sprite(wave_b, z: 20_030) },
        wave_glow: a.sprite(glow_b, z: 20_028),
        path_sparks: Array.new(28) { a.sprite(spark_b, z: 20_032) },
        flying_leaves: Array.new(32) { a.sprite(leaf_b, z: 20_031) },
        blast: a.sprite(blast_b, z: 20_038),
        blast_glow: a.sprite(glow_b, z: 20_035),
        rings: Array.new(3) { a.sprite(ring_b, z: 20_039) },
        inner_ring: a.sprite(ring2_b, z: 20_040),
        shards: Array.new(32) { a.sprite(shard_b, z: 20_043) },
        debris: Array.new(36) { a.sprite(leaf_b, z: 20_044) },
        afterglow: a.sprite(glow_b, z: 20_025)
      }
    end
  end
) do |a, _t|
  sec = a.seconds
  ux, uy = a[:ux], a[:uy]
  intro = a.clamp(sec / 0.26)
  outro = a.clamp((2.75 - sec) / 0.45)
  a[:veil].opacity = (intro * outro * 100).to_i

  # 1. Charge a violent emerald vortex around the user.
  charge = a.clamp(sec / 0.65)
  charge_out = a.clamp((0.88 - sec) / 0.19)

  glow = a[:charge_glow]
  glow.x, glow.y = ux, uy
  glow.zoom_x = glow.zoom_y = 0.44 + charge * 1.14
  glow.opacity = (intro * charge_out * (80 + charge * 165)).to_i

  a[:charge_rings].each_with_index do |s, i|
    q = (sec - i * 0.095) / 0.63
    p = a.clamp(q)
    s.x, s.y = ux, uy
    s.zoom_x = 1.18 - p * 0.83
    s.zoom_y = s.zoom_x * 0.42
    s.angle = i * 30 + sec * (i.even? ? 42 : -42)
    s.opacity = q.between?(0.0, 1.0) ?
      (Math.sin(p * Math::PI) * charge_out * 245).to_i : 0
  end

  a[:charge_leaves].each_with_index do |s, i|
    q = (sec - i % 8 * 0.035) / 0.63
    p = a.clamp(q)
    theta = i * 2.399 + p * 3.8
    r = (65 + i % 5 * 11) * (1.0 - p * 0.80)
    s.x = ux + Math.cos(theta) * r
    s.y = uy + Math.sin(theta) * r * 0.68
    s.angle = i * 29 + p * 160
    s.zoom_x = s.zoom_y = 0.28 + i % 4 * 0.10
    s.opacity = q.between?(0.0, 1.0) ?
      (Math.sin(p * Math::PI) * charge_out * 255).to_i : 0
  end

  a[:charge_sparks].each_with_index do |s, i|
    q = (sec - i % 5 * 0.040) / 0.60
    p = a.clamp(q)
    theta = i * 2.399 + sec * 3.0
    r = 58 * (1.0 - p)
    s.x = ux + Math.cos(theta) * r
    s.y = uy + Math.sin(theta) * r * 0.70
    s.angle = i * 22 + sec * 110
    s.zoom_x = s.zoom_y = 0.20 + i % 3 * 0.13
    s.opacity = q.between?(0.0, 1.0) ?
      (Math.sin(p * Math::PI) * charge_out * 255).to_i : 0
  end

  body = a[:user]
  kick = a.clamp((sec - 0.68) / 0.12) *
         a.clamp((1.06 - sec) / 0.25)
  direction = a[:groups].empty? ? 1 : a[:groups][0][:direction]
  body.x = a[:user_x] - direction * kick * 7
  body.y = a[:user_y] + kick * 3
  body.color = kick > 0 ?
    Color.new(157, 255, 106, (kick * 120).to_i) : a[:user_color]

  a[:groups].each do |g|
    sx, sy, tx, ty = g.values_at(:sx, :sy, :tx, :ty)

    # 2. Three staggered waves tear across the battlefield.
    g[:waves].each_with_index do |s, i|
      q = (sec - 0.69 - i * 0.095) / (0.60 + i * 0.06)
      p = a.clamp(q)
      travel = p * p * (3.0 - 2.0 * p)
      s.x = a.lerp(sx, tx, travel) - g[:direction] * (20 + i * 12)
      s.y = a.lerp(sy, ty, travel) - Math.sin(p * Math::PI) * (15 + i * 5)
      s.mirror = g[:direction] < 0
      s.angle = g[:angle] * 0.37
      s.zoom_x = 0.78 + i * 0.23
      s.zoom_y = 0.66 + i * 0.20
      s.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI)**0.36 * (255 - i * 40)).to_i : 0
    end

    q = (sec - 0.75) / 0.69
    p = a.clamp(q)
    wx = a.lerp(sx, tx, p)
    wy = a.lerp(sy, ty, p) - Math.sin(p * Math::PI) * 13

    g[:wave_glow].x, g[:wave_glow].y = wx, wy
    g[:wave_glow].zoom_x = 1.55
    g[:wave_glow].zoom_y = 0.75
    g[:wave_glow].opacity = q.between?(0.0, 1.0) ?
      (Math.sin(p * Math::PI) * 215).to_i : 0

    g[:path_sparks].each_with_index do |s, i|
      q = (sec - 0.71 - i % 7 * 0.028) / 0.77
      p = a.clamp(q)
      theta = i * 2.399
      s.x = a.lerp(sx, tx, p) + Math.cos(theta) * (18 + i % 5 * 8)
      s.y = a.lerp(sy, ty, p) + Math.sin(theta) * (16 + i % 4 * 9)
      s.angle = i * 23 + sec * 90
      s.zoom_x = s.zoom_y = 0.20 + i % 3 * 0.09
      s.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 235).to_i : 0
    end

    g[:flying_leaves].each_with_index do |s, i|
      q = (sec - 0.73 - i % 8 * 0.031) / 0.87
      p = a.clamp(q)
      theta = i * 2.399
      s.x = a.lerp(sx, tx, p) +
            Math.cos(theta + p * 6) * (15 + i % 6 * 8)
      s.y = a.lerp(sy, ty, p) +
            Math.sin(theta + p * 6) * (13 + i % 5 * 8) -
            Math.sin(p * Math::PI) * 20
      s.angle = i * 29 + p * (i.even? ? 260 : -260)
      s.zoom_x = s.zoom_y = 0.22 + i % 4 * 0.11
      s.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 245).to_i : 0
    end

    # 3. The emerald shockwave detonates on the target.
    impact_time = 1.31
    age = sec - impact_time
    hit = a.clamp(age / 0.59)
    active = age.between?(0.0, 0.59)

    blast = g[:blast]
    blast.x, blast.y = tx, ty
    blast.angle = hit * 40
    blast.zoom_x = blast.zoom_y = 0.26 + hit * 1.28
    blast.opacity = active ? ((1.0 - hit)**1.15 * 255).to_i : 0

    flash = g[:blast_glow]
    flash.x, flash.y = tx, ty
    flash.zoom_x = flash.zoom_y = 0.50 + hit * 2.30
    flash.opacity = active ? ((1.0 - hit)**2 * 245).to_i : 0

    g[:rings].each_with_index do |s, i|
      rq = (age - i * 0.07) / 0.54
      rp = a.clamp(rq)
      s.x, s.y = tx, ty
      s.zoom_x = 0.20 + rp * (1.60 + i * 0.42)
      s.zoom_y = s.zoom_x * (i == 0 ? 0.85 : 0.54)
      s.opacity = rq.between?(0.0, 1.0) ?
        ((1.0 - rp) * (245 - i * 26)).to_i : 0
    end

    inner = g[:inner_ring]
    inner.x, inner.y = tx, ty
    inner.zoom_x = inner.zoom_y = 0.22 + hit * 1.98
    inner.opacity = active ? ((1.0 - hit) * 215).to_i : 0

    g[:shards].each_with_index do |s, i|
      q = (age - i % 6 * 0.016) / 0.90
      p = a.clamp(q)
      theta = i * 2.399
      radius = (25 + i % 7 * 14) * p
      s.x = tx + Math.cos(theta) * radius
      s.y = ty + Math.sin(theta) * radius * 0.65 -
            Math.sin(p * Math::PI) * (12 + i % 4 * 8) + p * p * 27
      s.angle = -theta * 180 / Math::PI + p * 130
      s.zoom_x = s.zoom_y = (0.26 + i % 4 * 0.10) * (1.0 - p * 0.28)
      s.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 255).to_i : 0
    end

    g[:debris].each_with_index do |s, i|
      q = (age - 0.08 - i % 8 * 0.022) / 1.11
      p = a.clamp(q)
      theta = i * 2.399 + p * 3.5
      radius = (22 + p * (42 + i % 6 * 12))
      s.x = tx + Math.cos(theta) * radius
      s.y = ty + Math.sin(theta) * radius * 0.55 -
            Math.sin(p * Math::PI) * 26 + p * p * 46
      s.angle = i * 27 + p * (i.even? ? 220 : -220)
      s.zoom_x = s.zoom_y = 0.23 + i % 5 * 0.10
      s.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 245).to_i : 0
    end

    # 4. Emerald drag visual (does not alter Speed or trigger any effect).
    after = a.clamp((sec - 1.64) / 0.24) *
            a.clamp((2.57 - sec) / 0.63)
    tail = g[:afterglow]
    tail.x, tail.y = tx, ty + 13
    tail.zoom_x = 1.0 + after * 0.55
    tail.zoom_y = 0.34 + after * 0.28
    tail.opacity = (after * 112).to_i

    foe = g[:foe]
    shake = active ? (1.0 - hit) * 11 : 0
    foe.x = g[:base_x] + Math.sin(age * 98) * shake
    foe.y = g[:base_y] + Math.cos(age * 79) * shake * 0.25
    foe.color = active ?
      Color.new(201, 255, 155, ((1.0 - hit) * 205).to_i) : g[:foe_color]
  end
end
