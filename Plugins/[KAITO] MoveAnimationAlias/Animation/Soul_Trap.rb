#===============================================================================
# SOUL TRAP — Eye Seal
# Yêu cầu: 000_AnimationCore.rb
# Thay thế toàn bộ animation Soul Trap cũ.
#===============================================================================

module KaitoSoulTrapEye
  module_function

  def setup(a, activation)
    a[:activation] = activation

    #---------------------------------------------------------------------------
    # Vòng ấn dùng chung cho cả hai pha
    #---------------------------------------------------------------------------
    outer = a.ring(88, Color.new(164, 126, 235, 235), 3)
    inner = a.ring(65, Color.new(157, 241, 226, 220), 2)

    pool = a.bitmap(184, 66) do |b|
      66.times do |y|
        184.times do |x|
          r = ((x - 91.5) / 90.0)**2 +
              ((y - 32.5) / 31.0)**2
          next if r > 1.0
          b.set_pixel(
            x, y,
            Color.new(35, 16, 58, ((1.0 - r) * 185).to_i)
          )
        end
      end
    end

    #---------------------------------------------------------------------------
    # Con mắt: viền ngọc, lòng trắng tím, đồng tử dọc
    #---------------------------------------------------------------------------
    eye = a.bitmap(96, 44) do |b|
      a.polygon(
        b,
        [[1, 22], [21, 6], [48, 1], [75, 6],
         [95, 22], [75, 38], [48, 43], [21, 38]],
        Color.new(157, 240, 225, 255)
      )
      a.polygon(
        b,
        [[8, 22], [25, 11], [48, 6], [71, 11],
         [88, 22], [71, 33], [48, 38], [25, 33]],
        Color.new(230, 216, 255, 255)
      )

      44.times do |y|
        96.times do |x|
          r = ((x - 48) / 16.0)**2 + ((y - 22) / 16.0)**2
          next if r > 1.0
          b.set_pixel(x, y, Color.new(132, 72, 197, 255))
        end
      end

      a.polygon(
        b,
        [[48, 8], [53, 19], [53, 25], [48, 36],
         [43, 25], [43, 19]],
        Color.new(24, 13, 40, 255)
      )
      b.fill_rect(40, 12, 5, 4, Color.new(238, 255, 247, 255))
    end

    #---------------------------------------------------------------------------
    # Bốn mẫu ký tự, xuất hiện lần lượt quanh vòng
    #---------------------------------------------------------------------------
    glyphs = Array.new(4) do |i|
      a.bitmap(16, 20) do |b|
        color = Color.new(170, 239, 225, 245)
        case i
        when 0
          a.polygon(
            b,
            [[7, 1], [10, 1], [10, 19], [7, 19]], color
          )
          a.polygon(
            b,
            [[2, 5], [4, 3], [14, 12], [12, 14]], color
          )
        when 1
          a.polygon(
            b,
            [[2, 4], [8, 0], [14, 4], [8, 8]], color
          )
          b.fill_rect(7, 7, 3, 12, color)
        when 2
          a.polygon(
            b,
            [[2, 2], [5, 2], [5, 13], [13, 13],
             [13, 16], [2, 16]], color
          )
          b.fill_rect(9, 3, 3, 8, color)
        else
          a.polygon(
            b,
            [[1, 3], [4, 1], [15, 17], [12, 19]], color
          )
          a.polygon(
            b,
            [[12, 1], [15, 3], [4, 19], [1, 17]], color
          )
        end
      end
    end

    #---------------------------------------------------------------------------
    # Lửa tím, khói và sợi nối bóng hồn
    #---------------------------------------------------------------------------
    flame = a.bitmap(30, 44) do |b|
      a.polygon(
        b,
        [[15, 0], [19, 14], [25, 8], [24, 24],
         [29, 31], [23, 41], [13, 44], [4, 38],
         [1, 28], [8, 15], [9, 27]],
        Color.new(130, 70, 205, 225)
      )
      a.polygon(
        b,
        [[15, 15], [18, 27], [23, 30], [19, 38],
         [12, 39], [7, 33], [12, 26]],
        Color.new(197, 255, 239, 250)
      )
    end

    smoke = a.bitmap(48, 42) do |b|
      a.polygon(
        b,
        [[1, 26], [5, 13], [14, 8], [18, 1],
         [31, 3], [36, 11], [44, 14], [47, 28],
         [37, 39], [20, 41], [7, 36]],
        Color.new(92, 54, 132, 125)
      )
    end

    thread = a.bitmap(5, 80) do |b|
      b.fill_rect(0, 0, 5, 80, Color.new(137, 115, 220, 95))
      b.fill_rect(2, 0, 1, 80, Color.new(195, 255, 242, 235))
    end

    #---------------------------------------------------------------------------
    # Bàn tay ma: năm ngón dài và cổ tay tan mờ
    #---------------------------------------------------------------------------
    hand = a.bitmap(86, 140) do |b|
      silhouette = [
        [26, 139], [24, 108], [15, 94], [3, 73],
        [2, 61], [8, 57], [17, 68], [23, 77],
        [20, 36], [22, 25], [28, 23], [33, 31],
        [37, 66], [37, 12], [40, 3], [46, 2],
        [50, 12], [49, 64], [55, 21], [60, 14],
        [66, 17], [68, 26], [61, 71], [71, 44],
        [77, 40], [83, 45], [82, 57], [70, 91],
        [62, 108], [61, 139]
      ]
      a.polygon(b, silhouette, Color.new(153, 222, 212, 225))

      a.polygon(
        b,
        [[31, 139], [30, 106], [21, 91], [10, 70],
         [25, 88], [33, 84], [28, 34], [33, 66],
         [42, 82], [43, 14], [46, 79], [58, 36],
         [54, 87], [74, 53], [64, 91], [56, 106],
         [55, 139]],
        Color.new(77, 43, 125, 220)
      )
      a.polygon(
        b,
        [[34, 99], [43, 88], [55, 95], [48, 108],
         [47, 133], [39, 133]],
        Color.new(194, 167, 241, 185)
      )
    end

    #---------------------------------------------------------------------------
    # Các đối tượng của mỗi mục tiêu
    #---------------------------------------------------------------------------
    a[:groups] = a.targets.map do |target|
      original = a.battler_sprite(target)
      cx, cy = a.center(target)
      ground = original.y +
               (original.src_rect.height - original.oy) * original.zoom_y

      g = {
        x: cx, y: cy, ground: ground,
        pool: a.sprite(pool, z: 20_010),
        outer: a.sprite(outer, z: 20_012),
        inner: a.sprite(inner, z: 20_013),
        eye: a.sprite(eye, z: 20_014),
        glyphs: Array.new(12) do |i|
          a.sprite(glyphs[i % 4], z: 20_014)
        end,
        seed: a.sprite(flame, z: 20_028),
        embers: Array.new(16) { a.sprite(flame, z: 20_030) },
        smoke: Array.new(18) { a.sprite(smoke, z: 20_035) }
      }

      if activation
        body = a.copy(target, hide_original: true, z: 20_018)
        soul = a.copy(target, force_visible: true, z: 20_025)
        soul.color = Color.new(173, 130, 240, 175)
        soul.opacity = 0

        tether = a.sprite(thread, z: 20_023, centered: false)
        tether.ox = 2
        tether.oy = 0

        g[:body] = body
        g[:body_color] = body.color.clone
        g[:soul] = soul
        g[:soul_x] = soul.x
        g[:soul_y] = soul.y
        g[:soul_zx] = soul.zoom_x
        g[:soul_zy] = soul.zoom_y
        g[:thread] = tether
        g[:hands] = Array.new(3) do
          s = a.sprite(hand, z: 20_029)
          s.ox = 43
          s.oy = 140
          s
        end
      end

      g
    end

    if activation
      a.sound_at(0.03, ["PRSFX- Confuse Ray"], 60, 125)
      a.sound_at(0.30, ["PRSFX- Phantom Force1"], 75, 90)
      a.sound_at(0.77, ["PRSFX- Destiny Bond1"], 65, 105)
      a.sound_at(1.24, ["PRSFX- Phantom Force2"], 85, 85)
      a.sound_at(1.40, ["PRSFX- Ominous Wind"], 55, 110)
    else
      a[:origin] = a.center
      a.sound_at(0.03, ["PRSFX- Lick"], 40, 115)
      a.sound_at(0.46, ["PRSFX- Confuse Ray"], 45, 90)
      a.sound_at(0.88, ["PRSFX- Curse2"], 35, 125)
    end

    flash = a.bitmap(Graphics.width, Graphics.height) do |b|
      b.fill_rect(
        0, 0, b.width, b.height,
        Color.new(237, 221, 255)
      )
    end
    a[:flash] = a.sprite(flash, z: 20_050, centered: false)
  end

  #-----------------------------------------------------------------------------
  # Vòng ấn và con mắt dùng chung
  #-----------------------------------------------------------------------------
  def seal(a, g, visibility, scale, eye_open, rune_count, sink = 0)
    cx = g[:x]
    gy = g[:ground] + sink

    s = g[:pool]
    s.x = cx
    s.y = gy
    s.zoom_x = scale
    s.zoom_y = scale
    s.opacity = (visibility * 235).to_i

    [g[:outer], g[:inner]].each_with_index do |ring, i|
      ring.x = cx
      ring.y = gy
      ring.zoom_x = scale
      ring.zoom_y = scale * 0.29
      ring.angle = i == 0 ? 0 : 8
      ring.opacity = (visibility * 245).to_i
    end

    g[:glyphs].each_with_index do |glyph, i|
      theta = i * Math::PI * 2 / 12.0
      glyph.x = cx + Math.cos(theta) * 76 * scale
      glyph.y = gy + Math.sin(theta) * 22 * scale
      glyph.zoom_x = 0.66 * scale
      glyph.zoom_y = 0.46 * scale
      glyph.angle = -Math.cos(theta) * 12
      glyph.opacity = i < rune_count ? (visibility * 240).to_i : 0
    end

    eye = g[:eye]
    eye.x = cx
    eye.y = gy - 2
    eye.zoom_x = 0.68 * scale
    eye.zoom_y = 0.36 * scale * [eye_open, 0.025].max
    eye.opacity = (visibility * 255).to_i
  end

  #-----------------------------------------------------------------------------
  # ĐẶT BẪY — 1.75 giây
  #-----------------------------------------------------------------------------
  def cast(a)
    sec = a.seconds
    ox, oy = a[:origin]

    a[:groups].each do |g|
      cx = g[:x]
      ground = g[:ground]

      flight = a.clamp(sec / 0.48)
      seed = g[:seed]
      seed.x = a.lerp(ox, cx, flight)
      seed.y = a.lerp(oy, ground - 5, flight) -
               Math.sin(flight * Math::PI) * 24
      seed.zoom_x = 0.50
      seed.zoom_y = 0.50 + Math.sin(sec * 20) * 0.04
      seed.opacity = sec < 0.48 ? 240 : 0

      form = a.clamp((sec - 0.43) / 0.31)
      fade = a.clamp((1.64 - sec) / 0.40)
      opening = a.clamp((sec - 0.77) / 0.15)
      closing = a.clamp((1.23 - sec) / 0.22)
      sink = a.clamp((sec - 1.20) / 0.44)

      seal(
        a, g,
        form * fade,
        (0.25 + form * 0.75) * (1.0 - sink * 0.12),
        opening * closing,
        (a.clamp((sec - 0.48) / 0.42) * 12).floor,
        sink * 8
      )

      g[:embers].each_with_index do |ember, i|
        q = (sec - 0.97 - i * 0.025) / 0.40
        p = a.clamp(q)

        ember.x = cx + Math.sin(i * 2.4) * (18 + i % 4 * 9) +
                  Math.sin(p * 3 + i) * 5
        ember.y = ground - p * (25 + i % 4 * 8)
        ember.zoom_x = 0.12 + i % 3 * 0.04
        ember.zoom_y = ember.zoom_x
        ember.opacity = q.between?(0.0, 1.0) ?
          (Math.sin(p * Math::PI) * 180).to_i : 0
      end
    end

    gleam = 1.0 - (sec - 0.91).abs / 0.07
    a[:flash].opacity = ([gleam, 0].max * 25).to_i
  end

  #-----------------------------------------------------------------------------
  # KÍCH HOẠT — 2.10 giây
  #-----------------------------------------------------------------------------
  def activate(a)
    sec = a.seconds

    reveal = a.clamp(sec / 0.13)
    lock = a.clamp((sec - 1.17) / 0.20)
    dissolve = a.clamp((1.91 - sec) / 0.42)

    a[:groups].each do |g|
      cx = g[:x]
      cy = g[:y]
      ground = g[:ground]

      seal(
        a, g,
        reveal * dissolve,
        1.0 - lock * 0.77,
        a.clamp(sec / 0.07) * (1.0 - lock),
        12
      )

      # Trois bàn tay: trồi lên, khép vào và giật xuống.
      reach = a.clamp((sec - 0.19) / 0.39)
      grip = a.clamp((sec - 0.55) / 0.24)

      g[:hands].each_with_index do |hand, i|
        side = [-1, 0, 1][i]
        delay = a.clamp((sec - 0.20 - i * 0.045) / 0.36)
        height = [ground - cy + 42, 62].max
        height = [height, 130].min

        hand.x = cx + side * (49 - grip * 22) * (1.0 - lock)
        hand.y = ground - reach * 6 + lock * 18
        hand.zoom_x = (i == 1 ? 0.61 : 0.67) * (1.0 - lock * 0.45)
        hand.zoom_y = delay * height / 140.0 * (1.0 - lock * 0.86)
        hand.angle = -side * (16 + grip * 9) * (1.0 - lock)
        hand.mirror = i == 2
        hand.opacity = (delay * dissolve * 225).to_i
      end

      # Bóng hồn tách lên khỏi cơ thể, rồi bị kéo về tâm vòng.
      lift = a.clamp((sec - 0.57) / 0.34)
      drag = a.clamp((sec - 1.04) / 0.27)
      drag = drag * drag

      soul = g[:soul]
      dx = 17 * lift * (1.0 - drag)
      dy = -38 * lift * (1.0 - drag) +
           (ground - cy - 5) * drag

      soul.x = g[:soul_x] + dx
      soul.y = g[:soul_y] + dy
      soul.zoom_x = g[:soul_zx] * (1.0 - drag * 0.68)
      soul.zoom_y = g[:soul_zy] * (1.0 - drag * 0.76)
      soul.angle = -lift * 7 * (1.0 - drag)
      soul.opacity = (lift * (1.0 - drag) * 145).to_i

      # Sợi sáng nối tâm cơ thể với bóng hồn.
      tether = g[:thread]
      length = Math.sqrt(dx * dx + dy * dy)
      tether.x = cx
      tether.y = cy
      tether.angle = -Math.atan2(dy, dx) * 180 / Math::PI + 90
      tether.zoom_y = length / 80.0
      tether.opacity = (lift * (1.0 - drag) * 215).to_i

      # Cột khói ngắn phụt lên ngay khi khóa vòng.
      g[:smoke].each_with_index do |smoke, i|
        q = (sec - 1.27 - i % 6 * 0.026) / 0.54
        p = a.clamp(q)

        smoke.x = cx + Math.sin(i * 2.4) * (6 + p * 20)
        smoke.y = ground - 7 - p * (36 + i % 5 * 11)
        smoke.zoom_x = 0.25 + p * 0.70
        smoke.zoom_y = 0.45 + p * 0.85
        smoke.angle = i * 31 + p * 20
        smoke.opacity = q.between?(0.0, 1.0) ?
          (Math.sin(p * Math::PI) * 190).to_i : 0
      end

      # Tàn lửa ngọc tím tan sau cột khói.
      g[:embers].each_with_index do |ember, i|
        q = (sec - 1.32 - i % 5 * 0.035) / 0.48
        p = a.clamp(q)

        ember.x = cx + Math.sin(i * 2.4) * (8 + p * 33)
        ember.y = ground - 5 - p * (25 + i % 5 * 9)
        ember.zoom_x = 0.10 + i % 3 * 0.045
        ember.zoom_y = ember.zoom_x
        ember.opacity = q.between?(0.0, 1.0) ?
          (Math.sin(p * Math::PI) * 205).to_i : 0
      end

      # Mục tiêu chớp tối một nhịp khi bóng hồn bị giật xuống.
      dark = a.clamp((sec - 1.23) / 0.045) *
             a.clamp((1.48 - sec) / 0.15)

      body = g[:body]
      body.color = dark > 0 ?
        Color.new(23, 9, 38, (dark * 220).to_i) : g[:body_color]
    end

    # Chớp trắng tím lúc mắt bật mở.
    flash = a.clamp((sec - 0.04) / 0.025) *
            a.clamp((0.22 - sec) / 0.15)
    a[:flash].opacity = (flash * 95).to_i
  end

  #-----------------------------------------------------------------------------
  # Phân biệt đặt bẫy / kích hoạt.
  # Khi kích hoạt, lấy nạn nhân làm mốc hình ảnh để hỗ trợ nguồn đánh ngoài sân.
  #-----------------------------------------------------------------------------
  module Router
    def pbAnimation(move_id, user, targets, hit_num = 0)
      return super unless move_id == :SOULTRAP

      activation = hit_num == 1 || (@battle && @battle.futureSight)
      entries = targets.is_a?(Array) ? targets : [targets]
      anchor = activation ? (entries.compact.first || user) : user

      super(move_id, anchor, targets, activation ? 1 : 0)
    end
  end
end

#===============================================================================
# Đăng ký hai animation riêng biệt
#===============================================================================

KaitoAnimation.register(
  :SOULTRAP,
  duration: 1.75,
  hit: 0,
  setup: proc { |a| KaitoSoulTrapEye.setup(a, false) }
) do |a, _t|
  KaitoSoulTrapEye.cast(a)
end

KaitoAnimation.register(
  :SOULTRAP,
  duration: 2.10,
  hit: 1,
  setup: proc { |a| KaitoSoulTrapEye.setup(a, true) }
) do |a, _t|
  KaitoSoulTrapEye.activate(a)
end

unless Battle::Scene.ancestors.include?(KaitoSoulTrapEye::Router)
  Battle::Scene.prepend(KaitoSoulTrapEye::Router)
end