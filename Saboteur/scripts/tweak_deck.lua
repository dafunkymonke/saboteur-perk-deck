-- Saboteur perk deck definition
-- Hooked to: lib/tweak_data/skilltreetweakdata

local old_init = SkillTreeTweakData.init

function SkillTreeTweakData:init(tweak_data)
	old_init(self, tweak_data)

	local saboteur = {
		{
			upgrades = { "sab_regen" },
			cost = 200,
			icon_xy = { 0, 5 },
			name_id = "menu_deck_saboteur_1",
			desc_id = "menu_deck_saboteur_1_desc"
		},
		{
			-- stock deck2 card, identical to vanilla's shared table
			upgrades = { "weapon_passive_headshot_damage_multiplier" },
			cost = 300,
			icon_xy = { 1, 0 },
			name_id = "menu_deckall_2",
			desc_id = "menu_deck_saboteur_2_desc"
		},
		{
			upgrades = { "sab_radius", "sab_movespeed", "sab_health3", "sab_exp_dmg", "sab_armor7" },
			cost = 400,
			icon_xy = { 0, 3 },
			name_id = "menu_deck_saboteur_3",
			desc_id = "menu_deck_saboteur_3_desc"
		},
		{
			-- stock deck4 card, identical to vanilla's shared table
			upgrades = { "passive_player_xp_multiplier", "player_passive_suspicion_bonus", "player_passive_armor_movement_penalty_multiplier" },
			cost = 600,
			icon_xy = { 3, 0 },
			name_id = "menu_deckall_4",
			desc_id = "menu_deck_saboteur_4_desc"
		},
		{
			-- v1.2.0: Full Circle moved here from slot 9 (Paydirt took 9).
			-- v1.2.3: the Deck Completion Bonus did NOT move with it -- in
			-- vanilla it is a rider on the slot-9 card of every deck, so
			-- it now sits on Paydirt where slot 9 is.
			upgrades = { "sab_restock" },
			cost = 1000,
			icon_xy = { 6, 4 },
			name_id = "menu_deck_saboteur_9",
			desc_id = "menu_deck_saboteur_9_desc"
		},
		{
			-- stock deck6 card, identical to vanilla's shared table
			upgrades = { "armor_kit", "player_pick_up_ammo_multiplier" },
			cost = 1600,
			icon_xy = { 5, 0 },
			name_id = "menu_deckall_6",
			desc_id = "menu_deck_saboteur_6_desc"
		},
		{
			upgrades = { "sab_selfdmg", "sab_flash", "sab_tac_dmg", "sab_windup", "sab_dodge7", "sab_health7" },
			cost = 2400,
			icon_xy = { 1, 4 },
			name_id = "menu_deck_saboteur_7",
			desc_id = "menu_deck_saboteur_7_desc"
		},
		{
			-- stock deck8 card, identical to vanilla's shared table
			upgrades = { "weapon_passive_damage_multiplier", "passive_doctor_bag_interaction_speed_multiplier" },
			cost = 3200,
			icon_xy = { 7, 0 },
			name_id = "menu_deckall_8",
			desc_id = "menu_deck_saboteur_8_desc"
		},
		{
			-- v1.2.0: Paydirt moved here from slot 5 (Full Circle took 5)
			upgrades = { "sab_exp_armor", "sab_tac_hit", "sab_tac_gun", "sab_armor5", "sab_dodge5", "player_passive_loot_drop_multiplier" },
			cost = 4000,
			icon_xy = { 2, 5 },
			name_id = "menu_deck_saboteur_5",
			desc_id = "menu_deck_saboteur_5_desc"
		}
	}

	-- v1.0.2 fix: vanilla specializations are a FLAT array of the 9
	-- tier tables, with name_id/desc_id as keys on that same table.
	-- v1.0/v1.0.1 nested the tiers under a "cards" key, so
	-- SkillTreeManager:_setup_specialization read data[1] as nil and
	-- crashed on data[1].cost (skilltreemanager.lua:106).
	local spec = {}
	for i, card in ipairs(saboteur) do
		spec[i] = card
	end
	spec.name_id = "menu_deck_saboteur_title"
	spec.desc_id = "menu_deck_saboteur_desc"

	table.insert(self.specializations, spec)
end
