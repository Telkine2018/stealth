
---@param name string
local function np(name)
    return "stealth_" .. name

end

local declarations = {}
local order = 0

---@param name string
---@param default_value number
---@param min_value number
---@param type string?
local function add_field(name, default_value, min_value, type)

    if not type then
        type = "int-setting"
    end
    local declaration = {
        type = type,
        name = np(name),
		setting_type = "startup",
        default_value = default_value,
        min_value = min_value,
		order="a" .. string.char(order + string.byte("a"))
    }
    order = order + 1
    table.insert(declarations, declaration)
end

add_field("radius", 30, 10)
add_field("duration", 5 * 60, 30)
add_field("cooldown", 10, 1)
add_field("gun_threat", 15, 0)
add_field("threat_decrease", 1, 1)
add_field("threat_upperbound", 4, 1)
add_field("timebomb_delay", 10, 1)
add_field("timebomb_dist", 5, 1)
add_field("timebomb_damage", 8000, 1000)
add_field("timebomb_radius", 16, 5)
add_field("smokecloud_threat", 3, 1)
add_field("protection_threat", 2, 1)
add_field("protection_radius", 1.5, 1)
add_field("died_bonus", 10, 1)
add_field("exit_stealth_speed_modifier", 0.8, 0, "double-setting")

data:extend(declarations)
