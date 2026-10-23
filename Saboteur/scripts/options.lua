-- Saboteur: mod options menu (debug panel toggle, off by default as of release 1.3.0).
-- Hooked to: lib/managers/menu/menumanager

log("[Saboteur] options.lua loaded")
Saboteur = Saboteur or {}
Saboteur.options = Saboteur.options or { debug_panel = false }

local save_path = SavePath .. "saboteur_options.json"

function Saboteur.save_options()
	local file = io.open(save_path, "w")
	if file then
		file:write(json.encode(Saboteur.options))
		file:close()
	end
end

function Saboteur.load_options()
	local file = io.open(save_path, "r")
	if file then
		local ok, data = pcall(json.decode, file:read("*all"))
		file:close()
		if ok and data and type(data) == "table" then
			for k, v in pairs(data) do
				Saboteur.options[k] = v
			end
		end
	end
	if Saboteur.options.debug_panel == nil then
		Saboteur.options.debug_panel = false
	end
	Saboteur.debug = Saboteur.options.debug_panel
end

Saboteur.load_options()

Hooks:Add("MenuManagerSetupCustomMenus", "sab_menu_setup", function(menu_manager, nodes)
	MenuHelper:NewMenu("saboteur_options")
end)

Hooks:Add("MenuManagerPopulateCustomMenus", "sab_menu_populate", function(menu_manager, nodes)
	MenuHelper:AddToggle({
		id = "saboteur_debug_toggle",
		title = "saboteur_debug_title",
		desc = "saboteur_debug_desc",
		callback = "saboteur_debug_callback",
		value = Saboteur.options.debug_panel,
		menu_id = "saboteur_options"
	})
end)

Hooks:Add("MenuManagerBuildCustomMenus", "sab_menu_build", function(menu_manager, nodes)
	nodes["saboteur_options"] = MenuHelper:BuildMenu("saboteur_options", { area_bg = "half" })
	-- Current SuperBLT renamed the Mod Options parent node; "blt_options" is
	-- the old-BLT id. VanillaHUD+ resolves it via BLT.Mods.Constants, mirror that.
	local parent_id = "blt_options"
	pcall(function()
		if BLT and BLT.Mods and BLT.Mods.Constants and BLT.Mods.Constants.LuaModOptionsMenuID then
			parent_id = BLT.Mods.Constants:LuaModOptionsMenuID()
		end
	end)
	if nodes[parent_id] then
		MenuHelper:AddMenuItem(nodes[parent_id], "saboteur_options", "saboteur_menu_title", "saboteur_menu_desc")
		log("[Saboteur] options menu registered under " .. tostring(parent_id))
	else
		log("[Saboteur] options menu FAILED: parent node " .. tostring(parent_id) .. " missing")
	end
end)

MenuCallbackHandler.saboteur_debug_callback = function(self, item)
	Saboteur.options.debug_panel = (item:value() == "on")
	Saboteur.debug = Saboteur.options.debug_panel
	Saboteur.save_options()
end
