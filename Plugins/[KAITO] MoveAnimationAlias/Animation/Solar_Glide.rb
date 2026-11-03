#===============================================================================
# SOLAR GLIDE - Silken Flight (Remake)
# Pokemon Essentials v21.1 | Requires 000_AnimationCore.rb
# Light, graceful dash with ivory-jade ribbons and soft afterimages.
# No sun disc, leaves, or external spritesheets.
#===============================================================================
module KaitoSolarGlideVisual
  DURATION = 1.95

  def self.ribbon(a)
    a.bitmap(188, 36) do |b|
      a.polygon(b, [[0, 18], [44, 13], [115, 10], [175, 15],
                    [187, 18], [175, 21], [115, 26], [44, 23]],
                Color.new(67, 186, 149, 82))
      a.polygon(b, [[22, 18], [88, 14], [163, 16], [186, 18],
                    [163, 20], [88, 22]],
                Color.new(149, 238, 205, 189))
      a.polygon(b, [[54, 18], [120, 17], [186, 18],
                    [120, 19]], Color.new(253, 255, 232, 238))
    end
  end

  def self.curve(a)
    a.bitmap(192, 64) do |b|
      3.times do |layer|
        width = [5, 3, 1][layer]
        color = [Color.new(67, 182, 150, 100),
                 Color.new(158, 237, 207, 198),
                 Color.new(253, 255, 233, 236)][layer]
        165.times do |i|
          p = i / 164.0
          x = 12 + i
          y = 36 - Math.sin(p * Math::PI) * 20 + p * 7
          alpha = Math.sin(p * Math::PI)
          b.fill_rect(x, y.round - width / 2, width, width,
                      Color.new(color.red, color.green, color.blue,
                                (color.alpha * alpha).round))
        end
      end
    end
  end

  def self.glow(a)
    a.bitmap(96, 96) do |b|
      96.times do |y|
        96.times do |x|
          r = ((x - 47.5)**2 + (y - 47.5)**2) / (47.5**2)
          next if r >= 1.0
          b.set_pixel(x, y, Color.new(190, 249, 208,
                       ((1.0 - r)**2 * 168).round))
        end
      end
    end
  end

  def self.arc(a)
    a.bitmap(132, 132) do |b|
      [[51, 225, 3], [56, 128, 2]].each do |radius, alpha, thickness|
        175.times do |i|
          theta = (-125 + i * 1.43) * Math::PI / 180.0
          x = 66 + Math.cos(theta) * radius
          y = 66 + Math.sin(theta) * radius
          b.fill_rect(x.round, y.round, thickness, thickness,
                      Color.new(214, 251, 221, alpha))
        end
      end
    end
  end

  def self.mote(a)
    a.bitmap(14, 14) do |b|
      14.times do |y|
        14.times do |x|
          r = ((x - 6.5)**2 + (y - 6.5)**2) / 42.25
          next if r > 1
          b.set_pixel(x, y, Color.new(249, 255, 231,
                       ((1.0 - r)**2 * 233).round))
        end
      end
    end
  end
end

