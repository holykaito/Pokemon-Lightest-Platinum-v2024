# Mystic Dance - Pokemon Essentials v21.1
# Ancient dragon ritual. Install in an existing plugin folder and recompile.
# Visuals only: the existing move handles its stat changes and Dance effects.
module MysticDanceVisual
  MOVE_ID = :MYSTICDANCE
  DURATION = 2.70

  def self.line(b, x1, y1, x2, y2, width, c)
    steps = [(x2 - x1).abs.round, (y2 - y1).abs.round, 1].max
    (0..steps).each do |i|
      p = i.to_f / steps
      b.fill_rect((x1 + (x2 - x1) * p).round - width / 2,
                  (y1 + (y2 - y1) * p).round - width / 2, width, width, c)
    end
  end

  def self.polygon(b, points, c)
    low, high = points.map { |p| p[1] }.minmax
    (low..high).each do |y|
      xs = []
      points.each_with_index do |p, i|
        q = points[(i + 1) % points.length]
        next unless (p[1] <= y && q[1] > y) || (q[1] <= y && p[1] > y)
        xs << p[0] + (y - p[1]).to_f * (q[0] - p[0]) / (q[1] - p[1])
      end
      xs.sort.each_slice(2) do |l, r|
        b.fill_rect(l.ceil, y, [r.floor - l.ceil + 1, 1].max, 1, c) if r
      end
    end
  end

  def self.disc(b, cx, cy, r, c)
    (-r..r).each do |y|
      x = Math.sqrt([r * r - y * y, 0].max).floor
      b.fill_rect(cx - x, cy + y, x * 2 + 1, 1, c)
    end
  end

  def self.pearl(rgb)
    b = Bitmap.new(64, 64)
    20.downto(1) { |r| disc(b, 32, 32, r + 6, Color.new(rgb[0], rgb[1], rgb[2], 5)) }
    disc(b, 32, 32, 7, Color.new(rgb[0], rgb[1], rgb[2], 190))
    disc(b, 31, 30, 3, Color.new(240, 255, 245, 235))
    b
  end

  def self.seal
    b = Bitmap.new(256, 256)
    c = Color.new(112, 236, 217, 210)
    [84, 96, 111, 116].each do |r|
      360.times do |i|
        next if r == 116 && i % 30 > 18
        a = i * Math::PI / 180
        b.fill_rect((128 + Math.cos(a) * r).round, (128 + Math.sin(a) * r).round, 2, 2, c)
      end
    end
    6.times do |i|
      a, z = i * Math::PI / 3, (i + 2) * Math::PI / 3
      line(b, 128 + Math.cos(a) * 79, 128 + Math.sin(a) * 79,
           128 + Math.cos(z) * 79, 128 + Math.sin(z) * 79, 2, Color.new(192, 176, 247, 180))
    end
    b
  end

  def self.rune
    b = Bitmap.new(32, 40)
    c = Color.new(236, 215, 157, 225)
    [[16, 3, 16, 36], [16, 4, 5, 16], [16, 4, 27, 16],
     [5, 16, 16, 25], [27, 16, 16, 25], [10, 29, 22, 29]].each do |p|
      line(b, p[0], p[1], p[2], p[3], 2, c)
    end
    b
  end

  def self.dragon(rgb)
    b = Bitmap.new(96, 72)
    c = Color.new(rgb[0], rgb[1], rgb[2], 210)
    # Original spectral dragon silhouette, pointed snout and swept horns.
    polygon(b, [[12, 43], [27, 23], [51, 22], [68, 32], [89, 35], [91, 45],
                [68, 48], [55, 59], [30, 57]], c)
    polygon(b, [[26, 28], [15, 2], [45, 23]], c)
    polygon(b, [[42, 23], [40, 4], [59, 25]], c)
    polygon(b, [[23, 49], [4, 63], [35, 54]], c)
    line(b, 58, 33, 70, 36, 3, Color.new(255, 252, 213, 255))
    line(b, 74, 45, 88, 43, 2, Color.new(231, 255, 251, 225))
    b
  end

  module SceneHooks
    def pbAnimation(moveID, user, targets, hitNum = 0)
      return super unless moveID == MysticDanceVisual::MOVE_ID
      return if @battle && !@battle.showAnims
      sprite = user && @sprites["pokemon_#{user.index}"]
      return super unless sprite && !sprite.disposed? && sprite.bitmap
      pbMysticDanceVisual(sprite, user.index)
    end

    def pbMysticDanceVisual(original, user_index)
      sprites, bitmaps = [], []
      was_visible = original.visible
      shadow = @sprites["shadow_#{user_index}"]
      shadow_visible = shadow.visible if shadow
      begin
        @briefMessage = false
        sx, sy = original.x.to_f, original.y.to_f
        cx = sx + (original.src_rect.width / 2.0 - original.ox) * original.zoom_x
        cy = sy + (original.src_rect.height / 2.0 - original.oy) * original.zoom_y
        base_y = sy + (original.src_rect.height - original.oy) * original.zoom_y - 4
        radius = [[original.src_rect.width * original.zoom_x * 0.5 + 30, 67].max, 100].min
        make = proc do |b, ox, oy, z|
          s = Sprite.new(@viewport)
          sprites << s
          s.bitmap = b
          s.ox, s.oy, s.z = ox, oy, z
          s
        end
        shade_b = Bitmap.new(Graphics.width, Graphics.height)
        shade_b.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(13, 9, 33))
        seal_b, rune_b = MysticDanceVisual.seal, MysticDanceVisual.rune
        teal_b, violet_b = MysticDanceVisual.pearl([96, 239, 214]), MysticDanceVisual.pearl([179, 141, 246])
        heads_b = [MysticDanceVisual.dragon([112, 246, 220]), MysticDanceVisual.dragon([187, 157, 255])]
        actor_b = original.bitmap.clone
        bitmaps.concat([shade_b, seal_b, rune_b, teal_b, violet_b, actor_b] + heads_b)
        shade = make.call(shade_b, 0, 0, 19_990)
        seals = Array.new(2) do
          s = make.call(seal_b, 128, 128, 20_000)
          s.blend_type = 1
          s
        end
        actor = make.call(actor_b, original.ox, original.oy, 20_010)
        actor.src_rect.set(original.src_rect.x, original.src_rect.y, original.src_rect.width, original.src_rect.height)
        actor.zoom_x, actor.zoom_y = original.zoom_x, original.zoom_y
        actor.mirror, actor.tone = original.mirror, original.tone.clone
        actor.opacity = original.opacity
        original.visible = false
        shadow.visible = false if shadow
        runes = Array.new(12) do
          s = make.call(rune_b, 16, 20, 20_005)
          s.blend_type = 1
          s
        end
        ribbons = Array.new(2) do |i|
          Array.new(24) do
            s = make.call(i == 0 ? teal_b : violet_b, 32, 32, 20_020)
            s.blend_type = 1
            s
          end
        end
        heads = Array.new(2) do |i|
          s = make.call(heads_b[i], 48, 36, 20_025)
          s.blend_type = 1
          s
        end
        stars = Array.new(16) do
          s = make.call(rune_b, 16, 20, 20_026)
          s.blend_type = 1
          s
        end
        aura = make.call(teal_b, 32, 32, 20_022)
        aura.blend_type = 1
        frames = [(Graphics.frame_rate * MysticDanceVisual::DURATION).round, 2].max
        frames.times do |f|
          t = f.to_f / (frames - 1)
          fade = [[t / 0.16, (1 - t) / 0.18, 1].min, 0].max
          dance = Math.sin(t * Math::PI)
          sway = Math.sin(t * Math::PI * 6)
          actor.x = sx + sway * 15 * dance
          actor.y = sy - Math.sin(t * Math::PI * 6).abs * 10 * dance
          actor.angle = sway * 8 * dance
          actor.color = Color.new(154, 221, 239, (fade * (35 + 25 * Math.sin(t * 28))).round)
          shade.opacity = (fade * 100).round
          seals.each_with_index do |s, i|
            s.x, s.y = cx, base_y - i * 12
            s.zoom_x = radius / 105.0 * (1 + i * 0.14) * (0.85 + 0.15 * [t / 0.2, 1].min)
            s.zoom_y = s.zoom_x * 0.30
            s.angle = Math.sin(t * 4 + i * 2) * 5
            s.opacity = (fade * (i == 0 ? 215 : 95)).round
          end
          runes.each_with_index do |s, i|
            a = i * Math::PI / 6 + t * Math::PI * 1.25
            s.x = cx + Math.cos(a) * radius
            s.y = base_y + Math.sin(a) * radius * 0.30 - 7
            s.zoom_x = s.zoom_y = 0.34 + 0.07 * Math.sin(a)
            s.angle = Math.sin(a) * 14
            s.z = Math.sin(a) > 0 ? 20_015 : 20_004
            s.opacity = (fade * 220).round
          end
          2.times do |i|
            lead = t * Math::PI * 5 + i * Math::PI
            lift = [((t - 0.72) / 0.28), 0].max * 62
            shrink = 1 - [((t - 0.72) / 0.28), 0].max * 0.65
            ribbons[i].each_with_index do |s, j|
              a = lead - j * 0.11
              s.x = cx + Math.cos(a) * radius * shrink
              s.y = cy + Math.sin(a) * 24 - j * 0.65 - lift
              s.z = Math.sin(a) > 0 ? 20_020 : 20_006
              s.zoom_x = s.zoom_y = 0.35 + (1 - j / 24.0) * 0.40
              s.opacity = (fade * (1 - j / 28.0) * 180).round
            end
            s = heads[i]
            s.x = cx + Math.cos(lead) * radius * shrink
            s.y = cy + Math.sin(lead) * 24 - lift
            s.zoom_x = s.zoom_y = 0.50
            s.mirror = Math.sin(lead) > 0
            s.angle = Math.cos(lead) * 12
            s.z = Math.sin(lead) > 0 ? 20_025 : 20_007
            s.opacity = (fade * 215).round
          end
          stars.each_with_index do |s, i|
            a = i * 2.399 + t * 1.5
            s.x = cx + Math.cos(a) * (radius * 0.65 + i % 3 * 13)
            s.y = base_y - ((t * 100 + i * 17) % 135)
            s.zoom_x = s.zoom_y = 0.12 + (i % 3) * 0.04
            s.angle = t * 40 + i * 30
            s.opacity = (fade * (105 + 65 * Math.sin(i + t * 18))).round
          end
          final = (t - 0.76) / 0.24
          aura.x, aura.y = cx, cy
          aura.visible = final >= 0
          aura.zoom_x = aura.zoom_y = 1 + [final, 0].max * 3.0
          aura.opacity = final >= 0 ? (Math.sin(final * Math::PI) * 200).round : 0
          pbUpdate
        end
      ensure
        original.visible = was_visible unless original.disposed?
        shadow.visible = shadow_visible if shadow && !shadow.disposed?
        sprites.reverse_each { |s| s.dispose unless s.disposed? }
        bitmaps.each { |b| b.dispose unless b.disposed? }
      end
    end
  end
end
Battle::Scene.prepend(MysticDanceVisual::SceneHooks)
