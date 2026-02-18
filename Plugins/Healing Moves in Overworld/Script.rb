class PokemonPartyScreen
  def pbPokemonScreen
    can_access_storage = false
    if ($player.has_box_link || $bag.has?(:POKEMONBOXLINK)) &&
      !$game_switches[Settings::DISABLE_BOX_LINK_SWITCH] &&
      !$game_map.metadata&.has_flag?("DisableBoxLink")
      can_access_storage = true
    end
    @scene.pbStartScene(@party,
                        (@party.length > 1) ? _INTL("Choose a Pokémon.") : _INTL("Choose Pokémon or cancel."),
                        nil, false, can_access_storage)
    # Main loop
    loop do
      # Choose a Pokémon or cancel or press Action to quick switch
      @scene.pbSetHelpText((@party.length > 1) ? _INTL("Choose a Pokémon.") : _INTL("Choose Pokémon or cancel."))
      party_idx = @scene.pbChoosePokemon(false, -1, 1)
      break if (party_idx.is_a?(Numeric) && party_idx < 0) || (party_idx.is_a?(Array) && party_idx[1] < 0)
      # Quick switch
      if party_idx.is_a?(Array) && party_idx[0] == 1   # Switch
        @scene.pbSetHelpText(_INTL("Move to where?"))
        old_party_idx = party_idx[1]
        party_idx = @scene.pbChoosePokemon(true, -1, 2)
        pbSwitch(old_party_idx, party_idx) if party_idx >= 0 && party_idx != old_party_idx
        next
      end
      # Chose a Pokémon
      pkmn = @party[party_idx]
      # Get all commands
      command_list = []
      commands = []
      MenuHandlers.each_available(:party_menu, self, @party, party_idx) do |option, hash, name|
        command_list.push(name)
        commands.push(hash)
      end
      command_list.push(_INTL("Cancel"))
      # Add field move commands
      if !pkmn.egg?
        insert_index = ($DEBUG) ? 2 : 1
        pkmn.moves.each_with_index do |move, i|
          next if !HiddenMoveHandlers.hasHandler(move.id) &&
          ![:MILKDRINK,:SOFTBOILED,:HEALPULSE, :WISH,:ROOST, :RECOVER, :SYNTHESIS, :MOONLIGHT,
          :MORNINGSUN, :HEALORDER, :SLACKOFF,:LIFEDEW,
          :REFRESH,:AROMATHERAPY, :HEALBELL,:JUNGLEHEALING, :REVIVALBLESSING, :HEALINGWISH, 
          :AQUARING, :FLORALHEALING, :LUNARDANCE, :POLLENPUFF, :PRESENT, :PURIFY, :DREAMEATER,
          :LUNARBLESSING, :REST].include?(move.id)
          command_list.insert(insert_index, [move.name, 1])
          commands.insert(insert_index, i)
          insert_index += 1
        end
      end
      # Choose a menu option
      choice = @scene.pbShowCommands(_INTL("Do what with {1}?", pkmn.name), command_list)
      next if choice < 0 || choice >= commands.length
      # Effect of chosen menu option
      case commands[choice]
      when Hash   # Option defined via a MenuHandler below
        commands[choice]["effect"].call(self, @party, party_idx)
      when Integer   # Hidden move's index
        move = pkmn.moves[commands[choice]]
        #-------------------------------------------------------------
        # Cura um membro do time em 50% e não pode usar em sí mesmo
        #-------------------------------------------------------------
        if [:HEALPULSE].include?(move.id)
          amt = [(pkmn.totalhp / 2).floor, 1].max
          if pkmn.hp <= 0
            pbDisplay(_INTL("Not enough HP..."))
            next
          end
          @scene.pbSetHelpText(_INTL("Use on which Pokémon?"))
          old_party_idx = party_idx
          loop do
            @scene.pbPreSelect(old_party_idx)
            party_idx = @scene.pbChoosePokemon(true, party_idx)
            break if party_idx < 0
            newpkmn = @party[party_idx]
            movename = move.name
            if move.pp < 1
              pbDisplay(_INTL("Não tem PP suficiente..."))
              next
            end
            if party_idx == old_party_idx
              pbDisplay(_INTL("{1} não pode usar {2} em si mesmo",pkmn.name,movename))
              next
            elsif newpkmn.egg?
              pbDisplay(_INTL("{1} não pode ser usado em ovos!",movename))
              next
            elsif newpkmn.fainted? || newpkmn.hp == newpkmn.totalhp
              pbDisplay(_INTL("{1} não pode ser usado nesse Pokémon.",movename))
              next
            else
              move.pp -= 1
              amt = [(newpkmn.totalhp/2).floor,1].max
              hpgain = pbItemRestoreHP(newpkmn, amt)
              @scene.pbDisplay(_INTL("{1} curou o HP em {2} pontos.",newpkmn.name,hpgain))
              pbRefresh
            end
            break if pkmn.hp <= amt
          end
          @scene.pbSelect(old_party_idx)
          pbRefresh
          #-------------------------------------------------------------
          # heals himself by hitting an ally, he needs to hit a friend to steal their HP. The value changes depending on who has Big Root equipped.
          #-------------------------------------------------------------
          elsif [:DREAMEATER].include?(move.id)
            amt = [(pkmn.totalhp / 2).floor, 1].max
            if pkmn.hp <= 0
              pbDisplay(_INTL("Not enough HP..."))
              next
            end
            @scene.pbSetHelpText(_INTL("Selecione um Pokémon?"))
            old_party_idx = party_idx
            loop do
              @scene.pbPreSelect(old_party_idx)
              party_idx = @scene.pbChoosePokemon(true, party_idx)
              break if party_idx < 0
              newpkmn = @party[party_idx]
              movename = move.name
              if move.pp < 1
                pbDisplay(_INTL("Não tem PP suficiente..."))
                next
              end
              if party_idx == old_party_idx
                pbDisplay(_INTL("{1} não pode usar {2} em si mesmo",pkmn.name,movename))
                next
              elsif newpkmn.egg?
                pbDisplay(_INTL("{1} não pode ser usado em ovos!",movename))
                next
              elsif newpkmn.fainted? || newpkmn.hp == newpkmn.totalhp
                pbDisplay(_INTL("{1} não pode ser usado nesse Pokémon.",movename))
                next
              elsif newpkmn.status != :SLEEP
                pbDisplay(_INTL("{1} só pode ser usado em alvos dormindo.",movename))
                next
              else
                move.pp -= 1
                amt = [(newpkmn.totalhp/2).floor,1].max
                new_amt = (pkmn.totalhp*0.65).floor
                amt = new_amt if pkmn.hasItem?(:BIGROOT)


                new_hp = newpkmn.totalhp/4
                new_hp = newpkmn.totalhp/3 if pkmn.hasItem?(:BIGROOT)
                newpkmn.hp = newpkmn.hp - new_hp
                newpkmn.hp = 0 if new_hp < 0 
                hpgain = pbItemRestoreHP(pkmn, amt) 
                @scene.pbDisplay(_INTL("{1} curou o HP em {2} pontos e causou dano em {3}.",pkmn.name,hpgain,newpkmn.name ))
                pbRefresh
              end
              break if pkmn.hp <= amt
            end
            @scene.pbSelect(old_party_idx)
            pbRefresh
          #-------------------------------------------------------------
          # Cura um membro do time em 25% e não pode usar em sí mesmo - 20% CHANCE DE HP COMPLETO
          #-------------------------------------------------------------
          elsif [:PRESENT].include?(move.id)
            amt = [(pkmn.totalhp / 4).floor, 1].max
            chance = rand(101)
            amt = [(pkmn.totalhp).floor, 1].max if chance <= 20 
            if pkmn.hp <= 0
              pbDisplay(_INTL("Not enough HP..."))
              next
            end
            @scene.pbSetHelpText(_INTL("Use on which Pokémon?"))
            old_party_idx = party_idx
            loop do
              @scene.pbPreSelect(old_party_idx)
              party_idx = @scene.pbChoosePokemon(true, party_idx)
              break if party_idx < 0
              newpkmn = @party[party_idx]
              movename = move.name
              if move.pp < 1
                pbDisplay(_INTL("Não tem PP suficiente..."))
                next
              end
              if party_idx == old_party_idx
                pbDisplay(_INTL("{1} não pode usar {2} em si mesmo",pkmn.name,movename))
                next
              elsif newpkmn.egg?
                pbDisplay(_INTL("{1} não pode ser usado em ovos!",movename))
                next
              elsif newpkmn.fainted? || newpkmn.hp == newpkmn.totalhp
                pbDisplay(_INTL("{1} não pode ser usado nesse Pokémon.",movename))
                next
              elsif newpkmn.ability == :TELEPATHY
                pbDisplay(_INTL("{1} não pode ser usado nesse Pokémon pois possue a Ability Telepathy.",movename))
                next
              else
                move.pp -= 1


                hpgain = pbItemRestoreHP(newpkmn, amt)
                @scene.pbDisplay(_INTL("{1} curou o HP em {2} pontos.",newpkmn.name,hpgain))
                pbRefresh
              end
              break if pkmn.hp <= amt
            end
            @scene.pbSelect(old_party_idx)
            pbRefresh
        #----------------------------------------------------------
        # Cura um membro do time em 50% e pode curar a si mesmo
        #----------------------------------------------------------
        elsif [:WISH, :FLORALHEALING].include?(move.id)
          amt = [(pkmn.totalhp / 2).floor, 1].max
          if pkmn.hp <= 0
            pbDisplay(_INTL("Not enough HP..."))
            next
          end
          @scene.pbSetHelpText(_INTL("Use on which Pokémon?"))
          old_party_idx = party_idx
          loop do
            @scene.pbPreSelect(old_party_idx)
            party_idx = @scene.pbChoosePokemon(true, party_idx)
            break if party_idx < 0
            newpkmn = @party[party_idx]
            movename = move.name
            if move.pp < 1
              pbDisplay(_INTL("Não tem PP suficiente..."))
              next
            end
            if newpkmn.egg?
              pbDisplay(_INTL("{1} não pode ser usado em ovos!",movename))
              next
            elsif newpkmn.fainted? || newpkmn.hp == newpkmn.totalhp
              pbDisplay(_INTL("{1} não pode ser usado nesse Pokémon.",movename))
              next
            else
              move.pp -= 1
              amt = [(newpkmn.totalhp/2).floor,1].max
              hpgain = pbItemRestoreHP(newpkmn, amt)
              @scene.pbDisplay(_INTL("{1} curou o HP em {2} pontos.",newpkmn.name,hpgain))
              pbRefresh
            end
            break if pkmn.hp <= amt
          end
          @scene.pbSelect(old_party_idx)
          pbRefresh
        #----------------------------------------------------------
        # Cura um membro do time em 50% - Ability
        #----------------------------------------------------------
        elsif [:POLLENPUFF].include?(move.id)
          amt = [(pkmn.totalhp / 2).floor, 1].max
          if pkmn.hp <= 0
            pbDisplay(_INTL("Not enough HP..."))
            next
          end
          @scene.pbSetHelpText(_INTL("Use on which Pokémon?"))
          old_party_idx = party_idx
          loop do
            @scene.pbPreSelect(old_party_idx)
            party_idx = @scene.pbChoosePokemon(true, party_idx)
            break if party_idx < 0
            newpkmn = @party[party_idx]
            movename = move.name
            if move.pp < 1
              pbDisplay(_INTL("Não tem PP suficiente..."))
              next
            end
            if newpkmn.egg?
              pbDisplay(_INTL("{1} não pode ser usado em ovos!",movename))
              next
            elsif newpkmn.fainted? || newpkmn.hp == newpkmn.totalhp
              pbDisplay(_INTL("{1} não pode ser usado nesse Pokémon.",movename))
              next
            elsif newpkmn.ability == :BULLETPROOF
              pbDisplay(_INTL("{1} não pode ser usado nesse Pokémon pois possue a Ability Bulletproof.",movename))
              next
            elsif party_idx == old_party_idx
              pbDisplay(_INTL("{1} não pode usar {2} em si mesmo",pkmn.name,movename))
              next
            else
              move.pp -= 1
              amt = [(newpkmn.totalhp/2).floor,1].max
              hpgain = pbItemRestoreHP(newpkmn, amt)
              @scene.pbDisplay(_INTL("{1} curou o HP em {2} pontos.",newpkmn.name,hpgain))
              pbRefresh
            end
            break if pkmn.hp <= amt
          end
          @scene.pbSelect(old_party_idx)
          pbRefresh
        #-------------------------------
        # Cura Usuário e o time em 25%
        #-------------------------------
        elsif [:LIFEDEW].include?(move.id)
          curados = 0
          movename = move.name
          if move.pp < 1
              pbDisplay(_INTL("Não tem PP suficiente..."))
              next
          end
          if pkmn.hp==0
            pbDisplay(_INTL("{1} não pode ser usado.",movename))
            @scene.pbSelect(party_idx)
            next
          end  
          for a in party
            unless a.hp==0 || a.hp == a.totalhp
              amt = [(a.totalhp/4).floor,1].max
              hpgain = pbItemRestoreHP(a,amt)
              curados += 1
            end
          end  
          if curados > 0
            move.pp -= 1
            pbDisplay(_INTL("Os pokemon do seu time foram curados!"))
            pbRefresh
          else
            pbDisplay(_INTL("Nenhum pokemon do seu time foi curado!"))
            pbRefresh
          end 
        #-------------------------------
        # Cura Usuário e o time em 25%
        #-------------------------------
        elsif [:LUNARBLESSING].include?(move.id)
          curados = 0
          movename = move.name
          if move.pp < 1
              pbDisplay(_INTL("Não tem PP suficiente..."))
              next
          end
          if pkmn.hp==0
            pbDisplay(_INTL("{1} não pode ser usado.",movename))
            @scene.pbSelect(party_idx)
            next
          end  
          for a in party
            unless a.hp==0 || a.hp == a.totalhp || a.status != :NONE
              amt = [(a.totalhp/4).floor,1].max
              hpgain = pbItemRestoreHP(a,amt)
              a.heal_status
              curados += 1
            end
          end  
          if curados > 0
            move.pp -= 1
            pbDisplay(_INTL("Os pokemon do seu time foram curados!"))
            pbRefresh
          else
            pbDisplay(_INTL("Nenhum pokemon do seu time foi curado!"))
            pbRefresh
          end 
      #-------------------------------
      # Revive um Pokemon de batalha
      #-------------------------------
      elsif [:REVIVALBLESSING].include?(move.id)
        amt = [(pkmn.totalhp / 2).floor, 1].max
        if pkmn.hp <= 0
          pbDisplay(_INTL("Not enough HP..."))
          next
        end
        @scene.pbSetHelpText(_INTL("Use on which Pokémon?"))
        old_party_idx = party_idx
        loop do
          @scene.pbPreSelect(old_party_idx)
          party_idx = @scene.pbChoosePokemon(true, party_idx)
          break if party_idx < 0
          newpkmn = @party[party_idx]
          movename = move.name
          if move.pp < 1
            pbDisplay(_INTL("Não tem PP suficiente..."))
            next
          end
          if party_idx == old_party_idx
            pbDisplay(_INTL("{1} não pode usar {2} em si mesmo.",pkmn.name,movename))
            next
          elsif newpkmn.egg?
            pbDisplay(_INTL("{1} não pode ser usado em ovos!",movename))
            next
          elsif !newpkmn.fainted? 
            pbDisplay(_INTL("{1} não pode ser usado nesse Pokémon.",movename))
            next
          else
            move.pp -= 1
            newpkmn.hp = (newpkmn.totalhp / 2).floor
            newpkmn.hp = 1 if newpkmn.hp <= 0
            newpkmn.heal_status
            @scene.pbDisplay(_INTL("{1} foi revivido pelo Revival Blessing.",newpkmn.name,hpgain))
            pbRefresh
          end
          break if pkmn.hp <= 0
        end
        @scene.pbSelect(old_party_idx)
        pbRefresh
      #---------------------------------------------
      # Healing Wish restores a Pokémon's health and negative status and faints, but cannot be used on a fainted Pokémon.
      #---------------------------------------------
      elsif [:HEALINGWISH].include?(move.id)
        amt = [(pkmn.totalhp / 2).floor, 1].max
        if pkmn.hp <= 0
          pbDisplay(_INTL("Not enough HP..."))
          next
        end
        @scene.pbSetHelpText(_INTL("Use on which Pokémon?"))
        old_party_idx = party_idx
        loop do
          @scene.pbPreSelect(old_party_idx)
          party_idx = @scene.pbChoosePokemon(true, party_idx)
          break if party_idx < 0
          newpkmn = @party[party_idx]
          movename = move.name
          if move.pp < 1
            pbDisplay(_INTL("Não tem PP suficiente..."))
            next
          end
          if party_idx == old_party_idx
            pbDisplay(_INTL("{1} não pode usar {2} em si mesmo.",pkmn.name,movename))
            next
          elsif newpkmn.egg?
            pbDisplay(_INTL("{1} não pode ser usado em ovos!",movename))
            next
          elsif newpkmn.fainted? 
            pbDisplay(_INTL("{1} não pode ser usado nesse Pokémon.",movename))
            next
          else
            move.pp -= 1
            newpkmn.hp = (newpkmn.totalhp).floor
            newpkmn.hp = 1 if newpkmn.hp <= 0
            newpkmn.heal_status
            pkmn.hp = 0
            @scene.pbDisplay(_INTL("{1} foi revivido pelo Revival Blessing e {2} desmaiou.",newpkmn.name,pkmn.name))
            pbRefresh
          end
          break if pkmn.hp <= 0
        end
        @scene.pbSelect(old_party_idx)
        pbRefresh
      #---------------------------------------------
      # Lunar Dance restores a Pokémon's health to full and faints it, but cannot be used on a fainted Pokémon.
      #---------------------------------------------
      elsif [:LUNARDANCE].include?(move.id)
        amt = [(pkmn.totalhp / 2).floor, 1].max
        if pkmn.hp <= 0
          pbDisplay(_INTL("Not enough HP..."))
          next
        end
        @scene.pbSetHelpText(_INTL("Use on which Pokémon?"))
        old_party_idx = party_idx
        loop do
          @scene.pbPreSelect(old_party_idx)
          party_idx = @scene.pbChoosePokemon(true, party_idx)
          break if party_idx < 0
          newpkmn = @party[party_idx]
          movename = move.name
          if move.pp < 1
            pbDisplay(_INTL("Não tem PP suficiente..."))
            next
          end
          if party_idx == old_party_idx
            pbDisplay(_INTL("{1} não pode usar {2} em si mesmo.",pkmn.name,movename))
            next
          elsif newpkmn.egg?
            pbDisplay(_INTL("{1} não pode ser usado em ovos!",movename))
            next
          elsif newpkmn.fainted? 
            pbDisplay(_INTL("{1} não pode ser usado nesse Pokémon.",movename))
            next
          else
            move.pp -= 1
            newpkmn.hp = (newpkmn.totalhp).floor
            newpkmn.hp = 1 if newpkmn.hp <= 0
            newpkmn.pkmn.heal
            pkmn.hp = 0
            @scene.pbDisplay(_INTL("{1} foi revivido pelo Lunar Dance, curou {2} por completo e desmaiou.",newpkmn.name,pkmn.name))
            pbRefresh
          end
          break if pkmn.hp <= 0
        end
        @scene.pbSelect(old_party_idx)
        pbRefresh
      #-------------------------------
      # Cura usuário em Metade da vida
      #-------------------------------
      elsif [:MILKDRINK, :SOFTBOILED, :ROOST,:RECOVER,
          :SYNTHESIS, :MOONLIGHT, :MORNINGSUN, :HEALORDER, 
          :SHOREUP, :SLACKOFF].include?(move.id)
          amt = [(pkmn.totalhp/2).floor,1].max
          if pkmn.hp==0 || pkmn.hp==pkmn.totalhp
            movename = move.name
            pbDisplay(_INTL("{1} can't be used.",movename))
            next
            @scene.pbSelect(party_idx)
          end
          if move.pp<=0
            pbDisplay(_INTL("Restaure os PPS..."))
            next
          elsif pkmn.egg?
            pbDisplay(_INTL("{1} não pode ser usado em ovos!",movename))
            next
          elsif pkmn.fainted? 
            pbDisplay(_INTL("{1} não pode ser usado nesse Pokémon.",movename))
            next
          end
          move.pp -= 1
          hpgain = pbItemRestoreHP(pkmn,amt)
          @scene.pbDisplay(_INTL("{1}'s HP was restored by {2} points.",pkmn.name,hpgain))
          pbRefresh
          @scene.pbSelect(party_idx)
          pbRefresh
      #-------------------------------
      # Rest
      #-------------------------------
      elsif [:REST].include?(move.id)
        amt = [(pkmn.totalhp).floor,1].max
        if pkmn.hp==0 || pkmn.hp==pkmn.totalhp
          movename = move.name
          pbDisplay(_INTL("{1} can't be used.",movename))
          next
          @scene.pbSelect(party_idx)
        end
        if move.pp <= 0
          pbDisplay(_INTL("Not enough PP..."))
          next
        elsif pkmn.egg?
          pbDisplay(_INTL("{1} não pode ser usado em ovos!",movename))
          next
        elsif pkmn.fainted? 
          pbDisplay(_INTL("{1} não pode ser usado nesse Pokémon.",movename))
          next
        end
        move.pp -= 1
        hpgain = pbItemRestoreHP(pkmn,amt)
        pkmn.status = :SLEEP
        @scene.pbDisplay(_INTL("{1} restaurou 100% do seu HP e dormiu.",pkmn.name,hpgain))
        pbRefresh
        @scene.pbSelect(party_idx)
        pbRefresh
      #-------------------------------------------------
      # Cura usuário em 1/16 ou 3/10 se Big Root.
      #-------------------------------------------------
      elsif [:AQUARING].include?(move.id)
        amt = [(pkmn.totalhp/16).floor, 1].max
        new_amt = (pkmn.totalhp * 0.30).floor
        amt = new_amt if pkmn.hasItem?(:BIGROOT)
        if pkmn.hp==0 || pkmn.hp==pkmn.totalhp
          movename = move.name
          pbDisplay(_INTL("{1} can't be used.",movename))
          next
          @scene.pbSelect(party_idx)
        end
        if move.pp <= 0
          pbDisplay(_INTL("Not enough PP..."))
          next
        elsif pkmn.egg?
          pbDisplay(_INTL("{1} não pode ser usado em ovos!",movename))
          next
        elsif pkmn.fainted? 
          pbDisplay(_INTL("{1} não pode ser usado nesse Pokémon.",movename))
          next
        end
        move.pp -= 1
        hpgain = pbItemRestoreHP(pkmn,amt)
        @scene.pbDisplay(_INTL("{1}'s HP was restored by {2} points.",pkmn.name,hpgain))
        pbRefresh
        @scene.pbSelect(party_idx)
        pbRefresh
      #-------------------------------------------------
      # Heals user by 1/2 and their negative status only if they have a negative effect on them.
      #-------------------------------------------------
        elsif [:PURIFY].include?(move.id)
          amt = [(pkmn.totalhp / 2).floor, 1].max
          if pkmn.hp <= 0
            pbDisplay(_INTL("Not enough HP..."))
            next
          end
          @scene.pbSetHelpText(_INTL("Use on which Pokémon?"))
          old_party_idx = party_idx
          loop do
            @scene.pbPreSelect(old_party_idx)
            party_idx = @scene.pbChoosePokemon(true, party_idx)
            break if party_idx < 0
            newpkmn = @party[party_idx]
            movename = move.name
            if move.pp < 1
              pbDisplay(_INTL("Não tem PP suficiente..."))
              next
            end
            if newpkmn.egg?
              pbDisplay(_INTL("{1} não pode ser usado em ovos!",movename))
              next
            elsif newpkmn.fainted? || newpkmn.status == :NONE
              pbDisplay(_INTL("{1} não pode ser usado nesse Pokémon.",movename))
              next
            elsif party_idx == old_party_idx
              pbDisplay(_INTL("{1} não pode usar {2} em si mesmo",pkmn.name,movename))
              next
            else
              move.pp -= 1
              newpkmn.heal_status
              amt = [(pkmn.totalhp/2).floor,1].max
              hpgain = pbItemRestoreHP(pkmn, amt)
              @scene.pbDisplay(_INTL("{1} curou o HP em {2} pontos e curou efeito negativo de #{newpkmn.name}.",pkmn.name,hpgain))
              pbRefresh
            end
            break if pkmn.hp <= amt
          end
          @scene.pbSelect(old_party_idx)
          pbRefresh
      #-------------------------------
      # Cure User Status
      #-------------------------------
      elsif [:REFRESH].include?(move.id)
        if move.pp < 1
          pbDisplay(_INTL("Não tem PP suficiente..."))
          next
        end
        if pkmn.status != :NONE
          pkmn.heal_status
          move.pp -= 1
          pbDisplay(_INTL("Seus status foram curados!"))
        else
          pbDisplay(_INTL("Você não tem nenhum status valido!"))
          pbRefresh
        end
      #-------------------------------
      # Cure party Status
      #-------------------------------
      elsif [:AROMATHERAPY, :HEALBELL].include?(move.id)
          if pkmn.hp==0 
            movename = move.name
            pbDisplay(_INTL("{1} não pode ser usado.",movename))
            @scene.pbSelect(party_idx)
          end
          if move.pp < 1
            pbDisplay(_INTL("Não tem PP suficiente..."))
            next
          end
          oldpkmnid = party_idx
          cured = 0
          for i in 0...party.length
            newpkmn = @party[i]
            if newpkmn.status != :NONE
              newpkmn.heal_status
            else
              cured+=1
          end
          end
        if cured==party.length
          pbDisplay(_INTL("Ninguém tem nenhum efeito de status!"))
          @scene.pbSelect(oldpkmnid)
          pbRefresh
        else
          move.pp -= 1
          pbDisplay(_INTL("Os efeitos de status de todos foram curados!"))
          @scene.pbSelect(oldpkmnid)
          pbRefresh
        end
        #-------------------------------
        elsif [:JUNGLEHEALING].include?(move.id)
          if pkmn.hp==0 
            movename = move.name
            pbDisplay(_INTL("{1} não pode ser usado.",movename))
            @scene.pbSelect(party_idx)
          end
          if move.pp < 1
            pbDisplay(_INTL("Não tem PP suficiente..."))
            next
          end
          curados = 0 
          for a in party
            if (a.hp != 0 && a.hp != a.totalhp) || a.status != :NONE
              amt = [(a.totalhp/4).floor,1].max
              hpgain = pbItemRestoreHP(a,amt)
              a.heal_status
              curados += 1
            end 
          end
          if curados > 0
            move.pp -= 1
            pbDisplay(_INTL("Os Pokémon do seu time foram curados!"))
            pbRefresh
          else
            pbDisplay(_INTL("Nenhum Pokémon do seu time foi curado!"))
            pbRefresh
          end
        #-------------------------------------------------------------
        elsif pbCanUseHiddenMove?(pkmn, move.id)
          if pbConfirmUseHiddenMove(pkmn, move.id)
            @scene.pbEndScene
            if move.id == :FLY
              scene = PokemonRegionMap_Scene.new(-1, false)
              screen = PokemonRegionMapScreen.new(scene)
              ret = screen.pbStartFlyScreen
              if ret
                $game_temp.fly_destination = ret
                return [pkmn, move.id]
              end
              @scene.pbStartScene(
                @party, (@party.length > 1) ? _INTL("Choose a Pokémon.") : _INTL("Choose Pokémon or cancel.")
              )
              next
            end
            return [pkmn, move.id]
          end
        end
      end
    end
    @scene.pbEndScene
    return nil
  end
end
