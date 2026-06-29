# Requirements Document

## Introduction

This document defines the requirements for a Roblox competitive shooter game featuring Deathmatch and Free-for-All game modes. Players engage in fast-paced gun combat across themed maps, earn coins through kills and wins, unlock weapons and abilities, and progress through a dual-currency economy (coins and gems). The game supports 1v1 through 5v5 team matches and free-for-all modes with cross-platform support (PC, Console, Mobile). Key features include a weapon rarity system (Common through Mythic), purchasable combat abilities, kill streaks, tiered playtime chests, weapon mastery camos, a prestige system, and a training range. The game is built using Rojo file sync with Luau scripts following a strict Server/Client/Shared architecture.

## Glossary

- **Game_Server**: The Roblox server instance hosting a match session, responsible for authoritative game state
- **Player**: A user participating in the game
- **Combat_System**: The server-side module handling weapon firing, hit detection, damage calculation, and kill attribution
- **Match_Manager**: The server-side system managing match lifecycle: countdown, timer, scoring, and results
- **Weapon_System**: The shared module defining weapon stats (damage, fire rate, range, reload time) and handling equip/fire/reload logic
- **Ability_System**: The module managing player abilities (dash, heal, grapple, shield, speed boost) including cooldowns and effects
- **Economy_Service**: The server-side system tracking coins, gems, and Robux purchase transactions with persistent DataStore storage
- **Loadout_Manager**: The system managing weapon, ability, finisher, and emote equipment before matches
- **Chest_System**: The module awarding tiered playtime-based chests (bronze, silver, gold) with randomized rewards
- **Kill_Streak_Manager**: The system tracking consecutive kills without death and granting streak rewards
- **Map_System**: The module handling map selection, rotation, and spawn point management
- **HUD_Manager**: The client-side UI system displaying health, ammo, kills, timer, ability cooldowns, and notifications
- **Leaderboard_Service**: The system tracking and displaying in-match scores and all-time stats
- **Matchmaking_Service**: The system grouping players into appropriate match lobbies based on mode and party size
- **Spawn_System**: The server-side module managing respawn timers, spawn point selection, and spawn protection
- **Progression_Engine**: The system tracking player XP, levels, prestige, and unlocks
- **Mastery_System**: The module tracking per-weapon kill counts and awarding mastery camos at milestones
- **Finisher_System**: The module managing equipped kill effects that play on special kills
- **Ping_System**: The team communication module for location/enemy pings and quick callouts
- **Replay_System**: The client-side module recording and displaying the final kill of a match
- **Training_Range**: A solo practice environment for testing weapons and abilities
- **AFK_Detector**: The server-side module detecting idle players and removing them from active matches
- **Settings_Manager**: The client-side module managing player preferences for sensitivity, crosshair, audio, and keybinds

## Requirements

### Requirement 1: Core Shooting Mechanics

**User Story:** As a player, I want responsive and accurate gun combat, so that skill determines the outcome of fights.

#### Acceptance Criteria

1. WHEN a Player presses the fire input, THE Combat_System SHALL fire the equipped weapon and perform server-side hit detection within 150 milliseconds of input
2. WHEN a hit is confirmed on the server, THE Combat_System SHALL reduce the target Player's health by the weapon's damage value adjusted for weapon rarity stat bonus
3. WHEN a Player presses the reload input, THE Weapon_System SHALL initiate the weapon's reload animation and replenish ammunition after the weapon's reload duration completes
4. WHILE a Player is reloading, THE Weapon_System SHALL prevent the Player from firing until the reload completes
5. WHEN a Player's health reaches zero, THE Combat_System SHALL register a kill for the attacker and a death for the victim
6. THE Combat_System SHALL validate all hit registration on the server using server-side raycasting to prevent client-side exploitation
7. WHEN a headshot is confirmed, THE Combat_System SHALL apply a 1.5x damage multiplier to the base weapon damage

### Requirement 2: Weapon Arsenal and Rarity System

**User Story:** As a player, I want a variety of weapons with distinct stats and rarity tiers, so that I can find a playstyle that suits me and have aspirational upgrades.

#### Acceptance Criteria

