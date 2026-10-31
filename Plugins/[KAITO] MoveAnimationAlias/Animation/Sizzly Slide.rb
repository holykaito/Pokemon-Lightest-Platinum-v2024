#===============================================================================
# SIZZLY SLIDE — Blazing Skid
# Pokémon Essentials v21.1 / KaitoAnimation Core
# Chỉ thay đổi hoạt ảnh; sát thương và hiệu ứng Burn do move gốc xử lý.
#===============================================================================
module KaitoSizzlySkid
  # Vệt lửa có đầu thuôn, thân uốn và lõi vàng trắng.
  def self.make_flame(a)
    a.bitmap(72, 120) do |b|
      a.polygon(b, [
        [35, 118], [13, 105], [5, 84], [13, 64],
        [12, 83], [29, 56], [33, 15], [46, 43],
        [49, 68], [61, 49], [66, 81], [60, 105],
        [47, 117]
      ], Color.new(234, 53, 29, 90))

      a.polygon(b, [
        [35, 114], [17, 103], [12, 85], [26, 65],
        [32, 39], [38, 8], [47, 47], [43, 75],
        [56, 61], [59, 89], [51, 108]
      ], Color.new(255, 108, 27, 215))

      a.polygon(b, [
        [35, 110], [23, 99], [24, 84], [34, 65],
        [39, 39], [44, 69], [39, 89], [49, 80],
        [48, 100]
      ], Color.new(255, 205, 65, 245))

      a.polygon(b, [
        [35, 106], [29, 97], [33, 83], [38, 69],
        [40, 89], [43, 97]
      ], Color.new(255, 249, 199, 245))
    end
  end

  def self.make_glow(a)
    a.bitmap(112, 112) do |b|
      20.downto(1) do |i|
        radius = i * 2.6
        points = []
        40.times do |j|
          angle = j * Math::PI * 2.0 / 40
          points << [
            56 + Math.cos(angle) * radius,
            56 + Math.sin(angle) * radius
          ]
        end
        a.polygon(
          b, points,
          Color.new(255, 126, 33, 3 + (20 - i) / 3)
        )
      end
    end
  end

  # alpha thấp ở mép, tâm sáng để vệt trượt không thành một thanh đặc.
  def self.line(a, bitmap, x1, y1, x2, y2, width, color)
    dx = x2 - x1
    dy = y2 - y1
    length = Math.sqrt(dx * dx + dy * dy)
    return if length < 0.01
    nx = -dy / length * width * 0.5
    ny =  dx / length * width * 0.5

    a.polygon(bitmap, [
      [x1 + nx, y1 + ny],
      [x2 + nx, y2 + ny],
      [x2 - nx, y2 - ny],
      [x1 - nx, y1 - ny]
    ], color)
  end

  def self.path(a, progress)
    p = a.clamp(progress)
    [
      a.lerp(a[:start_x], a[:finish_x], p),
      a.lerp(a[:start_y], a[:finish_y], p) +
        Math.sin(p * Math::PI) * 15
    ]
  end
end

