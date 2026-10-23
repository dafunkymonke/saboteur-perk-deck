-- Saboteur perk deck: core state, helpers, card 1 (regen), card 3 (movespeed),
-- card 5 (restock funnel), debug panel.
-- Hooked to: lib/managers/playermanager

Saboteur = Saboteur or {}

-- ============ Balance constants (tweak here) ============
Saboteur.REGEN_TIME = 20        -- card 1: seconds per throwable
Saboteur.REDUCE_EXPLOSIVE = 5  -- card 1: explosive throwable kill reduction
Saboteur.REDUCE_TACTICAL = 10  -- card 1: tactical/weapon kill reduction
Saboteur.REDUCE_ICD = 2        -- card 1: internal cooldown on reductions
Saboteur.GRACE_TIME = 1        -- card 1: splash grace window after an explosive kill (s)
Saboteur.RADIUS_MULT = 1.25    -- card 3: thrown explosive blast radius
Saboteur.EXPLOSIVE_DMG_MULT = 1.25 -- card 3: thrown explosive damage (v1.2.3)
Saboteur.MOVESPEED_MULT = 0.15 -- card 3: tactical headshot movespeed bonus
Saboteur.SPEED_DURATION = 4    -- card 3: headshot speed buff duration (s)
Saboteur.ARMOR_PCT = 0.10      -- card 9: armor per explosive hit
Saboteur.ARMOR_CAP_HITS = 5    -- card 9: max counted hits per throw (50%)
Saboteur.TOTAL_DODGE_CAP = 0.75 -- v1.2.7: hard cap on TOTAL dodge, all sources
Saboteur.DODGE_CARD = 0.10     -- v1.1.0: passive dodge on cards 3 and 7 (tactical)
Saboteur.ARMOR_CARD = 0.10     -- v1.1.0: max armor on cards 9 and 7 (explosive)
Saboteur.HEALTH_CARD = 0.10    -- v1.1.0: max health on cards 3 and 7 (tactical)
Saboteur.BUFF_STEP = 0.10      -- card 9: dodge + gun damage per tactical hit (v1.2.7: was 0.05)
Saboteur.BUFF_CAP = 0.30       -- card 9: both buffs stack to +30%, in sync
Saboteur.BUFF_DURATION = 10    -- card 9: buff duration (s)
Saboteur.OVER_STEP = 0.05      -- v1.2.7: overdodge per hit once base stacks are maxed
Saboteur.OVER_MAX = 5          -- v1.2.7: max stored overdodge stacks
Saboteur.OVER_DURATION = 5     -- v1.2.7: seconds per overdodge stack, rolling
Saboteur.WINDUP_MULT = 0.25    -- card 7: wind-up timings at 0.25x = throws 4x vanilla speed. He chose to run v1.2.7 (this value) over v1.2.8's 0.5 on 2026-10-23, so source matches the build he actually uses.
Saboteur.SELFDGM_MULT = 0.5    -- card 7: self-damage taken
Saboteur.FLASH_RATE = 1.5      -- card 7: flashbang fade rate bonus (explosive)
Saboteur.KNIFE_DMG_MULT = 1.5  -- card 7: tactical throwable damage
Saboteur.RESTOCK_ARMOR = 0.10  -- card 5: armor on restock (explosive)
Saboteur.RESTOCK_HEALTH = 0.15 -- card 5: health on restock (tactical)

