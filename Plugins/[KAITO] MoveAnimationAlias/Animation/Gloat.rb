#===============================================================================
# Gloat - Pokemon Essentials v21.1
# Requires: KaitoAnimation Core v1.0
# Move ID: GLOAT
# Visuals only. Conditions and stat changes are handled by the move.
#===============================================================================
KaitoAnimation.register(
  :GLOAT,
  duration: 1.95,
  require_target: false,
  setup: proc do |a|
    a.sound_at(
      0.07,
      ["PRSFX- Nasty Plot", "PRSFX- Taunt"],
      60, 105
    )
    a.sound_at(
      0.68,
      ["PRSFX- Cosmic Power", "PRSFX- Quiver Dance"],
      70, 115
    )

    #===========================================================================
    # Golden crown
    #===========================================================================
    crown = a.bitmap(104, 70) do |b|
      a.polygon(
        b,
        [[5,14], [29,30], [52,3], [75,30],
         [99,14], [87,59], [17,59]],
        Color.new(87, 43, 109, 210)
      )
      a.polygon(
        b,
        [[10,19], [30,36], [52,10], [74,36],
         [94,19], [83,54], [21,54]],
        Color.new(255, 205, 77, 250)
      )
      a.polygon(
        b,
        [[18,29], [32,41], [52,19], [72,41],
         [86,29], [79,49], [25,49]],
        Color.new(255, 243, 177, 245)
      )

      b.fill_rect(20, 54, 64, 7, Color.new(197, 123, 42, 250))
      b.fill_rect(23, 54, 58, 3, Color.new(255, 240, 171, 255))

      a.polygon(
        b,
        [[52,38], [58,45], [52,52], [46,45]],
        Color.new(168, 83, 218, 255)
      )
    end

    #===========================================================================
    # Sparkles
    #===========================================================================
    star = a.bitmap(24, 24) do |b|
      a.polygon(
        b,
        [[12,0], [15,9], [23,12], [15,15],
         [12,23], [9,15], [0,12], [9,9]],
        Color.new(255, 240, 180, 250)
      )
      b.fill_rect(10, 10, 4, 4, Color.new(255, 255, 245, 255))
    end

    # Five decorative gems representing the five main stats.
    colors = [
      [248, 116, 108],
      [255, 210, 100],
      [192, 133, 245],
      [117, 220, 247],
      [151, 236, 145]
    ]

    gems = colors.map do |rgb|
      a.bitmap(22, 30) do |b|
        a.polygon(
          b,
          [[11,1], [20,13], [11,28], [2,13]],
          Color.new(*rgb, 240)
        )
        a.polygon(
          b,
          [[11,5], [14,13], [11,22], [8,13]],
          Color.new(255, 255, 235, 250)
        )
      end
    end

    #===========================================================================
    # Soft dark aura
    #===========================================================================
    haze = a.bitmap(56, 56) do |b|
      56.times do |y|
        56.times do |x|
          r = ((x-27.5)**2 + (y-27.5)**2) / 756.25
          next if r >= 1

          b.fill_rect(
            x, y, 1, 1,
            Color.new(91, 39, 120, ((1-r)**2 * 110).round)
          )
        end
      end
    end

    ring = a.ring(60, Color.new(203, 148, 240, 215), 3)

    src = a.battler_sprite
    ux, uy = a.center
    top = src.y - src.oy * src.zoom_y

    a[:center] = [ux, uy]
    a[:crown_y] = [[top-18, 38].max, Graphics.height-38].min
    a[:radius] = [
      [src.src_rect.width * src.zoom_x * 0.35, 42].max,
      70
    ].min

    a[:crown] = a.sprite(crown, z: 20_030)
    a[:ring] = a.sprite(ring, z: 20_022)
    a[:haze] = Array.new(7) { a.sprite(haze, z: 20_020) }
    a[:gems] = gems.map { |b| a.sprite(b, z: 20_027) }
    a[:glints] = Array.new(8) { a.sprite(star, z: 20_032) }
  end
) do |a, t|
  ux, uy = a[:center]

  #=============================================================================
  # Crown appears and floats above the user
  #=============================================================================
  appear = a.clamp((t-0.08) / 0.18)
  fade = a.clamp((1-t) / 0.20)

  crown = a[:crown]
  crown.x = ux
  crown.y = a[:crown_y] + (1-appear)*15 -
            Math.sin(t*Math::PI)*4
  crown.zoom_x = crown.zoom_y = 0.70 + appear*0.30
  crown.angle = Math.sin(t*Math::PI*2)*5
  crown.opacity = (appear * fade * 255).round

  #=============================================================================
  # Purple aura
  #=============================================================================
  aura = Math.sin(t*Math::PI)

  a[:haze].each_with_index do |s, i|
    angle = i*2.399 + t*1.4

    s.x = ux + Math.cos(angle)*(22+t*22)
    s.y = uy + Math.sin(angle)*22 - t*12
    s.zoom_x = s.zoom_y = 0.70 + t*0.70
    s.opacity = (aura * 125).round
  end

  q = (t-0.10) / 0.70
  p = a.clamp(q)

  ring = a[:ring]
  ring.x, ring.y = ux, uy
  ring.zoom_x = 0.40 + p*1.15
  ring.zoom_y = ring.zoom_x*0.65
  ring.angle = -t*70

  ring.opacity = if q >= 0 && q <= 1
    (Math.sin(p*Math::PI)*175).round
  else
    0
  end

  #=============================================================================
  # Five gems spread outward and rise
  #=============================================================================
  a[:gems].each_with_index do |s, i|
    q = (t-0.28-i*0.035) / 0.52
    p = a.clamp(q)

    angle = -Math::PI/2 + i*Math::PI*2/5 + p*0.35
    radius = a[:radius]*(0.45+p*0.65)

    s.x = ux + Math.cos(angle)*radius
    s.y = uy + Math.sin(angle)*radius*0.75 - p*24
    s.zoom_x = s.zoom_y = 0.40 + Math.sin(p*Math::PI)*0.30
    s.angle = -Math.sin(p*Math::PI)*12

    s.opacity = if q >= 0 && q <= 1
      (Math.sin(p*Math::PI)*245).round
    else
      0
    end
  end

  #=============================================================================
  # Successive glints around the crown
  #=============================================================================
  a[:glints].each_with_index do |s, i|
    q = (t-0.20-i*0.065) / 0.20
    p = a.clamp(q)
    angle = i*2.399

    s.x = ux + Math.cos(angle)*(35+i%3*13)
    s.y = a[:crown_y] + Math.sin(angle)*24 - p*9
    s.zoom_x = s.zoom_y = 0.30 + Math.sin(p*Math::PI)*0.50
    s.angle = p*55

    s.opacity = if q >= 0 && q <= 1
      (Math.sin(p*Math::PI)*250).round
    else
      0
    end
  end
end