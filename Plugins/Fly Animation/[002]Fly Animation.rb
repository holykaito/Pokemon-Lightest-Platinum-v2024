#===============================================================================
# ■ Fly Animation by KleinStudio
# http://pokemonfangames.com
#===============================================================================
# A.I.R (Update for v21.1)
#===============================================================================
class Game_Character
  def setOpacity(value)
    @opacity = value
  end
end
#-------------------
# Animation
#-------------------

def pbFlyAnimation(landing = true)
  if landing
    $game_player.turn_left
    pbSEPlay("flybird")
  end
  width = Settings::SCREEN_WIDTH
  height = Settings::SCREEN_HEIGHT
  @flybird = Sprite.new
  @flybird.bitmap = if SHOW_GEN_4_BIRD == false
                      RPG::Cache.picture("flybird")
                    else
                      RPG::Cache.picture("flybird_gen4")
                    end
  @flybird.ox = @flybird.bitmap.width / 2
  @flybird.oy = @flybird.bitmap.height / 2
  @flybird.x  = width + @flybird.bitmap.width
  @flybird.y  = height / 4
  center_x  = width / 2 + 10
  center_y  = height / 2
  exit_x    = -@flybird.bitmap.width

  x_in = (center_x - @flybird.x) / BIRD_ANIMATION_TIME
  y_in = (center_y - @flybird.y) / BIRD_ANIMATION_TIME
  x_out = (exit_x - center_x) / BIRD_ANIMATION_TIME
  y_out = (@flybird.y - center_y) / BIRD_ANIMATION_TIME

  start_time = System.uptime
  loop do
    delta = System.uptime - start_time
    start_time = System.uptime

    if @flybird.x > center_x
      @flybird.x += x_in * delta
      @flybird.y += y_in * delta
      @flybird.x = center_x if @flybird.x < center_x
    elsif @flybird.x >= exit_x
      @flybird.x += x_out * delta
      @flybird.y += y_out * delta
      $game_player.setOpacity(landing ? 0 : 255)
    else
      break
    end

    pbUpdateSceneMap
    Graphics.update
  end
  @flybird.dispose
  @flybird = nil
end
