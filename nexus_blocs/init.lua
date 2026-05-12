-- nexus_blocs/init.lua
-- Mod "nexus_blocs" : minerai Nexus, éclats, génération d'ore, ruines de surface et Fusionneur
-- Enregistre les items et la machine sous le préfixe nexus_blocs:.

local s_stone = (default and default.node_sound_stone_defaults) and default.node_sound_stone_defaults() or nil

-- ==========================================
-- Configuration
-- ==========================================
local FUSION_MAX = 5

local function return_item_to_player_or_drop(pos, player, stack)
    if player and player:is_player() then
        local inv = player:get_inventory()
        local leftover = inv:add_item("main", stack)
        if not leftover:is_empty() then
            minetest.add_item(pos, leftover)
        end
    else
        minetest.add_item(pos, stack)
    end
end

-- =========================
-- Items / blocs
-- =========================

minetest.register_craftitem("nexus_blocs:nexus_shard", {
    description = "Éclat de Nexus",
    inventory_image = "nexus_shard.png",
})

minetest.register_node("nexus_blocs:nexus_ore", {
    description = "Minerai de Nexus",
    tiles = {"default_stone.png^nexus_ore.png"},
    groups = {cracky = 2},
    drop = "nexus_blocs:nexus_shard",
    sounds = s_stone,
})

-- =========================
-- Fusionneur (machine)
-- =========================

local function get_nexus_formspec(progress)
    local p = progress or 0
    local arrow = "nexus_arrow_" .. p .. ".png"
    return "size[8,9]" ..
        "label[1,0.5;Fragment de Nexus]" ..
        "list[context;input_nexus;1,1;1,1;]" ..
        "label[3,0.5;Stellaria]" ..
        "list[context;input_plant;3,1;1,1;]" ..
        "image[4.6,1;1,1;" .. arrow .. "]" ..
        "label[6,0.5;Résultat]" ..
        "list[context;output;6,1;1,1;]" ..
        "list[current_player;main;0,5;8,4;]" ..
        "listring[context;output]" ..
        "listring[current_player;main]"
end

minetest.register_node("nexus_blocs:fusionner", {
    description = "Fusionneur de Nexus",
    tiles = {"fusionner_top.png", "fusionner_bottom.png", "fusionner_side.png"},
    groups = {cracky = 2, stone = 1},
    sounds = s_stone,

    on_construct = function(pos)
        local meta = minetest.get_meta(pos)
        meta:set_int("progress", 0)
        meta:set_string("formspec", get_nexus_formspec(0))
        local inv = meta:get_inventory()
        inv:set_size("input_nexus", 1)
        inv:set_size("input_plant", 1)
        inv:set_size("output", 1)
    end,

    on_metadata_inventory_put = function(pos, listname, index, stack, player)
        local meta = minetest.get_meta(pos)
        local inv = meta:get_inventory()

        if listname == "input_nexus" then
            if stack:get_name() ~= "nexus_blocs:nexus_shard" then
                inv:set_stack("input_nexus", index, "")
                return_item_to_player_or_drop(pos, player, stack)
                if player and player:is_player() then
                    minetest.chat_send_player(player:get_player_name(), "Seul l'Éclat de Nexus est accepté dans cette fente.")
                end
                return
            end
        end

        if listname == "input_plant" then
            if stack:get_name() ~= "nexus_farming:stellaria" then
                inv:set_stack("input_plant", index, "")
                return_item_to_player_or_drop(pos, player, stack)
                if player and player:is_player() then
                    minetest.chat_send_player(player:get_player_name(), "Seule la Stellaria est acceptée dans cette fente.")
                end
                return
            end
        end

        local timer = minetest.get_node_timer(pos)
        if not timer:is_started() then
            timer:start(1.0)
        end
    end,

    on_timer = function(pos, elapsed)
        local meta = minetest.get_meta(pos)
        local inv = meta:get_inventory()
        local nexus = inv:get_stack("input_nexus", 1)
        local plant = inv:get_stack("input_plant", 1)
        local progress = meta:get_int("progress")

        -- validate items still present and correct
        if nexus:get_name() ~= "" and nexus:get_name() ~= "nexus_blocs:nexus_shard" then
            local stack = nexus
            inv:set_stack("input_nexus", 1, "")
            minetest.add_item(pos, stack)
            meta:set_int("progress", 0)
            meta:set_string("formspec", get_nexus_formspec(0))
            return false
        end
        if plant:get_name() ~= "" and plant:get_name() ~= "nexus_farming:stellaria" then
            local stack = plant
            inv:set_stack("input_plant", 1, "")
            minetest.add_item(pos, stack)
            meta:set_int("progress", 0)
            meta:set_string("formspec", get_nexus_formspec(0))
            return false
        end

        if nexus:get_name() ~= "nexus_blocs:nexus_shard" or plant:get_name() ~= "nexus_farming:stellaria" then
            meta:set_int("progress", 0)
            meta:set_string("formspec", get_nexus_formspec(0))
            return false
        end

        progress = progress + 1

        if progress >= FUSION_MAX then
            if inv:room_for_item("output", "nexus_stuff:nexurium_ingot") then
                nexus:take_item()
                plant:take_item()
                inv:set_stack("input_nexus", 1, nexus)
                inv:set_stack("input_plant", 1, plant)
                inv:add_item("output", "nexus_stuff:nexurium_ingot")
                minetest.sound_play("default_cool_lava", {pos = pos, gain = 0.5}, true)
                meta:set_int("progress", 0)
                meta:set_string("formspec", get_nexus_formspec(0))
                return not inv:get_stack("input_nexus", 1):is_empty()
            end
            return false
        else
            meta:set_int("progress", progress)
            meta:set_string("formspec", get_nexus_formspec(progress))
            return true
        end
    end,

    on_metadata_inventory_take = function(pos, listname, index, stack, player)
        local timer = minetest.get_node_timer(pos)
        if not timer:is_started() then
            timer:start(1.0)
        end
    end,
})

