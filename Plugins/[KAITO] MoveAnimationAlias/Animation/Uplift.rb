#===============================================================================
# UPLIFT — Phấn chấn
# Tăng Speed cho người dùng và đồng minh
# Yêu cầu: 000_AnimationCore.rb
#===============================================================================

KaitoAnimation.register(
  :UPLIFT,
  duration: 2.10,
  require_target: false,
  setup: proc do |a|
    a.sound_at(0.04, ["PRSFX- Refresh"], 45, 115)
    a.sound_at(0.54, ["PRSFX- Agility"], 55, 115)
    a.sound_at(1.05, ["PRSFX- Dazzling Gleam"], 40, 125)

    #---------------------------------------------------------------------------
    # Ánh sáng ấm dưới chân
    #---------------------------------------------------------------------------
    glow = a.bitmap(156, 60) do |b|
      60.times do |y|
        156.times do |x|
          r = ((x - 77.5) / 76.0)**2 +
              ((y - 29.5) / 28.0)**2
          next if r > 1.0

          b.set_pixel(
            x, y,
            Color.new(255, 198, 219, ((1.0 - r) * 150).to_i)
          )
        end
      end
    end

    ring = a.ring(57, Color.new(255, 224, 166, 225), 2)

    #---------------------------------------------------------------------------
    # Dải sáng mềm hướng lên
    #---------------------------------------------------------------------------
    ribbon = a.bitmap(34, 110) do |b|
      a.polygon(
        b,
        [[14, 110], [6, 91], [5, 72], [15, 49],
         [22, 31], [18, 13], [23, 0], [28, 19],
         [28, 36], [20, 55], [12, 76], [13, 92],
         [22, 110]],
        Color.new(247, 168, 210, 155)
      )
      a.polygon(
        b,
        [[17, 108], [10, 90], [10, 74], [19, 52],
         [25, 32], [23, 15], [26, 29], [23, 48],
         [15, 73], [15, 90], [23, 108]],
        Color.new(255, 241, 206, 225)
      )
    end

    #---------------------------------------------------------------------------
    # Mũi tên hướng lên, viền hồng và lõi vàng kem
    #---------------------------------------------------------------------------
    arrow = a.bitmap(36, 44) do |b|
      a.polygon(
        b,
        [[18, 0], [35, 18], [26, 18], [26, 43],
         [10, 43], [10, 18], [1, 18]],
        Color.new(239, 155, 202, 240)
      )
      a.polygon(
        b,
        [[18, 5], [28, 15], [22, 15], [22, 38],
         [14, 38], [14, 15], [8, 15]],
        Color.new(255, 234, 175, 255)
      )
      b.fill_rect(16, 16, 3, 19, Color.new(255, 255, 235, 245))
    end

    #---------------------------------------------------------------------------
    # Tia lấp lánh bốn cánh
    #---------------------------------------------------------------------------
    sparkle = a.bitmap(20, 20) do |b|
      a.polygon(
        b,
        [[10, 0], [13, 7], [20, 10], [13, 13],
         [10, 20], [7, 13], [0, 10], [7, 7]],
        Color.new(255, 235, 188, 250)
      )
      b.fill_rect(8, 8, 4, 4, Color.new(255, 255, 249, 255))
    end

    petal = a.bitmap(16, 22) do |b|
      a.polygon(
        b,
        [[8, 0], [15, 8], [13, 16], [7, 22],
         [1, 14], [2, 6]],
        Color.new(255, 192, 221, 225)
      )
      a.polygon(
        b,
        [[8, 3], [10, 11], [7, 19], [5, 11]],
        Color.new(255, 239, 244, 235)
      )
    end

    #---------------------------------------------------------------------------
    # Người dùng và đồng minh đang hiện diện trên sân
    #---------------------------------------------------------------------------
    battlers = ([a.user] + a.user.allAllies).select do |battler|
      next false if battler.fainted?
      sprite = a.battler_sprite(battler)
      next false unless KaitoAnimation.valid_sprite?(sprite)
      next false unless sprite.visible && sprite.opacity > 0
      next false if battler.isCommander?
      next false if battler.respond_to?(:vanishMode) &&
                    battler.vanishMode > 0
      true
    end

    a[:groups] = battlers.each_with_index.map do |battler, i|
      original = a.battler_sprite(battler)
      cx, cy = a.center(battler)
      ground = original.y +
               (original.src_rect.height - original.oy) * original.zoom_y

      body = a.copy(battler, hide_original: true, z: 20_018)

      {
        x: cx, y: cy, ground: ground,
        delay: i == 0 ? 0.0 : 0.12,
        body: body,
        base_x: body.x, base_y: body.y,
        color: body.color.clone,
        glow: a.sprite(glow, z: 20_010),
        rings: Array.new(2) { a.sprite(ring, z: 20_012) },
        ribbons: Array.new(3) do |j|
          s = a.sprite(ribbon, z: j == 1 ? 20_024 : 20_014)
          s.ox = 17
          s.oy = 110
          s
        end,
        arrows: Array.new(3) { a.sprite(arrow, z: 20_028) },
        sparks: Array.new(18) { a.sprite(sparkle, z: 20_030) },
        petals: Array.new(10) { a.sprite(petal, z: 20_026) }
      }
    end
  end
) do |a, _t|
  a[:groups].each do |g|
    sec = a.seconds - g[:delay]
    cx = g[:x]
    cy = g[:y]
    ground = g[:ground]

    #=============================================================================
    # 1. ÁNH SÁNG LAN DƯỚI CHÂN
    #=============================================================================
    form = a.clamp(sec / 0.32)
    fade = a.clamp((1.96 - sec) / 0.44)

    glow = g[:glow]
    glow.x = cx
    glow.y = ground - 2
    glow.zoom_x = 0.35 + form * 0.75
    glow.zoom_y = 0.55 + form * 0.35
    glow.opacity = (form * fade * 225).to_i

    g[:rings].each_with_index do |ring, i|
      q = (sec - 0.08 - i * 0.22) / 0.68
      p = a.clamp(q)

      ring.x = cx
      ring.y = ground - 2
      ring.zoom_x = 0.20 + p * 1.10
      ring.zoom_y = ring.zoom_x * 0.27
      ring.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 210).to_i : 0
    end

    #=============================================================================
    # 2. DẢI SÁNG NÂNG LÊN QUANH CƠ THỂ
    #=============================================================================
    g[:ribbons].each_with_index do |ribbon, i|
      q = (sec - 0.22 - i * 0.07) / 0.98
      p = a.clamp(q)
      side = i - 1

      ribbon.x = cx + side * (23 + Math.sin(p * Math::PI) * 8)
      ribbon.y = ground - p * 14
      ribbon.zoom_x = 0.48 + Math.sin(p * Math::PI) * 0.18
      ribbon.zoom_y = 0.20 + Math.sin(p * Math::PI) * 0.80
      ribbon.angle = side * -8
      ribbon.mirror = i == 2
      ribbon.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 220).to_i : 0
    end

    # Nhún vui một nhịp, sau đó trở lại đúng vị trí.
    q = (sec - 0.43) / 0.57
    p = a.clamp(q)
    bounce = Math.sin(p * Math::PI)

    body = g[:body]
    body.x = g[:base_x]
    body.y = g[:base_y] - bounce * 5

    warmth = a.clamp((sec - 0.28) / 0.20) *
             a.clamp((1.30 - sec) / 0.42)
    body.color = warmth > 0 ?
      Color.new(255, 223, 194, (warmth * 50).to_i) : g[:color]

    #=============================================================================
    # 3. PHẤN CHẤN — MŨI TÊN SPEED BAY LÊN
    #=============================================================================
    g[:arrows].each_with_index do |arrow, i|
      q = (sec - 0.58 - i * 0.12) / 0.72
      p = a.clamp(q)

      arrow.x = cx + [-22, 0, 22][i]
      arrow.y = cy + 16 - p * (53 + i * 5)
      arrow.zoom_x = [0.40, 0.55, 0.40][i]
      arrow.zoom_y = arrow.zoom_x
      arrow.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 240).to_i : 0
    end

    # Cánh sáng hồng nâng lên theo đường cong nhẹ.
    g[:petals].each_with_index do |petal, i|
      q = (sec - 0.30 - i % 5 * 0.055) / 1.02
      p = a.clamp(q)

      petal.x = cx + Math.sin(i * 2.399 + p * 2.0) * (22 + i % 3 * 9)
      petal.y = ground - 8 - p * (61 + i % 4 * 12)
      petal.angle = i * 29 + p * 110
      petal.zoom_x = 0.30 + i % 3 * 0.12
      petal.zoom_y = petal.zoom_x
      petal.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 215).to_i : 0
    end

    #=============================================================================
    # 4. KẾT THÚC — LẤP LÁNH VÀ NHẸ DẦN
    #=============================================================================
    g[:sparks].each_with_index do |spark, i|
      q = (sec - 0.83 - i % 6 * 0.055) / 0.84
      p = a.clamp(q)
      theta = i * 2.399

      spark.x = cx + Math.cos(theta) * (20 + p * 24) +
                Math.sin(p * 3 + i) * 4
      spark.y = cy + Math.sin(theta) * 30 - p * 27
      spark.angle = i * 31 + p * 50
      spark.zoom_x = 0.20 + i % 3 * 0.12 +
                     Math.sin(p * Math::PI) * 0.10
      spark.zoom_y = spark.zoom_x
      spark.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 235).to_i : 0
    end
  end
end