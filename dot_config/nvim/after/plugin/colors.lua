vim.o.background = "dark" -- or "light" for light mode
function ColorTheScreen(color)
    color = color or "gruvbox"
    vim.cmd.colorscheme(color)
end

ColorTheScreen()

