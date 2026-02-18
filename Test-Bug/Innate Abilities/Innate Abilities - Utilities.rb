def pbChooseInnateList(default = nil)
  return pbChooseFromGameDataList(:Innate, default)
end

MenuHandlers.add(:pokemon_debug_menu, :set_innate, {
  "name"   => _INTL("Set innate"),
  "parent" => :main,
  "effect" => proc { |pkmn, pkmnid, heldpoke, settingUpBattle, screen|
    cmd = 0
    commands = [
      _INTL("Set possible innate"),
      _INTL("Set any innate"),
      _INTL("Reset")
    ]
    loop do
      if pkmn.innate
        msg = _INTL("Innate is {1} (index {2}).", pkmn.innate.name, pkmn.innate_index)
      else
        msg = _INTL("No ability (index {1}).", pkmn.innate_index)
      end
      cmd = screen.pbShowCommands(msg, commands, cmd)
      break if cmd < 0
      case cmd
      when 0   # Set possible ability
        innas = pkmn.getInnateList
        innate_commands = []
        inna_cmd = 0
        innas.each do |i|
          innate_commands.push(((i[1] < 2) ? "" : "(H) ") + GameData::Innate.get(i[0]).name)
          inna_cmd = innate_commands.length - 1 if pkmn.innate_id == i[0]
        end
        inna_cmd = screen.pbShowCommands(_INTL("Choose an innate."), innate_commands, inna_cmd)
        next if inna_cmd < 0
        pkmn.innate_index = innas[inna_cmd][1]
        pkmn.innate = nil
        screen.pbRefreshSingle(pkmnid)
      when 1   # Set any ability
        new_innate = pbChooseInnateList(pkmn.innate_id)
        if new_innate && new_innate != pkmn.innate_id
          pkmn.innate = new_innate
          screen.pbRefreshSingle(pkmnid)
        end
      when 2   # Reset
        pkmn.ability_index = nil
        pkmn.ability = nil
        screen.pbRefreshSingle(pkmnid)
      end
    end
    next false
  }
})