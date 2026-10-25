#===============================================================================
# KAITO Animation Core v1.0
# Pokemon Essentials v21.1
#
# Install:
# Plugins/[KAITO] MoveAnimationAlias/Animation/000_AnimationCore.rb
#
# Only registered moves use this core.
# Unregistered moves continue through the existing animation system.
#===============================================================================
module KaitoAnimation
  VERSION = "1.0"
  REGISTRY = {}

  # duration:       Animation duration in seconds.
  # hit:            nil = all hitNum values; integer = one specific hitNum.
  # require_target: false for charging/self/field animations without a target.
  # hide_hp:        Temporarily hide battle databoxes.
  # setup:          Called once before the first frame.
  #
  # Update block receives:
  #   animation player, normalized progress (0.0..1.0)
  def self.register(move_id, duration:, hit: nil, require_target: true,
                    hide_hp: true, setup: nil, &update)
    raise ArgumentError, "Animation needs an update block" unless update

    duration = Float(duration)
    unless duration.finite? && duration > 0
      raise ArgumentError, "Invalid duration"
    end

    key = [
      move_id.to_s.upcase.to_sym,
      hit.nil? ? nil : Integer(hit)
    ]

    if REGISTRY.key?(key)
      raise ArgumentError, "Animation already registered: #{key.inspect}"
    end

    REGISTRY[key] = {
      duration: duration,
      require_target: require_target,
      hide_hp: hide_hp,
      setup: setup,
      update: update
    }
  end

  def self.lookup(move_id, hit)
    id = move_id.to_s.upcase.to_sym
    REGISTRY[[id, hit]] || REGISTRY[[id, nil]]
  end

  def self.valid_sprite?(sprite)
    sprite && !sprite.disposed? &&
      sprite.bitmap && !sprite.bitmap.disposed? &&
      sprite.src_rect.width > 0 && sprite.src_rect.height > 0
  end

  #=============================================================================
  # Animation player
  #=============================================================================
  class Player
    attr_reader :user, :targets, :hit_num, :duration, :seconds, :t

    def initialize(scene, sprites, viewport, user, targets, hit_num, spec)
      @scene = scene
      @scene_sprites = sprites
      @viewport = viewport

      @user = user
      @targets = targets
      @hit_num = hit_num

      @spec = spec
      @duration = spec[:duration]

      @sprites = []
      @bitmaps = []
      @hidden = {}
      @data = {}
      @sounds = []

      @seconds = 0.0
      @t = 0.0
    end

    # Store animation-specific objects and values.
    # Example: animation[:wheel] = sprite
    def [](key)
      @data[key]
    end

    def []=(key, value)
      @data[key] = value
    end

    #===========================================================================
    # Timing and interpolation
    #===========================================================================
    def clamp(value)
      [[value, 0.0].max, 1.0].min
    end

    def lerp(from, to, progress)
      from + (to - from) * clamp(progress)
    end

    # Progress of a timed interval, measured in seconds.
    # Example: progress(0.3, 0.5)
    # Starts at 0.3 seconds and finishes at 0.8 seconds.
    def progress(start, length)
      unless length > 0
        raise ArgumentError, "Interval must be positive"
      end
      clamp((@seconds - start) / length.to_f)
    end

    #===========================================================================
    # Pokemon sprites
    #===========================================================================
    def battler_sprite(battler = @user)
      return nil unless battler && battler.respond_to?(:index)

      sprite = @scene_sprites["pokemon_#{battler.index}"]
      KaitoAnimation.valid_sprite?(sprite) ? sprite : nil
    end

    # Uses the displayed frame, not the full animated sprite sheet.
    def center(battler = @user)
      s = battler_sprite(battler)
      return nil unless s

      [
        s.x + (s.src_rect.width / 2.0 - s.ox) * s.zoom_x,
        s.y + (s.src_rect.height / 2.0 - s.oy) * s.zoom_y
      ]
    end

    #===========================================================================
    # Managed bitmaps and sprites
    #===========================================================================
    def bitmap(width, height)
      b = Bitmap.new(width, height)
      @bitmaps << b
      yield b if block_given?
      b
    end

    # Created sprites are disposed automatically.
    # External bitmaps are NOT disposed automatically.
    # Bitmaps created with bitmap(...) are owned by this player.
    def sprite(bitmap, z: 20_020, centered: true)
      s = Sprite.new(@viewport)
      @sprites << s

      s.bitmap = bitmap
      s.z = z

      if centered
        s.ox = bitmap.width / 2
        s.oy = bitmap.height / 2
      end

      s.opacity = 0
      s
    end

    # Temporarily hide a real sprite and remember its original visibility.
    def hide(sprite)
      return unless sprite && !sprite.disposed?

      @hidden[sprite.object_id] ||= [sprite, sprite.visible]
      sprite.visible = false
    end

    # Make a stationary copy of the currently displayed Pokemon frame.
    # Original scale, origin, angle and mirror are preserved.
    # The original Pokemon is untouched unless hide_original is true.
    #
    # force_visible is useful for an attack emerging from a hidden state.
    # This does NOT change the battler's actual vanishMode.
    def copy(battler = @user, hide_original: false, force_visible: false,
             z: 20_015)
      src = battler_sprite(battler)
      return nil unless src

      b = bitmap(src.src_rect.width, src.src_rect.height)
      b.blt(0, 0, src.bitmap, src.src_rect)

      s = sprite(b, z: z)
      s.x = src.x
      s.y = src.y
      s.ox = src.ox
      s.oy = src.oy
      s.zoom_x = src.zoom_x
      s.zoom_y = src.zoom_y
      s.angle = src.angle
      s.mirror = src.mirror
      s.color = src.color.clone
      s.tone = src.tone.clone
      s.visible = force_visible || src.visible
      s.opacity = force_visible && src.opacity == 0 ? 255 : src.opacity

      hide(src) if hide_original
      s
    end

    #===========================================================================
    # Drawing helpers
    #===========================================================================
    def polygon(b, points, color)
      low, high = points.map { |p| p[1] }.minmax

      (low.floor..high.ceil).each do |y|
        xs = []

        points.each_with_index do |p, i|
          q = points[(i + 1) % points.length]

          next unless (p[1] <= y && q[1] > y) ||
                      (q[1] <= y && p[1] > y)

          xs << p[0] +
            (y - p[1]).to_f * (q[0] - p[0]) / (q[1] - p[1])
        end

        xs.sort.each_slice(2) do |left, right|
          next unless right

          b.fill_rect(
            left.ceil, y,
            [right.floor - left.ceil + 1, 1].max,
            1, color
          )
        end
      end
    end

    # Creates an owned ring bitmap. Call during setup, not every frame.
    def ring(radius, color, thickness = 3)
      radius = Integer(radius)

      unless radius > 0 && thickness > 0
        raise ArgumentError, "Invalid ring"
      end

      size = radius * 2 + 4
      c = radius + 2
      inner = [radius - thickness, 0].max

      bitmap(size, size) do |b|
        size.times do |y|
          size.times do |x|
            d = (x - c)**2 + (y - c)**2

            if d <= radius**2 && d >= inner**2
              b.fill_rect(x, y, 1, 1, color)
            end
          end
        end
      end
    end

    #===========================================================================
    # Optional sound cues
    #===========================================================================
    # Schedule during setup.
    # Paths are relative to Audio/SE/Anim/.
    # An array supplies fallback names, not simultaneous sounds.
    #
    # Example:
    # sound_at(0.4, ["PRSFX- Tackle", "PRSFX- Body Slam"], 80, 100)
    def sound_at(time, names, volume = 75, pitch = 100)
      @sounds << [Float(time), Array(names), volume, pitch]
      @sounds.sort_by! { |cue| cue[0] }
    end

    def play_due_sounds
      while @sounds[0] && @sounds[0][0] <= @seconds
        _, names, volume, pitch = @sounds.shift

        name = names.find do |candidate|
          [".wav", ".ogg", ".mp3"].any? do |ext|
            File.file?("Audio/SE/Anim/#{candidate}#{ext}")
          end
        end

        pbSEPlay("Anim/#{name}", volume, pitch) if name
      end
    end

    #===========================================================================
    # Visibility management
    #===========================================================================
    def maintain_hidden
      if @spec[:hide_hp]
        @scene_sprites.each do |key, s|
          hide(s) if key.to_s.start_with?("dataBox_")
        end
      end

      @hidden.each_value do |s, _|
        s.visible = false unless s.disposed?
      end
    end

    #===========================================================================
    # Playback
    #===========================================================================
    def run
      maintain_hidden
      @spec[:setup].call(self) if @spec[:setup]

      frames = [(@duration * Graphics.frame_rate).round, 2].max

      frames.times do |frame|
        @t = frame.to_f / (frames - 1)
        @seconds = @t * @duration

        @spec[:update].call(self, @t)
        play_due_sounds
        maintain_hidden
        @scene.pbUpdate
      end
    end

    # Restore visibility and clean owned resources, including after errors.
    def dispose
      begin
        @hidden.each_value do |s, visible|
          s.visible = visible unless s.disposed?
        end
      ensure
        begin
          @sprites.reverse_each do |s|
            s.dispose unless s.disposed?
          end
        ensure
          @bitmaps.each do |b|
            b.dispose unless b.disposed?
          end
        end
      end
    end
  end

  #=============================================================================
  # Battle scene integration
  #=============================================================================
  module SceneHooks
    def pbAnimation(move_id, user, targets, hit_num = 0)
      spec = KaitoAnimation.lookup(move_id, hit_num)

      # Preserve the existing animation chain for unregistered moves.
      return super unless spec
      return if @battle && !@battle.showAnims
      return if @kaito_animation_player

      source = user && user.respond_to?(:index) &&
               @sprites && @sprites["pokemon_#{user.index}"]

      return super unless KaitoAnimation.valid_sprite?(source)
      return if user.respond_to?(:isCommander?) && user.isCommander?

      entries = (targets.is_a?(Array) ? targets : [targets]).compact
      entries = entries.select do |b|
        b.respond_to?(:index)
      end.uniq { |b| b.index }

      entries = entries.select do |b|
        s = @sprites["pokemon_#{b.index}"]

        KaitoAnimation.valid_sprite?(s) &&
          s.visible && s.opacity > 0 &&
          !(b.respond_to?(:isCommander?) && b.isCommander?) &&
          !(s.respond_to?(:vanishMode) && s.vanishMode > 0)
      end

      return if spec[:require_target] && entries.empty?

      player = KaitoAnimation::Player.new(
        self, @sprites, @viewport, user, entries, hit_num, spec
      )

      @kaito_animation_player = player

      begin
        @briefMessage = false
        player.run
      ensure
        @kaito_animation_player = nil
        player.dispose
      end
    end

    def pbGraphicsUpdate
      if @kaito_animation_player
        @kaito_animation_player.maintain_hidden
      end
      super
    end
  end
end

unless Battle::Scene.ancestors.include?(KaitoAnimation::SceneHooks)
  Battle::Scene.prepend(KaitoAnimation::SceneHooks)
end