# PetPal - Digital Pet Care and Community Platform

A blockchain-based platform built on Stacks that enables pet owners to register their pets, track care activities, schedule vet checkups, and earn rewards through the PetPal Care Token (PCT) ecosystem.

## Overview

PetPal combines pet management with a tokenized reward system, incentivizing responsible pet ownership through on-chain activity tracking and milestone achievements.

## Features

### 🐾 Pet Management
- **Pet Registration**: Register pets with detailed profiles including name, type, breed, age, and weight
- **Profile Updates**: Track and update pet information over time
- **Multi-Pet Support**: Manage multiple pets under a single owner profile
- **Pet Types**: Support for dogs, cats, birds, fish, and reptiles

### 📊 Activity Tracking
- **Care Activities**: Log daily care activities (feeding, walking, grooming, playing)
- **Duration Tracking**: Record time spent on each care activity
- **Activity Notes**: Add custom notes for each care session
- **Historical Records**: Maintain complete care history on-chain

### 🏥 Veterinary Management
- **Vet Checkup Scheduling**: Schedule and record veterinary visits
- **Checkup Types**: Track routine checkups, emergency visits, and vaccinations
- **Vet Notes**: Store veterinarian observations and recommendations
- **Next Checkup Reminders**: Set future checkup dates

### 🪙 Token Rewards (PCT)
PetPal Care Token incentivizes active pet care with automatic rewards:
- **Care Activity Rewards**: 1.5 PCT per logged activity
- **Vet Checkup Rewards**: 3 PCT per completed checkup
- **Milestone Rewards**: 8 PCT for achievement unlocks

**Token Details:**
- Name: PetPal Care Token
- Symbol: PCT
- Decimals: 6
- Max Supply: 40,000 PCT (40,000,000,000 micro-tokens)

### 🏆 Milestones & Achievements
Unlock special rewards by reaching care milestones:
- **Caregiver-20**: Complete 20 care activities
- **Vet-Regular-10**: Complete 10 vet visits
- **Multi-Pet-3**: Register 3 or more pets

### 👤 Owner Profiles
- Custom usernames
- Pet ownership count
- Total care activities
- Vet visit tracking
- Owner level progression (based on care minutes)
- Join date tracking

## Contract Architecture

### Data Structures

#### Owner Profiles
```clarity
{
  username: (string-ascii 32),
  pets-owned: uint,
  care-activities: uint,
  vet-visits: uint,
  owner-level: uint,
  join-date: uint
}
```

#### Pet Profiles
```clarity
{
  owner: principal,
  pet-name: (string-ascii 24),
  pet-type: (string-ascii 12),
  breed: (string-ascii 24),
  age-months: uint,
  weight-grams: uint,
  registration-date: uint,
  active: bool
}
```

#### Care Activities
```clarity
{
  pet-id: uint,
  caregiver: principal,
  activity-type: (string-ascii 16),
  duration-minutes: uint,
  notes: (string-ascii 64),
  activity-date: uint
}
```

#### Vet Checkups
```clarity
{
  owner: principal,
  checkup-type: (string-ascii 16),
  vet-notes: (string-ascii 128),
  next-checkup: uint,
  completed: bool
}
```

## Public Functions

### Pet Management

#### `register-pet`
```clarity
(register-pet 
  (pet-name (string-ascii 24))
  (pet-type (string-ascii 12))
  (breed (string-ascii 24))
  (age-months uint)
  (weight-grams uint))
```
Registers a new pet and returns the pet ID. Creates owner profile if first pet.

#### `update-pet-weight`
```clarity
(update-pet-weight (pet-id uint) (new-weight-grams uint))
```
Updates a pet's weight. Only callable by pet owner.

### Activity Tracking

#### `log-care-activity`
```clarity
(log-care-activity
  (pet-id uint)
  (activity-type (string-ascii 16))
  (duration-minutes uint)
  (notes (string-ascii 64)))
```
Logs a care activity and awards 1.5 PCT. Updates owner level based on duration.

