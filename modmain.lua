local GLOBAL = GLOBAL
local TUNING = GLOBAL.TUNING or {}
local GetModConfigData = GLOBAL.GetModConfigData
local AddPrefabPostInit = GLOBAL.AddPrefabPostInit
local AddComponentPostInit = GLOBAL.AddComponentPostInit

-- Configuration --------------------------------------------------------------
local function NormaliseMode(value)
    if type(value) == "string" then
        value = string.lower(value)
    end
    if value == "multiplier" then
        return "multiplier"
    end
    return "infinite"
end

local remote_mode = NormaliseMode(GetModConfigData("REMOTE_RANGE_MODE") or "infinite")
local remote_multiplier = tonumber(GetModConfigData("REMOTE_RANGE_MULTIPLIER")) or 100

local catapult_mode = NormaliseMode(GetModConfigData("CATAPULT_RANGE_MODE") or "infinite")
local catapult_multiplier = tonumber(GetModConfigData("CATAPULT_RANGE_MULTIPLIER")) or 100

local REMOTE_INFINITY_RADIUS = 99999
local CATAPULT_INFINITY_RADIUS = 99999

local DEFAULT_REMOTE_RANGE = math.max(TUNING.WINONA_CATAPULT_REMOTE_RANGE or 40, 40)
local DEFAULT_CATAPULT_RANGE = math.max(
    TUNING.WINONA_CATAPULT_MAX_RANGE or 20,
    TUNING.WINONA_CATAPULT_TARGET_DIST or 20,
    TUNING.WINONA_CATAPULT_ATTACK_RANGE or 20,
    20
)

-- Uses configuration values to convert base remote interaction distances
-- into the mod-adjusted radius that Winona can reach.
local function ComputeRemoteRange(base)
    base = math.max(base or DEFAULT_REMOTE_RANGE, 1)
    if remote_mode == "infinite" then
        return math.max(base, REMOTE_INFINITY_RADIUS)
    end
    return math.max(base * remote_multiplier, base)
end

-- Uses configuration values to expand the catapult's target and projectile
-- range while preserving the original baseline when multipliers are used.
local function ComputeCatapultRange(base)
    base = math.max(base or DEFAULT_CATAPULT_RANGE, 1)
    if catapult_mode == "infinite" then
        return math.max(base, CATAPULT_INFINITY_RADIUS)
    end
    return math.max(base * catapult_multiplier, base)
end

local function LogWarning(message)
    GLOBAL.print("[Winona Infinite Catapult Remote] " .. tostring(message))
end

-- Winona Remote --------------------------------------------------------------
AddComponentPostInit("winonaremote", function(self)
    if self == nil then
        LogWarning("winonaremote component missing; remote range override skipped.")
        return
    end

    -- Expand each distance related field on the remote component.
    local function AdjustField(field)
        if self[field] ~= nil then
            local success, new_value = pcall(ComputeRemoteRange, self[field])
            if success and new_value ~= nil then
                self[field] = new_value
            else
                LogWarning("Failed to adjust winonaremote field: " .. tostring(field))
            end
        end
    end

    AdjustField("range")
    AdjustField("searchdistance")
    AdjustField("scanrange")
    AdjustField("linkdist")

    -- Some fields are also exposed through setter helpers; update them when
    -- available so other systems that read via getters receive the new range.
    if self.SetRange ~= nil then
        local ok, current = pcall(function()
            return self.GetRange ~= nil and self:GetRange() or self.range
        end)
        if ok then
            local new_value = ComputeRemoteRange(current)
            if new_value ~= nil then
                self:SetRange(new_value)
            end
        end
    end

    if self.SetSearchDistance ~= nil and self.searchdistance ~= nil then
        local new_value = ComputeRemoteRange(self.searchdistance)
        if new_value ~= nil then
            self:SetSearchDistance(new_value)
        end
    end

    if self.SetScanRange ~= nil and self.scanrange ~= nil then
        local new_value = ComputeRemoteRange(self.scanrange)
        if new_value ~= nil then
            self:SetScanRange(new_value)
        end
    end

    if self.SetLinkDistance ~= nil and self.linkdist ~= nil then
        local new_value = ComputeRemoteRange(self.linkdist)
        if new_value ~= nil then
            self:SetLinkDistance(new_value)
        end
    end
end)

