#===============================================================================
# MIDNIGHT BEAM — Nguyệt quang Fairy
# Yêu cầu: 000_AnimationCore.rb
# hit 1: Sạc 2,3 giây
# hit 0: Bắn 2,7 giây
#===============================================================================

module KaitoMidnightFairyVisual
  module_function

  def line(a, bitmap, p1, p2, color, thickness)
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

  def setup(a, firing)
    ux, uy = a.center
    target = a.targets.first || a.user.pbDirectOpposing
    sprite = target && a.battler_sprite(target)

    if KaitoAnimation.valid_sprite?(sprite)
      tx, ty = a.center(target)
    else
      tx = ux + (a.user.index.even? ? 150 : -150)
      ty = uy
    end

    dx = tx - ux
    dy = ty - uy
    length = [Math.sqrt(dx * dx + dy * dy), 1.0].max

    a[:ux] = ux
    a[:uy] = uy
    a[:vx] = dx / length
    a[:vy] = dy / length
    a[:sx] = ux + a[:vx] * 35
    a[:sy] = uy + a[:vy] * 15 - 7

    body = a.copy(a.user, hide_original: true, z: 20_018)
    a[:body] = body
    a[:base_x] = body.x
    a[:base_y] = body.y
    a[:body_color] = body.color.clone

    #---------------------------------------------------------------------------
    # Đêm tím lam dịu, không phủ đen đặc
    #---------------------------------------------------------------------------
    veil = a.bitmap(Graphics.width, Graphics.height) do |b|
      b.fill_rect(
        0, 0, b.width, b.height,
        Color.new(41, 38, 83)
      )
    end
    a[:veil] = a.sprite(veil, z: 20_000, centered: false)

    #---------------------------------------------------------------------------
    # Lõi trăng ngọc trai với vành bạc
    #---------------------------------------------------------------------------
    moon = a.bitmap(96, 96) do |b|
      96.times do |y|
        96.times do |x|
          r = Math.sqrt((x - 47.5)**2 + (y - 47.5)**2)
          next if r > 46

          color =
            if r > 41
              Color.new(193, 168, 245, ((46 - r) / 5.0 * 95).to_i)
            elsif r > 37
              Color.new(240, 238, 255, 240)
            elsif r > 34
              Color.new(193, 191, 245, 235)
            else
              light = 1.0 - r / 34.0
              Color.new(
                (220 + light * 35).to_i,
                (215 + light * 36).to_i,
                (245 + light * 10).to_i,
                245
              )
            end
          b.set_pixel(x, y, color)
        end
      end
    end

    pink_ring = a.ring(54, Color.new(255, 203, 233, 225), 2)
    silver_ring = a.ring(63, Color.new(218, 229, 255, 225), 2)

    a[:moon] = a.sprite(moon, z: 20_029)
    a[:rings] = [
      a.sprite(pink_ring, z: 20_028),
      a.sprite(silver_ring, z: 20_030)
    ]

    #---------------------------------------------------------------------------
    # Bụi sao hồng và vàng kem
    #---------------------------------------------------------------------------
    colors = [
      Color.new(255, 211, 235, 245),
      Color.new(255, 239, 187, 245)
    ]

    stars = colors.map do |color|
      a.bitmap(20, 20) do |b|
        a.polygon(
          b,
          [[10, 0], [13, 7], [20, 10], [13, 13],
           [10, 20], [7, 13], [0, 10], [7, 7]],
          color
        )
        b.fill_rect(8, 8, 4, 4, Color.new(255, 255, 250, 255))
      end
    end

    # Quầng sáng mềm.
    glow = a.bitmap(112, 112) do |b|
      112.times do |y|
        112.times do |x|
          r = Math.sqrt((x - 55.5)**2 + (y - 55.5)**2) / 55.0
          next if r > 1.0
          b.set_pixel(
            x, y,
            Color.new(244, 186, 233, ((1.0 - r)**2 * 165).to_i)
          )
        end
      end
    end

    a[:source_glow] = a.sprite(glow, z: 20_025)

    if firing
      #-------------------------------------------------------------------------
      # Tia chính mềm:
      # mép alpha giảm dần, hai đầu bo và lõi trắng ngọc trai.
      #-------------------------------------------------------------------------
      beam = a.bitmap(192, 96) do |b|
        96.times do |y|
          192.times do |x|
            dy = (y - 47.5) / 47.0

            cap =
              if x < 24
                (24 - x) / 24.0
              elsif x > 167
                (x - 167) / 24.0
              else
                0.0
              end

            r = Math.sqrt(dy * dy + cap * cap)
            next if r >= 1.0

            density = (1.0 - r)**1.25
            center = (1.0 - r)**2

            b.set_pixel(
              x, y,
              Color.new(
                (201 + center * 54).to_i,
                (175 + center * 76).to_i,
                (242 + center * 13).to_i,
                (density * 235).to_i
              )
            )
          end
        end
      end

      # Tia dẫn thanh mảnh, không có viền cứng.
      pilot = a.bitmap(128, 8) do |b|
        b.fill_rect(0, 1, 128, 6, Color.new(222, 191, 249, 70))
        b.fill_rect(0, 3, 128, 2, Color.new(250, 246, 255, 235))
      end

      a[:flow_bitmap] = a.bitmap(Graphics.width, Graphics.height)
      a[:flow] = a.sprite(
        a[:flow_bitmap], z: 20_032, centered: false
      )

      a[:groups] = a.targets.map do |battler|
        cx, cy = a.center(battler)
        copy = a.copy(battler, hide_original: true, z: 20_019)

        dx = cx - a[:sx]
        dy = cy - a[:sy]
        distance = [Math.sqrt(dx * dx + dy * dy), 1.0].max

        main = a.sprite(beam, z: 20_030, centered: false)
        main.oy = 48

        guide = a.sprite(pilot, z: 20_031, centered: false)
        guide.oy = 4

        {
          x: cx, y: cy,
          dx: dx, dy: dy,
          length: distance,
          nx: -dy / distance, ny: dx / distance,
          angle: -Math.atan2(dy, dx) * 180 / Math::PI,
          body: copy, color: copy.color.clone,
          beam: main,
          pilot: guide,
          stream_stars: Array.new(24) do |i|
            a.sprite(stars[i % 2], z: 20_034)
          end,
          impact: a.sprite(moon, z: 20_036),
          glow: a.sprite(glow, z: 20_035),
          waves: [
            a.sprite(pink_ring, z: 20_037),
            a.sprite(silver_ring, z: 20_037)
          ],
          dust: Array.new(42) do |i|
            a.sprite(stars[i % 2], z: 20_039)
          end
        }
      end

      flash = a.bitmap(Graphics.width, Graphics.height) do |b|
        b.fill_rect(
          0, 0, b.width, b.height,
          Color.new(255, 238, 251)
        )
      end
      a[:flash] = a.sprite(flash, z: 20_050, centered: false)

      viewport = a.instance_variable_get(:@viewport)
      a[:viewport] = viewport
      a[:camera_x] = viewport.ox
      a[:camera_y] = viewport.oy

      a.sound_at(0.03, ["PRSFX- Moonlight"], 50, 105)
      a.sound_at(0.65, ["PRSFX- Moonblast1"], 70, 110)
      a.sound_at(0.79, ["PRSFX- Hyper Beam"], 65, 125)
      a.sound_at(1.31, ["PRSFX- Moonblast2"], 80, 115)
      a.sound_at(1.90, ["PRSFX- Dazzling Gleam"], 40, 125)
    else
      a[:motes] = Array.new(38) do |i|
        a.sprite(stars[i % 2], z: 20_027)
      end

      a.sound_at(0.04, ["PRSFX- Cosmic Power"], 50, 95)
      a.sound_at(0.71, ["PRSFX- Moonlight"], 45, 110)
      a.sound_at(1.54, ["PRSFX- Heal Bell"], 45, 125)
    end
  end

  #-----------------------------------------------------------------------------
  # Lõi trăng và hai vành sáng dùng chung giữa hai lượt
  #-----------------------------------------------------------------------------
  def source(a, scale, visibility, speed, opening = 0)
    moon = a[:moon]
    moon.x = a[:sx]
    moon.y = a[:sy]
    moon.zoom_x = scale
    moon.zoom_y = scale
    moon.opacity = (visibility * 245).to_i

    glow = a[:source_glow]
    glow.x = a[:sx]
    glow.y = a[:sy]
    glow.zoom_x = scale * 1.60
    glow.zoom_y = glow.zoom_x
    glow.opacity = (visibility * 210).to_i

    a[:rings].each_with_index do |ring, i|
      phase = a.seconds * speed + i * Math::PI / 2
      ring.x = a[:sx]
      ring.y = a[:sy]
      ring.angle = -phase * 180 / Math::PI
      ring.zoom_x = scale * (1.05 - opening * 0.70)
      ring.zoom_y = scale * (0.42 + Math.sin(phase).abs * 0.45)
      ring.opacity = (visibility * (i == 0 ? 220 : 175)).to_i

      if opening > 0.95
        ring.angle = -Math.atan2(a[:vy], a[:vx]) * 180 / Math::PI
        ring.zoom_x = scale * 0.28
        ring.zoom_y = scale * 1.08
      end
    end
  end

  #-----------------------------------------------------------------------------
  # SẠC — Hút ánh sáng thành một vầng trăng ngọc trai
  #-----------------------------------------------------------------------------
  def charge(a)
    sec = a.seconds
    night = a.clamp(sec / 0.40) *
            a.clamp((2.30 - sec) / 0.38)
    a[:veil].opacity = (night * 85).to_i

    grow = a.clamp((sec - 0.35) / 1.07)
    compress = a.clamp((sec - 1.45) / 0.24)
    scale = (0.18 + grow * 0.92) * (1.0 - compress * 0.33)
    visible = a.clamp((sec - 0.24) / 0.23) *
              a.clamp((2.23 - sec) / 0.32)

    source(a, scale, visible, 0.85)

    gleam = [1.0 - (sec - 1.75).abs / 0.18, 0].max
    a[:moon].color = Color.new(255, 245, 255, (gleam * 135).to_i)

    a[:motes].each_with_index do |spark, i|
      width = [Graphics.width - 40, 1].max
      height = [Graphics.height - 40, 1].max
      start_x = 20 + i * 79 % width
      start_y = 20 + i * 53 % height

      q = (sec - 0.30 - i % 7 * 0.05) / 1.05
      p = a.clamp(q)
      travel = p * p

      dx = start_x - a[:sx]
      dy = start_y - a[:sy]
      radius = Math.sqrt(dx * dx + dy * dy) * (1.0 - travel)
      theta = Math.atan2(dy, dx) + travel * 1.8

      spark.x = a[:sx] + Math.cos(theta) * radius
      spark.y = a[:sy] + Math.sin(theta) * radius
      spark.angle = i * 23 + travel * 110
      spark.zoom_x = (0.18 + i % 3 * 0.09) * (1.0 - travel * 0.35)
      spark.zoom_y = spark.zoom_x
      spark.opacity = (
        a.clamp((sec - 0.04) / 0.18) *
        a.clamp((1.0 - p) / 0.20) * 225
      ).to_i
    end

    a[:body].color = Color.new(215, 207, 249, (night * 42).to_i)
  end

  #-----------------------------------------------------------------------------
  # BẮN — Tia ngọc trai, các dòng sáng uốn bên trong
  #-----------------------------------------------------------------------------
  def fire(a)
    sec = a.seconds
    night = a.clamp(sec / 0.22) *
            a.clamp((2.70 - sec) / 0.52)
    a[:veil].opacity = (night * 90).to_i

    opening = a.clamp(sec / 0.38)
    source_fade = a.clamp((2.31 - sec) / 0.43)
    source(a, 0.65 + opening * 0.13, opening * source_fade, 3.7, opening)

    # Tia dẫn hoàn tất ở 0,50s, giữ đến 0,65s.
    guide = a.clamp((sec - 0.42) / 0.08)
    erupt = a.clamp((sec - 0.65) / 0.20)
    erupt = 1.0 - (1.0 - erupt)**3
    narrow = a.clamp((sec - 1.77) / 0.56)
    power = erupt * (1.0 - narrow)

    recoil = a.clamp((sec - 0.65) / 0.07) *
             a.clamp((1.12 - sec) / 0.35)
    a[:body].x = a[:base_x] - a[:vx] * recoil * 6
    a[:body].y = a[:base_y] - a[:vy] * recoil * 6

    canvas = a[:flow_bitmap]
    canvas.clear
    a[:flow].opacity = 255

    a[:groups].each do |g|
      pilot = g[:pilot]
      pilot.x = a[:sx]
      pilot.y = a[:sy]
      pilot.angle = g[:angle]
      pilot.zoom_x = g[:length] / 128.0 * guide
      pilot.zoom_y = 0.80
      pilot.opacity = (
        guide * a.clamp((2.44 - sec) / 0.30) * 225
      ).to_i

      # Tia kết thúc tại mục tiêu, được nối bằng quầng sáng mềm.
      beam = g[:beam]
      beam.x = a[:sx]
      beam.y = a[:sy]
      beam.angle = g[:angle]
      beam.zoom_x = g[:length] / 192.0
      beam.zoom_y = power * (0.83 + Math.sin(sec * 16) * 0.025)
      beam.opacity = (power * 245).to_i

      # Ba sợi ánh sáng pastel uốn liên tục trong tia.
      if power > 0
        [
          [255, 194, 230],
          [255, 237, 194],
          [197, 207, 255]
        ].each_with_index do |rgb, arm|
          points = Array.new(25) do |i|
            u = i / 24.0
            wave = Math.sin(u * Math::PI * 3 - sec * 7 + arm * 2.1) *
                   Math.sin(u * Math::PI) * power * 13
            [
              a[:sx] + g[:dx] * u + g[:nx] * wave,
              a[:sy] + g[:dy] * u + g[:ny] * wave
            ]
          end

          points.each_cons(2) do |p1, p2|
            line(
              a, canvas, p1, p2,
              Color.new(*rgb, (power * 125).to_i), 3
            )
          end
        end
      end

      # Kim tuyến trôi nhanh từ người dùng tới mục tiêu.
      g[:stream_stars].each_with_index do |spark, i|
        u = (i / 24.0 + sec * 1.15) % 1.0
        offset = Math.sin(u * 12 - sec * 7 + i) * 12 * power

        spark.x = a[:sx] + g[:dx] * u + g[:nx] * offset
        spark.y = a[:sy] + g[:dy] * u + g[:ny] * offset
        spark.angle = sec * 95 + i * 23
        spark.zoom_x = 0.12 + i % 3 * 0.065
        spark.zoom_y = spark.zoom_x
        spark.opacity = (
          power * Math.sin(u * Math::PI) * 235
        ).to_i
      end

      #-----------------------------------------------------------------------
      # Điểm chạm nén sáng rồi nở thành quầng trăng Fairy
      #-----------------------------------------------------------------------
      hit = a.clamp((sec - 0.83) / 0.22)
      bloom = a.clamp((sec - 1.25) / 0.18)
      impact_fade = a.clamp((1.93 - sec) / 0.42)

      impact = g[:impact]
      impact.x = g[:x]
      impact.y = g[:y]
      impact.zoom_x = 0.18 + hit * 0.45 + bloom * 0.66
      impact.zoom_y = impact.zoom_x
      impact.opacity = (hit * impact_fade * 235).to_i

      glow = g[:glow]
      glow.x = g[:x]
      glow.y = g[:y]
      glow.zoom_x = 0.30 + hit * 0.70 + bloom * 1.10
      glow.zoom_y = glow.zoom_x
      glow.opacity = (hit * impact_fade * 255).to_i

      g[:waves].each_with_index do |ring, i|
        q = (sec - 1.31 - i * 0.08) / 0.55
        p = a.clamp(q)

        ring.x = g[:x]
        ring.y = g[:y]
        ring.zoom_x = 0.22 + p * (i == 0 ? 1.80 : 1.55)
        ring.zoom_y = ring.zoom_x * (i == 0 ? 0.85 : 0.48)
        ring.opacity = q.between?(0.0, 1.0) ?
          ((1.0 - p) * 220).to_i : 0
      end

      age = sec - 1.31
      flash = age.between?(0.0, 0.19) ? 1.0 - age / 0.19 : 0.0
      g[:body].color = flash > 0 ?
        Color.new(255, 244, 253, (flash * 205).to_i) : g[:color]

      # Dư quang: sao nhỏ chậm rãi rơi, không có mảnh đen.
      g[:dust].each_with_index do |spark, i|
        q = (sec - 1.51 - i % 6 * 0.035) / 0.97
        p = a.clamp(q)
        theta = i * 2.399
        spread = 1.0 - (1.0 - p)**3
        radius = 20 + i % 6 * 12

        spark.x = g[:x] + Math.cos(theta) * spread * radius +
                  Math.sin(p * 3 + i) * 4
        spark.y = g[:y] + Math.sin(theta) * spread * radius * 0.65 +
                  p * p * 45
        spark.angle = i * 29 + p * 55
        spark.zoom_x = 0.15 + i % 4 * 0.07
        spark.zoom_y = spark.zoom_x
        spark.opacity = q.between?(0.0, 1.0) ?
          (Math.sin(p * Math::PI) * 235).to_i : 0
      end
    end

    age = sec - 1.31
    flash = age.between?(0.0, 0.16) ? 1.0 - age / 0.16 : 0.0
    a[:flash].opacity = (flash * 80).to_i

    viewport = a[:viewport]
    unless viewport.disposed?
      shake = age.between?(0.0, 0.20) ?
        (1.0 - age / 0.20)**2 : 0.0
      viewport.ox = a[:camera_x] + Math.sin(age * 125) * shake * 7
      viewport.oy = a[:camera_y] + Math.cos(age * 95) * shake * 4
    end
  end

  module SceneHooks
    def pbAnimation(move_id, user, targets, hit_num = 0)
      return super unless move_id == :MIDNIGHTBEAM

      if hit_num == 1 && user &&
         user.effectiveWeather == :GloomMoonlight
        return
      end

      viewport = @viewport
      return super unless viewport && !viewport.disposed?

      old_ox = viewport.ox
      old_oy = viewport.oy

      begin
        super
      ensure
        unless viewport.disposed?
          viewport.ox = old_ox
          viewport.oy = old_oy
        end
      end
    end
  end
end

KaitoAnimation.register(
  :MIDNIGHTBEAM,
  hit: 1,
  duration: 2.30,
  require_target: false,
  setup: proc { |a| KaitoMidnightFairyVisual.setup(a, false) }
) do |a, _t|
  KaitoMidnightFairyVisual.charge(a)
end

KaitoAnimation.register(
  :MIDNIGHTBEAM,
  hit: 0,
  duration: 2.70,
  setup: proc { |a| KaitoMidnightFairyVisual.setup(a, true) }
) do |a, _t|
  KaitoMidnightFairyVisual.fire(a)
end

unless Battle::Scene.ancestors.include?(KaitoMidnightFairyVisual::SceneHooks)
  Battle::Scene.prepend(KaitoMidnightFairyVisual::SceneHooks)
end