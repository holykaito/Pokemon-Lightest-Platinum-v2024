#===============================================================================
# DARK MIST — Màn sương hắc ám
# Yêu cầu: 000_AnimationCore.rb
#===============================================================================

module KaitoDarkMistVisual
  module_function

  def setup(a, activation)
    #---------------------------------------------------------------------------
    # Khói mềm: nhiều búi tròn chồng nhau, rìa trong suốt.
    # Bitmap nhỏ, dùng chung cho toàn bộ các sprite khói.
    #---------------------------------------------------------------------------
    clouds = Array.new(2) do |variant|
      a.bitmap(80, 80) do |b|
        lobes = [
          [39, 43, 32],
          [24, 38, 23],
          [53, 31 + variant * 5, 25],
          [36, 24, 23]
        ]

        80.times do |y|
          80.times do |x|
            density = 0.0
            lobes.each do |lx, ly, radius|
              r = Math.sqrt((x - lx)**2 + (y - ly)**2) / radius
              next if r >= 1.0
              value = (1.0 - r)**1.35
              density = [density, value].max
            end
            next if density <= 0.0

            b.set_pixel(
              x, y,
              Color.new(
                (63 - density * 35).to_i,
                (37 - density * 17).to_i,
                (79 - density * 43).to_i,
                (density * 205).to_i
              )
            )
          end
        end
      end
    end

    #---------------------------------------------------------------------------
    # Đôi mắt tím, không có khuôn mặt
    #---------------------------------------------------------------------------
    eyes = a.bitmap(116, 36) do |b|
      [
        [[4, 9], [20, 8], [46, 17], [39, 26], [19, 24]],
        [[112, 9], [96, 8], [70, 17], [77, 26], [97, 24]]
      ].each do |points|
        a.polygon(b, points, Color.new(153, 94, 214, 220))
      end

      a.polygon(
        b,
        [[10, 12], [23, 12], [41, 18], [35, 22], [21, 21]],
        Color.new(212, 166, 255, 255)
      )
      a.polygon(
        b,
        [[106, 12], [93, 12], [75, 18], [81, 22], [95, 21]],
        Color.new(212, 166, 255, 255)
      )
      b.fill_rect(28, 14, 3, 8, Color.new(48, 20, 69, 255))
      b.fill_rect(85, 14, 3, 8, Color.new(48, 20, 69, 255))
    end

    # Đốm lavender yếu.
    mote = a.bitmap(12, 12) do |b|
      a.polygon(
        b,
        [[6, 0], [8, 4], [12, 6], [8, 8],
         [6, 12], [4, 8], [0, 6], [4, 4]],
        Color.new(185, 137, 231, 225)
      )
    end

    # Tia tím ngắn tại thời điểm siết.
    ray = a.bitmap(42, 10) do |b|
      a.polygon(
        b,
        [[0, 5], [30, 1], [41, 5], [30, 9]],
        Color.new(137, 76, 189, 210)
      )
      a.polygon(
        b,
        [[12, 5], [34, 3], [41, 5], [34, 6]],
        Color.new(211, 164, 250, 245)
      )
    end

    if activation
      entries = a.targets.map { |b| [b] }
    else
      foes = a.user.allOpposing.reject(&:fainted?).select do |b|
        KaitoAnimation.valid_sprite?(a.battler_sprite(b))
      end
      entries = [foes]
    end

    a[:groups] = entries.map do |battlers|
      positions = battlers.map do |b|
        sprite = a.battler_sprite(b)
        cx, cy = a.center(b)
        floor = sprite.y +
                (sprite.src_rect.height - sprite.oy) * sprite.zoom_y
        [cx, cy, floor]
      end

      if positions.empty?
        positions = [[
          Graphics.width * (a.user.index.even? ? 0.70 : 0.30),
          Graphics.height * 0.45,
          Graphics.height * (a.user.index.even? ? 0.49 : 0.75)
        ]]
      end

      cx = positions.inject(0.0) { |s, p| s + p[0] } / positions.length
      cy = positions.inject(0.0) { |s, p| s + p[1] } / positions.length
      floor = positions.inject(0.0) { |s, p| s + p[2] } / positions.length
      span = positions.map { |p| p[0] }.max -
             positions.map { |p| p[0] }.min

      radius = activation ? 78 : [span / 2.0 + 95, 112].max
      radius = [radius, Graphics.width * 0.43].min

      covers = battlers.map do |b|
        sprite = a.battler_sprite(b)
        next unless sprite.visible && sprite.opacity > 0
        a.copy(b, hide_original: true, z: 20_018)
      end.compact

      fog = Array.new(28) do |i|
        # Búi phía trước và phía sau tạo chiều sâu quanh chân.
        a.sprite(clouds[i % 2], z: i.even? ? 20_013 : 20_021)
      end

      g = {
        x: cx, y: cy, floor: floor, radius: radius,
        covers: covers,
        fog: fog,
        eyes: a.sprite(eyes, z: activation ? 20_016 : 20_024),
        motes: Array.new(10) { a.sprite(mote, z: 20_025) }
      }

      if activation
        body = covers.first
        g[:body] = body
        if body
          g[:base_x] = body.x
          g[:base_y] = body.y
          g[:color] = body.color.clone
        end

        g[:helix] = Array.new(28) do |i|
          a.sprite(clouds[i % 2], z: 20_023)
        end
        g[:rays] = Array.new(12) { a.sprite(ray, z: 20_030) }
      end
      g
    end

    if activation
      a.sound_at(0.02, ["PRSFX- Haze"], 40, 110)
      a.sound_at(0.35, ["PRSFX- Nightmare"], 45, 115)
      a.sound_at(0.72, ["PRSFX- Dark Pulse1"], 60, 80)
    else
      source = a.battler_sprite
      ux, _uy = a.center
      floor = source.y +
              (source.src_rect.height - source.oy) * source.zoom_y
      direction = a[:groups].first[:x] >= ux ? 1 : -1

      a[:sx] = ux + direction * 25
      a[:sy] = floor - 10
      a[:source] = Array.new(8) do |i|
        a.sprite(clouds[i % 2], z: 20_023)
      end
      a[:streams] = Array.new(42) do |i|
        a.sprite(clouds[i % 2], z: 20_015)
      end

      a.sound_at(0.03, ["PRSFX- Ominous Wind"], 50, 80)
      a.sound_at(0.64, ["PRSFX- Haze"], 40, 95)
    end
  end

  #-----------------------------------------------------------------------------
  # Lớp sương thấp dùng chung cho cả hai pha
  #-----------------------------------------------------------------------------
  def fog(a, g, visibility, spread, clock)
    g[:fog].each_with_index do |cloud, i|
      theta = i * 2.399
      radial = 0.28 + (i % 7) / 9.0
      roll = Math.sin(clock * (1.4 + i % 3 * 0.27) + i) * 5

      cloud.x = g[:x] +
                Math.cos(theta) * g[:radius] * radial * spread +
                roll
      cloud.y = g[:floor] - 7 +
                Math.sin(theta) * 15 * radial * spread -
                Math.cos(clock * 1.8 + i) * 3

      scale = 0.48 + i % 4 * 0.12
      cloud.zoom_x = scale * (0.85 + spread * 0.30) +
                     Math.sin(clock * 1.3 + i) * 0.035
      cloud.zoom_y = scale * 0.52 +
                     Math.cos(clock * 1.7 + i) * 0.025
      cloud.angle = Math.sin(clock + i) * 8
      cloud.opacity = (visibility * (170 + i % 3 * 20)).to_i
    end
  end

  #-----------------------------------------------------------------------------
  # ĐẶT SƯƠNG — 2 giây
  #-----------------------------------------------------------------------------
  def place(a)
    sec = a.seconds
    g = a[:groups].first

    # Cụm khói cuộn trước người dùng.
    source_in = a.clamp(sec / 0.20)
    source_out = a.clamp((0.75 - sec) / 0.36)

    a[:source].each_with_index do |cloud, i|
      theta = i * 2.399 + sec * 1.8
      cloud.x = a[:sx] + Math.cos(theta) * 11
      cloud.y = a[:sy] + Math.sin(theta) * 5
      cloud.zoom_x = 0.32 + source_in * 0.19 + i % 3 * 0.06
      cloud.zoom_y = cloud.zoom_x * 0.72
      cloud.opacity = (source_in * source_out * 195).to_i
    end

    # Ba dải sương gồm các búi khói, không kéo giãn thành tia.
    a[:streams].each_with_index do |cloud, i|
      lane = i / 14 - 1
      slot = i % 14
      duration = 0.66 + lane * 0.035
      q = (sec - 0.16 - slot * 0.025) / duration
      p = a.clamp(q)

      bend = Math.sin(p * Math::PI) *
             (lane * 18 + Math.sin(p * 5 - sec * 3 + lane) * 6)

      cloud.x = a.lerp(a[:sx], g[:x], p) + bend * 0.45
      cloud.y = a.lerp(a[:sy], g[:floor] - 9, p) +
                bend * 0.35 + lane * 5
      cloud.zoom_x = 0.28 + p * 0.24 + slot % 3 * 0.045
      cloud.zoom_y = cloud.zoom_x * 0.57
      cloud.angle = lane * 9 + Math.sin(sec * 2 + slot) * 7
      cloud.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 205).to_i : 0
    end

    form = a.clamp((sec - 0.60) / 0.48)
    form = form * form * (3.0 - 2.0 * form)
    fade = a.clamp((2.00 - sec) / 0.43)
    fog(a, g, form * fade, 0.30 + form * 0.70, sec)

    # Mắt mở thoáng qua trong sương.
    open = a.clamp((sec - 1.18) / 0.12) *
           a.clamp((1.67 - sec) / 0.21)
    eyes = g[:eyes]
    eyes.x = g[:x]
    eyes.y = g[:floor] - 19
    eyes.zoom_x = 0.76
    eyes.zoom_y = open * 0.55
    eyes.opacity = (open * 190).to_i

    g[:motes].each_with_index do |mote, i|
      theta = i * 2.399 + sec * 0.45
      mote.x = g[:x] + Math.cos(theta) * g[:radius] * 0.58
      mote.y = g[:floor] - 11 + Math.sin(theta) * 10
      mote.zoom_x = 0.16 + i % 3 * 0.06
      mote.zoom_y = mote.zoom_x
      mote.opacity = (
        form * fade * (45 + Math.sin(sec * 5 + i).abs * 60)
      ).to_i
    end
  end

  #-----------------------------------------------------------------------------
  # KÍCH HOẠT — 1,5 giây
  #-----------------------------------------------------------------------------
  def trigger(a)
    sec = a.seconds
    reveal = a.clamp(sec / 0.12)
    fade = a.clamp((1.50 - sec) / 0.23)

    a[:groups].each do |g|
      cx = g[:x]
      cy = g[:y]
      floor = g[:floor]

      fog(a, g, reveal * fade, 1.0, sec * 1.5)

      rise = a.clamp((sec - 0.10) / 0.34)
      squeeze = a.clamp((sec - 0.42) / 0.28)
      release = a.clamp((sec - 0.79) / 0.25)
      settle = a.clamp((sec - 0.98) / 0.30)
      height = [[floor - cy + 35, 64].max, 130].min

      # Hai dải xoắn; sprite đổi lớp khi đi ra trước/sau cơ thể.
      g[:helix].each_with_index do |cloud, i|
        arm = i / 14
        u = (i % 14) / 13.0
        theta = arm * Math::PI + u * Math::PI * 3.2 + sec * 4.2
        radius = 43 - squeeze * 25 + release * 22
        depth = Math.sin(theta)

        cloud.x = cx + Math.cos(theta) * radius
        cloud.y = floor - 8 -
                  rise * (1.0 - u) * height * (1.0 - settle)
        cloud.z = depth > 0 ? 20_024 : 20_014
        cloud.zoom_x = 0.30 + i % 4 * 0.065 + release * 0.10
        cloud.zoom_y = cloud.zoom_x * 0.76
        cloud.angle = Math.cos(theta) * 12
        cloud.opacity = (
          rise * (1.0 - settle) * (170 + depth * 25)
        ).to_i
      end

      # Đôi mắt lóe phía sau mục tiêu.
      eye_flash = a.clamp((sec - 0.46) / 0.10) *
                  a.clamp((0.99 - sec) / 0.20)
      eyes = g[:eyes]
      eyes.x = cx
      eyes.y = cy - 12
      eyes.zoom_x = 1.12
      eyes.zoom_y = eye_flash * 0.80
      eyes.opacity = (eye_flash * 255).to_i

      # Nhịp tối đánh dấu thời điểm sương siết.
      age = sec - 0.70
      pulse = age.between?(0.0, 0.20) ?
        Math.sin(age / 0.20 * Math::PI) : 0.0

      if g[:body]
        body = g[:body]
        body.x = g[:base_x]
        body.y = g[:base_y]
        body.color = pulse > 0 ?
          Color.new(30, 13, 43, (pulse * 170).to_i) : g[:color]
      end

      # Tia tím ngắn bung tại tâm, không giống vụ nổ sát thương.
      g[:rays].each_with_index do |ray, i|
        q = (sec - 0.72) / 0.23
        p = a.clamp(q)
        theta = i * Math::PI * 2 / 12

        ray.x = cx + Math.cos(theta) * (6 + p * 24)
        ray.y = cy + Math.sin(theta) * (6 + p * 21)
        ray.angle = -theta * 180 / Math::PI
        ray.zoom_x = 0.20 + Math.sin(p * Math::PI) * 0.35
        ray.zoom_y = 0.40
        ray.opacity = q.between?(0.0, 1.0) ?
          (Math.sin(p * Math::PI) * 225).to_i : 0
      end

      g[:motes].each_with_index do |mote, i|
        theta = i * 2.399 + sec
        mote.x = cx + Math.cos(theta) * (18 + release * 24)
        mote.y = cy + Math.sin(theta) * 20 + settle * 30
        mote.zoom_x = 0.16 + i % 3 * 0.06
        mote.zoom_y = mote.zoom_x
        mote.opacity = (eye_flash * (70 + i % 3 * 25)).to_i
      end
    end
  end
end

#===============================================================================
# Hai pha dùng chung ID, phân biệt bằng hit.
#===============================================================================

KaitoAnimation.register(
  :DARKMIST,
  duration: 2.00,
  hit: 0,
  require_target: false,
  setup: proc { |a| KaitoDarkMistVisual.setup(a, false) }
) do |a, _t|
  KaitoDarkMistVisual.place(a)
end

KaitoAnimation.register(
  :DARKMIST,
  duration: 1.50,
  hit: 1,
  setup: proc { |a| KaitoDarkMistVisual.setup(a, true) }
) do |a, _t|
  KaitoDarkMistVisual.trigger(a)
end