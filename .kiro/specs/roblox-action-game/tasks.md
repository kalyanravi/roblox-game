# Implementation Plan: Roblox Action Game

## Overview

This plan implements a competitive shooter game on Roblox using Rojo file sync with a strict Server/Client/Shared architecture in Luau. Tasks are ordered to build foundational shared definitions first, then server-side authoritative systems, then client-side controllers, and finally integration wiring. Property-based tests validate correctness properties defined in the design.

## Tasks

- [x] 1. Set up Rojo project structure and shared definitions
  - [x] 1.1 Create Rojo project file and directory scaffolding
    - Create `default.project.json` mapping `src/Server`, `src/Client`, `src/Shared` to appropriate Roblox services
    - Create all directories: `Server/Services/`, `Server/Systems/`, `Client/Controllers/`, `Shared/Definitions/`, `Shared/Types/`, `Shared/Utils/`
    - Create `Server/Init.server.luau` and `Client/Init.client.luau` entry points
    - _Requirements: 23.1, 24.5, 24.6_

  - [x] 1.2 Define shared type definitions
    - Create `Shared/Types/PlayerData.luau` with PlayerSaveData type
    - Create `Shared/Types/WeaponTypes.luau` with WeaponStats, WeaponCategory types
    - Create `Shared/Types/MatchTypes.luau` with MatchState, MatchConfig, PlayerMatchStats types
    - Create `Shared/Types/EconomyTypes.luau` with currency and transaction types
    - _Requirements: 2.6, 3.1, 6.7, 24.1_

  - [x] 1.3 Create shared constants module
    - Create `Shared/Constants.luau` with game-wide constants: respawn timer (3s), spawn protection (3s), match duration (300s), AFK thresholds (45s/60s), rate limits (60/s), max level (100), max prestige (5)
    - _Requirements: 3.5, 3.6, 22.1, 23.5, 12.1_

  - [x] 1.4 Create weapon definitions module
    - Create `Shared/Definitions/WeaponDefinitions.luau` with all 10+ Common weapons across categories (AR, Shotgun, Sniper, Revolver, DualPistols, RocketLauncher, Crossbow, LMG, Knife, Fists, Scythe)
    - Include 10-20 Rare/Epic/Legendary/Mythic weapons
    - Define `getWeapon`, `getWeaponsByCategory`, `getWeaponsByRarity`, `calculateEffectiveStats`, `getRarityBonus` functions
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_

  - [x] 1.5 Create rarity config and ability definitions
    - Create `Shared/Definitions/RarityConfig.luau` with stat bonuses: Common(0%), Rare(5%), Epic(10%), Legendary(15%), Mythic(20%)
    - Create `Shared/Definitions/AbilityDefinitions.luau` with Dash, Heal, Grapple, Shield, SpeedBoost (costs, cooldowns, params)
    - _Requirements: 2.5, 4.1_

  - [x] 1.6 Create map, streak, finisher, and chest definitions
    - Create `Shared/Definitions/MapDefinitions.luau` with 5 maps (Desert Outpost, Futuristic City, Military Base, Abandoned Factory, Sky Fortress) each with 8+ spawn points
    - Create `Shared/Definitions/StreakDefinitions.luau` with milestones at 3, 5, 7, 10 kills
    - Create `Shared/Definitions/FinisherDefinitions.luau` with 6 finishers (Dissolve, Explosion, Freeze Shatter, Lightning Strike, Vaporize, Ragdoll Launch)
    - Create `Shared/Definitions/ChestDefinitions.luau` with Bronze/Silver/Gold tiers and reward pools
    - _Requirements: 5.2, 5.3, 5.4, 5.5, 9.1, 9.2, 9.3, 9.6, 10.1, 14.1_

  - [x] 1.7 Create shared utility modules
    - Create `Shared/Utils/MathUtils.luau` with clamp, lerp, and distance helpers
    - Create `Shared/Utils/TableUtils.luau` with deep copy, merge, and find functions
    - Create `Shared/Utils/ValidationUtils.luau` with type-check and range-validation helpers for remote argument validation
    - _Requirements: 23.2_

