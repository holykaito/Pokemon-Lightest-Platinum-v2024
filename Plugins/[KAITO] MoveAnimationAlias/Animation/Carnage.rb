#===============================================================================
# Carnage v2 - Heavy Dragon Assault
# Pokemon Essentials v21.1 / KaitoAnimation Core v1.0
# Move ID: CARNAGE
# Visuals only. Damage, hit count and recoil are handled by the move.
#===============================================================================
KaitoAnimation.register(
  :CARNAGE,
  duration: 2.50,
  setup: proc do |a|
    a.sound_at(
      0.05,
      ["PRSFX- Dragon Dance", "PRSFX- Bulk Up1"],
      75, 75
    )
    a.sound_at(
      0.80,
      ["PRSFX- Dragon Claw", "PRSFX- Night Slash1"],
      85, 85
    )
    a.sound_at(
      1.25,
      ["PRSFX- Dragon Rush2", "PRSFX- Giga Impact2"],
      95, 75
    )

    #===========================================================================
    # Wide dragon-energy sweep
    #===========================================================================
    sweep = a.bitmap(288, 176) do |b|
      [
        [24, [64, 25, 101, 235]],
        [16, [181, 74, 227, 250]],
        [9,  [91, 227, 241, 250]],
        [3,  [248, 255, 237, 255]]
      ].each do |width, rgba|
        left, right = [], []

        81.times do |i|
          p = i / 80.0
          x = 12 + p*264
          y = 141 - Math.sin(p*Math::PI)*94 - p*38

          dx = 264.0
          dy = -Math.cos(p*Math::PI)*94*Math::PI - 38
          length = Math.sqrt(dx*dx + dy*dy)
          nx, ny = -dy/length, dx/length
          half = Math.sin(p*Math::PI)**0.65 * width

          left << [x+nx*half, y+ny*half]
          right << [x-nx*half, y-ny*half]
        end

        a.polygon(
          b, left + right.reverse, Color.new(*rgba)
        )
      end
    end

    #===========================================================================
    # Large finishing claws
    #===========================================================================
    claw = a.bitmap(192, 240) do |b|
      3.times do |i|
        x = 32 + i*61

        a.polygon(
          b,
          [[x+21,5], [x+37,51], [x+14,184],
           [x-24,233], [x-5,154]],
          Color.new(77, 26, 113, 245)
        )
        a.polygon(
          b,
          [[x+21,11], [x+29,55], [x+7,181],
           [x-20,228], [x+2,145]],
          Color.new(195, 83, 232, 250)
        )
        a.polygon(
          b,
          [[x+20,21], [x+23,63], [x+1,183],
           [x-18,225], [x+9,112]],
          Color.new(102, 235, 246, 255)
        )
        a.polygon(
          b,
          [[x+19,36], [x+17,79], [x-4,186],
           [x-16,221], [x+10,113]],
          Color.new(250, 255, 239, 255)
        )
      end
    end

    #===========================================================================
    # Impact burst
    #===========================================================================
    burst = a.bitmap(224, 224) do |b|
      points = Array.new(32) do |i|
        angle = i*Math::PI/16
        radius = i.even? ? 91+i%4*3 : 24

        [
          112 + Math.cos(angle)*radius,
          112 + Math.sin(angle)*radius
        ]
      end

      [
        [1.00, [84, 34, 132, 235]],
        [0.74, [115, 225, 247, 250]],
        [0.36, [255, 249, 211, 255]]
      ].each do |scale, rgba|
        scaled = points.map do |x, y|
          [112+(x-112)*scale, 112+(y-112)*scale]
        end

        a.polygon(b, scaled, Color.new(*rgba))
      end
    end

    shard = a.bitmap(18, 32) do |b|
      a.polygon(
        b,
        [[9,0], [17,10], [11,27], [3,31], [1,15]],
        Color.new(153, 85, 210, 245)
      )
      a.polygon(
        b,
        [[9,3], [13,11], [6,25], [5,16]],
        Color.new(116, 241, 246, 255)
      )
      a.polygon(
        b,
        [[9,5], [10,12], [6,21]],
        Color.new(255, 255, 235, 255)
      )
    end

    ring = a.ring(
      78, Color.new(156, 235, 255, 235), 4
    )

    veil = a.bitmap(Graphics.width, Graphics.height) do |b|
      b.fill_rect(
        0, 0, Graphics.width, Graphics.height,
        Color.new(31, 16, 46, 255)
      )
    end

    flash = a.bitmap(Graphics.width, Graphics.height) do |b|
      b.fill_rect(
        0, 0, Graphics.width, Graphics.height,
        Color.new(224, 250, 255, 255)
      )
    end

    a[:veil] = a.sprite(veil, z: 20_000, centered: false)
    a[:flash] = a.sprite(flash, z: 20_050, centered: false)
    a[:center] = a.center

    # Preserve the user's original sprite scale.
    a[:actor] = a.copy(hide_original: true, z: 20_016)
    a[:actor_state] = [
      a[:actor].x,
      a[:actor].y,
      a[:actor].color.clone
    ]

    a[:charge] = a.sprite(ring, z: 20_021)
    a[:motes] = Array.new(24) do
      a.sprite(shard, z: 20_023)
    end

    # All targets supplied by the move, including allies.
    a[:groups] = a.targets.map do |target|
      src = a.battler_sprite(target)
      cx, cy = a.center(target)
      copy = a.copy(target, hide_original: true, z: 20_013)

      {
        center: [cx, cy],
        copy: copy,
        x: copy.x,
        y: copy.y,
        color: copy.color.clone,
        ground: src.y + (src.src_rect.height-src.oy)*src.zoom_y,
        sweeps: Array.new(2) do
          a.sprite(sweep, z: 20_028)
        end,
        claw: a.sprite(claw, z: 20_033),
        burst: a.sprite(burst, z: 20_035),
        rings: Array.new(3) do
          a.sprite(ring, z: 20_030)
        end,
        shards: Array.new(44) do
          a.sprite(shard, z: 20_038)
        end
      }
    end

    average = a[:groups].sum do |g|
      g[:center][0]
    end / a[:groups].length.to_f

    a[:direction] = average >= a[:center][0] ? 1 : -1
  end
) do |a, real_t|
  # Short impact hold; the battle scene continues updating.
  t = if real_t < 0.50
    real_t
  elsif real_t < 0.54
    0.50
  else
    0.50 + (real_t-0.54)*0.50/0.46
  end

  ux, uy = a[:center]

  env = a.clamp(real_t/0.14) *
        a.clamp((1-real_t)/0.20)
  a[:veil].opacity = (env*95).round

  a[:flash].opacity = if real_t >= 0.50 && real_t < 0.57
    ((1-(real_t-0.50)/0.07)*65).round
  else
    0
  end

  #=============================================================================
  # Gather energy and lunge
  #=============================================================================
  charge = a.clamp(t/0.28) *
           (1-a.clamp((t-0.28)/0.15))

  actor = a[:actor]
  ax, ay, color = a[:actor_state]

  lunge = a.clamp((t-0.25)/0.25) *
          (1-a.clamp((t-0.65)/0.25))

  actor.x = ax + a[:direction]*(lunge*18-charge*5)
  actor.y = ay - Math.sin(lunge*Math::PI)*3

  actor.color = if charge > 0
    Color.new(170, 98, 230, (charge*135).round)
  else
    color
  end

  ring = a[:charge]
  ring.x, ring.y = ux, uy
  ring.zoom_x = ring.zoom_y = 1.20-a.clamp(t/0.28)*0.70
  ring.angle = t*180
  ring.opacity = (charge*220).round

  a[:motes].each_with_index do |s, i|
    p = (t*2.2+i/24.0) % 1.0
    angle = i*2.399-t*2
    radius = 15+(1-p)*85

    s.x = ux + Math.cos(angle)*radius
    s.y = uy + Math.sin(angle)*radius*0.70
    s.angle = i*31+t*180
    s.zoom_x = s.zoom_y = 0.22+i%3*0.09
    s.opacity = (Math.sin(p*Math::PI)*charge*235).round
  end

  a[:groups].each do |g|
    cx, cy = g[:center]
    direction = cx >= ux ? 1 : -1

    #===========================================================================
    # Two broad crossing sweeps
    #===========================================================================
    g[:sweeps].each_with_index do |s, i|
      q = (t-0.30-i*0.075) / 0.24
      p = a.clamp(q)

      s.x = cx + direction*(p-0.45)*42
      s.y = cy + (i == 0 ? -9 : 12)
      s.angle = i == 0 ? -direction*28 : direction*32
      s.mirror = direction < 0
      s.zoom_x = 0.88+p*0.30
      s.zoom_y = i == 0 ? 1.0 : 0.86

      s.opacity = if q >= 0 && q <= 1
        ((1-p)**0.55*255).round
      else
        0
      end
    end

    #===========================================================================
    # Finishing claw strike
    #===========================================================================
    q = (t-0.48) / 0.24
    p = a.clamp(q)

    claw = g[:claw]
    claw.x, claw.y = cx, cy+(p-0.40)*24
    claw.angle = -direction*14
    claw.zoom_x = 0.90+p*0.15
    claw.zoom_y = 0.95+p*0.15

    claw.opacity = if q >= 0 && q <= 1
      ((1-p)**0.55*255).round
    else
      0
    end

    #===========================================================================
    # Heavy impact and knockback
    #===========================================================================
    q = (t-0.50) / 0.35
    p = a.clamp(q)
    strength = q >= 0 && q <= 1 ? (1-p)**1.2 : 0

    burst = g[:burst]
    burst.x, burst.y = cx, cy
    burst.zoom_x = 0.32+p*1.65
    burst.zoom_y = burst.zoom_x*0.85
    burst.angle = direction*12
    burst.opacity = (strength*245).round

    knock = Math.sin(p*Math::PI)*17

    g[:copy].x = g[:x] + direction*knock +
                 Math.sin(t*165)*strength*10
    g[:copy].y = g[:y] - knock*0.30 +
                 Math.cos(t*145)*strength*3

    g[:copy].color = if strength > 0
      Color.new(219, 251, 255, (strength*135).round)
    else
      g[:color]
    end

    #===========================================================================
    # Expanding pressure waves
    #===========================================================================
    g[:rings].each_with_index do |s, i|
      v = (t-0.50-i*0.055) / 0.27
      r = a.clamp(v)

      s.x = cx
      s.y = i == 0 ? cy : g[:ground]-4
      s.zoom_x = 0.25+r*2.0
      s.zoom_y = s.zoom_x*(i == 0 ? 0.8 : 0.28)

      s.opacity = if v >= 0 && v <= 1
        ((1-r)*225).round
      else
        0
      end
    end

    #===========================================================================
    # Exploding dragon-energy shards
    #===========================================================================
    g[:shards].each_with_index do |s, i|
      v = (t-0.50-i%4*0.010) / 0.41
      r = a.clamp(v)
      angle = i*2.399
      radius = 8+r*(55+i%6*20)

      s.x = cx + Math.cos(angle)*radius + direction*r*18
      s.y = cy + Math.sin(angle)*radius*0.73 + r*r*35
      s.angle = i*31+direction*r*210
      s.zoom_x = s.zoom_y = 0.26+i%5*0.13

      s.opacity = if v >= 0 && v <= 1
        ((1-r)**0.65*250).round
      else
        0
      end
    end
  end
end