#===============================================================================
# DRAIN BRAIN — Rút cạn trí lực
# Yêu cầu: 000_AnimationCore.rb
#===============================================================================

module KaitoDrainBrainVisual
  module_function

  def line(a, bitmap, p1, p2, color, thickness = 2)
    dx = p2[0] - p1[0]
    dy = p2[1] - p1[1]
    length = Math.sqrt(dx * dx + dy * dy)
    return if length < 0.1

    nx = -dy / length * thickness / 2.0
    ny = dx / length * thickness / 2.0

    a.polygon(
      bitmap,
      [[p1[0] + nx, p1[1] + ny],
       [p2[0] + nx, p2[1] + ny],
       [p2[0] - nx, p2[1] - ny],
       [p1[0] - nx, p1[1] - ny]],
      color
    )
  end

  # Hướng luôn từ đầu mục tiêu về người dùng.
  def path(a, g, progress, arm = nil)
    dx = a[:ux] - g[:hx]
    dy = a[:uy] - g[:hy]
    length = [Math.sqrt(dx * dx + dy * dy), 1.0].max

    arch = Math.sin(progress * Math::PI)
    cross = arm.nil? ? 0.0 :
      Math.cos(progress * Math::PI * 2 + arm * Math::PI) * arch * 16

    [
      g[:hx] + dx * progress - dy / length * cross,
      g[:hy] + dy * progress - arch * 24 + dx / length * cross
    ]
  end
end

