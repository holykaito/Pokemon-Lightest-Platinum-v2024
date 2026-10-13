#===============================================================================
# Advanced AI System - DBK Compatibility Patches
# Supports wild Pokemon configured with DBK gimmick attributes.
#===============================================================================
# Fixes DBK AI trying to access statDown/statUp on Unimplemented moves
class Battle::Move
  def statDown
    return []
  end unless method_defined?(:statDown)

  def statUp
    return []
  end unless method_defined?(:statUp)
end

#===============================================================================

#===============================================================================
# Dynamax Compatibility
# Allows wild Pokemon with dynamax_lvl > 0 to Dynamax.
#===============================================================================
# The full DBK method accepts an optional argument; its placeholder does not.
if defined?(Battle::Battler) && Battle::Battler.method_defined?(:hasDynamax?) &&
   Battle::Battler.instance_method(:hasDynamax?).arity != 0
  class Battle::Battler
    alias_method :aai_compat_hasDynamax?, :hasDynamax? unless method_defined?(:aai_compat_hasDynamax?) || private_method_defined?(:aai_compat_hasDynamax?)
    def hasDynamax?(check_available = true)
      if wild? && @pokemon&.respond_to?(:dynamax_lvl) && @pokemon.dynamax_lvl && @pokemon.dynamax_lvl > 0
        AdvancedAI.log("  ✅ Wild Pokemon hasDynamax? override - has dynamax_lvl!", "Compatibility")
        return true
      end
      
      aai_compat_hasDynamax?(check_available)
    end
  end
  
  AdvancedAI.log("DBK hasDynamax? compatibility patch applied", "Compatibility")
end

if defined?(Battle) && Battle.method_defined?(:pbCanDynamax?)
  class Battle
    alias_method :aai_compat_pbCanDynamax?, :pbCanDynamax? unless method_defined?(:aai_compat_pbCanDynamax?) || private_method_defined?(:aai_compat_pbCanDynamax?)
    def pbCanDynamax?(idxBattler)
      battler = @battlers[idxBattler]
      
      if battler.wild? && battler.pokemon&.respond_to?(:dynamax_lvl) && battler.pokemon.dynamax_lvl && battler.pokemon.dynamax_lvl > 0
        AdvancedAI.log("  ✅ Wild Pokemon has dynamax_lvl, allowing Dynamax!", "Compatibility")
        if !battler.hasDynamax?
          AdvancedAI.log("  ❌ FAILED: battler.hasDynamax? returned false", "Compatibility")
          return false
        end
        AdvancedAI.log("  ✅ Passed hasDynamax check", "Compatibility")
        
        if battler.effects[PBEffects::SkyDrop] >= 0
          AdvancedAI.log("  ❌ FAILED: In Sky Drop", "Compatibility")
          return false
        end
        AdvancedAI.log("  ✅ Passed Sky Drop check", "Compatibility")
        
        if @dynamax
          side  = battler.idxOwnSide
          owner = pbGetOwnerIndexFromBattlerIndex(idxBattler)
          result = @dynamax[side][owner] == -1
          AdvancedAI.log("  Dynamax slot check: @dynamax[#{side}][#{owner}] == -1 ? #{result}", "Compatibility")
          return result
        end
        return false
      end
      
      aai_compat_pbCanDynamax?(idxBattler)
    end
  end
  
  AdvancedAI.log("DBK Dynamax compatibility patch applied", "Compatibility")
end

#===============================================================================
# Terastallization Compatibility
# Allows wild Pokemon with tera_type set to Terastallize (similar to Dynamax)
#===============================================================================

