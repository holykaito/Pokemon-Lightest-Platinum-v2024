#===============================================================================
# Advanced AI System - Z-Move Intelligence (DBK_004 Integration)
# Logic for optimal Z-Move usage
#===============================================================================

class Battle::AI
  Z_CRYSTAL_TYPES = {
    :NORMALIUMZ => :NORMAL, :FIRIUMZ => :FIRE, :WATERIUMZ => :WATER,
    :ELECTRIUMZ => :ELECTRIC, :GRASSIUMZ => :GRASS, :ICIUMZ => :ICE,
    :FIGHTINIUMZ => :FIGHTING, :POISONIUMZ => :POISON, :GROUNDIUMZ => :GROUND,
    :FLYINIUMZ => :FLYING, :PSYCHIUMZ => :PSYCHIC, :BUGINIUMZ => :BUG,
    :ROCKIUMZ => :ROCK, :GHOSTIUMZ => :GHOST, :DRAGONIUMZ => :DRAGON,
    :DARKINIUMZ => :DARK, :STEELIUMZ => :STEEL, :FAIRIUMZ => :FAIRY
  }
  SPECIAL_Z_CRYSTAL_MOVES = {
    :ALORAICHIUMZ => [:THUNDERBOLT], :DECIDIUMZ => [:SPIRITSHACKLE],
    :EEVIUMZ => [:LASTRESORT], :INCINIUMZ => [:DARKESTLARIAT],
    :KOMMONIUMZ => [:CLANGINGSCALES], :LUNALIUMZ => [:MOONGEISTBEAM],
    :LYCANIUMZ => [:STONEEDGE], :MARSHADIUMZ => [:SPECTRALTHIEF],
    :MEWNIUMZ => [:PSYCHIC], :MIMIKIUMZ => [:PLAYROUGH],
    :PIKANIUMZ => [:VOLTTACKLE], :PIKASHUNIUMZ => [:THUNDERBOLT],
    :PRIMARIUMZ => [:SPARKLINGARIA], :SNORLIUMZ => [:GIGAIMPACT],
    :SOLGANIUMZ => [:SUNSTEELSTRIKE], :TAPUNIUMZ => [:NATURESMADNESS],
    :ULTRANECROZIUMZ => [:PHOTONGEYSER]
  }

  # Main entry point for checking Z-Moves usage
  def should_z_move?(user, skill)
    return false unless AdvancedAI.dbk_enabled?(:z_moves)
    # Check if user can use Z-Moves (uses fixed helper method)
    return false unless user.can_z_move?
    
    score = 0
    
    # 1. Damage Potential (OHKO check)
    score += evaluate_z_move_damage(user, skill)
    
    # 2. Status Z-Move Value
    score += evaluate_z_move_status(user)
    
    AdvancedAI.log("Z-Move Eval for #{user.pbThis}: Score #{score}", "Z-Move")
    
    # Thresholds
    return true if score >= 40   # Excellent opportunity (OHKO)
    return true if score >= 20 && user.hp <= user.totalhp * 0.3 # Desperation
    
    return false
  end
  
  private

  def z_move_compatible?(user, move)
    item = user.item_id rescue nil
    return false unless item
    crystal_type = Z_CRYSTAL_TYPES[item]
    if crystal_type
      return AdvancedAI::CombatUtilities.resolve_move_type(user, move) == crystal_type
    end
    required_moves = SPECIAL_Z_CRYSTAL_MOVES[item]
    return required_moves.include?(move.id) if required_moves

    item_data = GameData::Item.try_get(item) rescue nil
    return false unless item_data && item_data.respond_to?(:has_flag?) && item_data.has_flag?("ZCrystal")
    move_data = GameData::Move.try_get(move.id) rescue nil
    move_data && move_data.respond_to?(:z_power) && move_data.z_power.to_i > 0
  end

  def z_move_base_power(move, user, target)
    power = AdvancedAI::CombatUtilities.resolve_move_power(move, user, target).to_i
    return 0 if power <= 0
    return 100 if power <= 55
    return 120 if power <= 60
    return 140 if power <= 70
    return 160 if power <= 100
    return 185 if power <= 110
    return 190 if power <= 125
    return 195 if power <= 130
    200
  end
  
  def evaluate_z_move_damage(user, skill)
    score = 0
    max_damage = 0

    user.moves.each do |move|
      next unless move.damagingMove?
      next unless z_move_compatible?(user, move)
      @battle.allOtherSideBattlers(user.index).each do |target|
        next unless target && !target.fainted?

        z_power = z_move_base_power(move, user, target)
        rough_dmg = calculate_rough_damage(move, user, target, z_power)

        if rough_dmg >= target.hp
          score = 50
          AdvancedAI.log("Z-Move KO predicted vs #{target.name}", "Z-Move")
          return score
        end

        if rough_dmg > max_damage
          max_damage = rough_dmg
        end
      end
    end
    
    # If no KO, but high damage
    if max_damage > 0
      score += 15
    end
    
    return score
  end
  
  def evaluate_z_move_status(user)
    score = 0
    user.moves.each do |move|
      next unless move.statusMove?
      next unless z_move_compatible?(user, move)
      if move.id == :SPLASH
        score = [score, 30].max
      end

      if move.id == :BELLYDRUM
        score = [score, 30].max
      end

      if [:CELEBRATE, :HAPPYHOUR, :CONVERSION, :GEOMANCY].include?(move.id)
        score = [score, 25].max
      end
    end
    return score
  end
end

class Battle::Battler
  def can_z_move?
    # Check if we have a Z-Crystal held and appropriate move
    # Use the DBK method directly
    return @battle.pbCanZMove?(@index) if @battle.respond_to?(:pbCanZMove?)
    return false
  end
end

class Battle::AI::AIBattler
  def can_z_move?
    return @battler.can_z_move? if @battler.respond_to?(:can_z_move?)
    # Fallback: check via battle reference
    return false unless @battler && @battler.battle
    return @battler.battle.pbCanZMove?(@battler.index) rescue false
  end
end
