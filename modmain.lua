local TUNING = GLOBAL.TUNING
local AddPrefabPostInit = GLOBAL.AddPrefabPostInit
local AddComponentPostInit = GLOBAL.AddComponentPostInit

local RANGE_MULTIPLIER = 3
local REMOTE_SUPER_RANGE = 10000

local function multiply_tuning_value(name, multiplier, minimum)
    if TUNING[name] ~= nil then
        local new_value = TUNING[name] * multiplier
        if minimum ~= nil then
            new_value = math.max(new_value, minimum)
        end
        TUNING[name] = new_value
        return new_value
    end
    return nil
end

local enhanced_range = multiply_tuning_value("WINONA_CATAPULT_MAX_RANGE", RANGE_MULTIPLIER, 1000) or 1000
local enhanced_target_dist = multiply_tuning_value("WINONA_CATAPULT_TARGET_DIST", RANGE_MULTIPLIER, enhanced_range) or enhanced_range
local enhanced_attack_range = multiply_tuning_value("WINONA_CATAPULT_ATTACK_RANGE", RANGE_MULTIPLIER, enhanced_range) or enhanced_range

if TUNING.WINONA_CATAPULT_REMOTE_RANGE ~= nil then
    TUNING.WINONA_CATAPULT_REMOTE_RANGE = math.max(TUNING.WINONA_CATAPULT_REMOTE_RANGE, REMOTE_SUPER_RANGE)
else
    TUNING.WINONA_CATAPULT_REMOTE_RANGE = REMOTE_SUPER_RANGE
end

local function configure_catapult(inst)
    local world = GLOBAL.TheWorld
    if world == nil or not world.ismastersim then
        return inst
    end

    local range = math.max(
        TUNING.WINONA_CATAPULT_MAX_RANGE or 0,
        TUNING.WINONA_CATAPULT_TARGET_DIST or 0,
        TUNING.WINONA_CATAPULT_ATTACK_RANGE or 0,
        enhanced_range,
        enhanced_target_dist,
        enhanced_attack_range
    )
    local search_range = math.max(range, TUNING.WINONA_CATAPULT_REMOTE_RANGE or 0, REMOTE_SUPER_RANGE)

    if inst.components.combat ~= nil then
        inst.components.combat:SetRange(range)
        inst.components.combat.hitrange = math.max(inst.components.combat.hitrange or range, range)
        inst.components.combat:SetDefaultDamage(inst.components.combat.defaultdamage)
    end

    if inst.components.entitytracker ~= nil and inst.components.entitytracker.range ~= nil then
        inst.components.entitytracker.range = math.max(inst.components.entitytracker.range, search_range)
    end

    if inst.components.projectile ~= nil then
        if inst.components.projectile.SetRange ~= nil then
            inst.components.projectile:SetRange(range)
        end

        if inst.components.projectile.SetSpeed ~= nil then
            local current_speed = nil
            if inst.components.projectile.GetSpeed ~= nil then
                current_speed = inst.components.projectile:GetSpeed()
            elseif inst.components.projectile.speed ~= nil then
                current_speed = inst.components.projectile.speed
            end

            inst.components.projectile:SetSpeed((current_speed or 30) * RANGE_MULTIPLIER)
        end
    end

    if inst.components.combat ~= nil then
        local function retargetfn(inst)
            return GLOBAL.FindEntity(
                inst,
                search_range,
                function(guy)
                    return inst.components.combat:CanTarget(guy)
                end,
                { "_combat" },
                { "FX", "INLIMBO", "playerghost", "companion", "wall" },
                { "monster", "character", "hostile", "animal" }
            )
        end

        inst.components.combat:SetRetargetFunction(0.25, retargetfn)
    end

    return inst
end

AddPrefabPostInit("winona_catapult", configure_catapult)

AddComponentPostInit("winonaremote", function(self)
    if self == nil then
        return
    end

    if self.range ~= nil then
        self.range = math.max(self.range, REMOTE_SUPER_RANGE)
    end

    if self.searchdistance ~= nil then
        self.searchdistance = math.max(self.searchdistance, REMOTE_SUPER_RANGE)
    end

    if self.scanrange ~= nil then
        self.scanrange = math.max(self.scanrange, REMOTE_SUPER_RANGE)
    end

    if self.linkdist ~= nil then
        self.linkdist = math.max(self.linkdist, REMOTE_SUPER_RANGE)
    end
end)

AddPrefabPostInit("winona_remote", function(inst)
    local world = GLOBAL.TheWorld
    if world == nil or not world.ismastersim then
        return inst
    end

    if inst.components.activatable ~= nil then
        inst.components.activatable.quickaction = true
    end

    if inst.components.inventoryitem ~= nil then
        inst.components.inventoryitem.atlasname = inst.components.inventoryitem.atlasname or "images/inventoryimages/winona_remote.xml"
    end

    return inst
end)
