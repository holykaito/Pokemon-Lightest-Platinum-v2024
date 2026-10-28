#===============================================================================
# BLACK MAGIC — Hắc chú
# Yêu cầu: 000_AnimationCore.rb
#===============================================================================

KaitoAnimation.register(
  :BLACKMAGIC,
  duration: 2.45,
  setup: proc do |a|
    a.sound_at(0.03, ["PRSFX- Confuse Ray"], 50, 80)
    a.sound_at(0.57, ["PRSFX- Curse2"], 65, 90)

    [1.00, 1.20, 1.40].each_with_index do |time, i|
      a.sound_at(time, ["PRSFX- Night Slash1"], 70 + i * 5, 95 + i * 8)
    end

    a.sound_at(1.57, ["PRSFX- Ominous Wind"], 45, 110)

    #---------------------------------------------------------------------------
    # Quả cầu đen, viền tím nhiều lớp
    #---------------------------------------------------------------------------
    orb = a.bitmap(88, 88) do |b|
      88.times do |y|
        88.times do |x|
          r = Math.sqrt((x - 43.5)**2 + (y - 43.5)**2)
          next if r > 42

          color =
            if r > 35
              Color.new(116, 58, 169, ((42 - r) / 7.0 * 130).to_i)
            elsif r > 30
              Color.new(171, 91, 222, 235)
            elsif r > 26
              Color.new(71, 31, 101, 255)
            else
              Color.new(13, 8, 22, 255)
            end

          b.set_pixel(x, y, color)
        end
      end
    end

    #---------------------------------------------------------------------------
    # Ký tự đỏ sẫm
    #---------------------------------------------------------------------------
    glyphs = Array.new(3) do |i|
      a.bitmap(18, 24) do |b|
        color = Color.new(190, 48, 78, 245)

        case i
        when 0
          a.polygon(
            b,
            [[2, 4], [9, 0], [16, 4], [9, 9]],
            color
          )
          b.fill_rect(8, 8, 3, 15, color)
          b.fill_rect(3, 15, 13, 3, color)
        when 1
          a.polygon(
            b,
            [[2, 1], [5, 1], [5, 14], [15, 14],
             [15, 17], [2, 17]],
            color
          )
          a.polygon(
            b,
            [[9, 3], [12, 3], [12, 23], [9, 23]],
            color
          )
        else
          a.polygon(
            b,
            [[1, 3], [4, 1], [17, 21], [14, 23]],
            color
          )
          a.polygon(
            b,
            [[14, 1], [17, 3], [4, 23], [1, 21]],
            color
          )
        end
      end
    end

    #---------------------------------------------------------------------------
    # Ấn chú: vòng đỏ đen, ngôi sao và ký tự quanh viền
    #---------------------------------------------------------------------------
    seal = a.bitmap(176, 176) do |b|
      176.times do |y|
        176.times do |x|
          r = Math.sqrt((x - 87.5)**2 + (y - 87.5)**2)
          next if r > 85

          color =
            if r >= 80 || r.between?(62, 65)
              Color.new(190, 43, 74, 240)
            elsif r >= 75
              Color.new(42, 10, 27, 245)
            else
              Color.new(20, 8, 29, 65)
            end

          b.set_pixel(x, y, color)
        end
      end

      points = Array.new(5) do |i|
        theta = -Math::PI / 2 + i * Math::PI * 2 / 5
        [88 + Math.cos(theta) * 55, 88 + Math.sin(theta) * 55]
      end

      [0, 2, 4, 1, 3, 0].each_cons(2) do |i, j|
        x1, y1 = points[i]
        x2, y2 = points[j]
        dx = x2 - x1
        dy = y2 - y1
        length = Math.sqrt(dx * dx + dy * dy)
        nx = -dy / length * 1.5
        ny = dx / length * 1.5

        a.polygon(
          b,
          [[x1 + nx, y1 + ny], [x2 + nx, y2 + ny],
           [x2 - nx, y2 - ny], [x1 - nx, y1 - ny]],
          Color.new(172, 40, 72, 235)
        )
      end

      12.times do |i|
        theta = i * Math::PI * 2 / 12
        x = (88 + Math.cos(theta) * 71).round
        y = (88 + Math.sin(theta) * 71).round
        b.blt(x - 5, y - 7, glyphs[i % 3], Rect.new(0, 0, 18, 24))
      end
    end

    #---------------------------------------------------------------------------
    # Vệt cắt: thân đen, viền đỏ rõ
    #---------------------------------------------------------------------------
    cut = a.bitmap(232, 72) do |b|
      a.polygon(
        b,
        [[1, 65], [50, 29], [108, 9], [169, 2],
         [231, 9], [169, 17], [110, 32], [53, 50]],
        Color.new(207, 47, 78, 250)
      )
      a.polygon(
        b,
        [[7, 61], [56, 31], [112, 13], [170, 6],
         [224, 9], [165, 14], [108, 28], [53, 46]],
        Color.new(17, 7, 24, 255)
      )
      a.polygon(
        b,
        [[16, 55], [69, 28], [124, 13], [187, 7],
         [224, 9], [166, 12], [109, 25]],
        Color.new(73, 17, 45, 235)
      )
    end

    #---------------------------------------------------------------------------
    # Mảnh ấn chú và khói đen viền tím
    #---------------------------------------------------------------------------
    shard = a.bitmap(18, 24) do |b|
      a.polygon(
        b,
        [[2, 5], [15, 0], [11, 14], [5, 23]],
        Color.new(200, 42, 75, 250)
      )
      a.polygon(
        b,
        [[5, 6], [13, 2], [9, 13], [6, 17]],
        Color.new(76, 13, 39, 255)
      )
    end

    smoke = a.bitmap(48, 44) do |b|
      a.polygon(
        b,
        [[1, 27], [4, 14], [14, 8], [20, 1],
         [33, 4], [38, 13], [46, 20], [47, 32],
         [36, 42], [17, 43], [5, 36]],
        Color.new(68, 37, 88, 150)
      )
      a.polygon(
        b,
        [[5, 27], [9, 16], [19, 12], [24, 6],
         [32, 10], [35, 18], [42, 24], [41, 33],
         [32, 39], [18, 39], [9, 34]],
        Color.new(16, 11, 23, 205)
      )
    end

    #---------------------------------------------------------------------------
    # Tụ cầu trước người dùng
    #---------------------------------------------------------------------------
    ux, uy = a.center
    tx, ty = a.center(a.targets.first)
    dx = tx - ux
    dy = ty - uy
    length = [Math.sqrt(dx * dx + dy * dy), 1.0].max

    a[:orb_x] = ux + dx / length * 30
    a[:orb_y] = uy - 8 + dy / length * 12
    a[:orb] = a.sprite(orb, z: 20_025)
    a[:glyphs] = Array.new(12) do |i|
      a.sprite(glyphs[i % 3], z: 20_027)
    end
    a[:source_smoke] = Array.new(12) do
      a.sprite(smoke, z: 20_029)
    end

    a[:groups] = a.targets.map do |target|
      cx, cy = a.center(target)
      body = a.copy(target, hide_original: true, z: 20_015)

      {
        x: cx, y: cy,
        body: body,
        base_x: body.x,
        base_y: body.y,
        color: body.color.clone,
        seal: a.sprite(seal, z: 20_024),
        cuts: Array.new(6) { a.sprite(cut, z: 20_033) },
        shards: Array.new(24) { a.sprite(shard, z: 20_035) },
        smoke: Array.new(18) { a.sprite(smoke, z: 20_037) }
      }
    end
  end
) do |a, _t|
  sec = a.seconds

  #=============================================================================
  # 1. NIỆM CHÚ — Ký tự xoay rồi hút vào cầu đen
  #=============================================================================
  grow = a.clamp(sec / 0.36)
  consume = a.clamp((sec - 0.34) / 0.27)
  vanish = a.clamp((0.74 - sec) / 0.20)

  orb = a[:orb]
  orb.x = a[:orb_x]
  orb.y = a[:orb_y]
  orb.zoom_x = (0.18 + grow * 0.56) *
               (1.0 + Math.sin(sec * 18) * 0.035)
  orb.zoom_y = orb.zoom_x
  orb.opacity = (grow * vanish * 255).to_i

  a[:glyphs].each_with_index do |glyph, i|
    theta = i * Math::PI * 2 / 12 + sec * 2.5
    radius = (45 + i % 3 * 5) * (1.0 - consume * 0.94)

    glyph.x = a[:orb_x] + Math.cos(theta) * radius
    glyph.y = a[:orb_y] + Math.sin(theta) * radius * 0.65
    glyph.angle = -theta * 180 / Math::PI
    glyph.zoom_x = 0.55 * (1.0 - consume * 0.65)
    glyph.zoom_y = glyph.zoom_x
    glyph.opacity = (grow * (1.0 - consume) * 235).to_i
  end

  # Cầu tan thành khói tại chỗ; ấn xuất hiện bên mục tiêu.
  a[:source_smoke].each_with_index do |smoke, i|
    q = (sec - 0.48 - i % 4 * 0.025) / 0.43
    p = a.clamp(q)
    theta = i * 2.399

    smoke.x = a[:orb_x] + Math.cos(theta) * p * 29
    smoke.y = a[:orb_y] + Math.sin(theta) * p * 20 - p * 13
    smoke.zoom_x = 0.23 + p * 0.55
    smoke.zoom_y = smoke.zoom_x
    smoke.angle = i * 31
    smoke.opacity = q.between?(0.0, 1.0) ?
      (Math.sin(p * Math::PI) * 195).to_i : 0
  end

  a[:groups].each do |g|
    cx = g[:x]
    cy = g[:y]

    #===========================================================================
    # 2. ÁP LỜI NGUYỀN — Ấn trước cơ thể, xoay chậm rồi co đột ngột
    #===========================================================================
    appear = a.clamp((sec - 0.57) / 0.22)
    contract = a.clamp((sec - 0.92) / 0.09)
    break_up = a.clamp((sec - 1.52) / 0.12)

    seal = g[:seal]
    seal.x = cx
    seal.y = cy
    seal.angle = (sec - 0.57) * 15
    seal.zoom_x = (0.50 + appear * 0.25) * (1.0 - contract * 0.43)
    seal.zoom_y = seal.zoom_x
    seal.opacity = (appear * (1.0 - break_up) * 225).to_i

    #===========================================================================
    # 3. SÁT THƯƠNG — Ba vệt cắt và dư ảnh ngắn
    #===========================================================================
    pulse = 0.0

    g[:cuts].each_with_index do |cut, i|
      hit = i / 2
      afterimage = i.odd?
      start = [1.00, 1.20, 1.40][hit]
      start += 0.045 if afterimage

      q = (sec - start) / 0.20
      p = a.clamp(q)
      direction = hit == 1 ? -1 : 1

      cut.x = cx + direction * (-22 + p * 44)
      cut.y = cy + [10, -7, 2][hit] - p * 13
      cut.angle = [-36, 39, -18][hit]
      cut.mirror = hit == 1
      cut.zoom_x = (0.72 + p * 0.25) * (hit == 2 ? 1.10 : 1.0)
      cut.zoom_y = afterimage ? 0.70 : 0.90
      cut.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * (afterimage ? 95 : 255)).to_i : 0
    end

    [1.00, 1.20, 1.40].each do |time|
      age = sec - time
      pulse = [pulse, 1.0 - age / 0.12].max if age.between?(0.0, 0.12)
    end

    body = g[:body]
    body.color = pulse > 0 ?
      Color.new(58, 18, 82, (pulse * 205).to_i) : g[:color]

    # Chỉ nhát cuối tạo rung rõ.
    age = sec - 1.40
    shake = age.between?(0.0, 0.22) ? 1.0 - age / 0.22 : 0.0
    body.x = g[:base_x] + Math.sin(age * 110) * shake * 5
    body.y = g[:base_y] - Math.sin(age * 75).abs * shake * 2

    #===========================================================================
    # 4. TÀN DƯ — Mảnh đỏ rơi rồi tan thành khói đen
    #===========================================================================
    g[:shards].each_with_index do |shard, i|
      q = (sec - 1.53 - i % 4 * 0.012) / 0.62
      p = a.clamp(q)
      theta = i * Math::PI * 2 / 24

      shard.x = cx + Math.cos(theta) * (32 + p * 24)
      shard.y = cy + Math.sin(theta) * 32 -
                p * (8 + i % 3 * 5) + p * p * 67
      shard.angle = i * 29 + p * (i.even? ? 170 : -170)
      shard.zoom_x = (0.28 + i % 3 * 0.12) * (1.0 - p * 0.45)
      shard.zoom_y = shard.zoom_x
      shard.opacity = q.between?(0.0, 1.0) ?
        (a.clamp((1.0 - p) / 0.40) * 240).to_i : 0
    end

    g[:smoke].each_with_index do |smoke, i|
      q = (sec - 1.78 - i % 6 * 0.025) / 0.50
      p = a.clamp(q)
      theta = i * 2.399

      smoke.x = cx + Math.cos(theta) * (22 + p * 18)
      smoke.y = cy + 25 + Math.sin(theta) * 20 - p * 27
      smoke.angle = i * 23 + p * 15
      smoke.zoom_x = 0.22 + p * 0.65
      smoke.zoom_y = smoke.zoom_x * 0.85
      smoke.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 185).to_i : 0
    end
  end
end