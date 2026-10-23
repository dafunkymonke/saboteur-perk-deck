# Saboteur — Perk Deck for PAYDAY 2

**By DaFunkyMonke** · Twitter/X: [@dafunkymonke](https://x.com/dafunkymonke)

A dual-state throwable deck. What you equip decides how it plays.

Explosives: an armor-gating demolisher.
Tactical throwables: fast, dodgy, and hard to pin down.

Saboteur is a dual-state perk deck built entirely around your throwables. There is no separate activation and no injector: whichever throwable you bring decides which deck you are playing for that whole heist.

---

## The Two Modes

Your equipped throwable is read once at heist start and locks the mode in.

**Explosive mode** — frags, HE grenades, dynamite, matryoshkas, molotovs, incendiaries, flashbangs, concussion and electric grenades. An armor-gating demolisher: your grenades print more grenades, hits with them rebuild your armor, and dense fights turn into a grenade every few seconds.

**Tactical mode** — throwing knives, shurikens, throwing cards, throwing axes, javelins. A dodge build with a stacking damage/dodge ramp and the **Overdodge** mechanic (below). Fast throws, fast feet, and a survivability ceiling no other dodge deck can touch — while you keep feeding it.

## Card 1: The Regen Engine

Every Saboteur build runs on **Steady Supply**: your throwables regenerate, one every **20 seconds**, forever. Kills shorten the wait:

- **Explosive blast kills: −5s each.** The first blast kill opens a 1-second grace window in which every additional kill from your explosions also pays out, so one good frag in a group can refund the entire timer. The 2s internal cooldown runs from the window closing.
- **Tactical throwable kills, and any weapon or melee kill while a tactical throwable is equipped: −10s**, once every 2 seconds.
- Fire pools and damage-over-time **never** pay out. Only the throw itself counts.

Regen gains are network-synced the same way Fully Loaded gains are, so the game's own grenade audit stays happy and you never get flagged for the extra throwables.

## The Cards

**1. Steady Supply (200)**
Your throwables regenerate, one every 20 seconds.

Explosive blast kills shorten the wait by 5 seconds. Kills with tactical throwables, or any weapon kill while one is equipped, shorten it by 10 seconds. Reductions can only occur once every 2 seconds, but every kill from the same blast counts.

Fire pools and damage over time do not count.

**2. Helmet Popping (300)**
Increases your headshot damage by 25%.

**3. Split Ordnance (400)**
EXPLOSIVE: Your thrown explosives deal 25% more damage and have a 25% larger blast radius. This also applies to flashbangs and burn pools. Grenade launchers do not count. Your max armor is increased by 10%.

TACTICAL: Headshots with thrown weapons grant 15% movement speed for 4 seconds. You gain 10% more max health.

On the explosive side this crosses a real breakpoint: a stock frag (160 damage) becomes **200**, enough to one-shot a Death Wish / Death Sentence medic (180 HP), which vanilla frags cannot do.

**4. Blending In (600)**
You gain +1 increased concealment. When wearing armor, your movement speed is 15% less affected. You gain 45% more experience when you complete days and jobs.

**5. Full Circle (1000)**
Whenever you gain a throwable from regeneration, Fully Loaded or a throwable case:

EXPLOSIVE: You regain 10% of your max armor.
TACTICAL: You regain 15% of your max health.

Throwables picked up off the ground do not count.

Restock triggers are strict: regeneration, Fully Loaded aced procs, and throwable cases count. Picking knives up off the ground does **not**.

**6. Walk-in Closet (1600)**
Unlocks an armor bag equipment for you to use. The armor bag can be used to change your armor during a heist. Increases your ammo pickup to 135% of the normal rate.

**7. Controlled Burn (2400)**
EXPLOSIVE: You take 50% less damage from your own explosions, fire and damage over time. Flashbangs clear up 50% faster.

TACTICAL: Knives, shurikens, cards, axes and javelins deal 50% more damage and are thrown 100% faster. You gain 10% dodge chance and 10% more max health.

Details: the flashbang bonus multiplies your fade rate by 1.5 and stacks with the Resilience skill (both together clear flashes at 3.75x the base rate). The tactical wind-up bonus cuts all throw timing values to a quarter of vanilla, so tactical throwables come out at **4x vanilla throw speed**.

**8. Fast and Furious (3200)**
You deal 5% more damage. Does not apply to melee damage, throwables, grenade launchers, crossbows, and the HRL-7 Rocket Launcher. Increases your doctor bag interaction speed by 20%.

**9. Paydirt (4000)**
EXPLOSIVE: Hitting an enemy restores 10% of your max armor, up to 50% per throw. Your max armor is increased by 10%.

TACTICAL: You gain 10% dodge chance. Hitting an enemy grants 10% dodge chance and 10% more weapon damage, stacking up to 30% for 10 seconds. Every hit refreshes the duration. Hits at full stacks instead grant 5% dodge chance for 5 seconds, stacking separately. Your total dodge chance cannot exceed 75%.

Deck Completion Bonus: You gain a 10% increased chance of getting a higher quality item from a card drop.

Explosive Paydirt counts hits on the explosion, tase and stun channels alike, so electric and concussion grenades restore armor on hit even though they earn no regen time. The per-throw counter caps at 5 hits (50% of your armor per throw, maximum).

## Overdodge, In Detail

Tactical Paydirt works in three bands:

1. **Passive: +20% dodge** from the deck (+10% on Controlled Burn, +10% on Paydirt). With Sneaky Bastard, your standing floor is ~30%.
2. **Base stacks:** every tactical hit adds **+10% dodge and +10% gun damage**, up to **+30%** (3 hits). One shared 10-second timer, refreshed by every hit, drives both buffs in sync.
3. **Overdodge:** once base stacks are maxed, further hits stop adding to the base and instead bank **+5% dodge-only stacks, each lasting 5 seconds**, ticking down individually — they bleed off one at a time instead of dropping off a cliff. Gun damage does **not** grow in this band; it stays at +30%.

Your **total dodge chance can never exceed 75%**, from any source — deck, suit, Sneaky Bastard, sprint and crouch bonuses, all of it. In a suit with Sneaky Bastard you stand at ~60% with base stacks maxed, and holding the full 75% means landing a hit at least every 5 seconds. It is a burst state for aggressive plays, not a stance.

## Attribution Rules

Only **your own hand-thrown projectiles** trigger anything in this deck. Excluded by design:

- Grenade launcher rounds
- Trip mines and C4 (including their kills)
- Cars and other environmental kills
- Teammates' throwables

If it didn't leave your hand, it doesn't count.

## VanillaHUD Plus Integration (Optional)

If you run VanillaHUD Plus, Saboteur feeds its buff system instead of drawing its own numbers:

- **SUPPLY** — the regen countdown
- **DAMAGE** — the gun-damage buff, routed into the total damage readout at its live stack value
- **Dodge** — routed into the total dodge readout, post-clamp, so the number you see is the real capped total
- **SPEED** — the headshot movement-speed buff

Without VanillaHUD Plus the deck plays identically; you just lose the buff readouts. If the integration ever breaks after a VanillaHUD update, the deck posts one chat notice and keeps working.

## Debug Panel

Mod Options → Saboteur Options has a debug panel toggle showing live mode, throwable count, regen timer, dodge contribution, overdodge stack count and buff timers. It is a testing tool and is **off by default**.

## Multiplayer Notes

- Players without Saboteur installed see a **blank deck slot** where yours should be. This is a vanilla limitation for all custom decks and is cosmetic only; your deck works normally in their game.
- Tested solo and as host. As a client your deck logic runs on your own machine like any other deck.

## Requirements & Install

- PAYDAY 2 with **SuperBLT** (64-bit). No BeardLib required.
- Download the latest release zip and extract the `Saboteur` folder into `PAYDAY 2/mods`.
- Buy it with perk points like any other deck.

## Design Notes

Every stat line sits at or below the vanilla deck that specializes in it: less armor than Armorer, a passive dodge floor under Rogue, less health than Muscle. The one novel power is the regen engine — and grenade launchers already give any deck explosive spam with retrievable ammo while keeping their whole perk deck, so Saboteur trades its entire deck slot for never running out of throwables. It is tuned to be strong and fun on Death Wish, not to move the Death Sentence meta. Like Sociopath, it is a monster while you are fighting in a held position and taxed the moment an objective makes you stop — that is the deck's honest weakness, and it is deliberate.

## Known Quirk

Spamming throws at maximum speed can occasionally desync the weapon animation and leave your gun invisible until your next clean throw. Cosmetic, self-healing, and a side effect of the 4x throw speed.

## Bug Reports

Open an issue with your BLT log (`PAYDAY 2/mods/logs`) and a short description of what you were doing. Reports with logs get fixed first.

---

*Current release: **1.3.0***
