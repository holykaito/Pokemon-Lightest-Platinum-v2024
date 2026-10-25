#===============================================================================
# Severe Poison - Pokemon Essentials v21.1
# Requires: KaitoAnimation Core v1.0
# Move ID: SEVEREPOISON
# Visuals only. Poison mechanics remain handled by the move.
#===============================================================================
KaitoAnimation.register(
  :SEVEREPOISON,
  duration: 2.20,
  setup: proc do |a|
    a.sound_at(0.05, "PRSFX- Poison Gas", 65, 85)
    a.sound_at(0.67, "PRSFX- Acid", 75, 90)
    a.sound_at(1.16, "PRSFX- Poison", 75, 80)

    #===========================================================================
    # Purple and acid-green bubbles
    #===========================================================================
    bubbles = [
      [170, 65, 207],
      [178, 224, 88]
    ].map do |rgb|
      a.bitmap(32, 32) do |b|
        32.times do |y|
          32.times do |x|
            r = Math.sqrt((x-15.5)**2 + (y-15.5)**2)
            next if r > 14

            alpha = r > 11 ? 230 : 105
            b.fill_rect(x, y, 1, 1, Color.new(*rgb, alpha))
          end
        end

        b.fill_rect(
          8, 7, 5, 3, Color.new(255, 245, 255, 235)
        )
        b.fill_rect(
          7, 10, 3, 4, Color.new(255, 245, 255, 190)
        )
      end
    end

    #===========================================================================
    # Dense toxic fumes
    #===========================================================================
    mist = a.bitmap(72, 72) do |b|
      (0...72).step(2) do |y|
        (0...72).step(2) do |x|
          r = ((x-35.0)/35.0)**2 +
              ((y-35.0)/35.0)**2
          next if r >= 1

          b.fill_rect(
            x, y, 2, 2,
            Color.new(89, 24, 117, ((1-r)**1.3*165).round)
          )
        end
      end
    end

    #===========================================================================
    # Toxic pool with a bright purple edge
    #===========================================================================
    pool = a.bitmap(176, 64) do |b|
      64.times do |y|
        176.times do |x|
          r = ((x-87.5)/85.0)**2 +
              ((y-31.5)/29.0)**2
          next if r >= 1

          color = if r > 0.68
            Color.new(184, 67, 204, 190)
          else
            Color.new(66, 19, 83, ((1-r)*210).round)
          end

          b.fill_rect(x, y, 1, 1, color)
        end
      end
    end

    drop = a.bitmap(14, 24) do |b|
      a.polygon(
        b,
        [[7,0], [13,12], [11,21], [7,23], [2,20], [1,12]],
        Color.new(176, 222, 91, 245)
      )
      a.polygon(
        b,
        [[7,6], [9,13], [6,19], [4,15]],
        Color.new(242, 255, 198, 245)
      )
    end

    ring = a.ring(
      58, Color.new(221, 99, 227, 235), 4
    )

    a[:source] = a.center

    a[:groups] = a.targets.map do |target|
      s = a.battler_sprite(target)
      copy = a.copy(target, hide_original: true, z: 20_015)

      {
        center: a.center(target),
        ground: s.y + (s.src_rect.height-s.oy)*s.zoom_y,
        copy: copy,
        color: copy.color.clone,
        opacity: copy.opacity,
        pool: a.sprite(pool, z: 20_011),
        shots: Array.new(4) do |i|
          a.sprite(bubbles[i%2], z: 20_026)
        end,
        fumes: Array.new(16) do
          a.sprite(mist, z: 20_022)
        end,
        bubbles: Array.new(18) do |i|
          a.sprite(bubbles[i%2], z: 20_029)
        end,
        rings: Array.new(2) do
          a.sprite(ring, z: 20_027)
        end,
        drops: Array.new(24) do
          a.sprite(drop, z: 20_031)
        end
      }
    end
  end
) do |a, t|
  ux, uy = a[:source]

  env = a.clamp((t-0.26)/0.13) *
        a.clamp((1-t)/0.23)
  grow = a.clamp((t-0.26)/0.22)

  a[:groups].each do |g|
    cx, cy = g[:center]

    #===========================================================================
    # Poison globules arc toward the target
    #===========================================================================
    g[:shots].each_with_index do |s, i|
      q = (t-0.03-i*0.025)/0.28
      p = a.clamp(q)

      s.x = a.lerp(ux, cx, p) +
            Math.sin(p*Math::PI)*(i-1.5)*8
      s.y = a.lerp(uy, cy, p) -
            Math.sin(p*Math::PI)*(20+i*5)
      s.zoom_x = s.zoom_y = 0.50+i*0.08

      s.opacity = if q >= 0 && q <= 1
        (Math.sin(p*Math::PI)*245).round
      else
        0
      end
    end

    #===========================================================================
    # Pool spreads beneath the target
    #===========================================================================
    pool = g[:pool]
    pool.x, pool.y = cx, g[:ground]-3
    pool.zoom_x = 0.35+grow*0.75
    pool.zoom_y = 0.55+grow*0.35
    pool.opacity = (env*225).round

    #===========================================================================
    # Fumes wind around the Pokemon
    #===========================================================================
    g[:fumes].each_with_index do |s, i|
      p = (t*1.2+i*0.083) % 1.0
      angle = i*2.399+t*2

      s.x = cx + Math.cos(angle)*(18+p*28)
      s.y = g[:ground] - p*(65+i%4*16)
      s.zoom_x = s.zoom_y = 0.45+p*0.80

      # Alternate behind and in front of the target.
      s.z = Math.sin(angle) < 0 ? 20_012 : 20_022
      s.opacity = (Math.sin(p*Math::PI)*env*180).round
    end

    #===========================================================================
    # Rising bubbles
    #===========================================================================
    g[:bubbles].each_with_index do |s, i|
      p = (t*1.45+i*0.071) % 1.0

      s.x = cx + Math.sin(i*2.399+p*3)*(22+i%4*10)
      s.y = g[:ground]+4-p*(70+i%5*15)
      s.zoom_x = s.zoom_y = 0.22+i%4*0.11+p*0.12
      s.opacity = (Math.sin(p*Math::PI)*env*235).round
    end

    #===========================================================================
    # Two expanding toxic pulses
    #===========================================================================
    g[:rings].each_with_index do |s, i|
      q = (t-0.31-i*0.20)/0.30
      p = a.clamp(q)

      s.x, s.y = cx, cy
      s.zoom_x = s.zoom_y = 0.25+p*1.1
      s.angle = i*24

      s.opacity = if q >= 0 && q <= 1
        ((1-p)*230).round
      else
        0
      end
    end

    #===========================================================================
    # Toxic splashes
    #===========================================================================
    g[:drops].each_with_index do |s, i|
      q = (t-0.34-i%3*0.055)/0.44
      p = a.clamp(q)
      angle = i*2.399

      s.x = cx + Math.cos(angle)*(8+p*(28+i%4*13))
      s.y = cy + Math.sin(angle)*p*35 -
            Math.sin(p*Math::PI)*26 + p*p*35
      s.angle = i*31+p*125
      s.zoom_x = s.zoom_y = 0.25+i%4*0.10

      s.opacity = if q >= 0 && q <= 1
        ((1-p)**0.65*245).round
      else
        0
      end
    end

    # Temporary purple pulse; the original sprite is restored by the core.
    pulse = 0.72+Math.sin(t*Math::PI*6)*0.28

    g[:copy].color = if env > 0
      Color.new(126, 38, 155, (env*pulse*145).round)
    else
      g[:color]
    end

    g[:copy].opacity = (g[:opacity]*(1-env*0.12)).round
  end
end