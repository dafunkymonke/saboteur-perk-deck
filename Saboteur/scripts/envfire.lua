-- Saboteur: Card 3 burn pool radius, applied at the fire itself.
-- Hooked to: lib/units/environment/environmentfire
--
-- This used to re-call EnvironmentFire.spawn from MolotovGrenade /
-- IncendiaryGrenade overrides with a custom range_multiplier argument.
-- In his game build that argument arrived as nil and molotovs crashed
-- on detonation (environmentfire.lua: arithmetic on range_multiplier,
-- 2026-10-23). Scaling data.range here instead: on_spawn computes
-- range = data.range * range_multiplier with the game's own vanilla
-- argument pair, and data is a fresh table per pool, so this is safe.
-- The sound_event gate matches the two handheld fire throwables
-- (molotov_impact / gl_explode); the thrower must be the player.

Saboteur = Saboteur or {}

Hooks:PreHook(EnvironmentFire, "on_spawn", "sab_envfire_radius", function(self, data, normal, user_unit, added_time, range_multiplier)
	if Saboteur.mode ~= "explosive" or not Saboteur.has_upgrade("sab_radius") then
		return
	end
	if not data or (data.sound_event ~= "molotov_impact" and data.sound_event ~= "gl_explode") then
		return
	end
	local pu = Saboteur.player_unit()
	if not pu or user_unit ~= pu then
		return
	end
	data.range = data.range * (Saboteur.RADIUS_MULT or 1.25)
	Saboteur.debug_log("Burn pool +25% radius")
end)
