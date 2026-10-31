#===============================================================================
# BUZZY BUZZ — Voltage Rattle
# Pokémon Essentials v21.1 / KaitoAnimation Core
#===============================================================================
module KaitoBuzzyVoltage
  def self.line(a, bitmap, p1, p2, width, color)
    dx = p2[0] - p1[0]
    dy = p2[1] - p1[1]
    length = Math.sqrt(dx * dx + dy * dy)
    return if length < 0.01

    nx = -dy / length * width * 0.5
    ny =  dx / length * width * 0.5

    a.polygon(bitmap, [
      [p1[0] + nx, p1[1] + ny],
      [p2[0] + nx, p2[1] + ny],
      [p2[0] - nx, p2[1] - ny],
      [p1[0] - nx, p1[1] - ny]
    ], color)
  end

  def self.arc(a, bitmap, points, power = 1.0, width = 1.0)
    return if power <= 0

    [
      [12.0 * width, Color.new(101, 213, 255, 40 * power)],
      [ 6.0 * width, Color.new(255, 193, 40, 155 * power)],
      [ 2.1 * width, Color.new(255, 255, 220, 250 * power)]
    ].each do |size, color|
      (points.length - 1).times do |i|
        line(a, bitmap, points[i], points[i + 1], size, color)
      end
    end
  end

  def self.glow(a)
    a.bitmap(112, 112) do |b|
      18.downto(1) do |i|
        radius = i * 2.8
        points = []
        36.times do |j|
          angle = j * Math::PI * 2.0 / 36
          points << [
            56 + Math.cos(angle) * radius,
            56 + Math.sin(angle) * radius
          ]
        end
        a.polygon(b, points, Color.new(255, 219, 89, 6))
      end
    end
  end

  def self.bolt(a)
    a.bitmap(34, 62) do |b|
      a.polygon(b, [
        [20, 0], [4, 32], [15, 31],
        [9, 61], [31, 21], [19, 24]
      ], Color.new(255, 179, 31, 160))

      a.polygon(b, [
        [20, 5], [9, 29], [19, 27],
        [13, 51], [26, 25], [16, 29]
      ], Color.new(255, 255, 199, 255))
    end
  end
end

