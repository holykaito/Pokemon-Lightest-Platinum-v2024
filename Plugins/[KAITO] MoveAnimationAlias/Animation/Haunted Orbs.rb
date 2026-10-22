#===============================================================================
# Haunted Orbs - Pokemon Essentials v21.1 / MAG
# Move animation + persistent hazard + entry activation.
# Presentation only. Does not change hazard effects or stat calculations.
#===============================================================================
module KaitoHauntedOrbs
  CAST_SECONDS = 2.35
  HIT_SECONDS  = 1.20

  def self.clamp(x)
    [[x, 0.0].max, 1.0].min
  end

  def self.disc(b, cx, cy, r, color)
    cx, cy, r = cx.round, cy.round, [r.round, 1].max
    (-r..r).each do |dy|
      dx = Math.sqrt([r * r - dy * dy, 0].max).floor
      b.fill_rect(cx - dx, cy + dy, dx * 2 + 1, 1, color)
    end
  end

def self.draw_orb(b)
  # Soft aura surrounding the round flame body.
  29.downto(21) do |r|
    disc(b, 32, 34, r,
         Color.new(132, 65, 245, (30 - r) * 3))
  end

  # Short, curved tongues of fire grow out of the body.
  # Their broad roots merge with the circular silhouette.
  tongues = [
    [21, 24, 17, 10, -4],
    [30, 20, 35,  3,  5],
    [41, 23, 49, 11,  4],
    [47, 32, 57, 25,  2],
    [18, 35,  8, 28, -3]
  ]

  tongues.each do |sx, sy, tx, ty, bend|
    18.times do |i|
      p = i / 17.0
      x = sx + (tx - sx) * p +
          Math.sin(p * Math::PI) * bend
      y = sy + (ty - sy) * p
      r = [6.5 * (1 - p), 0.7].max

      disc(b, x, y, r + 2,
           Color.new(121, 57, 230, 65))
      disc(b, x, y, r,
           Color.new(159, 100, 247, 225))
      if p < 0.72
        disc(b, x, y + 1, [r * 0.48, 1].max,
             Color.new(183, 201, 255, 220))
      end
    end
  end

  # Irregular flame perimeter around a round body.
  19.downto(1) do |radius|
    160.times do |i|
      a = i * Math::PI * 2 / 160
      ripple = Math.sin(a * 7 + 0.5) * 1.5 +
               Math.sin(a * 11) * 0.8
      r = radius + ripple * (radius / 19.0) ** 2
      x = 32 + Math.cos(a) * r
      y = 35 + Math.sin(a) * r

      edge = radius / 19.0
      color = Color.new(
        (190 - edge * 57).round,
        (209 - edge * 126).round,
        250,
        235
      )
      disc(b, x, y, 1, color)
    end
  end

  # Uneven inner fire, without a glossy spherical highlight.
  disc(b, 31, 36, 12, Color.new(151, 174, 255, 245))
  disc(b, 33, 33, 10, Color.new(167, 211, 255, 245))
  disc(b, 29, 36,  8, Color.new(184, 240, 255, 250))
  disc(b, 33, 38,  6, Color.new(218, 255, 247, 250))

  # Small inner flame curling upwards.
  10.times do |i|
    p = i / 9.0
    x = 31 + Math.sin(p * Math::PI) * 3
    y = 34 - p * 15
    r = [4 * (1 - p), 0.7].max
    disc(b, x, y, r, Color.new(184, 236, 255, 235))
  end
