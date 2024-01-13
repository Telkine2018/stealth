local util = require("util")

local smokecloud_size = 2
local smokecloud_cooldown = 6 * 60
local smokecloud_duration = 12 * 60
local smokecloud_range = 30

local lurecapsule_cooldown = 6 * 60
local lurecapsule_range = 50

local pfx = "stealth_"
local path = "__stealth__/"
local gpath = path .. "graphics/"

local name

local function get_config(name)
  return settings.startup["stealth_" .. name].value
end

--------------------------------------------------------

local keybind = {
  type = "custom-input",
  name = "stealth_key_toggle",
  key_sequence = "Shift + R"
}

data:extend
{
  keybind
}

--------------------------------------------------------

local subgroup_name = pfx .. "subgroup"
data:extend {
  {
    type = "item-subgroup",
    name = subgroup_name,
    group = "combat",
    order = "s[tealth]"
  }
}

--------------------------------------------------------

name = pfx .. "walther_ppk"
local item = table.deepcopy(data.raw["gun"]["pistol"])
item.name = name
item.icon = gpath .. "icons/pistol.png"
item.attack_parameters.range = 20
for _, sound in pairs(item.attack_parameters.sound.variations) do
  sound.volume = 0.3
end

local recipe = table.deepcopy(data.raw["recipe"]["pistol"])
recipe.name = name
recipe.result = name

data:extend {
  item,
  recipe
}

--------------------------------------------------------

local sprite = {

  type = "sprite",
  name = "stealth_marker",
  filename = gpath .. "sprites/stealth_marker.png",
  width = 128,
  height = 109,
  scale = 0.25
}

data:extend { sprite }

--------------------------------------------------------

name = pfx .. "timebomb"

local entity = table.deepcopy(data.raw["land-mine"]["land-mine"])

entity.name = name
entity.icon = gpath .. "icons/timebomb.png"
entity.picture_safe.filename = gpath .. "entity/timebomb/hr-timebomb.png"
entity.picture_set.filename = gpath .. "entity/timebomb/hr-timebomb-set.png"
entity.picture_set_enemy.filename = gpath .. "entity/timebomb/timebomb-set-enemy.png"
entity.minable = { hardness = 0.2, mining_time = 10, result = name }
entity.max_health = 1000
entity.trigger_radius = 6

log("Damage:" .. tostring(get_config("timebomb_damage")))

entity.action = {
  type = "direct",
  action_delivery = {
    type = "instant",
    source_effects = {
      {
        type = "nested-result",
        action = {
          type = "area",
          action_delivery = {
            target_effects = {
              {
                type = "damage",
                damage =
                {
                  amount = get_config("timebomb_damage"),
                  type = "explosion"
                }
              },
              { type = "create-sticker", sticker = "stun-sticker" }
            },
            type = "instant"
          },
          radius = get_config("timebomb_radius")
        },
        affects_target = true,
      },
      { type = "create-entity", entity_name = "nuke-explosion" },
      { type = "damage", damage = { type = "explosion", amount = 1000 }
      }
    }
  }
}


item = {

  type = "item",
  name = name,
  icon = gpath .. "icons/timebomb.png",
  icon_size = 64,
  stack_size = 10,
  order = "t[imebomb]",
  subgroup = subgroup_name,
  place_result = name
}

recipe = {
  type = "recipe",
  name = name,
  icon = gpath .. "icons/timebomb.png",
  icon_size = 64,
  energy_required = 0.5,
  result = name,
  enabled = true,
  ingredients = {
    { "iron-plate",         2 },
    { "electronic-circuit", 1 },
    { "coal",               1 }
  },
  order = "stealth-[timebomb]"
}

data:extend { item, recipe, entity }

--------------------------------------------------------

name = pfx .. "bomb_trigger"
entity = table.deepcopy(data.raw["unit"]["small-biter"])
entity.name = name
entity.corpse = nil
entity.movement_speed = 0.01
entity.walking_sound = nil
entity.working_sound = nil
entity.vision_distance = 1
entity.dying_explosion = nil
entity.dying_sound = nil
entity.sound = nil
entity.animation = util.empty_sprite(16)
entity.run_animation = util.empty_sprite(16)

data:extend { entity }

--------------------------------------------------------
data.raw["gui-style"]["default"][pfx .. "progress-action"]   =
{
  type = "progressbar_style",
  parent = "progressbar",
  height = 7,
  bar_width = 7,
  with = 200
}

data.raw["gui-style"]["default"][pfx .. "progress-cooldown"] =
{
  type = "progressbar_style",
  parent = "progressbar",
  height = 20,
  bar_width = 20,
  with = 200
}

