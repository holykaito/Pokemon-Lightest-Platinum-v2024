# Changelog

## [Unreleased] - 2026-01-01

### Fixed
- **Systemstackerrror (Stack Level Too Deep):**
  - Added a recursion guard to the `waterborne_follower?` method in `Event_Sprite Commands.rb`. This prevents infinite loops when the game checks if a follower can surf while loading, specifically when the player is already on water.

### Changed
- **Follower Placement Logic:**
  - Updated `Following Event.rb` to improve how followers are placed after battles or map transfers. 
  - The system now attempts to place the follower in the following order of preference:
    1.  **Behind** the player (Traditional).
    2.  **Left or Right** of the player (if behind is blocked).
    3.  **On** the player (only as a last resort if all other tiles are blocked).
  - This significantly reduces instances where the follower spawns directly on top of the player.

- **Sprite Priority (Levitate vs Swim):**
  - Updated `Compatibility.rb` to prioritize "Levitate" sprites over "Swimming" sprites.
  - If a Pokémon has a sprite in the `Graphics/Characters/Levitates` folder, it will now use that sprite when moving over water instead of defaulting to the `Graphics/Characters/Swimming` sprite. This allows flying/floating Pokémon to appear as if they are hovering over the water rather than swimming in it.
