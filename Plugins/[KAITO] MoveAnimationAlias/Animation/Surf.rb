#===============================================================================
# SURF - Rolling Wave / Pokemon Essentials v21.1
# Replace the previous Surf.rb completely.
# No external graphics or PBS edits required.
#===============================================================================
module KaitoSurfVisual
  DURATION = 2.55

  def self.clamp(x)
    [[x, 0.0].max, 1.0].min
  end

  def self.disc(b, x, y, r, color)
    x, y, r = x.round, y.round, [r.round, 1].max
    (-r..r).each do |dy|
      dx = Math.sqrt([r * r - dy * dy, 0].max).floor
      b.fill_rect(x - dx, y + dy, dx * 2 + 1, 1, color)
    end
  end

  def self.polygon(b, points, color)
    low, high = points.map { |p| p[1] }.minmax
    ([low.floor, 0].max..[high.ceil, b.height - 1].min).each do |y|
      hits = []
      points.each_with_index do |p, i|
        q = points[(i + 1) % points.length]
        next unless (p[1] <= y && q[1] > y) ||
                    (q[1] <= y && p[1] > y)
        hits << p[0] + (y - p[1]).to_f *
                (q[0] - p[0]) / (q[1] - p[1])
      end
      hits.sort.each_slice(2) do |left, right|
        next unless right
        x1 = [left.ceil, 0].max
        x2 = [right.floor, b.width - 1].min
        b.fill_rect(x1, y, x2 - x1 + 1, 1, color) if x2 >= x1
      end
    end
  end

  # Catmull-Rom curves keep the crest smooth instead of angular.
  def self.curve(points, closed = false)
    output = []
    count = closed ? points.length : points.length - 1
    count.times do |i|
      p0 = points[closed ? (i - 1) % points.length : [i - 1, 0].max]
      p1 = points[i]
      p2 = points[(i + 1) % points.length]
      p3 = points[closed ? (i + 2) % points.length :
                   [i + 2, points.length - 1].min]
      7.times do |j|
        t = j / 7.0
        output << [0, 1].map do |axis|
          a, b, c, d = [p0, p1, p2, p3].map { |p| p[axis] }
          0.5 * (2 * b + (-a + c) * t +
            (2 * a - 5 * b + 4 * c - d) * t * t +
            (-a + 3 * b - 3 * c + d) * t * t * t)
        end
      end
    end
    output << points[-1] unless closed
    output
  end

  def self.stroke(b, points, radius, color)
    curve(points).each { |x, y| disc(b, x, y, radius, color) }
  end

  def self.draw_wave(b, phase)
    outline = [
      [5, 182], [37, 155], [65, 119], [85, 76],
      [104, 40], [130, 21], [162, 19], [191, 31],
      [212, 53], [220, 78], [214, 98], [200, 106],
      [187, 101], [182, 89], [188, 78], [197, 80],
      [201, 89], [204, 77], [195, 62], [179, 56],
      [166, 65], [164, 86], [175, 114], [201, 143],
      [224, 180], [244, 217], [5, 217]
    ]
    outline = outline.each_with_index.map do |p, i|
      offset = i < 24 ? Math.sin(phase + i * 0.48) * 2.5 : 0
      [p[0], p[1] + offset]
    end

    polygon(b, curve(outline, true), Color.new(21, 112, 191, 235))

    polygon(b, curve([
      [8, 184], [54, 151], [87, 101], [114, 58],
      [143, 39], [172, 43], [151, 67], [148, 99],
      [169, 135], [202, 171], [222, 211], [8, 211]
    ], true), Color.new(43, 173, 222, 235))

    polygon(b, curve([
      [20, 183], [66, 150], [98, 103], [123, 67],
      [139, 57], [119, 102], [105, 151], [89, 199],
      [29, 207]
    ], true), Color.new(94, 217, 242, 215))

    polygon(b, curve([
      [8, 205], [86, 186], [150, 174], [205, 190],
      [232, 217], [8, 217]
    ], true), Color.new(13, 83, 162, 190))

    rim = curve(outline[0, 17])
    rim.each_with_index do |(x, y), i|
      disc(b, x, y, 5, Color.new(153, 241, 255, 245))
      disc(b, x, y - 1, 2, Color.new(245, 255, 255, 255))
      next unless i % 7 == 0
      r = 3 + (i / 7) % 3
      disc(b, x - 2, y - 3, r, Color.new(230, 255, 255, 245))
    end

    stroke(b, [[29, 184], [76, 151], [106, 104], [130, 69]],
           2, Color.new(191, 250, 255, 210))
    stroke(b, [[112, 176], [125, 135], [139, 108]],
           2, Color.new(112, 231, 252, 190))
    stroke(b, [[166, 125], [184, 149], [208, 187]],
           2, Color.new(157, 240, 255, 210))

    19.times do |i|
      x = 19 + (i * 41) % 201
      y = 192 + (i * 13) % 22
      b.fill_rect(x, y, 8 + i % 9, 2,
                  Color.new(187, 248, 255, 190))
    end
  end

  def self.draw_ring(b)
    240.times do |i|
      a = i * Math::PI / 120
      next if i % 47 > 39
      x = 64 + Math.cos(a) * 54
      y = 64 + Math.sin(a) * 54
      disc(b, x, y, 2, Color.new(167, 239, 255, 210))
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
      return super unless moveID == :SURF
      return if @battle && !@battle.showAnims
      return super unless user && @sprites && @viewport
      return if @kaito_surf_boxes

      source = @sprites["pokemon_#{user.index}"]
      return super unless source && !source.disposed? && source.bitmap

      list = (targets.is_a?(Array) ? targets : [targets]).compact
      pbKaitoRollingSurf(user, source, list)
    end

    def pbKaitoSurfHideBoxes
      return unless @kaito_surf_boxes
      @sprites.each do |key, sprite|
        next unless key.to_s.start_with?("dataBox_")
        next unless sprite && !sprite.disposed?
        @kaito_surf_boxes[sprite.object_id] ||= [sprite, sprite.visible]
        sprite.visible = false
      end
    end

    def pbGraphicsUpdate
      pbKaitoSurfHideBoxes if @kaito_surf_boxes
      super
    end

    def pbKaitoRollingSurf(user, source, targets)
      objects, bitmaps = [], []
      @kaito_surf_boxes = {}

      begin
        @briefMessage = false
        pbKaitoSurfHideBoxes
        scale = [Graphics.width / 512.0, Graphics.height / 384.0].min

        bitmap = proc do |w, h|
          b = Bitmap.new(w, h)
          bitmaps << b
          b
        end
        sprite = proc do |b, ox, oy, z|
          s = Sprite.new(@viewport)
          objects << s
          s.bitmap, s.ox, s.oy, s.z = b, ox, oy, z
          s.opacity = 0
          s
        end

        wave_frames = Array.new(5) do |i|
          b = bitmap.call(256, 232)
          KaitoSurfVisual.draw_wave(b, i * Math::PI * 2 / 5)
          b
        end
        ring_b = bitmap.call(128, 128)
        KaitoSurfVisual.draw_ring(ring_b)
        drop_b = bitmap.call(16, 24)
        KaitoSurfVisual.disc(drop_b, 8, 15, 6, Color.new(53, 174, 235))
        KaitoSurfVisual.disc(drop_b, 7, 13, 4, Color.new(167, 242, 255))
        KaitoSurfVisual.disc(drop_b, 6, 11, 2, Color.new(248, 255, 255))
        drop_b.fill_rect(7, 3, 2, 8, Color.new(206, 251, 255, 230))

        veil_b = bitmap.call(1, 1)
        veil_b.fill_rect(0, 0, 1, 1, Color.new(5, 35, 72))
        veil = sprite.call(veil_b, 0, 0, 19_990)
        veil.zoom_x, veil.zoom_y = Graphics.width, Graphics.height

        flash_b = bitmap.call(1, 1)
        flash_b.fill_rect(0, 0, 1, 1, Color.new(202, 247, 255))
        flash = sprite.call(flash_b, 0, 0, 20_050)
        flash.zoom_x, flash.zoom_y = Graphics.width, Graphics.height

        sx = source.x + (source.src_rect.width / 2.0 - source.ox) *
             source.zoom_x
        sy = source.y - 8 * scale

        entries = targets.uniq { |b| b.index }.filter_map do |battler|
          s = @sprites["pokemon_#{battler.index}"]
          next unless s && !s.disposed? && s.bitmap && s.visible
          next if s.respond_to?(:vanishMode) && s.vanishMode > 0
          cx = s.x + (s.src_rect.width / 2.0 - s.ox) * s.zoom_x
          cy = s.y + (s.src_rect.height / 2.0 - s.oy) * s.zoom_y
          [battler.index, cx, cy, s.y]
        end

        # Aim towards opponents even when Surf also includes an ally.
        opponents = entries.select { |e| e[0] % 2 != user.index % 2 }
        direction = user.index.even? ? 1 : -1
        if opponents.empty?
          tx = sx + direction * Graphics.width * 0.55
          ty = sy - direction * Graphics.height * 0.22
        else
          tx = opponents.sum { |e| e[1] } / opponents.length.to_f
          ty = opponents.sum { |e| e[2] } / opponents.length.to_f + 24 * scale
        end

        dx, dy = tx - sx, ty - sy
        length = [Math.sqrt(dx * dx + dy * dy), 1.0].max
        ux, uy = dx / length, dy / length
        direction = dx >= 0 ? 1 : -1
        angle = -Math.atan2(dy, dx) * 180 / Math::PI
        angle += 180 if direction < 0

        charge = Array.new(3) { sprite.call(ring_b, 64, 64, 20_005) }
        waves = Array.new(2) do
          s = sprite.call(wave_frames[0], direction > 0 ? 205 : 51,
                          207, 20_015)
          s.mirror = direction < 0
          s.angle = 0
          s
        end
        foam = Array.new(36) { sprite.call(drop_b, 8, 15, 20_025) }

        splashes = entries.map do |entry|
          distance = (entry[1] - sx) * ux + (entry[2] - sy) * uy
          hit = 0.28 + KaitoSurfVisual.clamp(distance / length) * 0.34
          drops = Array.new(20) { sprite.call(drop_b, 8, 15, 20_035) }
          rings = Array.new(2) { sprite.call(ring_b, 64, 64, 20_030) }
          [entry, hit, drops, rings]
        end

        frames = [(Graphics.frame_rate * KaitoSurfVisual::DURATION).round, 2].max
        sound_flags = [false, false, false]

        frames.times do |f|
          t = f.to_f / (frames - 1)
          fade = KaitoSurfVisual.clamp([t / 0.13, (1 - t) / 0.18].min)
          veil.opacity = (fade * 57).round

          [[0.02, ["PRSFX- Whirlpool1", "PRSFX- Dive1"], 55, 105],
           [0.27, ["PRSFX- Surf", "PRSFX- Surf1", "PRSFX- Whirlpool2"], 85, 90],
           [0.61, ["PRSFX- Surf2", "PRSFX- Dive3"], 85, 105]
          ].each_with_index do |cue, i|
            next if sound_flags[i] || t < cue[0]
            KaitoSurfVisual.sound(cue[1], cue[2], cue[3])
            sound_flags[i] = true
          end

          # Water gathers beneath the user before the wave launches.
          charge.each_with_index do |s, i|
            p = (t / 0.29 + i * 0.30) % 1
            s.x, s.y = sx, sy + 8 * scale
            s.zoom_x = (1.5 - p * 1.15) * scale
            s.zoom_y = s.zoom_x * 0.26
            s.opacity = t < 0.29 ?
              (Math.sin(p * Math::PI) * fade * 210).round : 0
          end

          waves.each_with_index do |s, i|
            start = 0.19 + i * 0.13
            p = (t - start) / 0.59
            s.visible = p >= 0 && p <= 1
            next unless s.visible

            # Grow near the user, accelerate through the target and dissipate.
            travel = KaitoSurfVisual.clamp((t - 0.28 - i * 0.13) / 0.34)
            travel = travel * travel * (3 - 2 * travel)
            extension = KaitoSurfVisual.clamp(
              (t - 0.62 - i * 0.13) / 0.16
            ) * 180 * scale

            s.x = sx + dx * travel + ux * extension
            s.y = sy + dy * travel + uy * extension
