class Game_Temp
  attr_accessor :vs_transition_bg
  attr_accessor :vs_name
  
  alias vs_initialize initialize
  def initialize
    vs_initialize
    @vs_name = nil
  end
  
  def get_vs_transition_bg
    vs_transition_bg || "Plains"
  end
  
  def get_vs_name
    vs_name || "Default"
  end
end

#===============================================================================
# Helper Methods
# Do not touch unless you know what you're doing.
#===============================================================================
def dkDisplayBallCount(viewport,foe,team_index)
  ball_sprites = []
  foe_party = foe[team_index].party
  Settings::MAX_PARTY_SIZE.times do |i|
    graphicFilename = "Battle/icon_ball_empty"
    if foe_party[i]
      if !foe_party[i].able?
        graphicFilename = "Battle/icon_ball_faint"
      elsif foe_party[i].status != :NONE
        graphicFilename = "Battle/icon_ball_status"
      else
        graphicFilename = "Battle/icon_ball"
      end
    end
    ball_sprite = Sprite.new(viewport)
    ball_sprite.bitmap = RPG::Cache.ui(graphicFilename)
    ball_sprite.x = ((Settings::MAX_PARTY_SIZE - i) * 32) - (Graphics.width/2) # to push it off screen to the left
    ball_sprite.y = Graphics.height - 90 - (46 * team_index) # arbritrary
    ball_sprite.z  = 99999
    ball_sprites.push(ball_sprite)
  end
  return ball_sprites # for the calling method
end

def dkGetTrainerName(foe)
  vs_name1 = foe[0]&.name
  vs_name2 = foe[1]&.name
  vs_name3 = foe[2]&.name

  if vs_name3
    vs_name = "Vs. #{vs_name1}, #{vs_name2}, & #{vs_name3}"
  elsif vs_name2
    vs_name = "Vs. #{vs_name1} & #{vs_name2}"
  else
    vs_name = "Vs. #{vs_name1}"
  end

  return vs_name
end

def dkGetSpeciesName(foe)
  vs_name1 = foe[0]&.name
  vs_name2 = foe[1]&.name
  vs_name3 = foe[2]&.name

  if vs_name3
    vs_name = "Vs. #{vs_name1}, #{vs_name2}, & #{vs_name3}"
  elsif vs_name2
    vs_name = "Vs. #{vs_name1} & #{vs_name2}"
  else
    vs_name = "Vs. #{vs_name1}"
  end
  
  return vs_name
end

def dkConvertNameToBitmap(viewport, foe, battle_type)
  namesprite = Sprite.new(viewport)
  namesprite.z = 99999

  base_path = "Graphics/Transitions/DTS/Names/"
  image_name = nil

  enc_name = foe.compact.map { |s|
    [1, 3].include?(battle_type) ? s.trainer_type : "#{s.species}_W"
  }

  case enc_name.length
  when 3
    image_name = "Name_#{enc_name[0]}_#{enc_name[1]}_#{enc_name[2]}"
  when 2
    image_name = "Name_#{enc_name[0]}_#{enc_name[1]}"
  when 1
    image_name = "Name_#{enc_name[0]}"
  end
  
  echoln image_name
  
  full_path = "#{base_path}#{image_name}"

  if image_name && pbResolveBitmap(full_path)
    namesprite.bitmap = RPG::Cache.transition("DTS/Names/#{image_name}")
  else
    #pbMessage("vs_name = #{$game_temp.vs_name.inspect}")
    # Fallback to text
    text = $game_temp.vs_name ||
           ([0, 2].include?(battle_type) ? dkGetSpeciesName(foe) : dkGetTrainerName(foe))
    bmp = Bitmap.new(Graphics.width, Graphics.height)
    pbSetSystemFont(bmp)
    bmp.font.size = 40

    textpos = [
      [text, Graphics.width / 2, Graphics.height - 38, :center,
       Color.new(248, 248, 248), Color.new(72, 80, 88)]
    ]
    pbDrawTextPositions(bmp, textpos)
    namesprite.bitmap = bmp
  end
  
  namesprite.y = Graphics.height - namesprite.bitmap.height
  return namesprite
end

