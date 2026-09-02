#===============================================================================
# Marshal Damage Reduction
# Khi $marshalDamageReduction = true:
# - Pokemon bên đối thủ, tức bên Marshal, giảm 25% sát thương nhận từ đòn đánh.
# - Nghĩa là chỉ nhận 75% damage.
# - Không ảnh hưởng burn, poison, weather, hazard, recoil...
#===============================================================================

$marshalDamageReduction = false if !defined?($marshalDamageReduction)

class Battle::Move
  alias marshal_damage_reduction_pbCalcDamageMultipliers pbCalcDamageMultipliers unless method_defined?(:marshal_damage_reduction_pbCalcDamageMultipliers)

  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    marshal_damage_reduction_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)

    return if !$marshalDamageReduction
    return if !target
    return if target.fainted?
    return if target.pbOwnedByPlayer?
    return if multipliers[:marshal_damage_reduction_applied]

    # Pokemon của Marshal giảm 80% sát thương nhận vào.
    # Tức damage cuối còn 80%.
    multipliers[:final_damage_multiplier] *= 0.8
    multipliers[:marshal_damage_reduction_applied] = true
  end
end


#===============================================================================
# Shauntal Evasion Boost
# Khi $shauntalEvasionBoost = true:
# - Pokemon bên đối thủ, tức bên Shauntal, được tăng 15% evasion.
# - Không dùng setBattleRule nên không bị lỗi "Battle rule does not exist".
#===============================================================================

$shauntalEvasionBoost = false if !defined?($shauntalEvasionBoost)

module Battle::AbilityEffects
  class << self
    alias shauntal_evasion_triggerAccuracyCalcFromTarget triggerAccuracyCalcFromTarget unless method_defined?(:shauntal_evasion_triggerAccuracyCalcFromTarget)

    def triggerAccuracyCalcFromTarget(ability, mods, user, target, move, type)
      shauntal_evasion_triggerAccuracyCalcFromTarget(ability, mods, user, target, move, type)

      return if !$shauntalEvasionBoost
      return if !target
      return if target.fainted?
      return if target.pbOwnedByPlayer?
      return if mods[:shauntal_evasion_boost_applied]

      # Pokemon của Shauntal tăng 15% evasion.
      mods[:evasion_multiplier] *= 1.15
      mods[:shauntal_evasion_boost_applied] = true
    end
  end
end

#===============================================================================
# Grimsley Random Entrance
# Khi $grimsleyRandomEntrance = true:
# - Mỗi Pokemon bên đối thủ khi vào sân lần đầu nhận ngẫu nhiên 1 hiệu ứng:
#   1. Attack +1
#   2. Defense +1 và Special Defense +1
#   3. Evasion +1
#   4. Critical Hit ratio +1
# - Không thay ability thật.
# - Mỗi Pokemon chỉ kích hoạt 1 lần.
#===============================================================================

$grimsleyRandomEntrance = false if !defined?($grimsleyRandomEntrance)

class Battle::Battler
  def pbGrimsleyRandomEntrance
    return if !$grimsleyRandomEntrance
    return if self.pbOwnedByPlayer?
    return if self.fainted?
    return if !self.pokemon
    return if self.pokemon.instance_variable_get(:@grimsley_random_entrance_used)

    self.pokemon.instance_variable_set(:@grimsley_random_entrance_used, true)

    @battle.pbDisplay(_INTL("Grimsley's gamble begins!"))

    case @battle.pbRandom(4)
    when 0
      @battle.pbDisplay(_INTL("The gamble strengthened {1}'s attack!", self.pbThis(true)))
      if self.pbCanRaiseStatStage?(:ATTACK, self)
        self.pbRaiseStatStageByCause(:ATTACK, 1, self, "Grimsley's gamble")
      end

    when 1
      @battle.pbDisplay(_INTL("The gamble fortified {1}'s defenses!", self.pbThis(true)))
      show_anim = true
      if self.pbCanRaiseStatStage?(:DEFENSE, self)
        self.pbRaiseStatStageByCause(:DEFENSE, 1, self, "Grimsley's gamble", show_anim)
        show_anim = false
      end
      if self.pbCanRaiseStatStage?(:SPECIAL_DEFENSE, self)
        self.pbRaiseStatStageByCause(:SPECIAL_DEFENSE, 1, self, "Grimsley's gamble", show_anim)
      end

    when 2
      @battle.pbDisplay(_INTL("The gamble made {1} harder to hit!", self.pbThis(true)))
      if self.pbCanRaiseStatStage?(:EVASION, self)
        self.pbRaiseStatStageByCause(:EVASION, 1, self, "Grimsley's gamble")
      end

    when 3
      @battle.pbDisplay(_INTL("The gamble sharpened {1}'s focus!", self.pbThis(true)))
      if self.effects[PBEffects::FocusEnergy] < 3
        begin
          @battle.pbCommonAnimation("FocusEnergy", self)
        rescue
          @battle.pbCommonAnimation("StatUp", self)
        end
        self.effects[PBEffects::FocusEnergy] += 1
        @battle.pbDisplay(_INTL("{1}'s critical-hit ratio rose!", self.pbThis))
      end
    end
  end