- [x] 2. Implement server-side combat and match systems
  - [x] 2.1 Implement CombatService
    - Create `Server/Services/CombatService.server.luau`
    - Implement `handleFireRequest` with server-side raycasting using `workspace:Raycast()`
    - Implement `calculateDamage(baseDamage, rarityTier, isHeadshot)` applying rarity bonus and 1.5x headshot multiplier
    - Implement `applyDamage` reducing target health, `registerKill` notifying KillStreakManager, EconomyService, MasterySystem, ProgressionEngine
    - Validate fire requests: check ammo > 0, weapon owned, not reloading
    - Wire `FireWeapon` and `ReloadWeapon` RemoteEvents
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 23.1, 23.3_

  - [ ]* 2.2 Write property test: Damage Calculation Correctness
    - **Property 1: Damage Calculation Correctness**
    - Generate random weapon base damage (1-100), random rarity tier, random headshot boolean
    - Assert: finalDamage == baseDamage × (1 + rarityBonus) × headshotMultiplier
    - **Validates: Requirements 1.2, 1.7, 2.5**

  - [ ]* 2.3 Write property test: Reload State Blocks Firing
    - **Property 2: Reload State Blocks Firing**
    - Generate random weapon in reloading state, random fire attempts
    - Assert: all fire attempts return rejected/no-op while reloading
    - **Validates: Requirements 1.4**

  - [x] 2.4 Implement MatchService
    - Create `Server/Services/MatchService.server.luau`
    - Implement `createMatch(config)`, `startCountdown`, `endMatch`, `addKill`, `addDeath`, `getScoreboard`, `determineWinner`
    - Handle match state transitions: Waiting → Countdown → Active → Ending → Results
    - Implement tiebreaker logic: most kills wins, fewest deaths breaks ties
    - Implement 5-minute timer and auto-end
    - Support TDM (1v1–5v5) and FFA (2–10 players) modes
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.7, 3.8_

  - [ ]* 2.5 Write property test: Winner Determination with Tiebreaker
    - **Property 5: Winner Determination with Tiebreaker**
    - Generate random sets of player scores (kills, deaths)
    - Assert: winner has most kills; on tie, winner has fewest deaths
    - **Validates: Requirements 3.3, 3.4**

  - [x] 2.6 Implement SpawnSystem and MapSystem
    - Create `Server/Systems/SpawnSystem.server.luau` with `getSpawnPoint` (maximize min-distance from enemies), `startRespawnTimer` (3s), `applySpawnProtection` (3s invincibility), `removeSpawnProtection`, `isSpawnProtected`
    - Create `Server/Systems/MapSystem.server.luau` with map rotation (avoid repeats), map loading, fall-zone detection
    - _Requirements: 3.5, 3.6, 10.1, 10.2, 10.3, 10.4, 10.5_

  - [ ]* 2.7 Write property test: Spawn Point Maximizes Enemy Distance
    - **Property 6: Spawn Point Maximizes Enemy Distance**
    - Generate random spawn point sets and enemy positions
    - Assert: selected spawn maximizes minimum distance to any enemy
    - **Validates: Requirements 3.6**

- [x] 3. Checkpoint - Core combat and match systems
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. Implement server-side ability, streak, and finisher systems
  - [x] 4.1 Implement AbilityServer
    - Create ability handling in `Server/Services/CombatService.server.luau` or a dedicated module
    - Implement `activateAbility(player, slotIndex)` with server-side cooldown tracking
    - Implement `isOnCooldown`, `getEquippedAbilities`, `applyEffect` for each ability type (dash, heal, grapple, shield, speedboost)
    - Wire `ActivateAbility` RemoteEvent with server validation
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6_

  - [ ]* 4.2 Write property test: Ability Equip Slot Limit
    - **Property 7: Ability Equip Slot Limit**
    - Generate random sequences of ability equip/unequip operations
    - Assert: equipped ability count never exceeds 2
    - **Validates: Requirements 4.2**

  - [ ]* 4.3 Write property test: Ability Cooldown Enforcement
    - **Property 8: Ability Cooldown Enforcement**
    - Generate random ability activations and time advances
    - Assert: activation rejected while cooldown > 0, succeeds when cooldown elapsed
    - **Validates: Requirements 4.3, 4.4**

  - [x] 4.4 Implement KillStreakManager
    - Create `Server/Systems/KillStreakManager.server.luau`
    - Implement `registerKill(player)` returning streak reward at milestones (3, 5, 7, 10)
    - Implement `registerDeath(player)` resetting streak to 0
    - Implement `getCurrentStreak`, `applyStreakReward` for each tier (Radar Ping, Damage Boost, Airstrike, Juggernaut)
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7_

  - [ ]* 4.5 Write property test: Kill Streak Counter Consistency
    - **Property 9: Kill Streak Counter Consistency**
    - Generate random sequences of kill/death events
    - Assert: streak == consecutive kills since last death, resets to 0 on death
    - **Validates: Requirements 5.1, 5.6**

  - [x] 4.6 Implement FinisherSystem
    - Create `Server/Systems/FinisherSystem.server.luau`
    - Trigger equipped finisher on final kill and streak milestone kills (3, 5, 7, 10)
    - Standard ragdoll for regular kills
    - Fire client remote for VFX rendering
    - _Requirements: 14.1, 14.2, 14.3, 14.4, 14.5, 14.6_

