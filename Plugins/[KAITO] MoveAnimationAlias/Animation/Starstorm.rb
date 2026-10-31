#===============================================================================
# STARSTORM — Bão sao Fairy
# Yêu cầu: 000_AnimationCore.rb
#===============================================================================

module KaitoStarstormVisual
  module_function

  def star_points(cx, cy, outer, inner)
    Array.new(10) do |i|
      angle = -Math::PI / 2 + i * Math::PI / 5
      radius = i.even? ? outer : inner
      [cx + Math.cos(angle) * radius,
       cy + Math.sin(angle) * radius]
    end
  end

  def curve(start, control, finish, p)
    q = 1.0 - p
    [
      q * q * start[0] + 2 * q * p * control[0] + p * p * finish[0],
      q * q * start[1] + 2 * q * p * control[1] + p * p * finish[1]
    ]
  end

  # Khôi phục camera kể cả khi animation gặp lỗi giữa chừng.
  module SceneHooks
    def pbAnimation(move_id, user, targets, hit_num = 0)
      return super unless move_id == :STARSTORM

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
  :STARSTORM,
  duration: 3.40,
  setup: proc do |a|
    a.sound_at(0.03, ["PRSFX- Cosmic Power"], 55, 110)
    a.sound_at(0.64, ["PRSFX- Fairy Wind"], 60, 115)
    a.sound_at(1.05, ["PRSFX- Meteor Mash1"], 50, 120)
    a.sound_at(1.52, ["PRSFX- Meteor Mash1"], 60, 130)
    a.sound_at(1.86, ["PRSFX- Moonblast1"], 65, 110)
    a.sound_at(2.30, ["PRSFX- Moonblast2"], 85, 105)
    a.sound_at(2.62, ["PRSFX- Dazzling Gleam"], 45, 120)

    width = Graphics.width
    height = Graphics.height

    #---------------------------------------------------------------------------
    # Nền tím lam
    #---------------------------------------------------------------------------
    veil = a.bitmap(width, height) do |b|
      b.fill_rect(0, 0, width, height, Color.new(29, 20, 62))
    end
    a[:veil] = a.sprite(veil, z: 20_000, centered: false)

    #---------------------------------------------------------------------------
    # Sao năm cánh: viền hồng, thân kem, tâm trắng ngọc trai
    #---------------------------------------------------------------------------
    star_colors = [
      Color.new(255, 222, 237, 255),
      Color.new(255, 239, 178, 255)
    ]

    stars = star_colors.map do |color|
      a.bitmap(72, 72) do |b|
        # Quầng sáng mềm, không che mất hình sao.
        72.times do |y|
          72.times do |x|
            r = Math.sqrt((x - 35.5)**2 + (y - 35.5)**2)
            next if r > 35
            alpha = ((1.0 - r / 35.0)**2 * 65).to_i
            b.set_pixel(x, y, Color.new(255, 190, 224, alpha))
          end
        end

        a.polygon(
          b,
          KaitoStarstormVisual.star_points(36, 36, 28, 12),
          Color.new(237, 159, 210, 250)
        )
        a.polygon(
          b,
          KaitoStarstormVisual.star_points(36, 36, 24, 10),
          color
        )
        a.polygon(
          b,
          KaitoStarstormVisual.star_points(36, 36, 16, 7),
          Color.new(255, 253, 244, 255)
        )
      end
    end

    # Sao bốn cánh trong ngân hà.
    twinkle = a.bitmap(24, 24) do |b|
      a.polygon(
        b,
        [[12, 0], [15, 8], [24, 12], [15, 15],
         [12, 24], [8, 15], [0, 12], [8, 8]],
        Color.new(246, 241, 255, 245)
      )
    end

    #---------------------------------------------------------------------------
    # Quầng sáng dùng cho ngân hà và vụ nổ
    #---------------------------------------------------------------------------
    glow = a.bitmap(128, 128) do |b|
      128.times do |y|
        128.times do |x|
          r = Math.sqrt((x - 63.5)**2 + (y - 63.5)**2) / 63.0
          next if r > 1.0

          alpha = ((1.0 - r)**2 * 140).to_i
          b.set_pixel(x, y, Color.new(237, 169, 232, alpha))
        end
      end
    end

    # Đuôi sao: hồng bên ngoài, vàng kem bên trong.
    trail = a.bitmap(120, 24) do |b|
      a.polygon(
        b,
        [[0, 12], [91, 1], [119, 12], [91, 23]],
        Color.new(244, 164, 214, 125)
      )
      a.polygon(
        b,
        [[18, 12], [98, 6], [119, 12], [98, 17]],
        Color.new(255, 226, 166, 195)
      )
      a.polygon(
        b,
        [[48, 12], [105, 10], [119, 12], [105, 14]],
        Color.new(255, 251, 234, 230)
      )
    end

    impact_ring = a.ring(30, Color.new(255, 222, 240, 230), 2)
    burst_ring = a.ring(70, Color.new(255, 232, 247, 250), 4)

    #---------------------------------------------------------------------------
    # Các đốm sáng gọi sao từ sân đấu
    #---------------------------------------------------------------------------
    a[:gather] = Array.new(26) do
      a.sprite(twinkle, z: 20_023)
    end

    launch_times = [
      0.66, 0.80, 0.93, 1.05, 1.16, 1.26, 1.35,
      1.43, 1.50, 1.56, 1.62, 1.67, 1.72, 1.77
    ]

    a[:groups] = a.targets.map do |target|
      cx, cy = a.center(target)
      gx = [[cx + 12, 66].max, width - 66].min
      gy = [cy - 112, 54].max

      body = a.copy(target, hide_original: true, z: 20_017)

      specs = launch_times.each_with_index.map do |time, i|
        {
          time: time,
          duration: 0.35 + i % 3 * 0.025,
          size: [0.40, 0.58, 0.34, 0.66][i % 4],
          start: [gx - 85 + i % 5 * 21, gy - 12],
          control: [gx - 5 + i % 4 * 13, gy + 25],
          finish: [
            cx + Math.sin(i * 2.399) * 36,
            cy + Math.cos(i * 2.399) * 23
          ],
          large: false
        }
      end

      # Ba sao lớn đến gần như cùng lúc.
      3.times do |i|
        specs << {
          time: [1.80, 1.85, 1.90][i],
          duration: [0.40, 0.36, 0.33][i],
          size: [0.94, 1.10, 0.98][i],
          start: [gx + [-110, -10, 100][i], gy - 18],
          control: [gx + [-38, 28, 65][i], gy + 24],
          finish: [cx + [-20, 0, 20][i], cy + [7, -5, 7][i]],
          large: true
        }
      end

      meteors = specs.each_with_index.map do |spec, i|
        spec.merge(
          sprite: a.sprite(stars[i % 2], z: 20_030),
          trail: a.sprite(trail, z: 20_028),
          glitter: Array.new(3) do |j|
            a.sprite(stars[(i + j) % 2], z: 20_029)
          end,
          ring: a.sprite(impact_ring, z: 20_032)
        )
      end

      {
        x: cx, y: cy,
        gx: gx, gy: gy,
        body: body,
        base_x: body.x, base_y: body.y,
        color: body.color.clone,
        galaxy_glow: a.sprite(glow, z: 20_020),
        spiral: Array.new(30) { a.sprite(twinkle, z: 20_022) },
        twinkles: Array.new(6) { a.sprite(twinkle, z: 20_025) },
        meteors: meteors,
        giant_glow: a.sprite(glow, z: 20_035),
        giant: a.sprite(stars[1], z: 20_036),
        rings: Array.new(2) { a.sprite(burst_ring, z: 20_037) },
        dust: Array.new(52) do |i|
          a.sprite(stars[i % 2], z: 20_039)
        end
      }
    end

    flash = a.bitmap(width, height) do |b|
      b.fill_rect(0, 0, width, height, Color.new(255, 239, 250))
    end
    a[:flash] = a.sprite(flash, z: 20_050, centered: false)

    # Camera được khôi phục bởi SceneHooks ở cuối animation.
    viewport = a.instance_variable_get(:@viewport)
    a[:viewport] = viewport
    a[:camera_x] = viewport.ox
    a[:camera_y] = viewport.oy
  end
) do |a, _t|
  sec = a.seconds

  #=============================================================================
  # 1. GỌI SAO — Nền lavender, ánh sáng bay lên
  #=============================================================================
  night = a.clamp(sec / 0.35) *
          a.clamp((3.40 - sec) / 0.65)
  a[:veil].opacity = (night * 105).to_i

  first = a[:groups].first
  a[:gather].each_with_index do |spark, i|
    q = (sec - i % 7 * 0.035) / 0.65
    p = a.clamp(q)
    start_x = first[:gx] + Math.sin(i * 2.399) * 105
    start_y = first[:gy] + 85 + i % 4 * 18

    spark.x = a.lerp(start_x, first[:gx], p)
    spark.y = a.lerp(start_y, first[:gy], p)
    spark.angle = i * 31 + p * 55
    spark.zoom_x = 0.22 + i % 3 * 0.12
    spark.zoom_y = spark.zoom_x
    spark.opacity = q.between?(0.0, 1.0) ?
      (Math.sin(p * Math::PI) * 235).to_i : 0
  end

  final_flash = a.clamp((sec - 2.30) / 0.035) *
                a.clamp((2.52 - sec) / 0.18)
  a[:flash].opacity = (final_flash * 105).to_i

  a[:groups].each do |g|
    cx = g[:x]
    cy = g[:y]
    gx = g[:gx]
    gy = g[:gy]

    # Ngân hà giữ trên cao, khép dần ở cuối.
    galaxy_in = a.clamp((sec - 0.12) / 0.43)
    galaxy_out = a.clamp((3.35 - sec) / 0.55)
    galaxy_size = galaxy_in * (0.15 + galaxy_out * 0.85)

    glow = g[:galaxy_glow]
    glow.x = gx
    glow.y = gy
    glow.zoom_x = galaxy_size * 1.55
    glow.zoom_y = galaxy_size * 0.65
    glow.opacity = (galaxy_in * galaxy_out * 210).to_i

    g[:spiral].each_with_index do |spark, i|
      arm = i % 2
      u = (i / 2) / 14.0
      theta = u * Math::PI * 3.0 + sec * 1.55 + arm * Math::PI
      radius = (8 + u * 55) * galaxy_size

      spark.x = gx + Math.cos(theta) * radius
      spark.y = gy + Math.sin(theta) * radius * 0.38
      spark.angle = -sec * 35 + i * 19
      spark.zoom_x = 0.14 + u * 0.15
      spark.zoom_y = spark.zoom_x
      spark.opacity = (
        galaxy_in * galaxy_out * (150 + Math.sin(sec * 6 + i) * 55)
      ).to_i
    end

    g[:twinkles].each_with_index do |spark, i|
      theta = i * 2.399 + sec * 0.22
      spark.x = gx + Math.cos(theta) * (15 + i % 3 * 16) * galaxy_size
      spark.y = gy + Math.sin(theta) * (8 + i % 3 * 6) * galaxy_size
      spark.zoom_x = 0.30 + (Math.sin(sec * 5 + i).abs * 0.28)
      spark.zoom_y = spark.zoom_x
      spark.angle = sec * 12
      spark.opacity = (galaxy_in * galaxy_out * 230).to_i
    end

    #===========================================================================
    # 2. BÃO SAO — Quỹ đạo cong, nhịp rơi tăng dần
    #===========================================================================
    small_flash = 0.0

    g[:meteors].each_with_index do |meteor, i|
      age = sec - meteor[:time]
      q = age / meteor[:duration]
      p = a.clamp(q)
      point = KaitoStarstormVisual.curve(
        meteor[:start], meteor[:control], meteor[:finish], p
      )

      active = q.between?(0.0, 1.0)
      star = meteor[:sprite]
      star.x = point[0]
      star.y = point[1]
      star.angle = i * 29 + p * 85
      star.zoom_x = meteor[:size]
      star.zoom_y = meteor[:size]
      star.opacity = active ? 255 : 0

      # Vệt đuôi theo tiếp tuyến đường cong.
      previous = KaitoStarstormVisual.curve(
        meteor[:start], meteor[:control], meteor[:finish],
        [p - 0.08, 0].max
      )
      dx = point[0] - previous[0]
      dy = point[1] - previous[1]
      length = [Math.sqrt(dx * dx + dy * dy), 0.01].max

      trail = meteor[:trail]
      trail.x = point[0] - dx / length * 25 * meteor[:size]
      trail.y = point[1] - dy / length * 25 * meteor[:size]
      trail.angle = -Math.atan2(dy, dx) * 180 / Math::PI
      trail.zoom_x = meteor[:large] ? 0.90 : 0.65
      trail.zoom_y = meteor[:size] * 0.70
      trail.opacity = active && p > 0.04 ? 195 : 0

      # Kim tuyến là những sao nhỏ riêng biệt dọc đuôi.
      meteor[:glitter].each_with_index do |spark, j|
        tail_p = p - 0.08 * (j + 1)
        pos = KaitoStarstormVisual.curve(
          meteor[:start], meteor[:control], meteor[:finish],
          a.clamp(tail_p)
        )

        spark.x = pos[0] + Math.sin(i + j * 2.4) * 4
        spark.y = pos[1] + Math.cos(i + j * 2.4) * 4
        spark.angle = sec * 95 + j * 31
        spark.zoom_x = (0.15 - j * 0.025) *
                       (meteor[:large] ? 1.35 : 1.0)
        spark.zoom_y = spark.zoom_x
        spark.opacity = active && tail_p > 0 ?
          (190 - j * 35) : 0
      end

      # Gợn sáng nhỏ tại từng điểm chạm.
      hit_age = age - meteor[:duration]
      impact_p = a.clamp(hit_age / 0.23)
      ring = meteor[:ring]
      ring.x = meteor[:finish][0]
      ring.y = meteor[:finish][1]
      ring.zoom_x = 0.12 + impact_p * (meteor[:large] ? 1.10 : 0.65)
      ring.zoom_y = ring.zoom_x * 0.72
      ring.opacity = hit_age.between?(0.0, 0.23) ?
        ((1.0 - impact_p) * 170).to_i : 0

      if hit_age.between?(0.0, 0.10)
        small_flash = [
          small_flash,
          (1.0 - hit_age / 0.10) * 0.24
        ].max
      end
    end

    #===========================================================================
    # 3. CAO TRÀO — Ba sao hợp thành sao khổng lồ
    #===========================================================================
    merge = a.clamp((sec - 2.20) / 0.12)
    burst = a.clamp((sec - 2.32) / 0.30)
    giant_fade = a.clamp((2.65 - sec) / 0.30)

    giant = g[:giant]
    giant.x = cx
    giant.y = cy
    giant.angle = 8 - merge * 8
    giant.zoom_x = 0.60 + merge * 1.65 + burst * 0.75
    giant.zoom_y = giant.zoom_x
    giant.opacity = (merge * giant_fade * 255).to_i

    glow = g[:giant_glow]
    glow.x = cx
    glow.y = cy
    glow.zoom_x = 0.45 + merge * 1.20 + burst * 1.15
    glow.zoom_y = glow.zoom_x
    glow.opacity = (merge * giant_fade * 245).to_i

    g[:rings].each_with_index do |ring, i|
      q = (sec - 2.31 - i * 0.055) / 0.43
      p = a.clamp(q)

      ring.x = cx
      ring.y = cy
      ring.zoom_x = 0.22 + p * (i == 0 ? 2.25 : 1.85)
      ring.zoom_y = ring.zoom_x * (i == 0 ? 0.77 : 0.40)
      ring.opacity = q.between?(0.0, 1.0) ?
        ((1.0 - p) * 245).to_i : 0
    end

    flash = [small_flash, final_flash].max
    g[:body].color = flash > 0 ?
      Color.new(255, 249, 255, (flash * 225).to_i) : g[:color]

    #===========================================================================
    # 4. DƯ QUANG — Hàng chục sao rơi nhẹ rồi tan
    #===========================================================================
    g[:dust].each_with_index do |spark, i|
      q = (sec - 2.35 - i % 7 * 0.018) / 0.88
      p = a.clamp(q)
      theta = i * 2.399
      radius = 25 + i % 7 * 12
      spread = 1.0 - (1.0 - p)**3

      spark.x = cx + Math.cos(theta) * radius * spread +
                Math.sin(p * 3 + i) * 4
      spark.y = cy + Math.sin(theta) * radius * spread * 0.60 +
                p * p * 54
      spark.angle = i * 27 + p * (i.even? ? 55 : -55)
      spark.zoom_x = (0.12 + i % 4 * 0.055) * (1.0 - p * 0.30)
      spark.zoom_y = spark.zoom_x
      spark.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 245).to_i : 0
    end
  end

  #=============================================================================
  # RUNG TOÀN SÂN — Một nhịp mạnh, giảm nhanh rồi khôi phục
  #=============================================================================
  viewport = a[:viewport]
  unless viewport.disposed?
    age = sec - 2.31
    shake = age.between?(0.0, 0.22) ?
      (1.0 - age / 0.22)**2 : 0.0

    viewport.ox = a[:camera_x] + Math.sin(age * 130) * shake * 9
    viewport.oy = a[:camera_y] + Math.cos(age * 105) * shake * 5
  end
end

unless Battle::Scene.ancestors.include?(KaitoStarstormVisual::SceneHooks)
  Battle::Scene.prepend(KaitoStarstormVisual::SceneHooks)
end