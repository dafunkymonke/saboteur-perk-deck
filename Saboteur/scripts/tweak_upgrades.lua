-- Saboteur upgrade definitions (the "has this card" flags the Lua checks)
-- Actual balance numbers live as constants in scripts/pm.lua
-- Hooked to: lib/tweak_data/upgradestweakdata
--
-- v1.0.1 fix: v1.0 hooked _init_pd2_values, which runs BEFORE
-- self.definitions = {} is created inside init(), so indexing
-- self.definitions crashed on startup (nil value).
-- _player_definitions runs after both self.definitions and
-- self.values.player exist, so register everything there instead.
-- values.player entries are required too: PlayerManager:aquire_upgrade
-- looks up tweak_data.upgrades.values[category][upgrade][value]
-- when a perk card is acquired, and would crash without them.

local old_init = UpgradesTweakData._player_definitions

function UpgradesTweakData:_player_definitions()
	old_init(self)

	local defs = {
		"sab_regen",       -- card 1: throwable regen timer
		"sab_radius",      -- card 3: +25% thrown explosive radius
		"sab_exp_dmg",     -- card 3: +25% thrown explosive damage
		"sab_movespeed",   -- card 3: tactical movespeed
		"sab_exp_armor",   -- card 9: explosive hit armor
		"sab_armor5",      -- card 9: +10% max armor (explosive)
		"sab_tac_hit",     -- card 9: tactical hit dodge
		"sab_tac_gun",     -- card 9: tactical hit gun damage buff
		"sab_armor7",      -- card 3: +10% max armor (explosive; moved from card 7 in v1.2.4)
		"sab_selfdmg",     -- card 7: 50% self-damage reduction
		"sab_flash",       -- card 7: flashbangs clear 50% faster (explosive)
		"sab_tac_dmg",     -- card 7: +50% tactical throwable damage
		"sab_windup",      -- card 7: 100% faster wind-up (v1.2.7)
		"sab_dodge5",      -- card 9: +10% dodge (tactical)
		"sab_health3",     -- card 3: +10% max health (tactical)
		"sab_dodge7",      -- card 7: +10% dodge (tactical)
		"sab_health7",     -- card 7: +10% max health (tactical)
		"sab_restock"      -- card 5: restock heal
	}

	self.values.player = self.values.player or {}

	for _, id in ipairs(defs) do
		self.values.player[id] = { 1 }
		self.definitions[id] = {
			name_id = "menu_upgrade_" .. id .. "_name",
			category = "feature",
			upgrade = {
				value = 1,
				upgrade = id,
				category = "player"
			}
		}
	end
end