- [x] 5. Implement server-side economy, chests, and progression
  - [x] 5.1 Implement EconomyService
    - Create `Server/Services/EconomyService.server.luau`
    - Implement `getBalance`, `addCoins`, `addGems`, `spendCoins`, `spendGems` with server-side validation
    - Implement `validatePurchase`, `processPurchase` for weapons, abilities, emotes, finishers
    - Implement `processRobuxReceipt` for MarketplaceService callbacks
    - Implement `awardMatchRewards` (25 coins/kill, 10 coins/assist, 45 coins/win, 50 coins/5-streak, 100 coins/MVP)
    - Implement gem awards: 5 gems daily login, 10 gems for 3 consecutive wins
    - Wire `PurchaseItem` RemoteEvent
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 7.1, 7.2, 7.3, 7.4, 7.6, 8.1, 8.2, 8.3, 8.4, 8.5_

  - [ ]* 5.2 Write property test: Economy Transaction Integrity
    - **Property 10: Economy Transaction Integrity**
    - Generate random balances and purchase amounts
    - Assert: if balance >= cost, transaction succeeds and balance -= cost; if balance < cost, transaction rejected and balance unchanged
    - **Validates: Requirements 6.6, 7.6**

  - [ ]* 5.3 Write property test: Consecutive Win Gem Reward
    - **Property 11: Consecutive Win Gem Reward**
    - Generate random sequences of win/loss results
    - Assert: gems awarded exactly at 3-consecutive-win milestones, counter resets after award
    - **Validates: Requirements 7.3**

  - [x] 5.4 Implement ChestService
    - Create `Server/Services/ChestService.server.luau`
    - Implement `updatePlaytime(player, deltaMinutes)` triggering chests at 30/60/120 min thresholds
    - Implement `generateRewards(player, tier)` with tiered reward pools
    - Implement `handleDuplicate(player, itemId)` converting to coin value
    - Implement `getPlaytimeProgress` for UI display
    - Wire `ChestAwarded` RemoteEvent to client
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7_

  - [ ]* 5.5 Write property test: Chest Playtime Thresholds
    - **Property 12: Chest Playtime Thresholds**
    - Generate random playtime increment sequences
    - Assert: Bronze at 30 min, Silver at 60 min, Gold at 120 min exactly
    - **Validates: Requirements 9.1, 9.2, 9.3**

  - [ ]* 5.6 Write property test: Duplicate Item Conversion
    - **Property 13: Duplicate Item Conversion**
    - Generate random chest rewards containing already-owned weapons
    - Assert: duplicate converts to coin value equal to weapon's purchase price
    - **Validates: Requirements 9.5**

  - [x] 5.7 Implement ProgressionService
    - Create `Server/Services/ProgressionService.server.luau`
    - Implement `addXP(player, amount, source)` with level-up detection
    - Implement `calculateMatchXP(stats)`: 50 + 10×kills + 25×win
    - Implement `getLevelReward(level)` awarding at every 5-level milestone (200 coins / 10 gems / cosmetic)
    - Implement `activatePrestige(player)` resetting level to 1, granting badge + 500 gems
    - Cap at level 100, prestige 5
    - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5, 12.6_

  - [ ]* 5.8 Write property test: XP Calculation Formula
    - **Property 15: XP Calculation Formula**
    - Generate random kill counts and win booleans
    - Assert: XP == 50 + (10 × kills) + (25 × win)
    - **Validates: Requirements 12.2**

  - [ ]* 5.9 Write property test: Level and Prestige Cap Invariant
    - **Property 16: Level and Prestige Cap Invariant**
    - Generate random XP accumulation sequences
    - Assert: level never exceeds 100, prestige never exceeds 5, rewards at every multiple of 5
    - **Validates: Requirements 12.1, 12.3, 12.5**

  - [x] 5.10 Implement MasteryService
    - Create `Server/Services/MasteryService.server.luau`
    - Implement per-weapon kill tracking incremented on each kill
    - Implement camo unlock checks: Bronze(50), Silver(100), Gold(250), Diamond(500)
    - Persist mastery kill counts in player data
    - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5, 13.6, 13.7_

  - [ ]* 5.11 Write property test: Weapon Mastery Camo Unlocks
    - **Property 17: Weapon Mastery Camo Unlocks**
    - Generate random weapons and kill counts
    - Assert: Bronze unlocked if kills >= 50, Silver if >= 100, Gold if >= 250, Diamond if >= 500
    - **Validates: Requirements 13.1, 13.2, 13.3, 13.4, 13.5**

  - [x] 5.12 Implement daily login rewards in EconomyService
    - Track 4-day coin cycle (25, 50, 75, 100) with reset after Day 4
    - Track login streak; reset to Day 1 if calendar day missed
    - Award 5 gems per daily login
    - _Requirements: 11.1, 11.2, 11.3, 11.4_

  - [ ]* 5.13 Write property test: Daily Login Reward Cycle
    - **Property 14: Daily Login Reward Cycle**
    - Generate random sequences of daily logins (some consecutive, some with gaps)
    - Assert: coin rewards follow 25/50/75/100 cycle, streak resets on missed day
    - **Validates: Requirements 11.1, 11.3**