KaitoAnimation.register(
  :SIZZLYSLIDE,
  duration: 2.20,
  setup: proc { |a|
    source = a.battler_sprite(a.user)
    ux, uy = a.center(a.user)

    foe = a.targets.first
    target = a.battler_sprite(foe)
    tx, ty = a.center(foe)

    user_foot = source.y +
      (source.src_rect.height - source.oy) * source.zoom_y
    target_foot = target.y +
      (target.src_rect.height - target.oy) * target.zoom_y

    direction = tx >= ux ? 1 : -1
    gap = [[source.src_rect.width * source.zoom_x * 0.30, 25].max, 48].min

    a[:direction] = direction
    a[:start_x] = ux
    a[:start_y] = user_foot
    a[:finish_x] = tx - direction * gap
    a[:finish_y] = target_foot

    a[:flame_bitmap] = KaitoSizzlySkid.make_flame(a)
    a[:glow_bitmap] = KaitoSizzlySkid.make_glow(a)

    a[:ember_bitmap] = a.bitmap(16, 28) do |b|
      a.polygon(b, [
        [8, 0], [14, 12], [10, 27], [3, 22], [1, 13]
      ], Color.new(255, 116, 35, 230))
      a.polygon(b, [
        [8, 6], [11, 15], [7, 24], [5, 16]
      ], Color.new(255, 235, 146, 255))
    end

    a[:smoke_bitmap] = a.bitmap(72, 60) do |b|
      [
        [24, 32, 22], [44, 30, 23],
        [35, 19, 18], [39, 42, 16]
      ].each do |cx, cy, radius|
        7.downto(1) do |layer|
          r = radius * layer / 7.0
          points = []
          22.times do |j|
            angle = j * Math::PI * 2.0 / 22
            points << [
              cx + Math.cos(angle) * r,
              cy + Math.sin(angle) * r * 0.75
            ]
          end
          a.polygon(b, points, Color.new(99, 69, 66, 6))
        end
      end
    end

    a[:ring_bitmap] = a.ring(
      66, Color.new(255, 217, 133, 230), 4
    )

    # Người dùng di chuyển bằng bản sao, sprite gốc được core khôi phục.
    body = a.copy(a.user, hide_original: true, z: 20_023)
    a[:body] = body
    a[:body_base] = [
      body.x, body.y, body.zoom_x, body.zoom_y, body.angle
    ]

    a[:ghosts] = []
    4.times do
      ghost = a.copy(
        a.user, force_visible: true, z: 20_021
      )
      ghost.color = Color.new(255, 137, 48, 175)
      ghost.opacity = 0
      a[:ghosts] << ghost
    end

    # Ẩn bóng đứng yên trong thời gian Pokémon trượt.
    scene = a.instance_variable_get(:@scene)
    sprites = scene.instance_variable_get(:@sprites)
    if sprites
      shadow = sprites["shadow_#{a.user.index}"]
      a.hide(shadow) if shadow && !shadow.disposed?
    end

    a[:aura] = []
    5.times do
      a[:aura] << a.sprite(a[:flame_bitmap], z: 20_024)
    end

    a[:foot_glow] = a.sprite(a[:glow_bitmap], z: 20_020)

    a[:trail_bitmap] = a.bitmap(Graphics.width, Graphics.height)
    a[:trail] = a.sprite(
      a[:trail_bitmap], z: 20_016, centered: false
    )

    a[:ground_flames] = []
    22.times do
      flame = a.sprite(a[:flame_bitmap], z: 20_017)
      smoke = a.sprite(a[:smoke_bitmap], z: 20_018)
      a[:ground_flames] << [flame, smoke]
    end

    a[:speed_sparks] = []
    28.times do
      a[:speed_sparks] << a.sprite(a[:ember_bitmap], z: 20_025)
    end

    a[:groups] = []
    a.targets.each do |battler|
      sprite = a.battler_sprite(battler)
      cx, cy = a.center(battler)
      foot = sprite.y +
        (sprite.src_rect.height - sprite.oy) * sprite.zoom_y

      copy = a.copy(battler, hide_original: true, z: 20_022)
      group = {
        body: copy,
        base_x: copy.x,
        base_y: copy.y,
        color: copy.color.clone,
        x: cx,
        y: cy,
        foot: foot,
        flames: [],
        embers: [],
        smoke: [],
        rings: []
      }

      11.times do
        group[:flames] << a.sprite(a[:flame_bitmap], z: 20_030)
      end
      42.times do
        group[:embers] << a.sprite(a[:ember_bitmap], z: 20_033)
      end
      12.times do
        group[:smoke] << a.sprite(a[:smoke_bitmap], z: 20_031)
      end
      2.times do
        group[:rings] << a.sprite(a[:ring_bitmap], z: 20_032)
      end

      group[:glow] = a.sprite(a[:glow_bitmap], z: 20_029)
      a[:groups] << group
    end

    a[:flash] = a.sprite(
      a.bitmap(Graphics.width, Graphics.height) do |b|
        b.fill_rect(
          0, 0, b.width, b.height,
          Color.new(255, 232, 190)
        )
      end,
      z: 20_050,
      centered: false
    )

    a.sound_at(0.03, ["Flame Charge1", "Flamethrower"], 65, 95)
    a.sound_at(0.38, ["Flame Charge2", "Flame Charge1"], 85, 120)
    a.sound_at(0.89, ["Fire Punch2", "Flame Burst"], 90, 95)
    a.sound_at(1.06, ["Flame Burst", "Fire Punch3"], 80, 110)
  }
) do |a, _t|
  s = a.seconds
  dir = a[:direction]

  #---------------------------------------------------------------------------
  # 1. Hạ trọng tâm, gom lửa ở chân.
  # 2. Lao sát đất, đường trượt hơi cong.
  # 3. Giữ lực sau va chạm rồi trở về.
  #---------------------------------------------------------------------------
  charge = a.clamp(s / 0.30)

  dash = a.clamp((s - 0.38) / 0.51)
  dash = dash * dash

  back = a.clamp((s - 1.29) / 0.48)
  back = back * back * (3 - 2 * back)

  px, py = KaitoSizzlySkid.path(a, dash)
  px = a.lerp(px, a[:start_x], back)
  py = a.lerp(py, a[:start_y], back)

  base_x, base_y, zx, zy, base_angle = a[:body_base]
  body = a[:body]

  crouch = charge * (1 - a.clamp((s - 0.38) / 0.15))
  lean = Math.sin(dash * Math::PI) * (1 - back)

  body.x = base_x + px - a[:start_x] - dir * crouch * 7
  body.y = base_y + py - a[:start_y] + crouch * 5
  body.zoom_x = zx * (1 + crouch * 0.06 + lean * 0.04)
  body.zoom_y = zy * (1 - crouch * 0.09 - lean * 0.035)
  body.angle = base_angle - dir * (crouch * 5 + lean * 9)
  body.opacity = 255

  body.color = Color.new(
    255, 143, 57,
    42 * charge * (1 - a.clamp((s - 1.02) / 0.35))
  )

  # Dư ảnh chỉ kéo ra khi lao tới.
  a[:ghosts].each_with_index do |ghost, i|
    lag = 0.026 * (i + 1)
    p = a.clamp((s - 0.38 - lag) / 0.51)
    p *= p
    gx, gy = KaitoSizzlySkid.path(a, p)

    ghost.x = base_x + gx - a[:start_x]
    ghost.y = base_y + gy - a[:start_y]
    ghost.zoom_x = zx
    ghost.zoom_y = zy * 0.97
    ghost.angle = base_angle - dir * Math.sin(p * Math::PI) * 9

    visible = s > 0.40 && s < 0.96
    ghost.opacity = visible ? (100 - i * 19) : 0
  end

  aura_fade = a.clamp((1.16 - s) / 0.28)
  aura_power = charge * aura_fade

  a[:aura].each_with_index do |flame, i|
    offset = i - 2
    flicker = Math.sin(s * 27 + i * 1.7)

    flame.x = px - dir * (12 + i * 9)
    flame.y = py - 12 - i % 2 * 8
    flame.oy = a[:flame_bitmap].height
    flame.angle = -dir * (12 + dash * 43 + i * 3)
    flame.zoom_x = 0.36 + (i % 2) * 0.10
    flame.zoom_y = (0.48 + 0.10 * flicker + dash * 0.27) * aura_power
    flame.opacity = 205 * aura_power
    flame.x += offset * 2
  end

  foot_glow = a[:foot_glow]
  foot_glow.x = px
  foot_glow.y = py - 2
  foot_glow.zoom_x = 1.12 + dash * 0.55
  foot_glow.zoom_y = 0.25
  foot_glow.opacity = 200 * aura_power

  #---------------------------------------------------------------------------
  # Vệt trượt nhiều lớp: mép đỏ mờ, thân cam, lõi vàng đứt nhịp.
  #---------------------------------------------------------------------------
  trail = a[:trail_bitmap]
  trail.clear
  a[:trail].opacity = 255
  trail_fade = a.clamp((1.61 - s) / 0.53)

  if s >= 0.38 && trail_fade > 0
    33.times do |i|
      p1 = dash * i / 33.0
      p2 = dash * (i + 1) / 33.0
      x1, y1 = KaitoSizzlySkid.path(a, p1)
      x2, y2 = KaitoSizzlySkid.path(a, p2)
      width = 11 + Math.sin(p1 * Math::PI) * 15
      alpha = trail_fade * (0.45 + p1 * 0.55)

      KaitoSizzlySkid.line(
        a, trail, x1, y1, x2, y2, width + 12,
        Color.new(220, 58, 31, 45 * alpha)
      )
      KaitoSizzlySkid.line(
        a, trail, x1, y1, x2, y2, width,
        Color.new(255, 119, 30, 125 * alpha)
      )
      if i % 5 != 0
        KaitoSizzlySkid.line(
          a, trail, x1, y1 - 1, x2, y2 - 1, width * 0.28,
          Color.new(255, 231, 136, 185 * alpha)
        )
      end
    end
  end

  a[:ground_flames].each_with_index do |pair, i|
    flame, smoke = pair
    position = (i + 0.5) / a[:ground_flames].length
    born = 0.38 + Math.sqrt(position) * 0.51
    age = s - born
    gx, gy = KaitoSizzlySkid.path(a, position)

    q = a.clamp(age / 0.57)
    active = age >= 0 && age < 0.57
    envelope = active ? Math.sin(q * Math::PI) : 0

    flame.oy = a[:flame_bitmap].height
    flame.x = gx
    flame.y = gy
    flame.angle = -dir * (22 + i % 3 * 10)
    flame.zoom_x = 0.18 + i % 3 * 0.055
    flame.zoom_y = (0.28 + i % 4 * 0.07) *
      (0.85 + Math.sin(s * 30 + i) * 0.15)
    flame.opacity = 220 * envelope

    smoke.x = gx - dir * q * 15
    smoke.y = gy - q * 22
    smoke.zoom_x = smoke.zoom_y = 0.25 + q * 0.45
    smoke.opacity = 100 * envelope
  end

  # 火花沿地面向后甩出。
  a[:speed_sparks].each_with_index do |spark, i|
    born = 0.39 + (i / 27.0) * 0.46
    age = s - born
    q = a.clamp(age / 0.36)
    p = a.clamp((born - 0.38) / 0.51)
    gx, gy = KaitoSizzlySkid.path(a, p * p)

    spark.x = gx - dir * q * (30 + i % 5 * 9)
    spark.y = gy - Math.sin(q * Math::PI) * (9 + i % 4 * 5)
    spark.angle = dir * (55 + q * 65)
    spark.zoom_x = 0.10 + i % 3 * 0.035
    spark.zoom_y = 0.24 + i % 4 * 0.07
    spark.opacity = age >= 0 && age < 0.36 ? (1 - q) * 240 : 0
  end

  #---------------------------------------------------------------------------
  # Va chạm: quạt lửa mở ra, đợt thứ hai cuộn lên quanh mục tiêu.
  #---------------------------------------------------------------------------
  a[:groups].each do |g|
    age = s - 0.89
    recoil = age >= 0 && age < 0.25 ?
      Math.sin(age * 76) * (1 - age / 0.25) : 0

    g[:body].x = g[:base_x] + dir * recoil * 7
    g[:body].y = g[:base_y] - recoil.abs * 2

    flash = age >= 0 && age < 0.19 ? (1 - age / 0.19) : 0
    if flash > 0
      g[:body].color = Color.new(255, 240, 197, 230 * flash)
    else
      g[:body].color = g[:color]
    end

    glow_q = a.clamp(age / 0.55)
    g[:glow].x = g[:x]
    g[:glow].y = g[:y] + 9
    g[:glow].zoom_x = 1.1 + glow_q * 1.3
    g[:glow].zoom_y = 1.3 + glow_q * 0.7
    g[:glow].opacity = age >= 0 && age < 0.55 ?
      Math.sin(glow_q * Math::PI) * 240 : 0

    g[:flames].each_with_index do |flame, i|
      delay = i % 3 * 0.035
      flame_age = age - delay
      p = a.clamp(flame_age / 0.59)
      spread = i - 5
      envelope = flame_age >= 0 && flame_age < 0.59 ?
        Math.sin(p * Math::PI) : 0

      flame.oy = a[:flame_bitmap].height
      flame.x = g[:x] + spread * (5 + p * 5)
      flame.y = g[:foot] + 4 - p * 7
      flame.angle = -spread * (6 + p * 3)
      flame.zoom_x = 0.38 + (1 - spread.abs / 6.0) * 0.22
      flame.zoom_y = (0.60 + (1 - spread.abs / 6.0) * 0.65) *
        (0.85 + Math.sin(s * 30 + i) * 0.15)
      flame.opacity = 240 * envelope
    end

    g[:rings].each_with_index do |ring, i|
      ring_age = age - i * 0.11
      p = a.clamp(ring_age / 0.41)
      ring.x = g[:x]
      ring.y = i == 0 ? g[:foot] : g[:y]
      ring.zoom_x = 0.18 + p * (i == 0 ? 1.65 : 1.12)
      ring.zoom_y = ring.zoom_x * (i == 0 ? 0.30 : 0.85)
      ring.opacity = ring_age >= 0 && ring_age < 0.41 ?
        (1 - p) * 240 : 0
    end

    g[:embers].each_with_index do |ember, i|
      delay = i % 7 * 0.014
      ember_age = age - delay
      p = a.clamp(ember_age / 0.83)
      theta = i * 2.399963
      speed = 40 + i % 8 * 10

      ember.x = g[:x] + Math.cos(theta) * speed * p +
        dir * p * 14
      ember.y = g[:y] +
        Math.sin(theta) * speed * p * 0.66 +
        p * p * 69 - p * 27

      ember.angle = i * 31 + p * (i.even? ? 130 : -130)
      ember.zoom_x = 0.12 + i % 3 * 0.055
      ember.zoom_y = 0.20 + i % 4 * 0.07
      ember.opacity = ember_age >= 0 && ember_age < 0.83 ?
        (1 - p) * 255 : 0
    end

    g[:smoke].each_with_index do |smoke, i|
      smoke_age = s - 1.12 - i % 4 * 0.045
      p = a.clamp(smoke_age / 0.82)
      side = i.even? ? -1 : 1

      smoke.x = g[:x] + side * (9 + p * (20 + i % 3 * 9))
      smoke.y = g[:foot] - 17 - p * (35 + i % 4 * 12)
      smoke.zoom_x = 0.35 + p * 0.75
      smoke.zoom_y = 0.30 + p * 0.60
      smoke.opacity = smoke_age >= 0 && smoke_age < 0.82 ?
        Math.sin(p * Math::PI) * 125 : 0
    end
  end

  impact_age = s - 0.89
  a[:flash].opacity = impact_age >= 0 && impact_age < 0.12 ?
    105 * (1 - impact_age / 0.12) : 0
end