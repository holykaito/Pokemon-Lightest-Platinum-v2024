#===============================================================================
# BUBBLE BLASTER — Bong bóng đỏ cam / Bọt nước tăng cường
# Yêu cầu: 000_AnimationCore.rb
# Thay toàn bộ registration :BUBBLEBLASTER cũ.
#===============================================================================

KaitoAnimation.register(
  :BUBBLEBLASTER,
  duration: 2.85,
  setup: proc do |a|
    a.sound_at(0.05, ["PRSFX- Bubble"], 55, 90)
    a.sound_at(0.61, ["PRSFX- Bubblebeam"], 80, 105)
    a.sound_at(1.10, ["PRSFX- Bubble"], 60, 120)
    a.sound_at(1.76, ["PRSFX- Hydro Cannon2"], 90, 105)

    #---------------------------------------------------------------------------
    # Bong bóng lớn, viền đỏ cam dày, lòng bán trong suốt
    #---------------------------------------------------------------------------
    # Bong bóng đỏ cam toàn phần, ruột đậm và viền dày.
    # Bong bóng cyan trong suốt, viền sáng và phản chiếu hồng tím nhẹ.
    bubble = a.bitmap(100, 100) do |b|
      100.times do |y|
        100.times do |x|
          dx = x - 49.5
          dy = y - 49.5
          r = Math.sqrt(dx * dx + dy * dy)
          next if r > 47

          color =
            if r > 44
              Color.new(227, 253, 255, 230)
            elsif r > 39
              Color.new(111, 218, 245, 170)
            elsif r > 34
              Color.new(146, 231, 250, 95)
            else
              # Ruột trong, hơi xanh hơn về phía đáy.
              depth = [[(dy + 34) / 68.0, 0.0].max, 1.0].min
              Color.new(109, 207, 239, (20 + depth * 25).to_i)
            end

          b.set_pixel(x, y, color)

          # Phản chiếu cong trên bề mặt.
          if r.between?(38, 43) && dx < -9 && dy < -11
            b.set_pixel(x, y, Color.new(247, 255, 255, 235))
          end

          # Ánh hồng tím nhẹ ở mép dưới phải.
          if r.between?(39, 43) && dx > 12 && dy > 8
            b.set_pixel(x, y, Color.new(216, 187, 248, 145))
          end
        end
      end

      a.polygon(
        b,
        [[22, 23], [31, 15], [40, 15], [32, 22], [26, 29]],
        Color.new(255, 255, 255, 225)
      )
      b.fill_rect(20, 31, 4, 7, Color.new(235, 253, 255, 165))
    end

    #---------------------------------------------------------------------------
    # Vệt nước phía sau
    #---------------------------------------------------------------------------
    trail = a.bitmap(82, 20) do |b|
      a.polygon(
        b,
        [[0, 10], [61, 1], [81, 10], [61, 19]],
        Color.new(110, 215, 245, 160)
      )
      a.polygon(
        b,
        [[13, 10], [64, 6], [81, 10], [64, 13]],
        Color.new(239, 255, 255, 235)
      )
    end

    #---------------------------------------------------------------------------
    # Giọt nước lớn, viền trắng để nổi rõ
    #---------------------------------------------------------------------------
    drop = a.bitmap(20, 30) do |b|
      a.polygon(
        b,
        [[10, 0], [17, 12], [19, 20], [15, 28],
         [7, 29], [1, 23], [1, 17]],
        Color.new(237, 255, 255, 250)
      )
      a.polygon(
        b,
        [[10, 6], [14, 15], [15, 21], [12, 25],
         [7, 25], [4, 21], [5, 16]],
        Color.new(87, 201, 239, 245)
      )
      b.fill_rect(7, 14, 3, 7, Color.new(224, 254, 255, 250))
    end

    #---------------------------------------------------------------------------
    # Bọt trắng dạng cụm, khác rõ với giọt nước
    #---------------------------------------------------------------------------
    foam = a.bitmap(30, 26) do |b|
      circles = [
        [9, 15, 8], [18, 15, 9], [14, 8, 7], [24, 18, 5]
      ]
      26.times do |y|
        30.times do |x|
          next unless circles.any? do |cx, cy, radius|
            (x - cx)**2 + (y - cy)**2 <= radius**2
          end
          b.set_pixel(x, y, Color.new(242, 255, 255, 245))
        end
      end
      b.fill_rect(8, 18, 13, 3, Color.new(151, 225, 246, 205))
    end

    water_ring = a.ring(38, Color.new(210, 251, 255, 250), 5)
    thin_ring = a.ring(38, Color.new(111, 221, 250, 240), 2)
    air_ring = a.ring(43, Color.new(250, 244, 227, 235), 3)

    ux, uy = a.center
    tx, ty = a.center(a.targets.first)
    dx = tx - ux
    dy = ty - uy
    distance = [Math.sqrt(dx * dx + dy * dy), 1.0].max

    a[:sx] = ux + dx / distance * 35
    a[:sy] = uy + dy / distance * 16
    a[:charge] = a.sprite(bubble, z: 20_025)
    a[:gather] = Array.new(18) { a.sprite(bubble, z: 20_026) }

    # Sáu quả thường, một quả lớn cuối.
    a[:shots] = [
      [0.62, 0.34, 0.55, -9],
      [0.71, 0.34, 0.43,  9],
      [0.79, 0.34, 0.63, -4],
      [0.86, 0.34, 0.46, 11],
      [0.92, 0.34, 0.58, -9],
      [0.97, 0.34, 0.44,  4],
      [1.10, 0.66, 1.08,  0]
    ]

    a[:groups] = a.targets.map do |target|
      cx, cy = a.center(target)
      body = a.copy(target, hide_original: true, z: 20_015)

      {
        x: cx, y: cy,
        body: body,
        base_x: body.x, base_y: body.y,
        color: body.color.clone,
        muzzle: a.sprite(air_ring, z: 20_028),
        shots: Array.new(7) do |i|
          final = i == 6
          {
            bubble: a.sprite(bubble, z: 20_030),
            trail: a.sprite(trail, z: 20_027),
            rings: [
              a.sprite(water_ring, z: 20_033),
              a.sprite(thin_ring, z: 20_034)
            ],
            drops: Array.new(final ? 54 : 18) do
              a.sprite(drop, z: 20_035)
            end,
            foam: Array.new(final ? 30 : 10) do
              a.sprite(foam, z: 20_036)
            end
          }
        end,
        tiny: Array.new(24) { a.sprite(bubble, z: 20_037) }
      }
    end
  end
) do |a, _t|
  sec = a.seconds
  sx = a[:sx]
  sy = a[:sy]

  #=============================================================================
  # NẠP ÁP SUẤT
  #=============================================================================
  form = a.clamp(sec / 0.36)
  compress = a.clamp((sec - 0.37) / 0.22)
  fade = a.clamp((0.70 - sec) / 0.09)
  pressure = 0.28 + form * 0.58 - compress * 0.19

  charge = a[:charge]
  charge.x = sx + Math.sin(sec * 95) * compress * 1.8
  charge.y = sy + Math.cos(sec * 78) * compress
  charge.zoom_x = pressure * (1.0 + Math.sin(sec * 19) * 0.05)
  charge.zoom_y = pressure * (1.0 - Math.sin(sec * 19) * 0.05)
  charge.opacity = (form * fade * 250).to_i

  a[:gather].each_with_index do |bubble, i|
    q = (sec - i % 6 * 0.035) / 0.40
    p = a.clamp(q)
    theta = i * 2.399
    radius = 51 + i % 4 * 10

    bubble.x = sx + Math.cos(theta) * radius * (1.0 - p)
    bubble.y = sy + Math.sin(theta) * radius * 0.65 * (1.0 - p)
    bubble.zoom_x = (0.11 + i % 3 * 0.045) * (1.0 - p * 0.55)
    bubble.zoom_y = bubble.zoom_x
    bubble.opacity = q.between?(0.0, 1.0) ?
      (Math.sin(p * Math::PI) * 235).to_i : 0
  end

  a[:groups].each do |g|
    cx = g[:x]
    cy = g[:y]
    dx = cx - sx
    dy = cy - sy
    distance = [Math.sqrt(dx * dx + dy * dy), 1.0].max
    nx = -dy / distance
    ny = dx / distance
    angle = -Math.atan2(dy, dx) * 180 / Math::PI

    #===========================================================================
    # VÒNG KHÍ KHAI HỎA
    #===========================================================================
    q = (sec - 0.61) / 0.28
    p = a.clamp(q)
    muzzle = g[:muzzle]
    muzzle.x = sx
    muzzle.y = sy
    muzzle.angle = angle
    muzzle.zoom_x = (0.35 + p * 0.75) * 0.40
    muzzle.zoom_y = 0.35 + p * 0.75
    muzzle.opacity = q.between?(0.0, 1.0) ?
      ((1.0 - p) * 235).to_i : 0

    flash = 0.0

    g[:shots].each_with_index do |shot, i|
      start, flight, size, offset = a[:shots][i]
      final = i == 6
      age = sec - start
      p = a.clamp(age / flight)
      arrival = start + flight

      side = offset * Math.sin(p * Math::PI)
      bx = a.lerp(sx, cx, p) + nx * side
      by = a.lerp(sy, cy, p) + ny * side

      contact = a.clamp((p - 0.88) / 0.12)
      release = a.clamp((sec - arrival) / 0.055)
      squash = [contact, 1.0 - release].min

      bubble = shot[:bubble]
      bubble.x = bx
      bubble.y = by
      bubble.angle = angle
      bubble.zoom_x = size * (1.0 - squash * 0.46)
      bubble.zoom_y = size * (1.0 + squash * 0.28)
      bubble.opacity = age >= 0 && sec < arrival + 0.055 ? 255 : 0

      tail = shot[:trail]
      tail.x = bx - dx / distance * size * 45
      tail.y = by - dy / distance * size * 45
      tail.angle = angle
      tail.zoom_x = final ? 0.50 : 0.66
      tail.zoom_y = final ? 0.90 : 0.65
      tail.opacity = age >= 0 && age < flight ?
        (Math.sin(p * Math::PI) * 215).to_i : 0

      #=========================================================================
      # VỠ BONG BÓNG — Hai vòng nước rõ, giọt lớn và nhiều bọt trắng
      #=========================================================================
      burst_start = arrival + 0.035
      duration = final ? 0.73 : 0.43
      q = (sec - burst_start) / duration
      bp = a.clamp(q)
      active = q.between?(0.0, 1.0)

      shot[:rings].each_with_index do |ring, j|
        ring.x = cx
        ring.y = cy
        ring.zoom_x = 0.18 + bp * (final ? 2.65 : 1.10) +
                      j * bp * 0.22
        ring.zoom_y = ring.zoom_x * (j == 0 ? 0.86 : 0.62)
        ring.opacity = active ?
          ((1.0 - bp) * (j == 0 ? 255 : 210)).to_i : 0
      end

      # Giọt nước bắn xa, đầu sáng trắng.
      shot[:drops].each_with_index do |drop, j|
        theta = j * 2.399 + i * 0.73
        reach = final ? 55 + j % 7 * 12 : 28 + j % 5 * 8
        travel = 1.0 - (1.0 - bp)**2

        drop.x = cx + Math.cos(theta) * travel * reach
        drop.y = cy + Math.sin(theta) * travel * reach * 0.73 +
                 bp * bp * (final ? 55 : 27)
        drop.angle = -theta * 180 / Math::PI + 90
        scale = (final ? 0.43 : 0.29) + j % 4 * 0.08
        drop.zoom_x = scale * (1.0 - bp * 0.35)
        drop.zoom_y = scale * (1.0 + bp * 0.25)
        drop.opacity = active ?
          (a.clamp((1.0 - bp) / 0.55) * 250).to_i : 0
      end

      # Bọt trắng nở thành cụm, chuyển động chậm hơn giọt.
      shot[:foam].each_with_index do |foam, j|
        theta = j * 2.399 + 0.8
        reach = final ? 28 + j % 6 * 12 : 16 + j % 4 * 8

        foam.x = cx + Math.cos(theta) * bp * reach
        foam.y = cy + Math.sin(theta) * bp * reach * 0.65 +
                 bp * bp * 24
        foam.angle = j * 31 + bp * 35
        scale = (final ? 0.32 : 0.22) + j % 3 * 0.10
        foam.zoom_x = scale + Math.sin(bp * Math::PI) * 0.24
        foam.zoom_y = foam.zoom_x * 0.85
        foam.opacity = active ?
          (Math.sin(bp * Math::PI) * 245).to_i : 0
      end

      flash_age = sec - burst_start
      if flash_age.between?(0.0, 0.14)
        strength = (1.0 - flash_age / 0.14) * (final ? 1.0 : 0.25)
        flash = [flash, strength].max
      end
    end

    #===========================================================================
    # PHẢN LỰC QUẢ CUỐI
    #===========================================================================
    body = g[:body]
    body.color = flash > 0 ?
      Color.new(222, 252, 255, (flash * 220).to_i) : g[:color]

    age = sec - 1.795
    shake = age.between?(0.0, 0.25) ? 1.0 - age / 0.25 : 0.0
    body.x = g[:base_x] + Math.sin(age * 105) * shake * 7
    body.y = g[:base_y] - Math.sin(age * 80).abs * shake * 2

    # Bong bóng đỏ cam nhỏ nổi lên sau vụ nổ.
    g[:tiny].each_with_index do |bubble, i|
      q = (sec - 2.00 - i % 6 * 0.035) / 0.64
      p = a.clamp(q)

      bubble.x = cx + Math.sin(i * 2.399) * (23 + i % 4 * 12) +
                 Math.sin(p * 4 + i) * 5
      bubble.y = cy + 22 - p * (35 + i % 4 * 15)
      bubble.zoom_x = 0.065 + i % 3 * 0.035
      bubble.zoom_y = bubble.zoom_x
      bubble.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 220).to_i : 0
    end
  end
end