#===============================================================================
# Single Trainer Battle
#===============================================================================
SpecialBattleIntroAnimations.register("vs_boss_solo", 90,   # Priority 80
  proc { |battle_type, foe, location|   # Condition
    next false if ![1, 3].include?(battle_type)   # Trainer battles only
	next false if foe.length != 1 # Multi-Battles Only
    tr_type  = foe[0].trainer_type
    next pbResolveBitmap("Graphics/Transitions/DTS/PTs/Char_#{tr_type}") # Character cut-in
  },
  proc { |viewport, battle_type, foe, location|   # Animation
	#$game_temp.vs_name = dkGetTrainerName(foe)
	# Determine filenames of graphics to be used
    BAR_DISPLAY_WIDTH = 248
	tr_type        = foe[0].trainer_type
    bg_name        = $game_temp.get_vs_transition_bg
    bg_graphic     = sprintf("DTS/BGs/BG%s", bg_name.to_s) rescue nil
    tr_graphic     = sprintf("DTS/PTs/Char_%s", tr_type.to_s) rescue nil
    black_bars     = sprintf("DTS/BorderBars") rescue nil
    # Set up sprites
	ball_sprites     = dkDisplayBallCount(viewport, foe, 0) # Create the ball count for a trainer
	ball_bar         = Sprite.new(viewport)
    ball_bar.bitmap  = RPG::Cache.transition("DTS/Balls/overlay_lineup.png")
    ball_bar.x       = -440
    ball_bar.y       = 292
	ball_bar.z       = 99998
    # Background Graphic
    background              = Sprite.new(viewport)
    background.bitmap       = RPG::Cache.transition(bg_graphic)
    background.z            = 99990
    background.opacity      = 0
    # Character portrait and shadow
    portrait                = Sprite.new(viewport)
    portrait_shadow         = Sprite.new(viewport)
    portrait.bitmap         = RPG::Cache.transition(tr_graphic)
    portrait_shadow.bitmap  = RPG::Cache.transition(tr_graphic)   
    portrait.z              = 99996
    portrait.ox             = portrait.bitmap.width/2
    portrait.x              = Graphics.width/2
	portrait.oy             = portrait.bitmap.height
	portrait.y              = Graphics.height
    portrait.opacity        = 0
    portrait_shadow.tone    = Tone.new(-255, -255, -255)
    portrait_shadow.opacity = 0
    portrait_shadow.z       = portrait.z - 1
    portrait_shadow.ox      = portrait.bitmap.width/2
	portrait_shadow.x       = Graphics.width/2
	portrait_shadow.oy      = portrait.bitmap.height
	portrait_shadow.y       = Graphics.height
    # Black bars at the top and bottom of screen
    bartop            = Sprite.new(viewport)
    bartop.bitmap     = RPG::Cache.transition(black_bars)
    barbottom         = Sprite.new(viewport)
    barbottom.bitmap  = RPG::Cache.transition(black_bars)   
    bartop.y          = 0
    bartop.z          = portrait.z - 2
    barbottom.y       = Graphics.height - bartop.height
    barbottom.z       = portrait.z + 2
    bartop.opacity    = 0
    barbottom.opacity = 0   
    # Name graphic
    charname = dkConvertNameToBitmap(viewport, foe, battle_type)
    charname.z = barbottom.z + 2
    charname.opacity = 0
    # Flash graphic
    flash = Sprite.new(viewport)
    flash.bitmap  = RPG::Cache.transition("vsFlash")
    flash.opacity = 0
    flash.z       = 9999999
	
    # Initial screen flashing
	num_flashes = 2
    if num_flashes > 0
      c = (location == 2 || PBDayNight.isNight?) ? 0 : 255   # Dark=black, light=white
      viewport.color = Color.new(c, c, c)   # Fade to black/white a few times
      half_flash_time = 0.2   # seconds
      num_flashes.times do   # 2 flashes
        fade_out = false
        timer_start = System.uptime
        loop do
          if fade_out
            viewport.color.alpha = lerp(255, 0, half_flash_time, timer_start, System.uptime)
          else
            viewport.color.alpha = lerp(0, 255, half_flash_time, timer_start, System.uptime)
          end
          Graphics.update
          pbUpdateSceneMap
          break if fade_out && viewport.color.alpha <= 0
          if !fade_out && viewport.color.alpha >= 255
            fade_out = true
            timer_start = System.uptime
          end
        end
      end
    end
    
    # Fade to black, then fade in the background and black bars
    flash.tone = Tone.new(-255, -255, -255)   # Make the flash black
	pbWait(0.75) do |delta_t|
      flash.opacity = lerp(0, 255, 0.25, delta_t)   # Fade to black
	end
	
	bartop.opacity    = 230
    barbottom.opacity = 230
	background.opacity = 255
    pbWait(1) do |delta_t| # There was a 15 frame wait after the start of the background fading in. Is this right?
      flash.opacity      = lerp(255, 0, 0.25, delta_t)
	  #background.opacity = lerp(0, 255, 0.25, delta_t)
    end
    
    # Flash the screen, display the character's shadow portrait
    flash.tone = Tone.new(255, 255, 255)
	pbSEPlay("Vs flash")
    flash.opacity = 255
    
    pbWait(1.5) do |delta_t| # Initial delay was 40 frames after start of shadow showing up.
      flash.opacity           = lerp(255, 0, 0.25, delta_t)
      portrait_shadow.opacity = 192
    end
    
    # Flash the screen again, display the character's portrait and name. Begin shifting shadow leftward.
    pbSEPlay("Vs sword")
    flash.opacity = 255
    
    original_x = portrait_shadow.x
    pbWait(4) do |delta_t| # Initial delay was 60 frames after start of portrait showing up.
      flash.opacity     = lerp(255, 0, 0.5, delta_t)
      portrait.opacity  = 255
      charname.opacity  = 255
      portrait_shadow.x = lerp(original_x, original_x - 6, 1.5, delta_t)
      ball_sprites.each_with_index do |s,i|
        s.x = lerp(((Settings::MAX_PARTY_SIZE - i) * 32) - (Graphics.width/2), ((Settings::MAX_PARTY_SIZE - i) * 32), 0.4, delta_t)
      end
	  ball_bar.x = lerp(-440, -192, 0.4, delta_t)
    end    
    
    # Fade out all graphics, then change their color tone to black (Is that still necessary?)
    flash.tone = Tone.new(-255, -255, -255)
    pbWait(0.3) do |delta_t|
	  flash.opacity = lerp(0, 255, 0.25, delta_t)
    end

    # End of animation
    flash.dispose
    charname.dispose
    background.dispose
    portrait.dispose
    portrait_shadow.dispose
    bartop.dispose
    barbottom.dispose
	ball_bar.dispose
	ball_sprites.each {|s| s.dispose}
	$game_temp.vs_name = nil
	$game_temp.transition_animation_data = nil

    viewport.color = Color.black   # Ensure screen is black
  }
)

