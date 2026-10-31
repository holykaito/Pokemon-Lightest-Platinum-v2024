#===============================================================================
# MIND FIELD — Psychic Mine Network
# hit 0: Đặt bẫy
# hit 1: Bẫy kích hoạt
# Pokémon Essentials v21.1 / KaitoAnimation Core
#===============================================================================
module KaitoMindMine
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

  def self.setup(a, trigger)
    a[:trigger] = trigger
    ux, uy = a.center(a.user)
    a[:ux] = ux
    a[:uy] = uy

    if trigger
      battler = a.targets.first || a.user
      sprite = a.battler_sprite(battler)
      cx, cy = a.center(battler)
      foot = sprite.y +
        (sprite.src_rect.height - sprite.oy) * sprite.zoom_y

      body = a.copy(battler, hide_original: true, z: 20_022)
      a[:body] = body
      a[:body_base] = [body.x, body.y, body.color.clone]
      a[:cx] = cx
      a[:cy] = cy
      a[:floor_y] = foot
      a[:field_width] = 110
    else
      positions = []
      a.user.allOpposing.each do |battler|
        sprite = a.battler_sprite(battler)
        next unless KaitoAnimation.valid_sprite?(sprite)
        next unless sprite.visible && sprite.opacity > 0

        cx, cy = a.center(battler)
        foot = sprite.y +
          (sprite.src_rect.height - sprite.oy) * sprite.zoom_y
        positions << [cx, foot]
      end

      if positions.empty?
        a[:cx] = Graphics.width - ux
        a[:floor_y] = Graphics.height * (uy > Graphics.height / 2 ? 0.40 : 0.82)
        a[:field_width] = 145
      else
        xs = positions.map { |p| p[0] }
        a[:cx] = xs.inject(0.0) { |sum, x| sum + x } / xs.length
        a[:floor_y] = positions.inject(0.0) { |sum, p| sum + p[1] } /
          positions.length
        a[:field_width] = [[xs.max - xs.min + 130, 145].max, 260].min
      end
      a[:cy] = a[:floor_y] - 36
    end

    a[:mine_bitmap] = a.bitmap(64, 76) do |b|
      a.polygon(b, [
        [32, 3], [54, 33], [32, 71], [10, 33]
      ], Color.new(209, 151, 255, 120))

      a.polygon(b, [
        [32, 9], [49, 33], [32, 64], [15, 33]
      ], Color.new(127, 70, 211, 230))

      a.polygon(b, [
        [32, 9], [32, 35], [15, 33]
      ], Color.new(244, 212, 255, 245))

      a.polygon(b, [
        [32, 9], [49, 33], [32, 35]
      ], Color.new(192, 146, 246, 245))

      a.polygon(b, [
        [15, 33], [32, 35], [32, 64]
      ], Color.new(156, 91, 229, 235))

      a.polygon(b, [
        [32, 23], [40, 34], [32, 47], [24, 34]
      ], Color.new(255, 235, 255, 250))

      b.fill_rect(30, 27, 3, 15, Color.new(255, 255, 255, 240))
    end

    a[:shard_bitmap] = a.bitmap(22, 38) do |b|
      a.polygon(b, [
        [12, 0], [21, 13], [8, 37], [2, 19]
      ], Color.new(173, 114, 243, 235))
      a.polygon(b, [
        [12, 0], [12, 17], [8, 37], [6, 17]
      ], Color.new(248, 215, 255, 250))
    end

    a[:spark_bitmap] = a.bitmap(20, 20) do |b|
      a.polygon(b, [
        [10, 0], [12, 7], [20, 10], [12, 12],
        [10, 20], [8, 12], [0, 10], [8, 8]
      ], Color.new(246, 215, 255, 245))
    end

    a[:glow_bitmap] = a.bitmap(112, 112) do |b|
      18.downto(1) do |i|
        radius = i * 2.8
        points = []
        36.times do |j|
          theta = j * Math::PI * 2 / 36
          points << [
            56 + Math.cos(theta) * radius,
            56 + Math.sin(theta) * radius
          ]
        end
        a.polygon(b, points, Color.new(190, 116, 247, 6))
      end
    end

    a[:ring_bitmap] = a.ring(
      64, Color.new(223, 171, 255, 230), 3
    )

    a[:canvas] = a.bitmap(Graphics.width, Graphics.height)
    a[:network] = a.sprite(
      a[:canvas], z: 20_018, centered: false
    )

    a[:mines] = []
    count = trigger ? 3 : 7
    count.times do |i|
      if trigger
        theta = i * Math::PI * 2 / 3 - Math::PI / 2
        dx = Math.cos(theta) * 43
        dy = Math.sin(theta) * 16
      elsif i == 0
        dx = 0
        dy = 0
      else
        theta = (i - 1) * Math::PI * 2 / 6
        dx = Math.cos(theta) * a[:field_width] * 0.48
        dy = Math.sin(theta) * 25
      end

      a[:mines] << {
        sprite: a.sprite(a[:mine_bitmap], z: 20_028),
        glow: a.sprite(a[:glow_bitmap], z: 20_025),
        ring: a.sprite(a[:ring_bitmap], z: 20_019),
        dx: dx,
        dy: dy
      }
    end

    a[:waves] = []
    3.times do
      a[:waves] << a.sprite(a[:ring_bitmap], z: 20_033)
    end

    a[:particles] = []
    (trigger ? 42 : 28).times do |i|
      bitmap = trigger && i.even? ? a[:shard_bitmap] : a[:spark_bitmap]
      a[:particles] << a.sprite(bitmap, z: 20_036)
    end

    a[:burst_glow] = a.sprite(a[:glow_bitmap], z: 20_030)
    a[:flash] = a.sprite(
      a.bitmap(Graphics.width, Graphics.height) do |b|
        b.fill_rect(
          0, 0, b.width, b.height,
          Color.new(242, 219, 255)
        )
      end,
      z: 20_050,
      centered: false
    )

    if trigger
      a.sound_at(0.02, ["Confusion", "Psybeam"], 65, 130)
      a.sound_at(0.46, ["Psychic", "Psybeam"], 85, 110)
      a.sound_at(0.60, ["Confusion", "Psychic"], 75, 90)
    else
      a.sound_at(0.02, ["Confusion", "Psychic Terrain1"], 60, 105)
      a.sound_at(0.48, ["Psybeam", "Confusion"], 65, 125)
      a.sound_at(1.08, ["Psychic Terrain2", "Psychic"], 65, 110)
    end
  end

  def self.update(a)
    s = a.seconds
    pi = Math::PI
    canvas = a[:canvas]
    canvas.clear
    a[:network].opacity = 255

    if !a[:trigger]
      #---------------------------------------------------------------------
      # ĐẶT BẪY: lõi bay ra, hạ xuống rồi liên kết thành mạng.
      #---------------------------------------------------------------------
      fade = a.clamp((1.98 - s) / 0.38)
      link_form = a.clamp((s - 0.93) / 0.30)

      a[:mines].each_with_index do |mine, i|
        born = i * 0.065
        p = a.clamp((s - born) / 0.67)
        travel = p * p * (3 - 2 * p)
        dx = a[:cx] + mine[:dx]
        dy = a[:floor_y] + mine[:dy]

        x = a.lerp(a[:ux], dx, travel)
        y = a.lerp(a[:uy] - 15, dy - 18, travel)
        y -= Math.sin(p * pi) * (41 + i % 3 * 12)

        sink = a.clamp((s - 1.43 - i * 0.025) / 0.32)
        bob = Math.sin(s * 7 + i) * 3 * (1 - sink)

        sprite = mine[:sprite]
        sprite.x = x
        sprite.y = y + bob + sink * 18
        sprite.angle = Math.sin(s * 3 + i) * 12
        sprite.zoom_x = 0.13 + p * 0.29
        sprite.zoom_y = (0.13 + p * 0.29) * (1 - sink * 0.65)
        sprite.opacity = s >= born ? (1 - sink) * 235 * fade : 0

        glow = mine[:glow]
        glow.x = dx
        glow.y = dy - 5
        glow.zoom_x = 0.45 + link_form * 0.22
        glow.zoom_y = 0.24
        glow.opacity = p * link_form * fade * 120

        ring = mine[:ring]
        ring.x = dx
        ring.y = dy
        ring.angle = i * 23 + s * 20
        ring.zoom_x = 0.22 + link_form * 0.10
        ring.zoom_y = ring.zoom_x * 0.33
        ring.opacity = link_form * fade * (170 + Math.sin(s * 9 + i) * 30)
      end

      if link_form > 0
        # Trung tâm nối sáu nút ngoài; các nút ngoài nối thành lục giác.
        6.times do |i|
          center = [a[:cx], a[:floor_y]]
          m1 = a[:mines][i + 1]
          m2 = a[:mines][(i + 1) % 6 + 1]
          p1 = [a[:cx] + m1[:dx], a[:floor_y] + m1[:dy]]
          p2 = [a[:cx] + m2[:dx], a[:floor_y] + m2[:dy]]

          [ [center, p1], [p1, p2] ].each do |edge|
            from, to = edge
            tip = [
              a.lerp(from[0], to[0], link_form),
              a.lerp(from[1], to[1], link_form)
            ]

            line(a, canvas, from, tip, 7,
              Color.new(154, 91, 230, 38 * fade))
            line(a, canvas, from, tip, 1.5,
              Color.new(237, 192, 255, 175 * fade))

            # Hạt sáng chạy trên dây liên kết.
            u = (s * 1.3 + i * 0.17) % 1.0
            q1 = [a.lerp(from[0], tip[0], u), a.lerp(from[1], tip[1], u)]
            q2 = [
              a.lerp(from[0], tip[0], [u + 0.06, 1].min),
              a.lerp(from[1], tip[1], [u + 0.06, 1].min)
            ]
            line(a, canvas, q1, q2, 3,
              Color.new(255, 237, 255, 230 * fade))
          end
        end
      end

      a[:waves].each_with_index do |ring, i|
        age = s - 1.06 - i * 0.12
        p = a.clamp(age / 0.58)
        ring.x = a[:cx]
        ring.y = a[:floor_y]
        ring.zoom_x = (0.35 + p * 1.25) * a[:field_width] / 145.0
        ring.zoom_y = (0.35 + p * 1.25) * 0.30
        ring.opacity = age >= 0 && age < 0.58 ?
          Math.sin(p * pi) * 140 * fade : 0
      end

      a[:particles].each_with_index do |spark, i|
        age = s - 1.28 - i % 7 * 0.045
        p = a.clamp(age / 0.58)
        theta = i * 2.39996
        spark.x = a[:cx] + Math.cos(theta) * a[:field_width] * 0.43
        spark.y = a[:floor_y] + Math.sin(theta) * 20 - p * 30
        spark.angle = i * 29 + p * 70
        spark.zoom_x = spark.zoom_y = 0.13 + i % 3 * 0.055
        spark.opacity = age >= 0 && age < 0.58 ?
          Math.sin(p * pi) * 220 : 0
      end

    else
      #---------------------------------------------------------------------
      # KÍCH HOẠT: lõi trồi lên → co vào → phát nổ.
      #---------------------------------------------------------------------
      rise = a.clamp(s / 0.23)
      squeeze = a.clamp((s - 0.27) / 0.18)
      detonate = 0.46

      a[:mines].each_with_index do |mine, i|
        x = a[:cx] + mine[:dx] * (1 - squeeze * 0.66)
        y = a[:floor_y] + mine[:dy] - rise * 32 - squeeze * 9
        before_burst = a.clamp((detonate - s) / 0.06)

        sprite = mine[:sprite]
        sprite.x = x
        sprite.y = y
        sprite.angle = s * (i.even? ? 85 : -85)
        sprite.zoom_x = 0.40 * rise * (1 - squeeze * 0.28)
        sprite.zoom_y = 0.40 * rise * (1 + squeeze * 0.22)
        sprite.color = Color.new(255, 240, 255, squeeze * 220)
        sprite.opacity = rise * before_burst * 255

        glow = mine[:glow]
        glow.x = x
        glow.y = y
        glow.zoom_x = glow.zoom_y = 0.6 + squeeze * 0.35
        glow.opacity = rise * before_burst * (120 + squeeze * 100)

        ring = mine[:ring]
        ring.x = a[:cx] + mine[:dx]
        ring.y = a[:floor_y] + mine[:dy]
        ring.zoom_x = 0.36 * (1 - squeeze * 0.5)
        ring.zoom_y = ring.zoom_x * 0.32
        ring.opacity = rise * before_burst * 220
      end

      age = s - detonate
      burst = a.clamp(age / 0.31)
      glow = a[:burst_glow]
      glow.x = a[:cx]
      glow.y = a[:cy]
      glow.zoom_x = 0.25 + burst * 2.1
      glow.zoom_y = 0.35 + burst * 2.2
      glow.opacity = age >= 0 && age < 0.44 ?
        a.clamp((0.44 - age) / 0.27) * 255 : 0

      # Nhát sáng sắc cạnh tại tâm nổ.
      if age >= 0 && age < 0.19
        fade = 1 - age / 0.19
        10.times do |i|
          theta = i * pi * 2 / 10 + 0.16
          radius = (31 + i % 3 * 14) * (0.5 + burst)
          tip = [
            a[:cx] + Math.cos(theta) * radius,
            a[:cy] + Math.sin(theta) * radius
          ]
          line(a, canvas, [a[:cx], a[:cy]], tip, 8,
            Color.new(188, 115, 250, 100 * fade))
          line(a, canvas, [a[:cx], a[:cy]], tip, 2,
            Color.new(255, 237, 255, 245 * fade))
        end
      end

      a[:waves].each_with_index do |ring, i|
        ring_age = age - i * 0.065
        p = a.clamp(ring_age / 0.48)
        ring.x = a[:cx]
        ring.y = i == 2 ? a[:floor_y] : a[:cy]
        ring.zoom_x = 0.15 + p * (i == 2 ? 1.8 : 1.35)
        ring.zoom_y = ring.zoom_x * (i == 2 ? 0.28 : 0.83)
        ring.opacity = ring_age >= 0 && ring_age < 0.48 ?
          (1 - p) * 235 : 0
      end

      a[:particles].each_with_index do |particle, i|
        particle_age = age - i % 6 * 0.009
        p = a.clamp(particle_age / 0.81)
        theta = i * 2.39996
        radius = 34 + i % 7 * 9
        spread = 1 - (1 - p) ** 3

        particle.x = a[:cx] + Math.cos(theta) * radius * spread
        particle.y = a[:cy] + Math.sin(theta) * radius * spread * 0.75 +
          p * p * 46
        particle.angle = i * 31 + p * (i.even? ? 150 : -120)
        particle.zoom_x = particle.zoom_y = 0.18 + i % 4 * 0.075
        particle.opacity = particle_age >= 0 && particle_age < 0.81 ?
          (1 - p) * 245 : 0
      end

      bx, by, original_color = a[:body_base]
      shake = age >= 0 && age < 0.22 ?
        Math.sin(age * 117) * (1 - age / 0.22) ** 2 : 0

      a[:body].x = bx + shake * 6
      a[:body].y = by - shake.abs * 2
      a[:body].color = age >= 0 && age < 0.18 ?
        Color.new(239, 210, 255, (1 - age / 0.18) * 235) :
        original_color

      a[:flash].opacity = age >= 0 && age < 0.12 ?
        (1 - age / 0.12) * 85 : 0
    end
  end
end

KaitoAnimation.register(
  :MINDFIELD,
  duration: 2.0,
  hit: 0,
  require_target: false,
  setup: proc { |a| KaitoMindMine.setup(a, false) }
) do |a, _t|
  KaitoMindMine.update(a)
end

KaitoAnimation.register(
  :MINDFIELD,
  duration: 1.5,
  hit: 1,
  setup: proc { |a| KaitoMindMine.setup(a, true) }
) do |a, _t|
  KaitoMindMine.update(a)
end