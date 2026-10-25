#===============================================================================
# Astonish - Sudden Spectral Shout
# Pokemon Essentials v21.1 / KaitoAnimation Core v1.0
# Move ID: ASTONISH
# Visuals only. Damage and the 30% flinch chance belong to the move.
#===============================================================================
KaitoAnimation.register(
  :ASTONISH,
  duration: 1.10,
  setup: proc do |a|
    a.sound_at(0.04, "PRSFX- Astonish1", 60, 90)
    a.sound_at(0.25, "PRSFX- Astonish2", 85, 115)

    #===========================================================================
    # Stylized shouting ghost
    #===========================================================================
    ghost = a.bitmap(96, 112) do |b|
      outline = [
        [48,4], [67,9], [80,23], [83,45],
        [92,65], [78,61], [79,91], [66,103],
        [53,94], [45,108], [34,95], [20,103],
        [18,72], [4,78], [12,54], [12,30], [22,12]
      ]

      a.polygon(
        b, outline,
        Color.new(58, 24, 85, 240)
      )

      a.polygon(
        b,
        outline.map { |x, y| [48+(x-48)*0.86, 54+(y-54)*0.88] },
        Color.new(151, 91, 205, 250)
      )

      a.polygon(
        b,
        [[48,14], [64,19], [73,32], [73,49],
         [64,57], [48,51], [30,57], [22,44], [25,29]],
        Color.new(190, 144, 234, 245)
      )

      # Narrow eyes.
      a.polygon(
        b,
        [[25,36], [42,42], [37,48], [26,45]],
        Color.new(250, 239, 255, 255)
      )
      a.polygon(
        b,
        [[55,42], [72,35], [71,45], [60,49]],
        Color.new(250, 239, 255, 255)
      )

      # Open shouting mouth.
      a.polygon(
        b,
        [[43,57], [55,57], [59,68],
         [54,81], [44,78], [39,67]],
        Color.new(48, 18, 68, 255)
      )
      b.fill_rect(
        45, 58, 9, 3,
        Color.new(241, 219, 255, 245)
      )
    end

    #===========================================================================
    # Startled exclamation mark
    #===========================================================================
    mark = a.bitmap(22, 46) do |b|
      a.polygon(
        b,
        [[3,1], [20,1], [15,31], [6,31]],
        Color.new(92, 44, 122, 245)
      )
      a.polygon(
        b,
        [[7,4], [16,4], [12,27], [9,27]],
        Color.new(255, 246, 207, 255)
      )
      b.fill_rect(6, 35, 10, 9, Color.new(92, 44, 122, 245))
      b.fill_rect(9, 37, 5, 5, Color.new(255, 250, 224, 255))
    end

    mist = a.bitmap(56, 56) do |b|
      (0...56).step(2) do |y|
        (0...56).step(2) do |x|
          r = ((x-27.0)/27.0)**2 +
              ((y-27.0)/27.0)**2
          next if r >= 1

          b.fill_rect(
            x, y, 2, 2,
            Color.new(121, 69, 164, ((1-r)**1.4*155).round)
          )
        end
      end
    end

    spark = a.bitmap(10, 18) do |b|
      a.polygon(
        b,
        [[5,0], [9,6], [6,17], [1,11]],
        Color.new(212, 169, 247, 245)
      )
      b.fill_rect(
        4, 4, 2, 6,
        Color.new(255, 239, 255, 250)
      )
    end

    ring = a.ring(
      48, Color.new(226, 193, 255, 225), 3
    )

    a[:source] = a.center
    a[:actor] = a.copy(hide_original: true, z: 20_015)
    a[:actor_state] = [
      a[:actor].x,
      a[:actor].y,
      a[:actor].opacity,
      a[:actor].color.clone
    ]

    a[:groups] = a.targets.map do |target|
      src = a.battler_sprite(target)
      cx, cy = a.center(target)
      copy = a.copy(target, hide_original: true, z: 20_015)

      mark_y = [
        [cy-src.src_rect.height*src.zoom_y*0.40-15, 30].max,
        Graphics.height-30
      ].min

      {
        center: [cx, cy],
        direction: cx >= a[:source][0] ? 1 : -1,
        copy: copy,
        x: copy.x,
        y: copy.y,
        color: copy.color.clone,
        mark_y: mark_y,
        ghost: a.sprite(ghost, z: 20_029),
        ring: a.sprite(ring, z: 20_027),
        marks: Array.new(3) do
          a.sprite(mark, z: 20_033)
        end,
        smoke: Array.new(10) do
          a.sprite(mist, z: 20_030)
        end,
        sparks: Array.new(18) do
          a.sprite(spark, z: 20_032)
        end
      }
    end
  end
) do |a, _t|
  sec = a.seconds

  #=============================================================================
  # User briefly fades, then returns.
  # This does not alter the battler's actual hiding state.
  #=============================================================================
  ax, ay, opacity, color = a[:actor_state]

  vanish = a.clamp((sec-0.08)/0.12) *
           (1-a.clamp((sec-0.40)/0.20))

  actor = a[:actor]
  actor.x, actor.y = ax, ay
  actor.opacity = (opacity*(1-vanish*0.65)).round

  actor.color = if vanish > 0
    Color.new(86, 47, 123, (vanish*100).round)
  else
    color
  end

  a[:groups].each do |g|
    cx, cy = g[:center]
    direction = g[:direction]

    #===========================================================================
    # Ghost suddenly pops out beside the target
    #===========================================================================
    pop = a.clamp((sec-0.22)/0.06)
    fade = a.clamp((0.76-sec)/0.25)

    ghost = g[:ghost]
    ghost.x = cx-direction*(28-pop*12)
    ghost.y = cy-8-(1-pop)*12
    ghost.zoom_x = ghost.zoom_y = 0.15+pop*0.85
    ghost.angle = direction*(1-pop)*18
    ghost.opacity = (pop*fade*255).round

    #===========================================================================
    # Short shock ring and startled reaction
    #===========================================================================
    q = (sec-0.26)/0.25
    p = a.clamp(q)
    strength = q >= 0 && q <= 1 ? 1-p : 0

    ring = g[:ring]
    ring.x, ring.y = cx, cy
    ring.zoom_x = ring.zoom_y = 0.25+p*1.10
    ring.opacity = (strength*210).round

    hop = Math.sin(p*Math::PI)*5

    g[:copy].x = g[:x] +
                 Math.sin(sec*150)*strength*6
    g[:copy].y = g[:y]-hop

    g[:copy].color = if strength > 0
      Color.new(240, 218, 255, (strength*100).round)
    else
      g[:color]
    end

    g[:marks].each_with_index do |s, i|
      q = (sec-0.26-i*0.025)/0.29
      p = a.clamp(q)

      s.x = cx+(i-1)*23
      s.y = g[:mark_y]-Math.sin(p*Math::PI)*8
      s.angle = (1-i)*18
      s.zoom_x = s.zoom_y = i == 1 ? 0.82 : 0.62

      s.opacity = if q >= 0 && q <= 1
        (Math.sin(p*Math::PI)*255).round
      else
        0
      end
    end

    #===========================================================================
    # Ghost breaks apart into smoke
    #===========================================================================
    g[:smoke].each_with_index do |s, i|
      q = (sec-0.43-i%3*0.025)/0.48
      p = a.clamp(q)
      angle = i*2.399
      radius = 10+p*(22+i%4*8)

      s.x = cx-direction*16+Math.cos(angle)*radius
      s.y = cy-8+Math.sin(angle)*radius*0.70-p*20
      s.zoom_x = s.zoom_y = 0.30+p*0.95

      s.opacity = if q >= 0 && q <= 1
        (Math.sin(p*Math::PI)*170).round
      else
        0
      end
    end

    g[:sparks].each_with_index do |s, i|
      q = (sec-0.27)/0.43
      p = a.clamp(q)
      angle = i*2.399
      radius = 8+p*(24+i%5*10)

      s.x = cx+Math.cos(angle)*radius
      s.y = cy+Math.sin(angle)*radius*0.70-p*12
      s.angle = i*31+p*130
      s.zoom_x = s.zoom_y = 0.25+i%3*0.12

      s.opacity = if q >= 0 && q <= 1
        ((1-p)**0.7*225).round
      else
        0
      end
    end
  end
end