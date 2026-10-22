#===============================================================================
# Allergies status animation upgrade.
# Append to MAG_Brittle_Drenched_Allergies_Animations.rb.
# Uses the existing assets and HP visibility helpers in that file.
#===============================================================================
module KaitoAllergiesStatus
  DURATION = 0.85

  def self.clamp(x)
    [[x, 0.0].max, 1.0].min
  end

  module SceneHooks
    def pbMAGBrittleDrenchedAllergiesVisual(source, kind)
      return super unless kind == :allergies

      sprites, bitmaps = [], []
      @mag_brittle_drenched_allergies_boxes = {}

      begin
        @briefMessage = false
        pbMAGBrittleDrenchedAllergiesVisualHideHP

        bitmaps.concat(
          MAGBrittleDrenchedAllergiesVisual.assets(:allergies)
        )
        pollen_b, cloud_b, gust_b, grain_b = bitmaps

        scale = [Graphics.width / 512.0,
                 Graphics.height / 384.0].min

        make = proc do |b, ox, oy, z|
          s = Sprite.new(@viewport)
          sprites << s
          s.bitmap, s.ox, s.oy, s.z = b, ox, oy, z
          s.opacity = 0
          s
        end

        cx = source.x +
             (source.src_rect.width / 2.0 - source.ox) * source.zoom_x
        foot = source.y +
               (source.src_rect.height - source.oy) * source.zoom_y

        height = [[source.src_rect.height * source.zoom_y,
                   64 * scale].max, 180 * scale].min
        radius = [[source.src_rect.width * source.zoom_x * 0.43,
                   30 * scale].max, 66 * scale].min

        head = foot - height * 0.76
        direction = cx < Graphics.width / 2.0 ? 1 : -1
        z = source.z

        pollen = Array.new(24) do
          make.call(pollen_b, 14, 14, z + 4)
        end
        clouds = Array.new(5) do
          make.call(cloud_b, 24, 24, z + 2)
        end
        gusts = Array.new(6) do
          s = make.call(gust_b, 32, 20, z + 8)
          s.mirror = direction < 0
          s
        end
        puffs = Array.new(2) do
          make.call(cloud_b, 24, 24, z + 7)
        end
        grains = Array.new(28) do
          make.call(grain_b, 7, 9, z + 9)
        end

        MAGBrittleDrenchedAllergiesVisual.play_se(:allergies)

        frames = [(Graphics.frame_rate *
                   KaitoAllergiesStatus::DURATION).round, 2].max

        frames.times do |f|
          t = f.to_f / (frames - 1)
          fade = KaitoAllergiesStatus.clamp(
            [t / 0.12, (1 - t) / 0.20].min
          )

          # Pollen gathers around the upper body.
          # After the first sneeze it loosens and drifts away.
          scatter = KaitoAllergiesStatus.clamp((t - 0.30) / 0.70)

          pollen.each_with_index do |s, i|
            a = i * 2.399 + t * 4.0
            r = radius * (0.65 + scatter * 0.55)

            s.x = cx + Math.cos(a) * r +
                  direction * scatter * 13 * scale
            s.y = head + height * 0.16 +
                  Math.sin(a) * height * 0.25 -
                  scatter * 14 * scale

            s.zoom_x = s.zoom_y =
              (0.34 + i % 4 * 0.085) * scale
            s.angle = i * 29 + t * 150
            s.z = Math.sin(a) > 0 ? z + 4 : z - 1
            s.opacity = (fade * (210 - scatter * 65)).round
          end

          # A localized dust haze, without covering the whole battlefield.
          clouds.each_with_index do |s, i|
            a = i * 2.399 + t * 1.5

            s.x = cx + Math.cos(a) * radius * 0.65
            s.y = head + height * 0.13 +
                  Math.sin(a) * height * 0.17 -
                  scatter * 10 * scale

            s.zoom_x = (1.05 + scatter * 0.35) * scale
            s.zoom_y = (0.65 + scatter * 0.20) * scale
            s.opacity = (fade * 140).round
          end

          # Two short outward puffs clearly read as sneezing.
          puffs.each_with_index do |s, i|
            start = i == 0 ? 0.30 : 0.61
            p = (t - start) / 0.25
            s.visible = p >= 0 && p <= 1
            next unless s.visible

            s.x = cx + direction *
                  (radius * 0.28 + p * 57 * scale)
            s.y = head + 12 * scale - p * 7 * scale
            s.zoom_x = (0.60 + p * 1.25) * scale
            s.zoom_y = (0.40 + p * 0.65) * scale
            s.opacity = (Math.sin(p * Math::PI) * 200).round
          end

          # Three curved gust strokes accompany each sneeze.
          gusts.each_with_index do |s, i|
            burst = i / 3
            row = i % 3
            start = burst == 0 ? 0.30 : 0.61
            p = (t - start - row * 0.012) / 0.21
            s.visible = p >= 0 && p <= 1
            next unless s.visible

            s.x = cx + direction *
                  (radius * 0.25 + p * 69 * scale)
            s.y = head + 12 * scale +
                  (row - 1) * (9 + p * 7) * scale

            s.zoom_x = (0.58 + p * 0.40) * scale
            s.zoom_y = (0.43 + p * 0.16) * scale
            s.angle = direction * (row - 1) * 12
            s.opacity = (Math.sin(p * Math::PI) * 245).round
          end

          # Solid pollen flecks fly outward, then fall and disappear.
          grains.each_with_index do |s, i|
            burst = i / 14
            n = i % 14
            start = burst == 0 ? 0.30 : 0.61
            p = (t - start) / 0.28
            s.visible = p >= 0 && p <= 1
            next unless s.visible

            vx = direction * (34 + n % 5 * 14) * scale
            vy = (n - 6.5) * 5 * scale

            s.x = cx + direction * radius * 0.28 + vx * p
            s.y = head + 12 * scale + vy * p +
                  p * p * 22 * scale

            s.zoom_x = s.zoom_y =
              (0.34 + n % 3 * 0.11) * scale
            s.angle = n * 27 + direction * p * 170
            s.opacity = ((1 - p) * 245).round
          end

          pbUpdate
        end
      ensure
        boxes = @mag_brittle_drenched_allergies_boxes
        @mag_brittle_drenched_allergies_boxes = nil

        if boxes
          boxes.each_value do |s, visible|
            s.visible = visible if s && !s.disposed?
          end
        end

        sprites.reverse_each { |s| s.dispose unless s.disposed? }
        bitmaps.each { |b| b.dispose unless b.disposed? }
      end
    end
  end
end

unless Battle::Scene.ancestors.include?(KaitoAllergiesStatus::SceneHooks)
  Battle::Scene.prepend(KaitoAllergiesStatus::SceneHooks)
end