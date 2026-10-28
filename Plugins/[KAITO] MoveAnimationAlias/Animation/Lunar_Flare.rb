#===============================================================================
# LUNAR FLARE — Nguyệt diễm
# Yêu cầu: 000_AnimationCore.rb
#===============================================================================

KaitoAnimation.register(
  :LUNARFLARE,
  duration: 3.0,
  setup: proc do |a|
    a.sound_at(0.05, ["PRSFX- Energy Ball1"], 50, 115)
    a.sound_at(0.92, ["PRSFX- Magic Coat"], 55, 120)
    a.sound_at(1.22, ["PRSFX- Flame Burst"], 55, 120)
    a.sound_at(1.65, ["PRSFX- Flamethrower"], 85, 105)
    a.sound_at(2.20, ["PRSFX- Aqua Ring2"], 40, 120)

    width = Graphics.width
    height = Graphics.height
    a[:width] = width
    a[:height] = height

    ux, uy = a.center
    a[:ux] = ux
    a[:uy] = uy
    a[:mx] = [[ux, 58].max, width - 58].min
    a[:my] = [uy - 96, 54].max

    #---------------------------------------------------------------------------
    # Sân đấu tối nhẹ
    #---------------------------------------------------------------------------
    veil = a.bitmap(width, height) do |b|
      b.fill_rect(0, 0, width, height, Color.new(12, 14, 39))
    end
    a[:veil] = a.sprite(veil, z: 20_000, centered: false)

    #---------------------------------------------------------------------------
    # Trăng khuyết thật sự có phần khuyết trong suốt
    #---------------------------------------------------------------------------
    crescent = a.bitmap(96, 96) do |b|
      96.times do |y|
        96.times do |x|
          outer = Math.sqrt((x - 47.5)**2 + (y - 47.5)**2)
          cut = Math.sqrt((x - 64.5)**2 + (y - 40.5)**2)
          next if outer > 40 || cut < 36

          color = outer > 36 || cut < 39 ?
            Color.new(167, 180, 246, 245) :
            Color.new(244, 251, 255, 255)

          b.set_pixel(x, y, color)
        end
      end
    end

    moon_ring = a.ring(40, Color.new(225, 249, 255, 250), 3)
    halo_ring = a.ring(46, Color.new(148, 158, 243, 170), 2)

    a[:moon] = a.sprite(crescent, z: 20_026)
    a[:moon_ring] = a.sprite(moon_ring, z: 20_027)
    a[:moon_halo] = a.sprite(halo_ring, z: 20_025)

    #---------------------------------------------------------------------------
    # Bụi sao bạc
    #---------------------------------------------------------------------------
    star = a.bitmap(18, 18) do |b|
      a.polygon(
        b,
        [[9, 0], [11, 6], [18, 9], [11, 11],
         [9, 18], [6, 11], [0, 9], [6, 6]],
        Color.new(219, 238, 255, 245)
      )
      b.fill_rect(7, 7, 4, 4, Color.new(255, 255, 255, 255))
    end
    a[:gather] = Array.new(28) { a.sprite(star, z: 20_028) }

    #---------------------------------------------------------------------------
    # Tia nguyệt quang mảnh
    #---------------------------------------------------------------------------
    beam = a.bitmap(12, 100) do |b|
      b.fill_rect(0, 0, 12, 100, Color.new(125, 130, 234, 80))
      b.fill_rect(4, 0, 4, 100, Color.new(189, 225, 255, 210))
      b.fill_rect(5, 0, 2, 100, Color.new(255, 255, 255, 255))
    end

    #---------------------------------------------------------------------------
    # Cột lửa: viền xanh tím, thân bạc và lõi trắng
    #---------------------------------------------------------------------------
    flame = a.bitmap(144, 240) do |b|
      a.polygon(
        b,
        [[20, 239], [8, 211], [19, 183], [14, 155],
         [33, 121], [29, 92], [52, 58], [47, 27],
         [70, 0], [63, 38], [77, 63], [86, 36],
         [102, 17], [95, 57], [108, 87], [104, 118],
         [126, 148], [121, 180], [139, 207], [126, 239]],
        Color.new(115, 111, 218, 220)
      )
      a.polygon(
        b,
        [[29, 239], [19, 211], [30, 180], [27, 154],
         [45, 122], [42, 94], [62, 62], [60, 35],
         [69, 63], [79, 89], [94, 67], [91, 99],
         [96, 124], [113, 153], [109, 182], [126, 211],
         [118, 239]],
        Color.new(187, 214, 252, 245)
      )
      a.polygon(
        b,
        [[44, 239], [35, 211], [46, 184], [42, 158],
         [61, 124], [57, 102], [72, 77], [77, 110],
         [87, 133], [84, 159], [101, 189], [107, 218],
         [98, 239]],
        Color.new(249, 253, 255, 255)
      )
    end

    wave = a.ring(68, Color.new(205, 235, 255, 240), 4)

    a[:groups] = a.targets.map do |target|
      original = a.battler_sprite(target)
      cx, cy = a.center(target)
      ground = original.y +
               (original.src_rect.height - original.oy) * original.zoom_y

      body = a.copy(target, hide_original: true, z: 20_015)
      ray = a.sprite(beam, z: 20_029, centered: false)
      ray.ox = 6

      columns = Array.new(3) do
        s = a.sprite(flame, z: 20_031)
        s.ox = 72
        s.oy = 240
        s
      end

      {
        x: cx, y: cy, ground: ground,
        body: body, color: body.color.clone,
        beam: ray,
        columns: columns,
        tips: Array.new(5) { a.sprite(crescent, z: 20_033) },
        wave: a.sprite(wave, z: 20_034),
        stars: Array.new(36) { a.sprite(star, z: 20_036) },
        echo: a.sprite(crescent, z: 20_012)
      }
    end

    flash = a.bitmap(width, height) do |b|
      b.fill_rect(0, 0, width, height, Color.new(228, 239, 255))
    end
    a[:flash] = a.sprite(flash, z: 20_070, centered: false)

    # Ảnh toàn cảnh dùng cho nhịp rung; core tự giải phóng khi kết thúc.
    a[:shake_bitmap] = a.bitmap(width, height)
    a[:shake] = a.sprite(a[:shake_bitmap], z: 20_060)
    a[:shake].zoom_x = 1.04
    a[:shake].zoom_y = 1.04
    a[:shake_captured] = false
  end
) do |a, _t|
  sec = a.seconds
  mx = a[:mx]
  my = a[:my]

  #=============================================================================
  # 1. TRĂNG HIỆN — Hạt bạc hội tụ
  #=============================================================================
  appear = a.clamp(sec / 0.32)
  moon_fade = a.clamp((1.45 - sec) / 0.35)
  close = a.clamp((sec - 0.66) / 0.34)

  a[:veil].opacity = (
    appear * a.clamp((2.94 - sec) / 0.65) * 78
  ).to_i

  moon = a[:moon]
  moon.x = mx
  moon.y = my
  moon.zoom_x = 0.72 + appear * 0.12
  moon.zoom_y = moon.zoom_x
  moon.opacity = (appear * moon_fade * 255).to_i

  ring = a[:moon_ring]
  ring.x = mx
  ring.y = my
  ring.zoom_x = 0.84
  ring.zoom_y = 0.84
  ring.opacity = (close * moon_fade * 255).to_i

  halo = a[:moon_halo]
  halo.x = mx
  halo.y = my
  halo.zoom_x = 0.76 + close * 0.25
  halo.zoom_y = halo.zoom_x
  halo.opacity = (close * moon_fade * 190).to_i

  a[:gather].each_with_index do |spark, i|
    q = (sec - i % 7 * 0.045) / 0.70
    p = a.clamp(q)
    start_x = a[:ux] + Math.sin(i * 2.399) * (35 + i % 4 * 12)
    start_y = a[:uy] + 15 + i % 4 * 10

    spark.x = a.lerp(start_x, mx, p) + Math.sin(p * Math::PI) * 8
    spark.y = a.lerp(start_y, my, p)
    spark.angle = i * 23 + p * 70
    spark.zoom_x = 0.20 + i % 3 * 0.12
    spark.zoom_y = spark.zoom_x
    spark.opacity = q.between?(0.0, 1.0) ?
      (Math.sin(p * Math::PI) * 235).to_i : 0
  end

  #=============================================================================
  # Nhịp lực: xuất hiện → co nhỏ → bùng mạnh
  #=============================================================================
  if sec < 1.44
    power = a.clamp((sec - 1.20) / 0.24) * 0.40
  elsif sec < 1.64
    power = a.lerp(0.40, 0.13, (sec - 1.44) / 0.20)
  elsif sec < 1.82
    p = a.clamp((sec - 1.64) / 0.18)
    power = a.lerp(0.13, 1.12, 1.0 - (1.0 - p)**3)
  else
    power = 1.12 * a.clamp((2.35 - sec) / 0.53)
  end

  flash_power = a.clamp((sec - 1.65) / 0.035) *
                a.clamp((1.87 - sec) / 0.18)
  a[:flash].opacity = (flash_power * 100).to_i

  a[:groups].each do |g|
    cx = g[:x]
    cy = g[:y]
    ground = g[:ground]

    #===========================================================================
    # 2. NÉN NGUYỆT QUANG — Tia sáng chạm chân mục tiêu
    #===========================================================================
    dx = cx - mx
    dy = ground - my
    distance = Math.sqrt(dx * dx + dy * dy)
    reach = a.clamp((sec - 0.99) / 0.23)
    ray_fade = a.clamp((1.53 - sec) / 0.25)

    ray = g[:beam]
    ray.x = mx
    ray.y = my
    ray.angle = 90 - Math.atan2(dy, dx) * 180 / Math::PI
    ray.zoom_y = distance / 100.0 * reach
    ray.zoom_x = 0.65
    ray.opacity = (reach * ray_fade * 240).to_i

    #===========================================================================
    # 3. BÙNG FLARE — Cột lửa trắng bạc, đầu ngọn hình lưỡi liềm
    #===========================================================================
    g[:columns].each_with_index do |column, i|
      side = i - 1
      column.x = cx + side * power * 17
      column.y = ground + 4
      column.zoom_x = power * (i == 1 ? 0.78 : 0.48)
      column.zoom_y = power * (i == 1 ? 1.0 : 0.79)
      column.angle = side * 7
      column.mirror = i == 2
      column.opacity = ([power * 300, 255].min *
                        (i == 1 ? 1.0 : 0.72)).to_i
    end

    g[:tips].each_with_index do |tip, i|
      burst = a.clamp((sec - 1.64) / 0.22)
      fade = a.clamp((2.30 - sec) / 0.38)
      side = i - 2

      tip.x = cx + side * burst * 23
      tip.y = ground - power * (135 + i % 3 * 24)
      tip.angle = side * 32 - 35
      tip.zoom_x = power * (0.24 + i % 2 * 0.09)
      tip.zoom_y = tip.zoom_x
      tip.opacity = (burst * fade * 205).to_i
    end

    body = g[:body]
    body.color = flash_power > 0 ?
      Color.new(248, 253, 255, (flash_power * 220).to_i) : g[:color]

    #===========================================================================
    # 4. DƯ QUANG — Vòng ngang, bụi sao và bóng trăng phía sau
    #===========================================================================
    q = (sec - 2.14) / 0.61
    p = a.clamp(q)

    wave = g[:wave]
    wave.x = cx
    wave.y = ground - 13
    wave.zoom_x = 0.28 + p * 1.95
    wave.zoom_y = wave.zoom_x * 0.24
    wave.opacity = q.between?(0.0, 1.0) ?
      ((1.0 - p) * 245).to_i : 0

    g[:stars].each_with_index do |spark, i|
      q = (sec - 2.12 - i % 6 * 0.018) / 0.70
      p = a.clamp(q)
      theta = i * 2.399

      spark.x = cx + Math.cos(theta) * (12 + p * (45 + i % 5 * 10))
      spark.y = cy + Math.sin(theta) * (16 + p * 30) +
                p * p * 35 - p * 18
      spark.angle = i * 31 + p * 60
      spark.zoom_x = (0.22 + i % 3 * 0.10) * (1.0 - p * 0.45)
      spark.zoom_y = spark.zoom_x
      spark.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 235).to_i : 0
    end

    echo_in = a.clamp((sec - 2.12) / 0.17)
    echo_out = a.clamp((2.96 - sec) / 0.42)
    echo = g[:echo]
    echo.x = cx
    echo.y = cy - 21
    echo.angle = -22
    echo.zoom_x = 1.12
    echo.zoom_y = 1.12
    echo.opacity = (echo_in * echo_out * 100).to_i
  end

  #=============================================================================
  # RUNG TOÀN CẢNH MỘT NHỊP
  # Chụp lúc flare đã bùng; rung ảnh phủ trong thời gian rất ngắn.
  #=============================================================================
  if sec >= 1.80 && !a[:shake_captured]
    shot = Graphics.snap_to_bitmap
    begin
      a[:shake_bitmap].blt(
        0, 0, shot,
        Rect.new(0, 0, a[:width], a[:height])
      )
    ensure
      shot.dispose
    end
    a[:shake_start] = sec
    a[:shake_captured] = true
  end

  shake = a[:shake]
  if a[:shake_captured]
    age = sec - a[:shake_start]
    envelope = a.clamp(1.0 - age / 0.14)

    shake.x = a[:width] / 2.0 + Math.sin(age * 125) * envelope * 5
    shake.y = a[:height] / 2.0 + Math.cos(age * 95) * envelope * 3
    shake.opacity = age < 0.14 ? 255 : 0
  end
end