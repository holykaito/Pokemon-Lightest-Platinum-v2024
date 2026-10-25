#===============================================================================
# Flicked Pebble - Pokemon Essentials v21.1
# Requires: KaitoAnimation Core v1.0
# Move ID: FLICKEDPEBBLE
# Visuals only. Flinching and Accuracy changes belong to the move.
#===============================================================================
KaitoAnimation.register(
  :FLICKEDPEBBLE,
  duration: 0.90,
  setup: proc do |a|
    a.sound_at(0.09, "PRSFX- Rock Throw1", 50, 135)
    a.sound_at(0.32, "PRSFX- Rock Throw2", 60, 130)
    a.sound_at(0.58, "PRSFX- Focus Energy", 40, 125)

    # Small, angular pebble.
    pebble = a.bitmap(16, 18) do |b|
      a.polygon(
        b,
        [[5,1], [12,2], [15,8], [11,16], [4,17], [1,10]],
        Color.new(102, 81, 60, 255)
      )
      a.polygon(
        b,
        [[5,3], [11,4], [9,10], [3,9]],
        Color.new(205, 179, 137, 255)
      )
      a.polygon(
        b,
        [[9,10], [13,8], [10,14], [5,15]],
        Color.new(151, 122, 86, 255)
      )
      b.fill_rect(5, 4, 3, 2, Color.new(242, 222, 181, 255))
    end

    trail = a.bitmap(32, 6) do |b|
      a.polygon(
        b,
        [[0,3], [26,1], [31,3], [26,5]],
        Color.new(235, 210, 158, 210)
      )
    end

    impact = a.bitmap(48, 48) do |b|
      points = Array.new(16) do |i|
        angle = i*Math::PI/8
        radius = i.even? ? 21 : 7

        [
          24 + Math.cos(angle)*radius,
          24 + Math.sin(angle)*radius
        ]
      end

      a.polygon(b, points, Color.new(221, 176, 102, 230))
      a.polygon(
        b,
        points.map { |x, y| [24+(x-24)*0.48, 24+(y-24)*0.48] },
        Color.new(255, 247, 214, 255)
      )
    end

    chip = a.bitmap(6, 8) do |b|
      a.polygon(
        b,
        [[2,0], [5,2], [4,7], [0,5]],
        Color.new(187, 153, 105, 245)
      )
    end

    focus = a.ring(
      24, Color.new(255, 234, 166, 230), 2
    )

    a[:source] = a.center
    a[:focus] = a.sprite(focus, z: 20_025)

    a[:groups] = a.targets.map do |target|
      cx, cy = a.center(target)
      ux, uy = a[:source]
      dx, dy = cx-ux, cy-uy

      copy = a.copy(target, hide_original: true, z: 20_015)

      {
        center: [cx, cy],
        start: [ux+dx*0.12, uy+dy*0.12],
        angle: -Math.atan2(dy, dx)*180/Math::PI,
        direction: dx >= 0 ? 1 : -1,
        copy: copy,
        x: copy.x,
        y: copy.y,
        color: copy.color.clone,
        pebble: a.sprite(pebble, z: 20_028),
        trails: Array.new(3) do
          a.sprite(trail, z: 20_026)
        end,
        impact: a.sprite(impact, z: 20_031),
        chips: Array.new(10) do
          a.sprite(chip, z: 20_033)
        end
      }
    end
  end
) do |a, _t|
  sec = a.seconds
  ux, uy = a[:source]

  a[:groups].each do |g|
    cx, cy = g[:center]
    sx, sy = g[:start]

    #===========================================================================
    # A single fast pebble with a short trail
    #===========================================================================
    q = (sec-0.10)/0.22
    p = a.clamp(q)

    pebble = g[:pebble]
    pebble.x = a.lerp(sx, cx, p)
    pebble.y = a.lerp(sy, cy, p) -
               Math.sin(p*Math::PI)*5
    pebble.angle = g[:direction]*p*300
    pebble.zoom_x = pebble.zoom_y = 0.80
    pebble.opacity = q >= 0 && q < 1 ? 255 : 0

    g[:trails].each_with_index do |s, i|
      delayed = a.clamp(p-(i+1)*0.09)

      s.x = a.lerp(sx, cx, delayed)
      s.y = a.lerp(sy, cy, delayed) -
            Math.sin(delayed*Math::PI)*5
      s.angle = g[:angle]
      s.zoom_x = 0.90-i*0.18
      s.zoom_y = 0.55
      s.opacity = q >= 0 && q < 1 ? 140-i*35 : 0
    end

    #===========================================================================
    # Small, sharp impact
    #===========================================================================
    q = (sec-0.32)/0.24
    p = a.clamp(q)
    strength = q >= 0 && q <= 1 ? 1-p : 0

    hit = g[:impact]
    hit.x, hit.y = cx, cy
    hit.zoom_x = hit.zoom_y = 0.35+p*0.65
    hit.angle = g[:direction]*15
    hit.opacity = (strength**1.5*245).round

    flinch = Math.sin(p*Math::PI)*4

    g[:copy].x = g[:x] + g[:direction]*flinch +
                 Math.sin(sec*120)*strength*2
    g[:copy].y = g[:y]-flinch*0.20

    g[:copy].color = if strength > 0
      Color.new(255, 238, 194, (strength*65).round)
    else
      g[:color]
    end

    g[:chips].each_with_index do |s, i|
      angle = i*2.399
      radius = 3+p*(12+i%4*7)

      s.x = cx + Math.cos(angle)*radius
      s.y = cy + Math.sin(angle)*radius*0.65 + p*p*12
      s.angle = i*31+p*150
      s.zoom_x = s.zoom_y = 0.35+i%3*0.15
      s.opacity = (strength*220).round
    end
  end

  #=============================================================================
  # Brief focus cue around the user
  #=============================================================================
  q = (sec-0.54)/0.28
  p = a.clamp(q)

  focus = a[:focus]
  focus.x, focus.y = ux, uy
  focus.zoom_x = focus.zoom_y = 1.30-p*0.50

  focus.opacity = if q >= 0 && q <= 1
    (Math.sin(p*Math::PI)*210).round
  else
    0
  end
end