1. THE Weapon_System SHALL provide 10 Common-rarity starting weapons available to all Players without purchase, covering a balanced mix across weapon types
2. THE Weapon_System SHALL provide 10 to 20 additional unlockable weapons across Rare, Epic, Legendary, and Mythic rarity tiers
3. THE Weapon_System SHALL support the following weapon categories: Assault Rifles (balanced damage and fire rate), Shotguns (high damage at close range, low range), Snipers (high damage, high range, slow fire rate), Revolvers (high fire rate, medium damage), Dual Pistols (fast fire, low damage per shot), Rocket Launcher (slow, explosive area damage), Crossbow (silent, high damage, slow reload), and LMG (large magazine, reduced movement speed)
4. THE Weapon_System SHALL support the following melee weapons: Knife (fast attack speed, low damage), Fists (fastest speed, lowest damage, stun chance), and Scythe (slow speed, high damage, wide arc)
5. THE Weapon_System SHALL apply rarity stat bonuses: Common (base stats), Rare (+5% stat bonus, costs 500-1500 coins), Epic (+10% stat bonus with unique reload animation, costs 2000-4000 coins), Legendary (+15% stat bonus with unique firing sound and particle trail, costs 500 gems), Mythic (+20% stat bonus with unique kill effect and glowing weapon model, costs 1000 gems)
6. THE Weapon_System SHALL define each weapon with the following stats: damage, fire rate, range, reload time, magazine size, and movement speed modifier
7. WHEN a Player equips a weapon, THE Weapon_System SHALL apply the weapon's movement speed modifier to the Player's base movement speed

### Requirement 3: Match Modes and Structure

**User Story:** As a player, I want to choose between team-based and free-for-all modes, so that I can play the style I prefer.

#### Acceptance Criteria

1. THE Match_Manager SHALL support two game modes: Team Deathmatch (1v1 through 5v5) and Free-for-All (2 to 10 players)
2. WHEN a match begins, THE Match_Manager SHALL start a 5-minute countdown timer visible to all Players
3. WHEN the match timer reaches zero, THE Match_Manager SHALL end the match and declare the Player or team with the most kills as the winner
4. IF two Players or teams have equal kills when the timer ends, THEN THE Match_Manager SHALL use fewest deaths as the tiebreaker
5. WHILE a match is active, THE Match_Manager SHALL continuously respawn eliminated Players after a 3-second respawn timer
6. WHEN a Player respawns, THE Spawn_System SHALL grant 3 seconds of spawn protection (invincibility) and select a spawn point at maximum distance from enemy Players
7. THE Matchmaking_Service SHALL group Players into matches within 30 seconds of queue entry or start with available Players
8. THE Match_Manager SHALL support custom private matches with configurable settings: time limit, weapon restrictions, and specific map selection

### Requirement 4: Ability System

**User Story:** As a player, I want special abilities that complement my gunplay, so that matches have more tactical depth.

#### Acceptance Criteria

1. THE Ability_System SHALL provide the following abilities: Dash (free, 5-second cooldown, burst of speed in movement direction), Heal (500 coins, 20-second cooldown, restores 30% health over 3 seconds), Grapple (750 coins, 8-second cooldown, hooks to surfaces for vertical mobility), Shield (1000 coins, 25-second cooldown, temporary barrier absorbing 50 damage), and Speed Boost (600 coins, 15-second cooldown, 50% increased movement for 3 seconds)
2. THE Loadout_Manager SHALL allow each Player to equip up to 2 abilities before a match begins
3. WHEN a Player activates an ability, THE Ability_System SHALL execute the ability effect and start the cooldown timer on the server
4. WHILE an ability is on cooldown, THE Ability_System SHALL prevent the Player from activating that ability and display remaining cooldown time on the HUD
5. THE Ability_System SHALL validate all ability activations on the server to prevent cooldown bypass exploits
6. WHEN a Player purchases a new ability, THE Ability_System SHALL permanently add the ability to the Player's available ability pool stored in DataStore

### Requirement 5: Kill Streak System

**User Story:** As a player, I want to be rewarded for consecutive kills, so that I feel a power surge when I'm performing well.

#### Acceptance Criteria

