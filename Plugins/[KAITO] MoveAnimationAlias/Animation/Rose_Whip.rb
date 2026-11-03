#===============================================================================
# ROSE WHIP - Scarlet Briar / Pokemon Essentials v21.1
# Requires: [KAITO] MoveAnimationAlias/Animation/000_AnimationCore.rb
# Visuals only; move script handles damage, Defense drops, and status effects.
#===============================================================================
module KaitoRoseWhipVisual
  def self.ribbon(a, b, path, width, color)
    path.each_cons(2).with_index do |(p, q), i|
      dx, dy = q[0] - p[0], q[1] - p[1]
      len = [Math.sqrt(dx * dx + dy * dy), 1.0].max
      nx, ny = -dy / len, dx / len
      w1 = width * (1.0 - i.to_f / path.length * 0.75)
      w2 = width * (1.0 - (i + 1).to_f / path.length * 0.75)
      a.polygon(b, [
        [p[0] + nx * w1, p[1] + ny * w1],
        [q[0] + nx * w2, q[1] + ny * w2],
        [q[0] - nx * w2, q[1] - ny * w2],
        [p[0] - nx * w1, p[1] - ny * w1]
      ], color)
    end
  end

  def self.whip(a)
    a.bitmap(256, 116) do |b|
      path = [[2, 67], [25, 54], [55, 48], [82, 56], [112, 64],
              [143, 52], [173, 42], [201, 42], [225, 53], [252, 58]]
      ribbon(a, b, path, 9, Color.new(19, 77, 34, 245))
      ribbon(a, b, path, 6, Color.new(45, 143, 60, 255))
      ribbon(a, b, path, 2.3, Color.new(157, 237, 123, 255))

      path.each_cons(2).with_index do |(p, q), i|
        next if i == 0 || i == 8
        mx, my = (p[0] + q[0]) / 2.0, (p[1] + q[1]) / 2.0
        dx, dy = q[0] - p[0], q[1] - p[1]
        d = [Math.sqrt(dx * dx + dy * dy), 1.0].max
        nx, ny = -dy / d, dx / d
        side = i.even? ? 1 : -1
        base_x, base_y = mx + nx * side * 3, my + ny * side * 3
        tip_x, tip_y = mx - dx / d * 7 + nx * side * (14 + i % 3 * 2),
                       my - dy / d * 7 + ny * side * (14 + i % 3 * 2)
        a.polygon(b, [[base_x - 5, base_y - 3],
                      [tip_x, tip_y],
                      [base_x + 5, base_y + 3]],
                  Color.new(26, 106, 44, 255))
        a.polygon(b, [[base_x, base_y], [tip_x, tip_y],
                      [base_x + 2, base_y + 1]],
                  Color.new(158, 241, 119, 225))
      end
    end
  end

  def self.rose(a)
    a.bitmap(76, 76) do |b|
      outer = Color.new(143, 29, 64, 255)
      middle = Color.new(226, 70, 111, 255)
      inner = Color.new(255, 154, 173, 255)

      8.times do |i|
        t = i * Math::PI / 4
        x, y = 38 + Math.cos(t) * 20, 38 + Math.sin(t) * 20
        tangent_x, tangent_y = -Math.sin(t), Math.cos(t)
        radial_x, radial_y = Math.cos(t), Math.sin(t)
        a.polygon(b, [
          [38 + tangent_x * 8, 38 + tangent_y * 8],
          [x + tangent_x * 12, y + tangent_y * 12],
          [x + radial_x * 10, y + radial_y * 10],
          [x - tangent_x * 12, y - tangent_y * 12],
          [38 - tangent_x * 8, 38 - tangent_y * 8]
        ], outer)
        a.polygon(b, [
          [38 + tangent_x * 6, 38 + tangent_y * 6],
          [x + tangent_x * 8, y + tangent_y * 8],
          [x + radial_x * 6, y + radial_y * 6],
          [x - tangent_x * 8, y - tangent_y * 8]
        ], middle)
      end

      a.polygon(b, [[38, 21], [52, 27], [57, 39],
                    [47, 53], [34, 57], [23, 48],
                    [21, 34], [29, 25]], middle)
      a.polygon(b, [[37, 25], [48, 31], [50, 42],
                    [42, 50], [31, 46], [28, 35]], inner)
      a.polygon(b, [[30, 35], [39, 30], [45, 37],
                    [40, 44], [34, 43], [34, 38],
                    [39, 36]], Color.new(165, 37, 83, 250))
      b.fill_rect(34, 32, 4, 3, Color.new(255, 209, 206, 240))
    end
  end

  def self.petal(a)
    a.bitmap(30, 32) do |b|
      a.polygon(b, [[15, 1], [27, 9], [29, 20],
                    [20, 29], [10, 30], [2, 21], [3, 11]],
                Color.new(163, 35, 76, 245))
      a.polygon(b, [[15, 3], [25, 12], [25, 20],
                    [18, 26], [9, 26], [5, 19], [7, 10]],
                Color.new(244, 98, 140, 255))
      a.polygon(b, [[13, 7], [19, 10], [14, 18], [9, 20]],
                Color.new(255, 192, 200, 240))
    end
  end

  def self.leaf(a)
    a.bitmap(34, 19) do |b|
      a.polygon(b, [[1, 11], [10, 3], [26, 1],
                    [33, 6], [24, 16], [9, 18]],
                Color.new(32, 135, 57, 250))
      a.polygon(b, [[5, 11], [17, 5], [31, 5],
                    [20, 11], [11, 15]],
                Color.new(162, 226, 117, 250))
    end
  end

  def self.thorn(a)
    a.bitmap(24, 33) do |b|
      a.polygon(b, [[3, 28], [10, 7], [19, 0],
                    [17, 17], [22, 29]],
                Color.new(40, 96, 44, 255))
      a.polygon(b, [[9, 26], [15, 9], [19, 1],
                    [17, 17], [15, 26]],
                Color.new(174, 224, 130, 255))
    end
  end

  def self.glow(a)
    a.bitmap(104, 104) do |b|
      104.times do |y|
        104.times do |x|
          r = Math.sqrt((x - 51.5)**2 + (y - 51.5)**2) / 51.5
          next if r >= 1.0
          b.set_pixel(x, y, Color.new(255, 110, 144,
                       ((1.0 - r)**2 * 170).to_i))
        end
      end
    end
  end
