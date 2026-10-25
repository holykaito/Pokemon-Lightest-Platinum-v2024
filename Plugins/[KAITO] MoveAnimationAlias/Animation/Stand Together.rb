#===============================================================================
# Stand Together - Pokemon Essentials v21.1
# Requires: KaitoAnimation Core v1.0
# Move ID: STANDTOGETHER
# Visuals only. Stat changes are handled by the move.
#===============================================================================
KaitoAnimation.register(
  :STANDTOGETHER,
  duration: 2.10,
  require_target: false,
  setup: proc do |a|
    a.sound_at(
      0.08,
      ["PRSFX- Iron Defense", "PRSFX- Reflect"],
      65, 105
    )
    a.sound_at(
      0.70,
      ["PRSFX- Helping Hand", "PRSFX- Bulk Up1"],
      70, 110
    )

    #===========================================================================
    # Protective shield
    #===========================================================================
    shield = a.bitmap(112, 132) do |b|
      a.polygon(
        b,
        [[56,4], [103,22], [98,77], [80,106],
         [56,127], [32,106], [14,77], [9,22]],
        Color.new(66, 166, 240, 175)
      )
      a.polygon(
        b,
        [[56,11], [95,28], [90,75], [74,101],
         [56,117], [38,101], [22,75], [17,28]],
        Color.new(206, 247, 255, 240)
      )
      a.polygon(
        b,
        [[56,17], [88,32], [83,73], [69,96],
         [56,108], [43,96], [29,73], [24,32]],
        Color.new(39, 113, 202, 125)
      )

      # Two upward emblems.
      a.polygon(
        b,
        [[56,32], [76,50], [70,58],
         [56,46], [42,58], [36,50]],
        Color.new(255, 222, 127, 245)
      )
      a.polygon(
        b,
        [[56,56], [76,74], [70,82],
         [56,70], [42,82], [36,74]],
        Color.new(255, 245, 208, 245)
      )
    end

    #===========================================================================
    # Ally strength emblem
    #===========================================================================
    arrow = a.bitmap(40, 28) do |b|
      a.polygon(
        b,
        [[20,2], [38,18], [31,25],
         [20,15], [9,25], [2,18]],
        Color.new(255, 207, 104, 240)
      )
      a.polygon(
        b,
        [[20,5], [33,18], [30,20],
         [20,11], [10,20], [7,18]],
        Color.new(255, 250, 223, 255)
      )
    end

    mote = a.bitmap(12, 12) do |b|
      a.polygon(
        b,
        [[6,0], [8,4], [11,6], [8,8],
         [6,11], [4,8], [0,6], [4,4]],
        Color.new(255, 232, 156, 245)
      )
    end

    blue_ring = a.ring(
      62, Color.new(131, 223, 255, 220), 3
    )
    gold_ring = a.ring(
      54, Color.new(255, 222, 142, 220), 3
    )

    a[:center] = a.center
    a[:shield] = a.sprite(shield, z: 20_025)
    a[:rings] = Array.new(2) do
      a.sprite(blue_ring, z: 20_022)
    end
    a[:motes] = Array.new(20) do
      a.sprite(mote, z: 20_028)
    end

    # Only active, visible allies receive visual effects.
    allies = a.user.allAllies.select do |b|
      s = a.battler_sprite(b)

      s && s.visible && s.opacity > 0 &&
        !(b.respond_to?(:isCommander?) && b.isCommander?) &&
        !(s.respond_to?(:vanishMode) && s.vanishMode > 0)
    end

    a[:allies] = allies.map do |b|
      {
        center: a.center(b),
        ring: a.sprite(gold_ring, z: 20_023),
        arrows: Array.new(3) do
          a.sprite(arrow, z: 20_027)
        end,
        links: Array.new(16) do
          a.sprite(mote, z: 20_024)
        end
      }
    end
  end
) do |a, t|
  ux, uy = a[:center]

  #=============================================================================
  # User's shield
  #=============================================================================
  appear = a.clamp(t / 0.20)
  fade = a.clamp((1-t) / 0.22)
  envelope = appear * fade

  shield = a[:shield]
  shield.x = ux
  shield.y = uy + 12 - appear * 12
  shield.zoom_x = shield.zoom_y = 0.80 + appear * 0.20
  shield.opacity = (
    envelope * (210 + Math.sin(t*Math::PI*4) * 15)
  ).round

  a[:rings].each_with_index do |s, i|
    q = (t - 0.06 - i*0.17) / 0.54
    p = a.clamp(q)

    s.x, s.y = ux, uy
    s.zoom_x = 0.35 + p*1.05
    s.zoom_y = s.zoom_x * 0.65

    s.opacity = if q >= 0 && q <= 1
      (Math.sin(p*Math::PI) * 185).round
    else
      0
    end
  end

  # Rising sparks around the user.
  a[:motes].each_with_index do |s, i|
    q = (t - 0.05 - i%5*0.035) / 0.72
    p = a.clamp(q)
    angle = i*2.399 + p*1.5
    radius = 26 + i%4*9

    s.x = ux + Math.cos(angle) * radius
    s.y = uy + 42 - p*100 + Math.sin(angle) * 12
    s.zoom_x = s.zoom_y = 0.30 + i%3*0.12
    s.angle = i*27 + p*80

    s.opacity = if q >= 0 && q <= 1
      (Math.sin(p*Math::PI) * 220).round
    else
      0
    end
  end

  #=============================================================================
  # Energy links and ally strength
  #=============================================================================
  a[:allies].each do |g|
    cx, cy = g[:center]

    # Curved streams from the user to each ally.
    g[:links].each_with_index do |s, i|
      q = (t - 0.20 - i*0.012) / 0.30
      p = a.clamp(q)

      s.x = a.lerp(ux, cx, p)
      s.y = a.lerp(uy, cy, p) - Math.sin(p*Math::PI) * 32
      s.zoom_x = s.zoom_y = 0.30 + i%3*0.10

      s.opacity = if q >= 0 && q <= 1
        (Math.sin(p*Math::PI) * 225).round
      else
        0
      end
    end

    # Golden pulse around the ally.
    q = (t - 0.48) / 0.41
    p = a.clamp(q)

    ring = g[:ring]
    ring.x, ring.y = cx, cy+12
    ring.zoom_x = 0.35 + p*1.2
    ring.zoom_y = ring.zoom_x * 0.55

    ring.opacity = if q >= 0 && q <= 1
      (Math.sin(p*Math::PI) * 205).round
    else
      0
    end

    # Decorative upward arrows; no additional stat changes.
    g[:arrows].each_with_index do |s, i|
      q = (t - 0.45 - i*0.075) / 0.32
      p = a.clamp(q)

      s.x = cx
      s.y = cy + 22 - p*70
      s.zoom_x = s.zoom_y = 0.72

      s.opacity = if q >= 0 && q <= 1
        (Math.sin(p*Math::PI) * 245).round
      else
        0
      end
    end
  end
end