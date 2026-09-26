-- Personal key mappings, merged into AstroCore's options.

---@type LazySpec
return {
  "AstroNvim/astrocore",
  ---@type AstroCoreOpts
  opts = {
    mappings = {
      -- Deleting a character with `x` should not overwrite the clipboard,
      -- so send it to the black hole register instead.
      n = {
        ["x"] = { '"_x', desc = "Delete character without yanking" },
      },
      x = {
        ["x"] = { '"_x', desc = "Delete selection without yanking" },
      },
    },
  },
}
