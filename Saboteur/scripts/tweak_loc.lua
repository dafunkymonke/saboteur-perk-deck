-- Saboteur localization
-- Hooked to: lib/managers/localizationmanager

Hooks:Add("LocalizationManagerPostInit", "saboteur_loc", function(loc)
	loc:load_localization_file("mods/Saboteur/l10n/english.json")
end)