end

KaitoAnimation.register(
  :ROSEWHIP,
  duration: 2.05,
  require_target: true,
  setup: proc do |a|
    a.sound_at(0.04, ["PRSFX- Aromatherapy"], 45, 120)
    a.sound_at(0.47, ["PRSFX- Power Whip"], 77, 108)
    a.sound_at(0.90, ["PRSFX- Needle Arm1", "PRSFX- Leaf Blade"], 82, 112)
    a.sound_at(1.10, ["PRSFX- Petal Blizzard1"], 53, 123)

    a[:duration] = 2.05
    rose_b = KaitoRoseWhipVisual.rose(a)
    whip_b = KaitoRoseWhipVisual.whip(a)
    petal_b = KaitoRoseWhipVisual.petal(a)
    leaf_b = KaitoRoseWhipVisual.leaf(a)
    thorn_b = KaitoRoseWhipVisual.thorn(a)
    glow_b = KaitoRoseWhipVisual.glow(a)
    ring_b = a.ring(56, Color.new(250, 137, 173, 240), 3)

    veil = a.bitmap(Graphics.width, Graphics.height) do |b|
      b.fill_rect(0, 0, b.width, b.height, Color.new(45, 15, 39))
    end
    a[:veil] = a.sprite(veil, z: 19_990, centered: false)

    ux, uy = a.center
    a[:ux], a[:uy] = ux, uy
    a[:user_rose] = a.sprite(rose_b, z: 20_026)
    a[:user_glow] = a.sprite(glow_b, z: 20_018)
    a[:user_ring] = a.sprite(ring_b, z: 20_021)
    a[:user_leaves] = Array.new(13) { a.sprite(leaf_b, z: 20_027) }

    a[:groups] = a.targets.map do |target|
      tx, ty = a.center(target)
      dx, dy = tx - ux, ty - uy
      length = [Math.sqrt(dx * dx + dy * dy), 1.0].max
      sx, sy = ux + dx / length * 23, uy + dy / length * 15
      vx, vy = tx - sx, ty - sy
      distance = [Math.sqrt(vx * vx + vy * vy), 1.0].max
      foe = a.copy(target, hide_original: true, z: 20_020)
      lash = a.sprite(whip_b, z: 20_030, centered: false)
      lash.ox, lash.oy = 2, 58

      {
        sx: sx, sy: sy, tx: tx, ty: ty,
        angle: -Math.atan2(vy, vx) * 180.0 / Math::PI,
        distance: distance,
        direction: vx >= 0 ? 1 : -1,
        foe: foe, bx: foe.x, by: foe.y, color: foe.color.clone,
        lash: lash,
        echo: a.sprite(whip_b, z: 20_024, centered: false),
        rose: a.sprite(rose_b, z: 20_033),
        impact_glow: a.sprite(glow_b, z: 20_034),
        rings: Array.new(2) { a.sprite(ring_b, z: 20_035) },
        petals: Array.new(39) { a.sprite(petal_b, z: 20_040) },
        thorns: Array.new(16) { a.sprite(thorn_b, z: 20_038) },
        leaves: Array.new(18) { a.sprite(leaf_b, z: 20_037) }
      }.tap do |g|
        g[:echo].ox, g[:echo].oy = 2, 58
      end
    end
  end
) do |a, _t|
  sec = a.seconds
  ux, uy = a[:ux], a[:uy]
  fade = a.clamp(sec / 0.22) * a.clamp((2.05 - sec) / 0.38)
  a[:veil].opacity = (fade * 65).to_i

  charge = a.clamp(sec / 0.33)
  charge_fade = a.clamp((0.63 - sec) / 0.25)
  rose = a[:user_rose]
  rose.x, rose.y = ux + 5, uy - 33
  rose.angle = -15 + sec * 35
  rose.zoom_x = rose.zoom_y = 0.18 + charge * 0.57
  rose.opacity = (charge * charge_fade * 250).to_i

  glow = a[:user_glow]
  glow.x, glow.y = rose.x, rose.y
  glow.zoom_x = glow.zoom_y = 0.38 + charge * 0.91
  glow.opacity = (charge * charge_fade * 225).to_i

  ring = a[:user_ring]
  ring.x, ring.y = ux, uy
  ring.zoom_x = 0.22 + charge * 0.84
  ring.zoom_y = ring.zoom_x * 0.40
  ring.opacity = (charge * charge_fade * 180).to_i

  a[:user_leaves].each_with_index do |s, i|
    q = (sec - i % 6 * 0.028) / 0.48
    p = a.clamp(q)
    theta = i * 2.399
    s.x = ux + Math.cos(theta) * (50 - p * 35)
    s.y = uy + Math.sin(theta) * (40 - p * 25)
    s.angle = i * 31 + p * 78
    s.zoom_x = s.zoom_y = 0.32 + i % 3 * 0.12
    s.opacity = q.between?(0.0, 1.0) ?
      (Math.sin(p * Math::PI) * charge_fade * 245).to_i : 0
  end

  # A single thorned lash strikes the target, then retracts.
  a[:groups].each do |g|
    sx, sy, tx, ty = g.values_at(:sx, :sy, :tx, :ty)
    advance = a.clamp((sec - 0.42) / 0.43)
    advance = 1.0 - (1.0 - advance)**3
    recoil = a.clamp((sec - 1.05) / 0.44)
    recoil = recoil * recoil * (3.0 - 2.0 * recoil)
    lash_size = advance * (1.0 - recoil)
    visible = a.clamp((sec - 0.40) / 0.08) *
              a.clamp((1.53 - sec) / 0.14)

    lash = g[:lash]
    lash.x, lash.y = sx, sy
    lash.angle = g[:angle] + Math.sin(sec * 21) * (1.0 - advance) * 8
    lash.zoom_x = g[:distance] / 250.0 * lash_size
    lash.zoom_y = 0.66 + advance * 0.28
    lash.opacity = (visible * 255).to_i

    echo = g[:echo]
    echo.x = sx - g[:direction] * 7
    echo.y = sy + 7
    echo.angle = lash.angle + 3
    echo.zoom_x = lash.zoom_x * 0.93
    echo.zoom_y = lash.zoom_y * 1.15
    echo.color = Color.new(242, 85, 140, 170)
    echo.opacity = (visible * 83).to_i

    head = g[:rose]
    head.x = sx + (tx - sx) * lash_size
    head.y = sy + (ty - sy) * lash_size
    head.angle = 30 + sec * 100
    head.zoom_x = head.zoom_y = (0.24 + advance * 0.42) *
                                (1.0 - recoil * 0.30)
    head.opacity = (visible * 240).to_i

    # The rose bursts into petals and sharp briars on impact.
    age = sec - 0.85
    hit = a.clamp(age / 0.43)
    active = age.between?(0.0, 0.43)

    ig = g[:impact_glow]
    ig.x, ig.y = tx, ty
    ig.zoom_x = ig.zoom_y = 0.45 + hit * 1.7
    ig.opacity = active ? ((1.0 - hit)**2 * 235).to_i : 0

    g[:rings].each_with_index do |s, i|
      q = (age - i * 0.055) / 0.37
      p = a.clamp(q)
      s.x, s.y = tx, ty
      s.zoom_x = 0.18 + p * (1.35 + i * 0.4)
      s.zoom_y = s.zoom_x * (i == 0 ? 0.76 : 0.48)
      s.opacity = q.between?(0.0, 1.0) ? ((1.0 - p) * 230).to_i : 0
    end

    g[:petals].each_with_index do |s, i|
      q = (sec - 0.88 - i % 7 * 0.018) / 1.02
      p = a.clamp(q)
      theta = i * 2.399
      radius = (14 + p * (53 + i % 7 * 9))
      s.x = tx + Math.cos(theta) * radius + Math.sin(sec * 6 + i) * 4
      s.y = ty + Math.sin(theta) * radius * 0.55 -
            Math.sin(p * Math::PI) * (19 + i % 5 * 10) + p * p * 44
      s.angle = i * 27 + p * (i.even? ? 230 : -230)
      s.zoom_x = 0.24 + i % 5 * 0.10
      s.zoom_y = s.zoom_x * (0.68 + Math.sin(sec * 10 + i).abs * 0.32)
      s.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI)**0.65 * 245).to_i : 0
    end

    g[:thorns].each_with_index do |s, i|
      q = (sec - 0.86 - i % 4 * 0.015) / 0.57
      p = a.clamp(q)
      theta = i * 2.399
      distance = 12 + p * (41 + i % 5 * 12)
      s.x = tx + Math.cos(theta) * distance
      s.y = ty + Math.sin(theta) * distance * 0.62 + p * p * 20
      s.angle = -theta * 180.0 / Math::PI + 90
      s.zoom_x = s.zoom_y = 0.28 + i % 4 * 0.12
      s.opacity = q.between?(0.0, 1.0) ?
        ((1.0 - p)**0.6 * 255).to_i : 0
    end

    g[:leaves].each_with_index do |s, i|
      q = (sec - 0.97 - i % 6 * 0.035) / 0.75
      p = a.clamp(q)
      theta = i * 2.399 + p * 2.3
      s.x = tx + Math.cos(theta) * (24 + p * (42 + i % 4 * 13))
      s.y = ty + Math.sin(theta) * (14 + p * 37) + p * p * 37
      s.angle = i * 37 + p * 120
      s.zoom_x = s.zoom_y = 0.24 + i % 4 * 0.10
      s.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 230).to_i : 0
    end

    foe = g[:foe]
    shake = active ? (1.0 - hit) * 8.0 : 0.0
    foe.x = g[:bx] + Math.sin(age * 105) * shake
    foe.y = g[:by] - Math.sin(age * 80).abs * shake * 0.25
    foe.color = active ?
      Color.new(255, 175, 196, ((1.0 - hit) * 170).to_i) : g[:color]
  end
end
