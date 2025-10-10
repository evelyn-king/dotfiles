-- Wezterm config - Evelyn King

local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- Terminal colors
function get_appearance()
  if wezterm.gui then
    return wezterm.gui.get_appearance()
  end
  return 'Dark'
end

function scheme_for_appearance(appearance)
  if appearance:find 'Dark' then
    return 'Catppuccin Mocha'
  else
    return 'Catppuccin Latte'
  end
end
config.color_scheme = scheme_for_appearance(get_appearance())

-- Terminal fonts
config.font = wezterm.font_with_fallback(
    {
        family = 'Cascadia Code',
        weight = 'Regular',
        stretch = 'Normal',
        style = 'Normal'
    },
    {
        family = 'CaskaydiaCove Nerd Font',
        weight = 'Regular',
        stretch = 'Normal',
        style = 'Normal'
    },
    { family = 'Fira Code' },
    { family = 'JetBrains Mono' }
)
config.font_size = 13.0

return config
