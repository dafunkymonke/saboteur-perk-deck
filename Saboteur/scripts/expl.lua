-- Saboteur: blast radius.
-- Card 3: +25% radius on thrown explosives. Card 7: +50% concussion radius.
-- Done here on the explosion manager so every grenade type is covered with one hook.
-- Hooked to: lib/managers/explosionmanager

Saboteur = Saboteur or {}

-- True if this explosion came from our hand-thrown grenade.
local function our_blast(params)
	if not Saboteur.has_upgrade("sab_radius") then
		return nil
	end
	local pu = Saboteur.player_unit()
	if not pu then
		return nil
	end
	if params.user ~= pu then
		return nil
	end
	local owner = params.owner
	if not alive(owner) or not owner:base() or type(owner:base().thrower_unit) ~= "function" then
		return nil
	end
	local ob = owner:base()
	if ob:thrower_unit() ~= pu then
		return nil
	end
	if ob:weapon_unit() ~= nil then
		return nil -- fired from a weapon (GL), not thrown
	end
	return ob:projectile_entry()
end

Hooks:PreHook(ExplosionManager, "detect_and_give_dmg", "sab_radius_dmg", function(self, params)
	local entry = our_blast(params)
	if not entry then
		return
	end
	if Saboteur.mode == "explosive" and not Saboteur.TACTICAL_IDS[entry] then
		params.range = params.range * Saboteur.RADIUS_MULT
		Saboteur.debug_log("Blast radius +25%")
	end
end)

Hooks:PreHook(ExplosionManager, "detect_and_stun", "sab_radius_stun", function(self, params)
	local entry = our_blast(params)
	if not entry then
		return
	end
	if Saboteur.mode == "explosive" and entry == "concussion" and Saboteur.has_upgrade("sab_radius") then
		params.range = params.range * Saboteur.RADIUS_MULT
		Saboteur.debug_log("Concussion radius +25%")
	end
end)
