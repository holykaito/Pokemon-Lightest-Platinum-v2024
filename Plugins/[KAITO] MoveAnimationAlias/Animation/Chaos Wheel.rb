#===============================================================================
# Chaos Wheel - Pokemon Essentials v21.1
# Move ID: CHAOSWHEEL
# Visual animation only. No changes to damage or secondary effects.
#===============================================================================
module ChaosWheelVisual
  DURATION = 1.85
  COLORS = [
    [193, 91, 235],   # Poison
    [65, 191, 255],   # Drenched
    [126, 222, 94]    # Seed
  ]

  def self.clamp(value)
    return [[value, 0.0].max, 1.0].min
  end

  def self.polygon(bitmap, points, color)
    low, high = points.map { |p| p[1] }.minmax
    (low.floor..high.ceil).each do |y|
      intersections = []
      points.each_with_index do |p, i|
        q = points[(i + 1) % points.length]
        next unless (p[1] <= y && q[1] > y) ||
                    (q[1] <= y && p[1] > y)
        intersections << p[0] +
          (y - p[1]).to_f * (q[0] - p[0]) / (q[1] - p[1])
      end
      intersections.sort.each_slice(2) do |left, right|
        next unless right
        bitmap.fill_rect(
          left.ceil, y, [right.floor - left.ceil + 1, 1].max, 1, color
        )
      end
    end
  end

  def self.assets
    bitmaps = []
    begin
      # Three interlocking curved blades.
      wheel = Bitmap.new(160, 160)
      bitmaps << wheel
      COLORS.each_with_index do |rgb, sector|
        [[1.0, 100], [0.72, 235], [0.30, 255]].each do |width, alpha|
          outer, inner = [], []
          49.times do |i|
            p = i / 48.0
            angle = sector * Math::PI * 2 / 3 + p * Math::PI * 0.60
            radius = 44 + p * 20
            half = Math.sin(p * Math::PI)**0.65 * 12 * width
            outer << [
              80 + Math.cos(angle) * (radius + half),
              80 + Math.sin(angle) * (radius + half)
            ]
            inner << [
              80 + Math.cos(angle) * (radius - half),
              80 + Math.sin(angle) * (radius - half)
            ]
          end
          color = width == 0.30 ? Color.new(255, 249, 230, alpha) :
                                  Color.new(*rgb, alpha)
          polygon(wheel, outer + inner.reverse, color)
        end
      end

      # White central star.
      polygon(
        wheel,
        [[80, 57], [85, 75], [103, 80], [85, 85],
         [80, 103], [75, 85], [57, 80], [75, 75]],
        Color.new(255, 246, 220, 245)
      )

      ring = Bitmap.new(160, 160)
      bitmaps << ring
      240.times do |i|
        angle = i * Math::PI / 120
        ring.fill_rect(
          (80 + Math.cos(angle) * 65).round,
          (80 + Math.sin(angle) * 65).round,
          3, 3, Color.new(255, 233, 192, 220)
        )
      end

      burst = Bitmap.new(144, 144)
      bitmaps << burst
      points = Array.new(24) do |i|
        angle = i * Math::PI / 12
        radius = i.even? ? 61 : 18
        [72 + Math.cos(angle) * radius, 72 + Math.sin(angle) * radius]
      end
      [[1.0, [255, 195, 112, 180]],
       [0.70, [255, 231, 181, 240]],
       [0.35, [255, 255, 245, 255]]].each do |scale, rgba|
        polygon(
          burst,
          points.map { |x, y| [72 + (x - 72) * scale, 72 + (y - 72) * scale] },
          Color.new(*rgba)
        )
      end

      COLORS.each do |rgb|
        mote = Bitmap.new(16, 16)
        bitmaps << mote
        polygon(
          mote,
          [[8, 0], [11, 5], [15, 8], [11, 11],
           [8, 15], [5, 11], [0, 8], [5, 5]],
          Color.new(*rgb, 245)
        )
        mote.fill_rect(6, 6, 4, 4, Color.new(255, 255, 240, 255))
      end
      return bitmaps
    rescue
      bitmaps.each { |b| b.dispose unless b.disposed? }
      raise
    end
  end

  CUES = [
    [0.04, ["PRSFX- Charge", "PRSFX- Psybeam1"], 55, 120],
    [0.29, ["PRSFX- Rapid Spin", "PRSFX- Swift"], 70, 115],
    [0.57, ["PRSFX- Tri Attack", "PRSFX- Body Slam"], 85, 105]
  ]

  def self.sound(cue)
    cue[1].each do |name|
      next unless [".wav", ".ogg", ".mp3"].any? do |extension|
        File.file?("Audio/SE/Anim/#{name}#{extension}")
      end
      pbSEPlay("Anim/#{name}", cue[2], cue[3])
      break
    end
  end

  module SceneHooks
    def pbAnimation(moveID, user, targets, hitNum = 0)
      return super unless moveID == :CHAOSWHEEL
      return if @battle && !@battle.showAnims
      return if @chaos_wheel_boxes

      source = user && user.respond_to?(:index) &&
               @sprites && @sprites["pokemon_#{user.index}"]
      return super unless pbChaosWheelValidSprite(source)
      return if user.respond_to?(:isCommander?) && user.isCommander?

      entries = (targets.is_a?(Array) ? targets : [targets]).compact
      entries = entries.select { |b| b.respond_to?(:index) }
      return super if entries.empty?

      entries = entries.uniq { |b| b.index }.select do |b|
        sprite = @sprites["pokemon_#{b.index}"]
        pbChaosWheelValidSprite(sprite) &&
          sprite.visible && sprite.opacity > 0 &&
          !(b.respond_to?(:isCommander?) && b.isCommander?) &&
          !(sprite.respond_to?(:vanishMode) && sprite.vanishMode > 0)
      end
      return if entries.empty?
      pbChaosWheelVisual(source, entries)
    end

    def pbChaosWheelValidSprite(sprite)
      return sprite && !sprite.disposed? &&
        sprite.bitmap && !sprite.bitmap.disposed? &&
        sprite.src_rect.width > 0 && sprite.src_rect.height > 0
    end

    def pbChaosWheelCenter(sprite)
      return [
        sprite.x + (sprite.src_rect.width / 2.0 - sprite.ox) * sprite.zoom_x,
        sprite.y + (sprite.src_rect.height / 2.0 - sprite.oy) * sprite.zoom_y
      ]
    end

    def pbChaosWheelHideHP
      return unless @chaos_wheel_boxes && @sprites
      @sprites.each do |key, sprite|
        next unless key.to_s.start_with?("dataBox_") &&
                    sprite && !sprite.disposed?
        @chaos_wheel_boxes[sprite.object_id] ||= [sprite, sprite.visible]
        sprite.visible = false
      end
    end

    def pbGraphicsUpdate
      pbChaosWheelHideHP if @chaos_wheel_boxes
      super
    end

    def pbChaosWheelVisual(source, targets)
      sprites, bitmaps = [], []
      @chaos_wheel_boxes = {}
      begin
        @briefMessage = false
        pbChaosWheelHideHP
        bitmaps.concat(ChaosWheelVisual.assets)
        wheel_b, ring_b, burst_b = bitmaps[0, 3]
        particle_bitmaps = bitmaps[3, 3]

        make = proc do |bitmap, z|
          sprite = Sprite.new(@viewport)
          sprites << sprite
          sprite.bitmap = bitmap
          sprite.ox = bitmap.width / 2
          sprite.oy = bitmap.height / 2
          sprite.z = z
          sprite.opacity = 0
          sprite
        end

        ux, uy = pbChaosWheelCenter(source)
        groups = targets.map do |b|
          tx, ty = pbChaosWheelCenter(@sprites["pokemon_#{b.index}"])
          {
            :tx => tx, :ty => ty,
            :direction => tx >= ux ? 1 : -1,
            :wheel => make.call(wheel_b, 20_025),
            :echoes => Array.new(3) { make.call(wheel_b, 20_022) },
            :burst => make.call(burst_b, 20_030),
            :ring => make.call(ring_b, 20_028),
            :particles => Array.new(36) do |i|
              make.call(particle_bitmaps[i % 3], 20_032)
            end
          }
        end

        frames = [(Graphics.frame_rate * ChaosWheelVisual::DURATION).round, 2].max
        cue_index = 0

        frames.times do |frame|
          t = frame.to_f / (frames - 1)
          while cue_index < ChaosWheelVisual::CUES.size &&
                t >= ChaosWheelVisual::CUES[cue_index][0]
            ChaosWheelVisual.sound(ChaosWheelVisual::CUES[cue_index])
            cue_index += 1
          end

          groups.each do |g|
            direction = g[:direction]
            start_x = ux + direction * 38
            start_y = uy - 8
            travel = ChaosWheelVisual.clamp((t - 0.28) / 0.29)
            # Accelerate toward the target.
            progress = travel * travel
            wx = start_x + (g[:tx] - start_x) * progress
            wy = start_y + (g[:ty] - start_y) * progress -
                 Math.sin(travel * Math::PI) * 18

            charge = ChaosWheelVisual.clamp(t / 0.24)
            wheel = g[:wheel]
            wheel.x, wheel.y = wx, wy
            wheel.angle = direction * (t * 1080 + t * t * 720)
            wheel.zoom_x = wheel.zoom_y = 0.25 + charge * 0.65
            wheel.opacity = t < 0.57 ? (charge * 255).round : 0

            g[:echoes].each_with_index do |echo, i|
              delayed = ChaosWheelVisual.clamp(
                (t - 0.28 - (i + 1) * 0.018) / 0.29
              )
              echo.x = start_x + (g[:tx] - start_x) * delayed**2
              echo.y = start_y + (g[:ty] - start_y) * delayed**2 -
                       Math.sin(delayed * Math::PI) * 18
              echo.angle = wheel.angle - direction * (i + 1) * 22
              echo.zoom_x = echo.zoom_y = 0.82 - i * 0.08
              echo.opacity = t >= 0.28 && t < 0.57 ? 70 - i * 18 : 0
            end

            q = (t - 0.57) / 0.34
            impact = ChaosWheelVisual.clamp(q)
            strength = q >= 0 && q <= 1 ? 1 - impact : 0

            burst = g[:burst]
            burst.x, burst.y = g[:tx], g[:ty]
            burst.zoom_x = burst.zoom_y = 0.35 + impact * 1.35
            burst.angle = direction * impact * 35
            burst.opacity = (strength**1.6 * 255).round

            ring = g[:ring]
            ring.x, ring.y = g[:tx], g[:ty]
            ring.zoom_x = ring.zoom_y = 0.20 + impact * 1.55
            ring.opacity = (strength * 205).round

            g[:particles].each_with_index do |particle, i|
              angle = i * 2.399 + impact * direction * 0.8
              radius = 10 + impact * (55 + i % 6 * 15)
              particle.x = g[:tx] + Math.cos(angle) * radius
              particle.y = g[:ty] + Math.sin(angle) * radius * 0.72 +
                           impact**2 * 24
              particle.angle = i * 31 + direction * impact * 180
              particle.zoom_x = particle.zoom_y = 0.35 + i % 4 * 0.13
              particle.opacity = (strength**0.7 * 245).round
            end
          end

          pbChaosWheelHideHP
          pbUpdate
        end
      ensure
        boxes = @chaos_wheel_boxes
        @chaos_wheel_boxes = nil
        boxes.each_value do |sprite, visible|
          sprite.visible = visible unless sprite.disposed?
        end if boxes
        sprites.reverse_each { |sprite| sprite.dispose unless sprite.disposed? }
        bitmaps.each { |bitmap| bitmap.dispose unless bitmap.disposed? }
      end
    end
  end
end

Battle::Scene.prepend(ChaosWheelVisual::SceneHooks)