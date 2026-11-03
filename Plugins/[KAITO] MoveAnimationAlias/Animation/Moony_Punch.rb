#===============================================================================
# MOONY PUNCH - Lunar knuckle / Dark-type physical move
# Pokemon Essentials v21.1 | Requires 000_AnimationCore.rb
#===============================================================================

KaitoAnimation.register(
  :MOONYPUNCH,
  duration: 2.20,
  require_target: true,
  setup: proc do |a|
    a.sound_at(0.05, ["PRSFX- Cosmic Power"], 55, 85)
    a.sound_at(0.48, ["PRSFX- Moonblast1"], 65, 85)
    a.sound_at(0.85, ["PRSFX- Mach Punch", "PRSFX- Bullet Punch"], 75, 95)
    a.sound_at(1.10, ["PRSFX- Mega Punch2", "PRSFX- Meteor Mash2"], 90, 90)
    a.sound_at(1.18, ["PRSFX- Moonblast2"], 70, 75)

    target = a.targets.first
    ux, uy = a.center
    tx, ty = a.center(target)
    dir = tx >= ux ? 1 : -1
    a[:ux], a[:uy], a[:tx], a[:ty], a[:dir] = ux, uy, tx, ty, dir
    a[:distance] = tx - ux - dir * 51

    user = a.copy(a.user, hide_original: true, z: 20_030)
    enemy = a.copy(target, hide_original: true, z: 20_029)
    a[:user], a[:enemy] = user, enemy
    a[:user_x], a[:user_y] = user.x, user.y
    a[:enemy_x], a[:enemy_y] = enemy.x, enemy.y
    a[:user_color], a[:enemy_color] = user.color.clone, enemy.color.clone

    veil = a.bitmap(Graphics.width, Graphics.height) do |b|
      b.fill_rect(0, 0, b.width, b.height, Color.new(19, 10, 37))
    end
    a[:veil] = a.sprite(veil, z: 19_990, centered: false)

    glow = a.bitmap(128, 128) do |b|
      128.times do |y|
        128.times do |x|
          r = Math.sqrt((x - 63.5)**2 + (y - 63.5)**2) / 63.5
          next if r > 1.0
          b.set_pixel(x, y, Color.new(178, 109, 244, ((1.0 - r)**2 * 125).to_i))
        end
      end
    end

    moon = a.bitmap(100, 100) do |b|
      100.times do |y|
        100.times do |x|
          outer = Math.sqrt((x - 49.5)**2 + (y - 49.5)**2)
          cut = Math.sqrt((x - 65.5)**2 + (y - 37.5)**2)
          next if outer > 40 || cut < 36
          color = outer > 36 ? Color.new(167, 99, 230, 225) :
                  Color.new(235, 198, 255, 250)
          b.set_pixel(x, y, color)
        end
      end
    end

    star = a.bitmap(26, 26) do |b|
      a.polygon(b, [[13, 0], [16, 10], [26, 13], [16, 16],
                    [13, 26], [10, 16], [0, 13], [10, 10]],
                Color.new(204, 155, 255, 225))
      a.polygon(b, [[13, 5], [15, 11], [21, 13], [15, 15],
                    [13, 21], [11, 15], [5, 13], [11, 11]],
                Color.new(255, 234, 251, 255))
      b.fill_rect(12, 12, 3, 3, Color.new(255, 255, 255))
    end

    fist = a.bitmap(96, 76) do |b|
      a.polygon(b, [[8, 29], [24, 18], [50, 18], [60, 28], [84, 30],
                    [92, 39], [87, 51], [61, 54], [48, 69], [16, 62],
                    [4, 47]], Color.new(96, 45, 166, 230))
      a.polygon(b, [[12, 29], [25, 23], [49, 23], [57, 34], [83, 35],
                    [86, 41], [80, 47], [57, 48], [44, 63], [18, 55]],
                Color.new(184, 125, 246, 245))
      a.polygon(b, [[18, 30], [29, 27], [49, 27], [55, 37],
                    [28, 40]], Color.new(246, 213, 255, 255))
      4.times do |i|
        b.fill_rect(60 + i * 6, 34, 4, 7, Color.new(255, 229, 255, 225))
      end
    end

    streak = a.bitmap(160, 30) do |b|
      a.polygon(b, [[0, 15], [121, 1], [159, 15], [121, 29]],
                Color.new(112, 57, 200, 135))
      a.polygon(b, [[35, 15], [139, 9], [159, 15], [139, 21]],
                Color.new(208, 153, 255, 205))
      a.polygon(b, [[90, 15], [146, 13], [159, 15], [146, 17]],
                Color.new(255, 239, 255, 255))
    end

    burst = a.bitmap(160, 160) do |b|
      12.times do |i|
        angle = i * Math::PI / 6
        tip = [80 + Math.cos(angle) * 76, 80 + Math.sin(angle) * 76]
        left = [80 + Math.cos(angle + 0.14) * 22,
                80 + Math.sin(angle + 0.14) * 22]
        right = [80 + Math.cos(angle - 0.14) * 22,
                 80 + Math.sin(angle - 0.14) * 22]
        a.polygon(b, [left, tip, right], Color.new(188, 120, 255, 210))
      end
      a.polygon(b, [[80, 36], [91, 69], [124, 80], [91, 91],
                    [80, 124], [69, 91], [36, 80], [69, 69]],
                Color.new(249, 223, 255, 245))
      b.fill_rect(73, 73, 14, 14, Color.new(255, 255, 255, 255))
    end

    ring = a.ring(58, Color.new(219, 167, 255, 240), 3)
    a[:charge_moon] = a.sprite(moon, z: 20_037)
    a[:charge_glow] = a.sprite(glow, z: 20_026)
    a[:charge_ring] = a.sprite(ring, z: 20_035)
    a[:charge_stars] = Array.new(24) { a.sprite(star, z: 20_040) }
    a[:trails] = Array.new(7) do
      s = a.sprite(streak, z: 20_033)
      s.blend_type = 1
      s
    end
    a[:fist] = a.sprite(fist, z: 20_043)
    a[:fist_glow] = a.sprite(glow, z: 20_038)
    a[:impact_glow] = a.sprite(glow, z: 20_044)
    a[:impact_burst] = a.sprite(burst, z: 20_047)
    a[:impact_moons] = Array.new(3) { a.sprite(moon, z: 20_045) }
    a[:impact_rings] = Array.new(3) { a.sprite(ring, z: 20_046) }
    a[:shards] = Array.new(40) { a.sprite(star, z: 20_048) }
    a[:weakening] = Array.new(12) { a.sprite(star, z: 20_041) }
  end
) do |a, _t|
  sec = a.seconds
  ux, uy, tx, ty, dir = a[:ux], a[:uy], a[:tx], a[:ty], a[:dir]
  charge = a.clamp(sec / 0.72)
  charge_fade = a.clamp((0.91 - sec) / 0.20)
  finish = a.clamp((2.20 - sec) / 0.35)
  a[:veil].opacity = (a.clamp(sec / 0.32) * finish * 110).to_i

  # Charge a crescent moon and orbiting starlight around the attacker.
  moon = a[:charge_moon]
  moon.x, moon.y = ux + dir * 25, uy - 48
  moon.angle = dir * (-13 + sec * 28)
  moon.zoom_x = moon.zoom_y = 0.24 + charge * 0.62
  moon.opacity = (charge * charge_fade * 235).to_i

  aura = a[:charge_glow]
  aura.x, aura.y = ux + dir * 30, uy - 13
  aura.zoom_x = 0.35 + charge * 0.85
  aura.zoom_y = 0.38 + charge * 0.75
  aura.opacity = (charge * charge_fade * 180).to_i

  ring = a[:charge_ring]
  ring.x, ring.y = ux + dir * 22, uy
  ring.zoom_x = 0.25 + charge * 0.82
  ring.zoom_y = ring.zoom_x * 0.42
  ring.opacity = (charge * charge_fade * 210).to_i

  a[:charge_stars].each_with_index do |s, i|
    start = i % 6 * 0.045
    p = a.clamp((sec - start) / 0.68)
    angle = i * 2.399 + sec * 3.6
    radius = (70 - p * 42) * (1.0 - charge * 0.35)
    s.x = ux + dir * 30 + Math.cos(angle) * radius
    s.y = uy - 12 + Math.sin(angle) * radius * 0.70
    s.angle = i * 25 + sec * 80
    s.zoom_x = s.zoom_y = 0.16 + i % 4 * 0.08
    s.opacity = (Math.sin(p * Math::PI) * charge_fade * 240).to_i
  end

  # Fast physical lunge, then smooth return to the starting position.
  if sec < 0.78
    offset = 0.0
  elsif sec < 1.11
    p = a.clamp((sec - 0.78) / 0.33)
    offset = p * p * (3.0 - 2.0 * p)
  elsif sec < 1.47
    offset = 1.0
  elsif sec < 1.94
    p = a.clamp((sec - 1.47) / 0.47)
    offset = 1.0 - p * p * (3.0 - 2.0 * p)
  else
    offset = 0.0
  end

  body = a[:user]
  body.x = a[:user_x] + a[:distance] * offset
  body.y = a[:user_y] - Math.sin(offset * Math::PI) * 12
  body.angle = dir * (offset * 9)
  body.color = sec.between?(0.73, 1.25) ?
    Color.new(208, 151, 255, (a.clamp((1.25 - sec) / 0.25) * 110).to_i) :
    a[:user_color]

  # Meteor-like motion trails follow the advancing fist.
  fx = ux + a[:distance] * offset + dir * 43
  fy = uy - Math.sin(offset * Math::PI) * 12 - 10
  moving = a.clamp((sec - 0.79) / 0.10) * a.clamp((1.20 - sec) / 0.18)
  a[:trails].each_with_index do |s, i|
    s.x = fx - dir * (17 + i * 19)
    s.y = fy + Math.sin(sec * 21 - i * 0.9) * (3 + i)
    s.mirror = dir < 0
    s.zoom_x = 0.68 - i * 0.065
    s.zoom_y = 0.68 - i * 0.055
    s.opacity = (moving * (195 - i * 21)).to_i
  end

  fist = a[:fist]
  fist.x, fist.y = fx, fy
  fist.mirror = dir < 0
  fist.angle = dir * (-8 + Math.sin(sec * 25) * 5)
  fist.zoom_x = fist.zoom_y = 0.45 + a.clamp((sec - 0.79) / 0.25) * 0.42
  fist.opacity = (moving * 245).to_i

  fg = a[:fist_glow]
  fg.x, fg.y = fx, fy
  fg.zoom_x = fg.zoom_y = 0.40 + moving * 0.75
  fg.opacity = (moving * 180).to_i

  # Moonlight shock wave and spectral fragments upon impact.
  hit = a.clamp((sec - 1.10) / 0.45)
  hit_active = sec.between?(1.10, 1.58)
  glow = a[:impact_glow]
  glow.x, glow.y = tx, ty
  glow.zoom_x = glow.zoom_y = 0.45 + hit * 2.10
  glow.opacity = hit_active ? ((1.0 - hit)**2 * 230).to_i : 0

  burst = a[:impact_burst]
  burst.x, burst.y = tx, ty
  burst.angle = sec * 110
  burst.zoom_x = burst.zoom_y = 0.32 + hit * 1.08
  burst.opacity = hit_active ? ((1.0 - hit)**1.5 * 255).to_i : 0

  a[:impact_moons].each_with_index do |s, i|
    angle = i * Math::PI * 2 / 3 + 0.3
    radius = 9 + hit * (35 + i * 14)
    s.x = tx + Math.cos(angle) * radius
    s.y = ty + Math.sin(angle) * radius * 0.7
    s.angle = i * 120 + hit * 95
    s.zoom_x = s.zoom_y = 0.20 + hit * 0.27
    s.opacity = hit_active ? ((1.0 - hit) * 235).to_i : 0
  end

  a[:impact_rings].each_with_index do |s, i|
    q = (sec - 1.10 - i * 0.055) / 0.43
    p = a.clamp(q)
    s.x, s.y = tx, ty
    s.zoom_x = 0.25 + p * (1.45 + i * 0.30)
    s.zoom_y = s.zoom_x * (i == 0 ? 0.82 : 0.58)
    s.opacity = q.between?(0.0, 1.0) ? ((1.0 - p) * 220).to_i : 0
  end

  a[:shards].each_with_index do |s, i|
    q = (sec - 1.12 - i % 5 * 0.018) / 0.78
    p = a.clamp(q)
    angle = i * 2.399
    radius = 10 + p * (48 + i % 7 * 12)
    s.x = tx + Math.cos(angle) * radius
    s.y = ty + Math.sin(angle) * radius * 0.68 + p * p * 31
    s.angle = i * 31 + p * (i.even? ? 125 : -125)
    s.zoom_x = s.zoom_y = (0.17 + i % 4 * 0.085) * (1.0 - p * 0.42)
    s.opacity = q.between?(0.0, 1.0) ? (Math.sin(p * Math::PI) * 245).to_i : 0
  end

  # Brief dark wisps suggest the possible Sp. Atk reduction (visual only).
  a[:weakening].each_with_index do |s, i|
    q = (sec - 1.46 - i % 4 * 0.035) / 0.59
    p = a.clamp(q)
    angle = i * 2.399
    s.x = tx + Math.cos(angle) * (23 + p * 18)
    s.y = ty - 22 + p * (58 + i % 3 * 13)
    s.angle = i * 33 - p * 90
    s.color = Color.new(47, 19, 100, 190)
    s.zoom_x = s.zoom_y = 0.13 + i % 3 * 0.07
    s.opacity = q.between?(0.0, 1.0) ? (Math.sin(p * Math::PI) * 175).to_i : 0
  end

  enemy = a[:enemy]
  shake = a.clamp((sec - 1.10) / 0.38)
  amplitude = sec.between?(1.10, 1.48) ? (1.0 - shake) * 9 : 0.0
  enemy.x = a[:enemy_x] + Math.sin((sec - 1.10) * 100) * amplitude
  enemy.y = a[:enemy_y]
  enemy.color = sec.between?(1.10, 1.34) ?
    Color.new(229, 185, 255, (a.clamp((1.34 - sec) / 0.24) * 180).to_i) :
    a[:enemy_color]
end
