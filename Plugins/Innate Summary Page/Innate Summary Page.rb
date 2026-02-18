#===============================================================================
# Adds/edits various Summary utilities.
#===============================================================================
=begin
class PokemonSummary_Scene
  def drawPageINNATES
    overlay = @sprites["overlay"].bitmap
    base_color = Color.new(248, 248, 248)
    shadow_color = Color.new(104, 104, 104)
    text_base_color = Color.new(64, 64, 64)
    text_shadow_color = Color.new(176, 176, 176)
	text_red_color  = Color.new(175, 34, 34)
	text_red_shadow = Color.new(247, 106, 106)
    # Determine which stats are boosted and lowered by the Pokémon's nature
    statshadows = {}
    GameData::Stat.each_main { |s| statshadows[s.id] = shadow_color }
    # Write various bits of text
    textpos = [
      [_INTL(" Innate 1"), 224, 80, :left, base_color, shadow_color],
	  [_INTL(" Innate 2"), 224, 180, :left, base_color, shadow_color],
	  [_INTL(" Innate 3"), 224, 280, :left, base_color, shadow_color]
    ]
	 # Get variables for the progress system
	small_font = Settings::SMALL_FONT_IN_SUMMARY
    use_variable_unlock = Settings::INNATE_PROGRESS_WITH_VARIABLE
	use_level_unlock = Settings::INNATE_PROGRESS_WITH_LEVEL
	levels_to_unlock = Settings::LEVELS_TO_UNLOCK.find { |entry| entry.first == @pokemon.species }&.drop(1) || Settings::LEVELS_TO_UNLOCK.last #Added check for the specific ID of a pokemon.
	display_count = $game_variables[Settings::INNATE_PROGRESS_VARIABLE]
	pokemon_level = @pokemon.level
	
	# Draw innate name and description
	# Iterate over each innate skill
    3.times do |i|
      innate_name = @pokemon.getInnateListName[i]
      innate_data = GameData::Innate.try_get(innate_name)
	  
	   # If the pokemon doesn't have an Innate to show
      innate_name_display = innate_data ? innate_data.name : "---"
      innate_desc_display = innate_data ? innate_data.description : "--- No innate ---"

	#Properly write down each part of the innate
	if innate_data
        if use_level_unlock && pokemon_level < levels_to_unlock[i]
          textpos << ["Locked", 362, 80 + i * 100, :left, text_red_color, text_red_shadow]
          if small_font
            pbSetSmallFont(overlay)
            drawFormattedTextEx(overlay, 224, 112 + i * 100, 282, "This pokemon's innate is currently locked until level #{levels_to_unlock[i]}.", text_red_color, text_red_shadow, 20)
            pbSetSystemFont(overlay)
          else
            drawTextEx(overlay, 224, 112 + i * 100, 282, 2, "This innate is currently locked until level #{levels_to_unlock[i]}.", text_red_color, text_red_shadow)
          end
        elsif use_variable_unlock && i >= display_count
          textpos << ["Locked", 362, 80 + i * 100, :left, text_red_color, text_red_shadow]
          if small_font
            pbSetSmallFont(overlay)
            drawFormattedTextEx(overlay, 224, 112 + i * 100, 282, "This pokemon's innate is currently locked.", text_red_color, text_red_shadow, 20)
            pbSetSystemFont(overlay)
          else
            drawTextEx(overlay, 224, 112 + i * 100, 282, 2, "This innate is currently locked.", text_red_color, text_red_shadow)
          end
        else
          textpos << [innate_data.name, 362, 80 + i * 100, :left, text_base_color, text_shadow_color]
          if small_font
            pbSetSmallFont(overlay)
            drawFormattedTextEx(overlay, 224, 112 + i * 100, 282, innate_data.description, text_base_color, text_shadow_color, 20)
            pbSetSystemFont(overlay)
          else
            drawTextEx(overlay, 224, 112 + i * 100, 282, 2, innate_data.description, text_base_color, text_shadow_color)
          end
        end
	  else #The Pokemon has no Innate to show
	  textpos << [innate_name_display, 362, 80 + i * 100, :left, text_base_color, text_shadow_color]
        if small_font
          pbSetSmallFont(overlay)
          drawFormattedTextEx(overlay, 224, 112 + i * 100, 282, innate_desc_display, text_base_color, text_shadow_color, 20)
          pbSetSystemFont(overlay)
        else
          drawTextEx(overlay, 224, 112 + i * 100, 282, 2, innate_desc_display, text_base_color, text_shadow_color)
        end
      end
    end #
    
    pbDrawTextPositions(overlay, textpos)
  end
