#===============================================================================
# BOUNCY BUBBLE — Springwater Bounce
# Pokémon Essentials v21.1 / KaitoAnimation Core
# Xóa đăng ký :BOUNCYBUBBLE cũ nếu đã có.
#===============================================================================
module KaitoBouncyWater
  def self.oval(a, bitmap, cx, cy, rx, ry, color)
    points = []
    40.times do |i|
      angle = i * Math::PI * 2.0 / 40
      points << [
        cx + Math.cos(angle) * rx,
        cy + Math.sin(angle) * ry
      ]
    end
    a.polygon(bitmap, points, color)
  end

  def self.bubble(a)
    a.bitmap(128, 128) do |b|
      # Lòng nước trong, không dùng một khối xanh đặc.
      oval(a, b, 64, 64, 52, 52, Color.new(75, 192, 241, 28))
      oval(a, b, 64, 72, 47, 40, Color.new(87, 211, 246, 20))

      # Mép cong nhiều lớp, phía trên sáng hơn.
      [
        [53, 49, 115],
        [50, 47, 165],
        [47, 45, 65]
      ].each_with_index do |entry, layer|
        outer, inner, alpha = entry
        64.times do |i|
          t1 = i * Math::PI * 2.0 / 64
          t2 = (i + 1) * Math::PI * 2.0 / 64
          light = (1 - Math.sin(t1)) * 0.5

          color = if layer == 1
            Color.new(207, 248, 255, alpha * (0.65 + light * 0.35))
          else
            Color.new(96, 207, 246, alpha)
          end

          a.polygon(b, [
            [64 + Math.cos(t1) * outer, 64 + Math.sin(t1) * outer],
            [64 + Math.cos(t2) * outer, 64 + Math.sin(t2) * outer],
            [64 + Math.cos(t2) * inner, 64 + Math.sin(t2) * inner],
            [64 + Math.cos(t1) * inner, 64 + Math.sin(t1) * inner]
          ], color)
        end
      end

      # Phản chiếu trắng và hồng tím rất nhẹ.
      oval(a, b, 43, 35, 13, 7, Color.new(255, 255, 255, 220))
      oval(a, b, 34, 48, 5, 10, Color.new(231, 252, 255, 155))
      oval(a, b, 85, 91, 13, 5, Color.new(239, 193, 245, 105))
      oval(a, b, 91, 83, 5, 3, Color.new(255, 255, 255, 180))
    end
  end

  def self.glow(a)
    a.bitmap(96, 96) do |b|
      16.downto(1) do |i|
        radius = i * 2.7
        oval(
          a, b, 48, 48, radius, radius,
          Color.new(135, 226, 251, 5)
        )
      end
    end
  end
end

