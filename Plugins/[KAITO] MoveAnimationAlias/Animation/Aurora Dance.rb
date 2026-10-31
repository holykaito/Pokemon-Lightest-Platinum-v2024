#===============================================================================
# AURORA DANCE — Vũ điệu cực quang
# Yêu cầu: 000_AnimationCore.rb
#===============================================================================

KaitoAnimation.register(
  :AURORADANCE,
  duration: 2.60,
  require_target: false,
  setup: proc do |a|
    a.sound_at(0.03, ["PRSFX- Aurora Veil1"], 50, 105)
    a.sound_at(0.37, ["PRSFX- Quiver Dance"], 60, 110)
    a.sound_at(1.37, ["PRSFX- Cosmic Power"], 60, 115)
    a.sound_at(1.92, ["PRSFX- Aurora Veil2"], 55, 120)

    original = a.battler_sprite
    cx, cy = a.center
    floor = original.y +
            (original.src_rect.height - original.oy) * original.zoom_y

    a[:cx] = cx
    a[:cy] = cy
    a[:floor] = floor

    body = a.copy(a.user, hide_original: true, z: 20_020)
    a[:body] = body
    a[:base_x] = body.x
    a[:base_y] = body.y
    a[:base_angle] = body.angle
    a[:base_color] = body.color.clone

    #---------------------------------------------------------------------------
    # Nền đêm xanh tím dịu
    #---------------------------------------------------------------------------
    veil = a.bitmap(Graphics.width, Graphics.height) do |b|
      b.fill_rect(
        0, 0, b.width, b.height,
        Color.new(19, 28, 61)
      )
    end
    a[:veil] = a.sprite(veil, z: 20_000, centered: false)

    #---------------------------------------------------------------------------
    # Màn cực quang: dải màu mềm, các tia sáng chạy dọc
    #---------------------------------------------------------------------------
    curtain = a.bitmap(192, 152) do |b|
      192.times do |x|
        u = x / 191.0

        if u < 0.5
          p = u * 2
          red = 114 + p * 20
          green = 246 - p * 35
          blue = 205 + p * 47
        else
          p = (u - 0.5) * 2
          red = 134 + p * 90
          green = 211 - p * 49
          blue = 252
        end

        top = 14 + Math.sin(x * 0.047) * 10
        bottom = 121 + Math.sin(x * 0.031 + 1.2) * 20
        side_fade = Math.sin(u * Math::PI)**0.65
        strand = 0.65 + Math.sin(x * 0.36)**2 * 0.35

        152.times do |y|
          v = (y - top) / (bottom - top)
          next unless v.between?(0.0, 1.0)

          vertical = Math.sin(v * Math::PI)**0.75
          alpha = (vertical * side_fade * strand * 125).to_i
          b.set_pixel(
            x, y,
            Color.new(red.to_i, green.to_i, blue.to_i, alpha)
          )
        end
      end
    end

    a[:curtains] = Array.new(3) do |i|
      a.sprite(curtain, z: i == 1 ? 20_024 : 20_014)
    end

    #---------------------------------------------------------------------------
    # Vòng cực quang dưới chân
    #---------------------------------------------------------------------------
    rainbow_ring = a.bitmap(140, 140) do |b|
      140.times do |y|
        140.times do |x|
          dx = x - 69.5
          dy = y - 69.5
          radius = Math.sqrt(dx * dx + dy * dy)
          next unless radius.between?(61, 66)

          angle = Math.atan2(dy, dx)
          red = 164 + Math.sin(angle) * 54
          green = 211 + Math.sin(angle + 2.1) * 36
          blue = 235 + Math.sin(angle + 4.2) * 20
          edge = [radius - 61, 66 - radius].min / 2.5

          b.set_pixel(
            x, y,
            Color.new(
              red.to_i, green.to_i, blue.to_i,
              (edge * 225).to_i
            )
          )
        end
      end
    end

    a[:rings] = Array.new(2) do
      a.sprite(rainbow_ring, z: 20_012)
    end

    #---------------------------------------------------------------------------
    # Năm tinh thể tượng trưng cho năm chỉ số
    #---------------------------------------------------------------------------
    colors = [
      Color.new(153, 249, 214),
      Color.new(145, 222, 255),
      Color.new(184, 183, 255),
      Color.new(244, 186, 235),
      Color.new(255, 234, 177)
    ]

    a[:crystals] = colors.map do |color|
      bitmap = a.bitmap(28, 42) do |b|
        a.polygon(
          b,
          [[14, 0], [27, 16], [23, 30], [14, 41],
           [4, 30], [1, 16]],
          color
        )
        a.polygon(
          b,
          [[14, 3], [14, 37], [6, 28], [4, 17]],
          Color.new(244, 255, 255, 225)
        )
        a.polygon(
          b,
          [[14, 3], [23, 17], [14, 21]],
          Color.new(255, 255, 255, 245)
        )
      end
      a.sprite(bitmap, z: 20_027)
    end

    #---------------------------------------------------------------------------
    # Hạt sáng băng
    #---------------------------------------------------------------------------
    sparkle = a.bitmap(20, 20) do |b|
      a.polygon(
        b,
        [[10, 0], [12, 7], [20, 10], [12, 12],
         [10, 20], [7, 12], [0, 10], [7, 7]],
        Color.new(225, 254, 255, 245)
      )
      b.fill_rect(8, 8, 4, 4, Color.new(255, 255, 255, 255))
    end
    a[:sparks] = Array.new(34) { a.sprite(sparkle, z: 20_030) }

    burst = a.ring(60, Color.new(214, 249, 255, 245), 3)
    a[:burst] = a.sprite(burst, z: 20_032)
  end
) do |a, _t|
  sec = a.seconds
  cx = a[:cx]
  cy = a[:cy]
  floor = a[:floor]

  appear = a.clamp(sec / 0.38)
  fade = a.clamp((2.60 - sec) / 0.48)

  a[:veil].opacity = (appear * fade * 65).to_i

  #=============================================================================
  # 1. MỞ CỰC QUANG
  #=============================================================================
  a[:curtains].each_with_index do |curtain, i|
    phase = sec * 1.8 + i * Math::PI * 2 / 3
    depth = Math.sin(phase)

    curtain.x = cx + Math.cos(phase) * 22
    curtain.y = cy - 17 + depth * 9
    curtain.z = depth > 0 ? 20_024 : 20_014
    curtain.angle = Math.sin(phase * 0.8) * 9
    curtain.zoom_x = 0.78 + i * 0.12 + Math.sin(phase) * 0.06
    curtain.zoom_y = 0.68 + appear * 0.27
    curtain.mirror = i == 1
    curtain.opacity = (appear * fade * (i == 1 ? 150 : 205)).to_i
  end

  a[:rings].each_with_index do |ring, i|
    p = a.clamp((sec - i * 0.13) / 0.50)

    ring.x = cx
    ring.y = floor - 2
    ring.zoom_x = 0.25 + p * (i == 0 ? 0.82 : 1.05)
    ring.zoom_y = ring.zoom_x * 0.27
    ring.opacity = (p * fade * (i == 0 ? 220 : 115)).to_i
  end

  #=============================================================================
  # 2. VŨ ĐIỆU — Đung đưa và nhún nhẹ, giữ nguyên tỷ lệ Pokémon
  #=============================================================================
  dance = a.clamp((sec - 0.25) / 0.28) *
          a.clamp((1.98 - sec) / 0.38)

  body = a[:body]
  body.x = a[:base_x] + Math.sin((sec - 0.25) * 6.0) * dance * 6
  body.y = a[:base_y] -
           Math.sin((sec - 0.25) * 6.0).abs * dance * 4
  body.angle = a[:base_angle] +
               Math.sin((sec - 0.25) * 6.0) * dance * 4

  #=============================================================================
  # 3. NĂM TINH THỂ XOAY QUANH RỒI HỘI TỤ
  #=============================================================================
  crystal_in = a.clamp((sec - 0.38) / 0.25)
  gather = a.clamp((sec - 1.32) / 0.50)
  gather = gather * gather * (3.0 - 2.0 * gather)
  crystal_out = a.clamp((1.98 - sec) / 0.18)

  a[:crystals].each_with_index do |crystal, i|
    theta = i * Math::PI * 2 / 5 - sec * 1.65
    radius = (44 + Math.sin(sec * 2.5 + i) * 4) * (1.0 - gather)

    crystal.x = cx + Math.cos(theta) * radius
    crystal.y = cy + Math.sin(theta) * radius * 0.62 - gather * 8
    crystal.z = Math.sin(theta) > 0 ? 20_027 : 20_016
    crystal.angle = Math.sin(theta) * 12
    crystal.zoom_x = (0.46 + crystal_in * 0.15) * (1.0 - gather * 0.50)
    crystal.zoom_y = crystal.zoom_x
    crystal.opacity = (crystal_in * crystal_out * 245).to_i
  end

  # Một nhịp lóe dịu khi năm tinh thể hòa vào cơ thể.
  flash = a.clamp((sec - 1.75) / 0.10) *
          a.clamp((2.13 - sec) / 0.28)

  body.color = flash > 0 ?
    Color.new(225, 250, 255, (flash * 150).to_i) : a[:base_color]

  q = (sec - 1.82) / 0.52
  p = a.clamp(q)
  burst = a[:burst]
  burst.x = cx
  burst.y = cy
  burst.zoom_x = 0.22 + p * 1.35
  burst.zoom_y = burst.zoom_x * 0.85
  burst.opacity = q.between?(0.0, 1.0) ?
    ((1.0 - p) * 210).to_i : 0

  #=============================================================================
  # 4. ÁNH BĂNG NÂNG LÊN RỒI TAN
  #=============================================================================
  a[:sparks].each_with_index do |spark, i|
    start = i < 18 ?
      0.35 + i % 6 * 0.07 :
      1.80 + i % 5 * 0.035
    duration = i < 18 ? 1.10 : 0.60
    q = (sec - start) / duration
    p = a.clamp(q)
    theta = i * 2.399 + p * 1.4

    radius = i < 18 ? 35 + i % 4 * 9 : 12 + p * 48
    spark.x = cx + Math.cos(theta) * radius
    spark.y = cy + 25 + Math.sin(theta) * 15 -
              p * (57 + i % 4 * 10)
    spark.angle = i * 23 + p * 65
    spark.zoom_x = 0.19 + i % 3 * 0.11
    spark.zoom_y = spark.zoom_x
    spark.opacity = q.between?(0.0, 1.0) ?
      (Math.sin(p * Math::PI) * 235).to_i : 0
  end
end