--------------------------------------------------------

name                                                         = pfx .. "smokecloud-capsule"
local cloud_name                                             = pfx .. "smokecloud"
item                                                         = table.deepcopy(data.raw["capsule"]["poison-capsule"])
item.name                                                    = name
item.order                                                   = "b[smoke_cloud]"
item.capsule_action                                          = {
  attack_parameters = {
    activation_type = "throw",
    ammo_category = "capsule",
    ammo_type = {
      action = {
        {
          type = "direct",
          action_delivery = {
            type = "projectile",
            projectile = name,
            starting_speed = 0.3,
          },
        },
        {
          type = "direct",
          action_delivery = {
            type = "instant",
            target_effects = {
              {
                type = "play-sound",
                sound = {
                  { filename = "__base__/sound/fight/throw-projectile-1.ogg", volume = 0.4 },
                  { filename = "__base__/sound/fight/throw-projectile-2.ogg", volume = 0.4 },
                  { filename = "__base__/sound/fight/throw-projectile-3.ogg", volume = 0.4 },
                  { filename = "__base__/sound/fight/throw-projectile-4.ogg", volume = 0.4 },
                  { filename = "__base__/sound/fight/throw-projectile-5.ogg", volume = 0.4 },
                  { filename = "__base__/sound/fight/throw-projectile-6.ogg", volume = 0.4 }
                }
              }
            }
          }
        }
      },
      category = "capsule",
      target_type = "position"
    },
    cooldown = smokecloud_cooldown,
    projectile_creation_distance = 0.6,
    range = smokecloud_range,
    type = "projectile"
  },
  type = "throw"
}
item.icon                                                    = gpath .. "icons/smokecloud-capsule.png"
item.subgroup                                                = subgroup_name


entity = table.deepcopy(data.raw["projectile"]["poison-capsule"])
entity.name = name
entity.action = {
  {
    action_delivery = {
      target_effects = {
        {
          type = "create-smoke",
          entity_name = cloud_name,
          initial_height = 0,
          show_in_tooltip = true
        }
      },
      type = "instant"
    },
    type = "direct"
  }
}
entity.animation = {
  animation_speed = 0.25,
  draw_as_glow = true,
  filename = gpath .. "entity/smokecloud-capsule/smokecloud-capsule.png",
  frame_count = 16,
  height = 29,
  hr_version = {
    animation_speed = 0.25,
    draw_as_glow = true,
    filename = gpath .. "entity/smokecloud-capsule/hr-smokecloud-capsule.png",
    frame_count = 16,
    height = 59,
    line_length = 8,
    priority = "high",
    scale = 0.5,
    shift = { 0.03125, 0.015625 },
    width = 58
  },
  line_length = 8,
  priority = "high",
  shift = { 0.03125, 0.015625 },
  width = 29
}
entity.shadow = {
  animation_speed = 0.25,
  draw_as_shadow = true,
  filename = gpath .. "entity/smokecloud-capsule/smokecloud-capsule-shadow.png",
  frame_count = 16,
  height = 21,
  hr_version = {
    animation_speed = 0.25,
    draw_as_shadow = true,
    filename = gpath .. "entity/smokecloud-capsule/hr-smokecloud-capsule-shadow.png",
    frame_count = 16,
    height = 42,
    line_length = 8,
    priority = "high",
    scale = 0.5,
    shift = { 0.03125, 0.0625 },
    width = 54
  },
  line_length = 8,
  priority = "high",
  shift = { 0.03125, 0.0625 },
  width = 27
}

entity.smoke = nil

cloud = {

  name = cloud_name,
  animation = {
    animation_speed = 0.25,
    filename = gpath .. "entity/smoke.png",
    flags = {
      "smoke"
    },
    frame_count = 60,
    height = 120,
    line_length = 5,
    priority = "high",
    shift = {
      -0.53125,
      -0.4375
    },
    width = 152
  },
  action_cooldown = 5,
  affected_by_wind = false,
  color = { a = 0.69, b = 0.992, g = 0.875, r = 0.839 },
  action = {
    type = "direct",
    action_delivery = {
      type = "instant",
      target_effects = {
        type = "nested-result",
        action = {
          type = "area",
          radius = smokecloud_size,
          action_delivery = {
            target_effects = {

              type = "script",
              effect_id = "smokecloud",
              affects_target = true
            },
            type = "instant"
          },
          entity_flags = {
            "breaths-air"
          }
        }
      }
    }
  },
  cyclic = true,
  duration = smokecloud_duration,
  fade_away_duration = 60,
  flags = { "not-on-map" },
  particle_count = 16,
  particle_distance_scale_factor = 0.5,
  particle_duration_variation = 180,
  particle_scale_factor = { 1, 0.707 },
  particle_spread = { 3.78, 2.268 },
  render_layer = "object",
  show_when_smoke_off = true,
  spread_duration = 20,
  spread_duration_variation = 20,
  type = "smoke-with-trigger",
  wave_distance = { 0.3, 0.2 },
  wave_speed = { 0.0125, 0.0167 }
}

