#===============================================================================
# MOONLIGHT PRANCE — Vũ điệu triệu hồi nguyệt quang
# Yêu cầu: 000_AnimationCore.rb
# hit 0: Đòn đặc biệt
# hit 1: Lấy chỉ số tăng
#===============================================================================

KaitoAnimation.register(
  :MOONLIGHTPRANCE,
  hit: 0,
  duration: 2.50,
  setup: proc do |a|
    a.sound_at(0.03, ["PRSFX- Moonlight"], 45, 105)
    a.sound_at(0.50, ["PRSFX- Heal Bell"], 35, 125)
    a.sound_at(0.91, ["PRSFX- Heal Bell"], 38, 135)
    a.sound_at(1.20, ["PRSFX- Moonblast1"], 60, 115)
    a.sound_at(1.83, ["PRSFX- Moonblast2"], 75, 120)

    cx, cy = a.center
    original = a.battler_sprite
    floor = original.y +
            (original.src_rect.height - original.oy) * original.zoom_y

    a[:cx] = cx
    a[:cy] = cy
    a[:floor] = floor

    body = a.copy(a.user, hide_original: true, z: 20_020)
    a[:body] = body
    a[:base_y] = body.y
    a[:base_color] = body.color.clone

    #---------------------------------------------------------------------------
    # Nền xanh tím
    #---------------------------------------------------------------------------
    veil = a.bitmap(Graphics.width, Graphics.height) do |b|
      b.fill_rect(
        0, 0, b.width, b.height,
        Color.new(23, 25, 58)
      )
    end
    a[:veil] = a.sprite(veil, z: 20_000, centered: false)

    #---------------------------------------------------------------------------
    # Trăng khuyết
    #---------------------------------------------------------------------------
    moon = a.bitmap(88, 88) do |b|
      88.times do |y|
        88.times do |x|
          outer = Math.sqrt((x - 43.5)**2 + (y - 43.5)**2)
          cut = Math.sqrt((x - 58.5)**2 + (y - 36.5)**2)
          next if outer > 37 || cut < 33

          color = outer > 33 || cut < 36 ?
            Color.new(161, 176, 235, 240) :
            Color.new(238, 248, 255, 255)
          b.set_pixel(x, y, color)
        end
      end
    end

    #---------------------------------------------------------------------------
    # Quầng sáng mềm
    #---------------------------------------------------------------------------
    glow = a.bitmap(112, 112) do |b|
      112.times do |y|
        112.times do |x|
          r = Math.sqrt((x - 55.5)**2 + (y - 55.5)**2) / 55.0
          next if r > 1.0
          b.set_pixel(
            x, y,
            Color.new(167, 185, 247, ((1.0 - r)**2 * 170).to_i)
          )
        end
      end
    end

    ring = a.ring(61, Color.new(207, 226, 255, 235), 3)
    fine_ring = a.ring(48, Color.new(176, 159, 235, 225), 2)

    #---------------------------------------------------------------------------
    # Tia nguyệt quang: quầng ngoài rộng, lõi bạc mảnh
    #---------------------------------------------------------------------------
    beam = a.bitmap(40, 120) do |b|
      40.times do |x|
        distance = (x - 19.5).abs / 20.0
        alpha = ((1.0 - distance)**2 * 180).to_i
        b.fill_rect(
          x, 0, 1, 120,
          Color.new(174, 192, 248, alpha)
        )
      end
      b.fill_rect(17, 0, 6, 120, Color.new(221, 238, 255, 210))
      b.fill_rect(19, 0, 2, 120, Color.new(255, 255, 255, 245))
    end

    sparkle = a.bitmap(20, 20) do |b|
      a.polygon(
        b,
        [[10, 0], [13, 7], [20, 10], [13, 13],
         [10, 20], [7, 13], [0, 10], [7, 7]],
        Color.new(243, 239, 220, 245)
      )
      b.fill_rect(8, 8, 4, 4, Color.new(255, 255, 255, 255))
    end

    # Vòng phép và ba dấu trăng quanh người dùng.
    a[:user_ring] = a.sprite(ring, z: 20_012)
    a[:user_glow] = a.sprite(glow, z: 20_014)
    a[:dance_moons] = Array.new(3) do
      a.sprite(moon, z: 20_025)
    end
    a[:user_sparks] = Array.new(22) do
      a.sprite(sparkle, z: 20_028)
    end

    a[:groups] = a.targets.map do |target|
      tx, ty = a.center(target)
      target_copy = a.copy(target, hide_original: true, z: 20_019)

      {
        x: tx, y: ty,
        sky_y: [ty - 105, 53].max,
        body: target_copy,
        color: target_copy.color.clone,
        sigil: a.sprite(ring, z: 20_026),
        inner: a.sprite(fine_ring, z: 20_027),
        moon: a.sprite(moon, z: 20_028),
        sky_glow: a.sprite(glow, z: 20_025),
        beams: Array.new(3) do
          s = a.sprite(beam, z: 20_030, centered: false)
          s.ox = 20
          s
        end,
        flare: a.sprite(glow, z: 20_031),
        waves: Array.new(2) { a.sprite(ring, z: 20_033) },
        sparks: Array.new(32) { a.sprite(sparkle, z: 20_035) }
      }
    end
  end
) do |a, _t|
  sec = a.seconds
  cx = a[:cx]
  cy = a[:cy]
  floor = a[:floor]

  appear = a.clamp(sec / 0.28)
  fade = a.clamp((2.50 - sec) / 0.42)
  a[:veil].opacity = (appear * fade * 85).to_i

  #=============================================================================
  # 1. VŨ ĐIỆU NIỆM PHÉP — Nhún tại chỗ, không lao sang mục tiêu
  #=============================================================================
  lift = 0.0
  [
    [0.18, 0.32, 8],
    [0.56, 0.35, 11],
    [1.00, 0.55, 18]
  ].each do |start, duration, height|
    q = (sec - start) / duration
    next unless q.between?(0.0, 1.0)

    # Đỉnh nhảy mềm, giữ cảm giác lơ lửng.
    lift = Math.sin(q * Math::PI)**0.65 * height
  end

  a[:body].y = a[:base_y] - lift

  user_ring = a[:user_ring]
  user_ring.x = cx
  user_ring.y = floor
  user_ring.zoom_x = 0.30 + appear * 0.72
  user_ring.zoom_y = user_ring.zoom_x * 0.27
  user_ring.opacity = (appear * fade * 215).to_i

  user_glow = a[:user_glow]
  user_glow.x = cx
  user_glow.y = cy - lift
  user_glow.zoom_x = 0.90
  user_glow.zoom_y = 1.10
  user_glow.opacity = (appear * fade * 150).to_i

  # Ba dấu trăng bay quanh cơ thể như các ký hiệu niệm phép.
  a[:dance_moons].each_with_index do |moon, i|
    theta = i * Math::PI * 2 / 3 + sec * 2.6
    depth = Math.sin(theta)

    moon.x = cx + Math.cos(theta) * 36
    moon.y = cy - lift + depth * 15
    moon.z = depth > 0 ? 20_025 : 20_016
    moon.angle = -25 + Math.sin(theta) * 18
    moon.zoom_x = 0.22
    moon.zoom_y = 0.22
    moon.opacity = (
      appear * a.clamp((1.82 - sec) / 0.35) * 225
    ).to_i
  end

  a[:user_sparks].each_with_index do |spark, i|
    q = (sec - 0.15 - i % 7 * 0.065) / 1.20
    p = a.clamp(q)
    theta = i * 2.399 + p * 3.8

    spark.x = cx + Math.cos(theta) * (25 + i % 3 * 8)
    spark.y = floor - 5 - p * (85 + i % 4 * 10)
    spark.angle = i * 23 + p * 65
    spark.zoom_x = 0.16 + i % 3 * 0.10
    spark.zoom_y = spark.zoom_x
    spark.opacity = q.between?(0.0, 1.0) ?
      (Math.sin(p * Math::PI) * 210).to_i : 0
  end

  cast_glow = a.clamp((sec - 1.22) / 0.22) *
              a.clamp((1.88 - sec) / 0.30)
  a[:body].color = cast_glow > 0 ?
    Color.new(206, 221, 255, (cast_glow * 85).to_i) : a[:base_color]

  a[:groups].each do |g|
    tx = g[:x]
    ty = g[:y]
    sky_y = g[:sky_y]

    #===========================================================================
    # 2. NGUYỆT ẤN HIỆN TRÊN MỤC TIÊU
    #===========================================================================
    form = a.clamp((sec - 0.65) / 0.42)
    seal_fade = a.clamp((2.12 - sec) / 0.32)

    sigil = g[:sigil]
    sigil.x = tx
    sigil.y = sky_y
    sigil.zoom_x = 0.25 + form * 0.62
    sigil.zoom_y = sigil.zoom_x * 0.48
    sigil.opacity = (form * seal_fade * 235).to_i

    inner = g[:inner]
    inner.x = tx
    inner.y = sky_y
    inner.zoom_x = 0.20 + form * 0.64
    inner.zoom_y = inner.zoom_x * 0.48
    inner.opacity = (form * seal_fade * 210).to_i

    moon = g[:moon]
    moon.x = tx
    moon.y = sky_y - 3
    moon.angle = -22
    moon.zoom_x = 0.40 + form * 0.15
    moon.zoom_y = moon.zoom_x
    moon.opacity = (form * seal_fade * 245).to_i

    glow = g[:sky_glow]
    glow.x = tx
    glow.y = sky_y
    glow.zoom_x = 0.55 + form * 0.65
    glow.zoom_y = 0.65
    glow.opacity = (form * seal_fade * 220).to_i

    #===========================================================================
    # 3. GIÁNG NGUYỆT QUANG — Ba tia phép hội tụ từ trên cao
    #===========================================================================
    g[:beams].each_with_index do |beam, i|
      start = 1.49 + i * 0.045
      reach = a.clamp((sec - start) / 0.28)
      beam_fade = a.clamp((2.12 - sec) / 0.22)
      sx = tx + (i - 1) * 25
      dx = tx - sx
      dy = ty - sky_y
      distance = Math.sqrt(dx * dx + dy * dy)

      beam.x = sx
      beam.y = sky_y
      beam.angle = 90 - Math.atan2(dy, dx) * 180 / Math::PI
      beam.zoom_x = i == 1 ? 1.05 : 0.65
      beam.zoom_y = distance / 120.0 * reach
      beam.opacity = (reach * beam_fade * 245).to_i
    end

    # Ánh sáng nở rộng tại mục tiêu, không dùng lưỡi chém.
    bloom = a.clamp((sec - 1.80) / 0.12)
    bloom_fade = a.clamp((2.35 - sec) / 0.37)

    flare = g[:flare]
    flare.x = tx
    flare.y = ty
    flare.zoom_x = 0.25 + bloom * 1.45
    flare.zoom_y = 0.40 + bloom * 1.65
    flare.opacity = (bloom * bloom_fade * 255).to_i

    pulse = a.clamp((sec - 1.83) / 0.05) *
            a.clamp((2.08 - sec) / 0.20)
    g[:body].color = pulse > 0 ?
      Color.new(231, 240, 255, (pulse * 205).to_i) : g[:color]

    #===========================================================================
    # 4. DƯ QUANG — Vòng sáng và bụi sao tan nhẹ
    #===========================================================================
    g[:waves].each_with_index do |ring, i|
      q = (sec - 1.86 - i * 0.07) / 0.45
      p = a.clamp(q)

      ring.x = tx
      ring.y = ty
      ring.zoom_x = 0.20 + p * (i == 0 ? 1.35 : 1.10)
      ring.zoom_y = ring.zoom_x * (i == 0 ? 0.80 : 0.38)
      ring.opacity = q.between?(0.0, 1.0) ?
        ((1.0 - p) * 220).to_i : 0
    end

    g[:sparks].each_with_index do |spark, i|
      q = (sec - 1.89 - i % 6 * 0.025) / 0.46
      p = a.clamp(q)
      theta = i * 2.399
      distance = 15 + p * (28 + i % 5 * 10)

      spark.x = tx + Math.cos(theta) * distance
      spark.y = ty + Math.sin(theta) * distance * 0.75 + p * p * 20
      spark.angle = i * 29 + p * 45
      spark.zoom_x = 0.16 + i % 4 * 0.07
      spark.zoom_y = spark.zoom_x
      spark.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 235).to_i : 0
    end
  end