- [x] 6. Checkpoint - Economy, progression, and chest systems
  - Ensure all tests pass, ask the user if questions arise.

- [x] 7. Implement server-side networking, anti-exploit, and data persistence
  - [x] 7.1 Implement AntiExploitValidator
    - Create `Server/Systems/AntiExploitValidator.server.luau`
    - Implement `validateRemoteArgs(player, remoteName, args)` type/range/permission checking using `Shared/Utils/ValidationUtils.luau`
    - Implement `checkRateLimit(player, remoteName)` enforcing 60 calls/second per remote per player
    - Implement `logViolation` and `getViolationCount`
    - _Requirements: 23.1, 23.2, 23.4, 23.5, 23.6_

  - [ ]* 7.2 Write property test: Remote Rate Limiting
    - **Property 22: Remote Rate Limiting**
    - Generate random call sequences with varying rates
    - Assert: calls > 60/second rejected, calls <= 60/second processed
    - **Validates: Requirements 23.5**

  - [x] 7.3 Implement DataPersistenceService
    - Create `Server/Services/DataPersistenceService.server.luau`
    - Implement `loadPlayerData(player)` with DataStoreService, retry on failure (3 retries, exponential backoff)
    - Implement `savePlayerData(player)` on leave and periodic auto-save (every 5 minutes)
    - Implement `retryWithBackoff(key, data, attempt)` with exponential delay
    - Handle `Players.PlayerAdded` to load data and `Players.PlayerRemoving` to save
    - Clean up event listeners on player leave to prevent memory leaks
    - _Requirements: 24.1, 24.2, 24.3, 24.4, 24.5, 24.6_

  - [ ]* 7.4 Write property test: DataStore Retry with Exponential Backoff
    - **Property 23: DataStore Retry with Exponential Backoff**
    - Generate random failure sequences (0-4 failures)
    - Assert: retries up to 3 times with increasing delay, stops after 3 failures with alert
    - **Validates: Requirements 24.4**

  - [x] 7.5 Implement PingSystem and AFKDetector
    - Create `Server/Systems/PingSystem.server.luau` with 3-second rate limit per player, team-only broadcast
    - Create `Server/Systems/AFKDetector.server.luau` monitoring input during active matches, warning at 45s, removal at 60s, pausing chest playtime during warning
    - Wire `SendPing` and `SendCallout` RemoteEvents
    - _Requirements: 17.1, 17.2, 17.3, 17.4, 22.1, 22.2, 22.3, 22.4, 22.5_

  - [ ]* 7.6 Write property test: Ping Rate Limiting
    - **Property 18: Ping Rate Limiting**
    - Generate random ping attempt sequences with varying timestamps
    - Assert: pings within 3 seconds of last successful ping are rejected
    - **Validates: Requirements 17.4**

  - [ ]* 7.7 Write property test: AFK Detection Timing
    - **Property 21: AFK Detection Timing**
    - Generate random input timelines during active matches
    - Assert: warning at 45s inactivity, removal at 60s, any input during warning cancels timer
    - **Validates: Requirements 22.1, 22.2, 22.3**

  - [x] 7.8 Implement MatchmakingService and ReplayRecorder
    - Create `Server/Services/MatchmakingService.server.luau` grouping players within 30 seconds or starting with available players
    - Create `Server/Systems/ReplayRecorder.server.luau` recording last 10 seconds of match data, sending replay payload to clients on match end
    - Wire `JoinQueue` RemoteEvent and `ReplayData` remote
    - _Requirements: 3.7, 15.1, 15.2, 15.4_

