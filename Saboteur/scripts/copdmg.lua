-- Saboteur: enemy damage hooks.
-- Card 1: kill timer reduction. Card 9: explosive hit armor, tactical hit
-- dodge/gun buff. Card 7: +50% tactical throwable damage.
-- (The card 7 anti-special DoT was removed in v1.1.0: Controlled Burn's
-- explosive side became armor + self-damage reduction instead.)
-- Hooked to: lib/units/enemies/cop/copdamage

Saboteur = Saboteur or {}

-- True if weapon_unit is our hand-thrown projectile (knife, etc.)
local function our_projectile(wu, pu)
	if not alive(wu) or not wu:base() or type(wu:base().thrower_unit) ~= "function" then
		return false
	end
	local b = wu:base()
	return b:thrower_unit() == pu and b:weapon_unit() == nil
end

-- True if weapon_unit is our hand-thrown explosive grenade
local function our_grenade(wu, pu)
	return our_projectile(wu, pu)
end

local function is_civilian(unit)
	if unit and unit:base() and unit:base()._tweak_table and unit:character_damage() then
		local fn = unit:character_damage().is_civilian
		if type(fn) == "function" then
			return fn(unit:base()._tweak_table)
		end
	end
	return false
end

-- ============ Card 1: kill timer reduction ============
Hooks:PostHook(CopDamage, "die", "sab_kill_reduction", function(self, attack_data)
	if not Saboteur.has_upgrade("sab_regen") then
		return
	end
	local pu = Saboteur.player_unit()
	if not pu or attack_data.attacker_unit ~= pu then
		return
	end
	local variant = attack_data.variant
	local wu = attack_data.weapon_unit
	local reduction = 0
	local explosive_kill = false
	if Saboteur.mode == "explosive" then
		if variant == "explosion" then
			if our_grenade(wu, pu) then
				reduction = Saboteur.REDUCE_EXPLOSIVE
				explosive_kill = true
			end
		end
		-- Fire/poison (burn pools, ignite DoT) intentionally pay
		-- nothing: only the throw's initial blast counts. A doubled
		-- 30s+ pool farming the timer was too much (his call,
		-- 2026-10-23).
	else
		-- tactical: throwable kill OR weapon kill while tactical equipped
		if our_projectile(wu, pu) then
			reduction = Saboteur.REDUCE_TACTICAL
		elseif wu ~= nil or variant == "melee" then
			-- gun kill, or melee kill (melee attack_data has variant "melee"
			-- and no weapon_unit -- the tag Sociopath keys off)
			reduction = Saboteur.REDUCE_TACTICAL
		end
	end
	if reduction <= 0 then
		return
	end
	local now = Application:time()
	-- Grace window (v1.0.18): the ICD used to eat every splash kill after
	-- the first, so a grenade's multi-kills were worth a single reduction.
	-- Now the first explosive kill opens a 1s window where further
	-- explosive kills from the same blast also count, and the ICD runs
	-- from the window's close. Tactical kills keep the plain ICD.
	if explosive_kill and now < Saboteur.grace_until then
		Saboteur.regen_timer = math.max(0, Saboteur.regen_timer - reduction)
		Saboteur.debug_log("Kill: -" .. reduction .. "s regen (grace)")
		return
	end
	if now - Saboteur.last_reduction < Saboteur.REDUCE_ICD then
		return
	end
	if explosive_kill then
		Saboteur.grace_until = now + Saboteur.GRACE_TIME
		Saboteur.last_reduction = Saboteur.grace_until
	else
		Saboteur.last_reduction = now
	end
	Saboteur.regen_timer = math.max(0, Saboteur.regen_timer - reduction)
	Saboteur.debug_log("Kill: -" .. reduction .. "s regen")
end)