KaitoAnimation.register(
  :SOLARGLIDE,
  duration: KaitoSolarGlideVisual::DURATION,
  require_target: true,
  setup: proc do |a|
    a.sound_at(0.12, ["PRSFX- Energy Ball1"], 38, 130)
    a.sound_at(0.52, ["PRSFX- Quick Attack"], 73, 121)
    a.sound_at(0.76, ["PRSFX- Air Slash1"], 63, 127)
    a.sound_at(0.94, ["PRSFX- Body Slam1", "PRSFX- Tackle"], 83, 118)

    target = a.targets.first
    ux, uy = a.center(a.user)
    tx, ty = a.center(target)
    dx, dy = tx - ux, ty - uy
    distance = [Math.sqrt(dx * dx + dy * dy), 1.0].max
    dir = dx >= 0 ? 1 : -1
    a[:ux], a[:uy], a[:tx], a[:ty], a[:dir] = ux, uy, tx, ty, dir
    a[:dx] = dx - dx / distance * 28
    a[:dy] = dy - dy / distance * 28
    a[:angle] = -Math.atan2(dy, dx) * 180 / Math::PI

    # Managed copies of the real battlers. Restored by AnimationCore.
    user = a.copy(a.user, hide_original: true, z: 20_030)
    foe = a.copy(target, hide_original: true, z: 20_026)
    a[:user], a[:foe] = user, foe
    a[:user_x], a[:user_y] = user.x, user.y
    a[:foe_x], a[:foe_y] = foe.x, foe.y
    a[:user_color], a[:foe_color] = user.color.clone, foe.color.clone

    # Afterimages use the actual Pokemon frame, not a silhouette graphic.
    a[:echoes] = Array.new(5) do
      a.copy(a.user, force_visible: true, z: 20_019)
    end

    ribbon_b = KaitoSolarGlideVisual.ribbon(a)
    curve_b = KaitoSolarGlideVisual.curve(a)
    glow_b = KaitoSolarGlideVisual.glow(a)
    arc_b = KaitoSolarGlideVisual.arc(a)
    mote_b = KaitoSolarGlideVisual.mote(a)
    ring_b = a.ring(46, Color.new(205, 252, 218, 218), 2)

    a[:ready] = Array.new(3) { a.sprite(curve_b, z: 20_022) }
    a[:ready_motes] = Array.new(12) { a.sprite(mote_b, z: 20_024) }
    a[:aura] = a.sprite(glow_b, z: 20_021)
    a[:wake] = Array.new(5) { a.sprite(ribbon_b, z: 20_022) }
    a[:flow] = Array.new(3) { a.sprite(curve_b, z: 20_025) }
    a[:impact_glow] = a.sprite(glow_b, z: 20_039)
    a[:impact_arcs] = Array.new(3) { a.sprite(arc_b, z: 20_040) }
    a[:impact_ring] = a.sprite(ring_b, z: 20_041)
    a[:impact_motes] = Array.new(15) { a.sprite(mote_b, z: 20_042) }
  end
) do |a, _t|
  sec = a.seconds
  ux, uy, tx, ty, dir = a[:ux], a[:uy], a[:tx], a[:ty], a[:dir]

  # Quiet concentration: only fine strokes moving around the battler.
  charge = a.clamp(sec / 0.42)
  charge_fade = a.clamp((0.66 - sec) / 0.15)
  a[:ready].each_with_index do |s, i|
    q = (sec - i * 0.085) / 0.49
    p = a.clamp(q)
    s.x = ux + dir * (13 - p * 22)
    s.y = uy + [-22, 0, 19][i]
    s.angle = [18, -8, -22][i] * dir
    s.mirror = dir < 0
    s.zoom_x = 0.30 + p * 0.34
    s.zoom_y = 0.40 + p * 0.22
    s.opacity = q.between?(0.0, 1.0) ?
      (Math.sin(p * Math::PI) * charge_fade * 135).to_i : 0
  end

  a[:ready_motes].each_with_index do |s, i|
    q = (sec - i % 4 * 0.045) / 0.52
    p = a.clamp(q)
    theta = i * 2.399
    s.x = ux + Math.cos(theta) * (40 - p * 25)
    s.y = uy + Math.sin(theta) * (26 - p * 16)
    s.zoom_x = s.zoom_y = 0.35 + i % 3 * 0.13
    s.opacity = q.between?(0.0, 1.0) ?
      (Math.sin(p * Math::PI) * charge_fade * 170).to_i : 0
  end

  # A weightless glide: accelerate, touch the target, float back.
  if sec < 0.48
    travel = 0.0
  elsif sec < 0.95
    p = a.clamp((sec - 0.48) / 0.47)
    travel = p * p * (3.0 - 2.0 * p)
  elsif sec < 1.14
    travel = 1.0
  elsif sec < 1.69
    p = a.clamp((sec - 1.14) / 0.55)
    travel = 1.0 - p * p * (3.0 - 2.0 * p)
  else
    travel = 0.0
  end

  bx = a[:user_x] + a[:dx] * travel
  by = a[:user_y] + a[:dy] * travel - Math.sin(travel * Math::PI) * 11
  cx = ux + a[:dx] * travel
  cy = uy + a[:dy] * travel - Math.sin(travel * Math::PI) * 11
  rushing = a.clamp((sec - 0.51) / 0.14) *
            a.clamp((1.09 - sec) / 0.18)

  user = a[:user]
  user.x, user.y = bx, by
  user.angle = dir * (Math.sin(travel * Math::PI) * 5)
  user.color = rushing > 0 ?
    Color.new(213, 254, 218, (rushing * 62).to_i) : a[:user_color]

  # Five translucent copies form a soft motion blur, not a sharp attack beam.
  a[:echoes].each_with_index do |s, i|
    previous = a.clamp((sec - 0.48 - (i + 1) * 0.038) / 0.47)
    previous = previous * previous * (3.0 - 2.0 * previous)
    s.x = a[:user_x] + a[:dx] * previous
    s.y = a[:user_y] + a[:dy] * previous -
          Math.sin(previous * Math::PI) * 11
    s.angle = dir * Math.sin(previous * Math::PI) * 5
    s.color = Color.new(183, 248, 207, 130)
    s.opacity = (rushing * (100 - i * 14)).to_i
  end

  aura = a[:aura]
  aura.x, aura.y = cx, cy
  aura.zoom_x, aura.zoom_y = 0.66 + rushing * 0.55, 0.85
  aura.opacity = (rushing * 115).to_i

  a[:wake].each_with_index do |s, i|
    s.x = cx - dir * (26 + i * 19)
    s.y = cy + Math.sin(sec * 13 - i * 0.55) * (4 + i)
    s.angle = a[:angle] * 0.65
    s.mirror = dir < 0
    s.zoom_x = 0.42 + i * 0.045
    s.zoom_y = 0.30 + i * 0.045
    s.opacity = (rushing * (154 - i * 25)).to_i
  end

  a[:flow].each_with_index do |s, i|
    s.x = cx - dir * (29 + i * 17)
    s.y = cy + [-14, 1, 15][i]
    s.mirror = dir < 0
    s.angle = a[:angle] * 0.50 + [-6, 2, 9][i]
    s.zoom_x, s.zoom_y = 0.47 + i * 0.065, 0.43
    s.opacity = (rushing * (153 - i * 19)).to_i
  end

  # Restrained impact: a soft flash and three broken, expanding contours.
  age = sec - 0.95
  active = age.between?(0.0, 0.57)
  impact = a.clamp(age / 0.57)

  glow = a[:impact_glow]
  glow.x, glow.y = tx, ty
  glow.zoom_x = glow.zoom_y = 0.38 + impact * 1.32
  glow.opacity = active ? ((1.0 - impact)**2 * 195).to_i : 0

  a[:impact_arcs].each_with_index do |s, i|
    q = (age - i * 0.060) / 0.44
    p = a.clamp(q)
    s.x, s.y = tx, ty
    s.angle = [-25, 80, 195][i] + p * 29
    s.zoom_x = 0.43 + p * (1.20 + i * 0.15)
    s.zoom_y = s.zoom_x * 0.73
    s.opacity = q.between?(0.0, 1.0) ?
      ((1.0 - p)**1.25 * (191 - i * 20)).to_i : 0
  end

  ring = a[:impact_ring]
  ring.x, ring.y = tx, ty
  ring.zoom_x = 0.23 + impact * 1.53
  ring.zoom_y = ring.zoom_x * 0.62
  ring.opacity = active ? ((1.0 - impact) * 160).to_i : 0

  a[:impact_motes].each_with_index do |s, i|
    q = (age - i % 5 * 0.030) / 0.66
    p = a.clamp(q)
    theta = i * 2.399
    distance = p * (26 + i % 5 * 11)
    s.x = tx + Math.cos(theta) * distance
    s.y = ty + Math.sin(theta) * distance * 0.65 -
          Math.sin(p * Math::PI) * 12
    s.zoom_x = s.zoom_y = 0.25 + i % 3 * 0.10
    s.opacity = q.between?(0.0, 1.0) ?
      (Math.sin(p * Math::PI) * 183).to_i : 0
  end

  foe = a[:foe]
  recoil = active ? (1.0 - impact) * 5.0 : 0.0
  foe.x = a[:foe_x] + Math.sin(age * 81) * recoil
  foe.y = a[:foe_y] - Math.sin(age * 63).abs * recoil * 0.15
  foe.color = age.between?(0.0, 0.22) ?
    Color.new(232, 255, 223, (a.clamp((0.22 - age) / 0.22) * 115).to_i) :
    a[:foe_color]
end