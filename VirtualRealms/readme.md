# VirtualRealms Gaming Guild Smart Contract

A decentralized gaming guild treasury where players contribute loot shares and collectively vote on prize pool distributions, built on the Stacks blockchain.

## Overview

VirtualRealms Gaming Guild is a player-governed guild that enables members to contribute to a shared treasury, submit prize distribution requests for tournament champions, and collectively vote on reward allocations. The contract manages the entire lifecycle of prize quests in a transparent and fair manner.

## Key Features

- **Guild Treasury System**: Players pay tribute to build a shared prize pool
- **Democratic Prize Distribution**: Reward requests are approved through member voting
- **Time-bound Quest Rights**: Prize request submission is active for a limited period
- **Transparent Reward System**: All prize decisions are made collectively

## Contract Constants

| Constant | Description |
|----------|-------------|
| `JUDGMENT_PERIOD` | Quest voting duration (~24 hours) |
| `MEMBER_TENURE` | Period members can submit quests (~10 days) |
| `MAX_PRIZE_POOL` | Maximum prize amount limit |

## Core Functions

### For Guild Members

#### `pay_guild_tribute`
Join the guild by paying tribute in STX tokens.
```clarity
(pay_guild_tribute (tribute_size uint))
```
- **Parameters**: `tribute_size` - Amount of STX to contribute
- **Returns**: `(ok true)` on success
- **Errors**:
  - `ERR_PARAMETER_ERROR` - Invalid input values
  - `ERR_TRIBUTE_NEEDED` - Zero amount not allowed
  - STX transfer failures

#### `initiate_reward_quest`
Submit a prize distribution request for a tournament champion.
```clarity
(initiate_reward_quest (champion_wallet principal) (prize_amount uint))
```
- **Parameters**: 
  - `champion_wallet` - Principal address of the champion
  - `prize_amount` - Requested prize amount
- **Returns**: `(ok quest_id)` with the new quest ID
- **Errors**:
  - `ERR_NOT_MEMBER` - Caller not an active guild member
  - `ERR_PARAMETER_ERROR` - Invalid champion principal
  - `ERR_REWARD_TOO_LOW` - Invalid prize amount
  - `ERR_QUEST_ENDED` - Member tenure expired

#### `judge_reward_quest`
Vote on a pending prize distribution quest.
```clarity
(judge_reward_quest (quest_id uint) (approve_reward bool))
```
- **Parameters**:
  - `quest_id` - ID of the quest to judge
  - `approve_reward` - Boolean indicating approval/rejection
- **Returns**: `(ok true)` on successful vote
- **Errors**:
  - `ERR_QUEST_UNKNOWN` - Invalid quest ID
  - `ERR_NOT_MEMBER` - Caller not a guild member
  - `ERR_QUEST_ENDED` - Voting period closed
  - `ERR_VOTE_RECORDED` - Already voted on this quest

### System Functions

#### `cycle_forward`
Updates the system's game cycle counter.
```clarity
(cycle_forward)
```
- **Returns**: `(ok updated_cycle)` with the new cycle value
- **Errors**:
  - `ERR_COOLDOWN_ERROR` - Repeated calls from same member

#### `get_game_cycle`
Read-only function to check the current game cycle.
```clarity
(get_game_cycle)
```
- **Returns**: Current game cycle value

## Error Codes

| Code | Description |
|------|-------------|
| `ERR_NOT_MEMBER (u1)` | Caller lacks guild membership |
| `ERR_TRIBUTE_NEEDED (u2)` | Tribute amount insufficient |
| `ERR_INVALID_QUEST (u3)` | Quest parameters invalid |
| `ERR_VOTE_RECORDED (u4)` | Already voted on this quest |
| `ERR_QUEST_ENDED (u5)` | Action timeframe has expired |
| `ERR_COOLDOWN_ERROR (u6)` | Sequential updates from same member not allowed |
| `ERR_PARAMETER_ERROR (u7)` | Input validation failed |
| `ERR_REWARD_TOO_LOW (u8)` | Amount below minimum threshold |
| `ERR_QUEST_UNKNOWN (u9)` | Referenced quest doesn't exist |

## Implementation Details

### Data Structures

The contract uses three primary data maps:
1. `guild_roster` - Tracks member tributes and standing
2. `reward_quests` - Stores prize distribution request details
3. `vote_journal` - Records voting activity per member per quest

### Security Considerations

- Sequential update protection prevents cycle manipulation
- Comprehensive input validation for all public functions
- Protection against duplicate voting
- Time-bound actions with deadline enforcement

## Usage Example

1. Join the guild:
```clarity
;; Pay 100 STX tribute to join
(contract-call? .virtualrealms-guild pay_guild_tribute u100000000)
```

2. Submit a prize distribution quest:
```clarity
;; Request 50 STX prize for champion SP123...
(contract-call? .virtualrealms-guild initiate_reward_quest 'SP123456789ABCDEFGHJKL u50000000)
```

3. Vote on a reward quest:
```clarity
;; Approve quest #5
(contract-call? .virtualrealms-guild judge_reward_quest u5 true)
```

4. Check current game cycle:
```clarity
(contract-call? .virtualrealms-guild get_game_cycle)
```