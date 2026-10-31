#===============================================================================
# FREEZY FROST — Crystal Break
# Yêu cầu: 000_AnimationCore.rb
# Thay toàn bộ animation Freezy Frost cũ.
#===============================================================================

module KaitoFreezyCrystal
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

  module SceneHooks
    def pbAnimation(move_id, user, targets, hit_num = 0)
      return super unless move_id == :FREEZYFROST
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
  :FREEZYFROST,
  duration: 3.00,
  setup: proc do |a|
    a.sound_at(0.03, ["PRSFX- Icy Wind1"], 55, 90)
    a.sound_at(0.29, ["PRSFX- Icy Wind2"], 75, 115)
    a.sound_at(0.86, ["PRSFX- Icicle Crash1"], 65, 115)
    a.sound_at(1.18, ["PRSFX- Ice Beam"], 55, 130)
    a.sound_at(1.70, ["PRSFX- Icicle Crash2"], 85, 110)
    a.sound_at(1.74, ["PRSFX- Ice Shard"], 70, 120)
    a.sound_at(2.12, ["PRSFX- Haze"], 50, 110)

    a[:origin] = a.center
    a[:copies] = {}

    copy_for = proc do |battler|
      a[:copies][battler.index] ||= a.copy(
        battler, hide_original: true, z: 20_020
      )
    end

    #---------------------------------------------------------------------------
    # Sương có tâm mềm, rìa trong suốt
    #---------------------------------------------------------------------------
    mist = a.bitmap(80, 64) do |b|
      64.times do |y|
        80.times do |x|
          r = Math.sqrt(
            ((x - 39.5) / 39.0)**2 +
            ((y - 31.5) / 31.0)**2
          )
          next if r > 1.0
          b.set_pixel(
            x, y,
            Color.new(207, 238, 250, ((1.0 - r)**1.5 * 165).to_i)
          )
        end
      end
    end

    #---------------------------------------------------------------------------
    # Phiến băng lớn: cạnh sáng, mặt cyan và bóng lavender
    #---------------------------------------------------------------------------
    plate = a.bitmap(42, 144) do |b|
      a.polygon(
        b,
        [[20, 0], [39, 32], [35, 125], [21, 143],
         [5, 127], [1, 34]],
        Color.new(156, 214, 242, 205)
      )
      a.polygon(
        b,
        [[20, 5], [20, 136], [9, 124], [5, 35]],
        Color.new(236, 254, 255, 230)
      )
      a.polygon(
        b,
        [[22, 8], [34, 34], [30, 122], [22, 134]],
        Color.new(155, 171, 225, 155)
      )
      a.polygon(
        b,
        [[11, 39], [17, 27], [17, 100], [12, 119]],
        Color.new(255, 255, 255, 185)
      )
    end

    shard = a.bitmap(24, 38) do |b|
      a.polygon(
        b,
        [[11, 0], [23, 12], [17, 31], [7, 37], [1, 15]],
        Color.new(189, 233, 250, 245)
      )
      a.polygon(
        b,
        [[11, 4], [11, 29], [6, 31], [4, 16]],
        Color.new(250, 255, 255, 255)
      )
      a.polygon(
        b,
        [[13, 6], [19, 13], [14, 27]],
        Color.new(151, 176, 230, 230)
      )
    end

    #---------------------------------------------------------------------------
    # Tinh thể tuyết nhỏ
    #---------------------------------------------------------------------------
    snow = a.bitmap(36, 36) do |b|
      6.times do |i|
        theta = i * Math::PI / 3
        p1 = [18, 18]
        p2 = [18 + Math.cos(theta) * 16,
              18 + Math.sin(theta) * 16]

        KaitoFreezyCrystal.line(
          a, b, p1, p2, Color.new(231, 252, 255, 245), 2
        )
        joint = [18 + Math.cos(theta) * 10,
                 18 + Math.sin(theta) * 10]

        [-1, 1].each do |side|
          angle = theta + Math::PI + side * 0.85
          tip = [joint[0] + Math.cos(angle) * 6,
                 joint[1] + Math.sin(angle) * 6]
          KaitoFreezyCrystal.line(
            a, b, joint, tip, Color.new(220, 247, 255, 235), 1.5
          )
        end
      end
    end

    # Các vệt chỉ số, được bạc màu ở cuối.
    stat_bitmaps = [
      [242, 123, 144],
      [109, 171, 245]
    ].map do |rgb|
      a.bitmap(18, 42) do |b|
        a.polygon(
          b,
          [[9, 0], [16, 11], [12, 31], [7, 42],
           [2, 30], [5, 11]],
          Color.new(*rgb, 235)
        )
      end
    end

    ring = a.ring(70, Color.new(218, 250, 255, 240), 3)

    #---------------------------------------------------------------------------
    # Mép màn hình phủ sương giá, không xử lý từng pixel toàn màn hình
    #---------------------------------------------------------------------------
    border = a.bitmap(Graphics.width, Graphics.height) do |b|
      24.times do |i|
        alpha = ((1.0 - i / 24.0) * 95).to_i
        color = Color.new(196, 225, 246, alpha)
        b.fill_rect(i, 0, 1, b.height, color)
        b.fill_rect(b.width - 1 - i, 0, 1, b.height, color)
        b.fill_rect(0, i, b.width, 1, color)
        b.fill_rect(0, b.height - 1 - i, b.width, 1, color)
      end
    end
    a[:border] = a.sprite(border, z: 20_045, centered: false)

    a[:crystal_bitmap] = a.bitmap(Graphics.width, Graphics.height)
    a[:crystal_canvas] = a.sprite(
      a[:crystal_bitmap], z: 20_031, centered: false
    )

    a[:source_mist] = Array.new(8) { a.sprite(mist, z: 20_024) }
    a[:source_snow] = Array.new(10) { a.sprite(snow, z: 20_027) }

    a[:groups] = a.targets.map do |target|
      original = a.battler_sprite(target)
      cx, cy = a.center(target)
      floor = original.y +
              (original.src_rect.height - original.oy) * original.zoom_y
      width = original.src_rect.width * original.zoom_x.abs
      radius = [[width * 0.58, 66].max, 90].min

      body = copy_for.call(target)

      # Bông tuyết được dựng thành từng nhánh, không phóng lớn một hình.
      segments = []
      6.times do |i|
        theta = -Math::PI / 2 + i * Math::PI / 3
        tip = [cx + Math.cos(theta) * radius,
               cy + Math.sin(theta) * radius]
        segments << [[cx, cy], tip, i * 0.012]

        [0.45, 0.72].each_with_index do |fraction, j|
          joint = [
            cx + Math.cos(theta) * radius * fraction,
            cy + Math.sin(theta) * radius * fraction
          ]
          [-1, 1].each do |side|
            angle = theta + Math::PI + side * 0.88
            length = radius * (j == 0 ? 0.28 : 0.21)
            endpoint = [
              joint[0] + Math.cos(angle) * length,
              joint[1] + Math.sin(angle) * length
            ]
            segments << [joint, endpoint, 0.12 + j * 0.07 + i * 0.012]
          end
        end
      end

      {
        x: cx, y: cy, floor: floor,
        body: body, base_x: body.x, base_y: body.y,
        color: body.color.clone,
        segments: segments,
        front: a.sprite(ring, z: 20_028),
        mist: Array.new(42) { a.sprite(mist, z: 20_025) },
        needles: Array.new(28) { a.sprite(shard, z: 20_027) },
        plates: Array.new(7) do |i|
          s = a.sprite(plate, z: i.even? ? 20_015 : 20_029)
          s.ox = 21
          s.oy = 144
          s
        end,
        burst: a.sprite(ring, z: 20_034),
        shards: Array.new(56) { a.sprite(shard, z: 20_036) },
        aftermath: Array.new(18) { a.sprite(mist, z: 20_037) }
      }
    end

    battlers = ([a.user] + a.user.allAllies + a.user.allOpposing)
    battlers = battlers.uniq { |b| b.index }.select do |b|
      next false if b.fainted? || b.isCommander?
      sprite = a.battler_sprite(b)
      next false unless KaitoAnimation.valid_sprite?(sprite)
      next false unless sprite.visible && sprite.opacity > 0
      next false if b.respond_to?(:vanishMode) && b.vanishMode > 0
      true
    end

    a[:field] = battlers.map do |battler|
      cx, cy = a.center(battler)
      copy_for.call(battler)
      changes = battler.stages.values.reject { |value| value == 0 }

      {
        x: cx, y: cy,
        marks: changes.map do |value|
          a.sprite(stat_bitmaps[value > 0 ? 0 : 1], z: 20_039)
        end,
        snow: Array.new(12) { a.sprite(snow, z: 20_040) }
      }
    end

    a[:sweep] = a.sprite(ring, z: 20_038)

    flash = a.bitmap(Graphics.width, Graphics.height) do |b|
      b.fill_rect(
        0, 0, b.width, b.height, Color.new(229, 249, 255)
      )
    end
    a[:flash] = a.sprite(flash, z: 20_050, centered: false)

    viewport = a.instance_variable_get(:@viewport)
    a[:viewport] = viewport
    a[:camera_x] = viewport.ox
    a[:camera_y] = viewport.oy
  end
) do |a, _t|
  sec = a.seconds
  ux, uy = a[:origin]
  first = a[:groups].first

  #=============================================================================
  # 1. SƯƠNG CUỘN VÀ TINH THỂ TỤ LẠI
  #=============================================================================
  charge = a.clamp(sec / 0.18) *
           a.clamp((0.52 - sec) / 0.20)

  a[:source_mist].each_with_index do |cloud, i|
    theta = i * 2.399 + sec * 3
    cloud.x = ux + Math.cos(theta) * 19
    cloud.y = uy + Math.sin(theta) * 9
    cloud.zoom_x = 0.40 + i % 3 * 0.09
    cloud.zoom_y = cloud.zoom_x * 0.70
    cloud.opacity = (charge * 180).to_i
  end

  a[:source_snow].each_with_index do |flake, i|
    theta = i * Math::PI / 5 + sec * 4
    flake.x = ux + Math.cos(theta) * 28
    flake.y = uy + Math.sin(theta) * 19
    flake.angle = sec * 95 + i * 23
    flake.zoom_x = 0.18 + i % 3 * 0.07
    flake.zoom_y = flake.zoom_x
    flake.opacity = (charge * 235).to_i
  end

  border_strength = a.clamp((sec - 0.34) / 0.42) *
                    a.clamp((2.88 - sec) / 0.72)
  a[:border].opacity = (border_strength * 225).to_i

  crystal_canvas = a[:crystal_bitmap]
  crystal_canvas.clear
  a[:crystal_canvas].opacity = 255

  a[:groups].each do |g|
    cx = g[:x]
    cy = g[:y]
    dx = cx - ux
    dy = cy - uy
    length = [Math.sqrt(dx * dx + dy * dy), 1.0].max
    nx = -dy / length
    ny = dx / length

    #===========================================================================
    # 2. MẶT SÓNG GIÁ TRÀN TỚI, SƯƠNG XÒE HÌNH QUẠT
    #===========================================================================
    q = (sec - 0.27) / 0.55
    p = a.clamp(q)
    front = g[:front]
    front.x = a.lerp(ux, cx, p)
    front.y = a.lerp(uy, cy, p)
    front.angle = -Math.atan2(dy, dx) * 180 / Math::PI
    front.zoom_x = 0.15 + p * 0.13
    front.zoom_y = 0.28 + p * 0.88
    front.opacity = q.between?(0.0, 1.0) ?
      (Math.sin(p * Math::PI) * 220).to_i : 0

    g[:mist].each_with_index do |cloud, i|
      q = (sec - 0.25 - i % 10 * 0.024) / 0.62
      p = a.clamp(q)
      lane = (i % 7 - 3) / 3.0
      spread = lane * p * 57
      roll = Math.sin(p * 5 + i * 1.4) * Math.sin(p * Math::PI) * 7

      cloud.x = a.lerp(ux, cx, p) + nx * spread + roll
      cloud.y = a.lerp(uy, cy, p) + ny * spread +
                Math.sin(i * 2.399) * p * 20
      cloud.zoom_x = 0.35 + p * 0.85 + i % 3 * 0.08
      cloud.zoom_y = cloud.zoom_x * 0.75
      cloud.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 190).to_i : 0
    end

    g[:needles].each_with_index do |ice, i|
      q = (sec - 0.35 - i % 7 * 0.032) / 0.43
      p = a.clamp(q)
      spread = Math.sin(i * 2.399) * p * 43

      ice.x = a.lerp(ux, cx, p) + nx * spread
      ice.y = a.lerp(uy, cy, p) + ny * spread
      ice.angle = -Math.atan2(dy, dx) * 180 / Math::PI + 90
      ice.zoom_x = 0.18 + i % 3 * 0.08
      ice.zoom_y = ice.zoom_x * 1.45
      ice.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 245).to_i : 0
    end

    #===========================================================================
    # 3. CÁC PHIẾN BĂNG MỌC LÊN, BÔNG TUYẾT PHÂN NHÁNH
    #===========================================================================
    ice_fade = a.clamp((1.79 - sec) / 0.09)

    g[:plates].each_with_index do |plate, i|
      grow = a.clamp((sec - 0.85 - i % 3 * 0.055) / 0.20)
      side = i - 3
      plate.x = cx + side * 14
      plate.y = g[:floor] + 4
      plate.angle = side * 7
      plate.zoom_x = 0.42 + i % 3 * 0.10
      plate.zoom_y = grow * (0.46 + (3 - side.abs) * 0.13)
      plate.opacity = (grow * ice_fade * 210).to_i
    end

    g[:segments].each do |p1, p2, delay|
      grow = a.clamp((sec - 1.03 - delay) / 0.19)
      next if grow <= 0 || ice_fade <= 0

      tip = [
        a.lerp(p1[0], p2[0], grow),
        a.lerp(p1[1], p2[1], grow)
      ]

      KaitoFreezyCrystal.line(
        a, crystal_canvas, p1, tip,
        Color.new(132, 172, 228, (ice_fade * 190).to_i), 9
      )
      KaitoFreezyCrystal.line(
        a, crystal_canvas, p1, tip,
        Color.new(211, 247, 255, (ice_fade * 245).to_i), 4
      )
      KaitoFreezyCrystal.line(
        a, crystal_canvas, p1, tip,
        Color.new(255, 255, 255, (ice_fade * 245).to_i), 1.5
      )
    end

    # Băng hoàn chỉnh được giữ từ khoảng 1,49 đến 1,70 giây.
    tension = a.clamp((sec - 1.42) / 0.10) *
              a.clamp((1.70 - sec) / 0.08)
    age = sec - 1.70
    flash = age.between?(0.0, 0.17) ? 1.0 - age / 0.17 : 0.0
    recoil = a.clamp(age / 0.035) *
             a.clamp((0.27 - age) / 0.22)

    body = g[:body]
    body.x = g[:base_x] + Math.sin(age * 115) * recoil * 5
    body.y = g[:base_y] - recoil * 2

    if flash > 0
      body.color = Color.new(232, 253, 255, (flash * 225).to_i)
    elsif tension > 0
      body.color = Color.new(167, 218, 247, (tension * 75).to_i)
    else
      body.color = g[:color]
    end

    #===========================================================================
    # 4. VỠ GIÒN — MẢNH LỚN VÀ NHỎ BẮN RA CÙNG LÚC
    #===========================================================================
    q = age / 0.43
    p = a.clamp(q)
    burst = g[:burst]
    burst.x = cx
    burst.y = cy
    burst.zoom_x = 0.15 + p * 1.85
    burst.zoom_y = burst.zoom_x * 0.82
    burst.opacity = q.between?(0.0, 1.0) ?
      ((1.0 - p) * 240).to_i : 0

    g[:shards].each_with_index do |shard, i|
      q = (sec - 1.71 - i % 5 * 0.009) / 0.65
      p = a.clamp(q)
      theta = i * 2.399
      radius = 34 + i % 8 * 13
      spread = 1.0 - (1.0 - p)**3

      shard.x = cx + Math.cos(theta) * spread * radius
      shard.y = cy + Math.sin(theta) * spread * radius * 0.72 +
                p * p * 43
      shard.angle = i * 29 + p * (i.even? ? 210 : -210)
      shard.zoom_x = 0.18 + i % 5 * 0.10
      shard.zoom_y = shard.zoom_x
      shard.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 250).to_i : 0
    end

    g[:aftermath].each_with_index do |cloud, i|
      q = (sec - 1.76 - i % 5 * 0.025) / 0.65
      p = a.clamp(q)
      theta = i * 2.399

      cloud.x = cx + Math.cos(theta) * (15 + p * 55)
      cloud.y = cy + Math.sin(theta) * 20 - p * 14
      cloud.zoom_x = 0.35 + p * 0.95
      cloud.zoom_y = cloud.zoom_x * 0.70
      cloud.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 150).to_i : 0
    end
  end

  # Chớp trắng và rung toàn sân tại nhịp băng vỡ.
  age = sec - 1.70
  flash = age.between?(0.0, 0.16) ? 1.0 - age / 0.16 : 0.0
  a[:flash].opacity = (flash * 95).to_i

  viewport = a[:viewport]
  unless viewport.disposed?
    shake = age.between?(0.0, 0.22) ?
      (1.0 - age / 0.22)**2 : 0.0
    viewport.ox = a[:camera_x] + Math.sin(age * 130) * shake * 8
    viewport.oy = a[:camera_y] + Math.cos(age * 105) * shake * 4
  end

  #=============================================================================
  # 5. VÒNG SƯƠNG QUÉT SÂN, KÉO CÁC THAY ĐỔI CHỈ SỐ RA NGOÀI
  #=============================================================================
  q = (sec - 2.10) / 0.67
  p = a.clamp(q)

  sweep = a[:sweep]
  sweep.x = first[:x]
  sweep.y = first[:y]
  sweep.zoom_x = 0.18 + p * Graphics.width / 57.0
  sweep.zoom_y = sweep.zoom_x * 0.72
  sweep.opacity = q.between?(0.0, 1.0) ?
    (Math.sin(p * Math::PI) * 200).to_i : 0

  a[:field].each do |g|
    distance = Math.sqrt(
      (g[:x] - first[:x])**2 + (g[:y] - first[:y])**2
    )
    delay = [distance / Graphics.width * 0.40, 0.25].min
    start = 2.14 + delay

    g[:marks].each_with_index do |mark, i|
      q = (sec - start - i * 0.015) / 0.40
      p = a.clamp(q)
      theta = i * 2.399

      mark.x = g[:x] + Math.cos(theta) * (13 + p * 38)
      mark.y = g[:y] + Math.sin(theta) * 24 - p * 18
      mark.angle = Math.cos(theta) * p * 45
      mark.zoom_x = 0.42 * (1.0 - p * 0.70)
      mark.zoom_y = 0.58 * (1.0 - p * 0.35)
      mark.color = Color.new(238, 252, 255, (p * 255).to_i)
      mark.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 230).to_i : 0
    end

    g[:snow].each_with_index do |flake, i|
      q = (sec - start - 0.10 - i % 3 * 0.02) / 0.43
      p = a.clamp(q)
      theta = i * 2.399

      flake.x = g[:x] + Math.cos(theta) * (18 + p * 30)
      flake.y = g[:y] + Math.sin(theta) * 24 + p * p * 25
      flake.angle = i * 23 + p * 55
      flake.zoom_x = 0.14 + i % 3 * 0.055
      flake.zoom_y = flake.zoom_x
      flake.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 205).to_i : 0
    end
  end
end

unless Battle::Scene.ancestors.include?(KaitoFreezyCrystal::SceneHooks)
  Battle::Scene.prepend(KaitoFreezyCrystal::SceneHooks)
end