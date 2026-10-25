#===============================================================================
# Jagged Fangs - Pokemon Essentials v21.1
# Requires: KaitoAnimation Core v1.0
# Move ID: JAGGEDFANGS
# Visuals only. Damage and Attack increases belong to the move.
#===============================================================================
KaitoAnimation.register(
  :JAGGEDFANGS,
  duration: 1.50,
  setup: proc do |a|
    a.sound_at(0.10, "PRSFX- Rock Tomb", 55, 115)
    a.sound_at(0.49, "PRSFX- Crunch", 85, 85)
    a.sound_at(0.61, "PRSFX- Rock Slide", 65, 120)

    #===========================================================================
    # One jagged stone jaw, reused for upper and lower jaws
    #===========================================================================
    jaw = a.bitmap(160, 78) do |b|
      a.polygon(
        b,
        [[5,19], [19,6], [48,10], [79,2],
         [110,10], [141,6], [155,19], [146,29], [14,29]],
        Color.new(78, 66, 54, 255)
      )
      a.polygon(
        b,
        [[13,18], [23,11], [49,15], [79,8],
         [109,15], [137,11], [147,18], [141,23], [19,23]],
        Color.new(188, 171, 141, 255)
      )

      [
        [19, 45, 64],
        [47, 74, 70],
        [84, 112, 67],
        [118, 145, 61]
      ].each_with_index do |(left, right, tip_y), i|
        mid = (left+right)/2
        lean = i.even? ? -4 : 4

        a.polygon(
          b,
          [[left,21], [right,22], [right-4,39],
           [mid+lean,tip_y], [left+5,44]],
          Color.new(83, 72, 59, 255)
        )
        a.polygon(
          b,
          [[left+4,24], [right-4,25], [right-8,39],
           [mid+lean,tip_y-5], [left+8,42]],
          Color.new(205, 191, 161, 255)
        )
        a.polygon(
          b,
          [[left+5,25], [mid+2,25],
           [mid+lean,tip_y-9], [left+9,39]],
          Color.new(248, 233, 198, 255)
        )

        # A dark notch gives each fang a broken, rocky edge.
        a.polygon(
          b,
          [[right-4,35], [right-12,39], [right-7,43]],
          Color.new(98, 81, 62, 255)
        )
      end
    end

    #===========================================================================
    # Compact impact burst
    #===========================================================================
    burst = a.bitmap(112, 112) do |b|
      points = Array.new(24) do |i|
        angle = i*Math::PI/12
        radius = i.even? ? 47 : 13

        [
          56 + Math.cos(angle)*radius,
          56 + Math.sin(angle)*radius
        ]
      end

      [
        [1.00, [135, 105, 67, 215]],
        [0.64, [238, 207, 150, 245]],
        [0.28, [255, 250, 220, 255]]
      ].each do |scale, rgba|
        scaled = points.map do |x, y|
          [56+(x-56)*scale, 56+(y-56)*scale]
        end

        a.polygon(b, scaled, Color.new(*rgba))
      end
    end

    stone = a.bitmap(16, 22) do |b|
      a.polygon(
        b,
        [[6,0], [13,3], [15,12], [9,21], [2,17], [0,7]],
        Color.new(103, 85, 64, 255)
      )
      a.polygon(
        b,
        [[6,3], [11,5], [8,13], [2,9]],
        Color.new(218, 195, 151, 255)
      )
    end

    dust = a.bitmap(48, 48) do |b|
      (0...48).step(2) do |y|
        (0...48).step(2) do |x|
          r = ((x-23.0)/23.0)**2 +
              ((y-23.0)/23.0)**2
          next if r >= 1

          b.fill_rect(
            x, y, 2, 2,
            Color.new(183, 159, 121, ((1-r)**1.4*140).round)
          )
        end
      end
    end

    a[:groups] = a.targets.map do |target|
      src = a.battler_sprite(target)
      cx, cy = a.center(target)
      copy = a.copy(target, hide_original: true, z: 20_015)

      scale = [
        [(src.src_rect.height*src.zoom_y+110)/240.0, 0.90].max,
        1.15
      ].min

      jaws = Array.new(2) do
        s = a.sprite(jaw, z: 20_028)
        s.ox, s.oy = 80, 0
        s
      end

      {
        center: [cx, cy],
        scale: scale,
        copy: copy,
        x: copy.x,
        y: copy.y,
        color: copy.color.clone,
        jaws: jaws,
        burst: a.sprite(burst, z: 20_032),
        stones: Array.new(20) do
          a.sprite(stone, z: 20_034)
        end,
        dust: Array.new(10) do
          a.sprite(dust, z: 20_030)
        end
      }
    end
  end
) do |a, _t|
  sec = a.seconds

  appear = a.clamp(sec/0.16)
  close = a.clamp((sec-0.24)/0.25)
  reopen = a.clamp((sec-0.72)/0.35)
  fade = a.clamp((1.50-sec)/0.36)

  a[:groups].each do |g|
    cx, cy = g[:center]
    scale = g[:scale]
    gap = (1-close)*34 + reopen*8

    #===========================================================================
    # Stone jaws close around the target
    #===========================================================================
    upper, lower = g[:jaws]

    upper.x = cx-3*scale
    upper.y = cy-(64+gap)*scale
    upper.angle = 0

    lower.x = cx+3*scale
    lower.y = cy+(64+gap)*scale
    lower.angle = 180

    g[:jaws].each do |s|
      s.zoom_x = s.zoom_y = scale
      s.opacity = (appear*fade*255).round
    end

    #===========================================================================
    # Bite impact and brief target shake
    #===========================================================================
    q = (sec-0.49)/0.40
    p = a.clamp(q)
    strength = q >= 0 && q <= 1 ? (1-p)**1.2 : 0

    hit = g[:burst]
    hit.x, hit.y = cx, cy
    hit.zoom_x = scale*(0.25+p*1.0)
    hit.zoom_y = hit.zoom_x*0.72
    hit.angle = 15
    hit.opacity = (strength*245).round

    g[:copy].x = g[:x] + Math.sin(sec*135)*strength*6
    g[:copy].y = g[:y] + Math.cos(sec*117)*strength*3

    g[:copy].color = if strength > 0
      Color.new(255, 228, 174, (strength*105).round)
    else
      g[:color]
    end

    #===========================================================================
    # Sharp stone fragments scatter from the bite
    #===========================================================================
    g[:stones].each_with_index do |s, i|
      q = (sec-0.49-i%3*0.018)/0.65
      p = a.clamp(q)
      angle = i*2.399
      radius = 4+p*(26+i%5*11)

      s.x = cx + Math.cos(angle)*radius*scale
      s.y = cy + Math.sin(angle)*radius*0.65*scale +
            p*p*28
      s.angle = i*37+p*220
      s.zoom_x = s.zoom_y = scale*(0.25+i%4*0.11)

      s.opacity = if q >= 0 && q <= 1
        ((1-p)**0.65*245).round
      else
        0
      end
    end

    #===========================================================================
    # Dust puffs escape between the jaws
    #===========================================================================
    g[:dust].each_with_index do |s, i|
      q = (sec-0.50-i%3*0.025)/0.62
      p = a.clamp(q)
      side = i.even? ? 1 : -1

      s.x = cx + side*(8+p*(28+i%3*13))*scale
      s.y = cy + (i%3-1)*12-p*12
      s.zoom_x = 0.30+p*0.85
      s.zoom_y = s.zoom_x*0.75

      s.opacity = if q >= 0 && q <= 1
        (Math.sin(p*Math::PI)*155).round
      else
        0
      end
    end
  end
end