grow = KaitoSurfVisual.clamp(p / 0.12)
grow = 1.0 - (1.0 - grow) ** 3

size = (i == 0 ? 1.45 : 1.85) * scale
s.zoom_x = size * (0.50 + grow * 0.50)
s.zoom_y = size * (0.20 + grow * 0.80)
            s.bitmap = wave_frames[(t * KaitoSurfVisual::DURATION * 13).floor % 5]
            s.opacity = (KaitoSurfVisual.clamp(
              [p / 0.13, (1 - p) / 0.23].min
            ) * (i == 0 ? 225 : 245)).round
          end

          # Continuous spray rides the leading crest.
          head = waves[0]
          foam.each_with_index do |s, i|
            p = (t * 4.5 + i * 0.137) % 1
            active = t >= 0.25 && t < 0.76 && head.visible
            s.visible = active
            next unless active
            back = (18 + i % 6 * 12) * scale
            s.x = head.x - ux * back +
                  direction * p * (30 + i % 4 * 12) * scale
            s.y = head.y - (66 + i % 5 * 16) * scale -
                  Math.sin(p * Math::PI) * 28 * scale
            s.zoom_x = (0.12 + i % 4 * 0.06) * scale
            s.zoom_y = s.zoom_x * 1.6
            s.angle = direction * (25 + p * 60)
            s.opacity = (Math.sin(p * Math::PI) * 225 * fade).round
          end

          flash_strength = 0
          splashes.each do |entry, hit, drops, rings|
            cx, cy, floor_y = entry[1], entry[2], entry[3]
            age = t - hit
            flash_strength = [flash_strength,
              (1 - KaitoSurfVisual.clamp(age / 0.045)) * 55
            ].max if age >= 0

            drops.each_with_index do |s, i|
              p = (age - (i % 3) * 0.013) / 0.24
              s.visible = p >= 0 && p <= 1
              next unless s.visible
