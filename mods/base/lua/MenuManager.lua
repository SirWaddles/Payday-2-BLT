
CloneClass( MenuManager )
CloneClass( MenuCallbackHandler )
CloneClass( ModMenuCreator )
CloneClass( MenuModInfoGui )

Hooks:RegisterHook( "MenuManagerInitialize" )
function MenuManager.init( self, ... )
	self.orig.init( self, ... )
	Hooks:Call( "MenuManagerInitialize", self )
end

Hooks:RegisterHook( "MenuManagerOnOpenMenu" )
function MenuManager.open_menu( self, menu_name, position )
	self.orig.open_menu( self, menu_name, position )
	Hooks:Call( "MenuManagerOnOpenMenu", self, menu_name, position )
end

function MenuManager.open_node( self, node_name, parameter_list )
	self.orig.open_node( self, node_name, parameter_list )
end

-- Add menus
Hooks:Add( "MenuManagerInitialize", "MenuManagerInitialize_Base_AddLuaModsMenu", function( menu_manager )

	local success, err = pcall(function()

		-- Setup lua mods menu
		menu_manager:_base_process_menu(
			"menu_main",
			"mods_options",
			"options",
			"MenuManager_Base_SetupModsMenu",
			"MenuManager_Base_PopulateModsMenu",
			"MenuManager_Base_BuildModsMenu"
		)

		-- Setup mod keybinds menu
		menu_manager:_base_process_menu(
			"menu_main",
			"video",
			"options",
			"MenuManager_Base_SetupKeybindsMenu",
			"MenuManager_Base_PopulateKeybindsMenu",
			"MenuManager_Base_BuildKeybindsMenu"
		)

		-- Allow custom menus on the main menu (and lobby) and the pause menu 
		menu_manager:_base_process_menu( "menu_main" )
		menu_manager:_base_process_menu( "menu_pause" )

	end)
	if not success then
		log("[Error] " .. err)
	end

end )

function MenuManager._base_process_menu( menu_manager, menu_name, parent_menu_name, parent_menu_button, setup_hook, populate_hook, build_hook )

	local menu = menu_manager._registered_menus[ menu_name ]
	if menu then

		local nodes = menu.logic._data._nodes
		local hook_id_setup = setup_hook or "MenuManagerSetupCustomMenus"
		local hook_id_populate = populate_hook or "MenuManagerPopulateCustomMenus"
		local hook_id_build = build_hook or "MenuManagerBuildCustomMenus"

		MenuHelper:SetupMenu( nodes, parent_menu_name or "video" )
		MenuHelper:SetupMenuButton( nodes, parent_menu_button or "options" )

		Hooks:RegisterHook( hook_id_setup )
		Hooks:RegisterHook( hook_id_populate )
		Hooks:RegisterHook( hook_id_build )

		Hooks:Call( hook_id_setup, menu_manager, nodes )
		Hooks:Call( hook_id_populate, menu_manager, nodes )
		Hooks:Call( hook_id_build, menu_manager, nodes )

	end

end

-- Add lua mods menu
ModMenuCreator._mod_menu_modifies = {
	["base_lua_mods_menu"] = "create_lua_mods_menu"
}
function ModMenuCreator.modify_node(self, original_node, data)

	local node_name = original_node._parameters.name
	if self._mod_menu_modifies then
		if self._mod_menu_modifies[node_name] then

			local func = self._mod_menu_modifies[node_name]
			local node = original_node
			self[func](self, node, data)

			return node

		end
	end

	return self.orig.modify_node(self, original_node, data)
end