recipe = {
  type = "recipe",
  name = name,
  icon = item.icon,
  icon_size = 64,
  energy_required = 0.2,
  result = name,
  enabled = true,
  ingredients = {
    { "iron-plate", 1 },
    { "coal",       2 }
  },
  order = "stealth-[smokecloud-capsule]"
}
data:extend { item, recipe, entity, cloud }

--------------------------------------------------------

name                 = pfx .. "lure-capsule"

item                 = table.deepcopy(data.raw["capsule"]["poison-capsule"])
item.name            = name
item.order           = "b[lure-capsule]"
item.capsule_action  = {
  attack_parameters = {
    activation_type = "throw",
    ammo_category = "capsule",
    ammo_type = {
      action = {
        {
          type = "direct",
          action_delivery = {
            type = "projectile",
            projectile = name,
            starting_speed = 0.3,
          },
        },
        {
          type = "direct",
          action_delivery = {
            type = "instant",
            target_effects = {
              {
                type = "play-sound",
                sound = {
                  { filename = "__base__/sound/fight/throw-projectile-1.ogg", volume = 0.4 },
                  { filename = "__base__/sound/fight/throw-projectile-2.ogg", volume = 0.4 },
                  { filename = "__base__/sound/fight/throw-projectile-3.ogg", volume = 0.4 },
                  { filename = "__base__/sound/fight/throw-projectile-4.ogg", volume = 0.4 },
                  { filename = "__base__/sound/fight/throw-projectile-5.ogg", volume = 0.4 },
                  { filename = "__base__/sound/fight/throw-projectile-6.ogg", volume = 0.4 }
                }
              }
            }
          }
        }
      },
      category = "capsule",
      target_type = "position"
    },
    cooldown = lurecapsule_cooldown,
    projectile_creation_distance = 0.6,
    range = lurecapsule_range,
    type = "projectile"
  },
  type = "throw"
}
item.icon            = gpath .. "icons/lure-capsule.png"
item.subgroup        = subgroup_name

recipe               = {
  type = "recipe",
  name = name,
  icon = item.icon,
  icon_size = 64,
  energy_required = 1,
  result = name,
  enabled = true,
  ingredients = {
    { "iron-plate", 1 },
    { "wood",       5 }
  },
  order = "stealth-[lure-capsule]"
}

local projectile     = table.deepcopy(data.raw["projectile"]["poison-capsule"])
projectile.name      = name
projectile.action    = {
  {
    action_delivery = {
      target_effects = {
        {
          type = "create-entity",
          entity_name = pfx .. "lure",
          show_in_tooltip = true,
          trigger_created_entity = true
        }
      },
      type = "instant"
    },
    type = "direct"
  }
}
projectile.animation = {
  animation_speed = 0.25,
  draw_as_glow = true,
  filename = gpath .. "entity/lure-capsule/lure-capsule.png",
  frame_count = 16,
  height = 29,
  hr_version = {
    animation_speed = 0.25,
    draw_as_glow = true,
    filename = gpath .. "entity/lure-capsule/hr-lure-capsule.png",
    frame_count = 16,
    height = 59,
    line_length = 8,
    priority = "high",
    scale = 0.5,
    shift = { 0.03125, 0.015625 },
    width = 58
  },
  line_length = 8,
  priority = "high",
  shift = { 0.03125, 0.015625 },
  width = 29
}
projectile.shadow    = {
  animation_speed = 0.25,
  draw_as_shadow = true,
  filename = gpath .. "entity/lure-capsule/lure-capsule-shadow.png",
  frame_count = 16,
  height = 21,
  hr_version = {
    animation_speed = 0.25,
    draw_as_shadow = true,
    filename = gpath .. "entity/lure-capsule/hr-lure-capsule-shadow.png",
    frame_count = 16,
    height = 42,
    line_length = 8,
    priority = "high",
    scale = 0.5,
    shift = { 0.03125, 0.0625 },
    width = 54
  },
  line_length = 8,
  priority = "high",
  shift = { 0.03125, 0.0625 },
  width = 27
}

projectile.smoke     = nil

name                 = pfx .. "lure"
local lure           = table.deepcopy(data.raw["character"]["character"])
lure.name            = name
lure.max_health      = 200

data:extend { item, recipe, projectile, lure }
