#===============================================================================
# Wyrm Winds - Pokemon Essentials v21.1
# Requires: KaitoAnimation Core v1.0
# Move ID: WYRMWIND
# Visuals only. Hit count and damage are handled by the move.
#===============================================================================
KaitoAnimation.register(
  :WYRMWIND,
  duration: 0.90,
  setup: proc do |a|
    pitch = 105 + a.hit_num.to_i % 5 * 4

    a.sound_at(
      0.02,
      ["PRSFX- Twister", "PRSFX- Gust"],
      60, pitch
    )
    a.sound_at(
      0.43,
      ["PRSFX- Dragon Breath", "PRSFX- Air Cutter"],
      65, pitch
    )

    #===========================================================================
    # Flowing draconic wind ribbons
    #===========================================================================
    wind = a.bitmap(184, 88) do |b|
      [-18, 0, 18].each_with_index do |offset, band|
        [
          [1.00, [113, 83, 207, 180]],
          [0.68, [96, 225, 239, 235]],
          [0.20, [239, 255, 248, 250]]
        ].each do |width, rgba|
          upper, lower = [], []

          65.times do |i|
            p = i / 64.0
            x = 3 + p*177
            y = 44 + offset +
                Math.sin(p*Math::PI*2 + band*0.6)*9
            half = Math.sin(p*Math::PI)**0.7 * 7 * width

            upper << [x, y-half]
            lower << [x, y+half]
          end

          a.polygon(
            b, upper + lower.reverse, Color.new(*rgba)
          )
        end
      end
    end

    #===========================================================================
    # Scale-shaped energy fragments
    #===========================================================================
    scale = a.bitmap(14, 24) do |b|
      a.polygon(
        b,
        [[7,0], [13,8], [9,20], [3,23], [1,12]],
        Color.new(115, 216, 243, 235)
      )
      a.polygon(
        b,
        [[7,4], [9,9], [6,17], [4,18]],
        Color.new(241, 255, 248, 245)
      )
    end

    #===========================================================================
    # Curved wind blade
    #===========================================================================
    arc = a.bitmap(112, 112) do |b|
      outer, inner = [], []

      57.times do |i|
        p = i / 56.0
        angle = -Math::PI*0.80 + p*Math::PI*1.45
        half = Math.sin(p*Math::PI)**0.7 * 6

        outer << [
          56 + Math.cos(angle)*(43+half),
          56 + Math.sin(angle)*(43+half)
        ]
        inner << [
          56 + Math.cos(angle)*(43-half),
          56 + Math.sin(angle)*(43-half)
        ]
      end

      a.polygon(
        b, outer + inner.reverse,
        Color.new(168, 242, 251, 235)
      )
    end

    halo = a.ring(
      54, Color.new(169, 141, 239, 205), 2
    )

    a[:source] = a.center
    a[:phase] = a.hit_num.to_i * Math::PI * 0.37

    a[:groups] = a.targets.map do |target|
      tx, ty = a.center(target)
      ux, uy = a[:source]
      dx, dy = tx-ux, ty-uy
      length = [Math.sqrt(dx*dx + dy*dy), 1.0].max

      {
        center: [tx, ty],
        delta: [dx, dy],
        normal: [-dy/length, dx/length],
        angle: -Math.atan2(dy, dx)*180/Math::PI,
        gust: a.sprite(wind, z: 20_025),
        echoes: Array.new(2) do
          a.sprite(wind, z: 20_023)
        end,
        arcs: Array.new(3) do
          a.sprite(arc, z: 20_029)
        end,
        halo: a.sprite(halo, z: 20_026),
        particles: Array.new(22) do
          a.sprite(scale, z: 20_031)
        end
      }
    end
  end
) do |a, t|
  ux, uy = a[:source]
  phase = a[:phase]

  a[:groups].each do |g|
    cx, cy = g[:center]
    dx, dy = g[:delta]
    nx, ny = g[:normal]

    #===========================================================================
    # Wind travels toward the target with two trailing echoes
    #===========================================================================
    ([g[:gust]] + g[:echoes]).each_with_index do |s, i|
      q = (t - 0.04 - i*0.035) / 0.44
      p = a.clamp(q)

      wobble = Math.sin(p*Math::PI*2 + phase) *
               Math.sin(p*Math::PI)*9
      travel = 0.14 + p*0.86

      s.x = ux + dx*travel + nx*wobble
      s.y = uy + dy*travel + ny*wobble
      s.angle = g[:angle] +
                Math.sin(p*Math::PI*2 + phase)*5

      s.zoom_x = 0.48 + p*0.27
      s.zoom_y = 0.55 + p*0.23

      s.opacity = if q >= 0 && q <= 1
        (Math.sin(p*Math::PI)*(245-i*75)).round
      else
        0
      end
    end

    #===========================================================================
    # Wind coils around the target
    #===========================================================================
    q = (t - 0.47) / 0.48
    p = a.clamp(q)
    active = q >= 0 && q <= 1
    strength = active ? Math.sin(p*Math::PI) : 0

    g[:arcs].each_with_index do |s, i|
      angle = i*Math::PI*2/3 + p*Math::PI*2.2 + phase
      radius = 5 + p*17

      s.x = cx + Math.cos(angle)*radius
      s.y = cy + Math.sin(angle)*radius*0.65
      s.angle = -angle*180/Math::PI

      s.zoom_x = 0.48 + p*0.52
      s.zoom_y = s.zoom_x*0.75
      s.opacity = (strength*(215-i*25)).round
    end

    #===========================================================================
    # Expanding pressure ring
    #===========================================================================
    halo = g[:halo]
    halo.x, halo.y = cx, cy
    halo.zoom_x = 0.25 + p*1.20
    halo.zoom_y = halo.zoom_x*0.65
    halo.angle = g[:angle]
    halo.opacity = (strength*(1-p)*190).round

    #===========================================================================
    # Spiraling energy fragments
    #===========================================================================
    g[:particles].each_with_index do |s, i|
      angle = i*2.399 + p*2.8 + phase
      radius = 10 + p*(28+i%5*11)

      s.x = cx + Math.cos(angle)*radius + dx*0.025*p
      s.y = cy + Math.sin(angle)*radius*0.65 - p*12
      s.angle = -angle*180/Math::PI + 35
      s.zoom_x = s.zoom_y = 0.20 + i%4*0.09
      s.opacity = (strength*(1-p*0.4)*225).round
    end
  end
end