-- ============ Card 9 explosive: armor per enemy hit ============
-- Registered for damage_explosion, and also damage_tase / damage_stun:
-- the electric and concussion grenades land through those channels
-- instead, and their hits pay armor the same way (his call, 2026-10-23
-- -- armor yes, timer income no; stuns still can't speed the regen).
-- damage_stun is guarded: the method is missing from the decompiled
-- tree, so register only if his build actually has it.
local function explosive_hit_armor(self, attack_data)
	if Saboteur.mode ~= "explosive" or not Saboteur.has_upgrade("sab_exp_armor") then
		return
	end
	local pu = Saboteur.player_unit()
	if not pu or attack_data.attacker_unit ~= pu then
		return
	end
	local wu = attack_data.weapon_unit
	if not our_grenade(wu, pu) then
		return
	end
	if is_civilian(self._unit) then
		return
	end
	-- per-grenade counter: the base dies with the grenade, so the 50% cap is per throw
	local gb = wu:base()
	gb._sab_hits = (gb._sab_hits or 0) + 1
	if gb._sab_hits <= Saboteur.ARMOR_CAP_HITS then
		Saboteur.grant_armor(Saboteur.ARMOR_PCT)
		Saboteur.debug_log(string.format("Explosive hit: +10%% armor (%d/5)", gb._sab_hits))
	end
end

Hooks:PreHook(CopDamage, "damage_explosion", "sab_exp_armor", explosive_hit_armor)
Hooks:PreHook(CopDamage, "damage_tase", "sab_tase_armor", explosive_hit_armor)
if CopDamage.damage_stun then
	Hooks:PreHook(CopDamage, "damage_stun", "sab_stun_armor", explosive_hit_armor)
end

-- ============ Card 3 explosive: +25% thrown explosive damage (v1.2.3) ============
-- Blast damage only: the damage_explosion channel. Fire pool ticks
-- (damage_fire) and ignite DoT deliberately do not scale.
Hooks:PreHook(CopDamage, "damage_explosion", "sab_exp_dmg", function(self, attack_data)
	if Saboteur.mode ~= "explosive" or not Saboteur.has_upgrade("sab_exp_dmg") then
		return
	end
	local pu = Saboteur.player_unit()
	if not pu or attack_data.attacker_unit ~= pu then
		return
	end
	if not our_grenade(attack_data.weapon_unit, pu) then
		return
	end
	if attack_data.damage then
		attack_data.damage = attack_data.damage * Saboteur.EXPLOSIVE_DMG_MULT
	end
end)

-- ============ Card 9 tactical: hits grant dodge + gun damage buff ============
-- ============ Card 7 tactical: +50% throwable damage ============
local function tactical_hit(self, attack_data)
	if Saboteur.mode ~= "tactical" then
		return
	end
	local pu = Saboteur.player_unit()
	if not pu or attack_data.attacker_unit ~= pu then
		return
	end
	local wu = attack_data.weapon_unit
	if our_projectile(wu, pu) then
		if Saboteur.has_upgrade("sab_tac_hit") then
			local now = Application:time()
			if Saboteur.dodge_bonus < Saboteur.BUFF_CAP then
				-- v1.2.7: base stacks are +10% per hit, dodge and gun
				-- damage in sync, cap +30% (3 hits), one shared 10s
				-- timer refreshed per hit. Gun damage is 1 + stacks in
				-- the weapon branch below.
				Saboteur.dodge_bonus = math.min(Saboteur.dodge_bonus + Saboteur.BUFF_STEP, Saboteur.BUFF_CAP)
				Saboteur.dodge_until = now + Saboteur.BUFF_DURATION
				Saboteur.gunbuff_until = now + Saboteur.BUFF_DURATION
				Saboteur.debug_log(string.format("Tactical hit: buff stacks %.0f%%", Saboteur.dodge_bonus * 100))
			else
				-- v1.2.7 overdodge: base is maxed, so the hit banks a
				-- +5% DODGE-ONLY stack for 5s. Rolling: every stack has
				-- its own expiry and bleeds off individually. Gun damage
				-- does NOT grow here (stays +30%). The hit still refreshes
				-- the base 10s timer, so feeding hits keeps the whole
				-- ramp alive. Total dodge hard-clamps at 75% inside
				-- skill_dodge_chance (pm.lua); stacks past the ceiling
				-- are duration banked against bleed-off.
				Saboteur.dodge_until = now + Saboteur.BUFF_DURATION
				Saboteur.gunbuff_until = now + Saboteur.BUFF_DURATION
				Saboteur.prune_overdodge()
				if #Saboteur.overdodge < Saboteur.OVER_MAX then
					table.insert(Saboteur.overdodge, now + Saboteur.OVER_DURATION)
				else
					local oldest = 1
					for i = 2, #Saboteur.overdodge do
						if Saboteur.overdodge[i] < Saboteur.overdodge[oldest] then
							oldest = i
						end
					end
					Saboteur.overdodge[oldest] = now + Saboteur.OVER_DURATION
				end
				Saboteur.debug_log(string.format("Overdodge: %d stacks", #Saboteur.overdodge))
			end
		end
		-- Card 3 rework (v1.2.0): a headshot with a thrown weapon grants
		-- +15% movement speed for 5s. Same body check CopDamage itself
		-- uses: the hit ray's body is the enemy's head body.
		if Saboteur.has_upgrade("sab_movespeed") then
			local cr = attack_data.col_ray
			if cr and cr.body and self._ids_head_body_name and cr.body:name() == self._ids_head_body_name then
				Saboteur.speed_until = Application:time() + Saboteur.SPEED_DURATION
				Saboteur.debug_log("Headshot: +15% speed, 4s")
			end
		end
		if Saboteur.has_upgrade("sab_tac_dmg") and attack_data.damage then
			attack_data.damage = attack_data.damage * Saboteur.KNIFE_DMG_MULT
		end
	elseif alive(wu) then
		-- regular weapon: gun damage scales with the shared stack counter
		if Saboteur.has_upgrade("sab_tac_gun") and attack_data.damage then
			if Application:time() < Saboteur.gunbuff_until then
				attack_data.damage = attack_data.damage * (1 + Saboteur.dodge_bonus)
			end
		end
	end
end

Hooks:PreHook(CopDamage, "damage_bullet", "sab_tac_bullet", tactical_hit)
Hooks:PreHook(CopDamage, "damage_melee", "sab_tac_melee", tactical_hit)
