-- Saboteur: VanillaHUD+ (HUDList) buff-bar integration.
-- Hooked to: lib/managers/playermanager
--
-- OPTIONAL dependency. If VanillaHUD+ is not installed, everything here
-- stays inert and the debug panel is the display. If VanillaHUD+ IS
-- installed but its buff internals no longer match what we expect (e.g.
-- one of its updates changed HUDList.BuffItemBase.MAP or the gameinfo
-- buff events), we post ONE chat notice per heist that the mod needs to
-- be updated, disable the integration, and fall back to the debug panel
-- instead of crashing or spamming errors.

Saboteur = Saboteur or {}
Saboteur._vplus_state = Saboteur._vplus_state or "unknown" -- unknown | ok | absent | broken
Saboteur._vplus_noticed = Saboteur._vplus_noticed or false

local BROKEN_MSG = "VanillaHUD+ integration failed (a VanillaHUD+ update likely changed its buff system). Saboteur needs an update to display buffs there again. Gameplay is unaffected, the debug panel still works."

local function chat_notice(msg)
	if Saboteur._vplus_noticed then
		return
	end
	Saboteur._vplus_noticed = true
	log("[Saboteur] " .. msg)
	if managers.chat then
		pcall(function()
			managers.chat:_receive_message(ChatManager.GAME, "Saboteur", msg, Color(1, 0.45, 0.1))
		end)
	end
end

local function mark_broken()
	Saboteur._vplus_state = "broken"
	chat_notice(BROKEN_MSG)
end

local function skill_icon(key, fallback_key)
	local skills = tweak_data.skilltree.skills
	local e = skills[key] or (fallback_key and skills[fallback_key])
	return e and e.icon_xy or nil
end

-- Probe VanillaHUD+ and, if it looks compatible, add our buff items to
-- its buff table. Returns true when the integration is live.
function Saboteur.vplus_register()
	if Saboteur._vplus_state == "ok" then
		return true
	end
	if Saboteur._vplus_state == "absent" then
		return false
	end
	if Saboteur._vplus_state == "broken" then
		chat_notice(BROKEN_MSG) -- once per heist; set_mode resets the flag
		return false
	end

	local has_hudlist = type(HUDList) == "table" and type(HUDList.BuffItemBase) == "table"
	local has_gameinfo = managers.gameinfo and type(managers.gameinfo.event) == "function"
	if not has_hudlist and not has_gameinfo then
		Saboteur._vplus_state = "absent" -- not installed: not an error, stay silent
		return false
	end
	if not (has_hudlist and has_gameinfo
		and type(HUDList.BuffItemBase.MAP) == "table"
		and type(HUDList.BuffItemBase.VALUE_FUNC) == "table"
		and type(HUDList.BuffItemBase.VALUE_FUNC.IN_PERCENT) == "function"
		and type(HUDListManager) == "table"
		and type(HUDListManager.BUFFS) == "table"
		and HUDList.BuffItemBase.MAP.damage_increase ~= nil
		and HUDList.BuffItemBase.MAP.total_dodge_chance ~= nil
		and HUDList.BuffItemBase.MAP.overkill ~= nil) then
		mark_broken() -- installed, but not the shape we were built against
		return false
	end

	local ok, err = pcall(function()
		local MAP = HUDList.BuffItemBase.MAP
		local VF = HUDList.BuffItemBase.VALUE_FUNC
		local ref = MAP.armor_break_invulnerable or MAP.berserker
		local color = ref and ref.color or nil
		local function entry(icon_xy, class, title, show_value)
			local t = {
				class = class,
				priority = 4,
				ignore = false,
			}
			if icon_xy then
				t.skills_new = icon_xy
			else
				t.perks = { 6, 1 } -- known-good atlas coords as a last resort
			end
			if color then
				t.color = color
			end
			if title then
				t.title = title
				t.localized = true
			end
			if show_value then
				t.show_value = show_value
			end
			return t
		end
		MAP.saboteur_regen = entry(skill_icon("ammo_reservoir"), "TimedBuffItem", "saboteur_buff_regen")
		MAP.saboteur_speed = entry(skill_icon("duck_and_weave", "running_from_death"), "BuffItemBase", "saboteur_buff_speed", VF.IN_PERCENT)
		-- v1.0.17: no custom items for dodge / gun damage. Separate Saboteur
		-- stats forced the player to mentally add them to the totals every
		-- other deck/skill feeds. Instead, route our buff events into the
		-- vanilla items: gun damage lights the Overkill item AND feeds the
		-- total damage-increase readout; dodge feeds the total dodge readout
		-- directly (no icon of its own). VanillaHUD sums the members, same
		-- as it does for real Overkill / ECM dodge procs.
		HUDListManager.BUFFS.saboteur_gunbuff = { "overkill", "damage_increase" }
		HUDListManager.BUFFS.saboteur_dodge = { "total_dodge_chance" }
		-- No mode items on the bar by request (2026-10-21): the mode is
		-- explained on the perk deck itself and stays on the debug panel.
	end)
	if not ok then
		log("[Saboteur] VanillaHUD+ registration error: " .. tostring(err))
		mark_broken()
		return false
	end
	Saboteur._vplus_state = "ok"
	log("[Saboteur] VanillaHUD+ buff integration active.")
	return true
