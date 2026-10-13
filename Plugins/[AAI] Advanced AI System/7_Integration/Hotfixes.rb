#===============================================================================
# [000] Hotfixes - Compatibility Patches
#===============================================================================
# Fixes compatibility issues with DBK Plugins and Essentials Core
# This file is loaded BEFORE all other Advanced AI modules ([000])
#===============================================================================

#===============================================================================
# DBK Wonder Launcher Compatibility
#===============================================================================

class Battle
  def launcherBattle?
    return @launcherBattle if instance_variable_defined?(:@launcherBattle)
    return false
  end unless method_defined?(:launcherBattle?)
end

class Battle::AI
  def launcherBattle?
    return false unless @battle
    return @battle.launcherBattle? if @battle.respond_to?(:launcherBattle?)
    return false
  end
end

AdvancedAI.log("Wonder Launcher bridge ready", "Compatibility")

#===============================================================================
# DBK Improved Item AI Hotfix
#===============================================================================

if defined?(Battle::AI::AIMove)
  class Battle::AI::AIMove
    attr_reader :move
    
    alias original_battler battler if method_defined?(:battler) && !method_defined?(:original_battler)
    
    def battler
      return original_battler if respond_to?(:original_battler)
      return @battler if instance_variable_defined?(:@battler)
      return nil
    end
    
    # Mirror Battle::Move's category API.
    def physical?
      return @move.physicalMove? if @move && @move.respond_to?(:physicalMove?)
      return @move.physical? if @move && @move.respond_to?(:physical?)
      return false
    end
    
    def special?
      return @move.specialMove? if @move && @move.respond_to?(:specialMove?)
      return @move.special? if @move && @move.respond_to?(:special?)
      return false
    end
    
    def status?
      return @move.statusMove? if @move && @move.respond_to?(:statusMove?)
      return @move.status? if @move && @move.respond_to?(:status?)
      return false
    end
    
    def damagingMove?
      return @move.damagingMove? if @move && @move.respond_to?(:damagingMove?)
      return !status?
    end
    
    def statusMove?
      return @move.statusMove? if @move && @move.respond_to?(:statusMove?)
      return status?
    end

    # Forward the rest of the move API.
    def method_missing(method_name, *args, &block)
      if @move && @move.respond_to?(method_name)
        return @move.send(method_name, *args, &block)
      end
      super
    end

    def respond_to_missing?(method_name, include_private = false)
      (@move && @move.respond_to?(method_name, include_private)) || super
    end
  end
end

#===============================================================================
# AIBattler Compatibility
#===============================================================================

if defined?(Battle::AI::AIBattler)
  class Battle::AI::AIBattler
    def hasActiveAbility?(ability)
      return @battler.hasActiveAbility?(ability) if @battler
      return false
    end
    
    def hasActiveItem?(item)
      return @battler.hasActiveItem?(item) if @battler
      return false
    end
    
    # Mirror Battle::Battler stat accessors used by AAI scoring.
    def attack;  return @battler.attack  if @battler; 0; end
    def defense; return @battler.defense if @battler; 0; end
    def spatk;   return @battler.spatk   if @battler; 0; end
    def spdef;   return @battler.spdef   if @battler; 0; end
    def speed;   return @battler.speed   if @battler; 0; end
    def pbSpeed; return @battler.pbSpeed if @battler; 0; end
    
    # Forward remaining Battle::Battler calls.
    def method_missing(method, *args, &block)
      if @battler && @battler.respond_to?(method)
        return @battler.send(method, *args, &block)
      end
      super
    end
    
    def respond_to_missing?(method, include_private = false)
      (@battler && @battler.respond_to?(method, include_private)) || super
    end
  end
end

#===============================================================================
# Essentials Core Effectiveness Hotfix
#===============================================================================

