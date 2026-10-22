#===============================================================================
# Hay Fever - Pokemon Essentials v21.1
# Pollen stream -> enveloping cloud -> irritation puffs.
# Presentation only. Allergies remains handled by the existing move code.
#===============================================================================
module KaitoHayFever
  DURATION = 1.95

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

  def self.assets
    owned = []
    begin
      # Solid, textured pollen grains rather than sparkles.
      pollen = Bitmap.new(24, 24)
      owned << pollen
      8.times do |i|
        a = i * Math::PI / 4
        disc(pollen, 12 + Math.cos(a) * 8,
             12 + Math.sin(a) * 8, 2,
             Color.new(181, 147, 42, 225))
      end
      disc(pollen, 12, 12, 8, Color.new(205, 171, 48, 245))
      disc(pollen, 11, 11, 6, Color.new(246, 218, 88, 255))
      disc(pollen, 9, 9, 2, Color.new(255, 244, 173, 245))
      disc(pollen, 14, 13, 1, Color.new(174, 145, 42, 235))
      disc(pollen, 10, 15, 1, Color.new(174, 145, 42, 235))

      # A soft, irregular cloud of yellow-green dust.
      mist = Bitmap.new(128, 96)
      owned << mist
      [
        [35, 47, 27], [58, 35, 28], [82, 44, 28],
        [94, 57, 22], [66, 64, 25], [42, 63, 22]
      ].each do |x, y, r|
        4.downto(1) do |layer|
          disc(mist, x, y, r - (4 - layer) * 4,
               Color.new(224, 210, 103, 9 + (4 - layer) * 4))
        end
      end

      # Small leaf fragments carried by the pollen stream.
      leaf = Bitmap.new(40, 24)
      owned << leaf
      34.times do |x|
        p = x / 33.0
        half = (Math.sin(p * Math::PI) * 8).round
        next if half < 1
        leaf.fill_rect(x + 3, 12 - half, 1, half * 2,
                       Color.new(121, 167, 65, 235))
        leaf.fill_rect(x + 3, 12 - half, 1, half,
                       Color.new(183, 203, 95, 235))
      end
      leaf.fill_rect(4, 11, 32, 2, Color.new(223, 228, 146, 220))

      # Tiny dust flecks used in the final sneeze-like puffs.
      dust = Bitmap.new(8, 8)
      owned << dust
      disc(dust, 4, 4, 3, Color.new(244, 218, 108, 240))
      disc(dust, 3, 3, 1, Color.new(255, 246, 181, 250))

      owned
    rescue
      owned.each { |b| b.dispose unless b.disposed? }
      raise
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

  module SceneHooks
    def pbAnimation(moveID, user, targets, hitNum = 0)
      return super unless moveID == :HAYFEVER
      return if @battle && !@battle.showAnims
      return if @hay_fever_boxes

      target = targets.is_a?(Array) ? targets.compact.first : targets
      return super unless user && target && @sprites && @viewport

      attacker = @sprites["pokemon_#{user.index}"]
      defender = @sprites["pokemon_#{target.index}"]
      valid = [attacker, defender].all? do |s|
        s && !s.disposed? && s.bitmap && !s.bitmap.disposed?
      end
      return super unless valid

      pbKaitoHayFever(user, attacker, defender)
    end

    def pbHayFeverHideBoxes
      return unless @hay_fever_boxes
      @sprites.each do |key, s|
        next unless key.to_s.start_with?("dataBox_")
        next unless s && !s.disposed?
        @hay_fever_boxes[s.object_id] ||= [s, s.visible]
        s.visible = false
      end
    end

    def pbGraphicsUpdate
      pbHayFeverHideBoxes if @hay_fever_boxes
      super
    end

    def pbKaitoHayFever(user, attacker, defender)
      objects, bitmaps = [], []
      substitute = false
      @hay_fever_boxes = {}

      begin
        @briefMessage = false
        pbHayFeverHideBoxes

        if respond_to?(:pbAnimateSubstitute, true)
          substitute = true
          pbAnimateSubstitute(user.index, :hide)
          attacker = @sprites["pokemon_#{user.index}"]
        end
        return unless attacker && !attacker.disposed? && attacker.bitmap

        bitmaps.concat(KaitoHayFever.assets)
        pollen_b, mist_b, leaf_b, dust_b = bitmaps
        scale = [Graphics.width / 512.0,
                 Graphics.height / 384.0].min
        z = [attacker.z, defender.z].max + 100

        make = proc do |b, ox, oy, layer|
          s = Sprite.new(@viewport)
          objects << s
          s.bitmap, s.ox, s.oy, s.z = b, ox, oy, layer
          s.opacity = 0
          s
        end

        sx = attacker.x +
             (attacker.src_rect.width / 2.0 - attacker.ox) * attacker.zoom_x
        sy = attacker.y +
             (attacker.src_rect.height / 2.0 - attacker.oy) * attacker.zoom_y
        tx = defender.x +
             (defender.src_rect.width / 2.0 - defender.ox) * defender.zoom_x
        ty = defender.y +
             (defender.src_rect.height / 2.0 - defender.oy) * defender.zoom_y

        target_height = [
          defender.src_rect.height * defender.zoom_y, 64 * scale
        ].max
        cloud_radius = [[target_height * 0.45,
                         35 * scale].max, 75 * scale].min

        dx, dy = tx - sx, ty - sy
        distance = [Math.sqrt(dx * dx + dy * dy), 1].max
        ux, uy = dx / distance, dy / distance
        direction = dx >= 0 ? 1 : -1
        travel_angle = -Math.atan2(dy, dx) * 180 / Math::PI

        grains = Array.new(64) do |i|
          make.call(pollen_b, 12, 12, z + 4 + i % 2)
        end
        clouds = Array.new(9) { make.call(mist_b, 64, 48, z + 2) }
        leaves = Array.new(7) { make.call(leaf_b, 20, 12, z + 6) }
        puffs = Array.new(2) { make.call(mist_b, 64, 48, z + 9) }
        flecks = Array.new(28) { make.call(dust_b, 4, 4, z + 10) }

        frames = [(Graphics.frame_rate * KaitoHayFever::DURATION).round, 2].max
        sound_flags = [false, false, false]

        frames.times do |f|
          t = f.to_f / (frames - 1)
          fade = KaitoHayFever.clamp(
            [t / 0.12, (1 - t) / 0.22].min
          )

          cues = [
            [0.12, ["PRSFX- Sweet Scent", "PRSFX- Spore"], 65, 110],
            [0.39, ["PRSFX- Poison Powder", "PRSFX- Sleep Powder"], 70, 100],
            [0.73, ["PRSFX- Stun Spore", "PRSFX- Spore"], 45, 135]
          ]
          cues.each_with_index do |cue, i|
            next if sound_flags[i] || t < cue[0]
            KaitoHayFever.sound(cue[1], cue[2], cue[3])
            sound_flags[i] = true
          end

          # Staggered pollen particles create a broad, continuous stream.
          grains.each_with_index do |s, i|
            start = 0.13 + (i % 12) * 0.016
            p = KaitoHayFever.clamp((t - start) / 0.34)
            a = i * 2.399
            spread = (14 + i % 7 * 7) * scale

            if t < start
              charge = KaitoHayFever.clamp(t / start)
              r = (28 - charge * 13) * scale
              s.x = sx + Math.cos(a + t * 10) * r
              s.y = sy + Math.sin(a + t * 10) * r * 0.70
              s.opacity = (charge * fade * 205).round
            elsif p < 1
              ease = p * p * (3 - 2 * p)
              wobble = Math.sin(p * Math::PI * 3 + a) *
                       Math.sin(p * Math::PI) * 14 * scale

              s.x = sx + dx * ease +
                    Math.cos(a) * spread * p - uy * wobble
              s.y = sy + dy * ease +
                    Math.sin(a) * spread * p * 0.70 + ux * wobble
              s.opacity = (fade * 235).round
            else
              age = t - start - 0.34
              spin = a + age * (i.even? ? 3.5 : -2.8)
              r = spread + age * 25 * scale
              s.x = tx + Math.cos(spin) * r
              s.y = ty + Math.sin(spin) * r * 0.75 -
                    age * 32 * scale
              s.opacity = (fade * (190 + Math.sin(i + t * 9) * 30)).round
            end

            s.zoom_x = s.zoom_y = (0.23 + i % 4 * 0.085) * scale
            s.angle = i * 27 + t * (i.even? ? 135 : -110)
          end

          # Several overlapping billows travel from user to target.
          clouds.each_with_index do |s, i|
            start = 0.17 + i * 0.022
            p = KaitoHayFever.clamp((t - start) / 0.35)
            s.visible = t >= start
            next unless s.visible

            a = i * 2.399
            age = [t - start - 0.35, 0].max
            spread = (12 + i % 4 * 12 + age * 28) * scale
            ease = p * p * (3 - 2 * p)

            s.x = sx + dx * ease + Math.cos(a + age * 2) * spread * p
            s.y = sy + dy * ease +
                  Math.sin(a + age * 2) * spread * p * 0.60 -
                  age * 22 * scale

            size = (0.32 + p * 0.55 + age * 0.55) * scale
            s.zoom_x = size * 1.18
            s.zoom_y = size
            s.angle = Math.sin(t * 4 + i) * 12
            s.opacity = (fade * (p < 1 ? 80 : 105)).round
          end

          # A few leaves reinforce the Grass-type gust.
          leaves.each_with_index do |s, i|
            p = (t - 0.20 - i * 0.028) / 0.43
            s.visible = p >= 0 && p <= 1
            next unless s.visible

            a = i * 2.399
            s.x = sx + dx * p +
                  Math.cos(a + p * 7) * 22 * scale *
                  Math.sin(p * Math::PI)
            s.y = sy + dy * p +
                  Math.sin(a + p * 7) * 30 * scale
            s.zoom_x = (0.45 + i % 3 * 0.12) * scale
            s.zoom_y = s.zoom_x *
                       (0.30 + Math.sin(p * Math::PI * 4 + i).abs * 0.70)
            s.angle = travel_angle + p * 300 + i * 45
            s.opacity = (Math.sin(p * Math::PI) * 220).round
          end

          # Two quick outward puffs suggest an irritated, sneeze-like reaction.
          puffs.each_with_index do |s, i|
            p = (t - 0.70 - i * 0.12) / 0.17
            s.visible = p >= 0 && p <= 1
            next unless s.visible

            s.x = tx - direction * p * 52 * scale
            s.y = ty - cloud_radius * 0.25 - p * 10 * scale
            s.zoom_x = (0.22 + p * 0.65) * scale
            s.zoom_y = (0.20 + p * 0.42) * scale
            s.opacity = (Math.sin(p * Math::PI) * 180).round
          end

          flecks.each_with_index do |s, i|
            trigger = i < 14 ? 0.70 : 0.82
            p = (t - trigger) / 0.18
            s.visible = p >= 0 && p <= 1
            next unless s.visible

            n = i % 14
            s.x = tx - direction * (15 + n % 5 * 12) * p * scale
            s.y = ty - cloud_radius * 0.25 +
                  (n - 6.5) * p * 5 * scale +
                  p * p * 15 * scale
            s.zoom_x = s.zoom_y = (0.40 + n % 3 * 0.18) * scale
            s.opacity = ((1 - p) * 240).round
          end

          pbUpdate
        end
      ensure
        begin
          objects.reverse_each { |s| s.dispose unless s.disposed? }
          bitmaps.each { |b| b.dispose unless b.disposed? }
          pbAnimateSubstitute(user.index, :show) if substitute
        ensure
          boxes = @hay_fever_boxes
          @hay_fever_boxes = nil
          if boxes
            boxes.each_value do |s, visible|
              s.visible = visible unless s.disposed?
            end
          end
        end
      end
    end
  end
end

unless Battle::Scene.ancestors.include?(KaitoHayFever::SceneHooks)
  Battle::Scene.prepend(KaitoHayFever::SceneHooks)
end