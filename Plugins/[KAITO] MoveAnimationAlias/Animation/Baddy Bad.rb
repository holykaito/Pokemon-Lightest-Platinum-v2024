#===============================================================================
# BADDY BAD — Malice Burst
# Yêu cầu: 000_AnimationCore.rb
# Thay toàn bộ animation Baddy Bad cũ.
#===============================================================================

module KaitoBaddyBadVisual
  module SceneHooks
    def pbAnimation(move_id, user, targets, hit_num = 0)
      return super unless move_id == :BADDYBAD
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
  :BADDYBAD,
  duration: 2.60,
  setup: proc do |a|
    a.sound_at(0.03, ["PRSFX- Dark Pulse1"], 60, 85)
    a.sound_at(0.59, ["PRSFX- Confuse Ray"], 50, 105)
    a.sound_at(1.02, ["PRSFX- Dark Pulse2"], 85, 90)
    a.sound_at(1.52, ["PRSFX- Reflect"], 70, 100)

    a[:origin] = a.center
    a[:new_reflect] =
      a.user.pbOwnSide.effects[PBEffects::Reflect] <= 0

    #---------------------------------------------------------------------------
    # Khói hắc năng: tâm than tím, mép mờ
    #---------------------------------------------------------------------------
    fog = a.bitmap(88, 76) do |b|
      76.times do |y|
        88.times do |x|
          r = Math.sqrt(
            ((x - 43.5) / 43.0)**2 +
            ((y - 37.5) / 37.0)**2
          )
          next if r > 1.0
          density = (1.0 - r)**1.45

          b.set_pixel(
            x, y,
            Color.new(
              (82 - density * 52).to_i,
              (45 - density * 27).to_i,
              (117 - density * 68).to_i,
              (density * 210).to_i
            )
          )
        end
      end
    end

    # Quầng tím sáng cho nhịp nổ.
    glow = a.bitmap(112, 112) do |b|
      112.times do |y|
        112.times do |x|
          r = Math.sqrt((x - 55.5)**2 + (y - 55.5)**2) / 55.0
          next if r > 1.0
          b.set_pixel(
            x, y,
            Color.new(161, 99, 218, ((1.0 - r)**2 * 175).to_i)
          )
        end
      end
    end

    #---------------------------------------------------------------------------
    # Đôi mắt ảo ảnh — dấu hiệu áp lực hắc ám
    #---------------------------------------------------------------------------
    eyes = a.bitmap(136, 48) do |b|
      a.polygon(
        b,
        [[3, 8], [27, 10], [57, 25], [43, 38],
         [21, 31], [9, 21]],
        Color.new(148, 83, 193, 235)
      )
      a.polygon(
        b,
        [[133, 8], [109, 10], [79, 25], [93, 38],
         [115, 31], [127, 21]],
        Color.new(148, 83, 193, 235)
      )
      a.polygon(
        b,
        [[13, 15], [29, 17], [49, 26], [40, 31], [24, 26]],
        Color.new(230, 188, 252, 255)
      )
      a.polygon(
        b,
        [[123, 15], [107, 17], [87, 26], [96, 31], [112, 26]],
        Color.new(230, 188, 252, 255)
      )
      b.fill_rect(33, 20, 3, 10, Color.new(35, 15, 51, 255))
      b.fill_rect(100, 20, 3, 10, Color.new(35, 15, 51, 255))
    end

    shard = a.bitmap(20, 30) do |b|
      a.polygon(
        b,
        [[10, 0], [19, 10], [13, 26], [6, 30], [1, 13]],
        Color.new(153, 108, 198, 245)
      )
      a.polygon(
        b,
        [[10, 4], [10, 23], [5, 25], [4, 13]],
        Color.new(224, 198, 248, 245)
      )
    end

    ring = a.ring(62, Color.new(188, 133, 225, 240), 3)
    silver_ring = a.ring(62, Color.new(224, 209, 250, 230), 2)

    #---------------------------------------------------------------------------
    # Mảnh kính Reflect: khung bạc tím, lòng tối bán trong suốt
    #---------------------------------------------------------------------------
    panel = a.bitmap(84, 96) do |b|
      a.polygon(
        b,
        [[42, 1], [81, 24], [81, 70],
         [42, 95], [3, 70], [3, 24]],
        Color.new(195, 176, 234, 235)
      )
      a.polygon(
        b,
        [[42, 7], [75, 28], [75, 67],
         [42, 88], [9, 67], [9, 28]],
        Color.new(47, 30, 79, 100)
      )
      a.polygon(
        b,
        [[13, 30], [42, 12], [54, 19], [16, 43], [13, 62]],
        Color.new(229, 214, 252, 140)
      )
      a.polygon(
        b,
        [[60, 26], [71, 32], [71, 64], [44, 82]],
        Color.new(130, 115, 184, 85)
      )
    end

    a[:groups] = a.targets.map do |target|
      cx, cy = a.center(target)
      body = a.copy(target, hide_original: true, z: 20_019)

      {
        x: cx, y: cy,
        body: body,
        base_x: body.x, base_y: body.y,
        color: body.color.clone,
        stream: Array.new(24) { a.sprite(fog, z: 20_025) },
        cloud: Array.new(16) { a.sprite(fog, z: 20_026) },
        eyes: a.sprite(eyes, z: 20_028),
        glow: a.sprite(glow, z: 20_030),
        rings: [
          a.sprite(ring, z: 20_032),
          a.sprite(silver_ring, z: 20_033),
          a.sprite(ring, z: 20_032)
        ],
        shards: Array.new(38) { a.sprite(shard, z: 20_035) }
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

    if positions.empty?
      positions = [a.center]
    end

    center_x = positions.inject(0.0) { |sum, p| sum + p[0] } / positions.length
    center_y = positions.inject(0.0) { |sum, p| sum + p[1] } / positions.length
    span = positions.map { |p| p[0] }.max -
           positions.map { |p| p[0] }.min

    a[:wall_x] = center_x
    a[:wall_y] = center_y
    a[:wall_scale] = [[(span + 170) / 170.0, 1.0].max, 1.9].min
    a[:panels] = Array.new(7) { a.sprite(panel, z: 20_029) }
    a[:wall_glow] = a.sprite(glow, z: 20_024)
    a[:wall_ring] = a.sprite(silver_ring, z: 20_030)

    flash = a.bitmap(Graphics.width, Graphics.height) do |b|
      b.fill_rect(
        0, 0, b.width, b.height,
        Color.new(196, 164, 227)
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

  a[:groups].each do |g|
    cx = g[:x]
    cy = g[:y]

    #=============================================================================
    # 1. HẮC NĂNG CUỘN TỪ NGƯỜI DÙNG SANG MỤC TIÊU
    #=============================================================================
    g[:stream].each_with_index do |cloud, i|
      q = (sec - 0.10 - i % 8 * 0.022) / 0.55
      p = a.clamp(q)
      travel = p * p
      theta = i * 2.399 + p * 3

      cloud.x = a.lerp(ux, cx, travel) +
                Math.cos(theta) * (1.0 - p) * 20
      cloud.y = a.lerp(uy, cy, travel) -
                Math.sin(p * Math::PI) * 16 +
                Math.sin(theta) * 13
      cloud.zoom_x = 0.35 + p * 0.43 + i % 3 * 0.06
      cloud.zoom_y = cloud.zoom_x * 0.78
      cloud.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 225).to_i : 0
    end

    #=============================================================================
    # 2. ẢO ẢNH MỞ MẮT, ÁP LỰC SIẾT VÀO TRONG
    #=============================================================================
    form = a.clamp((sec - 0.45) / 0.25)
    squeeze = a.clamp((sec - 0.77) / 0.19)
    release = a.clamp((sec - 1.02) / 0.24)
    cloud_fade = a.clamp((1.40 - sec) / 0.27)

    g[:cloud].each_with_index do |cloud, i|
      theta = i * 2.399 + sec * 2.1
      radius = (37 + i % 4 * 7) *
               (1.0 - squeeze * 0.72 + release * 1.30)

      cloud.x = cx + Math.cos(theta) * radius
      cloud.y = cy + Math.sin(theta) * radius * 0.78
      cloud.zoom_x = 0.60 + form * 0.35 + release * 0.20
      cloud.zoom_y = cloud.zoom_x
      cloud.opacity = (form * cloud_fade * 225).to_i
    end

    eye_open = a.clamp((sec - 0.58) / 0.12) *
               a.clamp((1.15 - sec) / 0.15)
    eyes = g[:eyes]
    eyes.x = cx
    eyes.y = cy - 10
    eyes.zoom_x = 0.70 + form * 0.36 - squeeze * 0.17
    eyes.zoom_y = eye_open * 0.85
    eyes.opacity = (eye_open * 255).to_i

    # Mục tiêu bị phủ tối nhưng vẫn giữ hình dáng.
    gloom = form * a.clamp((1.02 - sec) / 0.18)
    body = g[:body]
    body.color = gloom > 0 ?
      Color.new(38, 17, 56, (gloom * 170).to_i) : g[:color]

    #=============================================================================
    # 3. ÁP LỰC BUNG NỔ — KHÔNG DÙNG CÚ CHÉM VẬT LÝ
    #=============================================================================
    age = sec - 1.02
    flash = age.between?(0.0, 0.17) ? 1.0 - age / 0.17 : 0.0
    recoil = a.clamp(age / 0.04) *
             a.clamp((0.27 - age) / 0.22)

    body.x = g[:base_x] + Math.sin(age * 110) * recoil * 5
    body.y = g[:base_y] - recoil * 2
    if flash > 0
      body.color = Color.new(190, 143, 220, (flash * 185).to_i)
    end

    glow = g[:glow]
    glow.x = cx
    glow.y = cy
    glow.zoom_x = 0.25 + release * 2.0
    glow.zoom_y = glow.zoom_x
    glow.opacity = (release * cloud_fade * 245).to_i

    g[:rings].each_with_index do |ring, i|
      q = (sec - 1.03 - i * 0.055) / 0.43
      p = a.clamp(q)
      ring.x = cx
      ring.y = cy
      ring.zoom_x = 0.12 + p * (1.55 + i * 0.20)
      ring.zoom_y = ring.zoom_x * [0.85, 0.45, 0.70][i]
      ring.opacity = q.between?(0.0, 1.0) ?
        ((1.0 - p) * 235).to_i : 0
    end

    g[:shards].each_with_index do |shard, i|
      q = (sec - 1.05 - i % 5 * 0.012) / 0.67
      p = a.clamp(q)
      theta = i * 2.399
      spread = 1.0 - (1.0 - p)**3
      radius = 27 + i % 6 * 12

      shard.x = cx + Math.cos(theta) * spread * radius
      shard.y = cy + Math.sin(theta) * spread * radius * 0.72 +
                p * p * 26
      shard.angle = i * 29 + p * (i.even? ? 150 : -150)
      shard.zoom_x = 0.21 + i % 4 * 0.09
      shard.zoom_y = shard.zoom_x
      shard.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 245).to_i : 0
    end
  end

  # Một nhịp rung tại lúc áp lực vỡ.
  age = sec - 1.02
  flash = age.between?(0.0, 0.15) ? 1.0 - age / 0.15 : 0.0
  a[:flash].opacity = (flash * 70).to_i

  viewport = a[:viewport]
  unless viewport.disposed?
    shake = age.between?(0.0, 0.21) ?
      (1.0 - age / 0.21)**2 : 0.0
    viewport.ox = a[:camera_x] + Math.sin(age * 125) * shake * 7
    viewport.oy = a[:camera_y] + Math.cos(age * 100) * shake * 4
  end

  #=============================================================================
  # 4. REFLECT — BẢY MẢNH KÍNH GHÉP THÀNH MỘT MẶT CHẮN LỚN
  #=============================================================================
  layouts = [
    [0, 0], [-1, 0], [1, 0],
    [-0.5, -0.75], [0.5, -0.75],
    [-0.5, 0.75], [0.5, 0.75]
  ]
  fade = a.clamp((2.60 - sec) / 0.34)

  a[:panels].each_with_index do |panel, i|
    form = a.clamp((sec - 1.45 - i * 0.045) / 0.23)
    form = form * form * (3.0 - 2.0 * form)
    lx, ly = layouts[i]

    panel.x = a[:wall_x] + lx * 54 * a[:wall_scale] +
              (1.0 - form) * lx * 30
    panel.y = a[:wall_y] + ly * 60 +
              (1.0 - form) * 25
    panel.angle = (1.0 - form) * (i.even? ? 16 : -16)
    panel.zoom_x = (0.35 + form * 0.40) * a[:wall_scale]
    panel.zoom_y = 0.35 + form * 0.40

    gleam_time = 1.98 + i * 0.025
    gleam = [1.0 - (sec - gleam_time).abs / 0.14, 0].max
    panel.color = Color.new(237, 224, 255, (gleam * 175).to_i)
    panel.opacity = (
      form * fade * (a[:new_reflect] ? 220 : 115)
    ).to_i
  end

  wall_form = a.clamp((sec - 1.48) / 0.40)
  glow = a[:wall_glow]
  glow.x = a[:wall_x]
  glow.y = a[:wall_y]
  glow.zoom_x = 1.65 * a[:wall_scale]
  glow.zoom_y = 1.65
  glow.opacity = (wall_form * fade * 125).to_i

  q = (sec - 1.92) / 0.47
  p = a.clamp(q)
  ring = a[:wall_ring]
  ring.x = a[:wall_x]
  ring.y = a[:wall_y]
  ring.zoom_x = (0.35 + p * 1.35) * a[:wall_scale]
  ring.zoom_y = 0.35 + p * 1.35
  ring.opacity = q.between?(0.0, 1.0) ?
    ((1.0 - p) * 175).to_i : 0
end

unless Battle::Scene.ancestors.include?(KaitoBaddyBadVisual::SceneHooks)
  Battle::Scene.prepend(KaitoBaddyBadVisual::SceneHooks)
end