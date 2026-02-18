#==============================================================================
# * Box Ranch - Overworld Shadows Compatibility
#==============================================================================
# Diese Datei fügt Kompatibilität zwischen dem Box Ranch System und dem
# Overworld Shadows Plugin hinzu.
#
# Pokémon im Wasser sollen keine Schatten haben.
#==============================================================================

# Prüfen, ob das Overworld Shadows Plugin installiert ist
if defined?(Sprite_Character::ShadowSprite)
  # Patchen der ShadowSprite-Klasse mit unserer eigenen Logik
  class Sprite_Character
    class ShadowSprite
      # Originale visible? Methode sichern
      alias_method :original_visible?, :visible?
      
      # Überschreiben der visible? Methode
      def visible?
        # Zuerst die originale Sichtbarkeitslogik prüfen
        return false unless original_visible?
        
        # BoxRanch: Wenn Event-Name "InWater" enthält, keinen Schatten anzeigen
        if @event.respond_to?(:name) && @event.name.include?("InWater")
          return false
        end
        
        # Ansonsten normale Sichtbarkeit zurückgeben
        return true
      end
    end
  end
  
  # Log-Eintrag für die Installation
  echoln("BoxRanch: Overworld Shadows Kompatibilität wurde geladen")
else
  # Wenn das Plugin nicht installiert ist, nichts tun
  echoln("BoxRanch: Overworld Shadows Plugin nicht gefunden - Keine Schatten-Kompatibilität")
end 