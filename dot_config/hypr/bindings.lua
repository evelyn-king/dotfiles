-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- Web apps: prefer Google/Anthropic services over Omarchy's Hey/Grok defaults.
hl.unbind("SUPER + SHIFT + ALT + A")
o.bind("SUPER + SHIFT + ALT + A", "Claude", { webapp = "https://claude.ai/new" })

hl.unbind("SUPER + SHIFT + C")
o.bind("SUPER + SHIFT + C", "Calendar", { webapp = "https://calendar.google.com/calendar/u/0/r?pli=1" })

hl.unbind("SUPER + SHIFT + E")
o.bind("SUPER + SHIFT + E", "Email", { webapp = "https://mail.google.com/mail/u/0/#inbox" })

hl.unbind("SUPER + SHIFT + ALT + E")
o.bind("SUPER + SHIFT + ALT + E", "New email", { webapp = "https://mail.google.com/mail/u/0/#compose=new" })

-- Slack instead of the default WhatsApp.
hl.unbind("SUPER + SHIFT + ALT + G")
o.bind("SUPER + SHIFT + ALT + G", "Slack", { launch = "gtk-launch slack", focus = "^slack$" })

-- Second password manager alongside the default 1Password on SUPER + SHIFT + SLASH.
o.bind("SUPER + SHIFT + ALT + SLASH", "Bitwarden", { launch = "bitwarden-desktop" })

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")