# Spray bursts forward in the direction of the incoming wave.
vx = direction * (65 + i % 5 * 24) + (i - 9.5) * 13
vy = -145 - i % 5 * 27

s.x = cx + vx * p * scale
s.y = cy + (vy * p + 270 * p * p) * scale

s.zoom_x = (0.48 + i % 4 * 0.15) * scale * (1 - p * 0.40)
s.zoom_y = s.zoom_x * (2.10 - p * 0.85)

# Orient elongated droplets along their flight.
velocity_y = vy + 540 * p
s.angle = Math.atan2(vx, -velocity_y) * 180 / Math::PI
s.opacity = ((1 - p * p) * 255).round
            end

            rings.each_with_index do |s, i|
              p = (age - i * 0.04) / 0.30
              s.visible = p >= 0 && p <= 1
              next unless s.visible
              s.x, s.y = cx, floor_y + 4 * scale
              s.zoom_x = (0.25 + p * 1.8) * scale
              s.zoom_y = s.zoom_x * 0.28
              s.opacity = ((1 - p) * 205).round
            end
          end
          flash.opacity = flash_strength.round
          pbUpdate
        end
      ensure
        saved = @kaito_surf_boxes
        @kaito_surf_boxes = nil
        objects.reverse_each { |s| s.dispose unless s.disposed? }
        bitmaps.each { |b| b.dispose unless b.disposed? }
        if saved
          saved.each_value do |s, visible|
            s.visible = visible unless s.disposed?
          end
        end
      end
    end
  end
end

unless Battle::Scene.ancestors.include?(KaitoSurfVisual::SceneHooks)
  Battle::Scene.prepend(KaitoSurfVisual::SceneHooks)
end