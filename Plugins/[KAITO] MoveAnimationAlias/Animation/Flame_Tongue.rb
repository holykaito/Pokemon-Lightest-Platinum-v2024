#===============================================================================
# Flame Tongue - Pokemon Essentials v21.1
# Requires: KaitoAnimation Core v1.0
# Move ID: FLAMETONGUE
# Visuals only. Damage and Burn chance belong to the move.
#===============================================================================
KaitoAnimation.register(
  :FLAMETONGUE,
  duration: 1.50,
  setup: proc do |a|
    a.sound_at(0.04, "PRSFX- Flame Charge1", 50, 110)
    a.sound_at(0.28, "PRSFX- Blaze Kick1", 70, 115)
    a.sound_at(0.53, "PRSFX- Fire Punch2", 85, 110)
    a.sound_at(0.80, "PRSFX- Flame Burst", 50, 120)

    #===========================================================================
    # Curved flaming blade
    #===========================================================================
    blade = a.bitmap(256, 160) do |b|
      [
        [20, [145, 32, 13, 225]],
        [14, [245, 73, 15, 245]],
        [8,  [255, 173, 37, 255]],
        [3,  [255, 248, 187, 255]]
      ].each do |width, rgba|
        upper, lower = [], []

        81.times do |i|
          p = i / 80.0
          x = 8+p*240
          y = 132-Math.sin(p*Math::PI)*94-p*36

          dx = 240.0
          dy = -Math.cos(p*Math::PI)*94*Math::PI-36
          length = Math.sqrt(dx*dx+dy*dy)
          nx, ny = -dy/length, dx/length
          half = Math.sin(p*Math::PI)**0.65*width

          upper << [x+nx*half, y+ny*half]
          lower << [x-nx*half, y-ny*half]
        end

        a.polygon(
          b, upper+lower.reverse, Color.new(*rgba)
        )
      end
    end

    #===========================================================================
    # Small tongues of flame
    #===========================================================================
    flame = a.bitmap(28, 48) do |b|
      a.polygon(
        b,
        [[13,1], [16,15], [24,8], [22,25],
         [27,31], [22,42], [14,47], [5,42],
         [1,31], [8,17], [7,30], [14,23]],
        Color.new(228, 51, 13, 240)
      )
      a.polygon(
        b,
        [[14,14], [17,28], [22,23], [22,35],
         [17,43], [10,43], [5,35], [10,27]],
        Color.new(255, 155, 23, 250)
      )
      a.polygon(
        b,
        [[14,27], [18,35], [15,42],
         [10,39], [10,34]],
        Color.new(255, 245, 165, 255)
      )
    end

    ember = a.bitmap(8, 12) do |b|
      a.polygon(
        b,
        [[4,0], [7,4], [5,11], [1,8]],
        Color.new(255, 177, 51, 250)
      )
      b.fill_rect(
        3, 3, 2, 4, Color.new(255, 250, 199, 255)
      )
    end

    burst = a.bitmap(112, 112) do |b|
      points = Array.new(24) do |i|
        angle = i*Math::PI/12
        radius = i.even? ? 48 : 13

        [
          56+Math.cos(angle)*radius,
          56+Math.sin(angle)*radius
        ]
      end

      [
        [1.00, [215, 57, 15, 220]],
        [0.68, [255, 169, 44, 250]],
        [0.30, [255, 250, 204, 255]]
      ].each do |scale, rgba|
        scaled = points.map do |x, y|
          [56+(x-56)*scale, 56+(y-56)*scale]
        end

        a.polygon(b, scaled, Color.new(*rgba))
      end
    end

    ring = a.ring(
      42, Color.new(255, 183, 74, 220), 3
    )

    a[:source] = a.center
    a[:actor] = a.copy(hide_original: true, z: 20_015)
    a[:actor_state] = [
      a[:actor].x,
      a[:actor].y,
      a[:actor].color.clone
    ]

    a[:charge] = Array.new(10) do
      a.sprite(ember, z: 20_023)
    end

    a[:groups] = a.targets.map do |target|
      cx, cy = a.center(target)
      copy = a.copy(target, hide_original: true, z: 20_015)
      direction = cx >= a[:source][0] ? 1 : -1

      {
        center: [cx, cy],
        direction: direction,
        angle: -direction*32,
        copy: copy,
        x: copy.x,
        y: copy.y,
        color: copy.color.clone,
        slash: a.sprite(blade, z: 20_029),
        echo: a.sprite(blade, z: 20_026),
        burst: a.sprite(burst, z: 20_033),
        ring: a.sprite(ring, z: 20_031),
        flames: Array.new(24) do
          a.sprite(flame, z: 20_032)
        end,
        embers: Array.new(26) do
          a.sprite(ember, z: 20_035)
        end
      }
    end

    average_x = a[:groups].sum do |g|
      g[:center][0]
    end / a[:groups].length.to_f

    a[:direction] = average_x >= a[:source][0] ? 1 : -1
  end
) do |a, _t|
  sec = a.seconds
  ux, uy = a[:source]

  #=============================================================================
  # Brief wind-up and physical lunge
  #=============================================================================
  charge = a.clamp(sec/0.15) *
           (1-a.clamp((sec-0.20)/0.15))

  lunge = a.clamp((sec-0.24)/0.25) *
          (1-a.clamp((sec-0.65)/0.30))

  ax, ay, color = a[:actor_state]
  actor = a[:actor]
  actor.x = ax+a[:direction]*(lunge*14-charge*4)
  actor.y = ay-Math.sin(lunge*Math::PI)*2

  actor.color = if charge > 0
    Color.new(255, 132, 41, (charge*75).round)
  else
    color
  end

  a[:charge].each_with_index do |s, i|
    angle = i*2.399+sec*3
    radius = 14+i%3*7

    s.x = ux+Math.cos(angle)*radius
    s.y = uy+Math.sin(angle)*radius*0.65-sec*12
    s.angle = i*29+sec*100
    s.zoom_x = s.zoom_y = 0.40+i%3*0.15
    s.opacity = (charge*220).round
  end

  a[:groups].each do |g|
    cx, cy = g[:center]
    direction = g[:direction]
    angle = g[:angle]

    #===========================================================================
    # One sweeping cut and its fading afterimage
    #===========================================================================
    [g[:slash], g[:echo]].each_with_index do |s, i|
      q = (sec-0.28-i*0.035)/0.37
      p = a.clamp(q)

      s.x = cx+direction*(p-0.50)*30
      s.y = cy+(p-0.50)*12
      s.angle = angle
      s.zoom_x = 0.85+p*0.18
      s.zoom_y = 0.90
      s.mirror = false

      s.opacity = if q >= 0 && q <= 1
        ((1-p)**0.45*(i == 0 ? 255 : 85)).round
      else
        0
      end
    end

    #===========================================================================
    # Flame fragments peel off the curved blade
    #===========================================================================
    radians = angle*Math::PI/180
    cosine = Math.cos(radians)
    sine = Math.sin(radians)

    g[:flames].each_with_index do |s, i|
      q = (sec-0.34-i*0.009)/0.52
      p = a.clamp(q)
      along = (i+0.5)/24.0

      local_x = 8+along*240-128
      local_y = 132-Math.sin(along*Math::PI)*94-
                along*36-80

      s.x = cx+local_x*cosine+local_y*sine+
            direction*p*(10+i%3*6)
      s.y = cy-local_x*sine+local_y*cosine-
            p*(25+i%4*10)
      s.angle = Math.sin(i*1.7+p*4)*15
      s.zoom_x = 0.24+i%4*0.07+p*0.15
      s.zoom_y = s.zoom_x*(1.0+p*0.45)

      s.opacity = if q >= 0 && q <= 1
        ((1-p)**0.7*235).round
      else
        0
      end
    end

    #===========================================================================
    # Impact and short target reaction
    #===========================================================================
    q = (sec-0.53)/0.34
    p = a.clamp(q)
    strength = q >= 0 && q <= 1 ? 1-p : 0

    hit = g[:burst]
    hit.x, hit.y = cx, cy
    hit.zoom_x = 0.30+p*1.05
    hit.zoom_y = hit.zoom_x*0.75
    hit.angle = angle
    hit.opacity = (strength**1.4*240).round

    ring = g[:ring]
    ring.x, ring.y = cx, cy
    ring.zoom_x = ring.zoom_y = 0.25+p*1.20
    ring.opacity = (strength*185).round

    knock = Math.sin(p*Math::PI)*9

    g[:copy].x = g[:x]+direction*knock+
                 Math.sin(sec*135)*strength*4
    g[:copy].y = g[:y]-knock*0.20

    g[:copy].color = if strength > 0
      Color.new(255, 181, 89, (strength*100).round)
    else
      g[:color]
    end

    #===========================================================================
    # Embers scatter and fall
    #===========================================================================
    g[:embers].each_with_index do |s, i|
      q = (sec-0.53-i%3*0.015)/0.75
      p = a.clamp(q)
      theta = i*2.399
      radius = 5+p*(22+i%5*12)

      s.x = cx+Math.cos(theta)*radius+direction*p*14
      s.y = cy+Math.sin(theta)*radius*0.65-
            Math.sin(p*Math::PI)*15+p*p*32
      s.angle = i*31+p*150
      s.zoom_x = s.zoom_y = 0.30+i%4*0.13

      s.opacity = if q >= 0 && q <= 1
        ((1-p)**0.8*245).round
      else
        0
      end
    end
  end
end