# Shadow Fangs animation - Pokemon Essentials v21.1
# Put this file in an existing plugin folder and recompile plugins.
# Procedural graphics only. No external image, audio or PBS edit required.
module ShadowFangsVisual
  MOVE_IDS = [:SHADOWFANGS, :SHADOWFANG]
  DURATION = 2.0

  def self.polygon(b, points, color)
    low, high = points.map { |p| p[1] }.minmax
    (low..high).each do |y|
      xs = []
      points.each_with_index do |p, i|
        q = points[(i + 1) % points.length]
        next unless (p[1] <= y && q[1] > y) || (q[1] <= y && p[1] > y)
        xs << p[0] + (y - p[1]).to_f * (q[0] - p[0]) / (q[1] - p[1])
      end
      xs.sort.each_slice(2) do |left, right|
        next unless right
        b.fill_rect(left.ceil, y, [right.floor - left.ceil + 1, 1].max, 1, color)
      end
    end
  end

  def self.disc(b, cx, cy, r, color)
    (-r..r).each do |dy|
      half = Math.sqrt([r * r - dy * dy, 0].max).floor
      b.fill_rect(cx - half, cy + dy, half * 2 + 1, 1, color)
    end
  end

  def self.jaw
    b = Bitmap.new(240, 120)
    polygon(b, [[15, 32], [39, 10], [77, 14], [120, 5], [164, 14],
                [201, 10], [225, 32], [198, 45], [120, 33], [42, 45]],
            Color.new(55, 24, 83, 220))
    # Long outer canines frame four smaller teeth.
    [[34, 40, 59], [69, 34, 39], [103, 32, 31],
     [137, 32, 31], [171, 34, 39], [206, 40, 59]].each do |x, y, length|
      polygon(b, [[x - 20, y - 5], [x + 21, y - 5], [x + 10, y + 24],
                  [x - 1, y + length + 7], [x - 15, y + 19]], Color.new(124, 55, 202, 100))
      polygon(b, [[x - 16, y], [x + 16, y], [x + 7, y + 22],
                  [x - 1, y + length], [x - 11, y + 16]], Color.new(18, 10, 34, 255))
      polygon(b, [[x - 11, y + 3], [x + 11, y + 3], [x + 3, y + 22],
                  [x - 1, y + length - 8], [x - 7, y + 16]], Color.new(177, 137, 225, 255))
      polygon(b, [[x - 8, y + 5], [x + 4, y + 5], [x - 2, y + length - 12]],
              Color.new(239, 225, 255, 255))
    end
    b
  end

  def self.mist
    b = Bitmap.new(192, 192)
    30.downto(1) do |i|
      disc(b, 96, 96, i * 2 + 10, Color.new(76, 31, 114, 4))
    end
    b
  end

  def self.spark
    b = Bitmap.new(24, 24)
    polygon(b, [[12, 0], [16, 9], [24, 12], [15, 15], [12, 24], [9, 15], [0, 12], [9, 9]],
            Color.new(157, 88, 225, 220))
    polygon(b, [[12, 5], [14, 11], [18, 12], [13, 14], [12, 19], [10, 13], [6, 12], [11, 10]],
            Color.new(235, 203, 255, 245))
    b
  end

  def self.slash
    b = Bitmap.new(192, 192)
    [[38, 151, 137, 24], [68, 168, 166, 41]].each do |x1, y1, x2, y2|
      polygon(b, [[x1 - 8, y1 + 5], [x2 - 8, y2], [x2 + 8, y2 - 8], [x1 + 7, y1]],
              Color.new(113, 48, 180, 160))
      polygon(b, [[x1, y1], [x2 - 3, y2 + 5], [x2 + 2, y2], [x1 + 2, y1 - 3]],
              Color.new(236, 211, 255, 255))
    end
    b
  end

  module SceneHooks
    def pbAnimation(moveID, user, targets, hitNum = 0)
      return super unless ShadowFangsVisual::MOVE_IDS.include?(moveID)
      return if @battle && !@battle.showAnims
      target = targets.is_a?(Array) ? targets[0] : targets
      defender = target && @sprites["pokemon_#{target.index}"]
      return super unless defender && !defender.disposed? && defender.bitmap
      pbShadowFangsVisual(defender)
    end

    def pbShadowFangsVisual(defender)
      sprites, bitmaps = [], []
      old_x, old_y = defender.x, defender.y
      begin
        @briefMessage = false
        cx = old_x + (defender.src_rect.width / 2.0 - defender.ox) * defender.zoom_x
        cy = old_y + (defender.src_rect.height / 2.0 - defender.oy) * defender.zoom_y
        scale = [[(defender.src_rect.width * defender.zoom_x + 100) / 240.0, 0.7].max, 1.15].min
        shade = Sprite.new(@viewport)
        sprites << shade
        shade.bitmap = Bitmap.new(Graphics.width, Graphics.height)
        bitmaps << shade.bitmap
        shade.bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(12, 5, 26))
        shade.z = 19_990
        jaw_bitmap = ShadowFangsVisual.jaw
        mist_bitmap = ShadowFangsVisual.mist
        spark_bitmap = ShadowFangsVisual.spark
        slash_bitmap = ShadowFangsVisual.slash
        bitmaps.concat([jaw_bitmap, mist_bitmap, spark_bitmap, slash_bitmap])
        clouds = Array.new(5) do
          s = Sprite.new(@viewport)
          sprites << s
          s.bitmap = mist_bitmap
          s.ox = s.oy = 96
          s.z = 20_000
          s
        end
        jaws = Array.new(2) do |i|
          s = Sprite.new(@viewport)
          sprites << s
          s.bitmap = jaw_bitmap
          s.ox, s.oy = 120, 30
          s.zoom_x = s.zoom_y = scale
          s.angle = i == 0 ? 0 : 180
          s.z = 20_010
          s
        end
        motes = Array.new(18) do
          s = Sprite.new(@viewport)
          sprites << s
          s.bitmap = spark_bitmap
          s.ox = s.oy = 12
          s.z = 20_015
          s.blend_type = 1
          s
        end
        slash = Sprite.new(@viewport)
        sprites << slash
        slash.bitmap = slash_bitmap
        slash.ox = slash.oy = 96
        slash.x, slash.y = cx, cy
        slash.z = 20_025
        slash.blend_type = 1
        flash = Sprite.new(@viewport)
        sprites << flash
        flash.bitmap = Bitmap.new(Graphics.width, Graphics.height)
        bitmaps << flash.bitmap
        flash.bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(184, 126, 226))
        flash.z = 20_030
        frames = [(Graphics.frame_rate * ShadowFangsVisual::DURATION).round, 2].max
        frames.times do |f|
          t = f.to_f / (frames - 1)
          fade = [[t / 0.20, (1 - t) / 0.22, 1].min, 0].max
          shade.opacity = (fade * 110).round
          clouds.each_with_index do |s, i|
            a = i * Math::PI * 2 / 5 + t * 2
            r = (t < 0.60 ? 55 * (1 - t / 0.85) : 25 + (t - 0.60) * 95) * scale
            s.x = cx + Math.cos(a) * r
            s.y = cy + Math.sin(a) * r * 0.7
            s.zoom_x = s.zoom_y = scale * (0.7 + i * 0.09)
            s.opacity = (fade * 140).round
          end
          if t < 0.44
            gap = 94 - [t / 0.44, 1].min * 15
          elsif t < 0.60
            p = (t - 0.44) / 0.16
            gap = 79 - p * p * p * 51
          else
            gap = 28 + [((t - 0.67) / 0.20), 0].max * 26
          end
          jaw_alpha = if t < 0.18
                        0
                      elsif t < 0.36
                        (t - 0.18) / 0.18
                      elsif t < 0.67
                        1
                      else
                        [1 - (t - 0.67) / 0.18, 0].max
                      end
          jaws.each_with_index do |s, i|
            s.x = cx
            s.y = cy + (i == 0 ? -1 : 1) * gap * scale
            s.opacity = (jaw_alpha * 255).round
          end
          motes.each_with_index do |s, i|
            a = i * Math::PI * 2 / motes.length + t * 3.6
            if t < 0.60
              r = (110 * (1 - t / 0.64) + (i % 3) * 8) * scale
            else
              r = (18 + (t - 0.60) * (160 + (i % 4) * 35)) * scale
            end
            s.x = cx + Math.cos(a) * r
            s.y = cy + Math.sin(a) * r * 0.8
            s.angle = t * 250 + i * 20
            s.zoom_x = s.zoom_y = 0.20 + (i % 4) * 0.10
            s.opacity = (fade * (130 + (i % 3) * 35)).round
          end
          impact = (t - 0.60) / 0.23
          slash.visible = impact >= 0 && impact <= 1
          slash.opacity = slash.visible ? ((1 - impact) * 255).round : 0
          slash.zoom_x = slash.zoom_y = scale * (0.8 + [impact, 0].max * 0.4)
          flash.opacity = (t >= 0.60 && t < 0.66) ? ((1 - (t - 0.60) / 0.06) * 130).round : 0
          if impact >= 0 && impact <= 1
            defender.x = old_x + Math.sin(impact * Math::PI * 10) * 6 * (1 - impact)
          else
            defender.x = old_x
          end
          pbUpdate
        end
      ensure
        unless defender.disposed?
          defender.x, defender.y = old_x, old_y
        end
        sprites.reverse_each { |s| s.dispose unless s.disposed? }
        bitmaps.each { |b| b.dispose unless b.disposed? }
      end
    end
  end
end
Battle::Scene.prepend(ShadowFangsVisual::SceneHooks)