if defined?(Pokemon) && Pokemon.method_defined?(:tera_type)
  class Pokemon
    alias_method :aai_compat_tera_type, :tera_type unless method_defined?(:aai_compat_tera_type) || private_method_defined?(:aai_compat_tera_type)
    def tera_type
      # DBK refreshes forced types after mask/form changes and already retains
      # explicitly assigned types for ordinary species.
      aai_compat_tera_type
    end
    
    if method_defined?(:terastallized=)
      alias_method :aai_compat_terastallized=, :terastallized= unless method_defined?(:aai_compat_terastallized=) || private_method_defined?(:aai_compat_terastallized=)
      def terastallized=(value)
        # Explicit wild Tera types bypass terastal_able?.
        if @tera_type && !@tera_type.nil?
          @terastallized = value
          if @terastallized
            self.makeTerastalForm if respond_to?(:makeTerastalForm)
          else
            self.makeUnterastal if respond_to?(:makeUnterastal)
          end
          return
        end
        
        self.aai_compat_terastallized = value
      end
    end
    
    def tera?
      return @terastallized
    end

    def dynamax?
      return @dynamax
    end
    
    attr_accessor :explicit_tera_type
    
    if method_defined?(:tera_type=)
      alias_method :aai_compat_tera_type=, :tera_type= unless method_defined?(:aai_compat_tera_type=) || private_method_defined?(:aai_compat_tera_type=)
      def tera_type=(value)
        self.aai_compat_tera_type = value
        @explicit_tera_type = true
      end
    else
      def tera_type=(value)
        @tera_type = value
        @explicit_tera_type = true
      end
    end
  end
  
  AdvancedAI.log("DBK Pokemon#tera_type compatibility patch applied", "Compatibility")
end

if defined?(Battle::Battler) && Battle::Battler.method_defined?(:tera_type)
  class Battle::Battler
    alias_method :aai_compat_battler_tera_type, :tera_type unless method_defined?(:aai_compat_battler_tera_type) || private_method_defined?(:aai_compat_battler_tera_type)
    def tera_type
      aai_compat_battler_tera_type
    end
    
    if method_defined?(:unTera)
      alias_method :aai_compat_unTera, :unTera unless method_defined?(:aai_compat_unTera) || private_method_defined?(:aai_compat_unTera)
      def unTera(teraBreak = false)
        aai_compat_unTera(teraBreak)
      end
    end
  end
  
  AdvancedAI.log("DBK Battle::Battler#tera_type compatibility patch applied", "Compatibility")
end

if defined?(Battle::Battler) && Battle::Battler.method_defined?(:hasTera?)
  class Battle::Battler
    alias_method :aai_compat_hasTera?, :hasTera? unless method_defined?(:aai_compat_hasTera?) || private_method_defined?(:aai_compat_hasTera?)
    def hasTera?(check_available = true)
      if wild? && @pokemon&.respond_to?(:tera_type) && @pokemon.tera_type && !@pokemon.tera_type.nil?
        return false if shadowPokemon?
        return false if @battle.raidBattle? && @battle.raidRules[:style] != :Tera
        return false if @pokemon.respond_to?(:hasTerastalForm?) && @pokemon.hasTerastalForm? && @effects[PBEffects::Transform]
        return false if @effects[PBEffects::TransformPokemon]&.respond_to?(:hasTerastalForm?) && @effects[PBEffects::TransformPokemon]&.hasTerastalForm?
        return false if !getActiveState.nil?
        
        if respond_to?(:hasEligibleAction?)
           return false if hasEligibleAction?(:mega, :primal, :zmove, :ultra, :dynamax, :style, :zodiac)
        end

        side  = self.idxOwnSide
        owner = @battle.pbGetOwnerIndexFromBattlerIndex(@index)
        if @battle.respond_to?(:terastallize) && @battle.terastallize
           return false if check_available && @battle.terastallize[side][owner] == -2
        end
        return true
      end
      
      aai_compat_hasTera?(check_available)
    end

    def tera?
      return @pokemon&.tera?
    end

    def dynamax?
      return @pokemon&.dynamax?
    end
    
    # Trainer Tera types may exist even when terastal_able? is false.
    def tera_type
      return nil if !@pokemon
      if !wild?
        stored_tera = @pokemon.instance_variable_get(:@tera_type)
        return stored_tera if stored_tera
      end
      return @pokemon.tera_type
    end
  end
  
  AdvancedAI.log("DBK Terastallization compatibility patch applied", "Compatibility")
end