end

-- Fire one buff event into VanillaHUD+. Any failure means its update
-- broke the event path: go broken, notify once, never try again.
function Saboteur.vplus_event(kind, event, id, data)
	if Saboteur._vplus_state ~= "ok" then
		return
	end
	local ok, err = pcall(function()
		managers.gameinfo:event(kind, event, id, data)
	end)
	if not ok then
		log("[Saboteur] VanillaHUD+ event error: " .. tostring(err))
		mark_broken()
	end
end

-- Called from Saboteur.set_mode() every heist spawn: probe VanillaHUD+
-- and re-arm the once-per-heist failure notice.
function Saboteur.vplus_sync_mode()
	Saboteur._vplus_noticed = false
	Saboteur.vplus_register()
end

-- Per-frame sync of the live values: regen countdown, dodge stack +
-- gun buff timers, movespeed value. Edge-triggered so we only talk to
-- VanillaHUD+ when something actually changed.
Hooks:PostHook(PlayerManager, "update", "sab_vplus_sync", function(self, t, dt)
	if Saboteur._vplus_state ~= "ok" then
		return
	end
	if not Saboteur.player_unit() then
		return
	end
	local now = Application:time()
	local ev = Saboteur.vplus_event

	-- Card 9 tactical: dodge + gun damage share one 10s clock, but display
	-- through the vanilla readouts (see vplus_register). Dodge is a plain
	-- buff feeding the total-dodge composite; gun damage is timed and
	-- rides the Overkill item + total damage composite.
	-- v1.1.0: the dodge feed carries the deck's TOTAL dodge (passive from
	-- cards 7/9 plus card 9 hit stacks and v1.2.7 overdodge), so in tactical
	-- mode it stays active once card 3 is owned. The gun buff keeps its
	-- own separate 10s clock.
	-- v1.2.10: feed the post-clamp contribution so VHud's summed total
	-- reads the real 75 cap instead of raw deck math (was showing 80).
	local dd = Saboteur.effective_dodge_add and Saboteur.effective_dodge_add() or (Saboteur.deck_dodge and Saboteur.deck_dodge() or 0)
	if dd > 0 then
		if not Saboteur._vp_dodge_on then
			Saboteur._vp_dodge_on = true
			ev("buff", "activate", "saboteur_dodge")
		end
		if Saboteur._vp_dodge_val ~= dd then
			Saboteur._vp_dodge_val = dd
			ev("buff", "set_value", "saboteur_dodge", { value = dd })
		end
	else
		if Saboteur._vp_dodge_on then
			Saboteur._vp_dodge_on = nil
			Saboteur._vp_dodge_val = nil
			ev("buff", "deactivate", "saboteur_dodge")
		end
	end
	if now < Saboteur.gunbuff_until then
		if Saboteur._vp_buff_until ~= Saboteur.gunbuff_until then
			Saboteur._vp_buff_until = Saboteur.gunbuff_until
			ev("timed_buff", "activate", "saboteur_gunbuff", { duration = Saboteur.gunbuff_until - now })
		end
		-- v1.2.1: the gun buff value is the live stack (1.05 .. 1.30),
		-- re-sent whenever another hit raises it.
		local gv = 1 + Saboteur.dodge_bonus
		if Saboteur._vp_gun_val ~= gv then
			Saboteur._vp_gun_val = gv
			ev("buff", "set_value", "saboteur_gunbuff", { value = gv })
		end
	elseif Saboteur._vp_buff_until ~= nil then
		Saboteur._vp_buff_until = nil
		Saboteur._vp_gun_val = nil
		ev("buff", "deactivate", "saboteur_gunbuff")
	end

	-- Card 1: regen countdown, refreshed when the whole second changes.
	if self:got_max_grenades() then
		if Saboteur._vp_regen_sec ~= nil then
			Saboteur._vp_regen_sec = nil
			ev("buff", "deactivate", "saboteur_regen")
		end
	else
		local sec = math.ceil(Saboteur.regen_timer)
		if Saboteur._vp_regen_sec ~= sec then
			Saboteur._vp_regen_sec = sec
			ev("timed_buff", "activate", "saboteur_regen", { duration = Saboteur.regen_timer })
		end
	end

	-- Card 3 tactical (v1.2.0): headshot speed buff, shown while active.
	local speed = 0
	if Saboteur.mode == "tactical" and now < Saboteur.speed_until then
		speed = Saboteur.MOVESPEED_MULT
	end
	if speed > 0 then
		if Saboteur._vp_speed ~= speed then
			if Saboteur._vp_speed == nil then
				ev("buff", "activate", "saboteur_speed")
			end
			Saboteur._vp_speed = speed
			ev("buff", "set_value", "saboteur_speed", { value = speed })
		end
	elseif Saboteur._vp_speed ~= nil then
		Saboteur._vp_speed = nil
		ev("buff", "deactivate", "saboteur_speed")
	end
end)
