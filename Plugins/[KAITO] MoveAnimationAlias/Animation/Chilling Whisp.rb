#===============================================================================
# CHILLING WHISP — Hàn khí ma mị
# Yêu cầu: 000_AnimationCore.rb
#===============================================================================

KaitoAnimation.register(
  :CHILLINGWHISP,
  duration: 2.00,
  setup: proc do |a|
    a.sound_at(0.03, ["PRSFX- Icy Wind1"], 45, 115)
    a.sound_at(0.42, ["PRSFX- Frost Breath1"], 55, 110)
    a.sound_at(1.00, ["PRSFX- Powder Snow2"], 60, 115)

    ux, uy = a.center
    a[:ux] = ux
    a[:uy] = uy

    #---------------------------------------------------------------------------
    # Đốm hàn khí: quầng mềm, viền tím băng, lõi trắng xanh
    #---------------------------------------------------------------------------
    wisp = a.bitmap(60, 84) do |b|
      84.times do |y|
        60.times do |x|
          r = Math.sqrt(
            ((x - 29.5) / 29.0)**2 +
            ((y - 48.0) / 34.0)**2
          )
          next if r > 1.0

          alpha = ((1.0 - r)**2 * 100).to_i
          b.set_pixel(x, y, Color.new(151, 177, 241, alpha))
        end
      end

      a.polygon(
        b,
        [[29, 77], [14, 72], [8, 59], [12, 44],
         [24, 30], [29, 14], [25, 2], [39, 16],
         [41, 32], [35, 43], [46, 38], [51, 51],
         [48, 65], [40, 75]],
        Color.new(145, 169, 235, 190)
      )
      a.polygon(
        b,
        [[29, 73], [18, 67], [15, 56], [23, 43],
         [31, 31], [32, 19], [36, 33], [29, 49],
         [39, 44], [44, 54], [40, 66]],
        Color.new(158, 231, 247, 235)
      )
      a.polygon(
        b,
        [[29, 67], [23, 61], [24, 51], [31, 40],
         [30, 53], [36, 50], [38, 59], [34, 66]],
        Color.new(242, 255, 255, 250)
      )
    end

    #---------------------------------------------------------------------------
    # Sương lạnh: tâm sáng nhạt, rìa hoàn toàn trong suốt
    #---------------------------------------------------------------------------
    mist = a.bitmap(72, 56) do |b|
      56.times do |y|
        72.times do |x|
          r = Math.sqrt(
            ((x - 35.5) / 35.0)**2 +
            ((y - 27.5) / 27.0)**2
          )
          next if r > 1.0

          alpha = ((1.0 - r)**1.7 * 120).to_i
          b.set_pixel(x, y, Color.new(173, 222, 244, alpha))
        end
      end
    end

    #---------------------------------------------------------------------------
    # Bông tuyết sáu cánh
    #---------------------------------------------------------------------------
    snow = a.bitmap(36, 36) do |b|
      draw_line = proc do |p1, p2, thickness, color|
        dx = p2[0] - p1[0]
        dy = p2[1] - p1[1]
        length = [Math.sqrt(dx * dx + dy * dy), 0.01].max
        nx = -dy / length * thickness / 2.0
        ny = dx / length * thickness / 2.0

        a.polygon(
          b,
          [[p1[0] + nx, p1[1] + ny],
           [p2[0] + nx, p2[1] + ny],
           [p2[0] - nx, p2[1] - ny],
           [p1[0] - nx, p1[1] - ny]],
          color
        )
      end

      color = Color.new(229, 251, 255, 245)

      6.times do |i|
        theta = i * Math::PI / 3
        tip = [18 + Math.cos(theta) * 16,
               18 + Math.sin(theta) * 16]
        draw_line.call([18, 18], tip, 2, color)

        joint = [18 + Math.cos(theta) * 10,
                 18 + Math.sin(theta) * 10]

        [-1, 1].each do |side|
          branch = theta + Math::PI + side * 0.85
          endpoint = [
            joint[0] + Math.cos(branch) * 6,
            joint[1] + Math.sin(branch) * 6
          ]
          draw_line.call(joint, endpoint, 1.5, color)
        end
      end
    end

    ring = a.ring(51, Color.new(194, 233, 255, 210), 2)

    a[:groups] = a.targets.map do |target|
      cx, cy = a.center(target)
      original = a.battler_sprite(target)
      floor = original.y +
              (original.src_rect.height - original.oy) * original.zoom_y
      body = a.copy(target, hide_original: true, z: 20_018)

      dx = cx - ux
      dy = cy - uy
      distance = [Math.sqrt(dx * dx + dy * dy), 1.0].max

      {
        x: cx, y: cy, floor: floor,
        sx: ux + dx / distance * 25,
        sy: uy + dy / distance * 12,
        body: body,
        base_x: body.x, base_y: body.y,
        color: body.color.clone,
        wisps: Array.new(3) { a.sprite(wisp, z: 20_028) },
        trails: Array.new(9) { a.sprite(wisp, z: 20_025) },
        mist: Array.new(18) { a.sprite(mist, z: 20_026) },
        snow: Array.new(24) { a.sprite(snow, z: 20_030) },
        ring: a.sprite(ring, z: 20_027)
      }
    end
  end
) do |a, _t|
  sec = a.seconds

  a[:groups].each do |g|
    cx = g[:x]
    cy = g[:y]

    #=============================================================================
    # 1. BA ĐỐM HÀN KHÍ TỤ LẠI RỒI BAY LƯỢN SANG MỤC TIÊU
    #=============================================================================
    g[:wisps].each_with_index do |wisp, i|
      q = (sec - 0.28 - i * 0.055) / 0.65
      p = a.clamp(q)
      phase = i * Math::PI * 2 / 3

      # Đường bay cong, dao động giảm dần khi đến mục tiêu.
      path = proc do |progress|
        theta = phase + progress * Math::PI * 2
        radius = 15 + Math.sin(progress * Math::PI) * 10

        [
          a.lerp(g[:sx], cx, progress) +
            Math.cos(theta) * radius,
          a.lerp(g[:sy], cy, progress) +
            Math.sin(theta) * radius * 0.75 -
            Math.sin(progress * Math::PI) * 15
        ]
      end

      point = path.call(p)
      linger = a.clamp((sec - 1.03) / 0.27)
      brightness = a.clamp(sec / 0.20) *
                   a.clamp((1.30 - sec) / 0.26)

      wisp.x = point[0] + Math.sin(sec * 7 + phase) * linger * 8
      wisp.y = point[1] - linger * 17
      wisp.angle = Math.sin(sec * 4 + phase) * 9
      wisp.zoom_x = [0.48, 0.61, 0.43][i] * (1.0 - linger * 0.20)
      wisp.zoom_y = wisp.zoom_x * (1.0 + Math.sin(sec * 6 + i) * 0.05)
      wisp.opacity = (brightness * 245).to_i

      # Dư ảnh nhỏ, trong, tạo đuôi hàn khí mềm.
      3.times do |j|
        tail = g[:trails][i * 3 + j]
        tail_p = p - (j + 1) * 0.075
        pos = path.call(a.clamp(tail_p))

        tail.x = pos[0]
        tail.y = pos[1]
        tail.angle = -8 + j * 7
        tail.zoom_x = (0.28 - j * 0.045) * (1.0 - linger)
        tail.zoom_y = tail.zoom_x
        tail.opacity = q > 0 && q < 1.0 && tail_p > 0 ?
          (105 - j * 25) : 0
      end
    end

    #=============================================================================
    # 2. HÀN KHÍ CUỐN QUANH CƠ THỂ
    #=============================================================================
    g[:mist].each_with_index do |cloud, i|
      q = (sec - 0.83 - i % 6 * 0.025) / 0.85
      p = a.clamp(q)
      theta = i * 2.399 + p * 2.4
      radius = 15 + i % 4 * 7 + p * 9
      depth = Math.sin(theta)

      cloud.x = cx + Math.cos(theta) * radius
      cloud.y = cy + depth * 22 - p * 12
      cloud.z = depth > 0 ? 20_026 : 20_014
      cloud.zoom_x = 0.35 + p * 0.55
      cloud.zoom_y = cloud.zoom_x * 0.75
      cloud.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 180).to_i : 0
    end

    # Vòng lạnh mỏng, không tạo vụ nổ sát thương.
    q = (sec - 1.01) / 0.48
    p = a.clamp(q)
    ring = g[:ring]
    ring.x = cx
    ring.y = cy
    ring.zoom_x = 0.25 + p * 0.92
    ring.zoom_y = ring.zoom_x * 0.82
    ring.opacity = q.between?(0.0, 1.0) ?
      ((1.0 - p) * 175).to_i : 0

    #=============================================================================
    # 3. RÉT RUN — Ánh xanh nhạt và một nhịp run nhỏ
    #=============================================================================
    chill = a.clamp((sec - 0.94) / 0.16) *
            a.clamp((1.80 - sec) / 0.45)
    age = sec - 1.04
    shiver = age.between?(0.0, 0.30) ?
      Math.sin(age / 0.30 * Math::PI) : 0.0

    body = g[:body]
    body.x = g[:base_x] + Math.sin(age * 110) * shiver * 1.8
    body.y = g[:base_y]
    body.color = chill > 0 ?
      Color.new(175, 220, 248, (chill * 95).to_i) : g[:color]

    #=============================================================================
    # 4. TINH THỂ TUYẾT XOAY NHẸ RỒI RƠI XUỐNG
    #=============================================================================
    g[:snow].each_with_index do |flake, i|
      q = (sec - 1.00 - i % 6 * 0.035) / 0.78
      p = a.clamp(q)
      theta = i * 2.399

      flake.x = cx + Math.cos(theta) * (21 + p * 25) +
                Math.sin(p * 3 + i) * 4
      flake.y = cy + Math.sin(theta) * 25 -
                Math.sin(p * Math::PI) * 9 + p * p * 32
      flake.angle = i * 27 + p * (i.even? ? 45 : -45)
      flake.zoom_x = 0.18 + i % 4 * 0.075
      flake.zoom_y = flake.zoom_x
      flake.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 230).to_i : 0
    end
  end
end