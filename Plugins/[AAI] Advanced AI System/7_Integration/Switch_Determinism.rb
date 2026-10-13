#===============================================================================
# Advanced AI System - Deterministic Switch Decisions
# Qualified trainers get deterministic rolls while switch handlers are checked.
# Conditional handlers and trainers below the AAI threshold keep normal behavior.
#===============================================================================

class Battle::AI
  alias_method :aai_dice_pbChooseToSwitchOut, :pbChooseToSwitchOut unless method_defined?(:aai_dice_pbChooseToSwitchOut) || private_method_defined?(:aai_dice_pbChooseToSwitchOut)

  def pbChooseToSwitchOut(terrible_moves = false)
    suppress = defined?(AdvancedAI::DETERMINISTIC_SWITCH_LOGIC) &&
               AdvancedAI::DETERMINISTIC_SWITCH_LOGIC && @trainer
    if suppress
      skill = (@trainer.instance_variable_get(:@aai_skill_override) rescue nil) || @trainer.skill
      suppress = AdvancedAI.qualifies_for_advanced_ai?(skill)
    end
    return aai_dice_pbChooseToSwitchOut(terrible_moves) unless suppress
    @aai_suppress_decision_dice = true
    begin
      aai_dice_pbChooseToSwitchOut(terrible_moves)
    ensure
      @aai_suppress_decision_dice = false
    end
  end

  alias_method :aai_dice_pbAIRandom, :pbAIRandom unless method_defined?(:aai_dice_pbAIRandom) || private_method_defined?(:aai_dice_pbAIRandom)

  def pbAIRandom(x)
    return [x.to_i - 1, 0].max if @aai_suppress_decision_dice
    aai_dice_pbAIRandom(x)
  end
end