end

class Battle
  alias grimsley_random_entrance_pbOnBattlerEnteringBattle pbOnBattlerEnteringBattle unless method_defined?(:grimsley_random_entrance_pbOnBattlerEnteringBattle)

  def pbOnBattlerEnteringBattle(*args)
    ret = grimsley_random_entrance_pbOnBattlerEnteringBattle(*args)

    battler = nil
    if args[0].is_a?(Battle::Battler)
      battler = args[0]
    elsif args[0].is_a?(Integer)
      battler = @battlers[args[0]]
    elsif args[0].respond_to?(:to_i)
      battler = @battlers[args[0].to_i]
    end

    battler.pbGrimsleyRandomEntrance if battler && battler.respond_to?(:pbGrimsleyRandomEntrance)

    return ret
  end

  alias grimsley_random_entrance_pbOnAllBattlersEnteringBattle pbOnAllBattlersEnteringBattle unless method_defined?(:grimsley_random_entrance_pbOnAllBattlersEnteringBattle)

  def pbOnAllBattlersEnteringBattle(*args)
    ret = grimsley_random_entrance_pbOnAllBattlersEnteringBattle(*args)

    if $grimsleyRandomEntrance
      @battlers.each do |b|
        next if !b || b.fainted?
        b.pbGrimsleyRandomEntrance if b.respond_to?(:pbGrimsleyRandomEntrance)
      end
    end

    return ret
  end
end

#===============================================================================
# Caitlin Trick Room AI
# Khi $caitlinTrickRoomAI = true:
# - Nếu Musharna của Caitlin đang ra sân và chưa có Trick Room:
#   Musharna bắt buộc chọn Trick Room nếu có thể dùng.
# - Nếu đang có Trick Room:
#   ưu tiên switch/send-in Musharna, Hatterene hoặc Calyrex.
# - Nếu chưa có Trick Room:
#   ưu tiên switch/send-in Gallade hoặc Reuniclus.
#===============================================================================

$caitlinTrickRoomAI = false if !defined?($caitlinTrickRoomAI)

