#===============================================================================
# Move Animation Alias v2.0 - Pokemon Essentials v21.1 (legacy animation player)
# Replace v1.0 completely before installing this version.
# Animation = HYPERFANG,INGRAIN
# Animation = HYPERFANG,INGRAIN@Target  (swap roles in the second animation)
#===============================================================================
module MultiMoveAnimation
  # "s" lists allow optional @Target suffixes without enum/forward-reference issues.
  GameData::Move::SCHEMA["Animation"] = [:animation, "*s"]

  module MoveData
    attr_reader :animation

    def initialize(hash)
      super
      @animation = hash[:animation]
    end
  end

  def self.entries(data)
    return [] if !data || !data.animation
    # Also tolerate old serialized string values until PBS is recompiled.
    return Array(data.animation).flat_map { |v| v.to_s.split(",") }.filter_map do |v|
      match = /\A\s*([A-Z0-9_]+)(?:@(USER|TARGET))?\s*\z/i.match(v)
      next if !match
      id = match[1].upcase.to_sym
      next if !GameData::Move.exists?(id)
      [id, match[2]&.upcase == "TARGET"]
    end
  end

  # Exact lookup: preserve opponent-specific animation and hit-number behavior.
  # Do not substitute a generic type animation for a missing overlay.
  def self.lookup(map, id, idx_user, hit_num)
    if idx_user.odd? && map[1][id]
      return [map[1][id] + hit_num, true]
    end
    return [map[0][id] + hit_num, false] if map[0][id]
    return nil
  end

  class Player < PBAnimationPlayerX
    def start_at(time)
      start
      @timer_start = time
    end
  end

  module Scene
    # Maintain v1 single-alias support for callers of pbFindMoveAnimation too.
    def pbFindMoveAnimDetails(map, move_id, idx_user, hit_num = 0)
      result = super
      return result if result
      data = GameData::Move.try_get(move_id)
      MultiMoveAnimation.entries(data).each do |id, _swap|
        next if id == data.id
        result = MultiMoveAnimation.lookup(map, id, idx_user, hit_num)
        return result if result
      end
      return nil
    end

    def pbAnimation(move_id, user, targets, hit_num = 0)
      data = GameData::Move.try_get(move_id)
      entries = MultiMoveAnimation.entries(data)
      return super if entries.empty?
      map = pbLoadMoveToAnim
      # A move's own animation always takes priority, as in v1.
      return super if MultiMoveAnimation.lookup(map, data.id, user.index, hit_num)
      animations = pbLoadBattleAnimations
      return super if !animations
      target = targets.is_a?(Array) ? targets[0] : targets
      specs = entries.filter_map do |id, swap|
        anim_user, anim_target = swap ? [target, user] : [user, target]
        next if !anim_user
        details = MultiMoveAnimation.lookup(map, id, anim_user.index, hit_num)
        next if !details || !animations[details[0]]
        if details[1]
          [animations[details[0]], anim_target, anim_user, true]
        else
          [animations[details[0]], anim_user, anim_target, false]
        end
      end
      return super if specs.empty?
      hide_boxes = defined?(Settings::HIDE_DATABOXES_DURING_MOVES) &&
                   Settings::HIDE_DATABOXES_DURING_MOVES &&
                   respond_to?(:pbToggleDataboxes)
      shadow_states = @sprites.filter_map do |key, sprite|
        next if !key.start_with?("shadow_") || !sprite || sprite.disposed?
        [sprite, sprite.visible]
      end
      begin
        pbToggleDataboxes if hide_boxes
        pbSaveShadows { mma_play_together(specs) }
      ensure
        shadow_states.each { |s, visible| s.visible = visible if !s.disposed? }
        pbToggleDataboxes(true) if hide_boxes
      end
    end

    def mma_sprite_snapshot(sprite)
      return nil if !sprite || sprite.disposed?
      state = {}
      [:bitmap, :x, :y, :z, :ox, :oy, :zoom_x, :zoom_y, :angle,
       :mirror, :opacity, :visible, :blend_type].each do |property|
        state[property] = sprite.public_send(property)
      end
      [:color, :tone, :src_rect].each do |property|
        state[property] = sprite.public_send(property).clone
      end
      return [sprite, state]
    end

    def mma_restore_sprites(snapshots)
      snapshots.each do |sprite, state|
        next if sprite.disposed?
        state.each do |property, value|
          sprite.public_send("#{property}=", value)
        end
      end
    end

    def mma_play_together(specs)
      @briefMessage = false
      players = []
      # Capture all involved battlers before any player updates them.
      battlers = specs.flat_map { |s| [s[1], s[2]] }.compact.uniq
      snapshots = battlers.filter_map do |b|
        mma_sprite_snapshot(@sprites["pokemon_#{b.index}"])
      end
      primary_restored = false
      begin
        specs.each_with_index do |(animation, anim_user, anim_target, opp), i|
          player = MultiMoveAnimation::Player.new(animation, anim_user, anim_target, self, opp)
          players.push(player)
          # Only the first animation may manipulate the real battler sprites.
          player.discard_user_and_target_sprites if i > 0
          us = anim_user ? @sprites["pokemon_#{anim_user.index}"] : nil
          ts = anim_target ? @sprites["pokemon_#{anim_target.index}"] : nil
          ux, uy = us ? [us.x, us.y] : [0, 0]
          tx, ty = ts ? [ts.x, ts.y] : [ux, uy]
          uh = us&.bitmap && !us.bitmap.disposed? ? us.bitmap.height : 128
          th = ts&.bitmap && !ts.bitmap.disposed? ? ts.bitmap.height : uh
          player.setLineTransform(
            Battle::Scene::FOCUSUSER_X, Battle::Scene::FOCUSUSER_Y,
            Battle::Scene::FOCUSTARGET_X, Battle::Scene::FOCUSTARGET_Y,
            ux, uy - uh / 2, tx, ty - th / 2
          )
        end
        # One shared start time, then one update loop for ALL players.
        start_time = System.uptime
        players.each { |p| p.start_at(start_time) }
        until players.all?(&:nil?)
          players.each_with_index do |player, i|
            next if !player
            player.update
            next if !player.animDone?
            player.dispose
            players[i] = nil
            if i == 0
              mma_restore_sprites(snapshots)
              primary_restored = true
            end
          end
          pbUpdate
        end
      ensure
        # Nested ensure guarantees sprite restoration even if disposal fails.
        begin
          players.compact.each { |p| p.dispose }
        ensure
          mma_restore_sprites(snapshots) if !primary_restored
        end
      end
    end
  end
end

GameData::Move.prepend(MultiMoveAnimation::MoveData)
Battle::Scene.prepend(MultiMoveAnimation::Scene)
