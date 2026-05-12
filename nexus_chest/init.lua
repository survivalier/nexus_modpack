-- nexus_chest/init.lua
-- Conversion du module de coffre en "nexus_chest:chest"
-- Version sans traduction et sans dépendance à un module 'nexus' inexistant

nexus_chest = {}

-- Formspect du coffre
function nexus_chest.get_chest_formspec(pos)
    local spos = pos.x .. "," .. pos.y .. "," .. pos.z
    local formspec =
        "size[8,9]" ..
        "list[nodemeta:" .. spos .. ";main;0,0.3;8,4;]" ..
        "list[current_player;main;0,4.85;8,1;]" ..
        "list[current_player;main;0,6.08;8,3;8]" ..
        "listring[nodemeta:" .. spos .. ";main]" ..
        "listring[current_player;main]" ..
        (default.get_hotbar_bg and default.get_hotbar_bg(0,4.85) or "")
    return formspec
end

-- Vérifie si le couvercle est obstrué
function nexus_chest.chest_lid_obstructed(pos)
    local above = {x = pos.x, y = pos.y + 1, z = pos.z}
    local node_above = minetest.get_node(above)
    local def = minetest.registered_nodes[node_above.name]
    -- allow ladders, signs, wallmounted things and torches to not obstruct
    if def and
            (def.drawtype == "airlike" or
            def.drawtype == "signlike" or
            def.drawtype == "torchlike" or
            (def.drawtype == "nodebox" and def.paramtype2 == "wallmounted")) then
        return false
    end
    return true
end

