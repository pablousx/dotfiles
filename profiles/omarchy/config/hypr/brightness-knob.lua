-- Replace Omarchy's focused-display 5% controls with 10% changes on every
-- active display. The macropad emits the standard XF86 brightness keys.
local function dotfiles_shell_quote(value)
    return "'" .. value:gsub("'", [=['"'"']=]) .. "'"
end

local dotfiles_brightness_helper = dotfiles_shell_quote(
    (os.getenv("HOME") or "") .. "/.local/bin/omarchy-brightness-all"
)

hl.unbind("XF86MonBrightnessDown")
hl.unbind("XF86MonBrightnessUp")
o.bind(
    "XF86MonBrightnessDown",
    "Brightness down on all displays",
    dotfiles_brightness_helper .. " 10%-",
    { locked = true, repeating = true }
)
o.bind(
    "XF86MonBrightnessUp",
    "Brightness up on all displays",
    dotfiles_brightness_helper .. " +10%",
    { locked = true, repeating = true }
)
