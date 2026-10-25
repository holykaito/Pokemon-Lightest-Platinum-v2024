#===============================================================================
# Neurotoxin - Pokemon Essentials v21.1
# Requires: KaitoAnimation Core v1.0
# Move ID: NEUROTOXIN
# Visuals only. Damage and Psychic move restriction belong to the move.
#===============================================================================
KaitoAnimation.register(
  :NEUROTOXIN,
  duration: 1.80,
  setup: proc do |a|
    a.sound_at(
      0.10,
      ["PRSFX- Poison Sting", "PRSFX- Pin Missile"],
      65, 115
    )
    a.sound_at(
      0.60,
      ["PRSFX- Poison Jab", "PRSFX- Poison Fang"],
      75, 105
    )
    a.sound_at(
      1.12,
      ["PRSFX- Disable", "PRSFX- Spite"],
      65, 90
    )

    #===========================================================================
    # Toxic needle
    #===========================================================================
    needle = a.bitmap(128, 28) do |b|
      a.polygon(
        b,
        [[2,14], [27,2], [114,10],
         [126,14], [114,18], [27,26]],
        Color.new(78, 30, 108, 225)
      )
      a.polygon(
        b,
        [[13,14], [32,7], [113,12],
         [126,14], [113,16], [32,21]],
        Color.new(175, 86, 221, 245)
      )
      a.polygon(
        b,
        [[29,14], [103,11], [126,14], [103,17]],
        Color.new(180, 244, 110, 255)
      )
      a.polygon(
        b,
        [[60,14], [111,13], [126,14], [111,15]],
        Color.new(251, 255, 226, 255)
      )
    end

    #===========================================================================
    # Neural network emblem
    #===========================================================================
    network = a.bitmap(96, 96) do |b|
      nodes = [
        [48,48], [48,15], [22,25], [74,25],
        [18,61], [78,61], [34,81], [62,81]
      ]

      [
        [0,1], [0,2], [0,3], [0,4], [0,5],
        [0,6], [0,7], [1,2], [1,3]
      ].each do |i, j|
        x1, y1 = nodes[i]
        x2, y2 = nodes[j]
        steps = [(x2-x1).abs, (y2-y1).abs, 1].max

        (0..steps).each do |n|
          p = n.to_f / steps
          x = (x1 + (x2-x1)*p).round
          y = (y1 + (y2-y1)*p).round

          b.fill_rect(
            x-1, y-1, 3, 3,
            Color.new(191, 132, 238, 220)
          )
        end
      end

      nodes.each_with_index do |(cx, cy), i|
        r = i == 0 ? 7 : 5

        (-r..r).each do |y|
          half = Math.sqrt(r*r-y*y).floor
          b.fill_rect(
            cx-half, cy+y, half*2+1, 1,
            Color.new(211, 167, 255, 245)
          )
        end

        b.fill_rect(
          cx-1, cy-1, 3, 3,
          Color.new(255, 245, 255, 255)
        )
      end
    end

    #===========================================================================
    # Suppression mark
    #===========================================================================
    cross = a.bitmap(80, 80) do |b|
      [
        [[10,3], [77,70], [70,77], [3,10]],
        [[70,3], [77,10], [10,77], [3,70]]
      ].each do |points|
        a.polygon(b, points, Color.new(62, 27, 78, 235))
      end

      a.polygon(
        b,
        [[10,7], [73,70], [70,73], [7,10]],
        Color.new(182, 238, 118, 250)
      )
      a.polygon(
        b,
        [[70,7], [73,10], [10,73], [7,70]],
        Color.new(182, 238, 118, 250)
      )
    end

    mote = a.bitmap(10, 16) do |b|
      a.polygon(
        b,
        [[5,0], [9,6], [6,15], [1,11]],
        Color.new(170, 222, 102, 240)
      )
      b.fill_rect(4, 5, 2, 4, Color.new(244, 255, 211, 255))
    end

    ring = a.ring(48, Color.new(186, 110, 227, 220), 3)
    a[:source] = a.center

    a[:groups] = a.targets.map do |target|
      cx, cy = a.center(target)
      ux, uy = a[:source]
      dx, dy = cx-ux, cy-uy
      s = a.battler_sprite(target)

      icon_y = [
        [cy-s.src_rect.height*s.zoom_y*0.18, 50].max,
        Graphics.height-50
      ].min

      {
        center: [cx, cy],
        delta: [dx, dy],
        angle: -Math.atan2(dy, dx)*180/Math::PI,
        icon_y: icon_y,
        needle: a.sprite(needle, z: 20_026),
        ring: a.sprite(ring, z: 20_028),
        network: a.sprite(network, z: 20_030),
        cross: a.sprite(cross, z: 20_032),
        motes: Array.new(24) do
          a.sprite(mote, z: 20_029)
        end
      }
    end
  end
) do |a, t|
  ux, uy = a[:source]

  a[:groups].each do |g|
    cx, cy = g[:center]
    dx, dy = g[:delta]

    #===========================================================================
    # Needle accelerates toward the target
    #===========================================================================
    q = (t-0.06) / 0.29
    p = a.clamp(q)
    travel = 0.20 + p*p*0.80

    needle = g[:needle]
    needle.x = ux + dx*travel
    needle.y = uy + dy*travel
    needle.angle = g[:angle]
    needle.zoom_x, needle.zoom_y = 0.72, 0.75

    needle.opacity = if q >= 0 && q <= 1
      (Math.sin(p*Math::PI)*255).round
    else
      0
    end

    #===========================================================================
    # Toxic impact
    #===========================================================================
    q = (t-0.33) / 0.30
    p = a.clamp(q)
    impact = q >= 0 && q <= 1 ? 1-p : 0

    ring = g[:ring]
    ring.x, ring.y = cx, cy
    ring.zoom_x = ring.zoom_y = 0.20 + p*1.05
    ring.opacity = (impact*215).round

    g[:motes].each_with_index do |s, i|
      angle = i*2.399
      radius = 5 + p*(24+i%5*9)

      s.x = cx + Math.cos(angle)*radius
      s.y = cy + Math.sin(angle)*radius*0.70 + p*p*14
      s.angle = i*29 + p*120
      s.zoom_x = s.zoom_y = 0.28 + i%3*0.10
      s.opacity = (impact**0.7*230).round
    end

    #===========================================================================
    # Neural network appears, flickers and becomes suppressed
    #===========================================================================
    appear = a.clamp((t-0.40) / 0.12)
    fade = a.clamp((0.94-t) / 0.15)
    suppress = a.clamp((t-0.62) / 0.24)

    network = g[:network]
    network.x, network.y = cx, g[:icon_y]-appear*5
    network.zoom_x = network.zoom_y = 0.72 + appear*0.12
    network.opacity = (
      appear * fade * (1-suppress*0.72) *
      (225 + Math.sin(t*65)*15)
    ).round

    cross = g[:cross]
    cross.x, cross.y = network.x, network.y
    cross.zoom_x = cross.zoom_y = 0.70 + suppress*0.16
    cross.opacity = (
      a.clamp((t-0.60)/0.10) * fade * 245
    ).round
  end
end