-- Ferme le couvercle (après fermeture de l'UI)
function nexus_chest.chest_lid_close(pn)
    local chest_open_info = nexus_chest.open_chests[pn]
    if not chest_open_info then return end
    local pos = chest_open_info.pos
    local sound = chest_open_info.sound
    local swap = chest_open_info.swap

    nexus_chest.open_chests[pn] = nil
    for k, v in pairs(nexus_chest.open_chests) do
        if vector.equals(v.pos, pos) then
            -- another player is also looking at the chest
            return true
        end
    end

    local node = minetest.get_node(pos)
    minetest.after(0.2, function()
        local current_node = minetest.get_node(pos)
        if current_node.name ~= swap .. "_open" then
            -- the chest has already been replaced, don't try to replace what's there.
            return
        end
        minetest.swap_node(pos, {name = swap, param2 = node.param2})
        if sound then
            minetest.sound_play(sound, {gain = 0.3, pos = pos, max_hear_distance = 10}, true)
        end
    end)
end

nexus_chest.open_chests = {}

-- Gestion de la fermeture si le joueur ferme la formspec
minetest.register_on_player_receive_fields(function(player, formname, fields)
    local pn = player:get_player_name()

    if formname ~= "nexus_chest:chest" then
        if nexus_chest.open_chests[pn] then
            nexus_chest.chest_lid_close(pn)
        end
        return
    end

    if not (fields.quit and nexus_chest.open_chests[pn]) then
        return
    end

    nexus_chest.chest_lid_close(pn)
    return true
end)

-- Fermer si le joueur se déconnecte
minetest.register_on_leaveplayer(function(player)
    local pn = player:get_player_name()
    if nexus_chest.open_chests[pn] then
        nexus_chest.chest_lid_close(pn)
    end
end)

-- Enregistre un coffre (standard ou protégé)
function nexus_chest.register_chest(prefixed_name, d)
    local name = prefixed_name:sub(1,1) == ':' and prefixed_name:sub(2,-1) or prefixed_name
    local def = table.copy(d)
    def.drawtype = "mesh"
    def.visual = "mesh"
    def.paramtype = "light"
    def.paramtype2 = "facedir"
    def.legacy_facedir_simple = true
    def.is_ground_content = false

    -- Protected variant
    if def.protected then
        def.on_construct = function(pos)
            local meta = minetest.get_meta(pos)
            meta:set_string("infotext", "Coffre en Nexurium")
            meta:set_string("owner", "")
            local inv = meta:get_inventory()
            inv:set_size("main", 8*4)
        end
        def.after_place_node = function(pos, placer)
            local meta = minetest.get_meta(pos)
            meta:set_string("owner", placer:get_player_name() or "")
            meta:set_string("infotext", "Coffre en Nexurium (" .. meta:get_string("owner") .. ")")
        end
        def.can_dig = function(pos,player)
            local meta = minetest.get_meta(pos)
            local inv = meta:get_inventory()
            return inv:is_empty("main") and
                    (default.can_interact_with_node and default.can_interact_with_node(player, pos) or true)
        end
        def.allow_metadata_inventory_move = function(pos, from_list, from_index,
                to_list, to_index, count, player)
            if default.can_interact_with_node and not default.can_interact_with_node(player, pos) then
                return 0
            end
            return count
        end
        def.allow_metadata_inventory_put = function(pos, listname, index, stack, player)
            if default.can_interact_with_node and not default.can_interact_with_node(player, pos) then
                return 0
            end
            return stack:get_count()
        end
        def.allow_metadata_inventory_take = function(pos, listname, index, stack, player)
            if default.can_interact_with_node and not default.can_interact_with_node(player, pos) then
                return 0
            end
            return stack:get_count()
        end
        def.on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
            if default.can_interact_with_node and not default.can_interact_with_node(clicker, pos) then
                return itemstack
            end

            local cn = clicker:get_player_name()

            if nexus_chest.open_chests[cn] then
                nexus_chest.chest_lid_close(cn)
            end

            minetest.sound_play(def.sound_open, {gain = 0.3, pos = pos, max_hear_distance = 10}, true)
            if not nexus_chest.chest_lid_obstructed(pos) then
                minetest.swap_node(pos, { name = name .. "_open", param2 = node.param2 })
            end
            minetest.after(0.2, minetest.show_formspec, cn, "nexus_chest:chest", nexus_chest.get_chest_formspec(pos))
            nexus_chest.open_chests[cn] = { pos = pos, sound = def.sound_close, swap = name }
        end
        def.on_blast = function() end
        def.on_key_use = function(pos, player)
            local secret = minetest.get_meta(pos):get_string("key_lock_secret")
            local itemstack = player:get_wielded_item()
            local key_meta = itemstack:get_meta()

            if itemstack:get_meta():get_string("") == "" then
                return
            end

            if key_meta:get_string("secret") == "" then
                key_meta:set_string("secret", minetest.parse_json(itemstack:get_meta():get_string("")).secret)
                itemstack:set_metadata("")
            end

            if secret ~= key_meta:get_string("secret") then
                return
            end

            minetest.show_formspec(player:get_player_name(), "nexus_chest:chest_locked", nexus_chest.get_chest_formspec(pos))
        end
        def.on_skeleton_key_use = function(pos, player, newsecret)
            local meta = minetest.get_meta(pos)
            local owner = meta:get_string("owner")
            local pn = player:get_player_name()

            -- verify placer is owner of lockable chest
            if owner ~= pn then
                minetest.record_protection_violation(pos, pn)
                minetest.chat_send_player(pn, "You do not own this chest.")
                return nil
            end

            local secret = meta:get_string("key_lock_secret")
            if secret == "" then
                secret = newsecret
                meta:set_string("key_lock_secret", secret)
            end

            return secret, "a locked chest", owner
        end
    else
        -- Non-protected variant
        def.on_construct = function(pos)
            local meta = minetest.get_meta(pos)
            meta:set_string("infotext", "Coffre en Nexurium")
            local inv = meta:get_inventory()
            inv:set_size("main", 8*4)
        end
        def.can_dig = function(pos,player)
            local meta = minetest.get_meta(pos)
            local inv = meta:get_inventory()
            return inv:is_empty("main")
        end
        def.on_rightclick = function(pos, node, clicker)
            local cn = clicker:get_player_name()

            if nexus_chest.open_chests[cn] then
                nexus_chest.chest_lid_close(cn)
            end

            minetest.sound_play(def.sound_open, {gain = 0.3, pos = pos, max_hear_distance = 10}, true)
            if not nexus_chest.chest_lid_obstructed(pos) then
                minetest.swap_node(pos, { name = name .. "_open", param2 = node.param2 })
            end
            minetest.after(0.2, minetest.show_formspec, cn, "nexus_chest:chest", nexus_chest.get_chest_formspec(pos))
            nexus_chest.open_chests[cn] = { pos = pos, sound = def.sound_close, swap = name }
        end
        def.on_blast = function(pos)
            local drops = {}
            if default.get_inventory_drops then
                default.get_inventory_drops(pos, "main", drops)
            end
            drops[#drops+1] = name
            minetest.remove_node(pos)
            return drops
        end
    end

    -- Use default logger setter if available, otherwise skip
    if default.set_inventory_action_loggers then
        default.set_inventory_action_loggers(def, "nexus_chest")
    end

    local def_opened = table.copy(def)
    local def_closed = table.copy(def)

    def_opened.mesh = "chest_open.obj"
    for i = 1, #def_opened.tiles do
        if type(def_opened.tiles[i]) == "string" then
            def_opened.tiles[i] = {name = def_opened.tiles[i], backface_culling = true}
        elseif def_opened.tiles[i].backface_culling == nil then
            def_opened.tiles[i].backface_culling = true
        end
    end
    def_opened.drop = name
    def_opened.groups.not_in_creative_inventory = 1
    def_opened.selection_box = {
        type = "fixed",
        fixed = { -1/2, -1/2, -1/2, 1/2, 3/16, 1/2 },
    }
    def_opened.can_dig = function()
        return false
    end
    def_opened.on_blast = function() end

    def_closed.mesh = nil
    def_closed.drawtype = nil
    -- swap textures around for "normal"
    def_closed.tiles[6] = def.tiles[5]
    def_closed.tiles[5] = def.tiles[3]
    def_closed.tiles[3] = def.tiles[3].."^[transformFX"

    minetest.register_node(prefixed_name, def_closed)
    minetest.register_node(prefixed_name .. "_open", def_opened)

    -- convert old chests to this new variant
    if name == "nexus:chest" or name == "nexus:chest_locked" then
        minetest.register_lbm({
            label = "update chests to opening chests",
            name = "nexus_chest:upgrade_" .. name:sub(9,-1) .. "_v2",
            nodenames = {name},
            action = function(pos, node)
                local meta = minetest.get_meta(pos)
                meta:set_string("formspec", "")
                local inv = meta:get_inventory()
                local list = inv:get_list("nexus:chest")
                if list then
                    inv:set_size("main", 8*4)
                    inv:set_list("main", list)
                    inv:set_list("nexus:chest", nil)
                end
            end
        })
    end

    -- close opened chests on load
    local modname_lbm, chestname = prefixed_name:match("^(:?.-):(.*)$")
    minetest.register_lbm({
        label = "close opened chests on load",
        name = modname_lbm .. ":close_" .. chestname .. "_open",
        nodenames = {prefixed_name .. "_open"},
        run_at_every_load = true,
        action = function(pos, node)
            node.name = prefixed_name
            minetest.swap_node(pos, node)
        end
    })
end

-- Register the standard and locked nexus_chest variants
nexus_chest.register_chest("nexus_chest:chest", {
    description = "Coffre en Nexurium",
    tiles = {
        "nexus_chest_top.png",
        "nexus_chest_top.png",
        "nexus_chest_side.png",
        "nexus_chest_side.png",
        "nexus_chest_front.png",
        "nexus_chest_inside.png"
    },
    sounds = (default and default.node_sound_wood_defaults) and default.node_sound_wood_defaults() or nil,
    sound_open = "default_chest_open",
    sound_close = "default_chest_close",
    groups = {choppy = 2, oddly_breakable_by_hand = 2},
})

nexus_chest.register_chest("nexus_chest:chest_locked", {
    description = "Coffre verrouillé en Nexurium",
    tiles = {
        "nexus_chest_top.png",
        "nexus_chest_top.png",
        "nexus_chest_side.png",
        "nexus_chest_side.png",
        "nexus_chest_lock.png",
        "nexus_chest_inside.png"
    },
    sounds = (default and default.node_sound_wood_defaults) and default.node_sound_wood_defaults() or nil,
    sound_open = "default_chest_open",
    sound_close = "default_chest_close",
    groups = {choppy = 2, oddly_breakable_by_hand = 2},
    protected = true,
})

-- =========================
-- COFFRE NORMAL
-- =========================
minetest.register_craft({
    output = "nexus_chest:chest",
    recipe = {
        {"nexus_stuff:nexurium_block", "nexus_stuff:nexurium_block", "nexus_stuff:nexurium_block"},
        {"nexus_stuff:nexurium_block", "",                         "nexus_stuff:nexurium_block"},
        {"nexus_stuff:nexurium_block", "nexus_stuff:nexurium_block", "nexus_stuff:nexurium_block"},
    }
})

-- =========================
-- COFFRE VERROUILLÉ
-- =========================
minetest.register_craft({
    type = "shapeless",
    output = "nexus_chest:chest_locked",
    recipe = {
        "nexus_chest:chest",
        "nexus_stuff:nexurium_ingot",
    }
})