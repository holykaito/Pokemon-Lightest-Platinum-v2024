#===============================================================================
# Advanced AI System - Mega Intelligence
# Logic for optimal Mega Evolution timing
#===============================================================================

class Battle::AI
  alias_method :aai_pbEnemyShouldMegaEvolve?, :pbEnemyShouldMegaEvolve? unless method_defined?(:aai_pbEnemyShouldMegaEvolve?)

  def pbEnemyShouldMegaEvolve?
    if @battle.wildBattle?
      return aai_pbEnemyShouldMegaEvolve? unless AdvancedAI::ENABLE_WILD_POKEMON_AI
      skill = AdvancedAI::WILD_POKEMON_SKILL_LEVEL
    else
      skill = (@trainer.instance_variable_get(:@aai_skill_override) rescue nil)
      skill ||= @trainer.skill if @trainer
    end
    return aai_pbEnemyShouldMegaEvolve? unless AdvancedAI.feature_enabled?(:mega_evolution, skill)
    should_mega_evolve?(@user, skill)
  rescue StandardError => e
    AdvancedAI.log("Mega evaluation failed: #{e.class}: #{e.message}", "Mega")
    aai_pbEnemyShouldMegaEvolve?
  end

  # Main entry point for checking Mega Evolution
  def should_mega_evolve?(user, skill)
    return false unless AdvancedAI.dbk_enabled?(:mega_evolution)
    return false unless user.can_mega_evolve?
    return false if user.mega?
    
    # Base score
    score = 0
    
    # 1. Stat Increase Value
    score += evaluate_mega_stats(user)
    
    # 2. Ability Change Value
    score += evaluate_mega_ability(user)
    
    # 3. Type Change Value
    score += evaluate_mega_type(user)
    
    # 4. Turn Context
    score += evaluate_mega_context(user, skill)
    
    AdvancedAI.log("Mega Eval for #{user.pbThis}: Score #{score}", "Mega")
    
    threshold = skill.to_i >= 100 ? 6 : 10
    return true if score >= threshold
    return true if user.hp <= user.totalhp * 0.5 && score > 0
    
    return false
  end
  
  private

  def mega_species_data(user)
    pokemon = user.respond_to?(:pokemon) ? user.pokemon : nil
    mega_form = pokemon ? (pokemon.getMegaForm rescue 0) : 0
    return nil if mega_form.to_i <= 0
    GameData::Species.get_species_form(user.species, mega_form)
  rescue
    nil
  end

  def evaluate_mega_stats(user)
    mega_data = mega_species_data(user)
    return 0 unless mega_data
    form = user.respond_to?(:form) ? user.form : 0
    current_data = GameData::Species.get_species_form(user.species, form)
    current_stats = current_data.base_stats
    mega_stats = mega_data.base_stats
    total_gain = mega_stats.values.sum - current_stats.values.sum
    speed_gain = mega_stats[:SPEED].to_i - current_stats[:SPEED].to_i
    offense_gain = [mega_stats[:ATTACK].to_i - current_stats[:ATTACK].to_i,
                    mega_stats[:SPECIAL_ATTACK].to_i - current_stats[:SPECIAL_ATTACK].to_i].max
    score = (total_gain / 15.0).round
    score += (speed_gain / 20.0).round if speed_gain > 0
    score += (offense_gain / 25.0).round if offense_gain > 0
    score
  rescue
    0
  end
  
  def evaluate_mega_ability(user)
    score = 0
    current_ability = user.respond_to?(:hasActiveAbility?) ? user.ability_id : nil
    
    mega_species = mega_species_data(user)
    if mega_species
      mega_abil = mega_species.abilities.first
      
      if mega_abil != current_ability
        # Weather setting abilities are high priority on turn 1
        if [:DRIZZLE, :DROUGHT, :SNOWWARNING, :SANDSTREAM].include?(mega_abil)
          score += 25
          # Don't override if we already have the weather we want
          weather = AdvancedAI::Utilities.current_weather(@battle)
          if (weather == :Sun && mega_abil == :DROUGHT) ||
             (weather == :Rain && mega_abil == :DRIZZLE) ||
             (weather == :Sandstorm && mega_abil == :SANDSTREAM) ||
             ([:Snow, :Hail].include?(weather) && mega_abil == :SNOWWARNING)
             score -= 20
          end
        end
        
        # Power boosts
        if [:HUGEPOWER, :PUREPOWER, :ADAPTABILITY, :TOUGHCLAWS].include?(mega_abil)
          score += 20
        end
        
        # Defensive
        if [:MAGICBOUNCE, :INTIMIDATE].include?(mega_abil)
          score += 15
        end
      end
    end

    if [:SPEEDBOOST, :REGENERATOR].include?(current_ability)
      score -= 6
    end
    
    return score
  end
  
  def evaluate_mega_type(user)
    mega_data = mega_species_data(user)
    return 0 unless mega_data
    current_types = user.respond_to?(:pbTypes) ? user.pbTypes(true) : user.pokemon.types
    mega_types = mega_data.types
    return 0 if current_types == mega_types

    incoming_types = []
    if @battle && user.respond_to?(:index)
      @battle.allOtherSideBattlers(user.index).each do |opponent|
        next unless opponent && !opponent.fainted?
        opponent.moves.each do |move|
          incoming_types << move.type if move && move.damagingMove?
        end
      end
    end
    return 0 if incoming_types.empty?

    old_risk = incoming_types.map { |type| Effectiveness.calculate(type, *current_types) }.max
    new_risk = incoming_types.map { |type| Effectiveness.calculate(type, *mega_types) }.max
    score = ((old_risk - new_risk).to_f / Effectiveness::NORMAL_EFFECTIVE_MULTIPLIER * 4).round
    [[score, -12].max, 12].min
  rescue
    0
  end
  
  def evaluate_mega_context(user, skill)
    score = 0
    score += 5 if user.hp <= user.totalhp * 0.5
    if @battle && user.respond_to?(:index)
      able = @battle.pbParty(user.index & 1).count { |pkmn| pkmn && pkmn.able? } rescue 2
      score += 3 if able <= 1
    end
    score
  end
end

class Battle::AI::AIBattler
  def can_mega_evolve?
    return @battler.can_mega_evolve? if @battler.respond_to?(:can_mega_evolve?)
    # Fallback: check via battle reference
    return false unless @battler && @battler.battle
    return @battler.battle.pbCanMegaEvolve?(@battler.index) rescue false
  end
  
  def mega?
    return @battler.mega? if @battler.respond_to?(:mega?)
    return false
  end
end
