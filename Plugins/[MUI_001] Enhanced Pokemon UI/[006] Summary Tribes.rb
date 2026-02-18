#===============================================================================
# Add tribe methods to Pokemon class
#===============================================================================
class Pokemon
  def tribe
    species_data.tribe rescue nil
  end

  def has_tribe?
    !tribe.nil?
  end

  # Returns true if this Pokémon belongs to the specified tribe
  def is_tribe?(check_tribe)
    return false if !has_tribe?
    return tribe == check_tribe
  end
end

#===============================================================================
# Summary scene edits for Tribe display
#===============================================================================
class PokemonSummary_Scene
  alias tribes_drawPageOne drawPageOne
  def drawPageOne
    tribes_drawPageOne
    return if !@pokemon || @pokemon.egg?
    drawTribeDetails
  end
  
  def drawTribeDetails
    return if !@pokemon.has_tribe?
    tribe = GameData::Tribe::DATA[@pokemon.tribe]
    return if !tribe
    
    base_y = 260  # Adjusted Y position to fit better in the summary screen
    overlay = @sprites["overlay"].bitmap
    tribe_members = []
    
    # Get all Pokémon in the party with the same tribe
    $player.party.each do |pkmn|
      next if !pkmn || !pkmn.has_tribe?
      tribe_members.push(pkmn) if pkmn.tribe == @pokemon.tribe
    end
    
    # Draw tribe section background
    tribe_bg_path = pbResolveBitmap("Graphics/UI/Summary/tribe_bg")
    if tribe_bg_path
      tribe_bg = Bitmap.new(tribe_bg_path)
      overlay.blt(10, base_y - 4, tribe_bg, Rect.new(0, 0, 400, 100))
      tribe_bg.dispose
    else
      # Fallback: draw a simple rectangle if image doesn't exist
      overlay.fill_rect(10, base_y - 4, 400, 100, Color.new(48, 48, 48, 160))
    end
    
    # Draw tribe information
    base_color = Color.new(248, 248, 248)
    shadow_color = Color.new(104, 104, 104)
    active_color = Color.new(64, 200, 64)
    inactive_color = Color.new(248, 248, 248)
    
    textpos = []
    # Tribe name and status
    textpos.push([_INTL("Tribe:"), 26, base_y, 0, base_color, shadow_color])
    textpos.push([tribe.name, 116, base_y, 0, base_color, shadow_color])
    
    # Progress indicator
    status_color = tribe_members.length >= tribe.required_count ? active_color : inactive_color
    progress_text = _INTL("{1}/{2} Pokémon", tribe_members.length, tribe.required_count)
    textpos.push([progress_text, 300, base_y, :right, status_color, shadow_color])
    
    # Draw tribe effect description (word wrapped)
    description = tribe.effect_desc
    drawFormattedTextEx(overlay, 26, base_y + 26, 380, 2, description, base_color, shadow_color)
    
    pbDrawTextPositions(overlay, textpos)
    
    # Draw member icons
    icon_x = 26
    icon_y = base_y + 52
    
    # Draw party member icons
    tribe_members.each_with_index do |pkmn, i|
      next if i >= 6
      pbDrawPokemonIcon(overlay, pkmn.species, pkmn.form, icon_x, icon_y)
      icon_x += 48
    end
  end
end

# Create tribe background image if it doesn't exist
def self.create_tribe_background
  return if pbResolveBitmap("Graphics/UI/Summary/tribe_bg")
  begin
    bitmap = Bitmap.new(400, 100)
    bitmap.fill_rect(0, 0, 400, 100, Color.new(48, 48, 48, 160))
    dir_path = "Graphics/UI/Summary"
    Dir.mkdir(dir_path) unless File.directory?(dir_path)
    bitmap.to_file("#{dir_path}/tribe_bg.png")
  rescue
    bitmap&.dispose
  end
end

# Create the tribe background on game load
create_tribe_background