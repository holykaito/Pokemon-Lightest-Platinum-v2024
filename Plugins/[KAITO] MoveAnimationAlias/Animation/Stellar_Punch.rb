#===============================================================================
# STELLAR PUNCH - Cosmic Star Knuckle
# Pokemon Essentials v21.1 | [KAITO] MoveAnimationAlias
# Requires: Animation/000_AnimationCore.rb
# Install : Plugins/[KAITO] MoveAnimationAlias/Animation/Stellar_Punch.rb
# Visuals only. The move's FunctionCode controls damage and Attack reduction.
#===============================================================================

KaitoAnimation.register(
  :STELLARPUNCH,
  duration: 2.15,
  require_target: true,
  setup: proc do |a|
    a.sound_at(0.04, ["PRSFX- Cosmic Power"], 45, 120)
    a.sound_at(0.45, ["PRSFX- Power Up Punch1"], 55, 110)
    a.sound_at(0.72, ["PRSFX- Mach Punch"], 75, 115)
    a.sound_at(0.99, ["PRSFX- Meteor Mash2", "PRSFX- Mega Punch2"], 85, 110)
    a.sound_at(1.16, ["PRSFX- Power Gem1"], 55, 120)

    source = a.battler_sprite
    ux, uy = a.center
    first_target = a.targets.first
    tx, ty = a.center(first_target)
    dir = tx >= ux ? 1 : -1

    width = source.src_rect.width * source.zoom_x.abs
    height = source.src_rect.height * source.zoom_y.abs
    dest = a.battler_sprite(first_target)
    tw = dest.src_rect.width * dest.zoom_x.abs
    stop_x = tx - dir * (tw * 0.43 + width * 0.29 + 12)
    stop_y = ty + (height * 0.12)
    a[:user_center] = [ux, uy]
    a[:direction] = dir
    a[:motion] = [stop_x - ux, stop_y - uy]
    a[:hand] = [ux + dir * [width * 0.38, 36].min, uy - height * 0.11]
    a[:target_center] = [tx, ty]

    # Dark lavender atmosphere. The battle scene remains visible beneath it.
    veil = a.bitmap(Graphics.width, Graphics.height) do |b|
      b.fill_rect(0, 0, b.width, b.height, Color.new(19, 14, 48))
    end
    a[:veil] = a.sprite(veil, z: 20_000, centered: false)

    # Soft pink / gold radial halo; created only once per playback.
    glow = a.bitmap(128, 128) do |b|
      128.times do |y|
        128.times do |x|
          d = Math.sqrt((x - 63.5)**2 + (y - 63.5)**2) / 63.0
          next if d > 1.0
          alpha = ((1.0 - d)**2 * 175).round
          b.set_pixel(x, y, Color.new(247, 183, 246, alpha)) if alpha > 0
        end
      end
    end

    # Eight-pointed starlight sparkle.
    sparkle = a.bitmap(28, 28) do |b|
      a.polygon(b, [
        [14, 0], [17, 10], [26, 14], [17, 17],
        [14, 27], [11, 17], [1, 14], [11, 10]
      ], Color.new(253, 181, 239, 230))
      a.polygon(b, [
        [14, 3], [16, 12], [24, 14], [16, 16],
        [14, 25], [12, 16], [4, 14], [12, 12]
      ], Color.new(255, 241, 181, 245))
      b.fill_rect(12, 12, 4, 4, Color.new(255, 255, 255))
    end

    # Magic fist pointing RIGHT; its rotation follows the punch trajectory.
    knuckle = a.bitmap(114, 100) do |b|
      # Starlight behind the fist.
      a.polygon(b, [
        [61, 2], [71, 31], [111, 37], [80, 55],
        [87, 88], [58, 69], [28, 91], [36, 59],
        [4, 38], [44, 31]
      ], Color.new(240, 143, 242, 120))
      a.polygon(b, [
        [61, 14], [68, 36], [96, 39], [75, 53],
        [80, 75], [59, 61], [40, 79], [46, 54],
        [20, 40], [48, 37]
      ], Color.new(255, 228, 151, 185))
      # Gold / white clenched fist with separate knuckles and cuff.
      a.polygon(b, [
        [24, 37], [40, 32], [48, 28], [59, 31],
        [65, 26], [77, 31], [82, 37], [91, 40],
        [93, 53], [83, 62], [65, 65], [51, 72],
        [28, 65], [15, 56], [18, 45]
      ], Color.new(144, 88, 189, 245))
      a.polygon(b, [
        [21, 44], [39, 37], [49, 34], [60, 38],
        [66, 33], [76, 38], [79, 44], [87, 45],
        [86, 53], [76, 57], [61, 58], [49, 64],
        [32, 60], [22, 53]
      ], Color.new(255, 231, 166, 250))
      a.polygon(b, [
        [30, 45], [43, 40], [50, 41], [48, 49],
        [34, 53]
      ], Color.new(255, 255, 246, 255))
      a.polygon(b, [[54, 39], [63, 39], [65, 46], [55, 48]],
                Color.new(255, 255, 246, 255))
      a.polygon(b, [[68, 41], [76, 42], [78, 49], [69, 50]],
                Color.new(255, 255, 246, 255))
      a.polygon(b, [[25, 58], [47, 64], [37, 72], [18, 66]],
                Color.new(229, 152, 237, 235))
    end

    # Comet tail extending behind a forward-moving fist.
    streak = a.bitmap(166, 52) do |b|
      a.polygon(b, [[0, 26], [120, 5], [164, 26], [120, 47]],
                Color.new(205, 128, 246, 100))
      a.polygon(b, [[25, 26], [137, 17], [164, 26], [137, 34]],
                Color.new(255, 215, 165, 190))
      a.polygon(b, [[68, 26], [153, 23], [165, 26], [153, 29]],
                Color.new(255, 255, 235, 255))
    end

    # Radial impact burst, with alternating long and short pastel rays.
    burst = a.bitmap(224, 224) do |b|
      16.times do |i|
        theta = i * Math::PI / 8
        reach = i.even? ? 101 : 75
        spread = i.even? ? 0.12 : 0.16
        a.polygon(b, [
          [112 + Math.cos(theta - spread) * 23,
           112 + Math.sin(theta - spread) * 23],
          [112 + Math.cos(theta) * reach,
           112 + Math.sin(theta) * reach],
          [112 + Math.cos(theta + spread) * 23,
           112 + Math.sin(theta + spread) * 23]
        ], i.even? ? Color.new(255, 221, 161, 220) :
                     Color.new(241, 174, 255, 190))
      end
      a.polygon(b, [
        [112, 70], [124, 99], [154, 112], [124, 125],
        [112, 154], [100, 125], [70, 112], [100, 99]
      ], Color.new(255, 246, 202, 240))
      b.fill_rect(103, 103, 18, 18, Color.new(255, 255, 250, 255))
    end

    ring_small = a.ring(44, Color.new(255, 229, 173, 230), 3)
    ring_big   = a.ring(70, Color.new(246, 179, 245, 225), 3)
    flash = a.bitmap(Graphics.width, Graphics.height) do |b|
      b.fill_rect(0, 0, b.width, b.height, Color.new(255, 244, 234))
    end
    a[:flash] = a.sprite(flash, z: 20_060, centered: false)

    # Afterimages are real-frame copies. Do not touch the real battler sprite.
    a[:echoes] = Array.new(3) do
      a.copy(a.user, force_visible: true, z: 20_012)
    end
    a[:body] = a.copy(a.user, hide_original: true, z: 20_020)
    a[:base_body] = [a[:body].x, a[:body].y, a[:body].angle]
    a[:base_body_color] = a[:body].color.clone

    a[:hand_glow] = a.sprite(glow, z: 20_022)
    a[:hand_ring] = a.sprite(ring_small, z: 20_024)
    a[:charge] = Array.new(30) { a.sprite(sparkle, z: 20_025) }
    a[:trail] = Array.new(10) { a.sprite(sparkle, z: 20_026) }
    a[:comet] = a.sprite(streak, z: 20_029)
    a[:fist] = a.sprite(knuckle, z: 20_030)

    a[:groups] = a.targets.map do |target|
      cx, cy = a.center(target)
      copy = a.copy(target, hide_original: true, z: 20_018)
      {
        cx: cx, cy: cy,
        copy: copy,
        base_x: copy.x, base_y: copy.y,
        base_color: copy.color.clone,
        glow: a.sprite(glow, z: 20_027),
        burst: a.sprite(burst, z: 20_032),
        rings: [a.sprite(ring_small, z: 20_034),
                a.sprite(ring_big, z: 20_035)],
        stars: Array.new(38) { a.sprite(sparkle, z: 20_036) }
      }
    end
  end
) do |a, _t|
  sec = a.seconds
  ux, uy = a[:user_center]
  tx, ty = a[:target_center]
  dir = a[:direction]
  hx, hy = a[:hand]
  mx, my = a[:motion]

  # 1. Star energy converges around the fist.
  charge = a.clamp((sec - 0.07) / 0.45)
  charge_out = a.clamp((0.81 - sec) / 0.22)
  fade = a.clamp((2.15 - sec) / 0.45)
  a[:veil].opacity = (a.clamp(sec / 0.22) * fade * 103).to_i

  ring = a[:hand_ring]
  ring.x, ring.y = hx, hy
  ring.zoom_x = 1.18 - charge * 0.72
  ring.zoom_y = ring.zoom_x * 0.78
  ring.opacity = (charge * charge_out * 230).to_i

  halo = a[:hand_glow]
  halo.x, halo.y = hx, hy
  halo.zoom_x = halo.zoom_y = 0.30 + charge * 0.95
  halo.opacity = (charge * charge_out * (150 + Math.sin(sec * 20) * 25)).to_i

  a[:charge].each_with_index do |s, i|
    q = (sec - 0.05 - (i % 6) * 0.026) / 0.57
    p = a.clamp(q)
    theta = i * 2.399 + sec * 3.9
    radius = (58 + (i % 4) * 10) * (1.0 - p * 0.88)
    s.x = hx + Math.cos(theta) * radius
    s.y = hy + Math.sin(theta) * radius * 0.70
    s.angle = i * 27 + sec * 90
    s.zoom_x = s.zoom_y = 0.14 + (i % 4) * 0.07
    s.opacity = q.between?(0.0, 1.0) ?
      (Math.sin(p * Math::PI) * charge_out * 240).to_i : 0
  end

  # 2. Lunging punch. The attacker is a managed visual copy only.
  dash = a.clamp((sec - 0.65) / 0.34)
  rush = dash * dash * (3.0 - 2.0 * dash)
  retreat = a.clamp((sec - 1.25) / 0.38)
  retreat = retreat * retreat * (3.0 - 2.0 * retreat)
  movement = rush * (1.0 - retreat)
  body = a[:body]
  bx, by, ba = a[:base_body]
  body.x = bx + mx * movement
  body.y = by + my * movement - Math.sin(movement * Math::PI) * 13
  body.angle = ba - dir * Math.sin(movement * Math::PI) * 7
  pulse = a.clamp((1.28 - sec) / 0.25) * charge
  body.color = pulse > 0 ?
    Color.new(255, 234, 194, (pulse * 65).to_i) : a[:base_body_color]

  a[:echoes].each_with_index do |s, i|
    q = a.clamp((sec - 0.65 - (i + 1) * 0.035) / 0.34)
    easing = q * q * (3.0 - 2.0 * q)
    s.x = bx + mx * easing
    s.y = by + my * easing - Math.sin(easing * Math::PI) * 13
    s.angle = ba - dir * Math.sin(easing * Math::PI) * 7
    s.color = Color.new(237, 183, 255, 185)
    s.opacity = sec.between?(0.68, 1.05) ?
      (a.clamp((sec - 0.68) / 0.08) *
       a.clamp((1.05 - sec) / 0.16) * (105 - i * 25)).to_i : 0
  end

  # Star knuckle flies from hand to the target, then disappears at contact.
  flight = a.clamp((sec - 0.66) / 0.33)
  flight = flight * flight * (3.0 - 2.0 * flight)
  fx = a.lerp(hx, tx, flight)
  fy = a.lerp(hy, ty, flight) - Math.sin(flight * Math::PI) * 19
  angle = -Math.atan2(ty - hy, tx - hx) * 180.0 / Math::PI
  visible_fist = a.clamp((sec - 0.35) / 0.20) *
                 a.clamp((1.04 - sec) / 0.09)

  fist = a[:fist]
  fist.x, fist.y = sec < 0.66 ? hx : fx, sec < 0.66 ? hy : fy
  fist.angle = angle
  fist.zoom_x = fist.zoom_y = 0.33 + charge * 0.22 + flight * 0.68
  fist.opacity = (visible_fist * 255).to_i

  comet = a[:comet]
  comet.x = fx - Math.cos(angle * Math::PI / 180) * 28
  comet.y = fy + Math.sin(angle * Math::PI / 180) * 28
  comet.angle = angle
  comet.zoom_x = 0.65 + flight * 0.50
  comet.zoom_y = 0.42 + flight * 0.20
  comet.opacity = sec.between?(0.66, 1.04) ?
    (Math.sin(flight * Math::PI) * 240).to_i : 0

  a[:trail].each_with_index do |s, i|
    q = a.clamp((sec - 0.68 - i * 0.020) / 0.34)
    s.x = a.lerp(hx, tx, q) + Math.sin(i * 2.4) * 13
    s.y = a.lerp(hy, ty, q) - Math.sin(q * Math::PI) * 18 +
          Math.cos(i * 2.4) * 10
    s.zoom_x = s.zoom_y = 0.22 + i % 3 * 0.08
    s.angle = sec * 120 + i * 30
    s.opacity = sec.between?(0.68 + i * 0.020, 1.11) ?
      (a.clamp((1.11 - sec) / 0.22) * 220).to_i : 0
  end

  # 3. Impact: expanding stellar shockwave and glitter fragments.
  hit = sec - 0.99
  flash = a.clamp(hit / 0.045) * a.clamp((1.18 - sec) / 0.15)
  a[:flash].opacity = (flash * 105).to_i

  a[:groups].each do |g|
    cx, cy = g[:cx], g[:cy]
    p = a.clamp(hit / 0.36)
    active = hit.between?(0.0, 0.36)

    burst = g[:burst]
    burst.x, burst.y = cx, cy
    burst.angle = p * 25
    burst.zoom_x = burst.zoom_y = 0.30 + p * 1.15
    burst.opacity = active ? ((1.0 - p)**1.6 * 255).to_i : 0

    shine = g[:glow]
    shine.x, shine.y = cx, cy
    shine.zoom_x = shine.zoom_y = 0.60 + p * 1.70
    shine.opacity = active ? ((1.0 - p) * 230).to_i : 0

    g[:rings].each_with_index do |s, i|
      q = (hit - i * 0.055) / 0.43
      rp = a.clamp(q)
      s.x, s.y = cx, cy
      s.zoom_x = 0.16 + rp * (i == 0 ? 1.95 : 1.35)
      s.zoom_y = s.zoom_x * (i == 0 ? 0.86 : 0.67)
      s.opacity = q.between?(0.0, 1.0) ?
        ((1.0 - rp) * 230).to_i : 0
    end

    # Only the visual target copy shakes. Real battler is never repositioned.
    knock = hit.between?(0.0, 0.27) ? (1.0 - hit / 0.27) : 0.0
    g[:copy].x = g[:base_x] + dir * knock * 9 +
                 Math.sin(hit * 105) * knock * 5
    g[:copy].y = g[:base_y] - knock * 2
    g[:copy].color = knock > 0 ?
      Color.new(255, 239, 196, (knock * 145).to_i) : g[:base_color]

    g[:stars].each_with_index do |s, i|
      q = (hit - (i % 6) * 0.019) / 0.73
      sp = a.clamp(q)
      theta = i * 2.399
      radius = (18 + i % 6 * 11) * (1.0 + sp * 1.10)
      s.x = cx + Math.cos(theta) * radius
      s.y = cy + Math.sin(theta) * radius * 0.72 + sp * sp * 45
      s.angle = i * 23 + sp * (i.even? ? 110 : -110)
      s.zoom_x = s.zoom_y = (0.18 + i % 4 * 0.07) * (1.0 - sp * 0.25)
      s.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(sp * Math::PI) * 242).to_i : 0
    end
  end
end