class Battle::AI
  alias caitlin_trick_room_ai_pbDefaultChooseEnemyCommand pbDefaultChooseEnemyCommand unless method_defined?(:caitlin_trick_room_ai_pbDefaultChooseEnemyCommand)
  alias caitlin_trick_room_ai_pbChooseToSwitchOut pbChooseToSwitchOut unless method_defined?(:caitlin_trick_room_ai_pbChooseToSwitchOut)
  alias caitlin_trick_room_ai_choose_best_replacement_pokemon choose_best_replacement_pokemon unless method_defined?(:caitlin_trick_room_ai_choose_best_replacement_pokemon)

  #-----------------------------------------------------------------------------
  # 1. Ép Musharna dùng Trick Room nếu chưa có Trick Room.
  #-----------------------------------------------------------------------------
  def pbDefaultChooseEnemyCommand(idxBattler)
    if $caitlinTrickRoomAI
      set_up(idxBattler)
      battler = @battle.battlers[idxBattler]

      if battler &&
         !@battle.pbOwnedByPlayer?(idxBattler) &&
         !battler.fainted? &&
         battler.isSpecies?(:MUSHARNA) &&
         !caitlin_trick_room_active?
        trick_room_index = -1

        battler.eachMoveWithIndex do |move, i|
          next if !move || move.id != :TRICKROOM
          next if !@battle.pbCanChooseMove?(idxBattler, i, false)
          trick_room_index = i
          break
        end

        if trick_room_index >= 0
          @battle.pbRegisterMove(idxBattler, trick_room_index, false)
          PBDebug.log_ai("#{battler.pbThis} is forced to use Trick Room by Caitlin's AI.")
          return
        end
      end
    end

    caitlin_trick_room_ai_pbDefaultChooseEnemyCommand(idxBattler)
  end

  #-----------------------------------------------------------------------------
  # 2. Khi AI tự muốn switch trong lượt, ép ưu tiên đúng nhóm Pokémon.
  #-----------------------------------------------------------------------------
  def pbChooseToSwitchOut(terrible_moves = false)
    if $caitlinTrickRoomAI && @user && @user.battler
      battler = @user.battler

      if !@battle.pbOwnedByPlayer?(@user.index) &&
         @battle.canSwitch &&
         @battle.pbCanSwitchOut?(@user.index)

        preferred_species = caitlin_preferred_species
        current_species   = battler.pokemon&.species

        # Nếu Pokémon hiện tại không thuộc nhóm ưu tiên hiện tại,
        # tìm Pokémon dự bị thuộc nhóm ưu tiên để switch ra.
        if !preferred_species.include?(current_species)
          idx_party = caitlin_find_preferred_replacement(@user.index, preferred_species)

          if idx_party >= 0 && @battle.pbRegisterSwitch(@user.index, idx_party)
            pkmn_name = @battle.pbParty(@user.index)[idx_party].name
            PBDebug.log_ai("Caitlin's AI switches to #{pkmn_name} for Trick Room strategy.")
            return true
          end
        end
      end
    end

    return caitlin_trick_room_ai_pbChooseToSwitchOut(terrible_moves)
  end

  #-----------------------------------------------------------------------------
  # 3. Khi phải chọn Pokémon thay thế sau KO/forced switch,
  # ưu tiên nhóm Pokémon theo trạng thái Trick Room.
  #-----------------------------------------------------------------------------
  def choose_best_replacement_pokemon(idxBattler, terrible_moves = false)
    if $caitlinTrickRoomAI && !@battle.pbOwnedByPlayer?(idxBattler)
      idx_party = caitlin_find_preferred_replacement(idxBattler, caitlin_preferred_species)
      return idx_party if idx_party >= 0
    end

    return caitlin_trick_room_ai_choose_best_replacement_pokemon(idxBattler, terrible_moves)
  end

  #-----------------------------------------------------------------------------
  # Helper methods
  #-----------------------------------------------------------------------------
  def caitlin_trick_room_active?
    value = @battle.field.effects[PBEffects::TrickRoom]
    return value && value > 0
  end

  def caitlin_preferred_species
    if caitlin_trick_room_active?
      # Khi có Trick Room: ưu tiên các Pokémon tận dụng Trick Room.
      return [:MUSHARNA, :HATTERENE, :CALYREX]
    else
      # Khi chưa có Trick Room: ưu tiên Gallade/Reuniclus.
      return [:GALLADE, :REUNICLUS]
    end
  end

  def caitlin_find_preferred_replacement(idxBattler, species_list)
    party = @battle.pbParty(idxBattler)

    species_list.each do |species|
      party.each_with_index do |pkmn, i|
        next if !pkmn
        next if pkmn.egg?
        next if pkmn.species != species
        next if !@battle.pbCanSwitchIn?(idxBattler, i)
        return i
      end
    end

    return -1
  end
end