#===============================================================================
# Double Trainer Battle
#===============================================================================
SpecialBattleIntroAnimations.register("vs_boss_duo", 91,   # Priority 81
  proc { |battle_type, foe, location|   # Condition
    next false if ![1, 3].include?(battle_type)   # Trainer battles only
	next false if foe.length == 1 # Multi-Battles Only
    tr_type   = foe[0].trainer_type
	tr_type2  = foe[1].trainer_type
    next pbResolveBitmap("Graphics/Transitions/DTS/PTs/Char_#{tr_type}") && # Character cut-in
	     pbResolveBitmap("Graphics/Transitions/DTS/PTs/Char_#{tr_type2}")
  },
  proc { |viewport, battle_type, foe, location|   # Animation
    #$game_temp.vs_name = dkGetTrainerName(foe)
	# Determine filenames of graphics to be used
    BAR_DISPLAY_WIDTH = 248
	tr_type  = foe[0].trainer_type
	tr_type2 = foe[1].trainer_type
    bg_name = $game_temp.get_vs_transition_bg
    bg_graphic     = sprintf("DTS/BGs/BG%s", bg_name.to_s) rescue nil
    tr1_graphic    = sprintf("DTS/PTs/Char_%s", tr_type.to_s) rescue nil
	tr2_graphic    = sprintf("DTS/PTs/Char_%s", tr_type2.to_s) rescue nil
    tr_name        = sprintf("DTS/Names/Name_%s_%s", tr_type.to_s, tr_type2.to_s) rescue nil
    black_bars     = sprintf("DTS/BorderBars") rescue nil
    # Set up sprites
	ball_sprites     = dkDisplayBallCount(viewport, foe, 0) # Create the ball count for trainer 0
	ball_sprites2    = dkDisplayBallCount(viewport, foe, 1) # Create the ball count for trainer 1
	ball_bar         = Sprite.new(viewport)
    ball_bar.bitmap  = RPG::Cache.transition("DTS/Balls/overlay_lineup.png")
    ball_bar.x       = -440
    ball_bar.y       = 292
	ball_bar.z       = 99998
	ball_bar2        = Sprite.new(viewport)
    ball_bar2.bitmap = ball_bar.bitmap
    ball_bar2.x      = ball_bar.x
    ball_bar2.y      = ball_bar.y - 46
	ball_bar2.z      = ball_bar.z
    # Background Graphic
    background              = Sprite.new(viewport)
    background.bitmap       = RPG::Cache.transition(bg_graphic)
    background.z            = 99990
    background.opacity      = 0
    # Trainer 1 portrait and shadow
    portrait                = Sprite.new(viewport)
    portrait_shadow         = Sprite.new(viewport)
    portrait.bitmap         = RPG::Cache.transition(tr1_graphic)
    portrait_shadow.bitmap  = RPG::Cache.transition(tr1_graphic)   
    portrait.z              = 99996
    portrait.ox             = portrait.bitmap.width/2
    portrait.x              = Graphics.width/2 + 128
	portrait.oy             = portrait.bitmap.height
	portrait.y              = Graphics.height
    portrait.opacity        = 0
    portrait_shadow.tone    = Tone.new(-255, -255, -255)
    portrait_shadow.opacity = 0
    portrait_shadow.z       = portrait.z - 1
    portrait_shadow.ox      = portrait.bitmap.width/2
	portrait_shadow.x       = Graphics.width/2 + 128
	portrait_shadow.oy      = portrait.bitmap.height
	portrait_shadow.y       = Graphics.height
    # Trainer 2 portrait and shadow
    portrait2                = Sprite.new(viewport)
    portrait2_shadow         = Sprite.new(viewport)
    portrait2.bitmap         = RPG::Cache.transition(tr2_graphic)
    portrait2_shadow.bitmap  = RPG::Cache.transition(tr2_graphic)   
    portrait2.z              = 99996
    portrait2.ox             = portrait2.bitmap.width/2
    portrait2.x              = Graphics.width/2 - 128
	portrait2.oy             = portrait2.bitmap.height
	portrait2.y              = Graphics.height
    portrait2.opacity        = 0
    portrait2_shadow.tone    = Tone.new(-255, -255, -255)
    portrait2_shadow.opacity = 0
    portrait2_shadow.z       = portrait2.z - 1
	portrait2_shadow.ox      = portrait2.bitmap.width/2
	portrait2_shadow.x       = Graphics.width/2 - 128
	portrait2_shadow.oy      = portrait2.bitmap.height
	portrait2_shadow.y       = Graphics.height
    # Black bars at the top and bottom of screen
    bartop            = Sprite.new(viewport)
    bartop.bitmap     = RPG::Cache.transition(black_bars)
    barbottom         = Sprite.new(viewport)
    barbottom.bitmap  = RPG::Cache.transition(black_bars)   
    bartop.y          = 0
    bartop.z          = portrait.z - 2
    barbottom.y       = Graphics.height - bartop.height
    barbottom.z       = portrait.z + 2
    bartop.opacity    = 0
    barbottom.opacity = 0   
    # Name graphic
    if pbResolveBitmap("Graphics/Transitions/DTS/Names/Name_#{tr_type}_#{tr_type2}")
      charname = Sprite.new(viewport)
      charname.bitmap = RPG::Cache.transition("DTS/Names/Name_#{tr_type}_#{tr_type2}")
    else
      charname = dkConvertNameToBitmap(viewport, foe, battle_type)
    end
    charname.z = barbottom.z + 2
    charname.opacity = 0
    # Flash graphic
    flash = Sprite.new(viewport)
    flash.bitmap  = RPG::Cache.transition("vsFlash")
    flash.opacity = 0
    flash.z       = 9999999
	
    # Initial screen flashing
	num_flashes = 2
    if num_flashes > 0
      c = (location == 2 || PBDayNight.isNight?) ? 0 : 255   # Dark=black, light=white
      viewport.color = Color.new(c, c, c)   # Fade to black/white a few times
      half_flash_time = 0.2   # seconds
      num_flashes.times do   # 2 flashes
        fade_out = false
        timer_start = System.uptime
        loop do
          if fade_out
            viewport.color.alpha = lerp(255, 0, half_flash_time, timer_start, System.uptime)
          else
            viewport.color.alpha = lerp(0, 255, half_flash_time, timer_start, System.uptime)
          end
          Graphics.update
          pbUpdateSceneMap
          break if fade_out && viewport.color.alpha <= 0
          if !fade_out && viewport.color.alpha >= 255
            fade_out = true
            timer_start = System.uptime
          end
        end
      end
    end
    
    # Fade to black, then fade in the background and black bars
    flash.tone = Tone.new(-255, -255, -255)   # Make the flash black
	pbWait(0.75) do |delta_t|
      flash.opacity = lerp(0, 255, 0.25, delta_t)   # Fade to black
	end
	
	bartop.opacity    = 230
    barbottom.opacity = 230
	background.opacity = 255
    pbWait(1) do |delta_t| # There was a 15 frame wait after the start of the background fading in. Is this right?
      flash.opacity      = lerp(255, 0, 0.25, delta_t)
	  #background.opacity = lerp(0, 255, 0.25, delta_t)
    end
    
    # Flash the screen, display the character's shadow portrait
    flash.tone = Tone.new(255, 255, 255)
	pbSEPlay("Vs flash")
    flash.opacity = 255
    
    pbWait(1.5) do |delta_t| # Initial delay was 40 frames after start of shadow showing up.
      flash.opacity           = lerp(255, 0, 0.25, delta_t)
      portrait_shadow.opacity = 192
	  portrait2_shadow.opacity = 192
    end
    
    # Flash the screen again, display the character's portrait. Begin shifting shadow leftward.
    pbSEPlay("Vs sword")
    flash.opacity = 255
    
    original_x = portrait_shadow.x
	original2_x = portrait2_shadow.x
    pbWait(4) do |delta_t| # Initial delay was 60 frames after start of portrait showing up.
      flash.opacity     = lerp(255, 0, 0.5, delta_t)
      portrait.opacity  = 255
	  portrait2.opacity  = 255
      charname.opacity  = 255
      portrait_shadow.x = lerp(original_x, original_x - 6, 1.5, delta_t)
	  portrait2_shadow.x = lerp(original2_x, original2_x - 6, 1.5, delta_t)
      ball_sprites.each_with_index do |s,i|
        s.x = lerp(((Settings::MAX_PARTY_SIZE - i) * 32) - (Graphics.width/2), ((Settings::MAX_PARTY_SIZE - i) * 32), 0.4, delta_t)
      end
	  ball_sprites2.each_with_index do |s,i|
        s.x = lerp(((Settings::MAX_PARTY_SIZE - i) * 32) - (Graphics.width/2), ((Settings::MAX_PARTY_SIZE - i) * 32), 0.4, delta_t)
      end
	  ball_bar.x  = lerp(-440, -192, 0.4, delta_t)
	  ball_bar2.x = lerp(-440, -192, 0.4, delta_t)
    end    
    
    # Fade out all graphics, then change their color tone to black (Is that still necessary?)
    flash.tone = Tone.new(-255, -255, -255)
    pbWait(0.3) do |delta_t|
      flash.opacity = lerp(0, 255, 0.25, delta_t)
    end

    # End of animation
    flash.dispose
    charname.dispose
    background.dispose
    portrait.dispose
    portrait_shadow.dispose
	portrait2.dispose
    portrait2_shadow.dispose
    bartop.dispose
    barbottom.dispose
	ball_bar.dispose
	ball_bar2.dispose
	ball_sprites.each {|s| s.dispose}
	ball_sprites2.each {|s| s.dispose}
	$game_temp.vs_name = nil
	$game_temp.transition_animation_data = nil

    viewport.color = Color.black   # Ensure screen is black
  }
)