-- Applies the enlarged range to the catapult's targeting logic and
-- interaction components so that it can acquire and shoot targets according
-- to the chosen configuration.
local function ApplyCatapultRange(inst)
    if inst == nil then
        return
    end

    local world = GLOBAL.TheWorld
    if world == nil or not world.ismastersim then
        return
    end

    local base_range = DEFAULT_CATAPULT_RANGE

    if inst.range ~= nil then
        base_range = math.max(base_range, inst.range)
    end
    if inst.targetrange ~= nil then
        base_range = math.max(base_range, inst.targetrange)
    end

    if inst.components ~= nil then
        if inst.components.combat ~= nil then
            if inst.components.combat.attackrange ~= nil then
                base_range = math.max(base_range, inst.components.combat.attackrange)
            end
            if inst.components.combat.hitrange ~= nil then
                base_range = math.max(base_range, inst.components.combat.hitrange)
            end
            if inst.components.combat.targetdistance ~= nil then
                base_range = math.max(base_range, inst.components.combat.targetdistance)
            end
            if inst.components.combat.areatargetdistance ~= nil then
                base_range = math.max(base_range, inst.components.combat.areatargetdistance)
            end
        end
        if inst.components.entitytracker ~= nil and inst.components.entitytracker.range ~= nil then
            base_range = math.max(base_range, inst.components.entitytracker.range)
        end
        if inst.components.turret ~= nil and inst.components.turret.range ~= nil then
            base_range = math.max(base_range, inst.components.turret.range)
        end
    end

    local desired_range = ComputeCatapultRange(base_range)

    if inst.components ~= nil then
        if inst.components.combat ~= nil then
            if inst.components.combat.SetRange ~= nil then
                inst.components.combat:SetRange(desired_range)
            else
                inst.components.combat.attackrange = desired_range
            end
            inst.components.combat.hitrange = math.max(inst.components.combat.hitrange or desired_range, desired_range)

            if inst.components.combat.SetRetargetFunction ~= nil then
                local function RetargetFn(catapult)
                    return GLOBAL.FindEntity(
                        catapult,
                        desired_range,
                        function(guy)
                            return catapult.components.combat ~= nil and catapult.components.combat:CanTarget(guy)
                        end,
                        { "_combat" },
                        { "FX", "NOCLICK", "INLIMBO", "playerghost", "companion", "wall" },
                        { "monster", "character", "hostile", "animal" }
                    )
                end
                inst.components.combat:SetRetargetFunction(0.25, RetargetFn)
            end

            if inst.components.combat.SetKeepTargetFunction ~= nil then
                inst.components.combat:SetKeepTargetFunction(function(catapult, target)
                    return catapult.components.combat ~= nil
                        and catapult.components.combat:CanTarget(target)
                        and target ~= nil
                        and target:IsValid()
                end)
            end
        end

        if inst.components.entitytracker ~= nil then
            if inst.components.entitytracker.SetRange ~= nil then
                inst.components.entitytracker:SetRange(desired_range)
            else
                inst.components.entitytracker.range = desired_range
            end
        end

        if inst.components.turret ~= nil then
            if inst.components.turret.SetRange ~= nil then
                inst.components.turret:SetRange(desired_range)
            end
            inst.components.turret.range = desired_range
            if inst.components.turret.SetProjectileDistance ~= nil then
                inst.components.turret:SetProjectileDistance(desired_range)
            end
        end
    end

    inst.range = desired_range
    inst.targetrange = desired_range
end

AddPrefabPostInit("winona_catapult", function(inst)
    if inst == nil then
        LogWarning("winona_catapult prefab missing; no range adjustments applied.")
        return
    end

    if not GLOBAL.TheWorld.ismastersim then
        return
    end

    ApplyCatapultRange(inst)
    inst:DoTaskInTime(0, ApplyCatapultRange)
end)

-- Ensure the spawned boulders retain damage behaviour but travel far enough
-- to reach distant targets based on the configuration or infinite mode.
AddPrefabPostInit("catapult_boulder", function(inst)
    local world = GLOBAL.TheWorld
    if world == nil or not world.ismastersim then
        return
    end

    if inst.components == nil or inst.components.projectile == nil then
        LogWarning("catapult_boulder missing projectile component; range boost skipped.")
        return
    end

    local projectile = inst.components.projectile
    local base_range = projectile.range or projectile.hitdist or DEFAULT_CATAPULT_RANGE
    local desired_range = ComputeCatapultRange(base_range)

    if projectile.SetRange ~= nil then
        projectile:SetRange(desired_range)
    else
        projectile.range = desired_range
    end

    if projectile.SetMaxDistance ~= nil then
        projectile:SetMaxDistance(desired_range)
    end

    if projectile.SetMaxTravelTime ~= nil then
        local speed = projectile.GetSpeed ~= nil and projectile:GetSpeed() or projectile.speed or 15
        if speed > 0 then
            projectile:SetMaxTravelTime(desired_range / speed)
        end
    end

    if projectile.SetSpeed ~= nil then
        local current_speed = projectile.GetSpeed ~= nil and projectile:GetSpeed() or projectile.speed or 15
        projectile:SetSpeed(current_speed)
    end
end)
