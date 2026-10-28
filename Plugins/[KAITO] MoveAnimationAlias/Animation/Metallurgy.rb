#===============================================================================
# METALLURGY — Tái rèn cơ thể
# Yêu cầu: 000_AnimationCore.rb
#===============================================================================

KaitoAnimation.register(
  :METALLURGY,
  duration: 2.60,
  require_target: false,
  setup: proc do |a|
    a.sound_at(0.04, ["PRSFX- Metal Sound"], 45, 115)
    a.sound_at(0.65, ["PRSFX- Recover"], 60, 95)
    a.sound_at(1.48, ["PRSFX- Iron Defense"], 75, 105)
    a.sound_at(2.05, ["PRSFX- Harden"], 50, 120)

    original = a.battler_sprite
    cx, cy = a.center
    ground = original.y +
             (original.src_rect.height - original.oy) * original.zoom_y

    # Kích thước hiệu ứng thích ứng với sprite Pokémon.
    width = original.src_rect.width * original.zoom_x.abs
    height = original.src_rect.height * original.zoom_y.abs
    a[:rx] = [[width * 0.45, 32].max, 76].min
    a[:ry] = [[height * 0.42, 32].max, 78].min
    a[:cx] = cx
    a[:cy] = cy
    a[:ground] = ground

    a[:body] = a.copy(a.user, hide_original: true, z: 20_015)
    a[:body_color] = a[:body].color.clone

    #---------------------------------------------------------------------------
    # Mảnh kim loại bạc, có mặt sáng và mặt tối
    #---------------------------------------------------------------------------
    metal = a.bitmap(24, 30) do |b|
      a.polygon(
        b,
        [[3, 6], [16, 1], [23, 10], [19, 25],
         [7, 29], [1, 18]],
        Color.new(98, 130, 151, 255)
      )
      a.polygon(
        b,
        [[3, 6], [16, 1], [16, 14], [7, 29], [1, 18]],
        Color.new(201, 222, 232, 255)
      )
      a.polygon(
        b,
        [[3, 6], [16, 1], [20, 6], [8, 11]],
        Color.new(247, 255, 255, 255)
      )
    end

    a[:metals] = Array.new(16) { a.sprite(metal, z: 20_025) }

    #---------------------------------------------------------------------------
    # Dòng kim loại nóng chảy
    #---------------------------------------------------------------------------
    molten = a.bitmap(20, 70) do |b|
      a.polygon(
        b,
        [[8, 0], [15, 8], [13, 25], [19, 42],
         [14, 60], [7, 70], [3, 57], [6, 40],
         [1, 23], [5, 12]],
        Color.new(255, 133, 40, 210)
      )
      a.polygon(
        b,
        [[9, 5], [12, 17], [9, 29], [14, 44],
         [10, 61], [7, 54], [9, 40], [5, 24]],
        Color.new(255, 232, 139, 255)
      )
    end

    a[:streams] = Array.new(8) { a.sprite(molten, z: 20_022) }

    #---------------------------------------------------------------------------
    # Vết nứt sáng: khép dần trong pha hồi phục
    #---------------------------------------------------------------------------
    crack = a.bitmap(34, 62) do |b|
      a.polygon(
        b,
        [[16, 0], [22, 0], [17, 17], [29, 27],
         [19, 41], [23, 51], [12, 62], [16, 48],
         [12, 40], [22, 27], [11, 18]],
        Color.new(255, 151, 58, 245)
      )
      a.polygon(
        b,
        [[18, 2], [20, 2], [15, 18], [26, 27],
         [16, 40], [20, 50], [15, 57], [18, 49],
         [14, 40], [24, 27], [13, 18]],
        Color.new(255, 249, 190, 255)
      )
    end

    a[:cracks] = Array.new(4) { a.sprite(crack, z: 20_024) }

    #---------------------------------------------------------------------------
    # Tấm giáp bạc xanh
    #---------------------------------------------------------------------------
    plate = a.bitmap(44, 52) do |b|
      a.polygon(
        b,
        [[5, 8], [23, 1], [40, 8], [43, 31],
         [22, 51], [1, 31]],
        Color.new(226, 250, 255, 250)
      )
      a.polygon(
        b,
        [[8, 11], [23, 5], [36, 11], [38, 29],
         [22, 44], [6, 29]],
        Color.new(115, 164, 188, 235)
      )
      a.polygon(
        b,
        [[8, 11], [23, 5], [22, 44], [6, 29]],
        Color.new(183, 219, 232, 240)
      )
      a.polygon(
        b,
        [[11, 13], [23, 8], [32, 12], [20, 16]],
        Color.new(248, 255, 255, 255)
      )
    end

    a[:plates] = Array.new(6) { a.sprite(plate, z: 20_027) }

    #---------------------------------------------------------------------------
    # Khiên hoàn chỉnh lóe lên sau khi các tấm giáp ghép lại
    #---------------------------------------------------------------------------
    shield = a.bitmap(112, 132) do |b|
      a.polygon(
        b,
        [[8, 20], [56, 2], [104, 20], [101, 75],
         [85, 102], [56, 130], [27, 102], [11, 75]],
        Color.new(220, 250, 255, 245)
      )
      a.polygon(
        b,
        [[16, 26], [56, 11], [96, 26], [93, 73],
         [78, 97], [56, 119], [34, 97], [19, 73]],
        Color.new(99, 155, 184, 155)
      )
      a.polygon(
        b,
        [[56, 14], [57, 115], [35, 94], [22, 71],
         [19, 28]],
        Color.new(202, 238, 246, 160)
      )
      a.polygon(
        b,
        [[52, 24], [60, 24], [60, 91], [56, 104],
         [52, 91]],
        Color.new(239, 255, 255, 235)
      )
      b.fill_rect(33, 49, 46, 6, Color.new(239, 255, 255, 235))
    end

    a[:shield] = a.sprite(shield, z: 20_032)

    #---------------------------------------------------------------------------
    # Hạt hồi phục vàng và tia lấp lánh bạc
    #---------------------------------------------------------------------------
    sparkles = [
      Color.new(255, 224, 130, 255),
      Color.new(211, 249, 255, 255)
    ].map do |color|
      a.bitmap(20, 20) do |b|
        a.polygon(
          b,
          [[10, 0], [12, 7], [20, 10], [12, 12],
           [10, 20], [7, 12], [0, 10], [7, 7]],
          color
        )
        b.fill_rect(8, 8, 4, 4, Color.new(255, 255, 239, 255))
      end
    end

    a[:gold] = Array.new(20) { a.sprite(sparkles[0], z: 20_030) }
    a[:silver] = Array.new(16) { a.sprite(sparkles[1], z: 20_035) }

    steel_ring = a.ring(66, Color.new(202, 248, 255, 240), 3)
    a[:sweep] = a.sprite(steel_ring, z: 20_033)
  end
) do |a, _t|
  sec = a.seconds
  cx = a[:cx]
  cy = a[:cy]
  rx = a[:rx]
  ry = a[:ry]

  #=============================================================================
  # 1. TỤ KIM LOẠI — Các mảnh bạc xoay thành vòng
  #=============================================================================
  gather = a.clamp(sec / 0.38)
  melt = a.clamp((sec - 0.58) / 0.38)

  a[:metals].each_with_index do |metal, i|
    theta = i * Math::PI * 2 / 16.0 + sec * 1.75
    radius = (1.35 - gather * 0.35) * (1.0 - melt * 0.80)
    depth = Math.sin(theta)

    metal.x = cx + Math.cos(theta) * (rx + 20) * radius
    metal.y = cy + depth * ry * 0.48 - melt * 5
    metal.z = depth > 0 ? 20_025 : 20_013
    metal.angle = i * 37 + sec * 65
    metal.zoom_x = (0.32 + i % 4 * 0.08) * (1.0 - melt * 0.65)
    metal.zoom_y = metal.zoom_x
    metal.color = Color.new(255, 169, 54, (melt * 230).to_i)
    metal.opacity = (gather * (1.0 - melt) * 250).to_i
  end

  #=============================================================================
  # 2. TÁI RÈN — Dòng cam vàng chảy xuống, vết nứt khép lại
  #=============================================================================
  heat = a.clamp((sec - 0.57) / 0.25)
  cool = a.clamp((sec - 1.28) / 0.42)

  a[:streams].each_with_index do |stream, i|
    q = (sec - 0.60 - i * 0.045) / 0.69
    p = a.clamp(q)
    lane = (i % 4 - 1.5) / 1.5

    stream.x = cx + lane * rx * 0.62 + Math.sin(p * 4 + i) * 3
    stream.y = cy - ry * 0.65 + p * ry * 1.35
    stream.angle = lane * 8
    stream.zoom_x = 0.32 + i % 3 * 0.09
    stream.zoom_y = 0.40 + Math.sin(p * Math::PI) * 0.30
    stream.opacity = q.between?(0.0, 1.0) ?
      (Math.sin(p * Math::PI) * 235).to_i : 0
  end

  a[:cracks].each_with_index do |crack, i|
    appear = a.clamp((sec - 0.65 - i * 0.04) / 0.12)
    close = a.clamp((sec - 0.96 - i * 0.055) / 0.34)

    crack.x = cx + [-0.42, 0.35, -0.12, 0.45][i] * rx
    crack.y = cy + [-0.30, -0.12, 0.32, 0.42][i] * ry
    crack.angle = [-15, 22, 10, -24][i]
    crack.zoom_x = (0.42 + i % 2 * 0.10) * (1.0 - close)
    crack.zoom_y = 0.48 + i % 2 * 0.12
    crack.opacity = (appear * (1.0 - close) * 245).to_i
  end

  a[:gold].each_with_index do |spark, i|
    q = (sec - 0.81 - i % 7 * 0.06) / 0.78
    p = a.clamp(q)

    spark.x = cx + Math.sin(i * 2.4) * rx * 0.72 +
              Math.sin(p * 3 + i) * 5
    spark.y = cy + ry * 0.60 - p * (ry + 28 + i % 3 * 9)
    spark.angle = i * 27 + p * 50
    spark.zoom_x = 0.22 + i % 3 * 0.12
    spark.zoom_y = spark.zoom_x
    spark.opacity = q.between?(0.0, 1.0) ?
      (Math.sin(p * Math::PI) * 245).to_i : 0
  end

  # Màu cơ thể chuyển từ nóng sang bạc xanh.
  finish = a.clamp((2.48 - sec) / 0.36)
  body = a[:body]

  if heat > 0 && cool < 1
    body.color = Color.new(
      a.lerp(255, 167, cool).to_i,
      a.lerp(163, 222, cool).to_i,
      a.lerp(57, 242, cool).to_i,
      (heat * (70 + cool * 25) * finish).to_i
    )
  elsif cool >= 1 && finish > 0
    body.color = Color.new(167, 222, 242, (finish * 95).to_i)
  else
    body.color = a[:body_color]
  end

  #=============================================================================
  # 3. ĐÓNG GIÁP — Các tấm ghép nhanh vào quanh thân
  #=============================================================================
  absorb = a.clamp((sec - 2.02) / 0.30)

  a[:plates].each_with_index do |plate, i|
    q = a.clamp((sec - 1.36 - i * 0.045) / 0.20)
    form = q * q * (3.0 - 2.0 * q)
    theta = i * Math::PI * 2 / 6.0 - Math::PI / 2
    distance = (1.90 - form * 1.15) * (1.0 - absorb * 0.75)

    plate.x = cx + Math.cos(theta) * rx * distance
    plate.y = cy + Math.sin(theta) * ry * distance * 0.76
    plate.angle = (1.0 - form) * (i.even? ? 35 : -35)
    plate.zoom_x = (0.45 + form * 0.15) * (1.0 - absorb * 0.45)
    plate.zoom_y = plate.zoom_x
    plate.opacity = (form * (1.0 - absorb) * 215).to_i
  end

  shield = a[:shield]
  shield_in = a.clamp((sec - 1.66) / 0.12)
  shield_out = a.clamp((2.16 - sec) / 0.28)
  gleam = [1.0 - (sec - 1.83).abs / 0.11, 0].max

  shield.x = cx
  shield.y = cy
  shield.zoom_x = 0.72 + shield_in * 0.12 - absorb * 0.12
  shield.zoom_y = shield.zoom_x
  shield.color = Color.new(245, 255, 255, (gleam * 205).to_i)
  shield.opacity = (shield_in * shield_out * 205).to_i

  #=============================================================================
  # 4. HOÀN TẤT — Vòng thép quét từ chân lên, giáp chìm vào cơ thể
  #=============================================================================
  q = (sec - 1.98) / 0.46
  p = a.clamp(q)

  sweep = a[:sweep]
  sweep.x = cx
  sweep.y = a.lerp(a[:ground] - 3, cy - ry - 10, p)
  sweep.zoom_x = (rx + 14) / 66.0 *
                 (0.80 + Math.sin(p * Math::PI) * 0.20)
  sweep.zoom_y = sweep.zoom_x * 0.24
  sweep.opacity = q.between?(0.0, 1.0) ?
    (Math.sin(p * Math::PI) * 245).to_i : 0

  a[:silver].each_with_index do |spark, i|
    q = (sec - 2.02 - i % 5 * 0.025) / 0.45
    p = a.clamp(q)
    theta = i * 2.399

    spark.x = cx + Math.cos(theta) * (rx * 0.55 + p * 20)
    spark.y = cy + Math.sin(theta) * ry * 0.70 - p * 18
    spark.angle = i * 31 + p * 60
    spark.zoom_x = 0.20 + Math.sin(p * Math::PI) * 0.22
    spark.zoom_y = spark.zoom_x
    spark.opacity = q.between?(0.0, 1.0) ?
      (Math.sin(p * Math::PI) * 245).to_i : 0
  end
end