#===============================================================================
# Triple Trainer Battle
#===============================================================================
SpecialBattleIntroAnimations.register("vs_boss_trio", 92,   # Priority 82
  proc { |battle_type, foe, location|   # Condition
    next false if ![1, 3].include?(battle_type)   # Trainer battles only
	next false if foe.length != 3 # Triple Battles Only
    tr_type  = foe[0].trainer_type
	tr_type2 = foe[1].trainer_type
	tr_type3 = foe[2].trainer_type
    next pbResolveBitmap("Graphics/Transitions/DTS/PTs/Char_#{tr_type}") && # Character cut-in
	     pbResolveBitmap("Graphics/Transitions/DTS/PTs/Char_#{tr_type2}") &&
		 pbResolveBitmap("Graphics/Transitions/DTS/PTs/Char_#{tr_type3}")
  },
  proc { |viewport, battle_type, foe, location|   # Animation
    #$game_temp.vs_name = dkGetTrainerName(foe)
    # Determine filenames of graphics to be used
    BAR_DISPLAY_WIDTH = 248
	tr_type  = foe[0].trainer_type
	tr_type2 = foe[1].trainer_type
	tr_type3 = foe[2].trainer_type
    bg_name        = $game_temp.get_vs_transition_bg
    bg_graphic     = sprintf("DTS/BGs/BG%s", bg_name.to_s) rescue nil
	tr1_graphic    = sprintf("DTS/PTs/Char_%s", tr_type.to_s) rescue nil
	tr2_graphic    = sprintf("DTS/PTs/Char_%s", tr_type2.to_s) rescue nil
	tr3_graphic    = sprintf("DTS/PTs/Char_%s", tr_type3.to_s) rescue nil
    tr_name        = sprintf("DTS/Names/Name_%s_%s_%s", tr_type.to_s, tr_type2.to_s, tr_type3.to_s) rescue nil
    black_bars     = sprintf("DTS/BorderBars") rescue nil
    # Set up sprites
	ball_sprites     = dkDisplayBallCount(viewport, foe, 0) # Create the ball count for trainer 0
	ball_sprites2    = dkDisplayBallCount(viewport, foe, 1) # Create the ball count for trainer 1
	ball_sprites3    = dkDisplayBallCount(viewport, foe, 2) # Create the ball count for trainer 2
	ball_bar         = Sprite.new(viewport)
    ball_bar.bitmap  = RPG::Cache.transition("DTS/Balls/overlay_lineup.png")
    ball_bar.x       = -440
    ball_bar.y       = 292
	ball_bar.z       = 99998
	ball_bar2        = Sprite.new(viewport)
    ball_bar2.bitmap = ball_bar.bitmap
    ball_bar2.x      = ball_bar.x
    ball_bar2.y      = ball_bar.y - 46
	ball_bar2.z      = ball_bar.z
	ball_bar3        = Sprite.new(viewport)
    ball_bar3.bitmap = ball_bar.bitmap
    ball_bar3.x      = ball_bar.x
    ball_bar3.y      = ball_bar2.y - 46
	ball_bar3.z      = ball_bar.z
    # Background Graphic
    background              = Sprite.new(viewport)
    background.bitmap       = RPG::Cache.transition(bg_graphic)
    background.z            = 99990
    background.opacity      = 0
    # Trainer 1 portrait and shadow
    portrait                = Sprite.new(viewport)
    portrait_shadow         = Sprite.new(viewport)
    portrait.bitmap         = RPG::Cache.transition(tr1_graphic)
    portrait_shadow.bitmap  = RPG::Cache.transition(tr1_graphic)   
    portrait.z              = 99997
    portrait.ox             = portrait.bitmap.width/2
    portrait.x              = Graphics.width/2
	portrait.oy             = portrait.bitmap.height
	portrait.y              = Graphics.height
    portrait.opacity        = 0
    portrait_shadow.tone    = Tone.new(-255, -255, -255)
    portrait_shadow.opacity = 0
    portrait_shadow.z       = portrait.z - 1
    portrait_shadow.ox      = portrait.bitmap.width/2
	portrait_shadow.x       = Graphics.width/2
	portrait_shadow.oy      = portrait.bitmap.height
	portrait_shadow.y       = Graphics.height
    # Trainer 2 portrait and shadow
    portrait2                = Sprite.new(viewport)
    portrait2_shadow         = Sprite.new(viewport)
    portrait2.bitmap         = RPG::Cache.transition(tr2_graphic)
    portrait2_shadow.bitmap  = RPG::Cache.transition(tr2_graphic)   
    portrait2.z              = 99996
    portrait2.ox             = portrait2.bitmap.width/2
    portrait2.x              = Graphics.width/2 - 128
	portrait2.oy             = portrait2.bitmap.height
	portrait2.y              = Graphics.height
    portrait2.opacity        = 0
    portrait2_shadow.tone    = Tone.new(-255, -255, -255)
    portrait2_shadow.opacity = 0
    portrait2_shadow.z       = portrait2.z - 1
	portrait2_shadow.ox      = portrait2.bitmap.width/2
	portrait2_shadow.x       = Graphics.width/2 - 128
	portrait2_shadow.oy      = portrait2.bitmap.height
	portrait2_shadow.y       = Graphics.height
	# Trainer 3 portrait and shadow
    portrait3                = Sprite.new(viewport)
    portrait3_shadow         = Sprite.new(viewport)
    portrait3.bitmap         = RPG::Cache.transition(tr3_graphic)
    portrait3_shadow.bitmap  = RPG::Cache.transition(tr3_graphic)   
    portrait3.z              = 99996
    portrait3.ox             = portrait3.bitmap.width/2
    portrait3.x              = Graphics.width/2 + 192
	portrait3.oy             = portrait3.bitmap.height
	portrait3.y              = Graphics.height
    portrait3.opacity        = 0
    portrait3_shadow.tone    = Tone.new(-255, -255, -255)
    portrait3_shadow.opacity = 0
    portrait3_shadow.z       = portrait3.z - 1
	portrait3_shadow.ox      = portrait3.bitmap.width/2
	portrait3_shadow.x       = Graphics.width/2 + 192
	portrait3_shadow.oy      = portrait3.bitmap.height
	portrait3_shadow.y       = Graphics.height
    # Black bars at the top and bottom of screen
    bartop            = Sprite.new(viewport)
    bartop.bitmap     = RPG::Cache.transition(black_bars)
    barbottom         = Sprite.new(viewport)
    barbottom.bitmap  = RPG::Cache.transition(black_bars)   
    bartop.y          = 0
    bartop.z          = portrait.z - 2
    barbottom.y       = Graphics.height - bartop.height
    barbottom.z       = portrait.z + 2
    bartop.opacity    = 0
    barbottom.opacity = 0   
    # Name graphic
    if pbResolveBitmap("Graphics/Transitions/DTS/Names/Name_#{tr_type}_#{tr_type2}_#{tr_type3}")
      charname = Sprite.new(viewport)
      charname.bitmap = RPG::Cache.transition("Graphics/Transitions/DTS/Names/Name_#{tr_type}_#{tr_type2}_#{tr_type3}")
    else
      charname = dkConvertNameToBitmap(viewport, foe, battle_type)
    end
    charname.z = barbottom.z + 2
    charname.opacity = 0
    # Flash graphic
    flash = Sprite.new(viewport)
    flash.bitmap  = RPG::Cache.transition("vsFlash")
    flash.opacity = 0
    flash.z       = 9999999
	
    # Initial screen flashing
	num_flashes = 2
    if num_flashes > 0
      c = (location == 2 || PBDayNight.isNight?) ? 0 : 255   # Dark=black, light=white
      viewport.color = Color.new(c, c, c)   # Fade to black/white a few times
      half_flash_time = 0.2   # seconds
      num_flashes.times do   # 2 flashes
        fade_out = false
        timer_start = System.uptime
        loop do
          if fade_out
            viewport.color.alpha = lerp(255, 0, half_flash_time, timer_start, System.uptime)
          else
            viewport.color.alpha = lerp(0, 255, half_flash_time, timer_start, System.uptime)
          end
          Graphics.update
          pbUpdateSceneMap
          break if fade_out && viewport.color.alpha <= 0
          if !fade_out && viewport.color.alpha >= 255
            fade_out = true
            timer_start = System.uptime
          end
        end
      end
    end
    
    # Fade to black, then fade in the background and black bars
    flash.tone = Tone.new(-255, -255, -255)   # Make the flash black
	pbWait(0.75) do |delta_t|
      flash.opacity = lerp(0, 255, 0.25, delta_t)   # Fade to black
	end
	
	bartop.opacity    = 230
    barbottom.opacity = 230
	background.opacity = 255
    pbWait(1) do |delta_t| # There was a 15 frame wait after the start of the background fading in. Is this right?
      flash.opacity      = lerp(255, 0, 0.25, delta_t)
	  #background.opacity = lerp(0, 255, 0.25, delta_t)
    end
    
    # Flash the screen, display the character's shadow portrait
    flash.tone = Tone.new(255, 255, 255)
	pbSEPlay("Vs flash")
    flash.opacity = 255
    
    pbWait(1.5) do |delta_t| # Initial delay was 40 frames after start of shadow showing up.
      flash.opacity           = lerp(255, 0, 0.25, delta_t)
      portrait_shadow.opacity = 192
	  portrait2_shadow.opacity = 192
	  portrait3_shadow.opacity = 192
    end
    
    # Flash the screen again, display the character's portrait. Begin shifting shadow leftward.
    pbSEPlay("Vs sword")
    flash.opacity = 255
    
    original_x = portrait_shadow.x
	original2_x = portrait2_shadow.x
	original3_x = portrait3_shadow.x
    pbWait(4) do |delta_t| # Initial delay was 60 frames after start of portrait showing up.
      flash.opacity     = lerp(255, 0, 0.5, delta_t)
      portrait.opacity  = 255
	  portrait2.opacity  = 255
	  portrait3.opacity  = 255
      charname.opacity  = 255
      portrait_shadow.x = lerp(original_x, original_x - 6, 1.5, delta_t)
	  portrait2_shadow.x = lerp(original2_x, original2_x - 6, 1.5, delta_t)
	  portrait3_shadow.x = lerp(original3_x, original3_x - 6, 1.5, delta_t)
      ball_sprites.each_with_index do |s,i|
        s.x = lerp(((Settings::MAX_PARTY_SIZE - i) * 32) - (Graphics.width/2), ((Settings::MAX_PARTY_SIZE - i) * 32), 0.4, delta_t)
      end
	  ball_sprites2.each_with_index do |s,i|
        s.x = lerp(((Settings::MAX_PARTY_SIZE - i) * 32) - (Graphics.width/2), ((Settings::MAX_PARTY_SIZE - i) * 32), 0.4, delta_t)
      end
	  ball_sprites3.each_with_index do |s,i|
        s.x = lerp(((Settings::MAX_PARTY_SIZE - i) * 32) - (Graphics.width/2), ((Settings::MAX_PARTY_SIZE - i) * 32), 0.4, delta_t)
      end
	  ball_bar.x = lerp(-440, -192, 0.4, delta_t)
	  ball_bar2.x = lerp(-440, -192, 0.4, delta_t)
	  ball_bar3.x = lerp(-440, -192, 0.4, delta_t)
    end    
    
    # Fade out all graphics, then change their color tone to black (Is that still necessary?)
    flash.tone = Tone.new(-255, -255, -255)
    pbWait(0.3) do |delta_t|
      flash.opacity = lerp(0, 255, 0.25, delta_t)
    end

    # End of animation
    flash.dispose
    charname.dispose
    background.dispose
    portrait.dispose
    portrait_shadow.dispose
	portrait2.dispose
    portrait2_shadow.dispose
	portrait3.dispose
    portrait3_shadow.dispose
    bartop.dispose
    barbottom.dispose
	ball_bar.dispose
	ball_bar2.dispose
	ball_bar3.dispose
	ball_sprites.each {|s| s.dispose}
	ball_sprites2.each {|s| s.dispose}
	ball_sprites3.each {|s| s.dispose}
	$game_temp.vs_name = nil
	$game_temp.transition_animation_data = nil

    viewport.color = Color.black   # Ensure screen is black
  }
)

