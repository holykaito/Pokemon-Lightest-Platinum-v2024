class Battle::Move::AddIceRingToFoeSide < Battle::Move
  def initialize(battle, move)
    super(battle, move)
  end

  def canMagicCoat?; return true; end

  def pbMoveFailed?(user, targets)
    if user.pbOpposingSide.effects[PBEffects::IceRing]
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return false
  end

  def pbEffectGeneral(user)
    user.pbOpposingSide.effects[PBEffects::IceRing] = true
    @battle.pbDisplay(_INTL("An ice ring formed on {1}!",
                            user.pbOpposingTeam(true)))
  end
end