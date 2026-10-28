#===============================================================================
# FOREST FURY — Tụ lực / Rễ siết / Tam trảm
# Yêu cầu: 000_AnimationCore.rb
# Thay thế registration :FORESTFURY cũ.
#===============================================================================

KaitoAnimation.register(
  :FORESTFURY,
  duration: 2.40,
  setup: proc do |a|
    #---------------------------------------------------------------------------
    # Âm thanh
    #---------------------------------------------------------------------------
    a.sound_at(0.02, ["PRSFX- Energy Ball1"], 65, 85)
    a.sound_at(0.48, ["PRSFX- Grass Knot1"], 80, 85)
    a.sound_at(0.76, ["PRSFX- Frenzy Plant1"], 80, 95)
    a.sound_at(1.08, ["PRSFX- Leaf Storm1"], 75, 110)

    [1.35, 1.57, 1.79].each_with_index do |time, i|
      a.sound_at(time, ["PRSFX- Leaf Blade"], 85, 95 + i * 10)
    end

    #---------------------------------------------------------------------------
    # Quầng sáng dưới đất
    #---------------------------------------------------------------------------
    glow = a.bitmap(196, 76) do |b|
      76.times do |y|
        196.times do |x|
          dx = (x - 97.5) / 96.0
          dy = (y - 37.5) / 36.0
          r = dx * dx + dy * dy
          next if r > 1.0

          alpha = ((1.0 - r) * 160).to_i
          b.set_pixel(x, y, Color.new(90, 240, 100, alpha))
        end
      end
    end

    ring = a.ring(66, Color.new(166, 255, 114, 220), 3)

    #---------------------------------------------------------------------------
    # Vết nứt, có lớp sáng xanh nằm trong khe
    #---------------------------------------------------------------------------
    cracks = a.bitmap(200, 76) do |b|
      paths = [
        [[100, 38], [75, 30], [57, 35], [30, 20], [10, 23]],
        [[100, 38], [123, 27], [143, 31], [166, 14], [188, 10]],
        [[100, 38], [82, 49], [60, 47], [42, 64]],
        [[100, 38], [125, 49], [146, 45], [174, 64]],
        [[76, 30], [69, 15], [52, 9]],
        [[144, 45], [153, 57], [150, 71]]
      ]

      paths.each do |points|
        points.each_cons(2) do |p1, p2|
          x1, y1 = p1
          x2, y2 = p2
          a.polygon(
            b,
            [[x1, y1 - 2], [x2, y2 - 1],
             [x2, y2 + 2], [x1, y1 + 3]],
            Color.new(56, 43, 24, 240)
          )
          a.polygon(
            b,
            [[x1, y1], [x2, y2],
             [x2, y2 + 1], [x1, y1 + 1]],
            Color.new(165, 246, 95, 220)
          )
        end
      end
    end

    #---------------------------------------------------------------------------
    # Lá: đầu nhọn, sống lá vàng xanh
    #---------------------------------------------------------------------------
    leaf = a.bitmap(30, 16) do |b|
      a.polygon(
        b,
        [[1, 12], [7, 3], [17, 1], [29, 3],
         [23, 11], [12, 15]],
        Color.new(41, 160, 52, 245)
      )
      a.polygon(
        b,
        [[2, 12], [14, 7], [29, 3], [16, 10]],
        Color.new(185, 246, 102, 255)
      )
    end

    #---------------------------------------------------------------------------
    # Rễ cong vào trong, có vân gỗ và đầu nhọn
    #---------------------------------------------------------------------------
    root = a.bitmap(120, 176) do |b|
      a.polygon(
        b,
        [[30, 175], [35, 133], [46, 110], [49, 84],
         [70, 59], [94, 40], [113, 8], [108, 50],
         [89, 77], [81, 104], [69, 128], [64, 175]],
        Color.new(82, 54, 26, 255)
      )
      a.polygon(
        b,
        [[38, 175], [44, 135], [57, 113], [59, 87],
         [78, 65], [99, 43], [88, 73], [73, 102],
         [62, 132], [55, 175]],
        Color.new(153, 113, 52, 255)
      )
      a.polygon(
        b,
        [[48, 171], [52, 134], [65, 108], [68, 87],
         [86, 64], [74, 93], [71, 115], [60, 143],
         [58, 173]],
        Color.new(191, 156, 80, 230)
      )
      a.polygon(
        b,
        [[47, 120], [25, 100], [14, 76], [36, 94],
         [57, 105]],
        Color.new(103, 75, 32, 255)
      )
      a.polygon(
        b,
        [[76, 88], [99, 77], [115, 58], [105, 85],
         [78, 103]],
        Color.new(115, 87, 39, 255)
      )
      a.polygon(
        b,
        [[62, 110], [68, 89], [86, 67], [74, 93],
         [68, 114]],
        Color.new(123, 214, 66, 225)
      )
    end

    #---------------------------------------------------------------------------
    # Bụi đất và mảnh gỗ
    #---------------------------------------------------------------------------
    dust = a.bitmap(32, 24) do |b|
      a.polygon(
        b,
        [[1, 15], [5, 6], [14, 2], [25, 5],
         [31, 14], [24, 22], [9, 23]],
        Color.new(151, 125, 78, 115)
      )
    end

    chip = a.bitmap(16, 22) do |b|
      a.polygon(
        b,
        [[2, 5], [10, 1], [14, 14], [7, 21]],
        Color.new(125, 85, 39, 255)
      )
      a.polygon(
        b,
        [[5, 6], [9, 3], [11, 14], [8, 17]],
        Color.new(206, 170, 91, 255)
      )
    end

    #---------------------------------------------------------------------------
    # Nhát chém cong: viền xanh đậm, thân lục sáng, lõi vàng nhạt
    #---------------------------------------------------------------------------
    slash = a.bitmap(228, 92) do |b|
      a.polygon(
        b,
        [[2, 79], [34, 47], [76, 24], [126, 11],
         [183, 9], [226, 18], [178, 23], [129, 35],
         [80, 51], [37, 68]],
        Color.new(24, 115, 38, 235)
      )
      a.polygon(
        b,
        [[4, 78], [45, 47], [91, 28], [140, 18],
         [195, 16], [221, 18], [171, 26], [120, 40],
         [68, 59]],
        Color.new(91, 245, 82, 255)
      )
      a.polygon(
        b,
        [[13, 73], [66, 43], [119, 26], [175, 18],
         [218, 18], [164, 24], [110, 35], [57, 55]],
        Color.new(243, 255, 177, 255)
      )
    end

    #---------------------------------------------------------------------------
    # Tụ lực tại người dùng
    #---------------------------------------------------------------------------
    source = a.battler_sprite
    ux, uy = a.center
    ug = source.y +
         (source.src_rect.height - source.oy) * source.zoom_y

    a[:source] = {
      x: ux, y: uy, ground: ug,
      glow: a.sprite(glow, z: 20_010),
      cracks: a.sprite(cracks, z: 20_011),
      ring: a.sprite(ring, z: 20_012),
      leaves: Array.new(9) { a.sprite(leaf, z: 20_024) }
    }

    #---------------------------------------------------------------------------
    # Hiệu ứng tại từng mục tiêu
    #---------------------------------------------------------------------------
    a[:groups] = a.targets.map do |target|
      original = a.battler_sprite(target)
      cx, cy = a.center(target)
      ground = original.y +
               (original.src_rect.height - original.oy) * original.zoom_y

      roots = Array.new(6) do |i|
        s = a.sprite(root, z: i < 2 ? 20_013 : 20_023)
        s.ox = 60
        s.oy = 176
        s.mirror = i.odd?
        s
      end

      copy = a.copy(target, hide_original: true, z: 20_015)

      {
        x: cx, y: cy, ground: ground,
        copy: copy,
        base_x: copy.x, base_y: copy.y,
        color: copy.color.clone,
        glow: a.sprite(glow, z: 20_010),
        cracks: a.sprite(cracks, z: 20_011),
        roots: roots,
        dust: Array.new(14) { a.sprite(dust, z: 20_025) },
        chips: Array.new(18) { a.sprite(chip, z: 20_027) },
        leaves: Array.new(46) { a.sprite(leaf, z: 20_028) },
        slashes: Array.new(3) { a.sprite(slash, z: 20_034) },
        rings: Array.new(3) { a.sprite(ring, z: 20_032) }
      }
    end

    flash_bitmap = a.bitmap(Graphics.width, Graphics.height) do |b|
      b.fill_rect(
        0, 0, b.width, b.height,
        Color.new(255, 245, 174)
      )
    end
    a[:flash] = a.sprite(flash_bitmap, z: 20_050, centered: false)
  end
) do |a, _t|
  sec = a.seconds

  #=============================================================================
  # 1. TỤ LỰC — Quầng xanh, lá bay lên, đất rạn
  #=============================================================================
  source = a[:source]
  charge = a.clamp(sec / 0.42)
  release = a.clamp((0.95 - sec) / 0.35)

  s = source[:glow]
  s.x = source[:x]
  s.y = source[:ground] - 3
  s.zoom_x = 0.35 + charge * 0.85
  s.zoom_y = 0.55 + charge * 0.45
  s.opacity = (charge * release * 230).to_i

  s = source[:cracks]
  s.x = source[:x]
  s.y = source[:ground]
  s.opacity = (charge * release * 235).to_i

  s = source[:ring]
  s.x = source[:x]
  s.y = source[:ground] - 2
  s.zoom_x = 0.35 + charge * 1.05
  s.zoom_y = s.zoom_x * 0.27
  s.opacity = (Math.sin(charge * Math::PI) * release * 210).to_i

  source[:leaves].each_with_index do |leaf, i|
    q = (sec - i * 0.035) / 0.70
    p = a.clamp(q)
    theta = i * 2.4 + p * 3.0

    leaf.x = source[:x] + Math.cos(theta) * (18 + p * 28)
    leaf.y = source[:ground] - 8 - p * (55 + i % 3 * 16)
    leaf.angle = theta * 180 / Math::PI
    leaf.zoom_x = 0.40 + i % 3 * 0.13
    leaf.zoom_y = leaf.zoom_x
    leaf.opacity = q.between?(0.0, 1.0) ?
      (Math.sin(p * Math::PI) * 240).to_i : 0
  end

  # Chớp vàng riêng cho từng nhát chém.
  impact = 0.0
  [1.35, 1.57, 1.79].each do |time|
    q = sec - time
    impact = [impact, 1.0 - q / 0.11].max if q.between?(0.0, 0.11)
  end
  a[:flash].opacity = (impact * 58).to_i

  a[:groups].each do |g|
    cx = g[:x]
    cy = g[:y]
    ground = g[:ground]
    finish = a.clamp((2.40 - sec) / 0.36)

    #===========================================================================
    # 2. KHỐNG CHẾ — Rễ trồi lên rồi siết vào trong
    #===========================================================================
    emergence = a.clamp((sec - 0.47) / 0.44)
    grip = a.clamp((sec - 0.86) / 0.25)

    s = g[:glow]
    s.x = cx
    s.y = ground - 3
    s.zoom_x = 1.05
    s.zoom_y = 0.8
    s.opacity = (emergence * finish * 120).to_i

    s = g[:cracks]
    s.x = cx
    s.y = ground
    s.zoom_x = 1.05
    s.opacity = (emergence * finish * 240).to_i

    g[:roots].each_with_index do |root, i|
      side = i.odd? ? 1 : -1
      rise = a.clamp((sec - 0.48 - i * 0.045) / 0.40)
      pair = i / 2

      root.x = cx + side * (76 - grip * 27 - pair * 9)
      root.y = ground + pair * 3
      root.zoom_x = 0.68 + pair * 0.10
      root.zoom_y = rise * (0.65 + pair * 0.13)
      root.angle = side * grip * 5
      root.opacity = (rise * finish * 255).to_i
    end

    # Bụi phun sang hai bên khi rễ xuyên đất.
    g[:dust].each_with_index do |dust, i|
      q = (sec - 0.54 - i % 4 * 0.055) / 0.65
      p = a.clamp(q)
      side = i.odd? ? 1 : -1

      dust.x = cx + side * (24 + p * (38 + i % 3 * 14))
      dust.y = ground - Math.sin(p * Math::PI) * (12 + i % 4 * 6)
      dust.zoom_x = 0.45 + p * 1.2
      dust.zoom_y = 0.35 + p * 0.65
      dust.angle = i * 29
      dust.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 155).to_i : 0
    end

    # Mảnh gỗ bật ra khi trồi rễ và khi bắt đầu chém.
    g[:chips].each_with_index do |chip, i|
      start = i < 10 ? 0.61 + i * 0.016 : 1.35 + (i - 10) * 0.045
      q = (sec - start) / 0.55
      p = a.clamp(q)
      side = i.odd? ? 1 : -1

      chip.x = cx + side * (20 + p * (35 + i % 4 * 13))
      chip.y = ground - 18 -
               Math.sin(p * Math::PI) * (35 + i % 5 * 9) + p * 22
      chip.angle = i * 37 + p * side * 240
      chip.zoom_x = 0.35 + i % 3 * 0.16
      chip.zoom_y = chip.zoom_x
      chip.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 255).to_i : 0
    end

    #===========================================================================
    # 3. BÙNG NỔ — Lốc lá quấn quanh thân mục tiêu
    #===========================================================================
    g[:leaves].each_with_index do |leaf, i|
      q = (sec - 0.99 - i % 8 * 0.024) / 1.10
      p = a.clamp(q)
      theta = i * 2.399 + p * 12.0
      radius = 70 - Math.sin(p * Math::PI) * 27 + i % 4 * 5
      depth = Math.sin(theta)

      leaf.x = cx + Math.cos(theta) * radius
      leaf.y = cy + 45 - p * 105 + depth * 17
      leaf.z = depth > 0 ? 20_029 : 20_014
      leaf.angle = theta * 180 / Math::PI + 30
      leaf.zoom_x = 0.35 + i % 4 * 0.12
      leaf.zoom_y = leaf.zoom_x * (0.45 + depth.abs * 0.55)
      leaf.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 255).to_i : 0
    end

    # Ba nhát chém xen hướng, nhát cuối rộng hơn.
    g[:slashes].each_with_index do |slash, i|
      q = (sec - [1.35, 1.57, 1.79][i]) / 0.19
      p = a.clamp(q)
      direction = i == 1 ? -1 : 1

      slash.x = cx + direction * (-30 + p * 60)
      slash.y = cy + [12, -4, 6][i] - p * 12
      slash.angle = [-32, 38, -12][i]
      slash.mirror = i == 1
      slash.zoom_x = (0.65 + p * 0.45) * (i == 2 ? 1.18 : 1.0)
      slash.zoom_y = 0.65 + Math.sin(p * Math::PI) * 0.40
      slash.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 255).to_i : 0
    end

    # Vòng xung lực theo từng lần chém.
    g[:rings].each_with_index do |ring, i|
      q = (sec - [1.35, 1.57, 1.79][i]) / 0.30
      p = a.clamp(q)

      ring.x = cx
      ring.y = cy
      ring.zoom_x = 0.25 + p * 1.20
      ring.zoom_y = ring.zoom_x * 0.80
      ring.opacity = q.between?(0.0, 1.0) ?
        ((1.0 - p) * 180).to_i : 0
    end

    # Phản lực và ánh vàng trên chính mục tiêu.
    copy = g[:copy]
    copy.x = g[:base_x] + Math.sin(sec * 100) * impact * 7
    copy.y = g[:base_y] - grip * finish * 3

    if impact > 0
      copy.color = Color.new(255, 245, 164, (impact * 185).to_i)
    else
      shade = emergence * finish * 32
      copy.color = shade > 0 ?
        Color.new(39, 91, 32, shade.to_i) : g[:color]
    end
  end
end