#===============================================================================
# Champion Alder Custom Battle
# Bật bằng: $alderChampionBattle = true
#
# Hiệu ứng hiện tại:
# - Tất cả Pokemon của Alder giảm 20% sát thương từ đòn đánh.
# - Accelgor vào sân: +1 Evasion, chạy hoạt ảnh Double Team.
# - Accelgor không tự switch out vì thấp máu.
# - Escavalier vào sân: +1 Defense.
# - Đã bỏ cơ chế Escavalier giảm damage ở hit đầu tiên.
# - Bouffalant có Max HP gấp đôi bình thường, giữ nguyên tỉ lệ HP hiện tại.
# - Bouffalant vào sân: +1 Attack.
# - Bouffalant cứ mất mỗi 10% HP tối đa thì giảm thêm 2% sát thương nhận vào.
# - Braviary vào sân: Speed tăng thêm 10%, không phải +1 stage.
# - Braviary của Alder bị KO: Pokemon đối phương mất 1/8 HP tối đa.
# - Khi Pokemon người chơi vào sân trong lúc Meloetta của Alder đang trên sân:
#   20% bị infatuated, bất kể giới tính.
# - Volcarona không còn tạo nắng khi vào sân.
# - Volcarona không còn hồi sinh 30% HP khi bị KO.
#===============================================================================

$alderChampionBattle = false if !defined?($alderChampionBattle)

#===============================================================================
# Damage modifiers
#===============================================================================
class Battle::Move
  alias alder_champion_pbCalcDamageMultipliers pbCalcDamageMultipliers unless method_defined?(:alder_champion_pbCalcDamageMultipliers)

  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    alder_champion_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)

    return if !$alderChampionBattle
    return if !target
    return if target.fainted?
    return if target.pbOwnedByPlayer?
    return if multipliers[:alder_champion_damage_applied]

    # Tất cả Pokemon của Alder giảm 20% sát thương nhận vào.
    multipliers[:final_damage_multiplier] *= 0.8

    # Bouffalant: mỗi 10% HP đã mất giảm thêm 2% sát thương nhận vào.
    # Ví dụ: đã mất 30% HP => giảm thêm 6% damage.
    if target.isSpecies?(:BOUFFALANT) && target.totalhp > 0
      hp_lost = target.totalhp - target.hp
      stacks = (hp_lost * 10 / target.totalhp).floor
      extra_reduction = stacks * 0.02

      # Giới hạn tối đa giảm thêm 50% để tránh damage về quá thấp.
      extra_reduction = 0.50 if extra_reduction > 0.50

      multipliers[:final_damage_multiplier] *= (1.0 - extra_reduction)
    end

    multipliers[:alder_champion_damage_applied] = true
  end
end

#===============================================================================
# Braviary: tăng 10% Speed bằng multiplier riêng, không dùng stat stage.
#===============================================================================
class Battle::Battler
  alias alder_champion_speed speed unless method_defined?(:alder_champion_speed)

  def speed
    base_speed = alder_champion_speed

    if $alderChampionBattle &&
       !self.pbOwnedByPlayer? &&
       self.isSpecies?(:BRAVIARY) &&
       self.pokemon &&
       self.pokemon.instance_variable_get(:@alder_braviary_speed_boost)
      return [(base_speed * 1.10).floor, 1].max
    end

    return base_speed
  end
end