#===============================================================================
# Single Wild Battle
#===============================================================================
SpecialBattleIntroAnimations.register("vs_wild_boss", 90,   # Priority 80
  proc { |battle_type, foe, location|   # Condition
    next false if ![0, 2].include?(battle_type)   # Wild Encounters Only
    species = foe[0].species
	form    = foe[0].form
	base_path = "Graphics/Transitions/DTS/PTs"
	
	has_form_graphic = pbResolveBitmap("#{base_path}/Wild_#{species}_#{form}")
    has_species_graphic = pbResolveBitmap("#{base_path}/Wild_#{species}")
    
	next has_form_graphic || has_species_graphic
  },
  proc { |viewport, battle_type, foe, location|   # Animation
    #$game_temp.vs_name = dkGetSpeciesName(foe)
	$game_temp.transition_animation_data = [foe[0].species, foe[0].form]
    # Determine filenames of graphics to be used
    species        = foe[0].species
	form           = foe[0].form
    bg_name        = $game_temp.get_vs_transition_bg
    bg_graphic     = sprintf("DTS/BGs/BG%s", bg_name.to_s) rescue nil
    bg_graphic     = sprintf("DTS/BGs/BG%s", bg_name.to_s) rescue nil
	if pbResolveBitmap(sprintf("Graphics/Transitions/DTS/PTs/Wild_%s_%s", species.to_s, form.to_s))
      wld_graphic = sprintf("DTS/PTs/Wild_%s_%s", species.to_s, form.to_s) rescue nil
    else
      wld_graphic = sprintf("DTS/PTs/Wild_%s", species.to_s) rescue nil
    end
    wld_name       = sprintf("DTS/Names/Name_%s_W", species.to_s) rescue nil
    black_bars     = sprintf("DTS/BorderBars") rescue nil
    # Set up sprites
    # Background Graphic
    background              = Sprite.new(viewport)
    background.bitmap       = RPG::Cache.transition(bg_graphic)
    background.z            = 99990
    background.opacity      = 0
    # Character portrait and shadow
    portrait                = Sprite.new(viewport)
    portrait_shadow         = Sprite.new(viewport)
    portrait.bitmap         = RPG::Cache.transition(wld_graphic)
    portrait_shadow.bitmap  = RPG::Cache.transition(wld_graphic)   
    portrait.z              = 99996
    portrait.ox             = portrait.bitmap.width/2
    portrait.x              = Graphics.width/2
	portrait.oy             = portrait.bitmap.height
	portrait.y              = Graphics.height
    portrait.opacity        = 0
    portrait_shadow.tone    = Tone.new(-255, -255, -255)
    portrait_shadow.opacity = 0
    portrait_shadow.z       = portrait.z - 1
    portrait_shadow.ox      = portrait.bitmap.width/2
	portrait_shadow.x       = Graphics.width/2
	portrait_shadow.oy      = portrait.bitmap.height
	portrait_shadow.y       = Graphics.height
    # Black bars at the top and bottom of screen
    bartop            = Sprite.new(viewport)
    bartop.bitmap     = RPG::Cache.transition(black_bars)
    barbottom         = Sprite.new(viewport)
    barbottom.bitmap  = RPG::Cache.transition(black_bars)   
    bartop.y          = 0
    bartop.z          = portrait.z - 2
    barbottom.y       = Graphics.height - bartop.height
    barbottom.z       = portrait.z + 2
    bartop.opacity    = 0
    barbottom.opacity = 0   
    # Name graphic
    wildname         = dkConvertNameToBitmap(viewport, foe, battle_type)
    wildname.z       = barbottom.z += 2
    wildname.opacity = 0    
    # Flash graphic
    flash = Sprite.new(viewport)
    flash.bitmap  = RPG::Cache.transition("vsFlash")
    flash.opacity = 0
    flash.z       = 9999999
	
    # Initial screen flashing
	num_flashes = 2
    if num_flashes > 0
      c = (location == 2 || PBDayNight.isNight?) ? 0 : 255   # Dark=black, light=white
      viewport.color = Color.new(c, c, c)   # Fade to black/white a few times
      half_flash_time = 0.2   # seconds
      num_flashes.times do   # 2 flashes
        fade_out = false
        timer_start = System.uptime
        loop do
          if fade_out
            viewport.color.alpha = lerp(255, 0, half_flash_time, timer_start, System.uptime)
          else
            viewport.color.alpha = lerp(0, 255, half_flash_time, timer_start, System.uptime)
          end
          Graphics.update
          pbUpdateSceneMap
          break if fade_out && viewport.color.alpha <= 0
          if !fade_out && viewport.color.alpha >= 255
            fade_out = true
            timer_start = System.uptime
          end
        end
      end
    end
    
    # Fade to black, then fade in the background and black bars
    flash.tone = Tone.new(-255, -255, -255)   # Make the flash black
	pbWait(0.75) do |delta_t|
      flash.opacity = lerp(0, 255, 0.25, delta_t)   # Fade to black
	end
	
	bartop.opacity    = 230
    barbottom.opacity = 230
	background.opacity = 255
    pbWait(1) do |delta_t| # There was a 15 frame wait after the start of the background fading in. Is this right?
      flash.opacity      = lerp(255, 0, 0.25, delta_t)
	  #background.opacity = lerp(0, 255, 0.25, delta_t)
    end
    
    # Flash the screen, display the character's shadow portrait
    flash.tone = Tone.new(255, 255, 255)
	pbSEPlay("Vs flash")
    flash.opacity = 255
    
    pbWait(1.5) do |delta_t| # Initial delay was 40 frames after start of shadow showing up.
      flash.opacity           = lerp(255, 0, 0.25, delta_t)
      portrait_shadow.opacity = 192
    end
    
    # Flash the screen again, display the character's portrait. Begin shifting shadow leftward.
    pbSEPlay("Vs sword")
    flash.opacity = 255
    
    original_x = portrait_shadow.x
    pbWait(4) do |delta_t| # Initial delay was 60 frames after start of portrait showing up.
      flash.opacity     = lerp(255, 0, 0.5, delta_t)
      portrait.opacity  = 255
      wildname.opacity  = 255
      portrait_shadow.x = lerp(original_x, original_x - 6, 1.5, delta_t)
    end    
    
    # Fade out all graphics, then change their color tone to black (Is that still necessary?)
    flash.tone = Tone.new(-255, -255, -255)
    pbWait(0.3) do |delta_t|
      flash.opacity = lerp(0, 255, 0.25, delta_t)
    end

    # End of animation
    flash.dispose
    wildname.dispose
    background.dispose
    portrait.dispose
    portrait_shadow.dispose
    bartop.dispose
    barbottom.dispose
	$game_temp.vs_name = nil
	$game_temp.transition_animation_data = nil
	$game_temp.transition_animation_data = nil

    viewport.color = Color.black   # Ensure screen is black
  }
)