#===============================================================================
# Fish Harpoon - Pokemon Essentials v21.1
# Custom animation for FISHHARPOON.
# No external graphics. Changes presentation only.
#===============================================================================
module KaitoFishHarpoon
  DURATION = 1.65

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

  def self.line(b, x1, y1, x2, y2, width, color)
    steps = [(x2 - x1).abs.ceil, (y2 - y1).abs.ceil, 1].max
    (0..steps).each do |i|
      p = i.to_f / steps
      x = (x1 + (x2 - x1) * p).round
      y = (y1 + (y2 - y1) * p).round
      b.fill_rect(x - width / 2, y - width / 2,
                  width, width, color)
    end
  end

  def self.polygon(b, points, color)
    low, high = points.map { |p| p[1] }.minmax
    (low..high).each do |y|
      xs = []
      points.each_with_index do |p, i|
        q = points[(i + 1) % points.length]
        next unless (p[1] <= y && q[1] > y) ||
                    (q[1] <= y && p[1] > y)
        xs << p[0] + (y - p[1]).to_f *
              (q[0] - p[0]) / (q[1] - p[1])
      end
      xs.sort.each_slice(2) do |left, right|
        next unless right
        x1, x2 = left.ceil, right.floor
        b.fill_rect(x1, y, x2 - x1 + 1, 1, color) if x2 >= x1
      end
    end
  end

  def self.assets
    owned = []
    begin
      # Sharp water harpoon pointing right.
      spear = Bitmap.new(208, 80)
      owned << spear

      polygon(spear, [
        [9, 37], [103, 27], [132, 9], [128, 27],
        [197, 40], [128, 53], [132, 71], [103, 53], [9, 43]
      ], Color.new(28, 113, 193, 225))

      polygon(spear, [
        [17, 38], [110, 31], [125, 19], [121, 33],
        [191, 40], [121, 47], [125, 60], [110, 48], [17, 42]
      ], Color.new(79, 210, 247, 245))

      polygon(spear, [
        [42, 39], [117, 35], [188, 40],
        [117, 43], [42, 41]
      ], Color.new(222, 255, 255, 255))

      line(spear, 109, 32, 127, 17, 2,
           Color.new(185, 248, 255, 245))
      line(spear, 109, 48, 127, 63, 2,
           Color.new(185, 248, 255, 245))

      # Long tapered water trail.
      trail = Bitmap.new(144, 32)
      owned << trail
      140.times do |x|
        p = x / 139.0
        half = [1, (p * 10).round].max
        trail.fill_rect(x, 16 - half, 1, half * 2,
                        Color.new(49, 173, 237, (p * 150).round))
        trail.fill_rect(x, 15, 1, 3,
                        Color.new(196, 252, 255, (p * 235).round))
      end

      ring = Bitmap.new(128, 128)
      owned << ring
      [48, 54].each do |r|
        240.times do |i|
          next if r == 54 && i % 40 > 28
          a = i * Math::PI / 120
          disc(ring, 64 + Math.cos(a) * r,
               64 + Math.sin(a) * r, 1,
               Color.new(170, 242, 255, r == 48 ? 230 : 140))
        end
      end

      drop = Bitmap.new(16, 24)
      owned << drop
      disc(drop, 8, 15, 6, Color.new(44, 153, 226, 230))
      disc(drop, 7, 13, 4, Color.new(149, 231, 255, 245))
      disc(drop, 6, 11, 2, Color.new(236, 255, 255, 255))
      drop.fill_rect(7, 3, 2, 8, Color.new(185, 246, 255, 225))

      flash = Bitmap.new(160, 160)
      owned << flash
      24.downto(1) do |r|
        disc(flash, 80, 80, r + 8,
             Color.new(94, 218, 255, 5))
      end
      10.times do |i|
        a = i * Math::PI / 5
        length = i.even? ? 68 : 41
        line(flash, 80, 80,
             80 + Math.cos(a) * length,
             80 + Math.sin(a) * length,
             i.even? ? 3 : 2, Color.new(202, 252, 255, 235))
      end
      disc(flash, 80, 80, 10, Color.new(246, 255, 255, 255))
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
      return super unless moveID == :FISHHARPOON
      return if @battle && !@battle.showAnims
      return if @fish_harpoon_boxes

      target = targets.is_a?(Array) ? targets.compact.first : targets
      return super unless user && target && @sprites && @viewport

      attacker = @sprites["pokemon_#{user.index}"]
      defender = @sprites["pokemon_#{target.index}"]
      valid = [attacker, defender].all? do |s|
        s && !s.disposed? && s.bitmap && !s.bitmap.disposed?
      end
      return super unless valid

      pbKaitoFishHarpoon(user, attacker, defender)
    end

    def pbFishHarpoonHideBoxes
      return unless @fish_harpoon_boxes
      @sprites.each do |key, s|
        next unless key.to_s.start_with?("dataBox_")
        next unless s && !s.disposed?
        @fish_harpoon_boxes[s.object_id] ||= [s, s.visible]
        s.visible = false
      end
    end

    def pbGraphicsUpdate
      pbFishHarpoonHideBoxes if @fish_harpoon_boxes
      super
    end

    def pbKaitoFishHarpoon(user, attacker, defender)
      objects, bitmaps = [], []
      substitute = false
      @fish_harpoon_boxes = {}

      begin
        @briefMessage = false
        pbFishHarpoonHideBoxes

        if respond_to?(:pbAnimateSubstitute, true)
          substitute = true
          pbAnimateSubstitute(user.index, :hide)
          attacker = @sprites["pokemon_#{user.index}"]
        end

        return unless attacker && !attacker.disposed? && attacker.bitmap

        bitmaps.concat(KaitoFishHarpoon.assets)
        spear_b, trail_b, ring_b, drop_b, flash_b = bitmaps
        scale = [Graphics.width / 512.0,
                 Graphics.height / 384.0].min
        z = [attacker.z, defender.z].max + 100

        make = proc do |b, ox, oy, layer, blend|
          s = Sprite.new(@viewport)
          objects << s
          s.bitmap, s.ox, s.oy = b, ox, oy
          s.z, s.blend_type = layer, blend
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

        dx, dy = tx - sx, ty - sy
        distance = [Math.sqrt(dx * dx + dy * dy), 1].max
        ux, uy = dx / distance, dy / distance
        angle = -Math.atan2(dy, dx) * 180 / Math::PI

        spear = make.call(spear_b, 193, 40, z + 5, 0)
        spear.angle = angle

        trails = Array.new(4) do
          s = make.call(trail_b, 140, 16, z + 2, 1)
          s.angle = angle
          s
        end
        rings = Array.new(4) do
          make.call(ring_b, 64, 64, z + 7, 1)
        end
        droplets = Array.new(28) do
          make.call(drop_b, 8, 15, z + 9, 0)
        end
        motes = Array.new(18) do
          make.call(drop_b, 8, 15, z + 3, 1)
        end
        flash = make.call(flash_b, 80, 80, z + 12, 1)
        flash.x, flash.y = tx, ty

        frames = [(Graphics.frame_rate *
                   KaitoFishHarpoon::DURATION).round, 2].max
        launched = false
        impacted = false

        KaitoFishHarpoon.sound(
          ["PRSFX- Whirlpool1", "PRSFX- Aqua Ring"], 60, 115
        )

        frames.times do |f|
          t = f.to_f / (frames - 1)

          unless launched
            if t >= 0.34
              KaitoFishHarpoon.sound(
                ["PRSFX- Aqua Jet", "PRSFX- Horn Attack"], 85, 110
              )
              launched = true
            end
          end
          unless impacted
            if t >= 0.56
              KaitoFishHarpoon.sound(
                ["PRSFX- Megahorn", "PRSFX- Dive3",
                 "PRSFX- Horn Attack"], 90, 105
              )
              impacted = true
            end
          end

          # Water gathers tightly near the user.
          charge = KaitoFishHarpoon.clamp(t / 0.34)
          motes.each_with_index do |s, i|
            s.visible = t < 0.35
            next unless s.visible
            a = i * 2.399 + charge * 5
            r = (1 - charge) * (35 + i % 4 * 10) * scale
            s.x = sx + Math.cos(a) * r
            s.y = sy + Math.sin(a) * r * 0.70
            s.zoom_x = s.zoom_y = (0.18 + i % 3 * 0.09) * scale
            s.angle = -a * 180 / Math::PI
            s.opacity = (Math.sin(charge * Math::PI) * 230).round
          end

          # The spear grows, accelerates, then continues through the impact.
          form = KaitoFishHarpoon.clamp((t - 0.13) / 0.21)
          if t < 0.34
            head_x = sx + ux * form * 52 * scale
            head_y = sy + uy * form * 52 * scale
          elsif t < 0.56
            p = KaitoFishHarpoon.clamp((t - 0.34) / 0.22)
            p = p * p
            start_x = sx + ux * 52 * scale
            start_y = sy + uy * 52 * scale
            head_x = start_x + (tx - start_x) * p
            head_y = start_y + (ty - start_y) * p
          else
            p = KaitoFishHarpoon.clamp((t - 0.56) / 0.18)
            head_x = tx + ux * p * 150 * scale
            head_y = ty + uy * p * 150 * scale
          end

          dissolve = KaitoFishHarpoon.clamp((t - 0.60) / 0.16)
          spear.x, spear.y = head_x, head_y
          spear.zoom_x = (0.25 + form * 0.85) * scale
          spear.zoom_y = (0.20 + form * 0.80) * scale
          spear.opacity = (form * (1 - dissolve) * 255).round

          trails.each_with_index do |s, i|
            s.x = head_x - ux * i * 22 * scale
            s.y = head_y - uy * i * 22 * scale
            s.zoom_x = (0.80 + i * 0.17) * scale
            s.zoom_y = (0.70 - i * 0.12) * scale
            s.opacity = t >= 0.34 ?
              ((1 - dissolve) * (195 - i * 35)).round : 0
          end

          rings.each_with_index do |s, i|
            if i < 2
              p = (t - i * 0.09) / 0.34
              s.visible = p >= 0 && p <= 1
              next unless s.visible
              s.x, s.y = sx, sy
              s.zoom_x = (0.85 - p * 0.60) * scale
              s.zoom_y = s.zoom_x * 0.65
              s.angle = angle + 90
              s.opacity = (Math.sin(p * Math::PI) * 210).round
            else
              p = (t - 0.56 - (i - 2) * 0.045) / 0.32
              s.visible = p >= 0 && p <= 1
              next unless s.visible
              s.x, s.y = tx, ty
              s.zoom_x = (0.25 + p * 1.50) * scale
              s.zoom_y = s.zoom_x * 0.65
              s.angle = angle + 90
              s.opacity = ((1 - p) * 230).round
            end
          end

          impact = (t - 0.56) / 0.27
          flash.visible = impact >= 0 && impact <= 1
          if flash.visible
            flash.zoom_x = (0.40 + impact * 1.10) * scale
            flash.zoom_y = (0.40 + impact * 0.85) * scale
            flash.angle = angle
            flash.opacity = ((1 - impact) ** 2 * 255).round
          end

          droplets.each_with_index do |s, i|
            p = (t - 0.56 - (i % 3) * 0.012) / 0.36
            s.visible = p >= 0 && p <= 1
            next unless s.visible

            a = i * 2.399
            speed = (45 + i % 6 * 13) * scale
            vx = Math.cos(a) * speed + ux * 55 * scale
            vy = Math.sin(a) * speed * 0.75 + uy * 30 * scale

            s.x = tx + vx * p
            s.y = ty + vy * p + p * p * 42 * scale
            s.zoom_x = (0.30 + i % 4 * 0.12) * scale
            s.zoom_y = s.zoom_x * (1.8 - p * 0.5)
            s.angle = Math.atan2(vx, -(vy + 84 * p * scale)) *
                      180 / Math::PI
            s.opacity = ((1 - p) * 245).round
          end

          pbUpdate
        end
      ensure
        begin
          objects.reverse_each { |s| s.dispose unless s.disposed? }
          bitmaps.each { |b| b.dispose unless b.disposed? }
          pbAnimateSubstitute(user.index, :show) if substitute
        ensure
          boxes = @fish_harpoon_boxes
          @fish_harpoon_boxes = nil
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

unless Battle::Scene.ancestors.include?(KaitoFishHarpoon::SceneHooks)
  Battle::Scene.prepend(KaitoFishHarpoon::SceneHooks)
end