#===============================================================================
# Entry effects
#===============================================================================
class Battle::Battler
  def pbAlderChampionEntryEffects
    return if !$alderChampionBattle
    return if self.fainted?
    return if !self.pokemon

    # Khi Pokemon người chơi vào sân, kiểm tra Meloetta.
    if self.pbOwnedByPlayer?
      pbAlderMeloettaInfatuation
      return
    end

    # Bouffalant: Max HP gấp đôi bình thường.
    # Đặt trước @alder_entry_effect_used để nếu Bouffalant switch lại vẫn đảm bảo HP đúng.
    if self.isSpecies?(:BOUFFALANT)
      pbAlderEnsureBouffalantDoubleHP
    end

    # Mỗi Pokemon của Alder chỉ nhận entry effect riêng 1 lần.
    return if self.pokemon.instance_variable_get(:@alder_entry_effect_used)

    if self.isSpecies?(:ACCELGOR)
      self.pokemon.instance_variable_set(:@alder_entry_effect_used, true)

      @battle.pbDisplay(_INTL("{1} blurred with incredible speed!", self.pbThis))

      begin
        @battle.pbAnimation(:DOUBLETEAM, self, self)
      rescue
        @battle.pbCommonAnimation("StatUp", self)
      end

      if self.pbCanRaiseStatStage?(:EVASION, self)
        self.pbRaiseStatStageByCause(:EVASION, 1, self, "Alder's strategy")
      end

    elsif self.isSpecies?(:ESCAVALIER)
      self.pokemon.instance_variable_set(:@alder_entry_effect_used, true)

      @battle.pbDisplay(_INTL("{1} braced its armor for battle!", self.pbThis))

      if self.pbCanRaiseStatStage?(:DEFENSE, self)
        self.pbRaiseStatStageByCause(:DEFENSE, 1, self, "Alder's strategy")
      end

    elsif self.isSpecies?(:BOUFFALANT)
      self.pokemon.instance_variable_set(:@alder_entry_effect_used, true)

      @battle.pbDisplay(_INTL("{1}'s reckless pride surged!", self.pbThis))

      if self.pbCanRaiseStatStage?(:ATTACK, self)
        self.pbRaiseStatStageByCause(:ATTACK, 1, self, "Alder's strategy")
      end

    elsif self.isSpecies?(:BRAVIARY)
      self.pokemon.instance_variable_set(:@alder_entry_effect_used, true)

      # Braviary: tăng 10% Speed, không phải +1 stage.
      self.pokemon.instance_variable_set(:@alder_braviary_speed_boost, true)
      @battle.pbDisplay(_INTL("{1}'s fighting spirit made it faster!", self.pbThis))

    elsif self.isSpecies?(:VOLCARONA)
      # Volcarona hiện không còn tạo nắng/hồi sinh.
      # Chỉ đánh dấu đã xử lý entry để tránh chạy lại.
      self.pokemon.instance_variable_set(:@alder_entry_effect_used, true)
    end
  end

  #-----------------------------------------------------------------------------
  # Bouffalant: Max HP gấp đôi bình thường.
  # Giữ nguyên tỉ lệ HP hiện tại, không tính là hồi máu miễn phí.
  #
  # Ví dụ:
  # 200/200 => 400/400
  # 100/200 => 200/400
  #-----------------------------------------------------------------------------
  def pbAlderEnsureBouffalantDoubleHP
    return if !self.isSpecies?(:BOUFFALANT)
    return if !self.pokemon

    old_totalhp = self.totalhp
    old_hp      = self.hp
    return if old_totalhp <= 0

    base_totalhp = self.pokemon.instance_variable_get(:@alder_bouffalant_base_totalhp)

    if !base_totalhp
      base_totalhp = old_totalhp
      self.pokemon.instance_variable_set(:@alder_bouffalant_base_totalhp, base_totalhp)
    end

    new_totalhp = base_totalhp * 2

    # Nếu battler hiện tại đã có đúng Max HP gấp đôi thì không cần làm gì.
    return if self.totalhp == new_totalhp

    hp_ratio = old_hp.to_f / old_totalhp
    new_hp   = [(new_totalhp * hp_ratio).round, 1].max

    self.instance_variable_set(:@totalhp, new_totalhp)
    self.instance_variable_set(:@hp, [new_hp, new_totalhp].min)

    @battle.scene.pbHPChanged(self) rescue nil
    @battle.pbDisplay(_INTL("{1}'s stamina became overwhelming!", self.pbThis))
  end

  #-----------------------------------------------------------------------------
  # Meloetta: 20% infatuated bất kể giới tính khi Pokemon người chơi vào sân.
  #-----------------------------------------------------------------------------
  def pbAlderMeloettaInfatuation
    attract_effect = self.effects[PBEffects::Attract] || -1
    return if attract_effect >= 0

    meloetta = nil

    @battle.allOtherSideBattlers(self.index).each do |b|
      next if !b
      next if b.fainted?
      next if !b.isSpecies?(:MELOETTA)
      meloetta = b
      break
    end

    return if !meloetta
    return if @battle.pbRandom(100) >= 20

    # Set trực tiếp để bỏ qua kiểm tra giới tính.
    self.effects[PBEffects::Attract] = meloetta.index

    begin
      @battle.pbCommonAnimation("Attract", self)
    rescue
      @battle.pbCommonAnimation("StatDown", self)
    end

    @battle.pbDisplay(_INTL("{1} became infatuated by Meloetta's captivating melody!", self.pbThis))
  end
end