end
=end
=begin
class PokemonSummary_Scene
  def drawPageINNATES
    overlay = @sprites["overlay"].bitmap
    base_color = Color.new(248, 248, 248)
    shadow_color = Color.new(104, 104, 104)
    text_base_color = Color.new(64, 64, 64)
    text_shadow_color = Color.new(176, 176, 176)
    text_red_color = Color.new(175, 34, 34)
    text_red_shadow = Color.new(247, 106, 106)
    small_font = Settings::SMALL_FONT_IN_SUMMARY
    use_variable_unlock = Settings::INNATE_PROGRESS_WITH_VARIABLE
    use_level_unlock = Settings::INNATE_PROGRESS_WITH_LEVEL
    levels_to_unlock = Settings::LEVELS_TO_UNLOCK.find { |entry| entry.first == @pokemon.species }&.drop(1) || Settings::LEVELS_TO_UNLOCK.last
    display_count = $game_variables[Settings::INNATE_PROGRESS_VARIABLE]
    pokemon_level = @pokemon.level

    #if @pokemon.fixed_innates.empty?
    #  @pokemon.assign_innate_abilities
    #end

	@pokemon.assign_innate_abilities
    active_innates = @pokemon.active_innates

    # Draw innate name and description
    textpos = [
      [_INTL(" Innate 1"), 224, 80, :left, base_color, shadow_color],
      [_INTL(" Innate 2"), 224, 180, :left, base_color, shadow_color],
      [_INTL(" Innate 3"), 224, 280, :left, base_color, shadow_color]
    ]

    # Iterate over each innate ability
    3.times do |i|
      innate_name = active_innates[i]
      innate_data = GameData::Innate.try_get(innate_name)
	  
	  # If the pokemon doesn't have an Innate to show
      innate_name_display = innate_data ? innate_data.name : "---"
      innate_desc_display = innate_data ? innate_data.description : "--- No innate ---"

      if innate_data
        if use_level_unlock && pokemon_level < levels_to_unlock[i]
          textpos << ["Locked", 362, 80 + i * 100, :left, text_red_color, text_red_shadow]
          if small_font
            pbSetSmallFont(overlay)
            drawFormattedTextEx(overlay, 224, 112 + i * 100, 282, "This pokemon's innate is currently locked until level #{levels_to_unlock[i]}.", text_red_color, text_red_shadow, 20)
            pbSetSystemFont(overlay)
          else
            drawTextEx(overlay, 224, 112 + i * 100, 282, 2, "This innate is currently locked until level #{levels_to_unlock[i]}.", text_red_color, text_red_shadow)
          end
        elsif use_variable_unlock && i >= display_count
          textpos << ["Locked", 362, 80 + i * 100, :left, text_red_color, text_red_shadow]
          if small_font
            pbSetSmallFont(overlay)
            drawFormattedTextEx(overlay, 224, 112 + i * 100, 282, "This pokemon's innate is currently locked.", text_red_color, text_red_shadow, 20)
            pbSetSystemFont(overlay)
          else
            drawTextEx(overlay, 224, 112 + i * 100, 282, 2, "This innate is currently locked.", text_red_color, text_red_shadow)
          end
        else
          textpos << [innate_data.name, 362, 80 + i * 100, :left, text_base_color, text_shadow_color]
          if small_font
            pbSetSmallFont(overlay)
            drawFormattedTextEx(overlay, 224, 112 + i * 100, 282, innate_data.description, text_base_color, text_shadow_color, 20)
            pbSetSystemFont(overlay)
          else
            drawTextEx(overlay, 224, 112 + i * 100, 282, 2, innate_data.description, text_base_color, text_shadow_color)
          end
        end
      else
        textpos << [innate_name_display, 362, 80 + i * 100, :left, text_base_color, text_shadow_color]
        if small_font
          pbSetSmallFont(overlay)
          drawFormattedTextEx(overlay, 224, 112 + i * 100, 282, innate_desc_display, text_base_color, text_shadow_color, 20)
          pbSetSystemFont(overlay)
        else
          drawTextEx(overlay, 224, 112 + i * 100, 282, 2, innate_desc_display, text_base_color, text_shadow_color)
        end
      end
    end

    pbDrawTextPositions(overlay, textpos)
  end
