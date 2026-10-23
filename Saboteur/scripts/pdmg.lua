-- Saboteur: self-damage reduction.
-- Card 7: 50% less damage from your own explosives and fire.
-- Hooked to: lib/units/beings/player/playerdamage

Saboteur = Saboteur or {}

-- ============ v1.1.0: spaced stat passives ============
-- Explosive: +10% max armor on card 9 and another +10% on card 3
-- (deck total +20%, kept under Armorer's ~35% on purpose; card 3
-- inherited card 7's share in v1.2.4 to standardize the spacing).
-- Tactical: +10% max health on card 3 and another +10% on card 7.
-- Mode-gated like everything else in this deck: the armor only exists
-- in explosive mode, the health only in tactical.
local orig_max_armor = PlayerDamage._max_armor
if orig_max_armor then
	function PlayerDamage:_max_armor()
		local a = orig_max_armor(self)
		if Saboteur.mode == "explosive" and managers.player then
			local mult = 1
			if Saboteur.has_upgrade("sab_armor5") then
				mult = mult + Saboteur.ARMOR_CARD
			end
			if Saboteur.has_upgrade("sab_armor7") then
				mult = mult + Saboteur.ARMOR_CARD
			end
			a = a * mult
		end
		return a
	end
end

local orig_max_health = PlayerDamage._max_health
if orig_max_health then
	function PlayerDamage:_max_health()
		local h = orig_max_health(self)
		if Saboteur.mode == "tactical" and managers.player then
			local mult = 1
			if Saboteur.has_upgrade("sab_health3") then
				mult = mult + Saboteur.HEALTH_CARD
			end
			if Saboteur.has_upgrade("sab_health7") then
				mult = mult + Saboteur.HEALTH_CARD
			end
			h = h * mult
		end
		return h
	end
end

local function reduce_self_damage(self, attack_data)
	if Saboteur.mode ~= "explosive" or not Saboteur.has_upgrade("sab_selfdmg") then
		return
	end
	local pu = Saboteur.player_unit()
	if not pu then
		return
	end
	local attacker = attack_data.attacker_unit
	if not alive(attacker) or attacker ~= pu then
		return
	end
	if attack_data.damage then
		attack_data.damage = attack_data.damage * Saboteur.SELFDGM_MULT
	end
end

Hooks:PreHook(PlayerDamage, "damage_explosion", "sab_self_exp", reduce_self_damage)
Hooks:PreHook(PlayerDamage, "damage_fire", "sab_self_fire", reduce_self_damage)
if PlayerDamage.damage_dot then
	Hooks:PreHook(PlayerDamage, "damage_dot", "sab_self_dot", reduce_self_damage)
end