1. THE Kill_Streak_Manager SHALL track consecutive kills without death for each Player during a match
2. WHEN a Player reaches a 3-kill streak, THE Kill_Streak_Manager SHALL grant Radar Ping (reveals all enemy positions for 5 seconds)
3. WHEN a Player reaches a 5-kill streak, THE Kill_Streak_Manager SHALL grant Damage Boost (20% increased damage for 10 seconds)
4. WHEN a Player reaches a 7-kill streak, THE Kill_Streak_Manager SHALL grant Airstrike (marks a targetable zone that deals heavy damage after a 3-second delay)
5. WHEN a Player reaches a 10-kill streak, THE Kill_Streak_Manager SHALL grant Juggernaut Mode (double health and increased armor for 15 seconds)
6. WHEN a Player dies, THE Kill_Streak_Manager SHALL reset the Player's kill streak counter to zero
7. THE Kill_Streak_Manager SHALL display current streak count on the Player's HUD and announce streaks of 5 or higher to all Players in the match

### Requirement 6: Economy — Coins

**User Story:** As a player, I want to earn coins through gameplay, so that I can unlock new weapons and items through skill and dedication.

#### Acceptance Criteria

1. WHEN a Player eliminates an enemy, THE Economy_Service SHALL award the Player 25 coins
2. WHEN a Player assists in an elimination (dealt damage within 5 seconds of the kill), THE Economy_Service SHALL award the Player 10 coins
3. WHEN a Player's team wins a Team Deathmatch or a Player finishes first in Free-for-All, THE Economy_Service SHALL award 45 coins
4. WHEN a Player achieves a 5-kill streak, THE Economy_Service SHALL award a bonus of 50 coins
5. WHEN a Player earns MVP status (most kills in the match), THE Economy_Service SHALL award a bonus of 100 coins
6. THE Economy_Service SHALL allow Players to spend coins on: weapons (Rare and Epic tiers), emotes, spray tags, kill sound effects, custom crosshairs, lobby animations, and finishers
7. THE Economy_Service SHALL persist all coin balances in DataStore and validate all transactions on the server

### Requirement 7: Economy — Gems

**User Story:** As a player, I want a premium earnable currency for exclusive items, so that I have aspirational goals to work toward.

#### Acceptance Criteria

1. THE Economy_Service SHALL maintain a separate gem balance for each Player persisted in DataStore
2. WHEN a Player logs in daily, THE Economy_Service SHALL award 5 gems
3. WHEN a Player achieves 3 consecutive match wins, THE Economy_Service SHALL award 10 gems
4. THE Economy_Service SHALL allow Players to spend gems on: Legendary weapons (500 gems), Mythic weapons (1000 gems), and exclusive ability skins
5. WHEN a Player opens a Silver or Gold chest, THE Chest_System SHALL include gems in the reward pool (5 gems for Silver, 15 gems for Gold)
6. THE Economy_Service SHALL validate all gem transactions on the server and reject client-initiated gem modifications

### Requirement 8: Bundles and Premium Shop

**User Story:** As a player, I want themed bundles and premium cosmetics, so that I can personalize my character and stand out.

#### Acceptance Criteria

1. THE Economy_Service SHALL support Robux-purchasable bundles containing a combination of: weapon skin, character outfit, kill effect, and victory emote
2. THE Economy_Service SHALL support individual Robux purchases for: weapon skins and character skins
3. THE Economy_Service SHALL ensure all Robux purchases are cosmetic only and provide no gameplay stat advantage
4. WHEN a Player purchases a bundle or item with Robux, THE Economy_Service SHALL immediately grant all contained items and persist ownership in DataStore
5. THE Economy_Service SHALL display bundle contents and pricing clearly in the shop interface before purchase confirmation

### Requirement 9: Playtime Chest System

**User Story:** As a player, I want to earn rewards for longer play sessions, so that I feel incentivized to keep playing.

#### Acceptance Criteria

1. WHEN a Player accumulates 30 minutes of active match playtime, THE Chest_System SHALL award a Bronze Chest containing: 1 common or rare item and 50 coins
2. WHEN a Player accumulates 60 minutes of active match playtime, THE Chest_System SHALL award a Silver Chest containing: 1 rare or epic item, 100 coins, and 5 gems
3. WHEN a Player accumulates 120 minutes of active match playtime, THE Chest_System SHALL award a Gold Chest containing: 1 epic or legendary item, 200 coins, and 15 gems
4. THE Chest_System SHALL track playtime on the server to prevent client-side time manipulation
5. IF a chest contains a weapon the Player already owns, THEN THE Chest_System SHALL convert the duplicate into a coin reward equivalent to the weapon's purchase price
6. THE Chest_System SHALL include wraps (weapon skins), coins, gems, and weapons in the possible reward pool
7. WHEN a chest is awarded, THE Chest_System SHALL display an opening animation on the client showing the rewards received

