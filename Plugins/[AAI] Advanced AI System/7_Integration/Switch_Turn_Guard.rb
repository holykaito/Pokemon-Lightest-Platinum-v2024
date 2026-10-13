module AAI_SwitchTurnGuard
  def pbChooseToSwitchOut(terrible_moves = false)
    skill = @trainer && (@trainer.instance_variable_get(:@aai_skill_override) || @trainer.skill)
    return super unless skill && AdvancedAI.qualifies_for_advanced_ai?(skill)
    battler = @user && @battle.battlers[@user.index]
    last = (@aai_last_voluntary_switch || {})[@user.index] if @user
    opponents = battler && @battle.allOtherSideBattlers(battler.index).map { |b| [b.pokemon, b.form] }
    if battler && last && last[0] == @battle.turnCount - 1 &&
       last[1] == battler.pokemon && last[2] == opponents && !battler.fainted? &&
       battler.effects[PBEffects::PerishSong] != 1 &&
       battler.moves.each_index.any? { |i| @battle.pbCanChooseMove?(battler.index, i, false) }
      return false
    end
    result = super
    if result && battler && @battle.choices[battler.index][0] == :SwitchOut
      @aai_last_voluntary_switch ||= {}
      destination = @battle.choices[battler.index][1]
      @aai_last_voluntary_switch[battler.index] = [@battle.turnCount, @battle.pbParty(battler.index)[destination], opponents]
    end
    result
  end
end
Battle::AI.prepend(AAI_SwitchTurnGuard)