end

#===============================================================================
# Pha lấy chỉ số tăng — Engine gọi riêng trước đòn đánh.
#===============================================================================

KaitoAnimation.register(
  :MOONLIGHTPRANCE,
  hit: 1,
  duration: 0.45,
  setup: proc do |a|
    a.sound_at(0.02, ["PRSFX- Moonlight"], 35, 125)
    a[:destination] = a.center

    mote = a.bitmap(16, 16) do |b|
      a.polygon(
        b,
        [[8, 0], [11, 5], [16, 8], [11, 11],
         [8, 16], [5, 11], [0, 8], [5, 5]],
        Color.new(224, 221, 255, 245)
      )
    end

    a[:groups] = a.targets.map do |target|
      {
        origin: a.center(target),
        motes: Array.new(10) { a.sprite(mote, z: 20_028) }
      }
    end
  end
) do |a, _t|
  ux, uy = a[:destination]

  a[:groups].each do |g|
    tx, ty = g[:origin]

    g[:motes].each_with_index do |mote, i|
      q = (a.seconds - i * 0.012) / 0.32
      p = a.clamp(q)
      travel = p * p

      mote.x = a.lerp(tx, ux, travel) +
               Math.sin(p * Math::PI) * Math.sin(i * 2.4) * 12
      mote.y = a.lerp(ty, uy, travel) -
               Math.sin(p * Math::PI) * (17 + i % 3 * 7)
      mote.angle = p * 90
      mote.zoom_x = 0.30 + i % 3 * 0.12
      mote.zoom_y = mote.zoom_x
      mote.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 235).to_i : 0
    end
  end
end