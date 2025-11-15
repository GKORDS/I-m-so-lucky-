name = "Winona Infinite Catapult Remote"
description = [[
Winona's Handy remote gains effectively global range (configurable) so she can command her inventions from anywhere.
Winona's Catapults acquire targets and fire across the map (configurable) without altering their damage or attack speed.
]]
author = "ChatGPT"
version = "1.0.0"
forumthread = ""
api_version = 10

dst_compatible = true
all_clients_require_mod = false
client_only_mod = false

configuration_options = {
    {
        name = "REMOTE_RANGE_MODE",
        label = "Remote Range Mode",
        options = {
            { description = "Infinite", data = "infinite" },
            { description = "Multiplier", data = "multiplier" },
        },
        default = "infinite",
    },
    {
        name = "REMOTE_RANGE_MULTIPLIER",
        label = "Remote Range Multiplier",
        options = {
            { description = "x10", data = 10 },
            { description = "x25", data = 25 },
            { description = "x50", data = 50 },
            { description = "x75", data = 75 },
            { description = "x100", data = 100 },
            { description = "x150", data = 150 },
            { description = "x200", data = 200 },
            { description = "x300", data = 300 },
            { description = "x500", data = 500 },
            { description = "x1000", data = 1000 },
        },
        default = 100,
    },
    {
        name = "CATAPULT_RANGE_MODE",
        label = "Catapult Range Mode",
        options = {
            { description = "Infinite", data = "infinite" },
            { description = "Multiplier", data = "multiplier" },
        },
        default = "infinite",
    },
    {
        name = "CATAPULT_RANGE_MULTIPLIER",
        label = "Catapult Range Multiplier",
        options = {
            { description = "x10", data = 10 },
            { description = "x25", data = 25 },
            { description = "x50", data = 50 },
            { description = "x75", data = 75 },
            { description = "x100", data = 100 },
            { description = "x150", data = 150 },
            { description = "x200", data = 200 },
            { description = "x300", data = 300 },
            { description = "x500", data = 500 },
            { description = "x1000", data = 1000 },
        },
        default = 100,
    },
}