### Requirement 10: Maps and Environment

**User Story:** As a player, I want varied maps with different tactical layouts, so that each match feels different and rewards map knowledge.

#### Acceptance Criteria

1. THE Map_System SHALL provide a minimum of 5 maps at launch: Desert Outpost (open sightlines, sniper-favored), Futuristic City (vertical gameplay, rooftops and alleys), Military Base (balanced layout, vehicles as cover), Abandoned Factory (tight corridors, shotgun-favored), and Sky Fortress (floating platforms, fall-off danger zones)
2. WHEN a match ends, THE Map_System SHALL rotate to a different map for the next match, avoiding immediate repetition
3. THE Map_System SHALL define a minimum of 8 spawn points per map distributed to prevent spawn camping
4. THE Map_System SHALL ensure each map provides viable gameplay for all weapon categories through varied engagement distances
5. WHEN a Player falls off the map boundary (Sky Fortress fall zones), THE Map_System SHALL register a self-inflicted death and respawn the Player normally

### Requirement 11: Daily Login and Rewards

**User Story:** As a player, I want daily login incentives, so that I have a reason to come back each day.

#### Acceptance Criteria

1. WHEN a Player logs in for the first time in a calendar day, THE Economy_Service SHALL award daily login coins on a scaling 4-day cycle: Day 1 = 25 coins, Day 2 = 50 coins, Day 3 = 75 coins, Day 4 = 100 coins, then reset
2. WHEN a Player logs in daily, THE Economy_Service SHALL award 5 gems as a daily gem bonus
3. THE Economy_Service SHALL track daily login streaks and reset the streak counter if a Player misses a calendar day
4. WHEN a Player claims daily rewards, THE Economy_Service SHALL display a notification showing the rewards received and current streak day

### Requirement 12: Player Leveling and Prestige

**User Story:** As a player, I want to level up and prestige for long-term progression, so that I always have something to work toward.

#### Acceptance Criteria

1. THE Progression_Engine SHALL track Player XP with a max level of 100
2. WHEN a Player completes a match, THE Progression_Engine SHALL award XP: 50 base XP + 10 XP per kill + 25 XP for a match win
3. WHEN a Player reaches a level milestone (every 5 levels), THE Progression_Engine SHALL award alternating rewards: 200 coins or 10 gems or a cosmetic unlock (spray, crosshair, or lobby animation)
4. WHEN a Player reaches Level 100, THE Progression_Engine SHALL unlock the prestige option allowing the Player to reset to Level 1 in exchange for: a prestige badge, gold nameplate, and 500 gems
5. THE Progression_Engine SHALL support up to Prestige 5, with each prestige granting a unique visual badge and nameplate color
6. THE Progression_Engine SHALL persist level, XP, and prestige data in DataStore

### Requirement 13: Weapon Mastery and Camos

**User Story:** As a player, I want to earn exclusive camos by mastering specific weapons, so that I have long-term progression goals tied to my favorite guns.

#### Acceptance Criteria

1. THE Mastery_System SHALL track total kills per weapon for each Player
2. WHEN a Player reaches 50 kills with a weapon, THE Mastery_System SHALL unlock the Bronze camo for that weapon
3. WHEN a Player reaches 100 kills with a weapon, THE Mastery_System SHALL unlock the Silver camo for that weapon
4. WHEN a Player reaches 250 kills with a weapon, THE Mastery_System SHALL unlock the Gold camo for that weapon
5. WHEN a Player reaches 500 kills with a weapon, THE Mastery_System SHALL unlock the Diamond camo for that weapon
6. THE Mastery_System SHALL display mastery progress and available camos in the loadout screen
7. THE Mastery_System SHALL persist all mastery kill counts in DataStore

### Requirement 14: Finisher (Kill Effect) System

**User Story:** As a player, I want to equip flashy kill effects, so that my eliminations feel impactful and I can show off my style.

#### Acceptance Criteria

