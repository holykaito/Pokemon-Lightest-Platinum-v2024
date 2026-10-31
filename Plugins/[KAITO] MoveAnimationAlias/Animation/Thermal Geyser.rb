#===============================================================================
# THERMAL GEYSER — Mạch nước phun siêu nhiệt
# Yêu cầu: 000_AnimationCore.rb
#===============================================================================

module KaitoThermalGeyserVisual
  module_function

  def line(a, bitmap, p1, p2, color, thickness)
    dx = p2[0] - p1[0]
    dy = p2[1] - p1[1]
    length = [Math.sqrt(dx * dx + dy * dy), 0.01].max
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

  module SceneHooks
    def pbAnimation(move_id, user, targets, hit_num = 0)
      return super unless move_id == :THERMALGEYSER

      # Giữ danh sách gốc để animation vẫn dựng được mục tiêu dưới đất.
      previous = @kaito_thermal_visual_targets
      @kaito_thermal_visual_targets = Array(targets).compact

      viewport = @viewport
      valid_viewport = viewport && !viewport.disposed?
      old_ox = viewport.ox if valid_viewport
      old_oy = viewport.oy if valid_viewport

      begin
        super
      ensure
        @kaito_thermal_visual_targets = previous
        if valid_viewport && !viewport.disposed?
          viewport.ox = old_ox
          viewport.oy = old_oy
        end
      end
    end
  end
end

