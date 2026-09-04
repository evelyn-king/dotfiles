-- Change the default Omarchy look'n'feel.

-- https://wiki.hypr.land/Configuring/Basics/Variables/#decoration
hl.config({
  decoration = {
    -- Use round window corners (Omarchy default: 0).
    rounding = 8,
  },
})

-- https://wiki.hypr.land/Configuring/Basics/Variables/#layout
local golden_ratio = (1 + math.sqrt(5)) / 2

local function monitor_is_wider_than_golden_ratio(monitor)
  if not monitor.enabled or monitor.height <= 0 then
    return false
  end

  local width = monitor.width
  local height = monitor.height

  -- Hyprland reports the untransformed mode dimensions.
  if monitor.transform % 2 == 1 then
    width, height = height, width
  end

  return width > height * golden_ratio
end

local function update_single_window_aspect_ratio()
  local ratio = { 0, 0 }

  for _, monitor in ipairs(hl.get_monitors()) do
    if monitor_is_wider_than_golden_ratio(monitor) then
      ratio = { golden_ratio, 1 }
      break
    end
  end

  hl.config({
    layout = {
      single_window_aspect_ratio = ratio,
    },
  })
end

update_single_window_aspect_ratio()
hl.on("hyprland.start", update_single_window_aspect_ratio)
hl.on("config.reloaded", update_single_window_aspect_ratio)
hl.on("monitor.added", update_single_window_aspect_ratio)
hl.on("monitor.removed", update_single_window_aspect_ratio)

-- https://wiki.hypr.land/Configuring/Basics/Variables/#general
-- hl.config({
--   general = {
--     -- No gaps between windows or borders.
--     gaps_in = 0,
--     gaps_out = 0,
--     border_size = 0,
--
--     -- Change to niri-like side-scrolling layout.
--     layout = "scrolling",
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#animations
-- hl.config({
--   animations = {
--     -- Disable all animations.
--     enabled = false,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/
-- hl.config({
--   scrolling = {
--     -- See only one column per screen instead of two.
--     column_width = 0.97,
--   },
-- })