1. THE Finisher_System SHALL provide the following purchasable finishers (1000-2500 coins each): Dissolve, Explosion, Freeze Shatter, Lightning Strike, Vaporize, and Ragdoll Launch
2. THE Loadout_Manager SHALL allow each Player to equip 1 active finisher at a time
3. WHEN a Player's finisher is equipped and the Player scores the final kill of a match, THE Finisher_System SHALL play the equipped finisher effect on the victim
4. WHEN a Player's finisher is equipped and the Player scores a kill streak milestone kill (3, 5, 7, or 10), THE Finisher_System SHALL play the equipped finisher effect
5. WHEN a regular kill occurs (not final kill or streak milestone), THE Combat_System SHALL play a standard ragdoll death animation
6. THE Finisher_System SHALL render all finisher visual effects on the client to preserve server performance

### Requirement 15: Final Kill Replay

**User Story:** As a player, I want to see the final kill of the match replayed in slow motion, so that matches end with a cinematic moment.

#### Acceptance Criteria

1. WHEN a match ends, THE Replay_System SHALL play a slow-motion replay of the final kill from the killer's perspective to all Players for 5 seconds
2. THE Replay_System SHALL display the killer's name, weapon used, and kill streak count during the replay
3. WHILE the replay is playing, THE HUD_Manager SHALL hide standard HUD elements and display a "FINAL KILL" banner
4. THE Replay_System SHALL record only the final 10 seconds of match data on the server to minimize memory usage

### Requirement 16: Training Range

**User Story:** As a player, I want a practice area to test weapons and abilities, so that I can improve my aim and learn mechanics without match pressure.

#### Acceptance Criteria

1. THE Training_Range SHALL provide a solo environment accessible from the main lobby with no time limit
2. THE Training_Range SHALL include stationary and moving target dummies that display damage numbers when hit
3. THE Training_Range SHALL allow Players to equip and test any weapon in their inventory and any owned ability
4. THE Training_Range SHALL display accuracy percentage, hits, and damage dealt in real-time on the HUD
5. WHEN a Player exits the Training Range, THE Game_Server SHALL return the Player to the main lobby without awarding any XP, coins, or gems

### Requirement 17: Communication and Ping System

**User Story:** As a player, I want to communicate with teammates quickly, so that I can coordinate without needing voice chat.

#### Acceptance Criteria

1. THE Ping_System SHALL allow Players in Team Deathmatch to ping a world location visible to all teammates for 5 seconds
2. THE Ping_System SHALL provide a quick-callout radial menu with pre-set messages: "Enemy Spotted", "Need Backup", "Push Now", "Fall Back", "Healing", and "Nice Shot"
3. WHEN a Player uses a callout, THE Ping_System SHALL display the message to all teammates in the chat feed and as a brief HUD notification
4. THE Ping_System SHALL limit pings to 1 per 3 seconds per Player to prevent spam
5. THE Game_Server SHALL support Roblox spatial voice chat for verified 13+ users without additional implementation

### Requirement 18: Emote Wheel

**User Story:** As a player, I want to perform emotes during matches, so that I can express myself and celebrate.

#### Acceptance Criteria

1. THE Loadout_Manager SHALL allow Players to equip up to 8 emotes to an emote wheel
2. WHEN a Player opens the emote wheel and selects an emote, THE Game_Server SHALL play the emote animation on the Player's character visible to all nearby Players
3. WHILE an emote animation is playing, THE Combat_System SHALL allow the Player to cancel the emote by providing any movement or combat input
4. THE Economy_Service SHALL support emote purchases with coins (200-500 coins per emote)
5. THE Loadout_Manager SHALL provide 2 default emotes (wave, thumbs up) free to all Players

### Requirement 19: Cross-Platform Support and Mobile

**User Story:** As a player, I want to play on any device, so that I can enjoy the game whether I'm on PC, console, or mobile.

#### Acceptance Criteria

1. THE Game_Server SHALL support cross-platform matchmaking between PC, Console, and Mobile players by default
2. THE HUD_Manager SHALL provide a mobile-optimized UI layout with virtual joystick, fire button, ability buttons, and reload button sized for touch input
3. WHEN a Mobile Player reaches Level 20, THE Combat_System SHALL unlock aim assist for that Player providing slight aim magnetism toward targets when aiming down sights
4. THE Combat_System SHALL restrict aim assist to Mobile platform players only; PC and Console players SHALL NOT receive aim assist
5. THE Settings_Manager SHALL allow Mobile players to opt into mobile-only matchmaking to avoid cross-platform lobbies

### Requirement 20: Settings and Customization

**User Story:** As a player, I want to customize my controls and visual settings, so that the game feels comfortable on my preferred device.

#### Acceptance Criteria