#===============================================================================
# Hook entry effects
#===============================================================================
class Battle
  def pbAlderChampionRunEntryEffectFor(arg)
    return if !$alderChampionBattle

    battler = nil

    if arg.is_a?(Battle::Battler)
      battler = arg
    elsif arg.is_a?(Integer)
      battler = @battlers[arg]
    elsif arg.respond_to?(:to_i)
      battler = @battlers[arg.to_i]
    end

    battler.pbAlderChampionEntryEffects if battler && battler.respond_to?(:pbAlderChampionEntryEffects)
  end

  if method_defined?(:pbOnBattlerEnteringBattle) &&
     !method_defined?(:alder_champion_pbOnBattlerEnteringBattle)
    alias alder_champion_pbOnBattlerEnteringBattle pbOnBattlerEnteringBattle

    def pbOnBattlerEnteringBattle(*args)
      ret = alder_champion_pbOnBattlerEnteringBattle(*args)
      pbAlderChampionRunEntryEffectFor(args[0])
      return ret
    end
  end

  if method_defined?(:pbOnAllBattlersEnteringBattle) &&
     !method_defined?(:alder_champion_pbOnAllBattlersEnteringBattle)
    alias alder_champion_pbOnAllBattlersEnteringBattle pbOnAllBattlersEnteringBattle

    def pbOnAllBattlersEnteringBattle(*args)
      ret = alder_champion_pbOnAllBattlersEnteringBattle(*args)

      if $alderChampionBattle
        @battlers.each do |b|
          next if !b
          next if b.fainted?
          b.pbAlderChampionEntryEffects if b.respond_to?(:pbAlderChampionEntryEffects)
        end
      end

      return ret
    end
  end
end

#===============================================================================
# Braviary KO effect
# Khi Braviary của Alder bị KO, Pokemon đối phương mất 1/8 HP tối đa.
#===============================================================================
class Battle::Battler
  if method_defined?(:pbFaint) &&
     !method_defined?(:alder_braviary_ko_damage_pbFaint)

    alias alder_braviary_ko_damage_pbFaint pbFaint

    def pbFaint(*args)
      should_trigger_braviary_ko =
        $alderChampionBattle &&
        !self.pbOwnedByPlayer? &&
        self.isSpecies?(:BRAVIARY) &&
        self.pokemon &&
        !self.pokemon.instance_variable_get(:@alder_braviary_ko_damage_used)

      if should_trigger_braviary_ko
        self.pokemon.instance_variable_set(:@alder_braviary_ko_damage_used, true)

        @battle.pbDisplay(_INTL("{1}'s final cry shook the battlefield!", self.pbThis))

        @battle.allOtherSideBattlers(self.index).each do |b|
          next if !b
          next if b.fainted?

          damage = [b.totalhp / 8, 1].max
          @battle.scene.pbDamageAnimation(b) rescue nil
          b.pbReduceHP(damage, false)

          @battle.pbDisplay(_INTL("{1} was struck by Braviary's last stand!", b.pbThis))

          b.pbFaint if b.fainted?
        end
      end

      return alder_braviary_ko_damage_pbFaint(*args)
    end
  end
end

#===============================================================================
# Alder Accelgor AI
# Accelgor của Alder sẽ không tự switch out vì thấp máu.
#===============================================================================
class Battle::AI
  if method_defined?(:pbChooseToSwitchOut) &&
     !method_defined?(:alder_accelgor_no_low_hp_switch_pbChooseToSwitchOut)

    alias alder_accelgor_no_low_hp_switch_pbChooseToSwitchOut pbChooseToSwitchOut

    def pbChooseToSwitchOut(*args)
      if $alderChampionBattle
        battler = nil

        if @user && @user.respond_to?(:battler)
          battler = @user.battler
        elsif @user && @user.respond_to?(:index) && @battle
          battler = @battle.battlers[@user.index] rescue nil
        end

        if battler &&
           !battler.pbOwnedByPlayer? &&
           battler.isSpecies?(:ACCELGOR) &&
           !battler.fainted?
          PBDebug.log_ai("Alder's Accelgor refuses to switch and keeps fighting.") rescue nil
          return false
        end
      end

      return alder_accelgor_no_low_hp_switch_pbChooseToSwitchOut(*args)
    end
  end
end