function ModMenuCreator.create_lua_mods_menu(self, node)

	node:clean_items()
	
	local C = LuaModManager.Constants
	local sorted_mods = {}
	local mods = {}
	local conflicted_content = {}
	local modded_content = {}

	local add_hooks_list = function( content_table, hooks_table, title )
		local _hooks = {}
		local hooks_str = ""
		if type(hooks_table) == "table" then
			for x, y in pairs( hooks_table ) do
				local hook = y[ C.mod_hook_id_key ]
				if not _hooks[ hook ] then
					hooks_str = hooks_str .. "    " .. tostring(hook) .. "\n"
					_hooks[ hook ] = true
				end
			end
		end
		if not string.is_nil_or_empty(hooks_str) then
			table.insert( content_table, title .. ":\n" .. hooks_str )
		end
	end

	local add_persist_scripts_list = function( content_table, persist_table, title )
		local str = ""
		if type( persist_table ) == "table" then
			local pattern = "    [{1}] = {2}\n"
			for k, v in pairs( persist_table ) do
				str = str .. pattern
				str = str:gsub("{1}", v[C.mod_persists_global_key])
				str = str:gsub("{2}", v[C.mod_script_path_key])
			end
		end
		if not string.is_nil_or_empty(str) then
			table.insert( content_table, title .. ":\n" .. str )
		end
	end

	for k, v in pairs( LuaModManager.Mods ) do

		local mod_disabled = not LuaModManager:IsModEnabled( v.path )
		local path = v.path
		local info = v.definition
		local mod_name = info[ C.mod_name_key ] or "No Mod Name"
		local mod_desc = info[ C.mod_desc_key ] or "No Mod Description"
		local mod_version = info[ C.mod_version_key ] or "1.0"
		local mod_author = info[ C.mod_author_key ] or "No Author"
		local mod_contact = info[ C.mod_contact_key ] or "No Contact Details"
		local mod_hooks = info[ C.mod_hooks_key ] or "No Hooks"
		local mod_prehooks = info[ C.mod_prehooks_key ] or "No Pre-Hooks"
		local mod_persist_scripts = info[ C.mod_persists_key ] or "No Persistent Scripts"

		table.insert(sorted_mods, mod_name)
		mods[mod_name] = {
			content = {},
			conflicted = {},
			title = nil
		}
		mods[mod_name].title = mod_name .. ( mod_disabled and " [Disabled]" or "" )
		local content = mods[mod_name].content
		table.insert( content, mod_desc )
		table.insert( content, "Version: " .. mod_version )
		table.insert( content, "Author: " .. mod_author )
		table.insert( content, "Contact: " .. mod_contact )
		table.insert( content, "Path: " .. path )
		add_hooks_list( content, mod_prehooks, "Pre-Hooks" )
		add_hooks_list( content, mod_hooks, "Hooks" )
		add_persist_scripts_list( content, mod_persist_scripts, "Persistent Scripts" )

		MenuCallbackHandler.base_toggle_lua_mod = function(this, item)
			if item and item._parameters.mod_path then
				LuaModManager:ToggleModState( item._parameters.mod_path )
			end
		end

		self:create_item(node, {
			text_id = mod_name,
			name = mod_name,
			mod_path = path,
			localize = false,
			enabled = true,
			callback = "base_toggle_lua_mod",
			hightlight_color = mod_disabled and tweak_data.screen_colors.important_1,
			row_item_color = mod_disabled and tweak_data.screen_colors.important_2,
		})

	end

	self:add_back_button(node)

	node:parameters().mods = mods
	node:parameters().sorted_mods = sorted_mods
	node:parameters().conflicted_content = conflicted_content
	node:parameters().modded_content = modded_content


end

