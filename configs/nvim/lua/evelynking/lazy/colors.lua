return {
    {
        "catppuccin/nvim",
        name = "catppuccin",
        lazy = false,
        config = function()
            require("catppuccin").setup({
                flavour = "auto",
                background = { -- :h background
                    light = "latte",
                    dark = "mocha",
                },
                term_colors = true,
            })
        end
    },
}
