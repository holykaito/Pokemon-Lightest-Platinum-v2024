# Procedural RGSS animation: no external graphics, audio or animation data.
module GloomMoonlightVisual
  DURATION = 2.8
  # Add a different move ID here if necessary.
  MOVE_IDS = [:MOONYNIGHT, :GLOOMMOONLIGHT]

  def self.ellipse(bitmap, cx, cy, rx, ry, color)
    (-ry..ry).each do |dy|
      half = (rx * Math.sqrt([1.0 - dy * dy.to_f / (ry * ry), 0].max)).floor
      bitmap.fill_rect(cx - half, cy + dy, half * 2 + 1, 1, color)
    end
  end

  def self.moon
    b = Bitmap.new(192, 192)
    32.downto(1) do |i|
      ellipse(b, 96, 96, 54 + i, 54 + i, Color.new(99, 60, 157, 3))
    end
    ellipse(b, 96, 96, 54, 54, Color.new(104, 91, 146))
    ellipse(b, 93, 92, 50, 50, Color.new(171, 164, 198))
    ellipse(b, 88, 85, 43, 43, Color.new(194, 189, 216))
    [[75, 70, 11], [111, 76, 7], [89, 111, 14], [117, 112, 8],
     [67, 99, 6], [96, 52, 5], [112, 97, 4]].each do |x, y, r|
      ellipse(b, x, y, r, r, Color.new(124, 117, 160, 160))
      ellipse(b, x - 2, y - 2, [r - 3, 1].max, [r - 3, 1].max,
              Color.new(155, 147, 181, 130))
    end
    b
  end

  def self.cloud
    b = Bitmap.new(384, 112)
    10.downto(1) do |i|
      [[70, 66, 54, 12], [130, 49, 67, 23], [207, 62, 82, 18],
       [285, 70, 65, 11]].each do |x, y, rx, ry|
        ellipse(b, x, y, rx + i * 2, ry + i, Color.new(23, 16, 42, 8))
      end
    end
    b
  end

  module SceneHooks
    def pbAnimation(moveID, user, targets, hitNum = 0)
      weather_move = GloomMoonlightVisual::MOVE_IDS.include?(moveID)
      if !weather_move && GameData::Move.exists?(moveID)
        weather_move = (GameData::Move.get(moveID).function_code == "StartGloomMoonlightWeather")
      end
      return super unless weather_move
      return if @battle && !@battle.showAnims
      pbGloomMoonlightVisual
    end

    def pbCommonAnimation(animName, user = nil, target = nil)
      return super unless animName.to_s.downcase == "gloommoon"
      return if @battle && !@battle.showAnims
      pbGloomMoonlightVisual
    end

    def pbGloomMoonlightVisual
      sprites = []
      bitmaps = []
      viewport = nil
      begin
        @briefMessage = false
        # Independent overlay: never changes battle sprites, tones or weather.
        viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
        viewport.z = (@viewport && !@viewport.disposed?) ? @viewport.z + 1 : 100_000
        shade = Sprite.new(viewport)
        sprites << shade
        shade.bitmap = Bitmap.new(Graphics.width, Graphics.height)
        bitmaps << shade.bitmap
        shade.bitmap.fill_rect(0, 0, Graphics.width, Graphics.height,
                               Color.new(12, 6, 28))
        moon = Sprite.new(viewport)
        sprites << moon
        moon.bitmap = GloomMoonlightVisual.moon
        bitmaps << moon.bitmap
        moon.ox = moon.oy = 96
        moon.x = Graphics.width / 2
        moon.z = 1
        cloud_bitmap = GloomMoonlightVisual.cloud
        bitmaps << cloud_bitmap
        clouds = []
        6.times do |i|
          s = Sprite.new(viewport)
          sprites << s
          s.bitmap = cloud_bitmap
          s.z = 2
          s.zoom_x = (Graphics.width / 512.0) * (i < 3 ? 1.2 : 1.7)
          s.zoom_y = i < 3 ? 0.8 : 1.1
          clouds << s
        end
        # Frame count follows the configured RGSS frame rate.
        frames = [(Graphics.frame_rate * GloomMoonlightVisual::DURATION).round, 1].max
        frames.times do |f|
          t = f.to_f / [frames - 1, 1].max
          fade = [[t / 0.2, (1.0 - t) / 0.24, 1.0].min, 0.0].max
          shade.opacity = (fade * 180).round
          moon.opacity = (fade * 255).round
          moon.y = Graphics.height * 0.29 + (1.0 - [t / 0.35, 1].min) * 25
          pulse = 1.0 + 0.035 * Math.sin(t * Math::PI * 4)
          moon.zoom_x = moon.zoom_y = pulse * Graphics.height / 384.0
          clouds.each_with_index do |s, i|
            direction = i.even? ? 1 : -1
            s.x = ((i % 3) * Graphics.width / 2.0) - 230 + direction * t * 110
            s.y = Graphics.height * (i < 3 ? 0.16 : 0.47) + (i % 3) * 16
            s.opacity = (fade * (i < 3 ? 195 : 160)).round
          end
          pbUpdate
        end
      ensure
        sprites.reverse_each { |s| s.dispose if s && !s.disposed? }
        bitmaps.each { |b| b.dispose if b && !b.disposed? }
        viewport.dispose if viewport && !viewport.disposed?
      end
    end
  end
end
Battle::Scene.prepend(GloomMoonlightVisual::SceneHooks)
