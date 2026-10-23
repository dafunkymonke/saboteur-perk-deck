-- Saboteur: card 5 ground-pickup suppression.
-- Knives/shurikens picked up off the ground flow through add_grenade_amount,
-- so we suppress the restock heal briefly when an AmmoClip with a projectile
-- id is picked up. Timestamp-based so it can't get stuck.
-- Hooked to: lib/units/pickups/ammoclip

Saboteur = Saboteur or {}

Hooks:PreHook(AmmoClip, "_pickup", "sab_pickup_pre", function(self, unit)
	if self._projectile_id then
		Saboteur.suppress_until = Application:time() + 1
	end
end)
