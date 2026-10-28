#===============================================================================
# MUD BATH — Tắm bùn
# Yêu cầu: 000_AnimationCore.rb
# Thay thế registration :MUDBATH cũ.
#===============================================================================

KaitoAnimation.register(
  :MUDBATH,
  duration: 2.45,
  require_target: false,
  setup: proc do |a|
    #---------------------------------------------------------------------------
    # Âm thanh nhẹ, nhịp chậm
    #---------------------------------------------------------------------------
    a.sound_at(0.05, ["PRSFX- Mud Sport1"], 48, 90)
    a.sound_at(0.57, ["PRSFX- Mud Sport2"], 45, 110)
    a.sound_at(1.15, ["PRSFX- Aqua Ring1"], 35, 120)
    a.sound_at(1.43, ["PRSFX- Refresh"], 48, 110)
    a.sound_at(2.03, ["PRSFX- Aqua Ring2"], 30, 105)

    #---------------------------------------------------------------------------
    # Vũng bùn: viền be, lòng nâu vàng
    #---------------------------------------------------------------------------
    pool = a.bitmap(192, 72) do |b|
      72.times do |y|
        192.times do |x|
          dx = (x - 95.5) / 93.0
          dy = (y - 35.5) / 33.0
          r = dx * dx + dy * dy
          next if r > 1.0

          color =
            if r > 0.86
              Color.new(224, 199, 151, 225)
            elsif r > 0.69
              Color.new(167, 126, 76, 240)
            else
              Color.new(113, 79, 46, 240)
            end

          b.set_pixel(x, y, color)
        end
      end

      a.polygon(
        b,
        [[33, 31], [64, 21], [111, 19], [150, 27],
         [118, 25], [72, 27]],
        Color.new(196, 156, 102, 155)
      )
    end

    #---------------------------------------------------------------------------
    # Bùn phủ phần thân dưới: mặt trên nhấp nhô
    #---------------------------------------------------------------------------
    coat = a.bitmap(156, 58) do |b|
      outline = [
        [2, 43], [8, 29], [19, 25], [26, 30],
        [34, 21], [45, 19], [54, 25], [66, 17],
        [79, 16], [89, 22], [101, 18], [113, 23],
        [123, 20], [136, 26], [147, 30], [154, 43],
        [145, 52], [119, 57], [36, 57], [12, 51]
      ]
      a.polygon(b, outline, Color.new(225, 198, 150, 240))

      a.polygon(
        b,
        [[6, 43], [12, 32], [21, 30], [28, 35],
         [37, 26], [46, 24], [55, 30], [68, 22],
         [79, 21], [90, 27], [102, 23], [114, 28],
         [124, 25], [135, 31], [145, 34], [150, 43],
         [140, 49], [116, 53], [39, 53], [16, 48]],
        Color.new(140, 98, 54, 250)
      )

      a.polygon(
        b,
        [[18, 42], [44, 37], [69, 39], [94, 34],
         [124, 38], [142, 43], [114, 42], [85, 40],
         [59, 44], [33, 45]],
        Color.new(180, 137, 82, 200)
      )
    end

    #---------------------------------------------------------------------------
    # Bùn trào từ hai bên
    #---------------------------------------------------------------------------
    swell = a.bitmap(54, 68) do |b|
      a.polygon(
        b,
        [[2, 67], [5, 43], [11, 31], [13, 16],
         [20, 7], [29, 6], [37, 14], [39, 31],
         [47, 44], [52, 67]],
        Color.new(222, 193, 145, 240)
      )
      a.polygon(
        b,
        [[7, 67], [10, 44], [16, 33], [18, 18],
         [23, 12], [28, 12], [32, 18], [34, 33],
         [42, 47], [47, 67]],
        Color.new(145, 102, 56, 250)
      )
      a.polygon(
        b,
        [[18, 48], [21, 24], [25, 18], [27, 30],
         [25, 49]],
        Color.new(191, 148, 91, 220)
      )
    end

    #---------------------------------------------------------------------------
    # Giọt bùn có viền sáng
    #---------------------------------------------------------------------------
    drop = a.bitmap(16, 22) do |b|
      a.polygon(
        b,
        [[8, 1], [14, 11], [15, 16], [11, 21],
         [5, 21], [1, 16], [2, 11]],
        Color.new(226, 199, 151, 245)
      )
      a.polygon(
        b,
        [[8, 5], [11, 12], [12, 16], [9, 18],
         [6, 18], [4, 15], [5, 11]],
        Color.new(147, 103, 55, 255)
      )
    end

    #---------------------------------------------------------------------------
    # Bong bóng tròn, có phản sáng nhỏ
    #---------------------------------------------------------------------------
    bubble = a.bitmap(26, 26) do |b|
      26.times do |y|
        26.times do |x|
          dx = x - 12.5
          dy = y - 12.5
          r = Math.sqrt(dx * dx + dy * dy)
          next if r > 11.5

          color = r > 9.2 ?
            Color.new(235, 212, 171, 245) :
            Color.new(161, 119, 70, 220)

          b.set_pixel(x, y, color)
        end
      end

      b.fill_rect(7, 6, 5, 3, Color.new(255, 239, 202, 240))
      b.fill_rect(6, 9, 3, 3, Color.new(242, 220, 178, 210))
    end

    pop_ring = a.ring(13, Color.new(243, 220, 178, 235), 2)
    ripple = a.ring(65, Color.new(226, 204, 164, 220), 2)

    #---------------------------------------------------------------------------
    # Đốm sáng xanh lá / vàng ấm
    #---------------------------------------------------------------------------
    lights = [
      Color.new(179, 244, 130, 250),
      Color.new(255, 224, 145, 250)
    ].map do |color|
      a.bitmap(18, 18) do |b|
        a.polygon(
          b,
          [[9, 0], [11, 6], [17, 9], [11, 11],
           [9, 17], [6, 11], [0, 9], [6, 6]],
          color
        )
        b.fill_rect(7, 7, 4, 4, Color.new(255, 255, 225, 255))
      end
    end

    # Người dùng luôn có hiệu ứng.
    # Đồng minh đang có status cũng được tắm bùn.
    affected = ([a.user] + a.user.allAllies).select do |battler|
      next false if battler.fainted?
      next false if battler != a.user && battler.status == :NONE

      sprite = a.battler_sprite(battler)
      next false unless KaitoAnimation.valid_sprite?(sprite)
      next false unless sprite.visible && sprite.opacity > 0
      next false if battler.isCommander?
      next false if battler.respond_to?(:vanishMode) &&
                    battler.vanishMode > 0
      true
    end

    a[:groups] = affected.map do |battler|
      sprite = a.battler_sprite(battler)
      cx, cy = a.center(battler)
      ground = sprite.y +
               (sprite.src_rect.height - sprite.oy) * sprite.zoom_y
      height = sprite.src_rect.height * sprite.zoom_y.abs

      swells = Array.new(2) do
        s = a.sprite(swell, z: 20_022)
        s.ox = 27
        s.oy = 68
        s
      end

      cover = a.sprite(coat, z: 20_024)
      cover.ox = 78
      cover.oy = 58

      {
        x: cx, y: cy, ground: ground,
        cover_height: [[height * 0.32, 20].max, 43].min,
        pool: a.sprite(pool, z: 20_010),
        coat: cover,
        swells: swells,
        drops: Array.new(12) { a.sprite(drop, z: 20_026) },
        bubbles: Array.new(12) do
          {
            body: a.sprite(bubble, z: 20_028),
            pop: a.sprite(pop_ring, z: 20_029)
          }
        end,
        lights: Array.new(16) do |i|
          a.sprite(lights[i % 2], z: 20_032)
        end,
        ripples: Array.new(3) { a.sprite(ripple, z: 20_027) }
      }
    end
  end
) do |a, _t|
  sec = a.seconds

  # Courbe mềm khi bùn lan và rút.
  spread = a.clamp(sec / 0.45)
  spread = spread * spread * (3.0 - 2.0 * spread)

  drain = a.clamp((sec - 1.83) / 0.54)
  drain = drain * drain * (3.0 - 2.0 * drain)

  a[:groups].each do |g|
    cx = g[:x]
    ground = g[:ground]

    #===========================================================================
    # 1. TẠO VŨNG
    #===========================================================================
    pool = g[:pool]
    pool.x = cx
    pool.y = ground - 2
    pool.zoom_x = (0.25 + spread * 0.78) * (1.0 - drain * 0.68)
    pool.zoom_y = (0.40 + spread * 0.45) * (1.0 - drain * 0.62)
    pool.opacity = (spread * (1.0 - drain) * 240).to_i

    #===========================================================================
    # 2. TẮM BÙN — Hai bên trào lên, thân dưới được phủ bùn
    #===========================================================================
    rise = a.clamp((sec - 0.38) / 0.42)
    rise = rise * rise * (3.0 - 2.0 * rise)
    bath = rise * (1.0 - drain)

    cover = g[:coat]
    cover.x = cx
    cover.y = ground + 1
    cover.zoom_x = 0.76 + Math.sin(sec * 5.0) * 0.025 * bath
    cover.zoom_y = g[:cover_height] / 42.0 * bath
    cover.opacity = (bath * 245).to_i

    g[:swells].each_with_index do |swell, i|
      side = i == 0 ? -1 : 1
      q = a.clamp((sec - 0.40 - i * 0.10) / 0.92)
      pulse = Math.sin(q * Math::PI)

      swell.x = cx + side * (43 - pulse * 7)
      swell.y = ground
      swell.zoom_x = 0.55 + pulse * 0.12
      swell.zoom_y = pulse * 0.68
      swell.angle = side * pulse * 6
      swell.opacity = (pulse * 235).to_i
    end

    # Giọt bắn lên rồi rơi về vũng theo cung thấp.
    g[:drops].each_with_index do |drop, i|
      start = 0.62 + i % 6 * 0.075
      q = (sec - start) / 0.60
      p = a.clamp(q)
      side = i.even? ? -1 : 1

      drop.x = cx + side * (31 + p * (12 + i % 3 * 7))
      drop.y = ground - 5 -
               Math.sin(p * Math::PI) * (23 + i % 4 * 7)
      drop.angle = side * (-15 + p * 50)
      drop.zoom_x = 0.32 + i % 3 * 0.10
      drop.zoom_y = drop.zoom_x
      drop.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 245).to_i : 0
    end

    #===========================================================================
    # 3. BONG BÓNG NỔ — Co nhẹ rồi bung vòng nhỏ
    #===========================================================================
    starts = [
      0.20, 0.29, 0.40, 0.52, 0.69, 0.82,
      1.03, 1.15, 1.32, 1.50, 1.78, 1.88
    ]

    g[:bubbles].each_with_index do |entry, i|
      age = sec - starts[i]
      body = entry[:body]
      pop = entry[:pop]

      offset = Math.sin(i * 2.4) * (24 + i % 3 * 10)
      bx = cx + offset
      by = ground - 5 - i % 3 * 4
      size = 0.32 + i % 4 * 0.10

      # Nổi lên và phồng chậm.
      p = a.clamp(age / 0.38)
      body.x = bx + Math.sin(p * Math::PI) * 3
      body.y = by - p * (9 + i % 3 * 3)
      body.zoom_x = size * (0.35 + p * 0.65)
      body.zoom_y = body.zoom_x * (1.0 + Math.sin(p * Math::PI) * 0.13)
      body.opacity = age.between?(0.0, 0.40) ?
        (a.clamp(age / 0.08) * 240).to_i : 0

      # “Bụp”: vòng be mở nhanh và tan.
      burst = (age - 0.40) / 0.16
      bp = a.clamp(burst)
      pop.x = bx
      pop.y = by - (9 + i % 3 * 3)
      pop.zoom_x = size * (0.80 + bp * 1.5)
      pop.zoom_y = pop.zoom_x * (1.0 - bp * 0.35)
      pop.opacity = burst.between?(0.0, 1.0) ?
        ((1.0 - bp) * 220).to_i : 0
    end

    # Đốm sáng ấm bay nhẹ lên sau khi bong bóng bắt đầu vỡ.
    g[:lights].each_with_index do |light, i|
      start = 0.98 + i % 8 * 0.07
      q = (sec - start) / 0.86
      p = a.clamp(q)

      light.x = cx + Math.sin(i * 2.4) * 38 +
                Math.sin(p * Math::PI * 1.5 + i) * 7
      light.y = ground - 10 - p * (45 + i % 4 * 13)
      light.angle = p * 55 + i * 23
      light.zoom_x = 0.28 + i % 3 * 0.13 +
                     Math.sin(p * Math::PI) * 0.12
      light.zoom_y = light.zoom_x
      light.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 230).to_i : 0
    end

    #===========================================================================
    # 4. KẾT THÚC — Bùn rút, gợn tròn lan nhẹ
    #===========================================================================
    g[:ripples].each_with_index do |ripple, i|
      q = (sec - 1.78 - i * 0.13) / 0.40
      p = a.clamp(q)

      ripple.x = cx
      ripple.y = ground - 2
      ripple.zoom_x = 0.24 + p * 0.80
      ripple.zoom_y = ripple.zoom_x * 0.27
      ripple.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 185).to_i : 0
    end
  end
end