**Activity Types:** "feeding", "walking", "grooming", "playing"

#### `schedule-vet-checkup`
```clarity
(schedule-vet-checkup
  (pet-id uint)
  (checkup-type (string-ascii 16))
  (vet-notes (string-ascii 128))
  (next-checkup-days uint))
```
Records a vet checkup and awards 3 PCT.

**Checkup Types:** "routine", "emergency", "vaccination"

### Profile & Rewards

#### `update-username`
```clarity
(update-username (new-username (string-ascii 32)))
```
Updates the owner's display username.

#### `claim-milestone`
```clarity
(claim-milestone (milestone (string-ascii 12)))
```
Claims a milestone achievement and awards 8 PCT. Can only be claimed once per milestone.

**Available Milestones:**
- "caregiver-20" - Requires 20+ care activities
- "vet-regular-10" - Requires 10+ vet visits
- "multi-pet-3" - Requires 3+ registered pets

### Admin Functions

#### `deactivate-pet`
```clarity
(deactivate-pet (pet-id uint))
```
Deactivates a pet profile. Owner-only function.

## Read-Only Functions

### Token Information
- `get-name()` - Returns token name
- `get-symbol()` - Returns token symbol
- `get-decimals()` - Returns token decimals
- `get-balance(principal)` - Returns token balance for an address

### Profile Queries
- `get-owner-profile(principal)` - Returns owner profile data
- `get-pet-profile(uint)` - Returns pet profile by ID
- `get-care-activity(uint)` - Returns care activity by ID
- `get-vet-checkup(uint, uint)` - Returns checkup by pet ID and date
- `get-milestone(principal, string-ascii)` - Returns milestone achievement data

## Error Codes

| Code | Error | Description |
|------|-------|-------------|
| u100 | err-owner-only | Function restricted to contract owner |
| u101 | err-not-found | Resource not found |
| u102 | err-already-exists | Resource already exists |
| u103 | err-unauthorized | Caller not authorized |
| u104 | err-invalid-input | Invalid input parameters |

## Usage Examples

### Register Your First Pet
```clarity
(contract-call? .petpal register-pet 
  "Buddy" 
  "dog" 
  "Golden Retriever" 
  u24 
  u25000)
```

### Log a Care Activity
```clarity
(contract-call? .petpal log-care-activity 
  u1 
  "walking" 
  u30 
  "Morning walk in the park")
```

### Schedule a Vet Checkup
```clarity
(contract-call? .petpal schedule-vet-checkup 
  u1 
  "routine" 
  "Annual wellness check - all healthy" 
  u365)
```

### Claim a Milestone
```clarity
(contract-call? .petpal claim-milestone "caregiver-20")
```

## Tokenomics

### Reward Distribution
- **Care Activities**: Consistent rewards for daily engagement
- **Vet Checkups**: Higher rewards for health maintenance
- **Milestones**: Bonus rewards for long-term commitment

### Owner Level Progression
Owner levels increase automatically based on care activity duration:
- Every 30 minutes of care = +1 level
- Levels serve as reputation indicators in the community

## Security Considerations

1. **Ownership Verification**: All pet modifications require owner authorization
2. **Active Status Checks**: Deactivated pets cannot receive new activities
3. **Input Validation**: All inputs validated for non-zero values and proper lengths
4. **Supply Cap**: Token minting limited to 40,000 PCT maximum
5. **Milestone Protection**: One-time milestone claims prevent double-claiming

## Development Roadmap

### Potential Enhancements
- Social features (pet playdates, community events)
- NFT integration for pet profiles
- Reward marketplace (exchange PCT for pet supplies)
- Veterinarian verification system
- Pet health records integration
- Cross-pet statistics and leaderboards

## License

This smart contract is provided as-is for the Stacks blockchain ecosystem.

## Contributing

Contributions welcome! Please ensure all changes maintain backward compatibility and include appropriate test coverage.

---

**Built with ❤️ for the pet community on Stacks**
