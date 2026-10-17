# Terrain floor colours - Pokemon Essentials v21.1
# Add alongside the terrain animation plugins. No replacement/PBS edits needed.
# Ground-only translucent colour wash; no changes to gameplay or battle sprites.
module TerrainFloorTint
  # RGB, maximum opacity (0-255). Lower the fourth number for a lighter tint.
  COLOURS = {
    :Grassy        => [62, 151, 63, 66],
    :Electric      => [238, 192, 57, 60],
    :Misty         => [233, 150, 192, 62],
    :Psychic       => [159, 99, 204, 66],
    :Cursed        => [71, 31, 103, 72],
    :Ghost         => [71, 31, 103, 72],
    :CursedTerrain => [71, 31, 103, 72]
  }

  def self.palette(battle)
    return nil unless battle && battle.field
    entry = COLOURS[battle.field.terrain]
    return entry if entry
    if defined?(CursedTerrain) && CursedTerrain.respond_to?(:active?) && CursedTerrain.active?(battle)
      return COLOURS[:Cursed]
    end
    nil
  end

  class Layer
    def initialize(hash,viewport)
      @hash = hash
      @key = "terrain_floor_tint_#{object_id}"
      @bitmap = nil
      @sprite = nil
      @disposed = false
      @rgb = nil
      @opacity = 0.0
      begin
        @bitmap = Bitmap.new(256,192)
        # Transparent above the ground; smooth increase toward the foreground.
        192.times do |y|
          p = [[(y/192.0-0.38)/0.43,0].max,1].min
          alpha = (p*p*(3-2*p)*255).round
          @bitmap.fill_rect(0,y,256,1,Color.new(255,255,255,alpha))
        end
        @sprite = Sprite.new(viewport)
        @sprite.bitmap = @bitmap
        @sprite.z = 2
        @sprite.zoom_x = Graphics.width/256.0
        @sprite.zoom_y = Graphics.height/192.0
        @sprite.opacity = 0
        @hash[@key] = @sprite
      rescue
        dispose
        raise
      end
    end

    def update(entry)
      dt = 1.0/[Graphics.frame_rate,1].max
      goal = entry ? entry[3].to_f : 0.0
      step = dt*180
      @opacity += [[goal-@opacity,-step].max,step].min
      if entry
        @rgb ||= entry[0,3].map { |c| c.to_f }
        3.times { |i| @rgb[i] += (entry[i]-@rgb[i])*[dt*10,1].min }
      end
      if @rgb
        # Full RGB recolour of the white alpha mask preserves its transparency.
        @sprite.color = Color.new(@rgb[0].round,@rgb[1].round,@rgb[2].round,255)
      end
      @sprite.opacity = @opacity.round
    end

    def faded?; @opacity <= 0.01; end
    def dispose
      return if @disposed
      @disposed = true
      @hash.delete(@key) if @hash
      @sprite.dispose if @sprite && !@sprite.disposed?
      @bitmap.dispose if @bitmap && !@bitmap.disposed?
    end
  end

  module SceneHooks
    def pbGraphicsUpdate
      if @sprites && @viewport && !@viewport.disposed? && @battle
        entry = TerrainFloorTint.palette(@battle)
        if entry || @terrain_floor_tint
          @terrain_floor_tint ||= TerrainFloorTint::Layer.new(@sprites,@viewport)
          @terrain_floor_tint.update(entry)
          if !entry && @terrain_floor_tint.faded?
            @terrain_floor_tint.dispose
            @terrain_floor_tint = nil
          end
        end
      end
      super
    end

    def pbDisposeSprites
      if @terrain_floor_tint
        @terrain_floor_tint.dispose
        @terrain_floor_tint = nil
      end
      super
    end
  end
end
Battle::Scene.prepend(TerrainFloorTint::SceneHooks)
