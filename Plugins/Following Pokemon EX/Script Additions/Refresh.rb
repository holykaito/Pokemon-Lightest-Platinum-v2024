#===============================================================================
# [Following Pokemon EX] Refresh.rb
# patched for v22 compatibility
#===============================================================================

#-------------------------------------------------------------------------------
# Refresh Following Pokemon when mounting Bike
#-------------------------------------------------------------------------------
alias __followingpkmn__pbMountBike pbMountBike unless defined?(__followingpkmn__pbMountBike)
def pbMountBike(*args)
  ret = __followingpkmn__pbMountBike(*args)
  FollowingPkmn.refresh(false)
  return ret
end

alias __followingpkmn__pbDismountBike pbDismountBike unless defined?(__followingpkmn__pbDismountBike)
def pbDismountBike(*args)
  ret = __followingpkmn__pbDismountBike(*args)
  FollowingPkmn.refresh(false)
  return ret
end

#-------------------------------------------------------------------------------
# Refresh Following Pokemon when using PC
#-------------------------------------------------------------------------------
alias __followingpkmn__pbTrainerPC pbTrainerPC unless defined?(__followingpkmn__pbTrainerPC)
def pbTrainerPC(*args)
  ret = __followingpkmn__pbTrainerPC(*args)
  FollowingPkmn.refresh(false)
  return ret
end

alias __followingpkmn__pbPokeCenterPC pbPokeCenterPC unless defined?(__followingpkmn__pbPokeCenterPC)
def pbPokeCenterPC(*args)
  $game_temp.pokecenter_following_pkmn = 0
  if FollowingPkmn.active?
    $game_temp.pokecenter_following_pkmn = 1
    $game_temp.pokecenter_following_pkmn = 2 if FollowingPkmn::SHOW_POKECENTER_ANIMATION
  end
  ret = __followingpkmn__pbPokeCenterPC(*args)
  FollowingPkmn.refresh(false)
  return ret
end

#-------------------------------------------------------------------------------
# [V22 Port] Refresh Following Pokemon after Party Screen closes
#-------------------------------------------------------------------------------
alias __followingpkmn__pbPokemonScreen pbPokemonScreen unless defined?(__followingpkmn__pbPokemonScreen)
def pbPokemonScreen
  __followingpkmn__pbPokemonScreen
  FollowingPkmn.refresh(false)
end

#-------------------------------------------------------------------------------



#-------------------------------------------------------------------------------
# [V22 Port] Refresh Following Pokemon after Evolution
# patched into PokemonEvolutionScene
#-------------------------------------------------------------------------------
class PokemonEvolutionScene
  alias __followingpkmn__pbEndScreen pbEndScreen unless method_defined?(:__followingpkmn__pbEndScreen)
  def pbEndScreen(*args)
    ret = __followingpkmn__pbEndScreen(*args)
    FollowingPkmn.refresh(false)
    return ret
  end
end

#-------------------------------------------------------------------------------
# [V22 Port] Refresh Following Pokemon after Trade
#-------------------------------------------------------------------------------
# NOTE: pbStartTrade is usually a global function.
alias __followingpkmn__pbStartTrade pbStartTrade unless defined?(__followingpkmn__pbStartTrade)
def pbStartTrade(*args)
  ret = __followingpkmn__pbStartTrade(*args)
  FollowingPkmn.refresh(false)
  return ret
end

#-------------------------------------------------------------------------------
# [V22 Port] Refresh Following Pokemon after Hatching
#-------------------------------------------------------------------------------
alias __followingpkmn__pbHatch pbHatch unless defined?(__followingpkmn__pbHatch)
def pbHatch(*args)
  ret = __followingpkmn__pbHatch(*args)
  FollowingPkmn.refresh(false)
  return ret
end

#-------------------------------------------------------------------------------
# [V22 Port] Refresh Following Pokemon after Bag (Item Choice)
#-------------------------------------------------------------------------------
alias __followingpkmn__pbChooseItem pbChooseItem unless defined?(__followingpkmn__pbChooseItem)
def pbChooseItem(*args)
  ret = __followingpkmn__pbChooseItem(*args)
  FollowingPkmn.refresh(false)
  return ret
end

#-------------------------------------------------------------------------------
# Refresh Following Pokemon after using Debug menu
#-------------------------------------------------------------------------------
alias __followingpkmn__pbDebugMenu pbDebugMenu unless defined?(__followingpkmn__pbDebugMenu)
def pbDebugMenu(*args)
  ret = __followingpkmn__pbDebugMenu(*args)
  FollowingPkmn.refresh(false)
  return ret
end

#-------------------------------------------------------------------------------
# Refresh Following Pokemon after taking a step, when a refresh is queued
#-------------------------------------------------------------------------------
class Scene_Map
  alias __followingpkmn__update update unless method_defined?(:__followingpkmn__update)
  def update(*args)
    __followingpkmn__update(*args)
    [:ACTION, :SPECIAL, :AUX1, :AUX2].each do |k|
      if Input.trigger?(k)
        pbMessage("Triggered: #{k}")
      end
    end
    t_key = FollowingPkmn::TOGGLE_FOLLOWER_KEY
    if FollowingPkmn.can_check? && (Input.trigger?(t_key) || (Input.const_defined?(t_key) && Input.trigger?(Input.const_get(t_key))) rescue false)
      FollowingPkmn.toggle
    end
    if $PokemonGlobal.call_refresh[0]
      FollowingPkmn.refresh($PokemonGlobal.call_refresh[1])
      $PokemonGlobal.call_refresh = false
    end
  end
end

EventHandlers.add(:on_player_step_taken, :forced_follower_refresh, proc {
  if $PokemonGlobal.call_refresh[0]
    FollowingPkmn.refresh($PokemonGlobal.call_refresh[1])
    $PokemonGlobal.call_refresh = false
  end
})

#-------------------------------------------------------------------------------
# Refresh Following Pokemon after Day Care interaction
#-------------------------------------------------------------------------------
class DayCare
  class << self
    alias __followingpkmn__deposit deposit unless method_defined?(:__followingpkmn__deposit)
    def deposit(*args)
      ret = __followingpkmn__deposit(*args)
      FollowingPkmn.refresh(false)
      return ret
    end

    alias __followingpkmn__withdraw withdraw unless method_defined?(:__followingpkmn__withdraw)
    def withdraw(*args)
      ret = __followingpkmn__withdraw(*args)
      FollowingPkmn.refresh(false)
      return ret
    end
  end
end
