#===============================================================================
# SUDDEN SPLASH — Nhảy bật sóng nước
# Yêu cầu: 000_AnimationCore.rb
#===============================================================================

KaitoAnimation.register(
  :SUDDENSPLASH,
  duration: 1.65,
  setup: proc do |a|
    a.sound_at(0.08, ["PRSFX- Agility"], 40, 125)
    a.sound_at(0.46, ["PRSFX- Aqua Ring2"], 55, 115)
    a.sound_at(0.53, ["PRSFX- Muddy Water"], 65, 120)
    a.sound_at(0.84, ["PRSFX- Bubble"], 65, 110)

    original = a.battler_sprite
    ux, uy = a.center
    ground = original.y +
             (original.src_rect.height - original.oy) * original.zoom_y

    a[:ux] = ux
    a[:uy] = uy
    a[:ground] = ground

    user_copy = a.copy(a.user, hide_original: true, z: 20_018)
    a[:user_copy] = user_copy
    a[:user_x] = user_copy.x
    a[:user_y] = user_copy.y

    #---------------------------------------------------------------------------
    # Sóng cuộn: xanh biển nhạt, bọt trắng ở đầu sóng
    #---------------------------------------------------------------------------
    wave = a.bitmap(136, 112) do |b|
      a.polygon(
        b,
        [[0, 109], [17, 94], [36, 78], [48, 56],
         [53, 33], [69, 13], [91, 3], [114, 8],
         [132, 27], [135, 43], [125, 57], [107, 61],
         [93, 52], [93, 40], [104, 32], [88, 31],
         [78, 45], [78, 61], [91, 79], [117, 96],
         [135, 109]],
        Color.new(83, 184, 231, 225)
      )
      a.polygon(
        b,
        [[4, 109], [37, 87], [58, 63], [62, 36],
         [76, 19], [94, 12], [112, 16], [126, 31],
         [127, 43], [117, 51], [106, 51], [99, 44],
         [111, 41], [113, 32], [103, 24], [88, 24],
         [73, 37], [70, 58], [79, 79], [103, 99]],
        Color.new(166, 235, 250, 240)
      )
      a.polygon(
        b,
        [[53, 35], [68, 13], [91, 3], [113, 8],
         [132, 26], [135, 41], [127, 54], [113, 59],
         [103, 54], [115, 50], [124, 41], [122, 30],
         [109, 18], [92, 13], [76, 19], [64, 36]],
        Color.new(241, 255, 255, 250)
      )
      a.polygon(
        b,
        [[18, 103], [50, 89], [69, 85], [89, 93],
         [112, 105], [75, 97], [47, 97]],
        Color.new(222, 253, 255, 195)
      )
    end

    #---------------------------------------------------------------------------
    # Màn nước phủ quanh mục tiêu
    #---------------------------------------------------------------------------
    splash = a.bitmap(128, 132) do |b|
      a.polygon(
        b,
        [[8, 131], [13, 92], [3, 64], [6, 43],
         [20, 64], [29, 73], [26, 38], [33, 16],
         [43, 43], [49, 63], [57, 33], [65, 1],
         [74, 38], [79, 65], [91, 37], [108, 20],
         [101, 63], [116, 49], [125, 42], [121, 77],
         [113, 99], [120, 131]],
        Color.new(116, 211, 242, 190)
      )
      a.polygon(
        b,
        [[19, 131], [24, 91], [15, 66], [34, 86],
         [36, 46], [48, 84], [59, 60], [65, 25],
         [71, 68], [80, 85], [95, 57], [91, 92],
         [112, 69], [103, 104], [109, 131]],
        Color.new(203, 247, 255, 225)
      )
      a.polygon(
        b,
        [[35, 131], [39, 103], [49, 94], [60, 108],
         [69, 80], [77, 108], [93, 98], [95, 131]],
        Color.new(242, 255, 255, 215)
      )
    end

    #---------------------------------------------------------------------------
    # Giọt nước và vòng gợn
    #---------------------------------------------------------------------------
    drop = a.bitmap(14, 22) do |b|
      a.polygon(
        b,
        [[7, 0], [12, 10], [13, 16], [9, 21],
         [4, 21], [0, 16], [2, 10]],
        Color.new(132, 222, 246, 240)
      )
      a.polygon(
        b,
        [[7, 5], [9, 12], [8, 17], [5, 17], [4, 13]],
        Color.new(244, 255, 255, 245)
      )
    end

    ring = a.ring(60, Color.new(201, 247, 255, 235), 3)
    a[:landing] = a.sprite(ring, z: 20_023)

    a[:groups] = a.targets.map do |target|
      sprite = a.battler_sprite(target)
      cx, cy = a.center(target)
      floor = sprite.y +
              (sprite.src_rect.height - sprite.oy) * sprite.zoom_y
      visible_height = sprite.src_rect.height * sprite.zoom_y.abs
      copy = a.copy(target, hide_original: true, z: 20_019)

      sheet = a.sprite(splash, z: 20_030)
      sheet.ox = 64
      sheet.oy = 132

      moving_wave = a.sprite(wave, z: 20_027)
      moving_wave.ox = 68
      moving_wave.oy = 112
      moving_wave.mirror = cx < ux

      {
        x: cx, y: cy, ground: floor,
        height: [[visible_height * 0.90, 60].max, 120].min,
        body: copy, color: copy.color.clone,
        wave: moving_wave,
        splash: sheet,
        ring: a.sprite(ring, z: 20_029),
        drops: Array.new(28) { a.sprite(drop, z: 20_033) },
        drips: Array.new(10) { a.sprite(drop, z: 20_034) }
      }
    end
  end
) do |a, _t|
  sec = a.seconds

  #=============================================================================
  # 1. NHẢY LÊN — Nhún nhẹ rồi đáp xuống
  #=============================================================================
  brace = Math.sin(a.clamp(sec / 0.13) * Math::PI)
  jump_p = a.clamp((sec - 0.10) / 0.38)
  jump = Math.sin(jump_p * Math::PI)

  a[:user_copy].x = a[:user_x]
  a[:user_copy].y = a[:user_y] + brace * 2 - jump * 28

  # Vòng nước bật ra khi tiếp đất.
  q = (sec - 0.46) / 0.35
  p = a.clamp(q)

  landing = a[:landing]
  landing.x = a[:ux]
  landing.y = a[:ground]
  landing.zoom_x = 0.22 + p * 1.18
  landing.zoom_y = landing.zoom_x * 0.25
  landing.opacity = q.between?(0.0, 1.0) ?
    ((1.0 - p) * 225).to_i : 0

  a[:groups].each do |g|
    cx = g[:x]
    cy = g[:y]
    floor = g[:ground]

    #===========================================================================
    # 2. SÓNG NƯỚC LAO TỚI
    #===========================================================================
    q = (sec - 0.49) / 0.35
    p = a.clamp(q)
    wave = g[:wave]

    wave.x = a.lerp(a[:ux], cx, p)
    wave.y = a.lerp(a[:ground], floor, p)
    wave.zoom_x = 0.35 + p * 0.42
    wave.zoom_y = 0.35 + p * 0.47
    wave.opacity = q.between?(0.0, 1.0) ?
      (a.clamp(q / 0.15) * 240).to_i : 0

    #===========================================================================
    # 3. NƯỚC PHỦ MỤC TIÊU — Bật nhanh rồi rơi xuống
    #===========================================================================
    age = sec - 0.82
    rise = a.clamp(age / 0.13)
    fall = a.clamp((age - 0.13) / 0.38)

    sheet = g[:splash]
    sheet.x = cx
    sheet.y = floor + fall * 12
    sheet.zoom_x = 0.62 + rise * 0.20 + fall * 0.12
    sheet.zoom_y = g[:height] / 132.0 *
                   rise * (1.0 - fall * 0.70)
    sheet.opacity = age >= 0 ?
      ((1.0 - fall) * 235).to_i : 0

    q = age / 0.48
    p = a.clamp(q)
    ring = g[:ring]
    ring.x = cx
    ring.y = floor
    ring.zoom_x = 0.25 + p * 1.15
    ring.zoom_y = ring.zoom_x * 0.28
    ring.opacity = q.between?(0.0, 1.0) ?
      ((1.0 - p) * 215).to_i : 0

    g[:drops].each_with_index do |drop, i|
      q = (sec - 0.84 - i % 4 * 0.015) / 0.50
      p = a.clamp(q)
      theta = i * 2.399
      spread = 20 + i % 5 * 10

      drop.x = cx + Math.cos(theta) * p * spread
      drop.y = floor - 14 -
               Math.sin(p * Math::PI) * (35 + i % 5 * 13) +
               p * p * 16
      drop.angle = Math.cos(theta) * p * 65
      drop.zoom_x = 0.26 + i % 3 * 0.11
      drop.zoom_y = drop.zoom_x
      drop.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 240).to_i : 0
    end

    # Ánh nước nhẹ trên cơ thể, không tạo phản lực sát thương.
    wet = a.clamp(age / 0.10) *
          a.clamp((1.43 - sec) / 0.35)
    g[:body].color = wet > 0 ?
      Color.new(154, 225, 246, (wet * 65).to_i) : g[:color]

    #===========================================================================
    # 4. DRENCHED — Vài giọt nhỏ trượt xuống rồi tan
    #===========================================================================
    g[:drips].each_with_index do |drop, i|
      q = (sec - 1.00 - i % 5 * 0.045) / 0.43
      p = a.clamp(q)

      drop.x = cx + Math.sin(i * 2.399) * 24
      drop.y = cy - 12 + i % 3 * 10 + p * p * 39
      drop.angle = 0
      drop.zoom_x = 0.17 + i % 3 * 0.05
      drop.zoom_y = drop.zoom_x * (1.0 + p * 0.40)
      drop.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 220).to_i : 0
    end
  end
end