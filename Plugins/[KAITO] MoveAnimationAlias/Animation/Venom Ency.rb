#===============================================================================
# Venom Envy - Pokemon Essentials v21.1
# Requires: KaitoAnimation Core v1.0
# Move ID: VENOMENVY
# Visuals only. Damage and poisoning are handled by the move.
#===============================================================================
KaitoAnimation.register(
  :VENOMENVY,
  duration: 1.90,
  setup: proc do |a|
    a.sound_at(0.06, "PRSFX- Acid Armor1", 55, 90)
    a.sound_at(0.48, "PRSFX- Poison Tail1", 70, 110)
    a.sound_at(0.82, "PRSFX- Poison Jab2", 80, 95)

    #===========================================================================
    # Toxic crescent blade
    #===========================================================================
    blade = a.bitmap(160, 144) do |b|
      [
        [17, [70, 23, 94, 240]],
        [11, [150, 221, 67, 250]],
        [4,  [239, 255, 195, 255]]
      ].each do |width, rgba|
        outer, inner = [], []

        65.times do |i|
          p = i / 64.0
          angle = -Math::PI*0.80 + p*Math::PI*1.60
          half = Math.sin(p*Math::PI)**0.65 * width

          outer << [
            80 + Math.cos(angle)*(53+half),
            72 + Math.sin(angle)*(53+half)
          ]
          inner << [
            80 + Math.cos(angle)*(53-half),
            72 + Math.sin(angle)*(53-half)
          ]
        end

        a.polygon(
          b, outer + inner.reverse, Color.new(*rgba)
        )
      end
    end

    #===========================================================================
    # Poison-energy impact
    #===========================================================================
    burst = a.bitmap(160, 160) do |b|
      points = Array.new(24) do |i|
        angle = i*Math::PI/12
        radius = i.even? ? 59+i%5*2 : 18

        [
          80 + Math.cos(angle)*radius,
          80 + Math.sin(angle)*radius
        ]
      end

      [
        [1.00, [100, 37, 137, 230]],
        [0.68, [165, 229, 80, 245]],
        [0.30, [248, 255, 214, 255]]
      ].each do |scale, rgba|
        scaled = points.map do |x, y|
          [80+(x-80)*scale, 80+(y-80)*scale]
        end

        a.polygon(b, scaled, Color.new(*rgba))
      end
    end

    spark = a.bitmap(20, 28) do |b|
      a.polygon(
        b,
        [[10,0], [13,10], [19,14], [13,17],
         [10,27], [7,17], [0,14], [7,10]],
        Color.new(177, 239, 89, 250)
      )
      a.polygon(
        b,
        [[10,7], [12,14], [10,21], [8,14]],
        Color.new(250, 255, 220, 255)
      )
    end

    mist = a.bitmap(64, 64) do |b|
      (0...64).step(2) do |y|
        (0...64).step(2) do |x|
          r = ((x-31.0)/31.0)**2 +
              ((y-31.0)/31.0)**2
          next if r >= 1

          b.fill_rect(
            x, y, 2, 2,
            Color.new(128, 35, 151, ((1-r)**1.4*155).round)
          )
        end
      end
    end

    ring = a.ring(
      58, Color.new(176, 229, 100, 225), 3
    )

    a[:source] = a.center
    a[:charge] = a.sprite(ring, z: 20_022)
    a[:charge_sparks] = Array.new(14) do
      a.sprite(spark, z: 20_024)
    end

    a[:groups] = a.targets.map do |target|
      cx, cy = a.center(target)
      ux, uy = a[:source]
      copy = a.copy(target, hide_original: true, z: 20_015)

      {
        center: [cx, cy],
        angle: -Math.atan2(cy-uy, cx-ux)*180/Math::PI,
        direction: cx >= ux ? 1 : -1,
        raised: target.stages.any? { |_stat, value| value > 0 },
        copy: copy,
        x: copy.x,
        y: copy.y,
        color: copy.color.clone,
        blade: a.sprite(blade, z: 20_028),
        echo: a.sprite(blade, z: 20_025),
        burst: a.sprite(burst, z: 20_032),
        ring: a.sprite(ring, z: 20_030),
        sparks: Array.new(28) do
          a.sprite(spark, z: 20_034)
        end,
        fumes: Array.new(10) do
          a.sprite(mist, z: 20_023)
        end
      }
    end
  end
) do |a, t|
  ux, uy = a[:source]

  #=============================================================================
  # Jealous energy gathers around the user
  #=============================================================================
  charge = a.clamp(t/0.18) *
           (1-a.clamp((t-0.22)/0.18))

  ring = a[:charge]
  ring.x, ring.y = ux, uy
  ring.zoom_x = ring.zoom_y = 1.0-a.clamp(t/0.24)*0.55
  ring.opacity = (charge*205).round

  a[:charge_sparks].each_with_index do |s, i|
    angle = i*2.399-t*3
    radius = 65*(1-a.clamp(t/0.33))+12

    s.x = ux + Math.cos(angle)*radius
    s.y = uy + Math.sin(angle)*radius*0.70
    s.angle = i*27+t*100
    s.zoom_x = s.zoom_y = 0.25+i%3*0.12
    s.opacity = (charge*220).round
  end

  a[:groups].each do |g|
    cx, cy = g[:center]

    #===========================================================================
    # Crescent rush and trailing afterimage
    #===========================================================================
    [g[:blade], g[:echo]].each_with_index do |s, i|
      q = (t-0.20-i*0.025)/0.25
      p = a.clamp(q)
      travel = 0.15+p*p*0.85

      s.x = a.lerp(ux, cx, travel)
      s.y = a.lerp(uy, cy, travel) -
            Math.sin(p*Math::PI)*14
      s.angle = g[:angle] + (1-p)*g[:direction]*35
      s.zoom_x = s.zoom_y = 0.50+p*0.35

      s.opacity = if q >= 0 && q <= 1
        (Math.sin(p*Math::PI)*(255-i*160)).round
      else
        0
      end
    end

    #===========================================================================
    # Impact and target reaction
    #===========================================================================
    q = (t-0.43)/0.34
    p = a.clamp(q)
    strength = q >= 0 && q <= 1 ? 1-p : 0

    burst = g[:burst]
    burst.x, burst.y = cx, cy
    burst.zoom_x = burst.zoom_y = 0.28+p*1.3
    burst.angle = g[:direction]*18
    burst.opacity = (strength**1.5*250).round

    ring = g[:ring]
    ring.x, ring.y = cx, cy
    ring.zoom_x = ring.zoom_y = 0.20+p*1.35
    ring.opacity = (strength*190).round

    knock = Math.sin(p*Math::PI)*8

    g[:copy].x = g[:x] + g[:direction]*knock +
                 Math.sin(t*130)*strength*3
    g[:copy].y = g[:y]-knock*0.20

    g[:copy].color = if strength > 0
      Color.new(190, 236, 111, (strength*100).round)
    else
      g[:color]
    end

    g[:sparks].each_with_index do |s, i|
      angle = i*2.399+p*0.5
      radius = 6+p*(30+i%5*13)

      s.x = cx + Math.cos(angle)*radius
      s.y = cy + Math.sin(angle)*radius*0.70 + p*p*22
      s.angle = i*31+p*150
      s.zoom_x = s.zoom_y = 0.22+i%4*0.10
      s.opacity = (strength**0.7*240).round
    end

    #===========================================================================
    # Extra toxic aura for targets with raised stat stages
    # This is visual emphasis, not a separate poisoning effect.
    #===========================================================================
    aura = if g[:raised]
      a.clamp((t-0.48)/0.12) * a.clamp((1-t)/0.20)
    else
      0
    end

    g[:fumes].each_with_index do |s, i|
      v = (t*1.3+i*0.117) % 1.0
      angle = i*2.399+t*2

      s.x = cx + Math.cos(angle)*(18+v*24)
      s.y = cy+35-v*(65+i%3*15)
      s.zoom_x = s.zoom_y = 0.45+v*0.70
      s.z = Math.sin(angle) < 0 ? 20_012 : 20_023
      s.opacity = (Math.sin(v*Math::PI)*aura*180).round
    end
  end
end