KaitoAnimation.register(
  :BOUNCYBUBBLE,
  duration: 2.65,
  setup: proc { |a|
    source = a.battler_sprite(a.user)
    ux, uy = a.center(a.user)
    target_x, target_y = a.center(a.targets.first)
    direction = target_x >= ux ? 1 : -1

    a[:ux] = ux
    a[:uy] = uy
    a[:sx] = ux + direction * 27
    a[:sy] = uy + 5
    a[:direction] = direction

    a[:bubble_bitmap] = KaitoBouncyWater.bubble(a)
    a[:glow_bitmap] = KaitoBouncyWater.glow(a)
    a[:ring_bitmap] = a.ring(
      54, Color.new(181, 243, 255, 225), 3
    )

    a[:drop_bitmap] = a.bitmap(18, 30) do |b|
      a.polygon(b, [
        [9, 0], [15, 13], [16, 21], [12, 28],
        [6, 29], [2, 23], [3, 15]
      ], Color.new(72, 190, 236, 195))

      a.polygon(b, [
        [9, 5], [12, 16], [11, 24], [6, 24], [5, 19]
      ], Color.new(200, 248, 255, 220))

      b.fill_rect(6, 17, 2, 6, Color.new(255, 255, 255, 235))
    end

    a[:star_bitmap] = a.bitmap(20, 20) do |b|
      a.polygon(b, [
        [10, 0], [12, 7], [20, 10], [12, 12],
        [10, 20], [8, 12], [0, 10], [8, 8]
      ], Color.new(239, 255, 250, 245))
    end

    a[:focus] = a.sprite(a[:bubble_bitmap], z: 20_026)
    a[:focus_glow] = a.sprite(a[:glow_bitmap], z: 20_025)

    a[:gather] = []
    12.times do
      a[:gather] << a.sprite(a[:bubble_bitmap], z: 20_025)
    end

    a[:groups] = []
    a.targets.each do |battler|
      sprite = a.battler_sprite(battler)
      cx, cy = a.center(battler)
      foot = sprite.y +
        (sprite.src_rect.height - sprite.oy) * sprite.zoom_y

      body = a.copy(battler, hide_original: true, z: 20_022)
      group = {
        x: cx,
        y: cy,
        foot: foot,
        body: body,
        bx: body.x,
        by: body.y,
        color: body.color.clone,
        shots: []
      }

      6.times do |i|
        shot = {
          sprite: a.sprite(a[:bubble_bitmap], z: 20_030),
          trail: [],
          drops: [],
          foam: [],
          ring: a.sprite(a[:ring_bitmap], z: 20_033),
          ground_ring: a.sprite(a[:ring_bitmap], z: 20_018),
          born: 0.28 + i * 0.09,
          flight: 0.56 + i * 0.025,
          size: [0.58, 0.42, 0.69, 0.48, 0.62, 0.96][i],
          lane: (i % 3 - 1) * 13
        }

        3.times do
          shot[:trail] << a.sprite(a[:bubble_bitmap], z: 20_028)
        end
        (i == 5 ? 28 : 16).times do
          shot[:drops] << a.sprite(a[:drop_bitmap], z: 20_034)
        end
        (i == 5 ? 14 : 8).times do
          shot[:foam] << a.sprite(a[:bubble_bitmap], z: 20_035)
        end

        group[:shots] << shot
      end

      a[:groups] << group
    end

    # Dòng giọt sáng quay về người dùng.
    a[:returns] = []
    24.times do |i|
      a[:returns] << {
        sprite: a.sprite(a[:bubble_bitmap], z: 20_037),
        spark: a.sprite(a[:star_bitmap], z: 20_038),
        group: i % a[:groups].length
      }
    end

    a[:heal_glow] = a.sprite(a[:glow_bitmap], z: 20_024)
    a[:heal_rings] = []
    2.times do
      a[:heal_rings] << a.sprite(a[:ring_bitmap], z: 20_039)
    end

    a[:heal_stars] = []
    18.times do
      a[:heal_stars] << a.sprite(a[:star_bitmap], z: 20_040)
    end

    a.sound_at(0.03, ["Bubble", "Bubblebeam"], 60, 110)
    a.sound_at(0.30, ["Bubblebeam", "Bubble"], 75, 115)
    a.sound_at(0.84, ["Bubble", "Bubblebeam"], 75, 105)
    a.sound_at(1.08, ["Bubblebeam", "Bubble"], 80, 120)
    a.sound_at(1.42, ["Muddy Water", "Bubblebeam"], 80, 125)
    a.sound_at(1.92, ["Absorb2", "Absorb1"], 65, 120)
    a.sound_at(2.15, ["Recover", "Aqua Ring2"], 65, 115)
  }
) do |a, _t|
  s = a.seconds
  pi = Math::PI

  #---------------------------------------------------------------------------
  # 1. Những bong bóng nhỏ nhập vào một bong bóng đàn hồi.
  #---------------------------------------------------------------------------
  gather = a.clamp(s / 0.29)
  focus_fade = a.clamp((0.51 - s) / 0.18)

  focus = a[:focus]
  focus.x = a[:sx]
  focus.y = a[:sy]
  pulse = Math.sin(gather * pi * 2.0)
  focus.zoom_x = (0.18 + gather * 0.43) * (1 + pulse * 0.09)
  focus.zoom_y = (0.18 + gather * 0.43) * (1 - pulse * 0.09)
  focus.opacity = 230 * gather * focus_fade

  glow = a[:focus_glow]
  glow.x = a[:sx]
  glow.y = a[:sy]
  glow.zoom_x = glow.zoom_y = 0.3 + gather * 0.8
  glow.opacity = 130 * gather * focus_fade

  a[:gather].each_with_index do |bubble, i|
    angle = i * 2.39996 + s * 2.3
    radius = (1 - gather) * (35 + i % 4 * 9)

    bubble.x = a[:sx] + Math.cos(angle) * radius
    bubble.y = a[:sy] + Math.sin(angle) * radius * 0.65
    bubble.zoom_x = bubble.zoom_y = 0.10 + i % 3 * 0.045
    bubble.opacity = 190 * Math.sin(gather * pi) * focus_fade
  end

  #---------------------------------------------------------------------------
  # 2. Bong bóng nảy hai nhịp trên đường bay.
  # 3. Bẹt theo hướng va chạm rồi nổ thành nước.
  #---------------------------------------------------------------------------
  a[:groups].each do |g|
    strongest_flash = 0.0
    shake_x = 0.0
    shake_y = 0.0

    g[:shots].each_with_index do |shot, i|
      elapsed = s - shot[:born]
      u = a.clamp(elapsed / shot[:flight])
      impact = shot[:born] + shot[:flight]
      age = s - impact

      # Hai cung nảy; cung thứ hai thấp hơn để tăng cảm giác tăng tốc.
      wave = Math.sin(u * pi * 2.0).abs
      height = (i == 5 ? 47 : 33) * (1 - u * 0.35)
      bx = a.lerp(a[:sx], g[:x], u)
      by = a.lerp(a[:sy], g[:y] + shot[:lane], u) - wave * height

      bubble = shot[:sprite]
      bubble.x = bx
      bubble.y = by

      # Bẹt ở đáy cung, tròn trở lại khi bật lên.
      bottom = [1 - wave * 5, 0].max
      squash = bottom * Math.sin(u * pi)
      bubble.zoom_x = shot[:size] * (1 + squash * 0.17)
      bubble.zoom_y = shot[:size] * (1 - squash * 0.15)
      bubble.angle = Math.sin(u * pi * 2) * 7

      if elapsed < 0
        bubble.opacity = 0
      elsif age < 0
        bubble.opacity = 235
      elsif age < 0.07
        p = age / 0.07
        bubble.x = g[:x]
        bubble.y = g[:y] + shot[:lane]
        bubble.zoom_x = shot[:size] * (1 - p * 0.47)
        bubble.zoom_y = shot[:size] * (1 + p * 0.32)
        bubble.opacity = 235 * (1 - p)
      else
        bubble.opacity = 0
      end

      shot[:trail].each_with_index do |trail, j|
        lag = (j + 1) * 0.024
        v = a.clamp((elapsed - lag) / shot[:flight])
        bounce = Math.sin(v * pi * 2).abs
        h = (i == 5 ? 47 : 33) * (1 - v * 0.35)

        trail.x = a.lerp(a[:sx], g[:x], v)
        trail.y = a.lerp(a[:sy], g[:y] + shot[:lane], v) - bounce * h
        trail.zoom_x = trail.zoom_y = shot[:size] * (0.28 - j * 0.05)
        trail.opacity = elapsed > lag && age < 0 ?
          100 - j * 24 : 0
      end

      burst_age = age - 0.035
      burst = a.clamp(burst_age / 0.37)
      ring = shot[:ring]
      ring.x = g[:x]
      ring.y = g[:y] + shot[:lane]
      ring.zoom_x = 0.1 + burst * (i == 5 ? 1.48 : 0.95)
      ring.zoom_y = ring.zoom_x * 0.80
      ring.opacity = burst_age >= 0 && burst_age < 0.37 ?
        (1 - burst) * 235 : 0

      ground = shot[:ground_ring]
      ground.x = g[:x]
      ground.y = g[:foot]
      ground.zoom_x = 0.14 + burst * (i == 5 ? 1.75 : 1.1)
      ground.zoom_y = ground.zoom_x * 0.24
      ground.opacity = burst_age >= 0 && burst_age < 0.37 ?
        (1 - burst) * 180 : 0

      shot[:drops].each_with_index do |drop, j|
        life = i == 5 ? 0.67 : 0.48
        p = a.clamp(burst_age / life)
        theta = j * 2.39996 + i * 0.7
        reach = (i == 5 ? 58 : 35) + j % 5 * 8

        drop.x = g[:x] + Math.cos(theta) * reach * p
        drop.y = g[:y] + shot[:lane] +
          Math.sin(theta) * reach * p * 0.60 -
          p * 35 + p * p * 90

        drop.angle = -theta * 180 / pi + 90 + p * 35
        drop.zoom_x = 0.17 + j % 3 * 0.055
        drop.zoom_y = 0.29 + j % 4 * 0.08
        drop.opacity = burst_age >= 0 && burst_age < life ?
          (1 - p) * 250 : 0
      end

      shot[:foam].each_with_index do |foam, j|
        p = a.clamp(burst_age / 0.56)
        theta = j * 2.39996
        reach = 19 + j % 4 * 13

        foam.x = g[:x] + Math.cos(theta) * reach * p
        foam.y = g[:y] + shot[:lane] +
          Math.sin(theta) * reach * p * 0.5 - p * 23
        foam.zoom_x = foam.zoom_y =
          (0.09 + j % 3 * 0.045) * (1 + p * 0.4)
        foam.opacity = burst_age >= 0 && burst_age < 0.56 ?
          Math.sin(p * pi) * 210 : 0
      end

      if age >= 0 && age < 0.13
        strongest_flash = [
          strongest_flash, (1 - age / 0.13) * (i == 5 ? 235 : 125)
        ].max
      end

      if i == 5 && age >= 0 && age < 0.22
        envelope = (1 - age / 0.22) ** 2
        shake_x = Math.sin(age * 112) * 6 * envelope
        shake_y = Math.sin(age * 89) * 2 * envelope
      end
    end

    g[:body].x = g[:bx] + shake_x
    g[:body].y = g[:by] + shake_y
    g[:body].color = strongest_flash > 0 ?
      Color.new(210, 249, 255, strongest_flash) : g[:color]
  end

  #---------------------------------------------------------------------------
  # 4. Nước hóa thành giọt sáng, uốn về phía người dùng.
  #---------------------------------------------------------------------------
  a[:returns].each_with_index do |entry, i|
    g = a[:groups][entry[:group]]
    born = 1.48 + i * 0.016
    age = s - born
    p = a.clamp(age / 0.58)
    travel = p * p * (2 - p)
    side = i.even? ? -1 : 1

    x = a.lerp(g[:x], a[:ux], travel)
    y = a.lerp(g[:y], a[:uy], travel) -
      Math.sin(travel * pi) * (28 + i % 4 * 7)
    y += Math.sin(travel * pi * 2 + i * 0.45) *
      Math.sin(travel * pi) * side * 9

    bubble = entry[:sprite]
    bubble.x = x
    bubble.y = y
    bubble.zoom_x = bubble.zoom_y =
      (0.11 + i % 4 * 0.032) * (1 - p * 0.35)
    bubble.color = Color.new(190, 255, 221, p * 110)
    bubble.opacity = age >= 0 && age < 0.58 ?
      Math.sin(p * pi) * 245 : 0

    spark = entry[:spark]
    spark.x = x + side * 5
    spark.y = y - 4
    spark.angle = s * 100 + i * 23
    spark.zoom_x = spark.zoom_y = 0.18 + i % 3 * 0.055
    spark.opacity = bubble.opacity * 0.8
  end

  heal_age = s - 1.95
  heal = a.clamp(heal_age / 0.70)
  heal_envelope = heal_age >= 0 && heal_age < 0.70 ?
    Math.sin(heal * pi) : 0

  glow = a[:heal_glow]
  glow.x = a[:ux]
  glow.y = a[:uy] + 8
  glow.zoom_x = 1.0 + heal * 0.9
  glow.zoom_y = 1.25 + heal * 0.65
  glow.color = Color.new(180, 255, 214, 95)
  glow.opacity = heal_envelope * 175

  a[:heal_rings].each_with_index do |ring, i|
    age = s - 2.00 - i * 0.10
    p = a.clamp(age / 0.44)
    ring.x = a[:ux]
    ring.y = a[:uy] + 15 - p * 25
    ring.zoom_x = 0.22 + p * 1.05
    ring.zoom_y = ring.zoom_x * 0.40
    ring.color = Color.new(191, 255, 216, 110)
    ring.opacity = age >= 0 && age < 0.44 ?
      Math.sin(p * pi) * 210 : 0
  end

  a[:heal_stars].each_with_index do |star, i|
    age = s - 2.02 - i % 6 * 0.025
    p = a.clamp(age / 0.47)
    star.x = a[:ux] + Math.sin(i * 2.39996) * (15 + i % 4 * 7)
    star.y = a[:uy] + 28 - p * (47 + i % 3 * 12)
    star.angle = i * 25 + p * 65
    star.zoom_x = star.zoom_y = 0.16 + i % 3 * 0.075
    star.color = Color.new(255, 238, 174, 100)
    star.opacity = age >= 0 && age < 0.47 ?
      Math.sin(p * pi) * 235 : 0
  end
end