-- Fusionneur craft (utilise des ressources de base)
minetest.register_craft({
    output = "nexus_blocs:fusionner",
    recipe = {
        {"default:steel_ingot", "group:wood", "default:steel_ingot"},
        {"group:wood", "group:wood", "group:wood"},
        {"default:stone", "default:stone", "default:stone"},
    }
})

-- =========================
-- Génération du minerai
-- =========================

minetest.register_ore({
    ore_type       = "scatter",
    ore            = "nexus_blocs:nexus_ore",
    wherein        = {"default:stone", "default:desert_stone", "default:sandstone"},
    clust_scarcity = 9 * 9 * 9,
    clust_num_ores = 6,
    clust_size     = 3,
    y_min          = -31000,
    y_max          = 200,
})

-- =========================
-- Ruines de surface avec coffres
-- =========================

local RUIN_CHANCE_PER_CHUNK = 0.02 -- 2% par chunk
local RUIN_RADIUS = 2
local RUIN_HEIGHT = 3

local function is_solid_node(name)
    if not name then return false end
    if name == "air" then return false end
    local reg = minetest.registered_nodes[name]
    if reg and reg.liquidtype and reg.liquidtype ~= "none" then
        return false
    end
    return true
end

local function fill_ruin_chest(pos)
    local meta = minetest.get_meta(pos)
    if not meta then return end
    local inv = meta:get_inventory()
    if not inv then return end
    if inv:get_size("main") then
        for i = 1, inv:get_size("main") do
            inv:set_stack("main", i, "")
        end
    end
    local roll = math.random()
    if roll < 0.08 then
        if math.random() < 0.5 then
            inv:add_item("main", "nexus_stuff:nexurium_block")
        else
            inv:add_item("main", "nexus_stuff:nexurium_ingot")
        end
    else
        local n = math.random(1,4)
        inv:add_item("main", "nexus_blocs:nexus_shard " .. tostring(n))
    end
end

