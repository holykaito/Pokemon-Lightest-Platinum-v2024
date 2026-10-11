# LP Proximity Water 1.0.0 - Pokemon Essentials 21.1 / mkxp-z.
# Active-page Comment: [Water:Lake,8,70,2]
# Syntax: [Water:filename,outer_radius,max_volume,inner_radius]
# Reserves BGM track 1; enable "BGMTrackCount": 2 in mkxp.json.
module LPWaterSound
  TRACK = 1
  SCAN_INTERVAL = 0.10
  FADE_SECONDS = 0.35
  TAG = /\[Water:([^\]]+)\]/i
  EXTENSIONS = [".ogg", ".wav", ".mp3", ".flac"]

  class << self
    attr_reader :enabled

    def warn_once(key, text)
      @warnings ||= {}
      return if @warnings[key]
      @warnings[key] = true
      message = "[LP Proximity Water] #{text}"
      if defined?(PBDebug) && PBDebug.respond_to?(:log)
        PBDebug.log(message)
      else
        puts message
      end
    end

    def boot
      @enabled = false
      @paused = false
      @path = nil
      @volume = 0.0
      @target = 0.0
      @scan_left = 0.0
      @cache = {}
      @files = {}
      return unless Audio.respond_to?(:bgm_set_volume) && Audio.respond_to?(:bgm_volume)
      # Do not probe a non-existent track: some builds clamp to track 0.
      text = File.binread("mkxp.json").force_encoding("UTF-8")
      # Preserve quoted strings while discarding JSONC comments.
      text = text.gsub(/"(?:\\.|[^"\\])*"|\/\/[^\r\n]*|\/\*.*?\*\//m) do |part|
        part.start_with?('"') ? part : ""
      end
      counts = text.scan(/"BGMTrackCount"\s*:\s*(\d+)/).flatten
      unless counts.length == 1 && counts[0].to_i > TRACK
        warn_once(:config, 'Set "BGMTrackCount": 2 in mkxp.json, then restart Game.exe.')
        return
      end
      Audio.bgm_volume(TRACK)
      @enabled = true
    rescue StandardError => error
      warn_once(:boot, "Ambient channel unavailable: #{error.message}")
    end

    def stop
      Audio.bgm_stop(TRACK) if @enabled && @path
      @path = nil
      @volume = 0.0
      @target = 0.0
      @last_sent = nil
    end

    def pause
      @paused = true
      stop
    end

    def resume
      @paused = false
      @scan_left = 0.0
    end

    def refresh
      @cache = {}
      @files = {}
      @scan_left = 0.0
    end

    def active_map?
      return false if @paused
      return false unless defined?(Scene_Map) && $scene.is_a?(Scene_Map)
      return false unless $game_map && $game_player && $game_temp
      return false if $game_temp.in_battle
      return false if $game_temp.player_transferring
      true
    end

    def resolve_file(name)
      return @files[name] if @files.key?(name)
      # Files are relative to Audio/BGS. No absolute paths or traversal.
      if name.empty? || name.include?("..") || name =~ /[\\\/:]/
        warn_once([:name, name], "Invalid water filename: #{name.inspect}")
        return @files[name] = nil
      end
      base = "Audio/BGS/#{name}"
      paths = File.extname(name).empty? ? EXTENSIONS.map { |ext| base + ext } : [base]
      @files[name] = paths.find do |path|
        if defined?(pbResolveAudioFile) && defined?(pbRgssExists?)
          pbRgssExists?(path)
        else
          File.file?(path)
        end
      end
      warn_once([:file, name], "Missing water audio in Audio/BGS: #{name}") unless @files[name]
      @files[name]
    end

    def parse_tags(list)
      return [] if !list
      text = list.select { |cmd| cmd.code == 108 || cmd.code == 408 }
                 .map { |cmd| cmd.parameters[0].to_s }.join("\n")
      text.scan(TAG).filter_map do |match|
        fields = match[0].split(",").map { |field| field.strip }
        name = fields[0].to_s
        begin
          radius = fields[1] ? Float(fields[1]) : 8.0
          maximum = fields[2] ? Integer(fields[2]) : 70
          inner = fields[3] ? Float(fields[3]) : 2.0
          valid = radius.finite? && inner.finite? && radius > 0 &&
                  inner >= 0 && inner < radius && maximum.between?(0, 100) && fields.length <= 4
          raise ArgumentError unless valid
          path = resolve_file(name)
          path ? [path, radius, maximum, inner] : nil
        rescue ArgumentError, TypeError
          warn_once([:tag, match[0]], "Invalid Comment: [Water:#{match[0]}]")
          nil
        end
      end
    end

    def sources
      live = {}
      result = []
      $game_map.events.each do |id, event|
        next unless event
        # Read the ACTIVE page only; an erased event has no active list.
        list = event.list
        next unless list
        cached = @cache[id]
        tags = cached && cached[0].equal?(list) ? cached[1] : parse_tags(list)
        live[id] = [list, tags]
        tags.each { |tag| result << [event, tag] }
      end
      @cache = live
      result
    end

    def scan
      best_path = nil
      best_volume = 0.0
      sources.each do |event, tag|
        path, radius, maximum, inner = tag
        dx = $game_player.x - event.x
        dy = $game_player.y - event.y
        distance = Math.sqrt(dx * dx + dy * dy)
        next if distance >= radius
        fraction = [[(radius - distance) / (radius - inner), 0.0].max, 1.0].min
        volume = maximum * fraction
        if volume > best_volume || (volume == best_volume && path == @path)
          best_path = path
          best_volume = volume
        end
      end
      @desired_path = best_path
      @target = best_volume
    end

    def update
      return unless @enabled
      unless active_map?
        stop
        @scan_left = 0.0
        return
      end
      key = [$game_map.map_id, $game_map.object_id]
      if key != @map_key
        stop
        @map_key = key
        refresh
      end
      dt = Graphics.respond_to?(:delta) ? Graphics.delta.to_f : 1.0 / Graphics.frame_rate
      dt = [[dt, 0.001].max, 0.1].min
      @scan_left -= dt
      if @scan_left <= 0
        scan
        @scan_left = SCAN_INTERVAL
      end
      # Different water recordings switch only after fading out the old one.
      goal = @path && @path != @desired_path ? 0.0 : @target
      step = 100.0 * dt / FADE_SECONDS
      @volume += [[goal - @volume, -step].max, step].min
      if @path && @volume <= 0.0
        stop
        @target = 0.0
        @scan_left = 0.0
      end
      if !@path && @desired_path && goal > 0
        @path = @desired_path
        @volume = [step, @target].min
        Audio.bgm_play(@path, @volume.round, 100, 0, TRACK)
        @last_sent = @volume.round
      end
      if @path && @last_sent != @volume.round
        Audio.bgm_set_volume(@volume.round, TRACK)
        @last_sent = @volume.round
      end
    rescue StandardError => error
      # A missing/unsupported file cannot crash the whole game.
      begin
        stop
      rescue StandardError
        @path = nil
      end
      @enabled = false
      warn_once(:runtime, "Disabled after audio error: #{error.class}: #{error.message}")
    end
  end
end

LPWaterSound.boot

# mkxp-z's unspecified-track play/stop/fade acts on ALL BGM tracks.
# Route ordinary Essentials calls to track 0, preserving the ambient stream.
# Explicit track arguments keep their original meaning.
module LPWaterSoundAudioRouting
  def bgm_play(name, volume = 100, pitch = 100, position = 0, track = nil)
    track = 0 if track.nil? && LPWaterSound.enabled
    super(name, volume, pitch, position, track)
  end

  def bgm_stop(track = nil)
    track = 0 if track.nil? && LPWaterSound.enabled
    super(track)
  end

  def bgm_fade(milliseconds, track = nil)
    track = 0 if track.nil? && LPWaterSound.enabled
    super(milliseconds, track)
  end
end

module LPWaterSoundGraphicsUpdate
  def update(*args)
    result = super
    LPWaterSound.update
    result
  end
end

if LPWaterSound.enabled
  Audio.singleton_class.prepend(LPWaterSoundAudioRouting)
  Graphics.singleton_class.prepend(LPWaterSoundGraphicsUpdate)
end
