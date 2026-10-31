#===============================================================================
# SAPPY SEED — Giant Stalk
# Yêu cầu: 000_AnimationCore.rb
# Thay toàn bộ animation Sappy Seed cũ.
#===============================================================================

module KaitoSappyStalk
  module_function

  def line(a, bitmap, p1, p2, color, width)
    dx = p2[0] - p1[0]
    dy = p2[1] - p1[1]
    length = Math.sqrt(dx * dx + dy * dy)
    return if length < 0.1

    nx = -dy / length * width / 2.0
    ny = dx / length * width / 2.0
    a.polygon(
      bitmap,
      [[p1[0] + nx, p1[1] + ny],
       [p2[0] + nx, p2[1] + ny],
       [p2[0] - nx, p2[1] - ny],
       [p1[0] - nx, p1[1] - ny]],
      color
    )
  end

  def stalk_point(g, t, load, strike)
    side = g[:side]
    x0 = g[:x] - side * 43
    y0 = g[:floor]

    x1 = g[:x] - side * (67 + load * 21) + side * strike * 24
    y1 = g[:floor] - g[:height] * 0.68

    x2 = g[:x] + side * (-27 - load * 13 + strike * 87)
    y2 = g[:floor] - g[:height] +
         strike * (g[:height] - (g[:floor] - g[:y]) + 7)

    q = 1.0 - t
    [
      q * q * x0 + 2 * q * t * x1 + t * t * x2,
      q * q * y0 + 2 * q * t * y1 + t * t * y2
    ]
  end

  module SceneHooks
    def pbAnimation(move_id, user, targets, hit_num = 0)
      return super unless move_id == :SAPPYSEED
      viewport = @viewport
      return super unless viewport && !viewport.disposed?

      old_x = viewport.ox
      old_y = viewport.oy
      begin
        super
      ensure
        unless viewport.disposed?
          viewport.ox = old_x
          viewport.oy = old_y
        end
      end
    end
  end
end