KaitoAnimation.register(
  :THERMALGEYSER,
  duration: 2.50,
  require_target: false,
  setup: proc do |a|
    a.sound_at(0.03, ["PRSFX- Bubble"], 45, 80)
    a.sound_at(0.39, ["PRSFX- Bubblebeam"], 45, 95)
    a.sound_at(0.77, ["PRSFX- Hydro Cannon2"], 70, 115)
    a.sound_at(1.07, ["PRSFX- Hydro Pump"], 85, 95)
    a.sound_at(1.72, ["PRSFX- Icy Wind1"], 35, 125)
    a.sound_at(2.04, ["PRSFX- Aqua Ring2"], 30, 100)

    #---------------------------------------------------------------------------
    # Khe nứt chia ba lớp: sáng từ ngoài vào tâm
    #---------------------------------------------------------------------------
    paths = [
      [[5, 22], [34, 28], [59, 23], [91, 34]],
      [[177, 17], [151, 28], [124, 26], [91, 34]],
      [[20, 57], [47, 46], [69, 48], [91, 34]],
      [[169, 57], [143, 43], [119, 46], [91, 34]],
      [[71, 3], [74, 16], [85, 22], [91, 34]]
    ]

    crack_layers = Array.new(3) do |layer|
      a.bitmap(184, 68) do |b|
        paths.each do |points|
          p1 = points[layer]
          p2 = points[layer + 1]

          KaitoThermalGeyserVisual.line(
            a, b, p1, p2, Color.new(206, 73, 24, 240), 5
          )
          KaitoThermalGeyserVisual.line(
            a, b, p1, p2, Color.new(255, 192, 76, 250), 2
          )
        end
      end
    end

    #---------------------------------------------------------------------------
    # Vũng nước sôi
    #---------------------------------------------------------------------------
    pool = a.bitmap(176, 62) do |b|
      62.times do |y|
        176.times do |x|
          r = ((x - 87.5) / 85.0)**2 +
              ((y - 30.5) / 28.0)**2
          next if r > 1.0

          color =
            if r > 0.87
              Color.new(213, 250, 250, 220)
            elsif r > 0.65
              Color.new(115, 222, 233, 225)
            else
              Color.new(72, 171, 194, 205)
            end
          b.set_pixel(x, y, color)
        end
      end
    end

    #---------------------------------------------------------------------------
    # Cột nước xòe đầu, không dùng hình ngọn lửa
    #---------------------------------------------------------------------------
    column = a.bitmap(160, 240) do |b|
      a.polygon(
        b,
        [[21, 239], [35, 195], [43, 154], [46, 109],
         [37, 75], [18, 49], [3, 36], [10, 17],
         [28, 22], [48, 45], [55, 56], [53, 26],
         [62, 5], [76, 14], [82, 45], [91, 21],
         [106, 8], [118, 20], [109, 55], [129, 35],
         [148, 28], [158, 43], [139, 62], [119, 86],
         [110, 119], [114, 162], [124, 204], [140, 239]],
        Color.new(109, 214, 236, 230)
      )
      a.polygon(
        b,
        [[35, 239], [47, 196], [54, 154], [58, 107],
         [48, 70], [28, 42], [14, 28], [27, 31],
         [53, 62], [65, 77], [63, 31], [66, 17],
         [71, 24], [76, 66], [86, 76], [101, 31],
         [109, 22], [104, 56], [102, 80], [128, 53],
         [143, 43], [129, 63], [108, 91], [100, 120],
         [104, 164], [113, 204], [125, 239]],
        Color.new(205, 248, 252, 250)
      )
      a.polygon(
        b,
        [[58, 239], [64, 194], [67, 150], [66, 112],
         [61, 86], [72, 100], [77, 72], [84, 100],
         [93, 83], [88, 119], [88, 161], [94, 205],
         [104, 239]],
        Color.new(250, 255, 255, 250)
      )

      # Vệt nước trắng chạy dọc thân.
      a.polygon(
        b,
        [[47, 225], [55, 165], [58, 118], [61, 104],
         [61, 158], [52, 224]],
        Color.new(249, 255, 255, 240)
      )
    end

    #---------------------------------------------------------------------------
    # Ánh địa nhiệt chỉ nằm ở chân cột
    #---------------------------------------------------------------------------
    heat = a.bitmap(100, 90) do |b|
      90.times do |y|
        p = y / 89.0
        half = (5 + p * 40).to_i
        b.fill_rect(
          50 - half, y, half * 2, 1,
          Color.new(255, 183, 72, (p * p * 135).to_i)
        )
      end
    end

    #---------------------------------------------------------------------------
    # Hơi trắng mềm
    #---------------------------------------------------------------------------
    steam = a.bitmap(80, 68) do |b|
      68.times do |y|
        80.times do |x|
          r = Math.sqrt(
            ((x - 39.5) / 39.0)**2 +
            ((y - 33.5) / 33.0)**2
          )
          next if r > 1.0

          b.set_pixel(
            x, y,
            Color.new(240, 248, 250, ((1.0 - r)**1.6 * 150).to_i)
          )
        end
      end
    end

    drop = a.bitmap(20, 30) do |b|
      a.polygon(
        b,
        [[10, 0], [17, 12], [19, 20], [15, 28],
         [7, 29], [1, 23], [2, 15]],
        Color.new(232, 255, 255, 250)
      )
      a.polygon(
        b,
        [[10, 6], [14, 16], [14, 22], [10, 25],
         [6, 23], [5, 18]],
        Color.new(106, 216, 239, 245)
      )
    end

    bubble = a.ring(8, Color.new(233, 254, 255, 235), 2)
    wave = a.ring(65, Color.new(184, 241, 249, 235), 3)

    scene = a.instance_variable_get(:@scene)
    raw_targets = scene.instance_variable_get(:@kaito_thermal_visual_targets)
    targets = raw_targets || a.targets

    a[:groups] = targets.select do |target|
      KaitoAnimation.valid_sprite?(a.battler_sprite(target))
    end.map do |target|
      original = a.battler_sprite(target)
      cx, cy = a.center(target)
      floor = original.y +
              (original.src_rect.height - original.oy) * original.zoom_y
      visible_height = original.src_rect.height * original.zoom_y.abs

      body = a.copy(
        target, hide_original: true, force_visible: true, z: 20_018
      )

      main = a.sprite(column, z: 20_026)
      main.ox = 80
      main.oy = 240

      g = {
        x: cx, y: cy, floor: floor,
        height: [[visible_height * 1.7 + 30, 180].max,
                 [floor - 18, 80].max].min,
        body: body,
        base_x: body.x,
        color: body.color.clone,
        cracks: crack_layers.map { |bitmap| a.sprite(bitmap, z: 20_010) },
        pool: a.sprite(pool, z: 20_011),
        bubbles: Array.new(10) { a.sprite(bubble, z: 20_023) },
        main: main,
        jets: Array.new(4) do
          s = a.sprite(column, z: 20_025)
          s.ox = 80
          s.oy = 240
          s
        end,
        heat: a.sprite(heat, z: 20_028),
        steam: Array.new(22) { a.sprite(steam, z: 20_030) },
        drops: Array.new(50) { a.sprite(drop, z: 20_033) },
        waves: Array.new(3) { a.sprite(wave, z: 20_032) }
      }
      g[:heat].ox = 50
      g[:heat].oy = 90
      g
    end

    viewport = a.instance_variable_get(:@viewport)
    a[:viewport] = viewport
    a[:camera_x] = viewport.ox
    a[:camera_y] = viewport.oy
  end
) do |a, _t|
  sec = a.seconds

  # Hai đợt phun nối nhau.
  first = a.clamp((sec - 0.76) / 0.15)
  second = a.clamp((sec - 1.04) / 0.13)
  collapse = a.clamp((sec - 1.48) / 0.39)
  strength = (first * 0.70 + second * 0.43) * (1.0 - collapse)

  a[:groups].each do |g|
    cx = g[:x]
    cy = g[:y]
    floor = g[:floor]

    #=============================================================================
    # 1. ĐỊA NHIỆT TÍCH TỤ — Sáng từ ngoài vào tâm
    #=============================================================================
    heat_fade = a.clamp((2.35 - sec) / 0.70)

    g[:cracks].each_with_index do |crack, i|
      appear = a.clamp((sec - 0.04 - i * 0.12) / 0.16)
      flicker = 0.80 + Math.sin(sec * 19 + i).abs * 0.20

      crack.x = cx
      crack.y = floor
      crack.opacity = (appear * heat_fade * flicker * 230).to_i
    end

    pool = g[:pool]
    pool.x = cx
    pool.y = floor + 1
    pool.zoom_x = 0.22 + a.clamp((sec - 0.15) / 0.55) * 0.65
    pool.zoom_y = 0.70
    pool.opacity = (
      a.clamp((sec - 0.15) / 0.25) *
      a.clamp((2.50 - sec) / 0.40) * 220
    ).to_i

    #=============================================================================
    # 2. ÁP SUẤT TĂNG — Sủi bọt và các tia phun ngắn
    #=============================================================================
    g[:bubbles].each_with_index do |bubble, i|
      q = (sec - 0.23 - i * 0.035) / 0.29
      p = a.clamp(q)

      bubble.x = cx + Math.sin(i * 2.399) * 28
      bubble.y = floor - 3 - Math.sin(p * Math::PI) * (8 + i % 3 * 5)
      bubble.zoom_x = 0.35 + p * 0.25
      bubble.zoom_y = bubble.zoom_x
      bubble.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 220).to_i : 0
    end

    g[:jets].each_with_index do |jet, i|
      side = i.even? ? -1 : 1
      q = (sec - 0.40 - i * 0.065) / 0.25
      p = a.clamp(q)
      short = q.between?(0.0, 1.0) ? Math.sin(p * Math::PI) : 0.0
      support = strength * a.clamp((sec - 0.86) / 0.14)

      jet.x = cx + side * (18 + i % 2 * 12)
      jet.y = floor + 2
      jet.angle = side * (12 + i * 3)
      jet.zoom_x = 0.17 + support * 0.10
      jet.zoom_y = short * 0.16 + support * g[:height] / 240.0 * 0.64
      jet.opacity = ([short + support, 1.0].min * 220).to_i
    end

    #=============================================================================
    # 3. PHUN TRÀO — Cột trắng xanh, ánh nóng chỉ ở miệng phun
    #=============================================================================
    main = g[:main]
    main.x = cx + Math.sin(sec * 38) * strength * 1.2
    main.y = floor + 3
    main.zoom_x = strength * (0.66 + second * 0.14)
    main.zoom_y = strength * g[:height] / 240.0
    main.opacity = strength > 0 ? 250 : 0

    heat = g[:heat]
    heat.x = cx
    heat.y = floor + 2
    heat.zoom_x = 0.35 + strength * 0.55
    heat.zoom_y = 0.20 + strength * 0.65
    heat.opacity = (
      a.clamp((sec - 0.52) / 0.20) *
      a.clamp((1.91 - sec) / 0.35) * 195
    ).to_i

    flash = 0.0
    [0.82, 1.10].each_with_index do |time, i|
      age = sec - time
      next unless age.between?(0.0, 0.16)
      flash = [flash, (1.0 - age / 0.16) * (i == 0 ? 0.65 : 1.0)].max
    end

    g[:body].color = flash > 0 ?
      Color.new(241, 255, 255, (flash * 210).to_i) : g[:color]

    #=============================================================================
    # 4. HẠ NHIỆT — Giọt nước lớn rơi và hơi trắng cuộn lên
    #=============================================================================
    g[:drops].each_with_index do |drop, i|
      q = (sec - 1.40 - i % 7 * 0.025) / 0.86
      p = a.clamp(q)
      side = Math.sin(i * 2.399)
      start_height = g[:height] * (0.55 + i % 5 * 0.09)

      drop.x = cx + side * (12 + p * (35 + i % 5 * 10))
      drop.y = floor - start_height -
               Math.sin(p * Math::PI) * (10 + i % 4 * 6) +
               p * p * start_height
      drop.angle = -side * (12 + p * 25)
      drop.zoom_x = 0.32 + i % 4 * 0.11
      drop.zoom_y = drop.zoom_x * (1.0 + p * 0.25)
      drop.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 245).to_i : 0
    end

    g[:steam].each_with_index do |cloud, i|
      if sec < 1.42
        q = (sec - 0.10 - i % 7 * 0.07) / 0.65
        p = a.clamp(q)
        base_height = 4
        rise = 30 + i % 4 * 11
        scale = 0.24 + p * 0.45
        opacity = 145
      else
        q = (sec - 1.46 - i % 6 * 0.035) / 0.80
        p = a.clamp(q)
        base_height = 18 + i % 4 * 15
        rise = 28 + i % 3 * 12
        scale = 0.55 + p * 0.60
        opacity = 190
      end

      cloud.x = cx + Math.sin(i * 2.399) * (17 + p * 37) +
                Math.sin(p * 3 + i) * 5
      cloud.y = floor - base_height - p * rise
      cloud.zoom_x = scale
      cloud.zoom_y = scale * 0.82
      cloud.angle = Math.sin(p * 2 + i) * 10
      cloud.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * opacity).to_i : 0
    end

    # Các vòng nước loang khi cột hạ xuống.
    g[:waves].each_with_index do |ring, i|
      q = (sec - 1.60 - i * 0.17) / 0.52
      p = a.clamp(q)

      ring.x = cx
      ring.y = floor + 2
      ring.zoom_x = 0.20 + p * (1.20 + i * 0.10)
      ring.zoom_y = ring.zoom_x * 0.27
      ring.opacity = q.between?(0.0, 1.0) ?
        ((1.0 - p) * 220).to_i : 0
    end
  end

  # Rung nhẹ lúc tích áp; rung mạnh một nhịp ở đợt phun thứ hai.
  viewport = a[:viewport]
  unless viewport.disposed?
    pressure = a.clamp((sec - 0.23) / 0.25) *
               a.clamp((0.74 - sec) / 0.20)

    age = sec - 1.08
    impact = age.between?(0.0, 0.23) ?
      (1.0 - age / 0.23)**2 : 0.0

    viewport.ox = a[:camera_x] +
      Math.sin(sec * 110) * (pressure * 1.2 + impact * 8)
    viewport.oy = a[:camera_y] +
      Math.cos(sec * 95) * (pressure * 0.6 + impact * 5)
  end
end

unless Battle::Scene.ancestors.include?(KaitoThermalGeyserVisual::SceneHooks)
  Battle::Scene.prepend(KaitoThermalGeyserVisual::SceneHooks)
end