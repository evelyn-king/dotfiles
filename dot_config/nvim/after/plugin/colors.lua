vim.o.background = "dark" -- or "light" for light mode
function ColorTheScreen(color)
    color = color or "catppuccin-mocha"
    vim.cmd.colorscheme(color)
end

ColorTheScreen()

