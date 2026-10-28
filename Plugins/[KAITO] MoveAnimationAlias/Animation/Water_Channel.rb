#===============================================================================
# WATER CHANNEL — Hồ nước / Xoáy nước đánh úp
# Yêu cầu: 000_AnimationCore.rb
#===============================================================================

module KaitoWaterChannelVisual
  module_function

  def setup(a, activation)
    a[:activation] = activation

    #---------------------------------------------------------------------------
    # Hồ elip: tâm xanh đậm, mép cyan và bọt trắng
    #---------------------------------------------------------------------------
    pool = a.bitmap(240, 88) do |b|
      88.times do |y|
        240.times do |x|
          dx = (x - 119.5) / 117.0
          dy = (y - 43.5) / 41.0
          r = dx * dx + dy * dy
          next if r > 1.0

          color =
            if r > 0.91
              Color.new(218, 253, 255, 225)
            elsif r > 0.74
              Color.new(89, 218, 241, 230)
            elsif r > 0.40
              Color.new(39, 143, 195, 225)
            else
              Color.new(24, 90, 153, 225)
            end

          b.set_pixel(x, y, color)
        end
      end
    end

    ring = a.ring(75, Color.new(164, 237, 251, 230), 3)
    strong_ring = a.ring(56, Color.new(224, 254, 255, 245), 4)

    #---------------------------------------------------------------------------
    # Luồng nước thấp chạy trên mặt đất
    #---------------------------------------------------------------------------
    stream = a.bitmap(120, 18) do |b|
      a.polygon(
        b,
        [[0, 9], [15, 4], [106, 1], [120, 9],
         [106, 17], [15, 14]],
        Color.new(68, 181, 223, 215)
      )
      a.polygon(
        b,
        [[0, 9], [37, 6], [113, 5], [120, 9],
         [109, 12], [35, 11]],
        Color.new(184, 244, 255, 235)
      )
      b.fill_rect(45, 7, 58, 2, Color.new(247, 255, 255, 240))
    end

    #---------------------------------------------------------------------------
    # Hai luồng nước dựng lên rồi quật vào trong
    #---------------------------------------------------------------------------
    jet = a.bitmap(110, 164) do |b|
      a.polygon(
        b,
        [[12, 163], [9, 134], [21, 106], [18, 78],
         [28, 48], [47, 22], [70, 6], [96, 1],
         [108, 11], [99, 30], [82, 36], [67, 30],
         [54, 45], [48, 68], [55, 92], [51, 118],
         [64, 142], [67, 163]],
        Color.new(53, 158, 211, 230)
      )
      a.polygon(
        b,
        [[23, 163], [20, 135], [32, 108], [30, 79],
         [39, 52], [54, 31], [74, 17], [95, 9],
         [102, 13], [94, 24], [79, 28], [65, 23],
         [46, 43], [39, 68], [46, 93], [43, 119],
         [56, 147], [57, 163]],
        Color.new(126, 225, 246, 245)
      )
      a.polygon(
        b,
        [[31, 160], [29, 133], [40, 108], [38, 80],
         [47, 53], [65, 32], [81, 23], [95, 15],
         [80, 19], [59, 29], [42, 51], [34, 79],
         [36, 109], [25, 135], [28, 160]],
        Color.new(237, 255, 255, 245)
      )
    end

    #---------------------------------------------------------------------------
    # Giọt nước rõ viền trắng
    #---------------------------------------------------------------------------
    drop = a.bitmap(18, 28) do |b|
      a.polygon(
        b,
        [[9, 0], [15, 11], [17, 19], [13, 26],
         [6, 27], [1, 21], [2, 14]],
        Color.new(231, 254, 255, 245)
      )
      a.polygon(
        b,
        [[9, 6], [12, 14], [13, 20], [10, 23],
         [6, 22], [4, 18], [6, 12]],
        Color.new(80, 200, 238, 245)
      )
    end

    # Bọt trắng dạng cụm.
    foam = a.bitmap(26, 22) do |b|
      circles = [[7, 13, 6], [15, 12, 8], [21, 15, 4]]
      22.times do |y|
        26.times do |x|
          next unless circles.any? do |cx, cy, radius|
            (x - cx)**2 + (y - cy)**2 <= radius**2
          end
          b.set_pixel(x, y, Color.new(239, 255, 255, 240))
        end
      end
    end

    #---------------------------------------------------------------------------
    # Xác định hồ bên đối phương hoặc hồ dưới nạn nhân
    #---------------------------------------------------------------------------
    if activation
      entries = a.targets.map { |battler| [battler] }
    else
      foes = a.user.allOpposing.reject(&:fainted?).select do |battler|
        KaitoAnimation.valid_sprite?(a.battler_sprite(battler))
      end
      entries = [foes]
    end

    a[:groups] = entries.map do |battlers|
      positions = battlers.map do |battler|
        sprite = a.battler_sprite(battler)
        cx, cy = a.center(battler)
        ground = sprite.y +
                 (sprite.src_rect.height - sprite.oy) * sprite.zoom_y
        [cx, cy, ground]
      end

      if positions.empty?
        positions = [[
          Graphics.width * (a.user.index.even? ? 0.70 : 0.30),
          Graphics.height * 0.45,
          Graphics.height * (a.user.index.even? ? 0.49 : 0.75)
        ]]
      end

      cx = positions.inject(0.0) { |sum, p| sum + p[0] } / positions.length
      cy = positions.inject(0.0) { |sum, p| sum + p[1] } / positions.length
      floor = positions.inject(0.0) { |sum, p| sum + p[2] } / positions.length

      spread = positions.map { |p| p[0] }.max -
               positions.map { |p| p[0] }.min
      pond_width = activation ? 200 : [spread + 215, 250].max
      pond_width = [pond_width, Graphics.width - 24].min

      # Đưa Pokémon lên trước mặt hồ.
      covers = battlers.map do |battler|
        sprite = a.battler_sprite(battler)
        next unless sprite.visible && sprite.opacity > 0
        a.copy(battler, hide_original: true, z: 20_018)
      end.compact

      g = {
        x: cx, y: cy, floor: floor,
        width: pond_width,
        pool: a.sprite(pool, z: 20_010),
        rings: Array.new(3) { a.sprite(ring, z: 20_012) },
        currents: Array.new(24) { a.sprite(foam, z: 20_014) },
        covers: covers
      }

      if activation
        body = covers.first
        g[:body] = body
        if body
          g[:base_x] = body.x
          g[:base_y] = body.y
          g[:color] = body.color.clone
        end

        g[:jets] = Array.new(2) do |i|
          s = a.sprite(jet, z: 20_026)
          s.ox = 40
          s.oy = 164
          s.mirror = i == 1
          s
        end
        g[:impact_ring] = a.sprite(strong_ring, z: 20_030)
        g[:drops] = Array.new(44) { a.sprite(drop, z: 20_033) }
        g[:foam] = Array.new(24) { a.sprite(foam, z: 20_034) }
      end
      g
    end

    unless activation
      sprite = a.battler_sprite
      ux, _uy = a.center
      a[:ux] = ux
      a[:ug] = sprite.y +
        (sprite.src_rect.height - sprite.oy) * sprite.zoom_y

      a[:source_ring] = a.sprite(ring, z: 20_013)
      # Canvas dòng nước mềm, cập nhật hình dạng từng frame.
      a[:flow_bitmap] = a.bitmap(Graphics.width, Graphics.height)
      a[:stream] = a.sprite(
        a[:flow_bitmap], z: 20_015, centered: false
      )

      a.sound_at(0.04, ["PRSFX- Aqua Ring1"], 45, 105)
      a.sound_at(0.28, ["PRSFX- Muddy Water"], 60, 110)
      a.sound_at(1.10, ["PRSFX- Bubblebeam"], 45, 100)
      a.sound_at(1.87, ["PRSFX- Aqua Ring2"], 35, 110)
    else
      a.sound_at(0.03, ["PRSFX- Aqua Ring1"], 50, 125)
      a.sound_at(0.35, ["PRSFX- Muddy Water"], 65, 115)
      a.sound_at(0.76, ["PRSFX- Hydro Cannon2"], 75, 115)
      a.sound_at(1.45, ["PRSFX- Aqua Ring2"], 40, 95)
    end
  end

  #-----------------------------------------------------------------------------
  # TẠO HỒ — Nước chảy ra, tích tụ và lắng xuống
  #-----------------------------------------------------------------------------
  def place(a)
    sec = a.seconds
    g = a[:groups].first

    # Vòng nước trước người dùng.
    p = a.clamp(sec / 0.40)
    ring = a[:source_ring]
    ring.x = a[:ux]
    ring.y = a[:ug]
    ring.zoom_x = 0.15 + p * 0.65
    ring.zoom_y = ring.zoom_x * 0.25
    ring.opacity = (
      a.clamp(sec / 0.10) * a.clamp((0.65 - sec) / 0.30) * 220
    ).to_i

    #---------------------------------------------------------------------------
    # Dòng nước chảy sát đất:
    # thân uốn mềm, mép dao động, đầu dòng xòe rộng khi đến hồ.
    #---------------------------------------------------------------------------
    canvas = a[:flow_bitmap]
    canvas.clear
    a[:stream].opacity = 255

    reach = a.clamp((sec - 0.12) / 0.67)
    reach = reach * reach * (3.0 - 2.0 * reach)
    flow_fade = a.clamp((1.40 - sec) / 0.48)

    if reach > 0 && flow_fade > 0
      dx = g[:x] - a[:ux]
      dy = g[:floor] + 2 - a[:ug]
      length = [Math.sqrt(dx * dx + dy * dy), 1.0].max

      # Phương ngang mặt đất và phương vuông góc dòng chảy.
      nx = -dy / length
      ny = dx / length

      samples = 34
      points = []

      (samples + 1).times do |i|
        u = reach * i / samples.to_f

        # Đường chảy cong nhẹ, neo ổn định ở hai đầu.
        bend = Math.sin(u * Math::PI) *
               (9 + Math.sin(u * 5.5 - sec * 4.0) * 3)

        x = a[:ux] + dx * u + nx * bend
        y = a[:ug] + dy * u + ny * bend * 0.48

        # Nước mở rộng dần; mặt trước loang ra thay vì nhọn như tia.
        head = Math.exp(-((u - reach) / 0.13)**2)
        width = 5 + Math.sin(u * Math::PI) * 7 +
                u * u * 8 + head * (4 + reach * 5)

        # Mép trái và phải chuyển động khác nhau.
        left = width * (
          1.0 + Math.sin(u * 24 - sec * 8.0) * 0.12
        )
        right = width * (
          1.0 + Math.sin(u * 21 - sec * 7.0 + 1.8) * 0.13
        )

        points << [x, y, left, right]
      end

      # Nước có chiều sâu: lớp ngoài trong, thân cyan, lõi sáng dịu.
      layers = [
        [1.18, Color.new(110, 215, 237, (flow_fade * 65).to_i)],
        [0.96, Color.new(59, 170, 213, (flow_fade * 155).to_i)],
        [0.52, Color.new(159, 232, 247, (flow_fade * 125).to_i)]
      ]

      layers.each do |scale, color|
        points.each_cons(2) do |p1, p2|
          a.polygon(
            canvas,
            [
              [p1[0] + nx * p1[2] * scale,
               p1[1] + ny * p1[2] * scale * 0.48],
              [p2[0] + nx * p2[2] * scale,
               p2[1] + ny * p2[2] * scale * 0.48],
              [p2[0] - nx * p2[3] * scale,
               p2[1] - ny * p2[3] * scale * 0.48],
              [p1[0] - nx * p1[3] * scale,
               p1[1] - ny * p1[3] * scale * 0.48]
            ],
            color
          )
        end
      end

      # Đầu dòng tròn, dẹt: nước bò và loang trên mặt đất.
      tip = points.last
      front = Array.new(20) do |i|
        theta = i * Math::PI * 2 / 20
        [
          tip[0] + Math.cos(theta) * (9 + reach * 12),
          tip[1] + Math.sin(theta) * (4 + reach * 5)
        ]
      end
      a.polygon(
        canvas, front,
        Color.new(143, 231, 246, (flow_fade * 155).to_i)
      )

      # Các vệt bọt nhỏ trôi theo nước, không tạo một đường trắng liên tục.
      12.times do |i|
        u = (i / 12.0 + sec * 0.39) % 1.0
        next if u >= reach
        next if u < 0.05

        index = [(u / reach * samples).to_i, samples - 1].min
        p1 = points[index]
        p2 = points[index + 1]

        side = i.even? ? 0.65 : -0.65
        offset1 = p1[2] * side
        offset2 = p2[2] * side

        a.polygon(
          canvas,
          [
            [p1[0] + nx * offset1,
             p1[1] + ny * offset1 * 0.48 - 1],
            [p2[0] + nx * offset2,
             p2[1] + ny * offset2 * 0.48 - 1],
            [p2[0] + nx * offset2,
             p2[1] + ny * offset2 * 0.48 + 1],
            [p1[0] + nx * offset1,
             p1[1] + ny * offset1 * 0.48 + 1]
          ],
          Color.new(229, 252, 255, (flow_fade * 180).to_i)
        )
      end
    end

    form = a.clamp((sec - 0.63) / 0.62)
    form = form * form * (3.0 - 2.0 * form)
    fade = a.clamp((2.30 - sec) / 0.43)
    merge = a.clamp((sec - 1.32) / 0.46)

    pool = g[:pool]
    pool.x = g[:x]
    pool.y = g[:floor] + 2
    pool.zoom_x = g[:width] / 240.0 * (0.18 + form * 0.82)
    pool.zoom_y = 0.20 + form * 0.68
    pool.opacity = (form * fade * 235).to_i

    # Hai dòng bọt chạy quanh mép rồi cùng cuộn vào tâm.
    g[:currents].each_with_index do |foam, i|
      arm = i / 12
      trail = i % 12
      clock = a.clamp((sec - 0.82) / 0.90)
      theta = arm * Math::PI + clock * Math::PI * 2 - trail * 0.075
      radius = 1.0 - merge * 0.76

      foam.x = g[:x] + Math.cos(theta) * g[:width] * 0.44 * radius
      foam.y = g[:floor] + 2 + Math.sin(theta) * 29 * radius
      foam.angle = -theta * 180 / Math::PI
      foam.zoom_x = 0.22 + (1.0 - trail / 12.0) * 0.18
      foam.zoom_y = foam.zoom_x * 0.65
      foam.opacity = (
        a.clamp((sec - 0.78) / 0.20) * fade *
        (1.0 - trail / 16.0) * 220
      ).to_i
    end

    # Các gợn cuối lan ra ngoài.
    g[:rings].each_with_index do |ripple, i|
      q = (sec - 1.46 - i * 0.16) / 0.57
      p = a.clamp(q)

      ripple.x = g[:x]
      ripple.y = g[:floor] + 2
      ripple.zoom_x = (0.15 + p * 1.30) * g[:width] / 240.0
      ripple.zoom_y = ripple.zoom_x * 0.27
      ripple.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * 190).to_i : 0
    end
  end

  #-----------------------------------------------------------------------------
  # KÍCH HOẠT — Nước cuộn vào và quật chéo lên
  #-----------------------------------------------------------------------------
  def trigger(a)
    sec = a.seconds
    reveal = a.clamp(sec / 0.13)
    fade = a.clamp((2.10 - sec) / 0.32)

    a[:groups].each do |g|
      cx = g[:x]
      cy = g[:y]
      floor = g[:floor]

      # Hồ hiện nhanh và giữ lại sau cú đánh.
      pool = g[:pool]
      pool.x = cx
      pool.y = floor + 2
      pool.zoom_x = g[:width] / 240.0
      pool.zoom_y = 0.80
      pool.opacity = (
        reveal * fade * (sec < 1.38 ? 235 : 185)
      ).to_i

      # Gợn sóng co vào tâm, đối lập với lúc đặt hồ.
      g[:rings].each_with_index do |ring, i|
        q = (sec - 0.02 - i * 0.075) / 0.52
        p = a.clamp(q)

        ring.x = cx
        ring.y = floor + 2
        ring.zoom_x = 1.13 - p * 1.02
        ring.zoom_y = ring.zoom_x * 0.27
        ring.opacity = q.between?(0.0, 1.0) ?
          (Math.sin(p * Math::PI) * 230).to_i : 0
      end

      # Bọt mép hồ chạy vào trong rồi trở lại chuyển động yên.
      inward = a.clamp((sec - 0.08) / 0.57)
      calm = a.clamp((sec - 1.22) / 0.25)
      radius = (1.0 - inward * 0.82) * (1.0 - calm) + calm

      g[:currents].each_with_index do |foam, i|
        theta = i * Math::PI * 2 / 24 - sec * (1.0 - calm) * 2.4
        foam.x = cx + Math.cos(theta) * 85 * radius
        foam.y = floor + 2 + Math.sin(theta) * 27 * radius
        foam.zoom_x = 0.19 + i % 3 * 0.05
        foam.zoom_y = foam.zoom_x * 0.65
        foam.opacity = (reveal * fade * (150 + calm * 40)).to_i
      end

      # Hai luồng dựng lên, nghiêng vào nhau rồi rút xuống.
      rise = a.clamp((sec - 0.27) / 0.34)
      strike = a.clamp((sec - 0.57) / 0.20)
      retreat = a.clamp((sec - 0.86) / 0.43)
      jet_height = [[floor - cy + 48, 85].max, 155].min

      g[:jets].each_with_index do |jet, i|
        side = i == 0 ? -1 : 1

        jet.x = cx + side * (61 - strike * 26)
        jet.y = floor + retreat * 15
        jet.angle = side * strike * 28
        jet.zoom_x = 0.68 * (1.0 - retreat * 0.30)
        jet.zoom_y = rise * jet_height / 164.0 *
                     (1.0 - retreat * 0.88)
        jet.opacity = (rise * (1.0 - retreat) * 250).to_i
      end

      # Chùm nước tại điểm hai luồng quật vào.
      q = (sec - 0.76) / 0.65
      p = a.clamp(q)
      active = q.between?(0.0, 1.0)

      g[:drops].each_with_index do |drop, i|
        theta = i * 2.399
        reach = 35 + i % 6 * 12
        travel = 1.0 - (1.0 - p)**2

        drop.x = cx + Math.cos(theta) * travel * reach
        drop.y = cy + Math.sin(theta) * travel * reach * 0.70 +
                 p * p * 42
        drop.angle = -theta * 180 / Math::PI + 90
        drop.zoom_x = 0.29 + i % 4 * 0.09
        drop.zoom_y = drop.zoom_x
        drop.opacity = active ? ((1.0 - p) * 250).to_i : 0
      end

      g[:foam].each_with_index do |foam, i|
        theta = i * 2.399 + 0.5
        reach = 24 + i % 5 * 10

        foam.x = cx + Math.cos(theta) * p * reach
        foam.y = cy + Math.sin(theta) * p * reach * 0.65 + p * p * 24
        foam.angle = i * 27 + p * 35
        foam.zoom_x = 0.25 + Math.sin(p * Math::PI) * 0.30
        foam.zoom_y = foam.zoom_x * 0.85
        foam.opacity = active ?
          (Math.sin(p * Math::PI) * 245).to_i : 0
      end

      # Vòng sóng mạnh dưới chân.
      ring = g[:impact_ring]
      ring.x = cx
      ring.y = floor + 2
      ring.zoom_x = 0.20 + p * 1.75
      ring.zoom_y = ring.zoom_x * 0.27
      ring.opacity = active ? ((1.0 - p) * 245).to_i : 0

      # Chớp trắng xanh và rung ngắn.
      age = sec - 0.76
      flash = age.between?(0.0, 0.15) ? 1.0 - age / 0.15 : 0.0
      shake = age.between?(0.0, 0.23) ? 1.0 - age / 0.23 : 0.0

      if g[:body]
        body = g[:body]
        body.x = g[:base_x] + Math.sin(age * 105) * shake * 6
        body.y = g[:base_y] - Math.sin(age * 75).abs * shake * 2
        body.color = flash > 0 ?
          Color.new(221, 252, 255, (flash * 210).to_i) : g[:color]
      end
    end
  end
end

#===============================================================================
# Hai pha dùng chung ID, phân biệt bằng hit.
#===============================================================================

KaitoAnimation.register(
  :WATERCHANNEL,
  duration: 2.30,
  hit: 0,
  require_target: false,
  setup: proc { |a| KaitoWaterChannelVisual.setup(a, false) }
) do |a, _t|
  KaitoWaterChannelVisual.place(a)
end

KaitoAnimation.register(
  :WATERCHANNEL,
  duration: 2.10,
  hit: 1,
  setup: proc { |a| KaitoWaterChannelVisual.setup(a, true) }
) do |a, _t|
  KaitoWaterChannelVisual.trigger(a)
end