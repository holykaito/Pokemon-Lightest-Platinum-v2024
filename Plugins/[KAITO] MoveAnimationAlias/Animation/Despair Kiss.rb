#===============================================================================
# DESPAIR KISS — Nụ hôn tuyệt vọng
# Yêu cầu: 000_AnimationCore.rb
#===============================================================================

KaitoAnimation.register(
  :DESPAIRKISS,
  duration: 2.20,
  setup: proc do |a|
    a.sound_at(0.08, ["PRSFX- Draining Kiss1"], 55, 90)
    a.sound_at(0.68, ["PRSFX- Draining Kiss2"], 65, 85)
    a.sound_at(0.98, ["PRSFX- Absorb1"], 60, 105)
    a.sound_at(1.52, ["PRSFX- Absorb2"], 50, 115)

    source = a.battler_sprite
    ux, uy = a.center
    a[:ux] = ux
    a[:uy] = uy
    a[:ground] = source.y +
      (source.src_rect.height - source.oy) * source.zoom_y

    #---------------------------------------------------------------------------
    # Nụ hôn: viền tím, thân đỏ mận, khe môi tối
    #---------------------------------------------------------------------------
    lips = a.bitmap(84, 50) do |b|
      a.polygon(
        b,
        [[2, 25], [18, 13], [29, 4], [40, 12],
         [45, 12], [56, 4], [68, 14], [82, 25],
         [67, 39], [53, 47], [31, 47], [16, 38]],
        Color.new(170, 108, 192, 235)
      )
      a.polygon(
        b,
        [[8, 25], [22, 16], [30, 10], [41, 18],
         [45, 18], [55, 10], [65, 18], [76, 25],
         [62, 35], [51, 41], [33, 41], [21, 34]],
        Color.new(102, 34, 91, 250)
      )
      a.polygon(
        b,
        [[8, 25], [27, 23], [42, 26], [58, 23],
         [76, 25], [58, 30], [42, 31], [26, 29]],
        Color.new(27, 12, 37, 255)
      )
      a.polygon(
        b,
        [[22, 17], [30, 11], [37, 17], [29, 15]],
        Color.new(225, 166, 225, 235)
      )
    end

    #---------------------------------------------------------------------------
    # Hai nửa trái tim với khe rạn hình tia sét
    #---------------------------------------------------------------------------
    heart_shapes = [
      [[35, 16], [25, 5], [13, 3], [3, 12], [2, 28],
       [10, 42], [33, 65], [29, 46], [35, 35], [30, 27]],
      [[37, 16], [47, 5], [59, 3], [69, 12], [70, 28],
       [62, 42], [37, 65], [33, 47], [39, 35], [34, 27]]
    ]

    hearts = heart_shapes.each_with_index.map do |points, i|
      a.bitmap(72, 70) do |b|
        a.polygon(b, points, Color.new(129, 64, 153, 245))

        inner = points.map do |x, y|
          [36 + (x - 36) * 0.82, 33 + (y - 33) * 0.82]
        end
        a.polygon(b, inner, Color.new(49, 22, 67, 250))

        if i == 0
          a.polygon(
            b,
            [[9, 17], [15, 10], [24, 11], [15, 15], [12, 23]],
            Color.new(206, 146, 225, 225)
          )
        end
      end
    end

    #---------------------------------------------------------------------------
    # Năng lượng hút về: quầng tím mềm, lõi lavender
    #---------------------------------------------------------------------------
    energy = a.bitmap(36, 36) do |b|
      36.times do |y|
        36.times do |x|
          r = Math.sqrt((x - 17.5)**2 + (y - 17.5)**2) / 17.0
          next if r > 1.0
          b.set_pixel(
            x, y,
            Color.new(166, 96, 205, ((1.0 - r)**2 * 180).to_i)
          )
        end
      end

      a.polygon(
        b,
        [[18, 9], [23, 16], [21, 23], [15, 25],
         [12, 18], [14, 13]],
        Color.new(211, 165, 239, 240)
      )
      b.fill_rect(16, 15, 3, 5, Color.new(246, 225, 255, 245))
    end

    sparkle = a.bitmap(18, 18) do |b|
      a.polygon(
        b,
        [[9, 0], [11, 6], [18, 9], [11, 11],
         [9, 18], [6, 11], [0, 9], [6, 6]],
        Color.new(229, 185, 242, 245)
      )
    end

    target_ring = a.ring(48, Color.new(166, 103, 198, 215), 2)
    heal_ring = a.ring(55, Color.new(221, 172, 238, 225), 3)

    a[:heal_rings] = Array.new(2) do
      a.sprite(heal_ring, z: 20_026)
    end
    a[:heal_sparks] = Array.new(18) do
      a.sprite(sparkle, z: 20_030)
    end

    a[:groups] = a.targets.map do |target|
      cx, cy = a.center(target)
      body = a.copy(target, hide_original: true, z: 20_018)

      {
        x: cx, y: cy,
        body: body,
        color: body.color.clone,
        lips: a.sprite(lips, z: 20_027),
        hearts: hearts.map { |bitmap| a.sprite(bitmap, z: 20_029) },
        ring: a.sprite(target_ring, z: 20_025),
        energy: Array.new(20) { a.sprite(energy, z: 20_031) },
        shards: Array.new(12) { a.sprite(sparkle, z: 20_030) }
      }
    end
  end
) do |a, _t|
  sec = a.seconds
  ux = a[:ux]
  uy = a[:uy]

  a[:groups].each do |g|
    cx = g[:x]
    cy = g[:y]

    #=============================================================================
    # 1. NỤ HÔN BAY SANG — Đường cong nhẹ, nhịp chậm
    #=============================================================================
    q = (sec - 0.12) / 0.55
    p = a.clamp(q)
    arrival_fade = a.clamp((0.85 - sec) / 0.18)

    kiss = g[:lips]
    kiss.x = a.lerp(ux, cx, p)
    kiss.y = a.lerp(uy - 5, cy, p) -
             Math.sin(p * Math::PI) * 24
    kiss.angle = Math.sin(p * Math::PI) * 12
    kiss.zoom_x = 0.35 + p * 0.43
    kiss.zoom_y = kiss.zoom_x
    kiss.opacity = (
      a.clamp((sec - 0.08) / 0.12) * arrival_fade * 245
    ).to_i

    #=============================================================================
    # 2. TRÁI TIM HIỆN RA RỒI RẠN VỠ
    #=============================================================================
    appear = a.clamp((sec - 0.65) / 0.12)
    split = a.clamp((sec - 0.80) / 0.38)
    fade = a.clamp((1.26 - sec) / 0.30)

    g[:hearts].each_with_index do |heart, i|
      side = i == 0 ? -1 : 1
      heart.x = cx + side * split * 18
      heart.y = cy - 4 + split * split * 22
      heart.angle = side * split * 22
      heart.zoom_x = 0.58 + appear * 0.22
      heart.zoom_y = heart.zoom_x
      heart.opacity = (appear * fade * 250).to_i
    end

    q = (sec - 0.69) / 0.40
    p = a.clamp(q)
    ring = g[:ring]
    ring.x = cx
    ring.y = cy
    ring.zoom_x = 0.30 + p * 0.68
    ring.zoom_y = ring.zoom_x * 0.82
    ring.opacity = q.between?(0.0, 1.0) ?
      ((1.0 - p) * 180).to_i : 0

    gloom = a.clamp((sec - 0.66) / 0.10) *
            a.clamp((1.29 - sec) / 0.37)
    g[:body].color = gloom > 0 ?
      Color.new(65, 25, 84, (gloom * 120).to_i) : g[:color]

    # Các tia nhỏ tan khỏi trái tim, không tạo vụ nổ lớn.
    g[:shards].each_with_index do |spark, i|
      q = (sec - 0.83 - i % 3 * 0.025) / 0.43
      p = a.clamp(q)
      theta = i * 2.399

      spark.x = cx + Math.cos(theta) * (12 + p * 23)
      spark.y = cy + Math.sin(theta) * (10 + p * 18) + p * p * 17
      spark.angle = i * 31 + p * 60
      spark.zoom_x = 0.17 + i % 3 * 0.07
      spark.zoom_y = spark.zoom_x
      spark.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 190).to_i : 0
    end

    #=============================================================================
    # 3. HÚT NĂNG LƯỢNG — Bay từ mục tiêu về người dùng
    #=============================================================================
    g[:energy].each_with_index do |orb, i|
      q = (sec - 0.88 - i * 0.022) / 0.60
      p = a.clamp(q)
      phase = i * 2.399

      start_x = cx + Math.cos(phase) * 20
      start_y = cy + Math.sin(phase) * 24
      curve = Math.sin(p * Math::PI)

      orb.x = a.lerp(start_x, ux, p) +
              curve * Math.sin(phase) * 14
      orb.y = a.lerp(start_y, uy, p) -
              curve * (23 + i % 4 * 6)
      orb.zoom_x = 0.38 + i % 3 * 0.12
      orb.zoom_y = orb.zoom_x
      orb.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 245).to_i : 0
    end
  end

  #=============================================================================
  # 4. NĂNG LƯỢNG HÒA VÀO NGƯỜI DÙNG
  #=============================================================================
  a[:heal_rings].each_with_index do |ring, i|
    q = (sec - 1.39 - i * 0.15) / 0.55
    p = a.clamp(q)

    ring.x = ux
    ring.y = a[:ground] - 3 - p * 25
    ring.zoom_x = 0.65 + Math.sin(p * Math::PI) * 0.22
    ring.zoom_y = ring.zoom_x * 0.30
    ring.opacity = q.between?(0.0, 1.0) ?
      (Math.sin(p * Math::PI) * 195).to_i : 0
  end

  a[:heal_sparks].each_with_index do |spark, i|
    q = (sec - 1.42 - i % 6 * 0.035) / 0.57
    p = a.clamp(q)
    theta = i * 2.399

    spark.x = ux + Math.cos(theta) * (15 + i % 3 * 8) +
              Math.sin(p * 3 + i) * 3
    spark.y = uy + 24 - p * (40 + i % 4 * 10)
    spark.angle = i * 23 + p * 45
    spark.zoom_x = 0.20 + i % 3 * 0.10
    spark.zoom_y = spark.zoom_x
    spark.opacity = q.between?(0.0, 1.0) ?
      (Math.sin(p * Math::PI) * 220).to_i : 0
  end
end