-- Pull in the wezterm API
local wezterm = require 'wezterm'
-- This will hold the configuration.
local config = wezterm.config_builder()

-- Actual config
config.color_scheme = 'Nord (Gogh)'
config.font = wezterm.font("CaskaydiaCove Nerd Font", {weight="Regular", stretch="Normal", style="Normal"})
config.font_size = 13.0
-- return the configuration to wezterm
return config
