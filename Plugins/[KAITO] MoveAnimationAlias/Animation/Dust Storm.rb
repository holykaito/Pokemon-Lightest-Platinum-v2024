#===============================================================================
# Dust Storm v3 - Complete Remake
# Requires: KaitoAnimation Core v1.0
# Move ID: DUSTSTORM
#
# Gather: 0.5s / Storm: 1.2s / Settle: 0.8s
# Visuals only. Damage and secondary effects belong to the move.
#===============================================================================
KaitoAnimation.register(
  :DUSTSTORM,
  duration: 2.50,
  setup: proc do |a|
    # Gathering wind, stomp, rushing storm, then quieter wind.
    a.sound_at(
      0.04, ["PRSFX- Roar", "PRSFX- Noble Roar1"], 48, 85
    )
    a.sound_at(0.08, "PRSFX- Razor Wind1", 48, 75)
    a.sound_at(0.22, "PRSFX- Earth Power", 52, 80)
    a.sound_at(0.50, "PRSFX- Razor Wind2", 90, 80)
    a.sound_at(0.78, "PRSFX- Rock Slide", 65, 105)
    a.sound_at(1.15, "PRSFX- Rock Slide", 60, 115)
    a.sound_at(1.72, "PRSFX- Razor Wind1", 32, 100)
    a.sound_at(2.10, "PRSFX- Razor Wind1", 16, 110)

    #===========================================================================
    # Soft brown and golden dust
    #===========================================================================
    clouds = [
      [143, 94, 49],
      [218, 175, 109]
    ].map do |rgb|
      a.bitmap(96, 72) do |b|
        (0...72).step(2) do |y|
          (0...96).step(2) do |x|
            r = ((x-47.0)/47.0)**2 +
                ((y-35.0)/35.0)**2
            next if r >= 1

            b.fill_rect(
              x, y, 2, 2,
              Color.new(*rgb, ((1-r)**1.25*175).round)
            )
          end
        end
      end
    end

    #===========================================================================
    # Curved bands forming the cyclone
    #===========================================================================
    curl = a.bitmap(196, 84) do |b|
      [
        [6, [139, 87, 40, 220]],
        [3, [245, 205, 140, 245]]
      ].each do |width, rgba|
        outer, inner = [], []

        81.times do |i|
          p = i / 80.0
          angle = -Math::PI*0.6 + p*Math::PI*1.7
          w = Math.sin(p*Math::PI)**0.6 * width

          outer << [
            98 + Math.cos(angle)*(88+w),
            42 + Math.sin(angle)*(29+w*0.4)
          ]
          inner << [
            98 + Math.cos(angle)*(88-w),
            42 + Math.sin(angle)*(29-w*0.4)
          ]
        end

        a.polygon(
          b, outer + inner.reverse, Color.new(*rgba)
        )
      end
    end

    #===========================================================================
    # Wind rushing toward the opposing side
    #===========================================================================
    gust = a.bitmap(220, 36) do |b|
      [
        [7, [153, 101, 48, 210]],
        [2, [255, 224, 169, 245]]
      ].each do |width, rgba|
        upper, lower = [], []

        57.times do |i|
          p = i / 56.0
          x = 3 + p*213
          y = 18 + Math.sin(p*Math::PI*2)*5
          w = Math.sin(p*Math::PI)**0.6 * width

          upper << [x, y-w]
          lower << [x, y+w]
        end

        a.polygon(
          b, upper + lower.reverse, Color.new(*rgba)
        )
      end
    end

    sand = a.bitmap(8, 10) do |b|
      a.polygon(
        b,
        [[4,0], [7,3], [5,9], [0,6]],
        Color.new(247, 206, 137, 250)
      )
      b.fill_rect(
        3, 2, 2, 3, Color.new(255, 239, 189, 255)
      )
    end

    stone = a.bitmap(18, 20) do |b|
      a.polygon(
        b,
        [[5,1], [14,3], [17,11], [10,19], [2,16], [0,7]],
        Color.new(112, 74, 39, 250)
      )
      a.polygon(
        b,
        [[5,3], [12,4], [10,11], [2,8]],
        Color.new(210, 159, 91, 255)
      )
    end

    warm = a.bitmap(Graphics.width, Graphics.height) do |b|
      b.fill_rect(
        0, 0, Graphics.width, Graphics.height,
        Color.new(213, 151, 77, 255)
      )
    end

    shock = a.ring(
      66, Color.new(236, 192, 120, 220), 3
    )

    a[:warm] = a.sprite(warm, z: 20_000, centered: false)
    a[:source] = a.center

    src = a.battler_sprite
    a[:start_ground] = src.y +
      (src.src_rect.height-src.oy)*src.zoom_y

    # Copies keep the Pokemon's original display size.
    a[:actor] = a.copy(hide_original: true, z: 20_014)
    a[:actor_xy] = [a[:actor].x, a[:actor].y]
    a[:shock] = a.sprite(shock, z: 20_019)

    a[:victims] = a.targets.map do |target|
      s = a.battler_sprite(target)
      cx, cy = a.center(target)
      copy = a.copy(target, hide_original: true, z: 20_014)

      {
        center: [cx, cy],
        ground: s.y + (s.src_rect.height-s.oy)*s.zoom_y,
        height: s.src_rect.height*s.zoom_y,
        copy: copy,
        x: copy.x,
        y: copy.y,
        opacity: copy.opacity,
        color: copy.color.clone
      }
    end

    # One cyclone grows wide enough to cover the target group.
    victims = a[:victims]
    count = victims.length.to_f
    ex = victims.sum { |g| g[:center][0] } / count
    ey = victims.sum { |g| g[:center][1] } / count
    ground = victims.sum { |g| g[:ground] } / count

    xs = victims.map { |g| g[:center][0] }
    span = xs.max-xs.min

    a[:finish] = [ex, ey, ground]
    a[:radius] = [100.0, span/2.0+78].max

    max_height = victims.map { |g| g[:height] }.max + 45
    a[:height] = [
      [max_height, 145].max,
      [ground-8, 225].min
    ].min

    ux, uy = a[:source]
    dx, dy = ex-ux, ey-uy
    length = [Math.sqrt(dx*dx+dy*dy), 1.0].max

    a[:normal] = [-dy/length, dx/length]
    a[:angle] = -Math.atan2(dy, dx)*180/Math::PI
    a[:direction] = dx >= 0 ? 1 : -1

    a[:clouds] = Array.new(32) do |i|
      a.sprite(clouds[i%2], z: 20_025)
    end
    a[:curls] = Array.new(9) do
      a.sprite(curl, z: 20_028)
    end
    a[:sand] = Array.new(100) do
      a.sprite(sand, z: 20_032)
    end
    a[:stones] = Array.new(22) do
      a.sprite(stone, z: 20_033)
    end
    a[:gusts] = Array.new(8) do
      a.sprite(gust, z: 20_030)
    end
  end
) do |a, _t|
  sec = a.seconds
  ux, uy = a[:source]
  ex, ey, ground = a[:finish]

  gather = a.clamp(sec/0.50)

  travel = a.clamp((sec-0.50)/0.62)
  travel = travel*travel*(3-2*travel)

  growth = a.clamp((sec-0.50)/0.55)
  fall = a.clamp((sec-1.70)/0.80)

  # Freeze the cyclone's rotation when the settling phase starts.
  clock = [sec, 1.70].min
  spin = if clock < 0.50
    clock*8.0
  else
    4.0 + (clock-0.50)*11.0
  end

  cx = a.lerp(ux, ex, travel)
  floor = a.lerp(a[:start_ground], ground, travel)

  height = if sec < 0.50
    12 + gather*16
  else
    a.lerp(28, a[:height], growth)
  end

  radius = if sec < 0.50
    24 + gather*20
  else
    a.lerp(44, a[:radius], growth)
  end

  envelope = a.clamp(sec/0.18)*(1-fall)**1.15
  power = sec < 0.50 ? 0.35+gather*0.40 : 1.0

  warmth = sec < 0.50 ? gather*38 : 38+growth*22
  a[:warm].opacity = (warmth*(1-fall)).round

  #=============================================================================
  # Phase 1: small stomp and gathering dust — 0.0 to 0.5 seconds
  #=============================================================================
  ax, ay = a[:actor_xy]

  lift = if sec < 0.22
    Math.sin(sec/0.22*Math::PI)*6
  else
    0
  end

  stomp = if sec >= 0.22 && sec < 0.38
    p = (sec-0.22)/0.16
    Math.sin(p*Math::PI*3)*(1-p)*2
  else
    0
  end

  a[:actor].x, a[:actor].y = ax, ay-lift+stomp

  q = (sec-0.22)/0.35
  p = a.clamp(q)

  shock = a[:shock]
  shock.x, shock.y = ux, a[:start_ground]-2
  shock.zoom_x = 0.25+p*1.05
  shock.zoom_y = shock.zoom_x*0.26

  shock.opacity = if q >= 0 && q <= 1
    ((1-p)*200).round
  else
    0
  end

  #=============================================================================
  # Phase 2: rushing wind and a growing cyclone — 0.5 to 1.7 seconds
  #=============================================================================
  nx, ny = a[:normal]

  a[:gusts].each_with_index do |s, i|
    q = (sec-0.50-i*0.095)/0.48
    p = a.clamp(q)

    s.x = a.lerp(ux, ex, p) + nx*(i%3-1)*23
    s.y = a.lerp(uy, ey, p) + ny*(i%3-1)*23
    s.angle = a[:angle]
    s.zoom_x = 0.75+p*0.40
    s.zoom_y = 0.85+i%3*0.15

    s.opacity = if q >= 0 && q <= 1
      (Math.sin(p*Math::PI)*235).round
    else
      0
    end
  end

  a[:curls].each_with_index do |s, i|
    level = (i+0.5)/9.0
    r = radius*(0.24+level*0.76)

    s.x = cx + Math.sin(spin+i*0.8)*r*0.12
    s.y = floor-height*level
    s.zoom_x = r/88.0
    s.zoom_y = [r/88.0*0.70, 0.18].max
    s.angle = Math.sin(spin+i)*10

    s.opacity = (
      envelope * power *
      (1-a.clamp(fall/0.45)) * 215
    ).round
  end

  a[:clouds].each_with_index do |s, i|
    level = (i*0.137+clock*0.24) % 1.0
    theta = i*2.399+spin
    r = radius*(0.24+level*0.76)
    front = Math.sin(theta)

    s.x = cx + Math.cos(theta)*r*0.84 +
          a[:direction]*fall*10
    s.y = [
      floor-height*level + front*r*0.16 +
      fall*(25+i%5*10),
      floor
    ].min

    s.zoom_x = 0.45+level*0.85+growth*0.22+fall*0.30
    s.zoom_y = 0.38+level*0.55+growth*0.15
    s.z = front < 0 ? 20_010 : 20_025
    s.opacity = (envelope*power*(110+i%4*18)).round
  end

  #=============================================================================
  # Phase 3: rotation stops; sand and stones fall — 1.7 to 2.5 seconds
  #=============================================================================
  [a[:sand], a[:stones]].each_with_index do |list, kind|
    list.each_with_index do |s, i|
      speed = kind == 0 ? 0.48 : 0.35
      level = (i*0.073+clock*speed) % 1.0
      theta = i*2.399 + spin*(kind == 0 ? 1.25 : 0.85)
      r = radius*(0.20+level*0.80)
      front = Math.sin(theta)

      s.x = cx + Math.cos(theta)*r +
            a[:direction]*fall*(6+i%4*3)
      s.y = [
        floor-height*level + front*r*0.18 +
        fall*fall*(100+i%7*18),
        floor-1
      ].min

      s.angle = i*37 +
                clock*(kind == 0 ? 260 : 170) + fall*90

      size = if kind == 0
        0.35+i%4*0.16
      else
        0.34+i%4*0.13
      end

      s.zoom_x = s.zoom_y = size
      s.z = front < 0 ? 20_012 : 20_033
      s.opacity = (
        envelope*power*(front < 0 ? 155 : 245)
      ).round
    end
  end

  # Opponents become silhouettes inside the dust, then regain visibility.
  cover = travel*growth*(1-fall)

  a[:victims].each do |g|
    copy = g[:copy]
    copy.opacity = (g[:opacity]*(1-cover*0.42)).round

    copy.color = if cover > 0
      Color.new(78, 51, 29, (cover*185).round)
    else
      g[:color]
    end

    copy.x = g[:x] + Math.sin(clock*43)*cover*2
    copy.y = g[:y]
  end
end