KaitoAnimation.register(
  :DRAINBRAIN,
  duration: 2.50,
  setup: proc do |a|
    a.sound_at(0.03, ["PRSFX- Confuse Ray"], 45, 85)
    a.sound_at(0.57, ["PRSFX- Absorb1"], 55, 95)
    a.sound_at(1.05, ["PRSFX- Absorb1"], 50, 110)
    a.sound_at(1.57, ["PRSFX- Absorb2"], 55, 115)
    a.sound_at(1.98, ["PRSFX- Recover"], 45, 120)

    ux, uy = a.center
    a[:ux] = ux
    a[:uy] = uy

    user_copy = a.copy(a.user, hide_original: true, z: 20_018)
    a[:user_copy] = user_copy
    a[:user_color] = user_copy.color.clone

    #---------------------------------------------------------------------------
    # Bộ não ánh sáng: hai bán cầu có các nếp gấp
    #---------------------------------------------------------------------------
    brain = a.bitmap(100, 80) do |b|
      circles = [
        [28, 23, 13], [41, 17, 12],
        [59, 17, 12], [73, 24, 13],
        [20, 39, 13], [35, 39, 16],
        [61, 39, 16], [80, 40, 12],
        [29, 54, 13], [42, 56, 12], [64, 55, 14]
      ]

      # Vẽ bằng các hàng ngang, tránh duyệt pixel toàn màn hình.
      fill_circle = proc do |cx, cy, radius, color|
        (-radius..radius).each do |dy|
          half = Math.sqrt([radius * radius - dy * dy, 0].max).floor
          b.fill_rect(cx - half, cy + dy, half * 2 + 1, 1, color)
        end
      end

      circles.each do |x, y, radius|
        fill_circle.call(x, y, radius, Color.new(219, 151, 243, 245))
      end
      circles.each do |x, y, radius|
        fill_circle.call(x, y, radius - 3, Color.new(128, 62, 169, 225))
      end

      # Khe giữa hai bán cầu.
      a.polygon(
        b,
        [[49, 7], [52, 9], [50, 25], [53, 37],
         [50, 49], [52, 63], [48, 67], [47, 49],
         [49, 37], [46, 24]],
        Color.new(64, 30, 101, 245)
      )

      folds = [
        [[27, 14], [24, 24], [33, 30], [31, 40]],
        [[40, 13], [38, 23], [43, 30]],
        [[14, 35], [24, 33], [29, 42], [22, 48]],
        [[32, 48], [39, 44], [44, 52], [39, 61]],
        [[62, 12], [65, 22], [58, 30]],
        [[76, 19], [73, 30], [65, 34], [69, 42]],
        [[83, 38], [75, 41], [73, 51], [65, 57]],
        [[57, 42], [61, 48], [57, 60]]
      ]

      folds.each do |points|
        points.each_cons(2) do |p1, p2|
          KaitoDrainBrainVisual.line(
            a, b, p1, p2, Color.new(242, 186, 252, 235), 2
          )
        end
      end

      a.polygon(
        b,
        [[45, 62], [55, 62], [57, 73], [50, 77], [45, 72]],
        Color.new(204, 137, 232, 240)
      )
    end

    #---------------------------------------------------------------------------
    # Đốm năng lượng có quầng mềm
    #---------------------------------------------------------------------------
    energy = a.bitmap(36, 36) do |b|
      36.times do |y|
        36.times do |x|
          r = Math.sqrt((x - 17.5)**2 + (y - 17.5)**2) / 17.0
          next if r > 1.0
          b.set_pixel(
            x, y,
            Color.new(205, 112, 231, ((1.0 - r)**2 * 180).to_i)
          )
        end
      end

      a.polygon(
        b,
        [[18, 9], [24, 17], [20, 25], [13, 23], [11, 16]],
        Color.new(235, 177, 249, 245)
      )
      b.fill_rect(16, 14, 4, 6, Color.new(255, 242, 255, 250))
    end

    sparkle = a.bitmap(18, 18) do |b|
      a.polygon(
        b,
        [[9, 0], [11, 6], [18, 9], [11, 11],
         [9, 18], [6, 11], [0, 9], [6, 6]],
        Color.new(255, 230, 162, 245)
      )
      b.fill_rect(7, 7, 4, 4, Color.new(255, 255, 233, 255))
    end

    lock_ring = a.ring(53, Color.new(210, 130, 234, 230), 2)
    heal_ring = a.ring(53, Color.new(255, 190, 220, 235), 3)

    a[:heal_rings] = Array.new(2) do
      a.sprite(heal_ring, z: 20_030)
    end
    a[:heal_sparks] = Array.new(22) do
      a.sprite(sparkle, z: 20_033)
    end

    a[:link_bitmap] = a.bitmap(Graphics.width, Graphics.height)
    a[:link] = a.sprite(
      a[:link_bitmap], z: 20_023, centered: false
    )

    a[:groups] = a.targets.map do |target|
      original = a.battler_sprite(target)
      cx, cy = a.center(target)
      visible_height = original.src_rect.height * original.zoom_y.abs

      # Mốc hút đặt ở vùng đầu, biểu tượng nằm phía trên.
      head_y = [cy - visible_height * 0.30, 29].max
      body = a.copy(target, hide_original: true, z: 20_018)

      {
        x: cx, y: cy,
        hx: cx, hy: head_y,
        brain_y: [head_y - 24, 35].max,
        body: body,
        color: body.color.clone,
        brain: a.sprite(brain, z: 20_028),
        rings: Array.new(2) { a.sprite(lock_ring, z: 20_027) },
        orbs: Array.new(22) do
          {
            head: a.sprite(energy, z: 20_031),
            tail: Array.new(3) { a.sprite(energy, z: 20_029) }
          }
        end
      }
    end
  end
) do |a, _t|
  sec = a.seconds
  link_canvas = a[:link_bitmap]
  link_canvas.clear
  a[:link].opacity = 255

  a[:groups].each do |g|
    #=============================================================================
    # 1. KHÓA TÂM TRÍ — Biểu tượng não và hai vòng co vào
    #=============================================================================
    appear = a.clamp(sec / 0.25)
    drain = a.clamp((sec - 0.60) / 1.18)
    shrink = a.clamp((sec - 1.80) / 0.35)
    brain_fade = a.clamp((2.17 - sec) / 0.28)

    pulse = 0.0
    [0.65, 0.98, 1.31, 1.64].each do |time|
      age = sec - time
      if age.between?(0.0, 0.18)
        pulse = [pulse, Math.sin(age / 0.18 * Math::PI)].max
      end
    end

    brain = g[:brain]
    brain.x = g[:hx]
    brain.y = g[:brain_y]
    brain.zoom_x = (0.52 + appear * 0.12 + pulse * 0.035) *
                   (1.0 - shrink * 0.78)
    brain.zoom_y = brain.zoom_x
    brain.color = Color.new(255, 205, 255, (pulse * 110).to_i)
    brain.opacity = (
      appear * brain_fade * (245 - drain * 105 + pulse * 15)
    ).to_i

    g[:rings].each_with_index do |ring, i|
      q = (sec - 0.05 - i * 0.13) / 0.49
      p = a.clamp(q)

      ring.x = g[:hx]
      ring.y = g[:brain_y]
      ring.zoom_x = 1.15 - p * 0.71
      ring.zoom_y = ring.zoom_x * (i == 0 ? 0.65 : 1.0)
      ring.angle = i == 0 ? 15 : -18
      ring.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 220).to_i : 0
    end

    # Mục tiêu chớp tím nhẹ theo từng nhịp rút.
    g[:body].color = pulse > 0 ?
      Color.new(156, 76, 194, (pulse * 85).to_i) : g[:color]

    #=============================================================================
    # 2. LIÊN KẾT TÂM LINH MẢNH, GIỮ TRONG SUỐT QUÁ TRÌNH HÚT
    #=============================================================================
    link_alpha = a.clamp((sec - 0.43) / 0.18) *
                 a.clamp((2.18 - sec) / 0.29)

    if link_alpha > 0
      28.times do |i|
        t1 = i / 28.0
        t2 = (i + 1) / 28.0
        p1 = KaitoDrainBrainVisual.path(a, g, t1)
        p2 = KaitoDrainBrainVisual.path(a, g, t2)

        color = Color.new(
          207 + (t1 * 42).to_i,
          128 + (t1 * 55).to_i,
          231 - (t1 * 30).to_i,
          (link_alpha * 115).to_i
        )
        KaitoDrainBrainVisual.line(
          a, link_canvas, p1, p2, color, 1.5
        )
      end
    end

    #=============================================================================
    # 3. HAI LUỒNG ĐAN NHAU — Giằng nhẹ rồi tăng tốc về người dùng
    #=============================================================================
    g[:orbs].each_with_index do |entry, i|
      start = 0.59 + i * 0.038
      duration = i % 4 == 0 ? 0.76 : 0.66
      q = (sec - start) / duration
      progress = a.clamp(q)

      # Một số đốm bị giằng lại tại đầu mục tiêu trước khi bị kéo đi.
      if i % 4 == 0
        if progress < 0.22
          travel = Math.sin(progress / 0.22 * Math::PI) * 0.035
        else
          travel = ((progress - 0.22) / 0.78)**1.65
        end
      else
        travel = progress**1.65
      end

      arm = i % 2
      pos = KaitoDrainBrainVisual.path(a, g, travel, arm)
      active = q.between?(0.0, 1.0)

      orb = entry[:head]
      orb.x = pos[0]
      orb.y = pos[1]
      orb.zoom_x = 0.39 + i % 3 * 0.095
      orb.zoom_y = orb.zoom_x
      orb.color = Color.new(
        255, 210, 148, (a.clamp((travel - 0.48) / 0.52) * 170).to_i
      )
      orb.opacity = active ?
        (Math.sin(progress * Math::PI) * 250).to_i : 0

      # Các đốm nhỏ xoắn quanh đường đi tạo đuôi năng lượng.
      entry[:tail].each_with_index do |tail, j|
        tail_progress = [travel - (j + 1) * 0.035, 0.0].max
        tail_pos = KaitoDrainBrainVisual.path(a, g, tail_progress, arm)
        twist = travel * Math::PI * 14 + j * 1.8 + i

        tail.x = tail_pos[0] + Math.cos(twist) * (3 + j)
        tail.y = tail_pos[1] + Math.sin(twist) * (3 + j)
        tail.zoom_x = 0.20 - j * 0.035
        tail.zoom_y = tail.zoom_x
        tail.color = orb.color
        tail.opacity = active && travel > 0.025 ?
          (orb.opacity * (0.65 - j * 0.15)).to_i : 0
      end
    end
  end

  #=============================================================================
  # 4. HẤP THỤ — Vòng hồng ấm và ánh vàng nâng lên
  #=============================================================================
  warmth = a.clamp((sec - 1.12) / 0.32) *
           a.clamp((2.45 - sec) / 0.40)
  a[:user_copy].color = warmth > 0 ?
    Color.new(255, 217, 195, (warmth * 60).to_i) : a[:user_color]

  a[:heal_rings].each_with_index do |ring, i|
    q = (sec - 1.35 - i * 0.25) / 0.69
    p = a.clamp(q)

    ring.x = a[:ux]
    ring.y = a[:uy]
    ring.zoom_x = 0.20 + p * 1.13
    ring.zoom_y = ring.zoom_x * 0.82
    ring.opacity = q.between?(0.0, 1.0) ?
      (Math.sin(p * Math::PI) * 205).to_i : 0
  end

  a[:heal_sparks].each_with_index do |spark, i|
    q = (sec - 1.39 - i % 7 * 0.045) / 0.73
    p = a.clamp(q)

    spark.x = a[:ux] + Math.sin(i * 2.399) * (17 + i % 3 * 8) +
              Math.sin(p * 3 + i) * 4
    spark.y = a[:uy] + 28 - p * (47 + i % 4 * 11)
    spark.angle = i * 29 + p * 45
    spark.zoom_x = 0.19 + i % 3 * 0.10
    spark.zoom_y = spark.zoom_x
    spark.opacity = q.between?(0.0, 1.0) ?
      (Math.sin(p * Math::PI) * 235).to_i : 0
  end
end