- [x] 8. Checkpoint - Networking, anti-exploit, and data systems
  - Ensure all tests pass, ask the user if questions arise.

- [x] 9. Implement client-side controllers and UI
  - [x] 9.1 Implement InputController
    - Create `Client/Controllers/InputController.client.luau`
    - Handle PC (keyboard/mouse), Console (gamepad), and Mobile (touch) input
    - Fire appropriate RemoteEvents: `FireWeapon`, `ReloadWeapon`, `ActivateAbility`, `SendPing`, `PlayEmote`
    - Support keybind remapping for PC via settings
    - _Requirements: 1.1, 19.1, 19.2, 20.4_

  - [x] 9.2 Implement HUDController
    - Create `Client/Controllers/HUDController.client.luau`
    - Render ScreenGui with: health bar, ammo count, K/D/A, match timer, ability cooldowns, streak count, minimap (TDM only)
    - Implement `showKillNotification`, `showDamageIndicator` (directional), `showMatchResults`
    - Implement mobile-optimized layout with virtual joystick, fire button, ability buttons, reload button
    - Implement scoreboard toggle
    - _Requirements: 21.1, 21.2, 21.3, 21.4, 21.5, 21.6, 19.2_

  - [x] 9.3 Implement WeaponViewController
    - Create `Client/Controllers/WeaponViewController.client.luau`
    - Render first-person weapon view model (arms, weapon mesh)
    - Handle fire animation, reload animation, weapon swap animation
    - Apply rarity visual features (particle trails for Legendary, glowing model for Mythic)
    - _Requirements: 2.5, 14.6_

  - [x] 9.4 Implement AbilityUIController and EmoteWheelController
    - Create `Client/Controllers/AbilityUIController.client.luau` displaying cooldown timers, slot indicators
    - Create `Client/Controllers/EmoteWheelController.client.luau` with radial menu for 8 equipped emotes
    - Cancel emote on movement/combat input
    - Wire `PlayEmote` RemoteEvent
    - _Requirements: 4.4, 18.1, 18.2, 18.3, 18.4, 18.5_

  - [ ]* 9.5 Write property test: Emote Equip Slot Limit
    - **Property 19: Emote Equip Slot Limit**
    - Generate random emote equip sequences
    - Assert: never more than 8 emotes equipped simultaneously
    - **Validates: Requirements 18.1**

  - [x] 9.6 Implement SettingsController
    - Create `Client/Controllers/SettingsController.client.luau`
    - Sensitivity slider (0.1x–5.0x) with clamping
    - Crosshair customization (shape, color, size, opacity)
    - Audio sliders (master, SFX, music, voice)
    - PC keybind remapping UI
    - Mobile-only matchmaking toggle
    - Wire `UpdateSettings` RemoteEvent to persist via DataPersistenceService
    - _Requirements: 20.1, 20.2, 20.3, 20.4, 20.5, 19.5_

  - [ ]* 9.7 Write property test: Settings Sensitivity Clamping
    - **Property 20: Settings Sensitivity Clamping**
    - Generate random sensitivity values (including out-of-range)
    - Assert: stored value always clamped to [0.1, 5.0]
    - **Validates: Requirements 20.1**

  - [x] 9.8 Implement ReplayController, ShopController, ChestUIController, and PingUIController
    - Create `Client/Controllers/ReplayController.client.luau` playing 5-second slow-motion final kill replay with killer name, weapon, and streak count; hide HUD during replay
    - Create `Client/Controllers/ShopController.client.luau` displaying shop items, bundle contents, prices, handling purchase confirmation
    - Create `Client/Controllers/ChestUIController.client.luau` with chest opening animation showing rewards
    - Create `Client/Controllers/PingUIController.client.luau` rendering world pings and callout HUD notifications for teammates
    - _Requirements: 15.1, 15.2, 15.3, 8.5, 9.7, 17.1, 17.2, 17.3_

