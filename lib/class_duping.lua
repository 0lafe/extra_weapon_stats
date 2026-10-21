-- Collection of logic related to duplicating and isolating vanilla classes
-- Meant for creating private instances of things like NewRaycastWeaponBase to isolate funcitonality

-- Gets classes with super's that resolve to a given root
-- More dynamic than a list of classes I wish to override
local function class_names_under(roots)
    local names = {}

    for k, v in pairs(_G) do
        if type(k) == "string" and type(v) == "table" then
            local c, depth = v, 0

            while type(c) == "table" and depth < 32 do
                local include_root = roots[c]

                if include_root ~= nil then
                    if c ~= v or include_root then
                        names[k] = true
                    end

                    break
                end

                c = rawget(c, "super")
                depth = depth + 1
            end
        end
    end

    return names
end

-- classes that need to be unreachable when requiring game classes
local function hidden_class_names()
    local roots = {}
    local function add(name, include_root)
        local c = rawget(_G, name)

        if type(c) == "table" then
            roots[c] = include_root
        end
    end

    add("UnitBase", false)
    add("PlayerMovementState", false)
    add("NewRaycastWeaponBase", true)
    add("InstantBulletBase", true)

    return class_names_under(roots)
end

local function noop() end

-- dupe table with overrides, but non overrides fallback to original
local function proxy(real, overrides)
    return setmetatable(overrides, {
        __index = function(_, k)
            local v = real[k]

            if type(v) == "function" then
                return function(_, ...)
                    return v(real, ...)
                end
            end

            return v
        end
    })
end

-- dupe table with overrides, but non overrides return noop
-- stolen from MWS :)
local function fill_with_empty_methods(source, result)
    if not source then
        return setmetatable(result or {}, {
            __index = function() return noop end
        })
    end

    result = result or {}

    if type(source.super) == 'table' then
        result = fill_with_empty_methods(source.super, result)
    end

    local holder = source
    if type(source) == 'userdata' then
        holder = getmetatable(source)
    end

    for k, v in pairs(holder) do
        if type(v) == 'function' and not result[k] then
            result[k] = noop
        end
    end

    return result
end

-- Standin for simulated timing
EWS.sim_timer = {
    t = 0,
    time = function(self)
        return self.t
    end
}

EWS.lerp_capture = nil

-- Global overrides for weapon specific logic
local function install_stand_ins(env)
    -- private math so lerp can be observed without patching the global one
    -- used to get ammo pickup the way MWS did it
    -- Probably a better way to do this, but I do not know it
    env.math = setmetatable(
        {
            lerp = function(a, b, t)
                local capture = EWS.lerp_capture

                if capture and not capture.min then
                    capture.min, capture.max = a, b
                end

                return math.lerp(a, b, t)
            end
        },
        {
            __index = math
        }
    )

    -- get tables in the local env first if they exist
    env.CoreSerialize = setmetatable(
        {
            string_to_classtable = function(s)
                return rawget(env, s) or CoreSerialize.string_to_classtable(s)
            end
        },
        {
            __index = CoreSerialize
        }
    )

    env.SoundDevice = {
        create_source = function()
            return {
                link = noop,
                set_switch = noop,
                post_event = noop,
                stop = noop
            }
        end
    }

    env.managers = setmetatable(
        {
            hud = fill_with_empty_methods(HUDManager),
            achievment = fill_with_empty_methods(AchievmentManager),
            challenge = fill_with_empty_methods(ChallengeManager),
            enemy = fill_with_empty_methods(EnemyManager),
            job = fill_with_empty_methods(JobManager),
            mission = fill_with_empty_methods(MissionManager),
            statistics = fill_with_empty_methods(StatisticsManager),
            player = proxy(managers.player, {
                register_message = noop,
                unregister_message = noop,
                send_message = noop,
                send_message_now = noop,
                player_unit = noop,
                remove_property = noop,
                player_timer = function()
                    return EWS.sim_timer
                end
            }),
        },
        {
            __index = function(_, k)
                return managers[k]
            end
        }
    )
end

local function build()
    local hidden = hidden_class_names()

    local env = setmetatable({}, {
        __index = function(_, k)
            if hidden[k] then
                return nil
            end

            return _G[k]
        end
    })

    install_stand_ins(env)

    -- files needed to be required
    local scripts = {
        "lib/units/weapons/RaycastWeaponBase",
        "lib/units/weapons/NewRaycastWeaponBase",
        "lib/units/weapons/NPCRaycastWeaponBase",
        "lib/units/weapons/NewNPCRaycastWeaponBase",
        "lib/units/weapons/SawWeaponBase",
        "lib/units/weapons/NewFlamethrowerBase",
        "lib/units/weapons/shotgun/ShotgunBase",
        "lib/units/weapons/ProjectileWeaponBase",
        "lib/units/weapons/GrenadeLauncherBase",
        "lib/units/weapons/BowWeaponBase",
        "lib/units/weapons/AkimboWeaponBase",
        "lib/units/weapons/AkimboShotgunBase",
        "lib/units/weapons/FlamethrowerEffectExtension",
        "lib/units/weapons/shotgun/RevolvingShotgunBase",
        "lib/units/beings/player/states/PlayerStandard",
        "lib/units/weapons/WeaponGadgetBase",
        "lib/units/weapons/WeaponUnderbarrel",
        "lib/units/weapons/WeaponUnderbarrelLauncher",
        "lib/units/weapons/WeaponUnderbarrelRaycast"
    }

    -- Only gamesetup loads UnitBase.
    if not rawget(_G, "UnitBase") then
        table.insert(scripts, "lib/units/UnitBase")
    end

    -- files that need to be required again
    -- found in NewRaycastWeaponBase
    local needs_require_again = {
        "lib/units/weapons/CosmeticsWeaponBase",
        "lib/units/weapons/ScopeBase"
    }

    -- Force rerunning of all scripts needed in the private env
    for _, list in ipairs({ scripts, needs_require_again }) do
        for _, path in ipairs(list) do
            package.loaded[path:lower()] = nil
        end
    end

    local co = coroutine.create(function()
        setfenv(0, env)

        for _, path in ipairs(scripts) do
            require(path)
        end
    end)

    coroutine.resume(co)

    return env
end

function EWS:get_classes()
    if not self._env then
        self._env = build()
    end
    
    return self._env
end
