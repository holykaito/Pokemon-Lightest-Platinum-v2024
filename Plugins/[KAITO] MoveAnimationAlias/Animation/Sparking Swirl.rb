#===============================================================================
# SPARKLY SWIRL — Fairy Tempest
# Yêu cầu: 000_AnimationCore.rb
# Thay toàn bộ animation Sparkly Swirl cũ.
#===============================================================================

module KaitoSparklyTempest
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

  def spiral(g, u, arm, rotation, pinch)
    theta = arm * Math::PI * 2 / 3 + u * Math::PI * 6 + rotation
    radius = (38 + u * 35) * (1.0 - pinch * 0.94)

    [
      g[:x] + Math.cos(theta) * radius,
      (g[:floor] - 5 - u * g[:height] +
        Math.sin(theta) * 10) * (1.0 - pinch) + g[:y] * pinch,
      Math.sin(theta)
    ]
  end

  module SceneHooks
    def pbAnimation(move_id, user, targets, hit_num = 0)
      return super unless move_id == :SPARKLYSWIRL
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
  :SPARKLYSWIRL,
  duration: 3.50,
  setup: proc do |a|
    a.sound_at(0.03, ["PRSFX- Heal Bell"], 45, 125)
    a.sound_at(0.49, ["PRSFX- Fairy Wind"], 75, 105)
    a.sound_at(1.12, ["PRSFX- Fairy Wind"], 70, 130)
    a.sound_at(1.57, ["PRSFX- Moonblast1"], 60, 125)
    a.sound_at(1.80, ["PRSFX- Moonblast2"], 90, 110)
    a.sound_at(1.88, ["PRSFX- Dazzling Gleam"], 75, 120)
    a.sound_at(2.65, ["PRSFX- Aromatherapy"], 50, 115)
    a.sound_at(3.03, ["PRSFX- Heal Bell"], 40, 120)

    a[:origin] = a.center
    a[:palette] = [
      [255, 167, 217],
      [255, 232, 155],
      [145, 242, 215]
    ]

    stars = a[:palette].map do |rgb|
      a.bitmap(24, 24) do |b|
        a.polygon(
          b,
          [[12, 0], [16, 8], [24, 12], [16, 16],
           [12, 24], [8, 16], [0, 12], [8, 8]],
          Color.new(*rgb, 250)
        )
        b.fill_rect(10, 10, 4, 4, Color.new(255, 255, 250, 255))
      end
    end

    glow = a.bitmap(112, 112) do |b|
      112.times do |y|
        112.times do |x|
          r = Math.sqrt((x - 55.5)**2 + (y - 55.5)**2) / 55.0
          next if r > 1.0
          b.set_pixel(
            x, y,
            Color.new(255, 181, 225, ((1.0 - r)**2 * 180).to_i)
          )
        end
      end
    end

    flower = a.bitmap(144, 144) do |b|
      points = Array.new(72) do |i|
        theta = i * Math::PI * 2 / 72
        radius = 48 + Math.cos(theta * 6) * 17
        [72 + Math.cos(theta) * radius,
         72 + Math.sin(theta) * radius]
      end
      a.polygon(b, points, Color.new(255, 162, 215, 235))

      inner = points.map do |x, y|
        [72 + (x - 72) * 0.78, 72 + (y - 72) * 0.78]
      end
      a.polygon(b, inner, Color.new(255, 227, 243, 250))

      core = points.map do |x, y|
        [72 + (x - 72) * 0.52, 72 + (y - 72) * 0.52]
      end
      a.polygon(b, core, Color.new(255, 255, 250, 255))
    end

    dark = a.bitmap(28, 28) do |b|
      28.times do |y|
        28.times do |x|
          r = Math.sqrt((x - 13.5)**2 + (y - 13.5)**2) / 13.0
          next if r > 1.0
          b.set_pixel(
            x, y,
            Color.new(72, 45, 95, ((1.0 - r)**1.4 * 190).to_i)
          )
        end
      end
    end

    pink_ring = a.ring(65, Color.new(255, 210, 235, 245), 4)
    mint_ring = a.ring(65, Color.new(185, 250, 225, 235), 3)

    a[:launch] = a.sprite(pink_ring, z: 20_026)
    a[:gather] = Array.new(26) do |i|
      a.sprite(stars[i % 3], z: 20_028)
    end

    a[:back_bitmap] = a.bitmap(Graphics.width, Graphics.height)
    a[:front_bitmap] = a.bitmap(Graphics.width, Graphics.height)
    a[:back] = a.sprite(a[:back_bitmap], z: 20_014, centered: false)
    a[:front] = a.sprite(a[:front_bitmap], z: 20_025, centered: false)

    a[:groups] = a.targets.map do |target|
      original = a.battler_sprite(target)
      cx, cy = a.center(target)
      floor = original.y +
              (original.src_rect.height - original.oy) * original.zoom_y
      height = original.src_rect.height * original.zoom_y.abs

      body = a.copy(target, hide_original: true, z: 20_019)

      {
        x: cx, y: cy, floor: floor,
        height: [[height * 1.45 + 30, 140].max,
                 [floor - 18, 90].max].min,
        body: body,
        base_x: body.x, base_y: body.y,
        color: body.color.clone,
        glitter: Array.new(42) do |i|
          a.sprite(stars[i % 3], z: 20_027)
        end,
        glow: a.sprite(glow, z: 20_030),
        flower: a.sprite(flower, z: 20_031),
        rings: Array.new(3) do |i|
          a.sprite(i == 1 ? mint_ring : pink_ring, z: 20_033)
        end,
        dust: Array.new(60) do |i|
          a.sprite(stars[i % 3], z: 20_035)
        end
      }
    end

    allies = ([a.user] + a.user.allAllies).select do |battler|
      next false if battler.fainted? || battler.isCommander?
      sprite = a.battler_sprite(battler)
      next false unless KaitoAnimation.valid_sprite?(sprite)
      next false unless sprite.visible && sprite.opacity > 0
      next false if battler.respond_to?(:vanishMode) &&
                    battler.vanishMode > 0
      true
    end

    a[:allies] = allies.map do |battler|
      cx, cy = a.center(battler)
      body = a.copy(battler, hide_original: true, z: 20_018)

      {
        x: cx, y: cy,
        status: battler.status != :NONE,
        body: body, color: body.color.clone,
        wave: a.sprite(mint_ring, z: 20_029),
        glow: a.sprite(glow, z: 20_026),
        dark: Array.new(8) { a.sprite(dark, z: 20_027) },
        sparks: Array.new(20) do |i|
          a.sprite(stars[i % 3], z: 20_034)
        end
      }
    end

    flash = a.bitmap(Graphics.width, Graphics.height) do |b|
      b.fill_rect(
        0, 0, b.width, b.height,
        Color.new(255, 236, 250)
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
  # 1. TỤ SÁNG VÀ PHÓNG VÒNG PHÉP — Nhanh, gọn
  #=============================================================================
  travel = a.clamp((sec - 0.23) / 0.32)
  travel = travel * travel * (3.0 - 2.0 * travel)
  cx = a.lerp(ux, first[:x], travel)
  cy = a.lerp(uy, first[:y], travel) -
       Math.sin(travel * Math::PI) * 25
  visible = a.clamp(sec / 0.16) *
            a.clamp((0.72 - sec) / 0.16)

  launch = a[:launch]
  launch.x = cx
  launch.y = cy
  launch.zoom_x = 0.25 + a.clamp(sec / 0.23) * 0.42
  launch.zoom_y = launch.zoom_x * 0.65
  launch.opacity = (visible * 245).to_i

  a[:gather].each_with_index do |spark, i|
    theta = i * 2.399 + sec * 7
    spark.x = cx + Math.cos(theta) * (21 + i % 3 * 5)
    spark.y = cy + Math.sin(theta) * 17
    spark.angle = i * 29 + sec * 100
    spark.zoom_x = 0.18 + i % 3 * 0.10
    spark.zoom_y = spark.zoom_x
    spark.opacity = (visible * 240).to_i
  end

  #=============================================================================
  # 2. LỐC TĂNG TỐC → SIẾT → KHỰNG TRƯỚC KHI NỔ
  #=============================================================================
  back = a[:back_bitmap]
  front = a[:front_bitmap]
  back.clear
  front.clear
  a[:back].opacity = 255
  a[:front].opacity = 255

  grow = a.clamp((sec - 0.50) / 0.26)
  pinch = a.clamp((sec - 1.40) / 0.24)
  pinch = pinch * pinch * (3.0 - 2.0 * pinch)
  ribbon_fade = a.clamp((1.83 - sec) / 0.10)

  # Tăng tốc rõ rệt; giảm chuyển động ở nhịp nén cuối.
  clock = [sec, 1.64].min
  rotation = -(clock * 4.0 + clock * clock * 3.8)

  a[:groups].each do |g|
    if grow > 0 && ribbon_fade > 0
      3.times do |arm|
        points = Array.new(37) do |i|
          KaitoSparklyTempest.spiral(
            g, grow * i / 36.0, arm, rotation, pinch
          )
        end
        rgb = a[:palette][arm]

        points.each_cons(2) do |p1, p2|
          canvas = p1[2] + p2[2] > 0 ? front : back
          KaitoSparklyTempest.line(
            a, canvas, p1, p2,
            Color.new(*rgb, (ribbon_fade * 100).to_i), 13
          )
          KaitoSparklyTempest.line(
            a, canvas, p1, p2,
            Color.new(*rgb, (ribbon_fade * 245).to_i), 6
          )
        end
      end
    end

    g[:glitter].each_with_index do |spark, i|
      u = (i / 42.0 + clock * 1.25) % 1.0
      pos = KaitoSparklyTempest.spiral(
        g, u, i % 3, rotation, pinch
      )

      spark.x = pos[0]
      spark.y = pos[1]
      spark.z = pos[2] > 0 ? 20_027 : 20_015
      spark.angle = sec * 160 + i * 23
      spark.zoom_x = 0.17 + i % 3 * 0.09
      spark.zoom_y = spark.zoom_x
      spark.opacity = u <= grow ?
        (grow * ribbon_fade * 245).to_i : 0
    end

    #===========================================================================
    # 3. BÙNG NỔ — Đóa sáng lớn, giữ lực rồi mới tan
    #===========================================================================
    bloom = a.clamp((sec - 1.78) / 0.12)
    hold_fade = a.clamp((2.35 - sec) / 0.28)
    expand = a.clamp((sec - 1.93) / 0.40)

    glow = g[:glow]
    glow.x = g[:x]
    glow.y = g[:y]
    glow.zoom_x = 0.35 + bloom * 2.25 + expand * 0.65
    glow.zoom_y = glow.zoom_x
    glow.opacity = (bloom * hold_fade * 255).to_i

    flower = g[:flower]
    flower.x = g[:x]
    flower.y = g[:y]
    flower.angle = bloom * 14 + expand * 12
    flower.zoom_x = 0.15 + bloom * 1.25 + expand * 0.35
    flower.zoom_y = flower.zoom_x
    flower.opacity = (bloom * hold_fade * 250).to_i

    g[:rings].each_with_index do |ring, i|
      q = (sec - 1.81 - i * 0.065) / 0.48
      p = a.clamp(q)
      ring.x = g[:x]
      ring.y = g[:y]
      ring.zoom_x = 0.15 + p * (2.10 + i * 0.15)
      ring.zoom_y = ring.zoom_x * [0.86, 0.45, 0.70][i]
      ring.opacity = q.between?(0.0, 1.0) ?
        ((1.0 - p) * 245).to_i : 0
    end

    age = sec - 1.80
    flash = age.between?(0.0, 0.22) ? 1.0 - age / 0.22 : 0.0
    recoil = a.clamp(age / 0.045) *
             a.clamp((0.31 - age) / 0.24)
    direction = g[:x] >= ux ? 1 : -1

    g[:body].x = g[:base_x] + direction * recoil * 7
    g[:body].y = g[:base_y] - recoil * 3
    g[:body].color = flash > 0 ?
      Color.new(255, 245, 253, (flash * 230).to_i) : g[:color]

    # Sao lớn nhỏ bung mạnh rồi giảm tốc, rơi nhẹ.
    g[:dust].each_with_index do |spark, i|
      q = (sec - 1.83 - i % 6 * 0.014) / 0.83
      p = a.clamp(q)
      theta = i * 2.399
      spread = 1.0 - (1.0 - p)**3
      radius = 35 + i % 8 * 13

      spark.x = g[:x] + Math.cos(theta) * spread * radius
      spark.y = g[:y] + Math.sin(theta) * spread * radius * 0.73 +
                p * p * 39
      spark.angle = i * 31 + p * (i.even? ? 100 : -100)
      spark.zoom_x = (0.17 + i % 5 * 0.075) * (1.0 - p * 0.25)
      spark.zoom_y = spark.zoom_x
      spark.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 250).to_i : 0
    end
  end

  # Chớp và rung toàn sân đúng một nhịp ở cao trào.
  age = sec - 1.80
  flash = age.between?(0.0, 0.18) ? 1.0 - age / 0.18 : 0.0
  a[:flash].opacity = (flash * 115).to_i

  viewport = a[:viewport]
  unless viewport.disposed?
    shake = age.between?(0.0, 0.24) ?
      (1.0 - age / 0.24)**2 : 0.0
    viewport.ox = a[:camera_x] + Math.sin(age * 130) * shake * 9
    viewport.oy = a[:camera_y] + Math.cos(age * 105) * shake * 5
  end

  #=============================================================================
  # 4. THANH TẨY — Dịu xuống sau cao trào
  #=============================================================================
  a[:allies].each do |g|
    q = (sec - 2.24) / 0.46
    p = a.clamp(q)
    wave = g[:wave]
    wave.x = a.lerp(first[:x], g[:x], p)
    wave.y = a.lerp(first[:y], g[:y], p) -
             Math.sin(p * Math::PI) * 16
    wave.zoom_x = 0.25 + p * 0.85
    wave.zoom_y = wave.zoom_x * 0.78
    wave.opacity = q.between?(0.0, 1.0) ?
      (Math.sin(p * Math::PI) * 200).to_i : 0

    cleanse = a.clamp((sec - 2.65) / 0.18)
    finish = a.clamp((3.50 - sec) / 0.36)

    glow = g[:glow]
    glow.x = g[:x]
    glow.y = g[:y]
    glow.zoom_x = 0.70 + cleanse * 0.70
    glow.zoom_y = 1.10
    glow.opacity = (cleanse * finish * 185).to_i

    g[:body].color = cleanse > 0 ?
      Color.new(228, 255, 237, (cleanse * finish * 55).to_i) : g[:color]

    g[:dark].each_with_index do |mote, i|
      theta = i * 2.399
      burst = a.clamp((sec - 2.75) / 0.22)
      visible = a.clamp((sec - 2.43) / 0.17) *
                a.clamp((3.03 - sec) / 0.23)

      mote.x = g[:x] + Math.cos(theta) * (22 + burst * 17)
      mote.y = g[:y] + Math.sin(theta) * 25 - burst * 8
      mote.zoom_x = (0.45 + i % 3 * 0.10) * (1.0 - burst * 0.85)
      mote.zoom_y = mote.zoom_x
      mote.color = Color.new(239, 255, 224, (burst * 255).to_i)
      mote.opacity = g[:status] ? (visible * 210).to_i : 0
    end

    g[:sparks].each_with_index do |spark, i|
      q = (sec - 2.72 - i % 5 * 0.035) / 0.60
      p = a.clamp(q)
      theta = i * 2.399

      spark.x = g[:x] + Math.cos(theta) * (17 + p * 18)
      spark.y = g[:y] + 24 + Math.sin(theta) * 12 -
                p * (43 + i % 4 * 9)
      spark.angle = i * 29 + p * 50
      spark.zoom_x = 0.17 + i % 3 * 0.09
      spark.zoom_y = spark.zoom_x
      spark.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 225).to_i : 0
    end
  end
end

unless Battle::Scene.ancestors.include?(KaitoSparklyTempest::SceneHooks)
  Battle::Scene.prepend(KaitoSparklyTempest::SceneHooks)
end