#===============================================================================
# Champion Iris Custom Battle
# Bật bằng: $irisChampionBattle = true
#
# Hiệu ứng:
# - Tất cả Pokemon của Iris giảm 20% sát thương từ đòn đánh.
# - Garchomp vào sân: +1 Evasion và tạo Sandstorm.
# - Aggron vào sân: +1 Defense.
# - Lapras vào sân: +1 Special Defense và tạo Rain.
# - Dragonite khi HP xuống dưới hoặc bằng 50%: +1 Speed, mỗi Dragonite 1 lần.
# - Hydreigon vào sân: +1 Special Attack.
# - Haxorus xử lý bằng midbattleScript: thoại + tăng Defense và Sp. Def.
#===============================================================================

$irisChampionBattle = false if !defined?($irisChampionBattle)

#===============================================================================
# Damage reduction: Pokemon của Iris giảm 20% damage từ đòn đánh.
#===============================================================================
class Battle::Move
  alias iris_champion_pbCalcDamageMultipliers pbCalcDamageMultipliers unless method_defined?(:iris_champion_pbCalcDamageMultipliers)

  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    iris_champion_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)

    return if !$irisChampionBattle
    return if !target
    return if target.fainted?
    return if target.pbOwnedByPlayer?
    return if multipliers[:iris_champion_damage_applied]

    # Pokemon của Iris chỉ nhận 90% sát thương từ đòn đánh.
    multipliers[:final_damage_multiplier] *= 0.9
    multipliers[:iris_champion_damage_applied] = true
  end
end

#===============================================================================
# Entry effects
#===============================================================================
class Battle::Battler
  def pbIrisChampionEntryEffects
    return if !$irisChampionBattle
    return if self.fainted?
    return if !self.pokemon
    return if self.pbOwnedByPlayer?

    # Weather nên được gọi mỗi lần Garchomp/Lapras vào sân.
    if self.isSpecies?(:GARCHOMP)
      pbIrisForceSandstorm
    elsif self.isSpecies?(:LAPRAS)
      pbIrisForceRain
    end

    # Dragonite nếu vào sân mà đã dưới 50% HP thì vẫn kích hoạt Speed.
    if self.isSpecies?(:DRAGONITE)
      pbIrisDragoniteSpeedBoostCheck
    end

    # Mỗi Pokemon chỉ nhận buff entry riêng 1 lần.
    return if self.pokemon.instance_variable_get(:@iris_entry_effect_used)

    if self.isSpecies?(:GARCHOMP)
      self.pokemon.instance_variable_set(:@iris_entry_effect_used, true)

      @battle.pbDisplay(_INTL("{1} vanished into the raging sand!", self.pbThis))

      if self.pbCanRaiseStatStage?(:EVASION, self)
        self.pbRaiseStatStageByCause(:EVASION, 1, self, "Iris's strategy")
      end

    elsif self.isSpecies?(:AGGRON)
      self.pokemon.instance_variable_set(:@iris_entry_effect_used, true)

      @battle.pbDisplay(_INTL("{1}'s iron defense hardened!", self.pbThis))

      if self.pbCanRaiseStatStage?(:DEFENSE, self)
        self.pbRaiseStatStageByCause(:DEFENSE, 1, self, "Iris's strategy")
      end

    elsif self.isSpecies?(:HYDREIGON)
      self.pokemon.instance_variable_set(:@iris_entry_effect_used, true)

      @battle.pbDisplay(_INTL("{1}'s dark power surged!", self.pbThis))

      if self.pbCanRaiseStatStage?(:SPECIAL_ATTACK, self)
        self.pbRaiseStatStageByCause(:SPECIAL_ATTACK, 1, self, "Iris's strategy")
      end
    end
  end

  #-----------------------------------------------------------------------------
  # Garchomp: tạo bão cát khi vào sân.
  #-----------------------------------------------------------------------------
  def pbIrisForceSandstorm
    return if @battle.field.weather == :Sandstorm

    begin
      @battle.pbStartWeatherAbility(:Sandstorm, self)
      return if @battle.field.weather == :Sandstorm
    rescue
    end

    begin
      @battle.pbStartWeather(self, :Sandstorm)
      return if @battle.field.weather == :Sandstorm
    rescue
    end

    @battle.field.weather = :Sandstorm
    @battle.field.weatherDuration = 5 if @battle.field.respond_to?(:weatherDuration=)
    @battle.pbDisplay(_INTL("A sandstorm brewed!"))
  end

  #-----------------------------------------------------------------------------
  # Lapras: tạo trời mưa khi vào sân.
  #-----------------------------------------------------------------------------
  def pbIrisForceRain
    return if @battle.field.weather == :Rain

    begin
      @battle.pbStartWeatherAbility(:Rain, self)
      return if @battle.field.weather == :Rain
    rescue
    end

    begin
      @battle.pbStartWeather(self, :Rain)
      return if @battle.field.weather == :Rain
    rescue
    end

    @battle.field.weather = :Rain
    @battle.field.weatherDuration = 5 if @battle.field.respond_to?(:weatherDuration=)
    @battle.pbDisplay(_INTL("It started to rain!"))
  end

  #-----------------------------------------------------------------------------
  # Dragonite: nếu HP <= 50%, tăng Speed 1 lần.
  #-----------------------------------------------------------------------------
  def pbIrisDragoniteSpeedBoostCheck
    return if !$irisChampionBattle
    return if self.pbOwnedByPlayer?
    return if !self.isSpecies?(:DRAGONITE)
    return if !self.pokemon
    return if self.fainted?
    return if self.hp <= 0
    return if self.hp > self.totalhp / 2
    return if self.pokemon.instance_variable_get(:@iris_dragonite_speed_used)

    self.pokemon.instance_variable_set(:@iris_dragonite_speed_used, true)

    @battle.pbDisplay(_INTL("{1}'s draconic instinct pushed it faster!", self.pbThis))

    if self.pbCanRaiseStatStage?(:SPEED, self)
      self.pbRaiseStatStageByCause(:SPEED, 1, self, "Iris's strategy")
    end
  end