if defined?(Battle) && Battle.method_defined?(:pbCanTerastallize?)
  class Battle
    alias_method :aai_compat_pbCanTerastallize?, :pbCanTerastallize? unless method_defined?(:aai_compat_pbCanTerastallize?) || private_method_defined?(:aai_compat_pbCanTerastallize?)
    def pbCanTerastallize?(idxBattler)
      battler = @battlers[idxBattler]
      
      if battler.wild?
         return false unless battler.pokemon.respond_to?(:explicit_tera_type) && battler.pokemon.explicit_tera_type

         return false if !battler.hasTera?
         return false if battler.tera?

         side  = battler.idxOwnSide
         owner = pbGetOwnerIndexFromBattlerIndex(idxBattler)
         if @terastallize
            return true if @terastallize[side][owner] == -1
         else
            return true
         end
         
         return false
      end
      
      return aai_compat_pbCanTerastallize?(idxBattler)
    end
  end
  
  #=============================================================================
  # Patch [DBK] Enhanced Battle UI to allow Wild Tera Icons
  #=============================================================================
  if defined?(Battle::Scene) && Battle::Scene.method_defined?(:pbAddTypesDisplay)
    class Battle::Scene
      # This copied method changes DBK's wild-Pokemon Tera check in place.
      def pbAddTypesDisplay(xpos, ypos, battler, poke)
        return unless battler && poke
        
        #---------------------------------------------------------------------------
        # Gets display types (considers Illusion)
        illusion = battler.effects[PBEffects::Illusion] && !battler.pbOwnedByPlayer?
        
        is_tera = battler.respond_to?(:tera?) && battler.tera?
        
        if is_tera
          displayTypes = (illusion) ? poke.types.clone : battler.pbPreTeraTypes
        elsif illusion
          displayTypes = poke.types.clone
          displayTypes.push(battler.effects[PBEffects::ExtraType]) if battler.effects[PBEffects::ExtraType]
        else
          displayTypes = battler.pbTypes(true)
        end
        #---------------------------------------------------------------------------
        # Displays the "???" type on newly encountered species, or battlers with no typing.
        if Settings::SHOW_TYPE_EFFECTIVENESS_FOR_NEW_SPECIES
          unknown_species = false
        else
          unknown_species = !(
            !@battle.internalBattle ||
            battler.pbOwnedByPlayer? ||
            $player.pokedex.owned?(poke.species) ||
            $player.pokedex.battled_count(poke.species) > 0
          )
        end
        displayTypes = [:QMARKS] if unknown_species || displayTypes.empty?
        #---------------------------------------------------------------------------
        # Draws each display type. Maximum of 3 types.
        typeY = (displayTypes.length >= 3) ? ypos + 6 : ypos + 34
        
        begin
          path = "Graphics/Battle/icon_types"
          if !pbResolveBitmap(path)
             path = "Graphics/UI/types"
          end
          typebitmap = AnimatedBitmap.new(_INTL(path))

          displayTypes.each_with_index do |type, i|
            break if i > 2
            type_number = GameData::Type.get(type).icon_position
            type_rect = Rect.new(0, type_number * 28, 64, 28)
            @enhancedUIOverlay.blt(xpos + 170, typeY + (i * 30), typebitmap.bitmap, type_rect)
          end
        rescue => e
          AdvancedAI.log("Error loading type icons (non-fatal): #{e.message}", "Compatibility")
        end

        #---------------------------------------------------------------------------
        # Draws Tera type.
        if is_tera
          showTera = true
        else
          showTera = false
          if battler.respond_to?(:tera_type) && battler.pokemon
             has_tera_type = battler.pokemon.respond_to?(:tera_type) && !battler.pokemon.tera_type.nil?
             is_able = battler.pokemon.respond_to?(:terastal_able?) && battler.pokemon.terastal_able?
             
             if is_able || (battler.wild? && has_tera_type)
               showTera = true
             end
          end
          
          showTera = ((@battle.internalBattle) ? !battler.opposes? : true) if showTera
        end
        
        if showTera
          pkmn = (illusion) ? poke : battler
          begin
            pbDrawImagePositions(@enhancedUIOverlay, [[@path + "info_extra", xpos + 182, ypos + 95]])
            pbDisplayTeraType(pkmn, @enhancedUIOverlay, xpos + 186, ypos + 97, true)
          rescue => e
             AdvancedAI.log("Error displaying Tera Type: #{e.message}", "Compatibility")
          end
        end
      end
    end
    AdvancedAI.log("DBK Enhanced Battle UI pbAddTypesDisplay compatibility patch applied", "Compatibility")
  end
  
  AdvancedAI.log("DBK pbCanTerastallize? compatibility patch applied", "Compatibility")
end

AdvancedAI.log("DBK Compatibility patches loaded", "Compatibility")
