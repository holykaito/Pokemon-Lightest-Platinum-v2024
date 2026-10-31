#===============================================================================
# GLITZY GLOW — Prismatic Psychic
# Yêu cầu: 000_AnimationCore.rb
# Thay toàn bộ animation Glitzy Glow cũ.
#===============================================================================

module KaitoGlitzyPrism
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

  def path(a, g, u, lane)
    dx = g[:x] - a[:sx]
    dy = g[:y] - a[:sy]
    length = [Math.sqrt(dx * dx + dy * dy), 1.0].max
    curve = Math.sin(u * Math::PI)
    offset = (lane - 1) * curve * 29

    [
      a[:sx] + dx * u - dy / length * offset,
      a[:sy] + dy * u + dx / length * offset - curve * 19
    ]
  end

  module SceneHooks
    def pbAnimation(move_id, user, targets, hit_num = 0)
      return super unless move_id == :GLITZYGLOW
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
  :GLITZYGLOW,
  duration: 2.60,
  setup: proc do |a|
    a.sound_at(0.03, ["PRSFX- Confusion"], 50, 115)
    a.sound_at(0.34, ["PRSFX- Psybeam"], 75, 110)
    a.sound_at(0.83, ["PRSFX- Psychic"], 65, 125)
    a.sound_at(1.05, ["PRSFX- Dazzling Gleam"], 75, 115)
    a.sound_at(1.58, ["PRSFX- Light Screen"], 70, 110)

    ux, uy = a.center
    tx, ty = a.center(a.targets.first)
    dx = tx - ux
    dy = ty - uy
    distance = [Math.sqrt(dx * dx + dy * dy), 1.0].max

    a[:sx] = ux + dx / distance * 29
    a[:sy] = uy + dy / distance * 14
    a[:new_screen] =
      a.user.pbOwnSide.effects[PBEffects::LightScreen] <= 0

    a[:palette] = [
      [249, 173, 226],
      [255, 231, 164],
      [178, 194, 249]
    ]

    #---------------------------------------------------------------------------
    # Lăng kính trung tâm
    #---------------------------------------------------------------------------
    prism = a.bitmap(72, 96) do |b|
      a.polygon(
        b,
        [[36, 1], [68, 32], [61, 68], [36, 95],
         [10, 68], [3, 32]],
        Color.new(219, 153, 224, 245)
      )
      a.polygon(
        b,
        [[36, 7], [35, 87], [15, 64], [9, 33]],
        Color.new(255, 229, 169, 250)
      )
      a.polygon(
        b,
        [[38, 8], [61, 34], [37, 45]],
        Color.new(255, 253, 244, 255)
      )
      a.polygon(
        b,
        [[38, 48], [60, 38], [54, 65], [38, 84]],
        Color.new(169, 192, 244, 230)
      )
    end

    glow = a.bitmap(112, 112) do |b|
      112.times do |y|
        112.times do |x|
          r = Math.sqrt((x - 55.5)**2 + (y - 55.5)**2) / 55.0
          next if r > 1.0
          b.set_pixel(
            x, y,
            Color.new(249, 193, 232, ((1.0 - r)**2 * 180).to_i)
          )
        end
      end
    end

    spark = a.bitmap(20, 20) do |b|
      a.polygon(
        b,
        [[10, 0], [13, 7], [20, 10], [13, 13],
         [10, 20], [7, 13], [0, 10], [7, 7]],
        Color.new(255, 237, 190, 245)
      )
      b.fill_rect(8, 8, 4, 4, Color.new(255, 255, 255, 255))
    end

    ring = a.ring(64, Color.new(249, 201, 236, 235), 3)
    gold_ring = a.ring(64, Color.new(255, 237, 189, 235), 2)

    #---------------------------------------------------------------------------
    # Ba mặt Light Screen: lòng kính trong, viền sáng
    #---------------------------------------------------------------------------
    glass = a.bitmap(124, 160) do |b|
      a.polygon(
        b,
        [[7, 9], [115, 1], [118, 149], [11, 159]],
        Color.new(255, 232, 175, 230)
      )
      a.polygon(
        b,
        [[11, 13], [111, 6], [114, 145], [15, 154]],
        Color.new(211, 179, 235, 48)
      )
      a.polygon(
        b,
        [[15, 17], [39, 15], [111, 120], [112, 143],
         [96, 145]],
        Color.new(255, 245, 251, 80)
      )
      a.polygon(
        b,
        [[80, 11], [106, 9], [109, 142], [84, 145]],
        Color.new(177, 231, 247, 55)
      )
      a.polygon(
        b,
        [[18, 24], [33, 21], [37, 61], [21, 66]],
        Color.new(255, 255, 241, 150)
      )
    end

    a[:focus] = a.sprite(prism, z: 20_027)
    a[:source_glow] = a.sprite(glow, z: 20_025)

    a[:ray_bitmap] = a.bitmap(Graphics.width, Graphics.height)
    a[:rays] = a.sprite(
      a[:ray_bitmap], z: 20_028, centered: false
    )

    a[:groups] = a.targets.map do |target|
      cx, cy = a.center(target)
      body = a.copy(target, hide_original: true, z: 20_019)

      {
        x: cx, y: cy,
        body: body, color: body.color.clone,
        lenses: Array.new(3) do |i|
          a.sprite(i == 1 ? gold_ring : ring, z: 20_030)
        end,
        impact: a.sprite(prism, z: 20_033),
        glow: a.sprite(glow, z: 20_032),
        waves: [
          a.sprite(ring, z: 20_034),
          a.sprite(gold_ring, z: 20_034)
        ],
        stream: Array.new(27) { a.sprite(spark, z: 20_031) },
        dust: Array.new(38) { a.sprite(spark, z: 20_036) }
      }
    end

    allies = ([a.user] + a.user.allAllies).select do |b|
      next false if b.fainted? || b.isCommander?
      sprite = a.battler_sprite(b)
      next false unless KaitoAnimation.valid_sprite?(sprite)
      next false unless sprite.visible && sprite.opacity > 0
      next false if b.respond_to?(:vanishMode) && b.vanishMode > 0
      true
    end

    positions = allies.map do |b|
      a.copy(b, hide_original: true, z: 20_018)
      a.center(b)
    end
    positions = [a.center] if positions.empty?

    a[:wall_x] = positions.inject(0.0) { |s, p| s + p[0] } / positions.length
    a[:wall_y] = positions.inject(0.0) { |s, p| s + p[1] } / positions.length
    span = positions.map { |p| p[0] }.max -
           positions.map { |p| p[0] }.min
    a[:wall_scale] = [[(span + 190) / 190.0, 1.0].max, 1.9].min

    a[:glass] = Array.new(3) { a.sprite(glass, z: 20_029) }
    a[:wall_glow] = a.sprite(glow, z: 20_024)
    a[:wall_sparks] = Array.new(18) { a.sprite(spark, z: 20_038) }

    flash = a.bitmap(Graphics.width, Graphics.height) do |b|
      b.fill_rect(
        0, 0, b.width, b.height,
        Color.new(255, 240, 252)
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

  #=============================================================================
  # 1. LĂNG KÍNH TỤ SÁNG
  #=============================================================================
  charge = a.clamp(sec / 0.28)
  source_fade = a.clamp((0.88 - sec) / 0.30)

  focus = a[:focus]
  focus.x = a[:sx]
  focus.y = a[:sy]
  focus.angle = -15 + charge * 15
  focus.zoom_x = 0.18 + charge * 0.54
  focus.zoom_y = focus.zoom_x
  focus.opacity = (charge * source_fade * 250).to_i

  glow = a[:source_glow]
  glow.x = a[:sx]
  glow.y = a[:sy]
  glow.zoom_x = 0.30 + charge * 1.0
  glow.zoom_y = glow.zoom_x
  glow.opacity = (charge * source_fade * 220).to_i

  #=============================================================================
  # 2. BA LUỒNG QUANG NĂNG CONG, HỘI TỤ VÀO MỤC TIÊU
  #=============================================================================
  canvas = a[:ray_bitmap]
  canvas.clear
  a[:rays].opacity = 255

  reach = a.clamp((sec - 0.32) / 0.32)
  ray_fade = a.clamp((1.16 - sec) / 0.30)

  a[:groups].each do |g|
    if reach > 0 && ray_fade > 0
      3.times do |lane|
        points = Array.new(27) do |i|
          KaitoGlitzyPrism.path(a, g, reach * i / 26.0, lane)
        end
        rgb = a[:palette][lane]

        points.each_cons(2) do |p1, p2|
          KaitoGlitzyPrism.line(
            a, canvas, p1, p2,
            Color.new(*rgb, (ray_fade * 75).to_i), 12
          )
          KaitoGlitzyPrism.line(
            a, canvas, p1, p2,
            Color.new(*rgb, (ray_fade * 225).to_i), 4
          )
        end
      end
    end

    g[:stream].each_with_index do |spark, i|
      u = (i / 27.0 + sec * 1.55) % 1.0
      point = KaitoGlitzyPrism.path(a, g, u, i % 3)
      spark.x = point[0]
      spark.y = point[1]
      spark.angle = sec * 120 + i * 23
      spark.zoom_x = 0.14 + i % 3 * 0.075
      spark.zoom_y = spark.zoom_x
      spark.opacity = u <= reach ?
        (reach * ray_fade * Math.sin(u * Math::PI) * 235).to_i : 0
    end

    # Ba vòng thấu kính co vào, giữ ngắn trước lúc bùng sáng.
    lens_form = a.clamp((sec - 0.61) / 0.17)
    compress = a.clamp((sec - 0.77) / 0.17)
    lens_fade = a.clamp((1.16 - sec) / 0.12)

    g[:lenses].each_with_index do |lens, i|
      lens.x = g[:x]
      lens.y = g[:y]
      lens.angle = [-28, 25, 0][i]
      lens.zoom_x = (0.85 - compress * 0.60) * (1.0 + i * 0.12)
      lens.zoom_y = lens.zoom_x * [0.55, 0.55, 0.95][i]
      lens.opacity = (lens_form * lens_fade * 235).to_i
    end

    #===========================================================================
    # 3. QUANG NĂNG BÙNG NỔ — LÕI TRẮNG, QUẦNG HỒNG VÀNG
    #===========================================================================
    bloom = a.clamp((sec - 1.03) / 0.11)
    bloom_fade = a.clamp((1.57 - sec) / 0.30)

    impact = g[:impact]
    impact.x = g[:x]
    impact.y = g[:y]
    impact.angle = bloom * 12
    impact.zoom_x = 0.15 + bloom * 1.15
    impact.zoom_y = impact.zoom_x
    impact.color = Color.new(255, 249, 241, (bloom * 165).to_i)
    impact.opacity = (bloom * bloom_fade * 250).to_i

    glow = g[:glow]
    glow.x = g[:x]
    glow.y = g[:y]
    glow.zoom_x = 0.30 + bloom * 2.0
    glow.zoom_y = glow.zoom_x
    glow.opacity = (bloom * bloom_fade * 255).to_i

    age = sec - 1.05
    flash = age.between?(0.0, 0.19) ? 1.0 - age / 0.19 : 0.0
    g[:body].color = flash > 0 ?
      Color.new(255, 240, 252, (flash * 220).to_i) : g[:color]

    g[:waves].each_with_index do |wave, i|
      q = (sec - 1.06 - i * 0.065) / 0.45
      p = a.clamp(q)
      wave.x = g[:x]
      wave.y = g[:y]
      wave.zoom_x = 0.12 + p * (i == 0 ? 1.85 : 1.55)
      wave.zoom_y = wave.zoom_x * (i == 0 ? 0.85 : 0.45)
      wave.opacity = q.between?(0.0, 1.0) ?
        ((1.0 - p) * 235).to_i : 0
    end

    g[:dust].each_with_index do |spark, i|
      q = (sec - 1.07 - i % 5 * 0.015) / 0.68
      p = a.clamp(q)
      theta = i * 2.399
      radius = 27 + i % 6 * 12
      spread = 1.0 - (1.0 - p)**3

      spark.x = g[:x] + Math.cos(theta) * spread * radius
      spark.y = g[:y] + Math.sin(theta) * spread * radius * 0.72 +
                p * p * 20
      spark.angle = i * 31 + p * 80
      spark.zoom_x = 0.18 + i % 4 * 0.08
      spark.zoom_y = spark.zoom_x
      spark.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 245).to_i : 0
    end
  end

  # Chớp và rung ngắn tại lúc thấu kính vỡ sáng.
  age = sec - 1.05
  flash = age.between?(0.0, 0.16) ? 1.0 - age / 0.16 : 0.0
  a[:flash].opacity = (flash * 90).to_i

  viewport = a[:viewport]
  unless viewport.disposed?
    shake = age.between?(0.0, 0.20) ?
      (1.0 - age / 0.20)**2 : 0.0
    viewport.ox = a[:camera_x] + Math.sin(age * 125) * shake * 6
    viewport.oy = a[:camera_y] + Math.cos(age * 100) * shake * 3
  end

  #=============================================================================
  # 4. LIGHT SCREEN — BA MẶT KÍNH MỞ THÀNH MÀN CHẮN
  #=============================================================================
  fade = a.clamp((2.60 - sec) / 0.34)
  scale = a[:wall_scale]

  a[:glass].each_with_index do |glass, i|
    side = i - 1
    delay = side.abs * 0.07
    form = a.clamp((sec - 1.48 - delay) / 0.32)
    form = form * form * (3.0 - 2.0 * form)

    glass.x = a[:wall_x] + side * 48 * scale * form
    glass.y = a[:wall_y] + (1.0 - form) * 25
    glass.angle = side * (22 - form * 14)
    glass.zoom_x = (0.18 + form * 0.62) * scale
    glass.zoom_y = 0.30 + form * 0.65

    gleam = [1.0 - (sec - 1.99 - i * 0.045).abs / 0.16, 0].max
    glass.color = Color.new(255, 251, 224, (gleam * 180).to_i)
    glass.opacity = (
      form * fade * (a[:new_screen] ? 225 : 120)
    ).to_i
  end

  wall_form = a.clamp((sec - 1.52) / 0.36)
  glow = a[:wall_glow]
  glow.x = a[:wall_x]
  glow.y = a[:wall_y]
  glow.zoom_x = 1.75 * scale
  glow.zoom_y = 1.80
  glow.opacity = (wall_form * fade * 115).to_i

  # Ánh phản chiếu quét ngang mặt kính.
  a[:wall_sparks].each_with_index do |spark, i|
    q = (sec - 1.91 - i % 6 * 0.025) / 0.42
    p = a.clamp(q)

    spark.x = a[:wall_x] + (-77 + p * 154) * scale
    spark.y = a[:wall_y] + (i / 6 - 1) * 39
    spark.angle = 20 + p * 50
    spark.zoom_x = 0.17 + Math.sin(p * Math::PI) * 0.25
    spark.zoom_y = spark.zoom_x
    spark.opacity = q.between?(0.0, 1.0) ?
      (Math.sin(p * Math::PI) * 235).to_i : 0
  end
end

unless Battle::Scene.ancestors.include?(KaitoGlitzyPrism::SceneHooks)
  Battle::Scene.prepend(KaitoGlitzyPrism::SceneHooks)
end