-- Throwable ids that put the deck in tactical mode. Everything else is explosive.
-- (Smoke/ECM are perk-deck locked and can't be equipped with Saboteur anyway.)
Saboteur.TACTICAL_IDS = {
	laser_watch = true,  -- Laser Chronometer (Espionage pack)
	wpn_prj_four = true,   -- shuriken
	wpn_prj_ace = true,    -- throwing cards
	wpn_prj_hur = true,    -- throwing axe
	wpn_prj_jav = true,    -- javelin
	wpn_prj_target = true, -- throwing knife
}

-- ============ State (nil-guarded so load order can't clobber it) ============
if Saboteur.mode == nil then Saboteur.mode = "explosive" end
if Saboteur.equipped_id == nil then Saboteur.equipped_id = "frag" end
if Saboteur.regen_timer == nil then Saboteur.regen_timer = Saboteur.REGEN_TIME end
if Saboteur.last_reduction == nil then Saboteur.last_reduction = -10 end
if Saboteur.grace_until == nil then Saboteur.grace_until = 0 end
if Saboteur.dodge_bonus == nil then Saboteur.dodge_bonus = 0 end
if Saboteur.dodge_until == nil then Saboteur.dodge_until = 0 end
if Saboteur.overdodge == nil then Saboteur.overdodge = {} end
if Saboteur.gunbuff_until == nil then Saboteur.gunbuff_until = 0 end
if Saboteur.speed_until == nil then Saboteur.speed_until = 0 end
if Saboteur.suppress_until == nil then Saboteur.suppress_until = 0 end
if Saboteur.debug == nil then Saboteur.debug = false end
if Saboteur._debug_lines == nil then Saboteur._debug_lines = {} end
Saboteur._windup_backup = Saboteur._windup_backup or nil

-- ============ Helpers ============
function Saboteur.has_upgrade(id)
	return managers.player:has_category_upgrade("player", id)
end

function Saboteur.player_unit()
	local u = managers.player:player_unit()
	return alive(u) and u or nil
end

-- v1.0.3 fix: PlayerManager:get_grenade_amount() REQUIRES a peer_id.
-- Calling it with no argument indexes synced_grenades[nil] and crashes
-- inside playermanager.lua (hit movement_speed_multiplier in v1.0.2).
-- Always go through this helper, which resolves the local peer safely.
function Saboteur.current_grenades()
	local session = managers.network and managers.network:session()
	local peer = session and session:local_peer()
	if not peer then
		return 0
	end
	return managers.player:get_grenade_amount(peer:id()) or 0
end

-- True if this projectile base is OUR hand-thrown throwable.
-- weapon_unit() is nil only for hand-thrown (GL rounds carry the launcher).
function Saboteur.is_ours(base)
	if not base or type(base.thrower_unit) ~= "function" then
		return false
	end
	local pu = Saboteur.player_unit()
	if not pu then
		return false
	end
	return base:thrower_unit() == pu and base:weapon_unit() == nil
end

function Saboteur.grant_armor(pct)
	local pu = Saboteur.player_unit()
	if not pu then
		return
	end
	local pd = pu:character_damage()
	pd:restore_armor(pd:_max_armor() * pct)
end

function Saboteur.grant_health(pct)
	local pu = Saboteur.player_unit()
	if not pu then
		return
	end
	local pd = pu:character_damage()
	-- restore_health takes a RATIO of max health (it multiplies internally);
	-- passing an absolute amount made it heal ~max^2 = a full heal. Bug found
	-- in testing 2026-10-21: restock healed to full instead of 15%.
	pd:restore_health(pct)
end

function Saboteur.debug_log(msg)
	log("[Saboteur] " .. msg)
	if Saboteur.debug then
		table.insert(Saboteur._debug_lines, 1, msg)
		while #Saboteur._debug_lines > 6 do
			table.remove(Saboteur._debug_lines)
		end
	end
end

-- ============ Heist setup: read equipped throwable, set mode ============
function Saboteur.set_mode()
	local gid = managers.blackmarket:equipped_grenade()
	Saboteur.equipped_id = gid or "frag"
	Saboteur.mode = Saboteur.TACTICAL_IDS[Saboteur.equipped_id] and "tactical" or "explosive"
	Saboteur.regen_timer = Saboteur.REGEN_TIME
	Saboteur.grace_until = 0
	Saboteur.dodge_bonus = 0
	Saboteur.dodge_until = 0
	Saboteur.gunbuff_until = 0
	Saboteur.speed_until = 0
	Saboteur.apply_flash_resistance()
	Saboteur.apply_windup_tweak()
	if Saboteur.vplus_sync_mode then
		Saboteur.vplus_sync_mode()
	end
	log("[Saboteur] Mode: " .. Saboteur.mode .. " (" .. Saboteur.equipped_id .. ")")
end

-- Card 7 explosive: flashbang resistance. The environment controller
-- fades the white-out at a rate proportional to its internal
-- multiplier, which PlayerBase sets from the flashbang_multiplier
-- upgrade as 1 + (1 - value) * 2 (Resilience aced: value 0.25 -> 2.5x
-- fade). Recompute that base here and multiply it, so the deck's 50%
-- faster clear is INDEPENDENT of Resilience and stacks with it
-- (both together: 3.75x fade). Absolute assignment, so re-running on
-- respawn can never compound.
function Saboteur.apply_flash_resistance()
	local ec = managers.environment_controller
	if not ec or type(ec._flashbang_multiplier) ~= "number" then
		return
	end
	pcall(function()
		local v = managers.player:upgrade_value("player", "flashbang_multiplier", 1)
		local base = 1 + (1 - v) * 2
		if Saboteur.mode == "explosive" and Saboteur.has_upgrade("sab_flash") then
			ec._flashbang_multiplier = base * Saboteur.FLASH_RATE
		else
			ec._flashbang_multiplier = base
		end
	end)
end

-- Card 7 tactical: cut throw wind-up timings at heist start, restore on change.
function Saboteur.apply_windup_tweak()
	if Saboteur._windup_backup then
		for id, vals in pairs(Saboteur._windup_backup) do
			local tw = tweak_data.blackmarket.projectiles[id]
			if tw then
				for k, v in pairs(vals) do
					tw[k] = v
				end
			end
		end
		Saboteur._windup_backup = nil
	end
	if Saboteur.mode == "tactical" and Saboteur.has_upgrade("sab_windup") then
		Saboteur._windup_backup = {}
		for id, _ in pairs(Saboteur.TACTICAL_IDS) do
			local tw = tweak_data.blackmarket.projectiles[id]
			if tw then
				Saboteur._windup_backup[id] = {}
				for _, k in ipairs({ "throw_allowed_expire_t", "expire_t", "repeat_expire_t" }) do
					if tw[k] then
						Saboteur._windup_backup[id][k] = tw[k]
						tw[k] = tw[k] * Saboteur.WINDUP_MULT
					end
				end
			end
		end
	end
end

Hooks:PostHook(PlayerManager, "spawned_player", "sab_spawned", function(self, id, unit)
	Saboteur.set_mode()
end)

-- ============ Card 1: regen timer ============
Hooks:PostHook(PlayerManager, "update", "sab_regen", function(self, t, dt)
	if not Saboteur.has_upgrade("sab_regen") then
		return
	end
	if not Saboteur.player_unit() then
		return
	end
	if self:got_max_grenades() then
		Saboteur.regen_timer = Saboteur.REGEN_TIME
	else
		Saboteur.regen_timer = Saboteur.regen_timer - dt
		if Saboteur.regen_timer <= 0 then
			Saboteur.regen_timer = Saboteur.REGEN_TIME
			-- v1.0.4 fix: sync MUST be true, same as Fully Loaded's gain.
			-- NetworkPeer:verify_grenade counts every throw (+1) against
			-- max_amount; only a synced gain registers the offset (-amount)
			-- on the peer. Unsynced regen gains left the counter climbing
			-- until the game marked the player a cheater (many_grenades).
			self:add_grenade_amount(1, true)
			Saboteur.debug_log("Regen: +1 throwable")
		end
	end
	-- Card 9 expiry belongs here, not inside skill_dodge_chance: that only
	-- runs when the game rolls dodge, so the bonus (and the panel reading)
	-- lingered after the buff timer ended. Caught in testing 2026-10-21.
	if Saboteur.dodge_bonus > 0 and t > Saboteur.dodge_until then
		Saboteur.dodge_bonus = 0
	end
	if #Saboteur.overdodge > 0 then
		Saboteur.prune_overdodge()
	end
	Saboteur.update_debug_panel()
end)

-- ============ Card 5: restock funnel ============
-- Every throwable gain flows through add_grenade_amount: our regen, Fully Loaded,
-- throwable cases. Ground knife pickups are suppressed (see pickup.lua).
Hooks:PostHook(PlayerManager, "add_grenade_amount", "sab_restock", function(self, amount, sync)
	if amount <= 0 then
		return
	end
	if Application:time() < Saboteur.suppress_until then
		return
	end
	if not Saboteur.has_upgrade("sab_restock") then
		return
	end
	if not Saboteur.player_unit() then
		return
	end
	if Saboteur.mode == "explosive" then
		Saboteur.grant_armor(Saboteur.RESTOCK_ARMOR)
		Saboteur.debug_log("Restock: +10% armor")
	else
		Saboteur.grant_health(Saboteur.RESTOCK_HEALTH)
		Saboteur.debug_log("Restock: +15% health")
	end
end)

-- ============ Card 3 tactical: headshot speed (v1.2.0 rework) ============
-- Landing a headshot with a thrown weapon grants +15% movement speed
-- for 4 seconds (set in copdmg.lua's tactical_hit). Replaces the old
-- speed-by-missing scale: the bonus is earned, not granted for being
-- empty. Chained override because PostHook can't change the return.
local orig_msm = PlayerManager.movement_speed_multiplier
function PlayerManager:movement_speed_multiplier(speed_state, bonus_multiplier, upgrade_level, health_ratio)
	local m = orig_msm(self, speed_state, bonus_multiplier, upgrade_level, health_ratio)
	if Saboteur.mode == "tactical" and Saboteur.has_upgrade("sab_movespeed") and Saboteur.player_unit() then
		if Application:time() < Saboteur.speed_until then
			m = m * (1 + Saboteur.MOVESPEED_MULT)
		end
	end
	return m
end

-- ============ Dodge (v1.2.7 overdodge rework) ============
-- Passive dodge is spaced across the deck Rogue-style: +10% on card 9
-- tactical and +10% on card 7 tactical (v1.2.0: card 9 inherited card
-- 3's share), 20% passive total. Card 9 hits stack +10% dodge and gun
-- damage in sync to +30% (3 hits). Once base stacks are maxed, further
-- hits bank overdodge: +5% dodge-only stacks, 5s each, rolling off one
-- at a time. Total dodge chance (every source) hard-clamps at 75%.
function Saboteur.passive_dodge()
	local p = 0
	if Saboteur.has_upgrade("sab_dodge5") then
		p = p + Saboteur.DODGE_CARD
	end
	if Saboteur.has_upgrade("sab_dodge7") then
		p = p + Saboteur.DODGE_CARD
	end
	return p
end

function Saboteur.prune_overdodge()
	local now = Application:time()
	local kept = {}
	for _, expiry in ipairs(Saboteur.overdodge) do
		if expiry > now then
			table.insert(kept, expiry)
		end
	end
	Saboteur.overdodge = kept
end

function Saboteur.overdodge_value()
	Saboteur.prune_overdodge()
	return #Saboteur.overdodge * Saboteur.OVER_STEP
end

function Saboteur.deck_dodge()
	if Saboteur.mode ~= "tactical" then
		return 0
	end
	local stacks = 0
	if Saboteur.dodge_bonus > 0 and Application:time() < Saboteur.dodge_until then
		stacks = Saboteur.dodge_bonus
	end
	return Saboteur.passive_dodge() + stacks + Saboteur.overdodge_value()
end

-- v1.2.10: the deck's EFFECTIVE dodge contribution after the 75 total
-- clamp, for displays. VanillaHUD's TotalDodgeChance sums raw components
-- itself (armor +5, risk-table dodge, plus whatever we feed it) and knows
-- nothing about the clamp, so feeding it raw deck_dodge() showed 80 while
-- the real roll was 75. Feeding the post-clamp contribution makes its
-- total read the same 75 the roll uses. Display-only; the roll itself is
-- clamped in skill_dodge_chance below.
function Saboteur.effective_dodge_add()
	if Saboteur.mode ~= "tactical" then
		return 0
	end
	local dd = Saboteur.deck_dodge()
	if dd <= 0 then
		return 0
	end
	local vanilla = 0
	pcall(function()
		vanilla = orig_sdc(managers.player, false, false, false)
	end)
	local armor_dodge = 0
	pcall(function()
		armor_dodge = managers.player:body_armor_value("dodge") or 0
	end)
	local headroom = Saboteur.TOTAL_DODGE_CAP - armor_dodge - vanilla
	return math.max(0, math.min(dd, headroom))
end

local orig_sdc = PlayerManager.skill_dodge_chance
function PlayerManager:skill_dodge_chance(running, crouching, on_zipline, override_armor, detection_risk)
	local c = orig_sdc(self, running, crouching, on_zipline, override_armor, detection_risk)
	if Saboteur.mode == "tactical" then
		if Saboteur.dodge_bonus > 0 and Application:time() > Saboteur.dodge_until then
			Saboteur.dodge_bonus = 0
		end
		c = c + Saboteur.deck_dodge()
		-- v1.2.7: 75% is the maximum total dodge at any time, his ruling.
		-- v1.2.9 correction: PlayerDamage's dodge roll adds ARMOR dodge
		-- (body_armor_value("dodge"), suit +5) AFTER this function returns,
		-- so a flat 75 clamp here produced 80 in a suit. Clamp against the
		-- headroom the armor addend leaves instead, so armor + skill-side
		-- total is 75 in any armor. Skill-tree dodge (Sneaky Bastard's
		-- detection-risk table, tier/passive/run/crouch) all lives INSIDE
		-- this function, so it is clamped too -- verified in source.
		local armor_dodge = 0
		pcall(function()
			armor_dodge = self:body_armor_value("dodge") or 0
		end)
		c = math.min(c, Saboteur.TOTAL_DODGE_CAP - armor_dodge)
	end
	return c
end

-- ============ Debug panel ============
function Saboteur.init_debug_panel()
	if Saboteur._dbg_panel then
		return
	end
	-- v1.0.10: draw into the main HUD script panel (the same surface
	-- VanillaHUD+ itself uses). The old standalone fullscreen workspace
	-- rendered invisibly on current SuperBLT builds.
	local panel = nil
	pcall(function()
		local script = managers.hud and managers.hud:script(PlayerBase.PLAYER_INFO_HUD_PD2)
		local parent = script and script.panel or nil
		if parent then
			panel = parent:panel({ name = "saboteur_debug", layer = 900 })
		end
	end)
	if not panel then
		local ok, ws = pcall(function()
			return managers.gui_data:create_fullscreen_workspace()
		end)
		if ok and ws then
			panel = ws:panel():panel({ name = "saboteur_debug", layer = 1000 })
		end
	end
	if not panel then
		return
	end
	Saboteur._dbg_text = panel:text({
		name = "saboteur_debug_text",
		text = "",
		font = "fonts/font_medium_mf",
		font_size = 16,
		color = Color.white,
		align = "left",
		vertical = "top",
		x = 10,
		y = 100,
		w = 700,
		h = 500,
		layer = 1001
	})
	Saboteur._dbg_panel = panel
end

Saboteur._dbg_tick = 0
function Saboteur.update_debug_panel()
	if not Saboteur.debug or not Saboteur.player_unit() then
		if Saboteur._dbg_panel then
			Saboteur._dbg_panel:set_visible(false)
		end
		return
	end
	Saboteur.init_debug_panel()
	if not Saboteur._dbg_text then
		return
	end
	Saboteur._dbg_panel:set_visible(true)
	Saboteur._dbg_tick = Saboteur._dbg_tick + 1
	if Saboteur._dbg_tick % 15 ~= 0 then
		return
	end
	local now = Application:time()
	local cur, max = 0, 0
	pcall(function()
		cur = Saboteur.current_grenades()
		max = managers.player:get_max_grenades(Saboteur.equipped_id) or 0
	end)
	local lines = {
		"SABOTEUR [" .. Saboteur.mode .. "]",
		string.format("Throwables: %d/%d   Regen: %.1fs", cur, max, math.max(0, Saboteur.regen_timer)),
		string.format("Dodge: +%.1f%%   Gun: %.1fs   Speed: %.1fs", Saboteur.deck_dodge() * 100, math.max(0, Saboteur.gunbuff_until - now), math.max(0, Saboteur.speed_until - now)),
		string.format("Overdodge: %d stacks (+%.0f%%)", #Saboteur.overdodge, Saboteur.overdodge_value() * 100)
	}
	for _, l in ipairs(Saboteur._debug_lines) do
		table.insert(lines, "> " .. l)
	end
	Saboteur._dbg_text:set_text(table.concat(lines, "\n"))
end
