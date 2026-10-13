#===============================================================================
# Advanced AI System - Settings & Configuration
# Version: 2.0
#===============================================================================

module AdvancedAI
  # ============================================================================
  # CORE SETTINGS
  # ============================================================================
  
  # Enable/Disable the entire system
  ENABLED = true
  
  # Auto-activate with Challenge Modes plugin (if installed)
  ACTIVATE_WITH_CHALLENGE_MODES = true
  
  # Minimum skill level for auto-activation
  MIN_SKILL_FOR_AUTO_ACTIVATION = 70
  
  # Debug mode - detailed logging in console
  DEBUG_MODE = false
  
  # Debug switch intelligence specifically (verbose logging)
  DEBUG_SWITCH_INTELLIGENCE = false
  
  # Show move explanations in battle text (e.g., "Thunder Wave (Paralyze fast threat)")
  SHOW_MOVE_EXPLANATIONS = true

  # Deterministic move choice. When true, AI always commits to the single
  # highest-scoring move (ties broken by move index, then target) instead of the
  # vanilla weighted-random pick among near-top moves. Makes the same situation
  # play out identically every time (useful for testing / bug repro). Default
  # false keeps the mild tie-break variety as a soft anti-exploit.
  DETERMINISTIC_MOVE_CHOICE = false

  # Deterministic switch DECISIONS for Advanced-AI-qualified trainers (the
  # "should I switch this turn?" question). The vanilla/Gen9/v21.1 ShouldSwitch
  # and ShouldNotSwitch handlers run alongside AAI's scored switch logic and
  # roll dice: "powerful super-effective foe move" triggers a switch 25-50% of
  # the time, a 50% roll randomly VETOES a switch the AI already decided on,
  # status-cure and Leech Seed switches roll 50-70%, etc. Net effect: the same
  # trainer in the same situation sometimes switches and sometimes doesn't,
  # even at skill 100. When true (default), those dice are suppressed for
  # qualified trainers — every chance-gated handler deterministically takes its
  # "no roll" branch, so the switch decision is fully reproducible and driven
  # by AAI's own scoring. Vanilla trainers below the AAI skill threshold are
  # unaffected. Set false to restore the old dice-rolling behaviour.
  DETERMINISTIC_SWITCH_LOGIC = true
  
  # Logging options
  LOG_TO_CONSOLE = false  # Enable only while investigating AI decisions
  LOG_TO_FILE = false     # Write logs to file (Logs/ai_log.txt)
  
  # ============================================================================
  # WILD POKEMON AI SETTINGS
  # ============================================================================
  
  # Enable smart AI for wild Pokemon (uses move scoring instead of random selection)
  ENABLE_WILD_POKEMON_AI = true
  
  # Enable intelligent lead selection for AI trainers
  # When true, AI trainers will pick an optimal lead Pokemon based on matchup
  # analysis instead of always sending out the first party member.
  # Requires the trainer's skill level to qualify for Advanced AI.
  ENABLE_LEAD_SELECTION = true
  
  # Skill level for wild Pokemon when AI is enabled (0-100)
  # 0     = Random moves (vanilla behavior)
  # Below MIN_SKILL_FOR_AUTO_ACTIVATION: native wild AI unless manually activated.
  # 70-84 = Advanced features  
  # 85-99 = Expert AI (items, patterns, personalities)
  # 100   = Master AI (Terastallization requires the matching DBK plugin)
  WILD_POKEMON_SKILL_LEVEL = 100
  
  # ============================================================================
  # SKILL LEVEL THRESHOLDS
  # ============================================================================
  
  # Defines which AI features are enabled at each skill level
  SKILL_THRESHOLDS = {
    :core              => 50,   # Core AI (Move Scoring, Memory, Threats)
    :switch_intelligence => 50, # Switch Intelligence (Type matchup analysis)
    :setup             => 55,   # Setup Recognition
    :endgame           => 60,   # Endgame Scenarios (1v1, 2v2)
    :personalities     => 65,   # Battle Personalities
    :items             => 85,   # Item Intelligence
    :prediction        => 85,   # Prediction System
    :mega_evolution    => 90,   # Mega Evolution Intelligence
    :z_moves           => 90,   # Z-Move Intelligence (DBK_004)
    :dynamax           => 95,   # Dynamax Intelligence (DBK_005)
    :terastallization  => 100   # Terastallization (DBK_006)
  }
  
  # Switch decision thresholds by AI mode (simplified to 3 tiers)
  # Higher threshold = Less likely to switch (Must be in more danger)
  SWITCH_THRESHOLDS = {
    :beginner => 65,  # Skill 0-60: Stays in until very dangerous
    :mid      => 55,  # Skill 61-85: Balanced switching
    :pro      => 45,  # Skill 86+: Aggressive but stable switching
    :extreme  => 35   # Skill 100 or tier override 4
  }
  
  # === ENHANCED DIFFICULTY FEATURES BY TIER ===
  # Tier switches gate their named scoring bonuses.
  # prediction_depth: 0 off, 1 next action, 2 two-action plans, 3 three-action plans.
  # learn_patterns controls anti-repeat and repeated-setup inference.
  TIER_FEATURES = {
    :beginner => {
      :switch_prediction   => false,
      :setup_detection     => false,
      :hazard_awareness    => false,
      :pivot_preference    => false,
      :recovery_timing     => false,
      :status_value        => 0.5,     # 50% status move value
      :prediction_depth    => 0,
      :learn_patterns      => false
    },
    :mid => {
      :switch_prediction   => true,
      :setup_detection     => true,
      :hazard_awareness    => true,
      :pivot_preference    => true,
      :recovery_timing     => true,
      :status_value        => 1.0,     # Full status move value
      :prediction_depth    => 1,
      :learn_patterns      => false
    },
    :pro => {
      :switch_prediction   => true,
      :setup_detection     => true,
      :hazard_awareness    => true,
      :pivot_preference    => true,
      :recovery_timing     => true,
      :status_value        => 1.2,     # 120% status move value
      :prediction_depth    => 2,
      :learn_patterns      => true
    },
    :extreme => {
      :switch_prediction   => true,
      :setup_detection     => true,
      :hazard_awareness    => true,
      :pivot_preference    => true,
      :recovery_timing     => true,
      :status_value        => 1.5,     # 150% status move value
      :prediction_depth    => 3,
      :learn_patterns      => true
    }
  }
  
  # ============================================================================
  # ADVANCED FLAGS (Bit Flags for Fine-Tuning)
  # ============================================================================
  
  # All flags below control their documented scoring bonuses.
  # Weather/terrain flags gate FieldEffects bonuses, not battle mechanics.
  # Example: 0b00000001 = Enable switch-ins prediction
  #          0b00000010 = Enable setup chain detection
  #          0b00000100 = Enable hazard calculations
  
  ADVANCED_FLAGS = {
    :switch_prediction    => 0b00000001,  # Predict opponent switches
    :setup_chains         => 0b00000010,  # Bonus for a usable counter against a Baton Pass chain
    :hazard_calc          => 0b00000100,  # Switch hazard costs/resistance; lethal-entry checks remain active
    :weather_abuse        => 0b00001000,  # Abuse weather conditions
    :terrain_abuse        => 0b00010000,  # Abuse terrain conditions
    :ko_prediction        => 0b00100000,  # Endgame KO/2HKO and partner-KO bonuses
    :revenge_kill         => 0b01000000,  # Belly Drum risk penalties
    :momentum_control     => 0b10000000   # Control battle momentum
  }
  
  # Enabled bits for get_setting.
  DEFAULT_FLAGS = 0b11111111
  
  # ============================================================================
  # PERSONALITY SETTINGS
  # ============================================================================
  
  # Auto-detect personality from team composition
  AUTO_DETECT_PERSONALITY = true
  
  # Personality modifiers (applied to move scores)
  PERSONALITY_MODIFIERS = {
    aggressive: { damage_bonus: 25, setup_penalty: -20, healing_penalty: -30, priority_bonus: 15, ohko_bonus: 40, coverage_bonus: 10, switch_threshold: 55 },
    defensive: { damage_bonus: -10, setup_bonus: 20, healing_bonus: 40, status_bonus: 30, protect_bonus: 35, hazard_bonus: 25, stall_bonus: 45, switch_threshold: 35 },
    balanced: { damage_bonus: 10, setup_bonus: 10, healing_bonus: 15, status_bonus: 15, pivot_bonus: 15, switch_threshold: 45 },
    hyper_offensive: { damage_bonus: 15, setup_bonus: 50, healing_penalty: -40, protect_bonus: 30, spread_bonus: 20, ohko_penalty: -20, switch_threshold: 60 },
  }
  # coverage_bonus scores non-STAB super-effective damage; switch_threshold adjusts the tier threshold.

  # ============================================================================
  # AI BEHAVIOR SETTINGS
  # ============================================================================
  
  # If true, the AI will respect the "ReserveLastPokemon" flag on trainers
  # preventing their ace (last Pokemon) from being switched in early
  RESPECT_RESERVE_LAST_POKEMON = true

  # Strict reserve rejects dominant-matchup exceptions and ace leads while
  # another able lead exists. Mandatory replacement can still use the ace
  # when it is the only legal reserve, including in multi battles.
  RESERVE_LAST_POKEMON_STRICT = false
  
  # Penalize additional sleep-status moves while an opponent is asleep.
  # Scoring preference only; this does not install an engine battle rule.
  ENFORCE_SLEEP_CLAUSE = true
  
  # ============================================================================
  # COMPATIBILITY SETTINGS
  # ============================================================================
  
  # DBK Plugin Integration
  DBK_PLUGINS = {
    :mega_evolution   => true,  # Core Essentials (Enhanced)
    :dynamax          => true,  # DBK_005 - Dynamax
    :terastallization => true,  # DBK_006 - Terastallization
    :z_moves          => true,  # DBK_004 - Z-Power
    :raid_battles     => true,  # DBK_003 - Raid Battles
    :sos_battles      => true   # DBK_002 - SOS Battles
  }
  
  # Dedicated Gen 9 move, switch-in and doubles bonuses; native mechanics stay active.
  GEN9_PACK_COMPAT = true
  
  # ============================================================================
  # HELPER METHODS
  # ============================================================================
  
  # Logging utility
  def self.log(message, source = "AAI")
    return unless DEBUG_MODE || LOG_TO_CONSOLE || LOG_TO_FILE
    
    safe_message = message.to_s
    stamp = Time.now.strftime("%H:%M:%S.%L") rescue "--:--:--.---"
    formatted = "[#{stamp}] [SC/AI      ] DEBUG #{source}: #{safe_message}"
    
    # Console output
    if DEBUG_MODE || LOG_TO_CONSOLE
      puts formatted
    end
    
    # File output
    if LOG_TO_FILE
      begin
        Dir.mkdir("Logs") unless Dir.exist?("Logs")
        File.open("Logs/ai_log.txt", "a") do |f|
          f.puts "[#{Time.now.strftime("%H:%M:%S")}] #{formatted}"
        end
      rescue SystemCallError, IOError
        # Silent fail if file writing fails
      end
    end
  end
  
  # Check if Advanced AI is active
  def self.active?(skill_level = nil)
    return false unless ENABLED
    return @manually_activated unless @manually_activated.nil?
    return true if mode_skill_override
    return true if DEBUG_MODE
    if ACTIVATE_WITH_CHALLENGE_MODES
      return true if defined?(ChallengeModes) && ChallengeModes.respond_to?(:on?) && ChallengeModes.on?
      return true if defined?(Settings::CHALLENGE_MODE) && Settings::CHALLENGE_MODE
    end
    return !skill_level.nil? && skill_level >= MIN_SKILL_FOR_AUTO_ACTIVATION
  end
  
  # Manually activate/deactivate
  def self.activate!
    @manually_activated = true
  end
  
  def self.deactivate!
    @manually_activated = false
  end
  
  # Check if skill level qualifies for Advanced AI
  # MIN_SKILL_FOR_AUTO_ACTIVATION (70) is only for automatic activation
  def self.qualifies_for_advanced_ai?(skill_level)
    return false unless skill_level && active?(skill_level)
    return skill_level >= SKILL_THRESHOLDS[:core]
  end
  
  # Game Variable ID that controls the AI Mode globally
  # 0 = Disabled (Use Skill Level logic)
  # 1 = Force Beginner Mode
  # 2 = Force Mid Mode
  # 3 = Force Pro Mode
  # 4 = Force Extreme Mode
  AI_MODE_VARIABLE = 100

  def self.mode_skill_override
    return nil unless defined?($game_variables) && $game_variables
    { 1 => 60, 2 => 80, 3 => 95, 4 => 100 }[$game_variables[AI_MODE_VARIABLE]]
  end
  
  # Get AI mode based on skill level (simplified to 3 tiers)
  def self.get_ai_tier(skill_level)
    # Check global variable override
    if defined?($game_variables) && $game_variables
      override = $game_variables[AI_MODE_VARIABLE]
      return :beginner if override == 1
      return :mid      if override == 2
      return :pro      if override == 3
      return :extreme  if override == 4  # New: Extreme difficulty
    end
    
    # Fallback to skill-based logic
    return :beginner if skill_level <= 60
    return :mid if skill_level <= 85
    return :pro if skill_level <= 99
    return :extreme  # Skill 100 = Extreme mode
  end
  
  # Get tier feature value
  def self.tier_feature(skill_level, feature)
    tier = get_ai_tier(skill_level)
    return TIER_FEATURES.dig(tier, feature)
  end

  def self.prediction_depth(skill_level)
    value = tier_feature(skill_level, :prediction_depth)
    value.is_a?(Numeric) ? value.to_i.clamp(0, 3) : 0
  end
  
  # Check if feature is enabled for skill level
  def self.feature_enabled?(feature, skill_level)
    threshold = SKILL_THRESHOLDS[feature]
    return false unless skill_level && threshold && active?(skill_level)
    return skill_level >= threshold
  end
  
  # Get setting value (with fallback)
  def self.get_setting(key, default = 0)
    flag = ADVANCED_FLAGS[key]
    return default unless flag
    return DEFAULT_FLAGS & flag
  end
  
  # Check if DBK plugin is enabled
  def self.dbk_enabled?(plugin)
    return false unless DBK_PLUGINS[plugin]
    
    # 1. Try PluginManager check (most reliable)
    if defined?(PluginManager) && PluginManager.respond_to?(:installed?)
      plugin_id = case plugin
        when :dynamax           then "[DBK] Dynamax"
        when :terastallization  then "[DBK] Terastallization"
        when :z_moves           then "[DBK] Z-Power"
        when :raid_battles      then "[DBK] Raid Battles"
        when :sos_battles       then "[DBK] SOS Battles"
        else nil
      end
      return true if plugin_id && PluginManager.installed?(plugin_id)
    end
    
    # 2. Fallback to method/constant checks
    case plugin
    when :mega_evolution
      return true # Built-in to Essentials, always available if item held
    when :dynamax
      # Check if Dynamax methods exist (more reliable than constants)
      return defined?(Battle) && Battle.instance_methods.include?(:pbCanDynamax?)
    when :terastallization
      # Check if Terastallization methods exist
      return defined?(Battle) && Battle.instance_methods.include?(:pbCanTerastallize?)
    when :z_moves
      return defined?(Battle) && Battle.instance_methods.include?(:pbCanZMove?)
    when :raid_battles
      return defined?(Battle) && Battle.instance_methods.include?(:pbRaidBattle?)
    when :sos_battles
      return defined?(Battle) && Battle.instance_methods.include?(:pbSOSBattle?)
    else
      return false
    end
  end