end

#===============================================================================
# Hook entry effects
#===============================================================================
class Battle
  def pbIrisChampionRunEntryEffectFor(arg)
    return if !$irisChampionBattle

    battler = nil

    if arg.is_a?(Battle::Battler)
      battler = arg
    elsif arg.is_a?(Integer)
      battler = @battlers[arg]
    elsif arg.respond_to?(:to_i)
      battler = @battlers[arg.to_i]
    end

    battler.pbIrisChampionEntryEffects if battler && battler.respond_to?(:pbIrisChampionEntryEffects)
  end

  if method_defined?(:pbOnBattlerEnteringBattle) &&
     !method_defined?(:iris_champion_pbOnBattlerEnteringBattle)
    alias iris_champion_pbOnBattlerEnteringBattle pbOnBattlerEnteringBattle

    def pbOnBattlerEnteringBattle(*args)
      ret = iris_champion_pbOnBattlerEnteringBattle(*args)
      pbIrisChampionRunEntryEffectFor(args[0])
      return ret
    end
  end

  if method_defined?(:pbOnAllBattlersEnteringBattle) &&
     !method_defined?(:iris_champion_pbOnAllBattlersEnteringBattle)
    alias iris_champion_pbOnAllBattlersEnteringBattle pbOnAllBattlersEnteringBattle

    def pbOnAllBattlersEnteringBattle(*args)
      ret = iris_champion_pbOnAllBattlersEnteringBattle(*args)

      if $irisChampionBattle
        @battlers.each do |b|
          next if !b
          next if b.fainted?
          b.pbIrisChampionEntryEffects if b.respond_to?(:pbIrisChampionEntryEffects)
        end
      end

      return ret
    end
  end
end

#===============================================================================
# Dragonite HP check after taking damage
#===============================================================================
class Battle::Battler
  alias iris_champion_pbReduceHP pbReduceHP unless method_defined?(:iris_champion_pbReduceHP)

  def pbReduceHP(*args)
    old_hp = self.hp
    ret = iris_champion_pbReduceHP(*args)

    if $irisChampionBattle &&
       !self.pbOwnedByPlayer? &&
       self.isSpecies?(:DRAGONITE) &&
       self.hp < old_hp
      pbIrisDragoniteSpeedBoostCheck
    end

    return ret
  end
end