#===============================================================================
# RAPID RIVER - Twin Torrent
# Pokemon Essentials v21.1 | [KAITO] MoveAnimationAlias
# Requires: Animation/000_AnimationCore.rb
#===============================================================================

module KaitoRapidRiverVisual
  def self.wave(a)
    a.bitmap(224, 108) do |b|
      a.polygon(b, [
        [3, 59], [32, 38], [63, 42], [92, 22], [126, 30],
        [153, 11], [177, 17], [196, 40], [188, 48],
        [204, 44], [222, 57], [206, 72], [166, 79],
        [127, 69], [92, 85], [54, 76], [24, 87], [2, 73]
      ], Color.new(22, 116, 203, 235))
      a.polygon(b, [
        [5, 57], [39, 43], [67, 49], [100, 31], [130, 38],
        [158, 21], [181, 29], [194, 48], [177, 54],
        [201, 53], [216, 59], [193, 66], [161, 67],
        [122, 57], [93, 73], [58, 65], [22, 76], [5, 68]
      ], Color.new(63, 192, 237, 240))
      a.polygon(b, [
        [18, 55], [44, 48], [69, 54], [104, 38],
        [132, 44], [162, 30], [179, 37], [190, 50],
        [166, 48], [140, 50], [111, 47], [89, 61],
        [51, 57], [20, 66]
      ], Color.new(148, 239, 251, 235))
      a.polygon(b, [
        [61, 44], [91, 31], [119, 31], [149, 17],
        [169, 20], [179, 30], [153, 27], [130, 40],
        [101, 39], [73, 51]
      ], Color.new(225, 255, 255, 235))
      a.polygon(b, [
        [58, 73], [86, 75], [122, 61], [157, 71],
        [185, 67], [159, 81], [128, 76], [94, 89]
      ], Color.new(18, 83, 168, 220))
      b.fill_rect(111, 43, 48, 2, Color.new(255, 255, 255, 220))
      b.fill_rect(37, 61, 30, 2, Color.new(214, 253, 255, 190))
    end
  end

  def self.drop(a)
    a.bitmap(20, 30) do |b|
      a.polygon(b, [
        [10, 0], [16, 12], [19, 20], [16, 26],
        [11, 29], [5, 27], [1, 21], [4, 12]
      ], Color.new(47, 165, 230, 245))
      a.polygon(b, [
        [10, 5], [14, 15], [14, 22],
        [10, 26], [5, 22], [6, 16]
      ], Color.new(160, 239, 255, 240))
      b.fill_rect(7, 14, 3, 6, Color.new(248, 255, 255, 250))
    end
  end

  def self.foam(a)
    a.bitmap(26, 24) do |b|
      [[8, 14, 7], [17, 15, 8], [12, 7, 6], [22, 9, 3]].each do |cx, cy, r|
        (-r..r).each do |dy|
          dx = Math.sqrt(r * r - dy * dy).floor
          b.fill_rect(cx - dx, cy + dy, dx * 2 + 1, 1,
                      Color.new(236, 255, 255, 245))
        end
      end
      b.fill_rect(7, 17, 13, 2, Color.new(137, 220, 247, 205))
    end
  end

  def self.glow(a)
    a.bitmap(112, 112) do |b|
      112.times do |y|
        112.times do |x|
          r = Math.sqrt((x - 55.5)**2 + (y - 55.5)**2) / 55.5
          next if r >= 1.0
          alpha = ((1.0 - r)**2 * 185).to_i
          b.set_pixel(x, y, Color.new(121, 228, 255, alpha))
        end
      end
    end
  end

  SETUP = proc do |a|
    first = a.hit_num == 0
    if first
      a.sound_at(0.04, ["PRSFX- Aqua Ring1", "PRSFX- Bubblebeam"], 50, 115)
      a.sound_at(0.43, ["PRSFX- Aqua Jet"], 82, 100)
      a.sound_at(0.97, ["PRSFX- Liquidation2", "PRSFX- Aqua Tail"], 87, 105)
    else
      a.sound_at(0.10, ["PRSFX- Aqua Jet"], 88, 115)
      a.sound_at(0.54, ["PRSFX- Liquidation3", "PRSFX- Aqua Tail"], 92, 110)
    end

    a[:start] = first ? 0.42 : 0.09
    a[:travel] = first ? 0.55 : 0.45
    a[:impact] = a[:start] + a[:travel]
    a[:power] = first ? 1.0 : 1.18

    ux, uy = a.center
    a[:ux], a[:uy] = ux, uy
    source = a.battler_sprite
    a[:user_body] = a.copy(a.user, hide_original: true, z: 20_019)
    a[:user_x], a[:user_y] = a[:user_body].x, a[:user_body].y
    a[:user_color] = a[:user_body].color.clone

    water = KaitoRapidRiverVisual.wave(a)
    drop = KaitoRapidRiverVisual.drop(a)
    foam = KaitoRapidRiverVisual.foam(a)
    glow = KaitoRapidRiverVisual.glow(a)
    ring = a.ring(53, Color.new(188, 248, 255, 235), 3)
    thin = a.ring(42, Color.new(77, 200, 245, 225), 2)

    veil_bitmap = a.bitmap(Graphics.width, Graphics.height) do |b|
      b.fill_rect(0, 0, b.width, b.height, Color.new(13, 45, 83))
    end
    a[:veil] = a.sprite(veil_bitmap, z: 19_990, centered: false)

    a[:charge_glow] = a.sprite(glow, z: 20_014)
    a[:charge_rings] = Array.new(3) { a.sprite(ring, z: 20_020) }
    a[:charge_drops] = Array.new(16) { a.sprite(drop, z: 20_025) }

    a[:groups] = a.targets.map do |target|
      tx, ty = a.center(target)
      dx = tx - ux
      dy = ty - uy
      dist = [Math.sqrt(dx * dx + dy * dy), 1.0].max
      sx = ux + dx / dist * 31
      sy = uy + dy / dist * 20
      body = a.copy(target, hide_original: true, z: 20_019)

      {
        sx: sx, sy: sy, tx: tx, ty: ty,
        dx: tx - sx, dy: ty - sy,
        nx: -(ty - sy) / dist, ny: (tx - sx) / dist,
        angle: -Math.atan2(ty - sy, tx - sx) * 180.0 / Math::PI,
        direction: dx >= 0 ? 1 : -1,
        body: body, base_x: body.x, base_y: body.y,
        body_color: body.color.clone,
        waves: Array.new(3) { a.sprite(water, z: 20_027) },
        glow: a.sprite(glow, z: 20_028),
        front_foam: Array.new(23) { a.sprite(foam, z: 20_032) },
        tail_drops: Array.new(18) { a.sprite(drop, z: 20_030) },
        impact_rings: Array.new(3) { a.sprite(ring, z: 20_036) },
        impact_inner: a.sprite(thin, z: 20_037),
        impact_glow: a.sprite(glow, z: 20_035),
        splashes: Array.new(40) { a.sprite(drop, z: 20_040) },
        bubbles: Array.new(24) { a.sprite(foam, z: 20_041) }
      }
    end
  end

  UPDATE = proc do |a, _t|
    sec = a.seconds
    first = a.hit_num == 0
    start = a[:start]
    travel = a[:travel]
    hit_at = a[:impact]
    power = a[:power]
    fade = a.clamp(sec / 0.15) * a.clamp((a.duration - sec) / 0.23)

    a[:veil].opacity = (fade * 64).to_i

    # Water pressure gathers in front of the user before release.
    charge = first ? a.clamp(sec / 0.34) : a.clamp(sec / 0.09)
    charge_out = a.clamp((start + 0.13 - sec) / 0.18)
    ux, uy = a[:ux], a[:uy]
    aura = a[:charge_glow]
    aura.x, aura.y = ux, uy
    aura.zoom_x = aura.zoom_y = 0.35 + charge * 0.88
    aura.opacity = (charge * charge_out * 200).to_i

    a[:charge_rings].each_with_index do |s, i|
      q = (sec - i * (first ? 0.10 : 0.035)) / (first ? 0.48 : 0.22)
      p = a.clamp(q)
      s.x, s.y = ux, uy
      s.zoom_x = 0.24 + p * 1.08
      s.zoom_y = s.zoom_x * 0.36
      s.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * charge_out * 220).to_i : 0
    end

    a[:charge_drops].each_with_index do |s, i|
      q = (sec - i % 5 * (first ? 0.035 : 0.010)) /
          (first ? 0.42 : 0.22)
      p = a.clamp(q)
      theta = i * 2.399
      radius = (52 + i % 4 * 8) * (1.0 - p)
      s.x = ux + Math.cos(theta) * radius
      s.y = uy + Math.sin(theta) * radius * 0.65
      s.zoom_x = s.zoom_y = 0.16 + i % 3 * 0.07
      s.angle = i * 24 + p * 80
      s.opacity = q.between?(0.0, 1.0) ?
        (Math.sin(p * Math::PI) * charge_out * 230).to_i : 0
    end

    recoil = a.clamp((sec - start) / 0.08) *
             a.clamp((start + 0.37 - sec) / 0.26)
    a[:user_body].x = a[:user_x] - recoil * 5 * (
      a[:groups].empty? ? 1 : a[:groups][0][:direction]
    )
    a[:user_body].y = a[:user_y] + recoil * 2
    a[:user_body].color = recoil > 0 ?
      Color.new(153, 235, 255, (recoil * 85).to_i) : a[:user_color]

    a[:groups].each do |g|
      sx, sy, tx, ty = g.values_at(:sx, :sy, :tx, :ty)
      q = (sec - start) / travel
      p = a.clamp(q)
      speed = p * p * (3.0 - 2.0 * p)
      cx = a.lerp(sx, tx, speed)
      cy = a.lerp(sy, ty, speed) - Math.sin(p * Math::PI) * 13
      active = q.between?(0.0, 1.0)
      release = a.clamp((sec - hit_at) / 0.09)

      # Three overlapping torrents form a fast continuous river.
      g[:waves].each_with_index do |s, i|
        delay = i * 0.08
        wq = (sec - start - delay) / travel
        wp = a.clamp(wq)
        ease = wp * wp * (3.0 - 2.0 * wp)
        s.x = a.lerp(sx, tx, ease) - g[:direction] * (12 + i * 15)
        s.y = a.lerp(sy, ty, ease) -
              Math.sin(wp * Math::PI) * (13 + i * 5) +
              (i - 1) * 8
        s.mirror = g[:direction] < 0
        s.angle = g[:angle] * 0.40
        s.zoom_x = (0.72 + i * 0.16) * power
        s.zoom_y = (0.60 + i * 0.14) * power
        s.opacity = wq.between?(0.0, 1.0) ?
          (Math.sin(wp * Math::PI)**0.35 *
           (245 - i * 38) * a.clamp((1.0 - release) / 0.35)).to_i : 0
      end

      glow = g[:glow]
      glow.x, glow.y = cx, cy
      glow.zoom_x = 0.52 + power * 0.48
      glow.zoom_y = 0.54 + power * 0.33
      glow.opacity = active ? (Math.sin(p * Math::PI) * 160).to_i : 0

      # White spray rides the crest.
      g[:front_foam].each_with_index do |s, i|
        fq = (sec - start - i % 5 * 0.018) / travel
        fp = a.clamp(fq)
        theta = i * 2.399
        s.x = a.lerp(sx, tx, fp) + Math.cos(theta) * (13 + i % 5 * 6)
        s.y = a.lerp(sy, ty, fp) - 25 -
              Math.sin(theta) * (12 + i % 4 * 8) -
              Math.sin(fp * Math::PI) * 14
        s.zoom_x = s.zoom_y = 0.16 + i % 4 * 0.08
        s.angle = i * 23 + fp * 60
        s.opacity = fq.between?(0.0, 1.0) ?
          (Math.sin(fp * Math::PI) * 230).to_i : 0
      end

      g[:tail_drops].each_with_index do |s, i|
        tq = (sec - start - 0.03 - i % 6 * 0.016) / travel
        tp = a.clamp(tq)
        angle = i * 2.399
        s.x = a.lerp(sx, tx, tp * tp) - g[:direction] * (18 + i % 5 * 9)
        s.y = a.lerp(sy, ty, tp * tp) +
              Math.sin(angle) * (12 + i % 4 * 9) -
              Math.sin(tp * Math::PI) * 26
        s.zoom_x = s.zoom_y = 0.22 + i % 4 * 0.10
        s.angle = -g[:angle] + i * 17
        s.opacity = tq.between?(0.0, 1.0) ?
          (Math.sin(tp * Math::PI) * 235).to_i : 0
      end

      # Impact: expanding ripple, white foam and exploding droplets.
      age = sec - hit_at
      hp = a.clamp(age / 0.54)
      hit_active = age.between?(0.0, 0.54)

      g[:impact_rings].each_with_index do |s, i|
        rq = (age - i * 0.065) / 0.45
        rp = a.clamp(rq)
        s.x, s.y = tx, ty
        s.zoom_x = (0.22 + rp * (1.40 + i * 0.33)) * power
        s.zoom_y = s.zoom_x * (i == 0 ? 0.80 : 0.45)
        s.opacity = rq.between?(0.0, 1.0) ?
          ((1.0 - rp) * (245 - i * 24)).to_i : 0
      end

      g[:impact_inner].x, g[:impact_inner].y = tx, ty
      g[:impact_inner].zoom_x = g[:impact_inner].zoom_y =
        (0.15 + hp * 1.85) * power
      g[:impact_inner].opacity = hit_active ?
        ((1.0 - hp) * 215).to_i : 0

      ig = g[:impact_glow]
      ig.x, ig.y = tx, ty
      ig.zoom_x = ig.zoom_y = 0.55 + hp * 1.60
      ig.opacity = hit_active ? ((1.0 - hp)**2 * 235).to_i : 0

      g[:splashes].each_with_index do |s, i|
        dq = (age - i % 5 * 0.012) / 0.60
        dp = a.clamp(dq)
        theta = i * 2.399
        distance = (27 + i % 7 * 14) * power
        s.x = tx + Math.cos(theta) * distance * dp
        s.y = ty + Math.sin(theta) * distance * dp * 0.45 -
              Math.sin(dp * Math::PI) * (22 + i % 5 * 16) +
              dp * dp * 32
        s.zoom_x = (0.23 + i % 4 * 0.12) * (1.0 - dp * 0.32)
        s.zoom_y = s.zoom_x * 1.32
        s.angle = theta * 180 / Math::PI
        s.opacity = dq.between?(0.0, 1.0) ?
          (Math.sin(dp * Math::PI) * 250).to_i : 0
      end

      g[:bubbles].each_with_index do |s, i|
        bq = (age - 0.07 - i % 6 * 0.022) / 0.60
        bp = a.clamp(bq)
        theta = i * 2.399
        s.x = tx + Math.cos(theta) * (13 + bp * (32 + i % 4 * 11))
        s.y = ty + Math.sin(theta) * (13 + bp * 31) + bp * bp * 33
        s.zoom_x = s.zoom_y = 0.20 + i % 4 * 0.08
        s.opacity = bq.between?(0.0, 1.0) ?
          (Math.sin(bp * Math::PI) * 220).to_i : 0
      end

      body = g[:body]
      shake = hit_active ? (1.0 - hp) * 8 * power : 0
      body.x = g[:base_x] + Math.sin(age * 95) * shake +
               g[:direction] * hp * (hit_active ? 6 : 0)
      body.y = g[:base_y] + Math.sin(age * 75).abs * shake * 0.30
      body.color = age.between?(0.0, 0.18) ?
        Color.new(207, 248, 255, ((1.0 - age / 0.18) * 200).to_i) :
        g[:body_color]
    end
  end
end

KaitoAnimation.register(
  :RAPIDRIVER,
  hit: 0,
  duration: 1.68,
  setup: KaitoRapidRiverVisual::SETUP,
  &KaitoRapidRiverVisual::UPDATE
)

KaitoAnimation.register(
  :RAPIDRIVER,
  hit: 1,
  duration: 1.12,
  setup: KaitoRapidRiverVisual::SETUP,
  &KaitoRapidRiverVisual::UPDATE
)