end

#===============================================================================
# Battle Integration
#===============================================================================

class Battle
  attr_accessor :advanced_ai_active
  attr_accessor :trainer_personalities
  
  alias_method :aai_initialize, :initialize unless method_defined?(:aai_initialize) || private_method_defined?(:aai_initialize)
  def initialize(*args)
    aai_initialize(*args)
    @advanced_ai_active = false
    @trainer_personalities = {}
  end
  
  # Check if trainer uses Advanced AI
  def uses_advanced_ai?(trainer_index)
    return false unless trainer_index
    trainer = pbGetOwnerFromBattlerIndex(trainer_index)
    return false unless trainer
    skill = AdvancedAI.mode_skill_override || trainer.skill_level || 50
    return AdvancedAI.qualifies_for_advanced_ai?(skill)
  end
  
  # Get/Set trainer personality
  def get_trainer_personality(trainer_index)
    AdvancedAI.get_personality(self, trainer_index)
  end
  
  def set_trainer_personality(trainer_index, personality)
    @trainer_personalities[trainer_index] = personality
    AdvancedAI.log("Trainer #{trainer_index} personality set to #{personality}", "Personality")
  end
  
  private
  
  def detect_personality(trainer_index)
    return :balanced unless AdvancedAI::AUTO_DETECT_PERSONALITY
    AdvancedAI.detect_personality(self, trainer_index)
  end
end

#===============================================================================
# Skill Level Enhancement
#===============================================================================

class Battle::Battler
  # Enhanced skill level with AI tier
  def ai_skill_level
    return 0 unless @battle.opposes?(@index)
    trainer = @battle.pbGetOwnerFromBattlerIndex(@index)
    return 50 unless trainer
    return AdvancedAI.mode_skill_override || trainer.skill_level || 50
  end
  
  def ai_tier
    return AdvancedAI.get_ai_tier(ai_skill_level)
  end
end

#===============================================================================
# Challenge Mode Integration (Optional)
#===============================================================================

if defined?(Settings::CHALLENGE_MODE)
  EventHandlers.add(:on_start_battle, :advanced_ai_challenge_mode,
    proc { |battle|
      if Settings::CHALLENGE_MODE && AdvancedAI::ACTIVATE_WITH_CHALLENGE_MODES
        battle.advanced_ai_active = true
        AdvancedAI.log("Advanced AI activated via Challenge Mode", "Core")
      end
    }
  )
end