- [x] 10. Checkpoint - Client controllers and UI
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 11. Implement remaining shared validation property tests
  - [ ]* 11.1 Write property test: Weapon Stat Schema Completeness
    - **Property 3: Weapon Stat Schema Completeness**
    - Iterate all weapons in WeaponDefinitions
    - Assert: every weapon has all required fields with values in valid ranges (positive numbers, movementSpeedModifier 0.5-1.5)
    - **Validates: Requirements 2.6**

  - [ ]* 11.2 Write property test: Movement Speed Modification
    - **Property 4: Movement Speed Modification**
    - Generate random weapon modifiers and base speeds
    - Assert: effective speed == baseSpeed × modifier
    - **Validates: Requirements 2.7**

- [x] 12. Implement integration wiring and training range
  - [x] 12.1 Wire server Init script connecting all services and systems
    - Update `Server/Init.server.luau` to initialize all services in correct order
    - Set up RemoteEvents/RemoteFunctions in ReplicatedStorage
    - Connect CombatService kill events → KillStreakManager, EconomyService, MasteryService, ProgressionEngine, FinisherSystem
    - Connect MatchService end → EconomyService rewards, ProgressionEngine XP, ReplayRecorder
    - Connect DataPersistenceService to PlayerAdded/PlayerRemoving
    - Ensure proper lifecycle cleanup with `:Disconnect()` on player leave
    - _Requirements: 23.1, 24.5, 24.6_

  - [x] 12.2 Wire client Init script connecting all controllers
    - Update `Client/Init.client.luau` to initialize all controllers
    - Connect RemoteEvent listeners for server → client communication (DamageIndicator, KillFeed, MatchState, StreakNotification, ChestAwarded, ReplayData, EconomyUpdate, AbilityCooldown)
    - Set up input routing from InputController to appropriate remotes
    - Handle platform detection (PC/Console/Mobile) for UI layout selection
    - _Requirements: 19.1, 21.6_

  - [x] 12.3 Implement Training Range
    - Create training range server logic: solo environment, no time limit, no XP/coins/gems awarded
    - Include stationary and moving target dummies displaying damage numbers
    - Allow testing all owned weapons and abilities
    - Display accuracy, hits, damage dealt on HUD
    - Handle exit returning player to lobby
    - _Requirements: 16.1, 16.2, 16.3, 16.4, 16.5_

  - [x] 12.4 Implement mobile aim assist
    - Add aim assist logic to CombatService: slight aim magnetism for Mobile players at Level 20+
    - Restrict to Mobile platform only (no PC/Console)
    - _Requirements: 19.3, 19.4_

  - [ ]* 12.5 Write integration tests for cross-system flows
    - Test kill → streak update → economy award → mastery increment → XP award propagation
    - Test DataStore round-trip: save → load produces identical PlayerSaveData
    - Test match flow: queue → match start → kill → score → end → results
    - Test anti-exploit: fabricated remote calls rejected with logged violations
    - _Requirements: 5.1, 6.1, 12.2, 13.1, 23.2, 24.1_

- [x] 13. Final checkpoint - Full integration
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate the 23 universal correctness properties from the design
- Unit tests validate specific examples and edge cases
- All game state is server-authoritative; client handles only rendering and input
- Use `--!strict` type annotations in all Luau files
- Use `task.wait()` instead of deprecated `wait()`
- Always disconnect event listeners on player leave to prevent memory leaks

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2", "1.3"] },
    { "id": 2, "tasks": ["1.4", "1.5", "1.6", "1.7"] },
    { "id": 3, "tasks": ["2.1", "2.4", "2.6"] },
    { "id": 4, "tasks": ["2.2", "2.3", "2.5", "2.7"] },
    { "id": 5, "tasks": ["4.1", "4.4", "4.6"] },
    { "id": 6, "tasks": ["4.2", "4.3", "4.5", "5.1"] },
    { "id": 7, "tasks": ["5.2", "5.3", "5.4", "5.7", "5.10", "5.12"] },
    { "id": 8, "tasks": ["5.5", "5.6", "5.8", "5.9", "5.11", "5.13"] },
    { "id": 9, "tasks": ["7.1", "7.3", "7.5", "7.8"] },
    { "id": 10, "tasks": ["7.2", "7.4", "7.6", "7.7"] },
    { "id": 11, "tasks": ["9.1", "9.2", "9.3", "9.4", "9.6", "9.8"] },
    { "id": 12, "tasks": ["9.5", "9.7", "11.1", "11.2"] },
    { "id": 13, "tasks": ["12.1", "12.2", "12.3", "12.4"] },
    { "id": 14, "tasks": ["12.5"] }
  ]
}
```