local function place_ruin_at(cx, cy, cz)
    -- vérifier espace libre au-dessus
    for x = cx - RUIN_RADIUS - 1, cx + RUIN_RADIUS + 1 do
        for z = cz - RUIN_RADIUS - 1, cz + RUIN_RADIUS + 1 do
            local top = minetest.get_node({x = x, y = cy + RUIN_HEIGHT + 1, z = z}).name
            if top ~= "air" then
                return
            end
        end
    end

    local wall = "default:stonebrick"
    if not minetest.registered_nodes[wall] then
        wall = "default:stone"
    end

    -- sol (cy-1)
    for x = cx - RUIN_RADIUS, cx + RUIN_RADIUS do
        for z = cz - RUIN_RADIUS, cz + RUIN_RADIUS do
            minetest.set_node({x = x, y = cy - 1, z = z}, {name = wall})
        end
    end

    -- murs (avec ouvertures aléatoires)
    for y = cy, cy + RUIN_HEIGHT - 1 do
        for x = cx - RUIN_RADIUS, cx + RUIN_RADIUS do
            for z = cz - RUIN_RADIUS, cz + RUIN_RADIUS do
                local at_edge = (x == cx - RUIN_RADIUS) or (x == cx + RUIN_RADIUS) or (z == cz - RUIN_RADIUS) or (z == cz + RUIN_RADIUS)
                if at_edge then
                    if math.random() < 0.25 then
                        minetest.set_node({x = x, y = y, z = z}, {name = "air"})
                    else
                        minetest.set_node({x = x, y = y, z = z}, {name = wall})
                    end
                else
                    minetest.set_node({x = x, y = y, z = z}, {name = "air"})
                end
            end
        end
    end

    -- toit partiel (cassé)
    for x = cx - RUIN_RADIUS, cx + RUIN_RADIUS do
        for z = cz - RUIN_RADIUS, cz + RUIN_RADIUS do
            if math.random() < 0.6 then
                minetest.set_node({x = x, y = cy + RUIN_HEIGHT, z = z}, {name = wall})
            else
                minetest.set_node({x = x, y = cy + RUIN_HEIGHT, z = z}, {name = "air"})
            end
        end
    end

    -- placer 1 ou 2 coffres à l'intérieur
    for i = 1, math.random(1,2) do
        local rx = cx + math.random(-RUIN_RADIUS+1, RUIN_RADIUS-1)
        local rz = cz + math.random(-RUIN_RADIUS+1, RUIN_RADIUS-1)
        local ry = cy
        local pos = {x = rx, y = ry, z = rz}
        minetest.set_node(pos, {name = "default:chest"})
        fill_ruin_chest(pos)
    end

    -- décoration occasionnelle : bloc de Nexurium
    if math.random() < 0.3 then
        local px = cx + math.random(-1,1)
        local pz = cz + math.random(-1,1)
        local py = cy
        minetest.set_node({x = px, y = py, z = pz}, {name = "nexus_stuff:nexurium_block"})
    end
end

minetest.register_on_generated(function(minp, maxp, blocseed)
    if math.random() > RUIN_CHANCE_PER_CHUNK then
        return
    end

    local rx = math.random(minp.x, maxp.x)
    local rz = math.random(minp.z, maxp.z)

    -- trouver la surface en descendant
    local surface_y = nil
    for y = maxp.y, minp.y, -1 do
        local n = minetest.get_node_or_nil({x = rx, y = y, z = rz})
        if n and is_solid_node(n.name) then
            surface_y = y + 1
            break
        end
    end
    if not surface_y then return end

    -- vérifier zone plate
    local flat_ok = true
    for x = rx - RUIN_RADIUS - 1, rx + RUIN_RADIUS + 1 do
        for z = rz - RUIN_RADIUS - 1, rz + RUIN_RADIUS + 1 do
            local n = minetest.get_node_or_nil({x = x, y = surface_y - 1, z = z})
            if not n or not is_solid_node(n.name) then
                flat_ok = false
                break
            end
        end
        if not flat_ok then break end
    end
    if not flat_ok then return end

    place_ruin_at(rx, surface_y, rz)
end)

-- Fin de nexus_blocs/init.lua