function MenuModInfoGui.set_mod_info(self, item)

	self.mod_info_panel:clear()

	if alive(self._scroll_bar_panel) then
		self.safe_rect_panel:remove(self._scroll_bar_panel)
	end

	self._scroll_bar_panel = nil
	if self._scroll_up_box then
		self._scroll_up_box:close()
		self._scroll_up_box = nil
	end

	if self._scroll_down_box then
		self._scroll_down_box:close()
		self._scroll_down_box = nil
	end

	if self.safe_rect_panel:child("info_title") then
		self.safe_rect_panel:remove(self.safe_rect_panel:child("info_title"))
	end

	local params = item:parameters() or {}
	if params.back or params.pd2_corner then
		return
	end

	local mods = self.node:parameters().mods
	local modded_content = self.node:parameters().modded_content
	local mod_name = params.name
	local mod_data = mods and mods[mod_name]
	local conflicted_panel = self.mod_info_panel:panel({name = "conflicted", y = 10})
	local modded_panel = self.mod_info_panel:panel({name = "modded"})
	local title = self.safe_rect_panel:text({
		name = "info_title",
		text = managers.localization:to_upper_text("menu_mods_info_title", {mod = mod_name}),
		font = self.medium_font,
		font_size = self.medium_font_size,
		layer = 1
	})

	self.make_fine_text(title)

	if mod_data then

		local text = conflicted_panel:text({
			text = managers.localization:to_upper_text("menu_mods_conflict_title"),
			font = self.medium_font,
			font_size = self.medium_font_size,
			layer = 1,
			x = 10,
			y = 0,
			w = conflicted_panel:w() - 20
		})

		local _, _, _, h = text:text_rect()
		text:set_h(h)
		local cy = h
		local conflict_text_title = text
		conflict_text_title:hide()

		local text = modded_panel:text({
			text = mod_data.title or managers.localization:to_upper_text("menu_mods_modded_title"),
			font = self.medium_font,
			font_size = self.medium_font_size,
			layer = 1,
			x = 10,
			y = 0,
			w = conflicted_panel:w() - 20
		})

		local _, _, _, h = text:text_rect()
		text:set_h(h)
		local my = h
		local mod_text_title = text
		mod_text_title:hide()
		local conflicted_mods = {}

		for _, path in ipairs(mod_data.content) do

			if mod_data.conflicted[Idstring(path):key()] then

				for _, conflict_mod in ipairs(mod_data.conflicted[Idstring(path):key()]) do
					if conflict_mod ~= mod_name then
						conflicted_mods[conflict_mod] = conflicted_mods[conflict_mod] or {}
						table.insert(conflicted_mods[conflict_mod], path)
					end
				end

				conflict_text_title:show()

			else

				text = modded_panel:text({
					text = path,
					font = self.small_font,
					font_size = self.small_font_size,
					layer = 1,
					x = 20,
					y = my,
					w = modded_panel:w() - 30,
					wrap = true
				})
				_, _, _, h = text:text_rect()
				text:set_h(h)
				text:set_color(tweak_data.screen_colors.text)
				my = my + math.ceil(h)
				mod_text_title:show()

			end

		end

		local sorted_conflicts = {}

		for mod, conflicts in pairs(conflicted_mods) do
			table.insert(sorted_conflicts, mod)
		end

		table.sort(sorted_conflicts)

		for _, mod in ipairs(sorted_conflicts) do

			text = conflicted_panel:text({
				text = utf8.to_upper(mod) .. ":",
				font = self.small_font,
				font_size = self.small_font_size,
				layer = 1,
				x = 20,
				y = cy,
				w = conflicted_panel:w() - 30,
				wrap = true
			})
			_, _, _, h = text:text_rect()
			text:set_h(h)
			cy = cy + math.ceil(h)

			for _, path in ipairs(conflicted_mods[mod]) do

				text = conflicted_panel:text({
					text = path,
					font = self.small_font,
					font_size = self.small_font_size,
					layer = 1,
					x = 25,
					y = cy,
					w = conflicted_panel:w() - 35,
					wrap = true
				})
				_, _, _, h = text:text_rect()
				text:set_h(h)
				text:set_color(tweak_data.screen_colors.important_1)
				cy = cy + math.ceil(h)

			end

			cy = cy + 10

		end

		conflicted_panel:set_h(cy)
		modded_panel:set_y(conflict_text_title:visible() and conflicted_panel:bottom() or 10)
		modded_panel:set_h(my)
		self.mod_info_panel:set_y(0)
		self.mod_info_panel:set_h(modded_panel:bottom() + 10)

		if self.mod_info_panel:h() > self._mod_main_panel:h() then

			self._scroll_up_box = BoxGuiObject:new(self._mod_main_panel, {
				sides = {
					0,
					0,
					2,
					0
				}
			})

			self._scroll_down_box = BoxGuiObject:new(self._mod_main_panel, {
				sides = {
					0,
					0,
					0,
					2
				}
			})

			self._scroll_up_box:hide()
			self._scroll_down_box:show()
			self._scroll_bar_panel = self.safe_rect_panel:panel({
				name = "scroll_bar_panel",
				w = 20,
				h = self._mod_main_panel:h()
			})

			self._scroll_bar_panel:set_world_left(self._mod_main_panel:world_right())
			self._scroll_bar_panel:set_world_top(self._mod_main_panel:world_top())

			local texture, rect = tweak_data.hud_icons:get_icon_data("scrollbar_arrow")
			local scroll_up_indicator_arrow = self._scroll_bar_panel:bitmap({
				name = "scroll_up_indicator_arrow",
				texture = texture,
				texture_rect = rect,
				layer = 2,
				color = Color.white,
				blend_mode = "add"
			})

			scroll_up_indicator_arrow:set_center_x(self._scroll_bar_panel:w() / 2)

			local texture, rect = tweak_data.hud_icons:get_icon_data("scrollbar_arrow")
			local scroll_down_indicator_arrow = self._scroll_bar_panel:bitmap({
				name = "scroll_down_indicator_arrow",
				texture = texture,
				texture_rect = rect,
				layer = 2,
				color = Color.white,
				rotation = 180,
				blend_mode = "add"
			})

			scroll_down_indicator_arrow:set_bottom(self._scroll_bar_panel:h())
			scroll_down_indicator_arrow:set_center_x(self._scroll_bar_panel:w() / 2)

			local bar_h = scroll_down_indicator_arrow:top() - scroll_up_indicator_arrow:bottom()
			self._scroll_bar_panel:rect({
				color = Color.black,
				alpha = 0.05,
				y = scroll_up_indicator_arrow:bottom(),
				h = bar_h,
				w = 4
			}):set_center_x(self._scroll_bar_panel:w() / 2)
			bar_h = scroll_down_indicator_arrow:bottom() - scroll_up_indicator_arrow:top()

			local scroll_bar = self._scroll_bar_panel:panel({
				name = "scroll_bar",
				layer = 2,
				h = bar_h
			})

			local scroll_bar_box_panel = scroll_bar:panel({
				name = "scroll_bar_box_panel",
				w = 4,
				halign = "scale",
				valign = "scale"
			})

			self._scroll_bar_box_class = BoxGuiObject:new(scroll_bar_box_panel, {
				sides = {
					2,
					2,
					0,
					0
				}
			})

			self._scroll_bar_box_class:set_aligns("scale", "scale")
			self._scroll_bar_box_class:set_blend_mode("add")
			scroll_bar_box_panel:set_w(8)
			scroll_bar_box_panel:set_center_x(scroll_bar:w() / 2)
			scroll_bar:set_top(scroll_up_indicator_arrow:top())
			scroll_bar:set_center_x(scroll_up_indicator_arrow:center_x())
			self:set_scroll_indicators(0)

		end

	end

end