end
=end
class PokemonSummary_Scene
  # Helper method to wrap text into multiple lines
  def wrap_text(text, max_width, overlay)
    words = text.split(' ')
    lines = []
    current_line = ""

    words.each do |word|
      if overlay.text_size("#{current_line} #{word}").width > max_width
        lines << current_line.strip
        current_line = word
      else
        current_line += " #{word}"
      end
    end
    lines << current_line.strip unless current_line.empty?
    lines
  end

  def drawPageINNATES
    overlay = @sprites["overlay"].bitmap
    base_color = Color.new(248, 248, 248)
    shadow_color = Color.new(104, 104, 104)
    text_base_color = Color.new(64, 64, 64)
    text_shadow_color = Color.new(176, 176, 176)
    text_red_color = Color.new(175, 34, 34)
    text_red_shadow = Color.new(247, 106, 106)
    small_font = Settings::SMALL_FONT_IN_SUMMARY
    max_width = 140 # Maximum width for wrapping innate names
    use_variable_unlock = Settings::INNATE_PROGRESS_WITH_VARIABLE
    use_level_unlock = Settings::INNATE_PROGRESS_WITH_LEVEL
    levels_to_unlock = Settings::LEVELS_TO_UNLOCK.find { |entry| entry.first == @pokemon.species }&.drop(1) || Settings::LEVELS_TO_UNLOCK.last
    display_count = $game_variables[Settings::INNATE_PROGRESS_VARIABLE]
    pokemon_level = @pokemon.level
	
	active_innates = @pokemon.active_innates
	#puts "Active innates 1: #{active_innates.inspect}"
	if active_innates.nil? || active_innates.empty?
		@pokemon.assign_innate_abilities
		active_innates = @pokemon.active_innates
		#puts "Active innates 2: #{active_innates.inspect}"
	end
    
	
	# Draw innate name and description
    textpos = [
      [_INTL(" Innate 1"), 224, 80, :left, base_color, shadow_color],
      [_INTL(" Innate 2"), 224, 180, :left, base_color, shadow_color],
      [_INTL(" Innate 3"), 224, 280, :left, base_color, shadow_color]
    ]

    3.times do |i|
      innate_name = active_innates[i]
      innate_data = GameData::Innate.try_get(innate_name)
      innate_name_display = innate_data ? innate_data.name : "---"
      innate_desc_display = innate_data ? innate_data.description : "--- No innate ---"

      text_x = 362
      text_y = 80 + i * 100

      if innate_data
        # Locked Innates
        if use_level_unlock && pokemon_level < levels_to_unlock[i]
          drawLockedInnate(overlay, text_y, i, "This innate is currently locked until level #{levels_to_unlock[i]}.", small_font, text_red_color, text_red_shadow)
        elsif use_variable_unlock && i >= display_count
          drawLockedInnate(overlay, text_y, i, "This innate is currently locked.", small_font, text_red_color, text_red_shadow)
        else
          # Dynamically adjust name font/lines
          drawInnateName(overlay, innate_name_display, text_x, text_y, max_width, text_base_color, text_shadow_color, small_font)

          # Description handling
          if small_font
            pbSetSmallFont(overlay)
            drawFormattedTextEx(overlay, 224, text_y + 32, 282, innate_desc_display, text_base_color, text_shadow_color, 20)
            pbSetSystemFont(overlay)
          else
            drawTextEx(overlay, 224, text_y + 32, 282, 2, innate_desc_display, text_base_color, text_shadow_color)
          end
        end
      else
        # If no innate data exists
        drawInnateName(overlay, innate_name_display, text_x, text_y, max_width, text_base_color, text_shadow_color, small_font)

        if small_font
          pbSetSmallFont(overlay)
          drawFormattedTextEx(overlay, 224, text_y + 32, 282, innate_desc_display, text_base_color, text_shadow_color, 20)
          pbSetSystemFont(overlay)
        else
          drawTextEx(overlay, 224, text_y + 32, 282, 2, innate_desc_display, text_base_color, text_shadow_color)
        end
      end
    end
	pbDrawTextPositions(overlay, textpos)
  end
  

  def drawLockedInnate(overlay, text_y, index, lock_message, small_font, color, shadow_color)
    textpos = [["Locked", 362, text_y, :left, color, shadow_color]]
    pbDrawTextPositions(overlay, textpos)
    if small_font
      pbSetSmallFont(overlay)
      drawFormattedTextEx(overlay, 224, text_y + 32, 282, lock_message, color, shadow_color, 20)
      pbSetSystemFont(overlay)
    else
      drawTextEx(overlay, 224, text_y + 32, 282, 2, lock_message, color, shadow_color)
    end
  end

  def drawInnateName(overlay, innate_name_display, text_x, text_y, max_width, base_color, shadow_color, small_font)
  if overlay.text_size(innate_name_display).width > max_width
    pbSetSmallFont(overlay)
    lines = wrap_text(innate_name_display, max_width, overlay)
    if lines.size > 1
      # Adjust position slightly for multi-line names
      adjusted_y = text_y - 10
      adjusted_x = text_x - 20
      lines.each_with_index do |line, index|
        drawTextEx(overlay, adjusted_x, adjusted_y + (index * 20), max_width, 2, line, base_color, shadow_color)
      end
    else
      # Single-line name fits in small font; keep original position
      drawTextEx(overlay, text_x, text_y, max_width, 2, lines.first, base_color, shadow_color)
    end
    pbSetSystemFont(overlay)
  else
    # Single-line name fits in regular font; keep original font and position
    drawTextEx(overlay, text_x, text_y, max_width, 2, innate_name_display, base_color, shadow_color)
  end
	end
end