KaitoAnimation.register(
  :SAPPYSEED,
  duration: 2.60,
  setup: proc do |a|
    a.sound_at(0.03, ["PRSFX- Bullet Seed"], 55, 100)
    a.sound_at(0.43, ["PRSFX- Leech Seed1"], 65, 85)
    a.sound_at(0.61, ["PRSFX- Frenzy Plant1"], 65, 110)
    a.sound_at(1.00, ["PRSFX- Power Whip"], 85, 95)
    a.sound_at(1.45, ["PRSFX- Leech Seed2"], 55, 110)

    a[:origin] = a.center

    #---------------------------------------------------------------------------
    # Hạt lớn, vỏ vàng nâu và sống hạt sáng
    #---------------------------------------------------------------------------
    seed = a.bitmap(38, 52) do |b|
      a.polygon(
        b,
        [[19, 1], [31, 9], [37, 27], [28, 45],
         [16, 51], [5, 39], [1, 23], [8, 7]],
        Color.new(113, 77, 35, 255)
      )
      a.polygon(
        b,
        [[18, 6], [26, 12], [30, 27], [23, 40],
         [16, 44], [9, 35], [6, 23], [11, 12]],
        Color.new(209, 167, 78, 255)
      )
      a.polygon(
        b,
        [[19, 7], [21, 23], [16, 43], [13, 36], [16, 23]],
        Color.new(255, 232, 146, 250)
      )
    end

    # Hai mảnh vỏ tách ra khi nảy mầm.
    shells = [
      [[18, 2], [8, 7], [1, 23], [5, 39], [16, 50],
       [12, 34], [17, 23]],
      [[20, 2], [31, 9], [37, 27], [28, 45], [18, 50],
       [23, 32], [19, 22]]
    ].map do |points|
      a.bitmap(38, 52) do |b|
        a.polygon(b, points, Color.new(193, 146, 67, 255))
      end
    end

    #---------------------------------------------------------------------------
    # Lá lớn hai mặt
    #---------------------------------------------------------------------------
    leaf = a.bitmap(58, 34) do |b|
      a.polygon(
        b,
        [[1, 29], [10, 10], [30, 1], [57, 3],
         [47, 23], [27, 33]],
        Color.new(55, 121, 40, 255)
      )
      a.polygon(
        b,
        [[5, 27], [17, 13], [34, 6], [52, 6],
         [39, 20], [22, 27]],
        Color.new(123, 185, 65, 255)
      )
      a.polygon(
        b,
        [[3, 28], [29, 15], [55, 5], [31, 19]],
        Color.new(209, 233, 130, 250)
      )
    end

    chip = a.bitmap(16, 24) do |b|
      a.polygon(
        b,
        [[3, 4], [12, 0], [15, 15], [8, 23], [1, 15]],
        Color.new(137, 102, 47, 250)
      )
      a.polygon(
        b,
        [[5, 6], [10, 3], [11, 15], [7, 19]],
        Color.new(217, 180, 96, 245)
      )
    end

    # Chồi ký sinh nhỏ.
    sprout = a.bitmap(46, 58) do |b|
      a.polygon(
        b,
        [[21, 57], [21, 32], [28, 17], [31, 18],
         [25, 34], [25, 57]],
        Color.new(96, 146, 43, 250)
      )
      a.polygon(
        b,
        [[23, 35], [10, 31], [1, 16], [17, 18], [26, 29]],
        Color.new(135, 186, 64, 255)
      )
      a.polygon(
        b,
        [[27, 24], [31, 10], [45, 2], [41, 19], [29, 29]],
        Color.new(176, 216, 96, 255)
      )
    end

    ring = a.ring(61, Color.new(221, 235, 150, 235), 3)

    a[:back_bitmap] = a.bitmap(Graphics.width, Graphics.height)
    a[:front_bitmap] = a.bitmap(Graphics.width, Graphics.height)
    a[:back] = a.sprite(a[:back_bitmap], z: 20_014, centered: false)
    a[:front] = a.sprite(a[:front_bitmap], z: 20_026, centered: false)

    a[:groups] = a.targets.map do |target|
      original = a.battler_sprite(target)
      cx, cy = a.center(target)
      floor = original.y +
              (original.src_rect.height - original.oy) * original.zoom_y
      visible_height = original.src_rect.height * original.zoom_y.abs
      body = a.copy(target, hide_original: true, z: 20_019)

      can_seed = !target.pbHasType?(:GRASS) &&
                 target.effects[PBEffects::LeechSeed] < 0 &&
                 target.effects[PBEffects::Substitute] <= 0

      {
        x: cx, y: cy, floor: floor,
        side: cx >= a[:origin][0] ? 1 : -1,
        height: [[visible_height * 1.4 + 45, 145].max,
                 [floor - 18, 90].max].min,
        body: body,
        base_x: body.x, base_y: body.y,
        color: body.color.clone,
        seed: a.sprite(seed, z: 20_028),
        shells: shells.map { |bitmap| a.sprite(bitmap, z: 20_029) },
        bud: a.sprite(seed, z: 20_028),
        leaves: Array.new(6) { a.sprite(leaf, z: 20_027) },
        flying_leaves: Array.new(30) { a.sprite(leaf, z: 20_034) },
        chips: Array.new(18) { a.sprite(chip, z: 20_032) },
        rings: Array.new(2) { a.sprite(ring, z: 20_031) },
        can_seed: can_seed,
        planted_seeds: Array.new(9) { a.sprite(seed, z: 20_033) },
        sprouts: Array.new(3) do
          s = a.sprite(sprout, z: 20_025)
          s.ox = 23
          s.oy = 58
          s
        end
      }
    end

    viewport = a.instance_variable_get(:@viewport)
    a[:viewport] = viewport
    a[:camera_x] = viewport.ox
    a[:camera_y] = viewport.oy
  end
) do |a, _t|
  sec = a.seconds
  ux, uy = a[:origin]
  back = a[:back_bitmap]
  front = a[:front_bitmap]
  back.clear
  front.clear
  a[:back].opacity = 255
  a[:front].opacity = 255

  a[:groups].each do |g|
    cx = g[:x]
    cy = g[:y]
    floor = g[:floor]
    side = g[:side]
    base_x = cx - side * 43

    #=============================================================================
    # 1. HẠT GIỐNG LỚN GIÁNG XUỐNG RỒI NỨT VỎ
    #=============================================================================
    q = (sec - 0.05) / 0.38
    p = a.clamp(q)
    seed = g[:seed]
    seed.x = a.lerp(ux, base_x, p)
    seed.y = a.lerp(uy, floor - 7, p) -
             Math.sin(p * Math::PI) * 38
    seed.angle = side * p * 210
    seed.zoom_x = 0.85
    seed.zoom_y = 0.85
    seed.opacity = q.between?(0.0, 1.0) ? 255 : 0

    g[:shells].each_with_index do |shell, i|
      q = (sec - 0.43) / 0.35
      p = a.clamp(q)
      direction = i == 0 ? -1 : 1

      shell.x = base_x + direction * p * 22
      shell.y = floor - 8 - Math.sin(p * Math::PI) * 16 + p * p * 9
      shell.angle = direction * p * 75
      shell.zoom_x = 0.85
      shell.zoom_y = 0.85
      shell.opacity = q.between?(0.0, 1.0) ?
        ((1.0 - p) * 245).to_i : 0
    end

    #=============================================================================
    # 2. THÂN CÂY MỌC BẬT LÊN, UỐN LẤY ĐÀ RỒI QUẬT
    #=============================================================================
    grow = a.clamp((sec - 0.44) / 0.29)
    grow = 1.0 - (1.0 - grow)**3

    load = a.clamp((sec - 0.73) / 0.18)
    strike = a.clamp((sec - 0.92) / 0.15)
    strike = strike * strike

    retreat = a.clamp((sec - 1.30) / 0.34)
    length = grow * (1.0 - retreat)
    opacity = (1.0 - retreat) * 255
    canvas = strike > 0.18 ? front : back

    if length > 0
      points = Array.new(25) do |i|
        t = length * i / 24.0
        KaitoSappyStalk.stalk_point(g, t, load, strike)
      end

      points.each_cons(2).with_index do |(p1, p2), i|
        u = i / 24.0
        width = 31 - u * 17

        KaitoSappyStalk.line(
          a, canvas, p1, p2,
          Color.new(48, 89, 31, opacity.to_i), width
        )
        KaitoSappyStalk.line(
          a, canvas, p1, p2,
          Color.new(118, 167, 54, opacity.to_i), width * 0.64
        )
        KaitoSappyStalk.line(
          a, canvas,
          [p1[0] - 2, p1[1]], [p2[0] - 2, p2[1]],
          Color.new(208, 219, 112, (opacity * 0.80).to_i),
          width * 0.15
        )
      end

      # Rễ lớn bám đất để cú quật có điểm tựa.
      4.times do |i|
        direction = i.even? ? -1 : 1
        reach = grow * (25 + i * 7)
        p1 = [base_x, floor]
        p2 = [base_x + direction * reach, floor + 3 + i * 2]
        KaitoSappyStalk.line(
          a, back, p1, p2,
          Color.new(113, 135, 55, (opacity * 0.85).to_i), 5
        )
      end
    end

    # Lá gắn trực tiếp vào thân cây và đổi góc theo đường cong.
    g[:leaves].each_with_index do |leaf, i|
      u = 0.24 + i * 0.115
      point = KaitoSappyStalk.stalk_point(g, u, load, strike)
      next_point = KaitoSappyStalk.stalk_point(
        g, [u + 0.025, 1.0].min, load, strike
      )
      angle = -Math.atan2(
        next_point[1] - point[1],
        next_point[0] - point[0]
      ) * 180 / Math::PI

      leaf.x = point[0]
      leaf.y = point[1]
      leaf.ox = 3
      leaf.oy = 28
      leaf.angle = angle + (i.even? ? 35 : -65)
      leaf.mirror = i.odd?
      leaf.zoom_x = 0.65 + i % 3 * 0.15
      leaf.zoom_y = leaf.zoom_x
      leaf.z = strike > 0.18 ? 20_028 : 20_015
      leaf.opacity = u <= length ? opacity.to_i : 0
    end

    # Búp hạt ở đầu thân cây.
    tip = KaitoSappyStalk.stalk_point(g, length, load, strike)
    bud = g[:bud]
    bud.x = tip[0]
    bud.y = tip[1]
    bud.angle = side * (load * 15 - strike * 65)
    bud.zoom_x = 0.45 + grow * 0.50
    bud.zoom_y = bud.zoom_x
    bud.opacity = (grow * (1.0 - retreat) * 250).to_i

    #=============================================================================
    # 3. VA CHẠM — PHẢN LỰC, LÁ VÀ MẢNH VỎ CÂY
    #=============================================================================
    age = sec - 1.02
    flash = age.between?(0.0, 0.16) ? 1.0 - age / 0.16 : 0.0
    recoil = a.clamp(age / 0.035) *
             a.clamp((0.30 - age) / 0.24)

    g[:body].x = g[:base_x] + side * recoil * 9
    g[:body].y = g[:base_y] - recoil * 3
    g[:body].color = flash > 0 ?
      Color.new(236, 248, 190, (flash * 195).to_i) : g[:color]

    g[:rings].each_with_index do |ring, i|
      q = (sec - 1.02 - i * 0.05) / 0.37
      p = a.clamp(q)
      ring.x = cx
      ring.y = cy
      ring.zoom_x = 0.12 + p * (i == 0 ? 1.45 : 1.10)
      ring.zoom_y = ring.zoom_x * (i == 0 ? 0.80 : 0.45)
      ring.opacity = q.between?(0.0, 1.0) ?
        ((1.0 - p) * 225).to_i : 0
    end

    g[:flying_leaves].each_with_index do |leaf, i|
      q = (sec - 1.02 - i % 4 * 0.014) / 0.74
      p = a.clamp(q)
      theta = i * 2.399
      spread = 1.0 - (1.0 - p)**3
      radius = 25 + i % 6 * 12

      leaf.x = cx + Math.cos(theta) * spread * radius
      leaf.y = cy + Math.sin(theta) * spread * radius * 0.65 +
               p * p * 34
      leaf.angle = i * 31 + p * (i.even? ? 180 : -180)
      leaf.zoom_x = 0.25 + i % 4 * 0.10
      leaf.zoom_y = leaf.zoom_x
      leaf.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 245).to_i : 0
    end

    g[:chips].each_with_index do |chip, i|
      q = (sec - 1.03 - i % 3 * 0.02) / 0.55
      p = a.clamp(q)
      theta = i * 2.399 + 0.7

      chip.x = cx + Math.cos(theta) * p * (35 + i % 4 * 12)
      chip.y = cy + Math.sin(theta) * p * 30 + p * p * 48
      chip.angle = i * 37 + p * 230
      chip.zoom_x = 0.28 + i % 3 * 0.10
      chip.zoom_y = chip.zoom_x
      chip.opacity = q.between?(0.0, 1.0) ?
        ((1.0 - p) * 235).to_i : 0
    end

    #=============================================================================
    # 4. KÝ SINH — HẠT RƠI XUỐNG RỒI BÉN RỄ
    #=============================================================================
    g[:planted_seeds].each_with_index do |seedling, i|
      q = (sec - 1.23 - i * 0.025) / 0.48
      p = a.clamp(q)
      spread = Math.sin(i * 2.399)

      seedling.x = cx + spread * (10 + p * 32)
      seedling.y = cy + p * (floor - cy - 4) -
                    Math.sin(p * Math::PI) * 18
      seedling.angle = i * 31 + p * spread * 130
      seedling.zoom_x = 0.20 + i % 3 * 0.045
      seedling.zoom_y = seedling.zoom_x
      seedling.opacity = g[:can_seed] && q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 240).to_i : 0
    end

    fade = a.clamp((2.60 - sec) / 0.34)
    g[:sprouts].each_with_index do |sprout, i|
      grow = a.clamp((sec - 1.65 - i * 0.09) / 0.26)
      sprout.x = cx + [-28, 0, 28][i]
      sprout.y = floor + [0, 5, 1][i]
      sprout.zoom_x = 0.56 + i % 2 * 0.12
      sprout.zoom_y = sprout.zoom_x * grow
      sprout.angle = Math.sin(sec * 4 + i) * grow * 4
      sprout.opacity = g[:can_seed] ?
        (grow * fade * 240).to_i : 0
    end
  end

  # Rung một nhịp đúng lúc thân cây quật trúng.
  viewport = a[:viewport]
  unless viewport.disposed?
    age = sec - 1.02
    shake = age.between?(0.0, 0.20) ?
      (1.0 - age / 0.20)**2 : 0.0
    viewport.ox = a[:camera_x] + Math.sin(age * 125) * shake * 7
    viewport.oy = a[:camera_y] + Math.cos(age * 100) * shake * 3
  end
end

unless Battle::Scene.ancestors.include?(KaitoSappyStalk::SceneHooks)
  Battle::Scene.prepend(KaitoSappyStalk::SceneHooks)
end