end

  def self.draw_ring(b)
    [45, 53].each do |r|
      240.times do |i|
        next if r == 53 && i % 40 > 27
        a = i * Math::PI / 120
        disc(b, 64 + Math.cos(a) * r, 64 + Math.sin(a) * r,
             1, Color.new(190, 132, 255, r == 45 ? 235 : 150))
      end
    end
    8.times do |i|
      a = i * Math::PI / 4
      x, y = 64 + Math.cos(a) * 53, 64 + Math.sin(a) * 53
      disc(b, x, y, 3, Color.new(218, 192, 255, 235))
    end
  end

  def self.sound(names, volume, pitch)
    name = names.find do |n|
      [".ogg", ".wav", ".mp3", ".flac"].any? do |ext|
        File.file?("Audio/SE/Anim/#{n}#{ext}")
      end
    end
    pbSEPlay("Anim/#{name}", volume, pitch) if name
  end

  def self.active?(battle, side)
    return false unless defined?(PBEffects::HauntedOrbs)
    return false unless battle && battle.respond_to?(:sides)
    value = battle.sides[side].effects[PBEffects::HauntedOrbs]
    value == true || (value.is_a?(Numeric) && value > 0)
  end

  # Install after all plugins have loaded, avoiding MAG alias load-order issues.
  def self.install
    unless Battle.ancestors.include?(BattleHooks)
      Battle.prepend(BattleHooks)
    end
  end

  module BattleHooks
    def pbEntryHazards(battler)
      previous = @kaito_ho_entry
      @kaito_ho_entry = battler
      begin
        super
      ensure
        @kaito_ho_entry = previous
      end
    end

    def pbAnimation(move, user, targets, hitNum = 0)
      # MAG uses GRUDGE specifically for Haunted Orbs entry activation.
      # Replace that call only while processing this battler's entry hazards.
      matching_targets = targets.is_a?(Array) &&
                         targets.length == 1 && targets[0].equal?(user)
      haunted_hit = move == :GRUDGE && user &&
                    @kaito_ho_entry.equal?(user) && matching_targets &&
                    KaitoHauntedOrbs.active?(self, user.index % 2)

      if haunted_hit && @scene.respond_to?(:pbKaitoHauntedVisual)
        return unless @showAnims
        return @scene.pbKaitoHauntedVisual(user, true)
      end
      super
    end
  end

  module SceneHooks
    def pbAnimation(moveID, user, targets, hitNum = 0)
      KaitoHauntedOrbs.install
      return super unless moveID == :HAUNTEDORBS
      return if @battle && !@battle.showAnims
      return super unless user && @viewport && @sprites
      pbKaitoHauntedVisual(user, false)
    end

    def pbHOAssets
      return @ho_assets if @ho_assets
      @ho_assets = []
      begin
        orb = Bitmap.new(64, 64)
        @ho_assets << orb
        KaitoHauntedOrbs.draw_orb(orb)

        ring = Bitmap.new(128, 128)
        @ho_assets << ring
        KaitoHauntedOrbs.draw_ring(ring)

        spark = Bitmap.new(12, 12)
        @ho_assets << spark
        spark.fill_rect(5, 1, 2, 10, Color.new(195, 156, 255, 200))
        spark.fill_rect(1, 5, 10, 2, Color.new(195, 156, 255, 200))
        spark.fill_rect(4, 4, 4, 4, Color.new(237, 255, 246, 255))

        shade = Bitmap.new(1, 1)
        @ho_assets << shade
        shade.fill_rect(0, 0, 1, 1, Color.new(24, 8, 45))
      rescue
        @ho_assets.each { |b| b.dispose unless b.disposed? }
        @ho_assets = nil
        raise
      end
      @ho_assets
    end

    def pbHOMake(bitmap, ox, oy, z, collection)
      s = Sprite.new(@viewport)
      collection << s
      s.bitmap, s.ox, s.oy, s.z = bitmap, ox, oy, z
      s.opacity = 0
      s
    end

    def pbHOHideBoxes
      return unless @ho_boxes
      @sprites.each do |key, s|
        next unless key.to_s.start_with?("dataBox_")
        next unless s && !s.disposed?
        @ho_boxes[s.object_id] ||= [s, s.visible]
        s.visible = false
      end
    end

    def pbHOScale
      [Graphics.width / 512.0, Graphics.height / 384.0].min
    end

    def pbHOAnchor(side)
      Battle::Scene.pbBattlerPosition(side, 1)
    end

    # Persistent hazard: read the real side effect every graphics frame.
    def pbHOAmbient
      return unless @battle && @viewport && !@viewport.disposed?
      return unless @battle.respond_to?(:sides)

      enabled = @battle.showAnims && !@battleEnd
      active = [0, 1].map do |side|
        enabled && KaitoHauntedOrbs.active?(@battle, side)
      end

      if !active.any? && !@ho_ambient
        return
      end

      @ho_ambient ||= [nil, nil]
      @ho_clock = (@ho_clock || 0.0) + 1.0 / [Graphics.frame_rate, 1].max
      scale = pbHOScale

      2.times do |side|
        if active[side] && !@ho_ambient[side]
          assets = pbHOAssets
          group = []
          pbHOMake(assets[1], 64, 64, 30, group)
          5.times { pbHOMake(assets[0], 32, 34, 50, group) }
          @ho_ambient[side] = group
        end

        group = @ho_ambient[side]
        next unless group

        unless active[side]
          group.each { |s| s.dispose unless s.disposed? }
          @ho_ambient[side] = nil
          next
        end

        visible = !@ho_playing
        cx, cy = pbHOAnchor(side)
        size = scale * (side == 0 ? 1.0 : 0.76)
        reference = @sprites["pokemon_#{side}"]
        base_z = reference && !reference.disposed? ? reference.z : 50

        ring = group[0]
        ring.visible = visible
        ring.x, ring.y = cx, cy + 2 * size
        ring.zoom_x, ring.zoom_y = 1.45 * size, 0.36 * size
        ring.opacity = (62 + Math.sin(@ho_clock * 2) * 18).round
        ring.z = base_z - 2

