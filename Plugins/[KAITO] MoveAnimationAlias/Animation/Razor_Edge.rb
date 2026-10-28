#===============================================================================
# RAZOR EDGE — Nhát chém cạnh thép
# Yêu cầu: 000_AnimationCore.rb
#===============================================================================

KaitoAnimation.register(
  :RAZOREDGE,
  duration: 1.35,
  setup: proc do |a|
    # Đọc bộ đếm sẵn có, không thay đổi cơ chế chiêu.
    uses = a.user.respond_to?(:kaito_razor_edge_uses) ?
      a.user.kaito_razor_edge_uses.to_i : 1
    dull = [[uses - 1, 0].max, 4].min
    a[:sharpness] = 1.0 - dull * 0.10

    a.sound_at(0.06, ["PRSFX- Metal Claw1"], 55, 120)
    a.sound_at(0.32, ["PRSFX- Metal Claw2"], 75, 110)
    a.sound_at(0.49, ["PRSFX- Iron Tail2"], 85, 110)

    ux, uy = a.center
    a[:origin] = [ux, uy]

    source = a.copy(a.user, hide_original: true, z: 20_016)
    a[:source] = source
    a[:source_x] = source.x
    a[:source_y] = source.y

    #---------------------------------------------------------------------------
    # Cạnh thép lóe trước khi ra đòn
    #---------------------------------------------------------------------------
    edge = a.bitmap(112, 18) do |b|
      a.polygon(
        b,
        [[0, 10], [75, 3], [111, 7], [34, 13]],
        Color.new(124, 191, 216, 210)
      )
      a.polygon(
        b,
        [[1, 10], [82, 6], [111, 7], [32, 11]],
        Color.new(245, 255, 255, 255)
      )
    end
    a[:edge] = a.sprite(edge, z: 20_029)

    #---------------------------------------------------------------------------
    # Lưỡi chém dài, mảnh, lõi trắng và viền bạc xanh
    #---------------------------------------------------------------------------
    blade = a.bitmap(248, 88) do |b|
      a.polygon(
        b,
        [[1, 79], [42, 46], [91, 24], [145, 10],
         [200, 5], [247, 11], [194, 18], [143, 30],
         [93, 47], [45, 66]],
        Color.new(63, 103, 131, 225)
      )
      a.polygon(
        b,
        [[2, 78], [48, 46], [99, 25], [153, 13],
         [205, 8], [245, 11], [190, 21], [137, 35],
         [83, 54]],
        Color.new(166, 224, 242, 250)
      )
      a.polygon(
        b,
        [[8, 74], [68, 39], [124, 21], [182, 11],
         [242, 11], [180, 17], [121, 29], [64, 48]],
        Color.new(250, 255, 255, 255)
      )
    end

    # Đường nối nhanh từ người dùng tới mục tiêu.
    streak = a.bitmap(160, 12) do |b|
      a.polygon(
        b,
        [[0, 6], [122, 0], [159, 6], [122, 11]],
        Color.new(172, 227, 244, 165)
      )
      a.polygon(
        b,
        [[7, 6], [130, 4], [159, 6], [130, 7]],
        Color.new(248, 255, 255, 245)
      )
    end

    #---------------------------------------------------------------------------
    # Tia kim loại: ngắn và sắc
    #---------------------------------------------------------------------------
    spark = a.bitmap(30, 8) do |b|
      a.polygon(
        b,
        [[0, 4], [22, 0], [29, 4], [22, 7]],
        Color.new(157, 222, 245, 240)
      )
      a.polygon(
        b,
        [[2, 4], [25, 2], [29, 4], [25, 5]],
        Color.new(255, 249, 206, 255)
      )
    end

    glint = a.bitmap(32, 32) do |b|
      a.polygon(
        b,
        [[16, 0], [19, 12], [32, 16], [19, 19],
         [16, 32], [12, 19], [0, 16], [12, 12]],
        Color.new(230, 253, 255, 255)
      )
    end

    a[:glint] = a.sprite(glint, z: 20_031)

    a[:groups] = a.targets.map do |target|
      cx, cy = a.center(target)
      copy = a.copy(target, hide_original: true, z: 20_017)

      {
        x: cx, y: cy,
        body: copy,
        base_x: copy.x, base_y: copy.y,
        color: copy.color.clone,
        streak: a.sprite(streak, z: 20_024),
        blades: Array.new(3) { a.sprite(blade, z: 20_030) },
        sparks: Array.new(28) { a.sprite(spark, z: 20_033) },
        glint: a.sprite(glint, z: 20_034)
      }
    end

    flash = a.bitmap(Graphics.width, Graphics.height) do |b|
      b.fill_rect(
        0, 0, b.width, b.height,
        Color.new(220, 245, 255)
      )
    end
    a[:flash] = a.sprite(flash, z: 20_050, centered: false)
  end
) do |a, _t|
  sec = a.seconds
  ux, uy = a[:origin]
  sharp = a[:sharpness]

  #=============================================================================
  # 1. LÓE CẠNH THÉP
  #=============================================================================
  charge = a.clamp(sec / 0.22)
  charge_fade = a.clamp((0.34 - sec) / 0.12)

  edge = a[:edge]
  edge.x = ux
  edge.y = uy - 5
  edge.angle = -24
  edge.zoom_x = 0.25 + charge * 0.85
  edge.zoom_y = 0.55 + charge * 0.35
  edge.opacity = (charge * charge_fade * sharp * 245).to_i

  glint = a[:glint]
  glint.x = ux + 31
  glint.y = uy - 18
  glint.angle = sec * 90
  glint.zoom_x = 0.25 + charge * 0.45
  glint.zoom_y = glint.zoom_x
  glint.opacity = (charge * charge_fade * sharp * 255).to_i

  # Người dùng lao nhẹ về phía mục tiêu rồi trở lại vị trí ban đầu.
  first = a[:groups].first
  if first
    dx = first[:x] - ux
    dy = first[:y] - uy
    distance = [Math.sqrt(dx * dx + dy * dy), 1.0].max
    forward = a.clamp((sec - 0.23) / 0.22)
    return_home = a.clamp((0.79 - sec) / 0.26)
    lunge = forward * return_home * 18

    a[:source].x = a[:source_x] + dx / distance * lunge
    a[:source].y = a[:source_y] + dy / distance * lunge
  end

  impact_age = sec - 0.49
  impact = impact_age.between?(0.0, 0.13) ?
    1.0 - impact_age / 0.13 : 0.0

  a[:flash].opacity = (impact * sharp * 65).to_i

  a[:groups].each do |g|
    cx = g[:x]
    cy = g[:y]
    direction = cx >= ux ? 1 : -1

    #===========================================================================
    # 2. LAO CHÉM — Vệt tốc độ nối hai Pokémon
    #===========================================================================
    q = (sec - 0.29) / 0.22
    p = a.clamp(q)
    dx = cx - ux
    dy = cy - uy
    distance = Math.sqrt(dx * dx + dy * dy)

    streak = g[:streak]
    streak.x = a.lerp(ux, cx, p)
    streak.y = a.lerp(uy, cy, p)
    streak.angle = -Math.atan2(dy, dx) * 180 / Math::PI
    streak.zoom_x = [distance / 160.0 * 0.52, 0.25].max
    streak.zoom_y = 0.55
    streak.opacity = q.between?(0.0, 1.0) ?
      (Math.sin(p * Math::PI) * sharp * 210).to_i : 0

    # Một nhát chém chính, hai dư ảnh sát nhau.
    g[:blades].each_with_index do |blade, i|
      q = (sec - 0.43 - i * 0.025) / 0.23
      p = a.clamp(q)

      blade.x = cx + direction * (-26 + p * 52)
      blade.y = cy + 15 - p * 32 + i * 3
      blade.angle = direction == 1 ? -26 : 26
      blade.mirror = direction == -1
      blade.zoom_x = 0.72 + p * 0.32
      blade.zoom_y = (0.62 + Math.sin(p * Math::PI) * 0.30) *
                     (1.0 - i * 0.13)
      blade.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * sharp * [255, 100, 55][i]).to_i : 0
    end

    #===========================================================================
    # 3. VA CHẠM — Lóe cạnh cắt và tia kim loại
    #===========================================================================
    glint = g[:glint]
    glint.x = cx
    glint.y = cy
    glint.angle = 20
    glint.zoom_x = 0.65 + impact * 1.15
    glint.zoom_y = glint.zoom_x * 0.75
    glint.opacity = (impact * sharp * 255).to_i

    g[:sparks].each_with_index do |spark, i|
      q = (sec - 0.49 - i % 4 * 0.012) / 0.43
      p = a.clamp(q)
      theta = i * 2.399
      travel = (1.0 - (1.0 - p)**2) * (30 + i % 6 * 10)

      spark.x = cx + Math.cos(theta) * travel
      spark.y = cy + Math.sin(theta) * travel * 0.72 + p * p * 16
      spark.angle = -theta * 180 / Math::PI
      spark.zoom_x = (0.28 + i % 4 * 0.13) * (1.0 - p * 0.65)
      spark.zoom_y = 0.30 + i % 3 * 0.12
      spark.opacity = q.between?(0.0, 1.0) ?
        ((1.0 - p) * sharp * 245).to_i : 0
    end

    # Phản lực ngắn trên bản sao mục tiêu.
    recoil = a.clamp((sec - 0.49) / 0.045) *
             a.clamp((0.78 - sec) / 0.24)

    body = g[:body]
    body.x = g[:base_x] + direction * recoil * 8 +
             Math.sin(sec * 105) * impact * 3
    body.y = g[:base_y] - recoil * 2
    body.color = impact > 0 ?
      Color.new(228, 249, 255, (impact * 170).to_i) : g[:color]
  end
end