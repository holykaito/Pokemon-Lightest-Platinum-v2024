#===============================================================================
# Screen Light Filters
#===============================================================================
# Displays a fixed, full-screen overlay while the player is on the map.
#
# Graphics/Pictures/Sunlight.png:
#   Outdoor maps from 06:00 until before 18:00, without rain or a blizzard.
# Graphics/Pictures/Border.png:
#   Indoor maps, rain, storms, heavy rain and blizzards.
#===============================================================================
module ScreenLightFilter
  SUNLIGHT_IMAGE = "Sunlight"
  BORDER_IMAGE   = "Border"
  OPACITY        = 255   # About 50% of the maximum opacity (255).
  VIEWPORT_Z     = 150   # Above the overworld, below screen pictures and UI.
  ZOOM           = 2   # Display the filter at 150%, centred on the screen.
  SUNLIGHT_START_HOUR = 6
  SUNLIGHT_END_HOUR   = 18

  # All rain variants use Border. Snow still uses Sunlight; only Blizzard is
  # treated as a snowstorm, as requested.
  BORDER_WEATHERS = [:Rain, :Storm, :HeavyRain, :Blizzard]

  def self.current_image
    return BORDER_IMAGE if !$game_map || !$game_map.metadata&.outdoor_map
    return BORDER_IMAGE if !sunlight_time?
    weather = ($game_screen) ? $game_screen.weather_type : :None
    return BORDER_IMAGE if BORDER_WEATHERS.include?(weather)
    return SUNLIGHT_IMAGE
  end

  def self.sunlight_time?
    hour = pbGetTimeNow.hour
    return hour >= SUNLIGHT_START_HOUR && hour < SUNLIGHT_END_HOUR
  end
end

class Spriteset_Global
  alias screen_light_filter_initialize initialize
  def initialize
    screen_light_filter_initialize
    create_screen_light_filter
    refresh_screen_light_filter(true)
  end

  alias screen_light_filter_update update
  def update
    screen_light_filter_update
    refresh_screen_light_filter if @screen_light_filter_sprite
  end

  alias screen_light_filter_dispose dispose
  def dispose
    dispose_screen_light_filter
    screen_light_filter_dispose
  end

  private

  def create_screen_light_filter
    @screen_light_filter_viewport = Viewport.new(
      0, 0, Graphics.width, Graphics.height
    )
    @screen_light_filter_viewport.z = ScreenLightFilter::VIEWPORT_Z
    @screen_light_filter_sprite = Sprite.new(@screen_light_filter_viewport)
    @screen_light_filter_sprite.opacity = ScreenLightFilter::OPACITY
    @screen_light_filter_image = nil
    @screen_light_filter_size = nil
  end

  def refresh_screen_light_filter(force = false)
    image_name = ScreenLightFilter.current_image
    screen_size = [Graphics.width, Graphics.height]
    return if !force && @screen_light_filter_image == image_name &&
              @screen_light_filter_size == screen_size
    bitmap = RPG::Cache.picture(image_name)
    @screen_light_filter_viewport.rect.set(
      0, 0, Graphics.width, Graphics.height
    )
    @screen_light_filter_sprite.bitmap = bitmap
    @screen_light_filter_sprite.ox = bitmap.width / 2
    @screen_light_filter_sprite.oy = bitmap.height / 2
    @screen_light_filter_sprite.x = Graphics.width / 2
    @screen_light_filter_sprite.y = Graphics.height / 2
    @screen_light_filter_sprite.zoom_x =
      (Graphics.width.to_f / bitmap.width) * ScreenLightFilter::ZOOM
    @screen_light_filter_sprite.zoom_y =
      (Graphics.height.to_f / bitmap.height) * ScreenLightFilter::ZOOM
    @screen_light_filter_sprite.opacity = ScreenLightFilter::OPACITY
    @screen_light_filter_image = image_name
    @screen_light_filter_size = screen_size
  end

  def dispose_screen_light_filter
    if @screen_light_filter_sprite
      @screen_light_filter_sprite.dispose
      @screen_light_filter_sprite = nil
    end
    if @screen_light_filter_viewport
      @screen_light_filter_viewport.dispose
      @screen_light_filter_viewport = nil
    end
  end
end