KaitoAnimation.register(
  :BUZZYBUZZ,
  duration: 2.15,
  setup: proc { |a|
    ux, uy = a.center(a.user)
    tx, ty = a.center(a.targets.first)
    direction = tx >= ux ? 1 : -1

    a[:ux] = ux
    a[:uy] = uy
    a[:sx] = ux + direction * 32
    a[:sy] = uy - 4
    a[:direction] = direction

    a[:glow_bitmap] = KaitoBuzzyVoltage.glow(a)
    a[:bolt_bitmap] = KaitoBuzzyVoltage.bolt(a)
    a[:ring_bitmap] = a.ring(
      60, Color.new(255, 230, 132, 235), 3
    )

    a[:spark_bitmap] = a.bitmap(24, 24) do |b|
      a.polygon(b, [
        [12, 0], [15, 9], [24, 12], [15, 14],
        [12, 24], [9, 15], [0, 12], [9, 9]
      ], Color.new(255, 247, 190, 250))

      b.fill_rect(10, 10, 4, 4, Color.new(255, 255, 255))
    end

    a[:core_bitmap] = a.bitmap(64, 64) do |b|
      a.polygon(b, [
        [32, 3], [38, 22], [54, 12], [43, 29],
        [61, 35], [42, 39], [48, 58], [33, 44],
        [18, 61], [23, 41], [3, 45], [20, 32],
        [5, 18], [25, 23]
      ], Color.new(255, 190, 45, 190))

      a.polygon(b, [
        [32, 14], [37, 27], [49, 31], [37, 36],
        [32, 49], [27, 36], [15, 32], [27, 27]
      ], Color.new(255, 255, 220, 255))
    end

    a[:core] = a.sprite(a[:core_bitmap], z: 20_028)
    a[:source_glow] = a.sprite(a[:glow_bitmap], z: 20_025)

    a[:charge_sparks] = []
    14.times do
      a[:charge_sparks] << a.sprite(a[:spark_bitmap], z: 20_027)
    end

    a[:canvas] = a.bitmap(Graphics.width, Graphics.height)
    a[:electricity] = a.sprite(
      a[:canvas], z: 20_032, centered: false
    )

    a[:groups] = []
    a.targets.each do |battler|
      sprite = a.battler_sprite(battler)
      cx, cy = a.center(battler)
      foot = sprite.y +
        (sprite.src_rect.height - sprite.oy) * sprite.zoom_y

      width = sprite.src_rect.width * sprite.zoom_x
      height = sprite.src_rect.height * sprite.zoom_y
      radius = [[width * 0.48, 29].max, 60].min
      cage_height = [[height * 0.80, 58].max, 118].min

      body = a.copy(battler, hide_original: true, z: 20_022)
      group = {
        x: cx,
        y: cy,
        foot: foot,
        radius: radius,
        height: cage_height,
        body: body,
        bx: body.x,
        by: body.y,
        color: body.color.clone,
        glow: a.sprite(a[:glow_bitmap], z: 20_029),
        rings: [],
        sparks: [],
        bolts: []
      }

      3.times do
        group[:rings] << a.sprite(a[:ring_bitmap], z: 20_034)
      end
      32.times do
        group[:sparks] << a.sprite(a[:spark_bitmap], z: 20_036)
      end
      8.times do
        group[:bolts] << a.sprite(a[:bolt_bitmap], z: 20_035)
      end

      a[:groups] << group
    end

    a[:veil] = a.sprite(
      a.bitmap(Graphics.width, Graphics.height) do |b|
        b.fill_rect(
          0, 0, b.width, b.height,
          Color.new(34, 43, 71)
        )
      end,
      z: 20_010,
      centered: false
    )

    a[:flash] = a.sprite(
      a.bitmap(Graphics.width, Graphics.height) do |b|
        b.fill_rect(
          0, 0, b.width, b.height,
          Color.new(255, 249, 214)
        )
      end,
      z: 20_050,
      centered: false
    )

    # Core bỏ qua âm thanh nếu không tìm thấy file tương ứng.
    a.sound_at(0.03, ["Charge", "Thunder Wave"], 65, 115)
    a.sound_at(0.48, ["Thunder Shock", "Thunderbolt"], 80, 125)
    a.sound_at(0.70, ["Thunder Shock", "Thunderbolt"], 85, 135)
    a.sound_at(0.92, ["Thunderbolt", "Thunder"], 90, 115)
    a.sound_at(1.25, ["Thunder Wave", "Thunder Shock"], 65, 105)
  }
) do |a, _t|
  s = a.seconds
  pi = Math::PI
  tick = (s * 27).floor
  canvas = a[:canvas]
  canvas.clear
  a[:electricity].opacity = 255

  #---------------------------------------------------------------------------
  # 1. Lõi điện rung nhanh, tia nhỏ bị hút vào tâm.
  #---------------------------------------------------------------------------
  charge = a.clamp(s / 0.39)
  source_fade = a.clamp((1.12 - s) / 0.28)
  vibration = Math.sin(s * 95)

  core = a[:core]
  core.x = a[:sx] + vibration * 1.8 * charge
  core.y = a[:sy] + Math.cos(s * 83) * 1.4 * charge
  core.angle = s * 150
  core.zoom_x = 0.18 + charge * 0.58 + vibration * 0.035
  core.zoom_y = 0.18 + charge * 0.58 - vibration * 0.035
  core.opacity = charge * source_fade * 255

  glow = a[:source_glow]
  glow.x = a[:sx]
  glow.y = a[:sy]
  glow.zoom_x = glow.zoom_y = 0.4 + charge * 0.85
  glow.opacity = charge * source_fade * (155 + vibration * 25)

  a[:charge_sparks].each_with_index do |spark, i|
    phase = (s * 1.8 + i / 14.0) % 1.0
    theta = i * 2.39996 + s * 2.6
    radius = (1 - phase) * (30 + i % 4 * 7)

    spark.x = a[:sx] + Math.cos(theta) * radius
    spark.y = a[:sy] + Math.sin(theta) * radius * 0.8
    spark.angle = i * 25 + s * 160
    spark.zoom_x = spark.zoom_y = 0.12 + i % 3 * 0.055
    spark.opacity = Math.sin(phase * pi) * charge * source_fade * 230
  end

  # Những nhánh điện ngắn quanh lõi.
  if s > 0.09 && s < 0.48
    5.times do |i|
      theta = i * pi * 2 / 5 + tick * 0.41
      radius = 18 + charge * 21
      points = [
        [a[:sx], a[:sy]],
        [
          a[:sx] + Math.cos(theta + 0.28) * radius * 0.55,
          a[:sy] + Math.sin(theta + 0.28) * radius * 0.55
        ],
        [
          a[:sx] + Math.cos(theta) * radius,
          a[:sy] + Math.sin(theta) * radius
        ]
      ]
      KaitoBuzzyVoltage.arc(a, canvas, points, charge * 0.65, 0.5)
    end
  end

  screen_flash = 0.0

  #---------------------------------------------------------------------------
  # 2. Ba xung sét, mỗi xung mạnh hơn và nhiều nhánh hơn.
  #---------------------------------------------------------------------------
  a[:groups].each do |g|
    body_flash = 0.0
    shake = 0.0
    impact_power = 0.0

    [0.48, 0.70, 0.92].each_with_index do |start, pulse|
      age = s - start
      reach = a.clamp(age / 0.075)
      fade = a.clamp((0.23 - age) / 0.12)
      active = age >= 0 && age < 0.23

      if active
        dx = g[:x] - a[:sx]
        dy = g[:y] - a[:sy]
        length = Math.sqrt(dx * dx + dy * dy)
        length = 1.0 if length < 1.0
        nx = -dy / length
        ny = dx / length

        2.times do |lane|
          points = []
          15.times do |j|
            u = reach * j / 14.0
            jagged = Math.sin(j * 17.13 + tick * 7.7 + lane * 9.1)
            jagged *= (9 + pulse * 4) * Math.sin(u * pi)
            jagged += (lane == 0 ? -4 : 4) * Math.sin(u * pi)

            points << [
              a[:sx] + dx * u + nx * jagged,
              a[:sy] + dy * u + ny * jagged
            ]
          end

          KaitoBuzzyVoltage.arc(
            a, canvas, points, fade, 0.70 + pulse * 0.17
          )

          # Nhánh sét tách khỏi thân chính rồi tắt ngắn.
          [5, 9].each do |j|
            root = points[j]
            side = (j + lane).even? ? 1 : -1
            branch = [
              root,
              [
                root[0] + dx / length * 11 + nx * side * 12,
                root[1] + dy / length * 11 + ny * side * 12
              ],
              [
                root[0] + dx / length * 25 + nx * side * 19,
                root[1] + dy / length * 25 + ny * side * 19
              ]
            ]
            KaitoBuzzyVoltage.arc(a, canvas, branch, fade * 0.7, 0.45)
          end
        end
      end

      hit_age = age - 0.075
      if hit_age >= 0 && hit_age < 0.17
        power = 1 - hit_age / 0.17
        body_flash = [body_flash, power * (160 + pulse * 40)].max
        impact_power = [impact_power, power].max
        shake += Math.sin(hit_age * 135) * power * (2 + pulse * 1.5)
        screen_flash = [
          screen_flash, power * (pulse == 2 ? 90 : 35)
        ].max
      end

      ring = g[:rings][pulse]
      ring_age = s - start - 0.075
      p = a.clamp(ring_age / 0.31)
      ring.x = g[:x]
      ring.y = g[:y]
      ring.zoom_x = 0.12 + p * (0.85 + pulse * 0.25)
      ring.zoom_y = ring.zoom_x * 0.78
      ring.opacity = ring_age >= 0 && ring_age < 0.31 ?
        (1 - p) * 225 : 0
    end

    #-----------------------------------------------------------------------
    # 3. Lồng điện dựng quanh mục tiêu rồi siết vào.
    #-----------------------------------------------------------------------
    cage_age = s - 1.05
    cage_form = a.clamp(cage_age / 0.16)
    cage_close = a.clamp((s - 1.25) / 0.26)
    cage_fade = a.clamp((1.65 - s) / 0.22)

    if cage_age >= 0 && cage_fade > 0
      radius = g[:radius] * (1 - cage_close * 0.46)

      5.times do |i|
        theta = i * pi * 2 / 5 + s * 2
        cx = g[:x] + Math.cos(theta) * radius
        ground_y = g[:foot] + Math.sin(theta) * radius * 0.25
        points = []

        9.times do |j|
          p = j / 8.0
          zigzag = Math.sin(j * 12.7 + tick * 8.3 + i) * 5
          points << [
            cx + zigzag * Math.sin(p * pi),
            ground_y - p * g[:height] * cage_form
          ]
        end

        KaitoBuzzyVoltage.arc(
          a, canvas, points, cage_fade * 0.72, 0.56
        )
      end

      # Vòng điện ngoằn ngoèo xoay ngang quanh thân.
      points = []
      33.times do |j|
        theta = j * pi * 2 / 32
        jitter = Math.sin(j * 9.3 + tick * 4.1) * 3
        points << [
          g[:x] + Math.cos(theta) * (radius + jitter),
          g[:y] + Math.sin(theta) * radius * 0.34
        ]
      end
      KaitoBuzzyVoltage.arc(a, canvas, points, cage_fade * 0.8, 0.55)
    end

    # Hạt điện bắn ra từ nhịp mạnh nhất.
    g[:sparks].each_with_index do |spark, i|
      age = s - 1.00 - i % 5 * 0.012
      p = a.clamp(age / 0.65)
      theta = i * 2.39996
      distance = 28 + i % 6 * 10
      spread = 1 - (1 - p) ** 2

      spark.x = g[:x] + Math.cos(theta) * distance * spread
      spark.y = g[:y] + Math.sin(theta) * distance * spread * 0.75 +
        p * p * 25
      spark.angle = i * 31 + p * 140
      spark.zoom_x = spark.zoom_y = 0.12 + i % 4 * 0.07
      spark.opacity = age >= 0 && age < 0.65 ?
        (1 - p) * 245 : 0
    end

    # Điện dư chớp theo cụm, không sáng liên tục.
    residual = a.clamp((2.12 - s) / 0.34)
    g[:bolts].each_with_index do |bolt, i|
      theta = i * pi * 2 / 8
      blink = (tick + i * 3) % 9 < 3
      visible = s > 1.28 && s < 2.12 && blink

      bolt.x = g[:x] + Math.cos(theta) * g[:radius] * 0.76
      bolt.y = g[:y] + Math.sin(theta) * g[:height] * 0.36
      bolt.angle = -theta * 180 / pi + 25
      bolt.zoom_x = bolt.zoom_y = 0.28 + i % 3 * 0.09
      bolt.opacity = visible ? 235 * residual : 0
    end

    glow = g[:glow]
    glow.x = g[:x]
    glow.y = g[:y]
    glow.zoom_x = 1.0 + impact_power * 0.6
    glow.zoom_y = 1.3 + impact_power * 0.5
    glow.opacity = [
      impact_power * 220,
      cage_form * cage_fade * 95
    ].max

    g[:body].x = g[:bx] + shake
    g[:body].y = g[:by] - shake.abs * 0.25
    g[:body].color = body_flash > 0 ?
      Color.new(255, 251, 190, body_flash) : g[:color]
  end

  a[:flash].opacity = screen_flash
  a[:veil].opacity =
    a.clamp(s / 0.30) * a.clamp((1.85 - s) / 0.45) * 48
end