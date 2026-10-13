#===============================================================================
# Advanced AI System - Mechanics Hooks
# Connects Intelligence Modules to Battle System
#===============================================================================

class Battle::AI
  #-----------------------------------------------------------------------------
  # Main Hook: Register Enemy Special Actions
  #-----------------------------------------------------------------------------
# prepend keeps this hook ahead of DBK definitions loaded later.

  def run_advanced_ai_special_actions(idxBattler)

    if @battle.wildBattle?
      AdvancedAI.log("Wild Pokemon battle detected", "Hooks")

      # Special wild modes remain DBK-controlled.
      if @battle.respond_to?(:wildBattleMode) && @battle.wildBattleMode
        AdvancedAI.log("Special wild battle mode detected (#{@battle.wildBattleMode}) - skipping AAI gimmick processing", "Hooks")
        return
      end
      
      unless AdvancedAI::ENABLE_WILD_POKEMON_AI
        AdvancedAI.log("Wild Pokemon AI is DISABLED", "Hooks")
        return
      end
      skill = AdvancedAI::WILD_POKEMON_SKILL_LEVEL
      AdvancedAI.log("Wild Pokemon - Using skill: #{skill}", "Hooks")
    else
      # Derive the trainer from the battler index to avoid stale @trainer state.
      trainer = @battle.pbGetOwnerFromBattlerIndex(idxBattler) rescue @trainer
      if trainer
        skill = trainer.skill_level
        AdvancedAI.log("Trainer battle - Skill: #{skill}", "Hooks")
      else
        skill = 100
        AdvancedAI.log("Unknown battle type - defaulting to skill 100", "Hooks")
      end
    end
    
    return unless AdvancedAI.qualifies_for_advanced_ai?(skill)
    
    battler = @battle.battlers[idxBattler]
    AdvancedAI.log("Qualified for Advanced AI - checking gimmicks for #{battler.name}", "Hooks")
    
    # Gimmick scorers expect a fresh AIBattler wrapper.
    ai_battler = Battle::AI::AIBattler.new(self, idxBattler) rescue battler
    
    # One gimmick per turn, in priority order.
    
    # --- MEGA EVOLUTION ---
    AdvancedAI.log("Checking Mega Evolution...", "Hooks")
    if AdvancedAI.feature_enabled?(:mega_evolution, skill) && should_mega_evolve?(ai_battler, skill)
      @battle.pbRegisterMegaEvolution(idxBattler)
      AdvancedAI.log("#{battler.name} registered Mega Evolution", "Hooks")
      return
    end
    
    # --- Z-MOVES ---
    AdvancedAI.log("Checking Z-Moves...", "Hooks")
    if AdvancedAI.feature_enabled?(:z_moves, skill) && should_z_move?(ai_battler, skill)
      @battle.pbRegisterZMove(idxBattler)
      AdvancedAI.log("#{battler.name} registered Z-Move", "Hooks")
      return
    end
    
    # --- DYNAMAX ---
    AdvancedAI.log("Checking Dynamax...", "Hooks")
    if AdvancedAI.feature_enabled?(:dynamax, skill) && should_dynamax?(ai_battler, skill)
      @battle.pbRegisterDynamax(idxBattler)
      AdvancedAI.log("#{battler.name} registered Dynamax", "Hooks")
      return
    end
    
    # --- TERASTALLIZATION ---
    AdvancedAI.log("Checking Terastallization...", "Hooks")
    if AdvancedAI.feature_enabled?(:terastallization, skill) && should_terastallize?(ai_battler, skill)
      @battle.pbRegisterTerastallize(idxBattler)
      AdvancedAI.log("#{battler.name} registered Terastallization", "Hooks")
      return
    end
  end
  
  #-----------------------------------------------------------------------------
  # Prepend-based hook: survives DBK overwriting pbRegisterEnemySpecialAction
  #-----------------------------------------------------------------------------
  module AAI_GimmickHook
    def pbRegisterEnemySpecialAction(idxBattler)
      # Recursion guard — Z-Power's alias cycles back into this prepended method
      return if @_aai_registering
      @_aai_registering = true
      begin
        battler = @battle.battlers[idxBattler]
        is_wild_with_gimmick = battler.wild? && (
          (battler.pokemon.respond_to?(:dynamax_lvl) && battler.pokemon.dynamax_lvl.to_i > 0) ||
          (battler.pokemon.respond_to?(:tera_type) && !battler.pokemon.tera_type.nil?)
        )

        if is_wild_with_gimmick
          AdvancedAI.log("Wild gimmick detected - skipping DBK auto-register for intelligent decision", "Hooks")
        else
          super if defined?(super)
        end

        run_advanced_ai_special_actions(idxBattler)
      ensure
        @_aai_registering = false
      end
    end
  end
  prepend AAI_GimmickHook
  
  #-----------------------------------------------------------------------------
  # Hook into pbChooseEnemyAction to trigger special action registration
  #-----------------------------------------------------------------------------
  if Battle::AI.instance_methods.include?(:pbChooseEnemyAction)
    alias_method :aai_pbChooseEnemyAction, :pbChooseEnemyAction unless method_defined?(:aai_pbChooseEnemyAction) || private_method_defined?(:aai_pbChooseEnemyAction)
    def pbChooseEnemyAction(idxBattler)
      pbRegisterEnemySpecialAction(idxBattler) if respond_to?(:pbRegisterEnemySpecialAction)

      aai_pbChooseEnemyAction(idxBattler)
    end
  end
end

AdvancedAI.log("Advanced AI Mechanics Hooks registered", "Hooks")