group[1, 5].each_with_index do |s, i|
  a = i * Math::PI * 2 / 5 + @ho_clock * 0.65
  pulse = Math.sin(@ho_clock * 3.4 + i * 1.7)
  flicker = Math.sin(@ho_clock * 7.5 + i * 2.3)

  s.visible = visible

  # Spread the larger flames around the affected side.
  s.x = cx + Math.cos(a) * 82 * size
  s.y = cy - 26 * size +
        Math.sin(a) * 20 * size -
        Math.sin(@ho_clock * 2.6 + i) * 7 * size

  # Approximately twice the previous ambient size.
orb_size = (0.72 + pulse * 0.035) * size
s.zoom_x = s.zoom_y = orb_size

  s.angle = Math.sin(@ho_clock * 2.8 + i) * 5
  s.opacity = (195 + pulse * 25).round
  s.z = Math.sin(a) > 0 ? base_z + 1 : base_z - 1
end
      end
    end

    def pbGraphicsUpdate
      KaitoHauntedOrbs.install
      pbHOHideBoxes if @ho_boxes
      pbHOAmbient
      super
    end

    def pbHODispose
      if @ho_ambient
        @ho_ambient.compact.each do |group|
          group.each { |s| s.dispose unless s.disposed? }
        end
      end
      @ho_ambient = nil
      if @ho_assets
        @ho_assets.each { |b| b.dispose unless b.disposed? }
      end
      @ho_assets = nil
      @ho_clock = nil
    end

    def pbDisposeSprites
      begin
        super
      ensure
        pbHODispose
      end
    end

    # Charging orbit -> arcing projectile -> haunting orbit over the target side.
    def pbHOFlight(t, i, sx, sy, tx, ty, scale)
      start = 0.27 + i * 0.035
      a = i * Math::PI * 2 / 5
      if t < start
        p = KaitoHauntedOrbs.clamp(t / 0.27)
        a += p * Math::PI * 2
        r = (51 - p * 17) * scale
        x = sx + Math.cos(a) * r
        y = sy + Math.sin(a) * r * 0.50
        return [x, y, (0.35 + p * 0.40) * scale]
      end

      p = KaitoHauntedOrbs.clamp((t - start) / 0.34)
      end_x = tx + Math.cos(a) * 65 * scale
      end_y = ty - 20 * scale + Math.sin(a) * 19 * scale
      cx = sx + (tx - sx) * 0.50
      cy = [sy, ty].min - (80 + i * 8) * scale

      if p < 1
        q = 1 - p
        x = q * q * sx + 2 * q * p * cx + p * p * end_x
        y = q * q * sy + 2 * q * p * cy + p * p * end_y
        return [x, y, (0.75 + Math.sin(p * Math::PI) * 0.20) * scale]
      end

      a += (t - start - 0.34) * 4
      [tx + Math.cos(a) * 65 * scale,
       ty - 20 * scale + Math.sin(a) * 19 * scale,
       0.62 * scale]
    end

    def pbKaitoHauntedVisual(user, hit)
      return if @battle && !@battle.showAnims
      return if @ho_playing
      source = @sprites && @sprites["pokemon_#{user.index}"]
      return unless source && !source.disposed? && source.bitmap
      return unless @viewport && !@viewport.disposed?

      objects = []
      @ho_boxes = {}
      @ho_playing = true

      begin
        @briefMessage = false
        pbHOHideBoxes
        assets = pbHOAssets
        scale = pbHOScale

        sx = source.x +
             (source.src_rect.width / 2.0 - source.ox) * source.zoom_x
        sy = source.y +
             (source.src_rect.height / 2.0 - source.oy) * source.zoom_y
        tx, ty = hit ? [sx, source.y] : pbHOAnchor(1 - user.index % 2)

        shade = pbHOMake(assets[3], 0, 0, 19_990, objects)
        shade.zoom_x, shade.zoom_y = Graphics.width, Graphics.height

        rings = Array.new(3) do
          pbHOMake(assets[1], 64, 64, 20_005, objects)
        end
        orbs = Array.new(5) do
          pbHOMake(assets[0], 32, 34, 20_020, objects)
        end
        trails = Array.new(5) do
          Array.new(4) { pbHOMake(assets[0], 32, 34, 20_010, objects) }
        end
        sparks = Array.new(30) do
          s = pbHOMake(assets[2], 6, 6, 20_030, objects)
          s.blend_type = 1
          s
        end

        seconds = hit ? KaitoHauntedOrbs::HIT_SECONDS :
                        KaitoHauntedOrbs::CAST_SECONDS
        frames = [(Graphics.frame_rate * seconds).round, 2].max
        sound_played = false

        KaitoHauntedOrbs.sound(
          hit ? ["PRSFX- Grudge", "PRSFX- Hex", "PRSFX- Curse"] :
                ["PRSFX- Ominous Wind", "PRSFX- Curse"],
          hit ? 75 : 65, hit ? 105 : 90
        )

        frames.times do |f|
          t = f.to_f / (frames - 1)
          fade = KaitoHauntedOrbs.clamp(
            [t / 0.12, (1 - t) / 0.16].min
          )
          shade.opacity = (fade * (hit ? 85 : 100)).round

          unless sound_played
            if t >= (hit ? 0.53 : 0.30)
              KaitoHauntedOrbs.sound(
                hit ? ["PRSFX- Hex", "PRSFX- Shadow Ball2"] :
                      ["PRSFX- Shadow Ball1", "PRSFX- Grudge"],
                80, hit ? 115 : 105
              )
              sound_played = true
            end
          end

          rings.each_with_index do |s, i|
            if hit
              p = KaitoHauntedOrbs.clamp((t - 0.48 - i * 0.04) / 0.38)
              s.x, s.y = sx, sy
              s.zoom_x = s.zoom_y = (0.25 + p * 1.75) * scale
              s.angle = i * 30 + p * 110
              s.opacity = t >= 0.48 + i * 0.04 ?
                ((1 - p) * 205 * fade).round : 0
            else
              late = t >= 0.62
              p = late ? KaitoHauntedOrbs.clamp((t - 0.62) / 0.30) :
                         KaitoHauntedOrbs.clamp(t / 0.30)
              s.x, s.y = late ? [tx, ty] : [sx, source.y]
              s.zoom_x = (0.5 + p * 0.9 + i * 0.15) * scale
              s.zoom_y = s.zoom_x * 0.30
              s.opacity = (fade * (late ? 150 : 190) *
                           (1 - i * 0.19)).round
            end
          end

          orbs.each_with_index do |s, i|
            if hit
              p = KaitoHauntedOrbs.clamp(t / 0.62)
              a = i * Math::PI * 2 / 5 + p * Math::PI * 3
              r = (1 - p) * 89 * scale
              s.x = sx + Math.cos(a) * r
              s.y = sy + Math.sin(a) * r * 0.65
              size = (0.50 + p * 0.38) * scale
              s.opacity = (fade * (1 - KaitoHauntedOrbs.clamp(
                (t - 0.60) / 0.16
              )) * 245).round

              trails[i].each_with_index do |tail, j|
                q = KaitoHauntedOrbs.clamp((t - (j + 1) * 0.022) / 0.62)
                aa = i * Math::PI * 2 / 5 + q * Math::PI * 3
                rr = (1 - q) * 89 * scale
                tail.x = sx + Math.cos(aa) * rr
                tail.y = sy + Math.sin(aa) * rr * 0.65
                tail.zoom_x = tail.zoom_y = size * (0.70 - j * 0.12)
                tail.opacity = (s.opacity * (0.32 - j * 0.065)).round
              end
            else
              x, y, size = pbHOFlight(t, i, sx, sy, tx, ty, scale)
              s.x, s.y = x, y
              s.opacity = (fade * 245).round

              trails[i].each_with_index do |tail, j|
                old_t = [t - (j + 1) * 0.017, 0].max
                xx, yy, zz = pbHOFlight(old_t, i, sx, sy, tx, ty, scale)
                tail.x, tail.y = xx, yy
                tail.zoom_x = tail.zoom_y = zz * (0.75 - j * 0.12)
                tail.opacity = t > 0.25 && t < 0.81 ?
                  (fade * (72 - j * 15)).round : 0
              end
            end
            s.zoom_x = s.zoom_y = size
            s.angle = Math.sin(t * 14 + i) * 7
          end

          sparks.each_with_index do |s, i|
            a = i * 2.399 + t * 3
            if hit
              p = (t - 0.53) / 0.43
              s.visible = p >= 0 && p <= 1
              next unless s.visible
              r = (12 + p * (58 + i % 5 * 13)) * scale
              s.x = sx + Math.cos(a) * r
              s.y = sy + Math.sin(a) * r * 0.75 + p * p * 24 * scale
              s.opacity = ((1 - p) * 240).round
            else
              p = (t * 2 + i * 0.113) % 1
              center_x, center_y = t < 0.42 ? [sx, sy] : [tx, ty - 15 * scale]
              r = (22 + i % 6 * 8) * scale
              s.x = center_x + Math.cos(a) * r
              s.y = center_y + Math.sin(a) * r * 0.40 - p * 35 * scale
              s.opacity = (Math.sin(p * Math::PI) * fade * 190).round
            end
            s.zoom_x = s.zoom_y = (0.30 + i % 3 * 0.17) * scale
            s.angle = t * 180 + i * 23
          end

          pbUpdate
        end
      ensure
        saved = @ho_boxes
        @ho_boxes = nil
        @ho_playing = false
        objects.reverse_each { |s| s.dispose unless s.disposed? }
        if saved
          saved.each_value do |s, visible|
            s.visible = visible unless s.disposed?
          end
        end
      end
    end
  end
end

unless Battle::Scene.ancestors.include?(KaitoHauntedOrbs::SceneHooks)
  Battle::Scene.prepend(KaitoHauntedOrbs::SceneHooks)
end