1. THE Settings_Manager SHALL provide adjustable aim sensitivity (0.1x to 5.0x) stored per Player in DataStore
2. THE Settings_Manager SHALL provide crosshair customization: shape (dot, cross, circle), color, size, and opacity
3. THE Settings_Manager SHALL provide audio volume sliders for: master, sound effects, music, and voice chat
4. THE Settings_Manager SHALL provide keybind remapping for PC players covering all gameplay actions
5. THE Settings_Manager SHALL persist all settings in DataStore and load them when the Player joins

### Requirement 21: User Interface and HUD

**User Story:** As a player, I want clear and informative UI during matches, so that I always know my game state and can react quickly.

#### Acceptance Criteria

1. THE HUD_Manager SHALL display the following during gameplay: Player health bar, ammo count and magazine indicator, kill/death/assist count, match timer, ability cooldown indicators, current kill streak count, and minimap (Team Deathmatch only showing teammate positions)
2. WHEN a Player eliminates an enemy, THE HUD_Manager SHALL display a kill notification with the weapon used and the victim's name
3. WHEN a Player takes damage, THE HUD_Manager SHALL display a directional damage indicator showing the source direction
4. THE HUD_Manager SHALL display a real-time scoreboard accessible via a keybind showing all Player names, kills, deaths, and assists
5. WHEN a match ends, THE HUD_Manager SHALL display a results screen showing final standings, personal stats, coins earned, XP earned, and MVP designation
6. THE HUD_Manager SHALL render all UI elements on the client using Roblox ScreenGui to maintain server performance

### Requirement 22: Anti-AFK System

**User Story:** As a player, I want idle players removed from matches, so that matches remain competitive and playtime rewards cannot be exploited.

#### Acceptance Criteria

1. THE AFK_Detector SHALL monitor Player input on the server (movement, firing, ability use) during active matches
2. WHEN a Player has provided no input for 45 seconds, THE AFK_Detector SHALL display a 15-second warning on the Player's screen
3. IF a Player provides no input for a total of 60 seconds, THEN THE AFK_Detector SHALL remove the Player from the active match and return the Player to the lobby
4. THE AFK_Detector SHALL pause playtime tracking for the Chest_System during the warning period to prevent idle chest farming
5. THE AFK_Detector SHALL only operate during active matches, not while in lobby or training range

### Requirement 23: Networking and Anti-Exploit

**User Story:** As a player, I want a fair game free of cheaters, so that my skill determines my success.

#### Acceptance Criteria

1. THE Game_Server SHALL maintain authoritative control over all game state: health values, kill attribution, economy balances, match scores, and ability cooldowns
2. WHEN a RemoteEvent or RemoteFunction is received from a client, THE Game_Server SHALL validate all arguments for type, range, and permission before processing
3. THE Combat_System SHALL perform all hit detection and damage calculation on the server using server-side raycasting
4. IF a client sends data that fails validation, THEN THE Game_Server SHALL reject the request and log the violation for the Player
5. THE Game_Server SHALL rate-limit RemoteEvent calls per Player to prevent remote spam (maximum 60 calls per second per remote per Player)
6. THE Economy_Service SHALL reject any client-initiated modification to coin, gem, or inventory data
7. THE Chest_System SHALL validate playtime accumulation on the server to prevent time manipulation exploits

### Requirement 24: Player Lifecycle and Data Persistence

**User Story:** As a player, I want my progress saved reliably, so that I never lose my unlocks, currency, or stats.

#### Acceptance Criteria

1. WHEN a Player joins the game, THE Game_Server SHALL load the Player's persistent data from DataStore including: coin balance, gem balance, owned weapons, owned abilities, owned emotes, owned finishers, equipped loadout, level, XP, prestige, mastery stats, settings, and playtime records
2. WHEN a Player leaves the game or is disconnected, THE Game_Server SHALL save all Player data to DataStore immediately
3. THE Game_Server SHALL perform periodic auto-saves of Player data every 5 minutes during active sessions
4. IF a DataStore save fails, THEN THE Game_Server SHALL retry the save up to 3 times with exponential backoff before alerting the Player
5. WHEN a Player joins the game, THE Game_Server SHALL disconnect all event listeners from a previous session for that Player to prevent memory leaks
6. THE Game_Server SHALL use `task.wait()` for all delay operations and properly clean up connections using `:Disconnect()` when Players leave