module Effectiveness
  @recursion_depth = 0
  MAX_RECURSION_DEPTH = 10
  
  class << self
    alias original_calculate calculate if method_defined?(:calculate) && !method_defined?(:original_calculate)
    
    def calculate(attack_type, *target_types)
      return NORMAL_EFFECTIVE_MULTIPLIER if !attack_type
      target_types = target_types.compact
      return NORMAL_EFFECTIVE_MULTIPLIER if target_types.empty?
      
      @recursion_depth ||= 0
      @recursion_depth += 1
      
      if @recursion_depth > MAX_RECURSION_DEPTH
        @recursion_depth = 0
        return NORMAL_EFFECTIVE_MULTIPLIER
      end
      
      result = original_calculate(attack_type, *target_types)
      @recursion_depth -= 1
      return result
    rescue StandardError => e
      @recursion_depth = 0
      echoln "[Advanced AI] Effectiveness calculation error: #{e.message}" if defined?(echoln)
      return NORMAL_EFFECTIVE_MULTIPLIER
    end
  end
end

# GameData::Type recursion guard
if defined?(GameData::Type)
  module GameData
    class Type
      @type_recursion_depth = 0
      MAX_TYPE_RECURSION = 10
      
      class << self
        if method_defined?(:calculate)
          alias original_type_calculate calculate unless method_defined?(:original_type_calculate)
          
          def calculate(attack_type, *target_types)
            @type_recursion_depth ||= 0
            @type_recursion_depth += 1
            
            if @type_recursion_depth > MAX_TYPE_RECURSION
              @type_recursion_depth = 0
              return Effectiveness::NORMAL_EFFECTIVE_MULTIPLIER
            end
            
            result = original_type_calculate(attack_type, *target_types)
            @type_recursion_depth -= 1
            return result
          rescue StandardError => e
            @type_recursion_depth = 0
            echoln "[Advanced AI] Type calculation error: #{e.message}" if defined?(echoln)
            return Effectiveness::NORMAL_EFFECTIVE_MULTIPLIER
          end
        end
      end
    end
  end
end

#===============================================================================
# Missing Method Shims
#===============================================================================

# Effectiveness.calculate_one returns the multiplier for one defending type.
module Effectiveness
  module_function

  def calculate_one(attack_type, defend_type)
    get_type_effectiveness(attack_type, defend_type) / NORMAL_EFFECTIVE.to_f
  end
end

# Match the Battle::Move category method names.
class GameData::Move
  def physicalMove?
    self.physical?
  end

  def specialMove?
    self.special?
  end

  def statusMove?
    self.status?
  end

  def damagingMove?
    self.damaging?
  end
end

# Alias expected by Tactical_Enhancements.rb.
module AdvancedAI
  module StrategicAwareness
    def self.battle_state(battle)
      get_state(battle)
    end
  end
end

AdvancedAI.log("Wonder Launcher, Item AI and type-effectiveness fixes ready", "Compatibility")

#===============================================================================
# Choice-lock + no-PP Struggle handling
#===============================================================================
# Bypass the Fight menu so pbAutoChooseMove can select Struggle.
# prepend keeps the check ahead of DBK's later command-menu definition.
module AAI_ChoiceLockStruggleFix
  def pbCanShowFightMenu?(idxBattler)
    battler = @battlers[idxBattler]
    if battler && aai_choice_locked_out_of_pp?(battler)
      PBDebug.log("[AAI] #{battler.pbThis} is Choice-locked with no PP left -> forcing Struggle") if defined?(PBDebug)
      return false
    end
    super
  end

  # True only when the battler is Choice-locked (Choice item or Gorilla Tactics,
  # both stored in PBEffects::ChoiceBand) into a move it still owns whose PP is 0.
  def aai_choice_locked_out_of_pp?(battler)
    return false unless battler.respond_to?(:effects)
    locked_id = battler.effects[PBEffects::ChoiceBand]
    return false unless locked_id
    return false unless battler.pbHasMove?(locked_id)
    locked_move = battler.moves.find { |m| m && m.id == locked_id }
    return false unless locked_move
    # total_pp > 0 guard: only a real move that has been spent, never an empty
    # slot that natively reports 0 PP.
    locked_move.pp == 0 && locked_move.total_pp > 0
  end
end
Battle.prepend(AAI_ChoiceLockStruggleFix)

# Boot banner (debug only)
if AdvancedAI::DEBUG_MODE
  echoln "═══════════════════════════════════════════════════"
  echoln "[AAI] Advanced AI System v3.0.0 - DEBUG MODE ACTIVE"
  echoln "[AAI] Console output is working!"
  echoln "[AAI] Switch Intelligence Handler will be registered by [002] Core.rb"
  echoln "═══════════════════════════════════════════════════"
end

