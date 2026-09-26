# Base16 Color Palette Reference

## What this is for

When Stylix generates a color scheme from your wallpaper, it maps every color to one of 16 named slots. You reference these slot names when you need a specific color in a custom config — a manual theme override, a bar widget script, or anything that isn't automatically themed by Stylix.

See the [Theme System section in the README](../README.md#theming-stylix) for how Stylix generates the palette and applies it.

---

## The 16 slots

Base16 splits into two groups: **base00–base07** are background and foreground shades (dark to light for dark themes), and **base08–base0F** are accent colors for syntax highlighting and UI accents.

| Slot   | Typical Color  | Intended Use |
|--------|----------------|--------------|
| base00 | Dark           | Default background |
| base01 | Slightly lighter | Status bars, line numbers, folding marks |
| base02 | Lighter still  | Selection background |
| base03 | Mid-dark       | Comments, invisible characters, line highlighting |
| base04 | Mid            | Dark foreground — used for status bars |
| base05 | Light          | Default foreground, caret, delimiters, operators |
| base06 | Lighter        | Light foreground (rarely used) |
| base07 | Lightest       | Light background (rarely used) |
| base08 | Red            | Variables, XML tags, markup link text, diff deleted |
| base09 | Orange         | Integers, booleans, constants, XML attributes, link URLs |
| base0A | Yellow         | Classes, markup bold, search highlight background |
| base0B | Green          | Strings, inherited class, markup code, diff inserted |
| base0C | Cyan           | Support, regular expressions, escape characters, markup quotes |
| base0D | Blue           | Functions, methods, attribute IDs, headings |
| base0E | Magenta        | Keywords, storage, selector, markup italic, diff changed |
| base0F | Brown/Dark Red | Deprecated, opening/closing embedded language tags |

For a dark theme: base00 is darkest, base07 is lightest. For a light theme, they flip.

---

## How to use a slot in practice

### In a Nix config (via Stylix config object)

Stylix exposes the current palette through `config.lib.stylix.colors` (hex
values without the `#`). This repo uses it wherever Stylix has no target,
for example the i3status colours in `desktops/i3/i3status.nix`:

```nix
{config, ...}: let
  c = config.lib.stylix.colors;
in {
  programs.i3status.general = {
    color_good = "#${c.base0B}"; # green
    color_degraded = "#${c.base0A}"; # yellow
    color_bad = "#${c.base08}"; # red
  };
}
```

`desktops/i3/dmenu.nix`, `desktops/i3/i3.nix` (the bar) and
`utilities/ghostty.nix` (the ANSI palette) do the same.

### Outside Nix

Stylix writes the generated palette to `~/.config/stylix/palette.json`, and
`~/.config/stylix/palette.html` shows it as swatches in a browser:

```bash
jq -r .base0D ~/.config/stylix/palette.json # blue accent, e.g. 7aa2f7
xdg-open ~/.config/stylix/palette.html
```

### Previewing base16 schemes

```bash
base16-shell-preview
```

Installed from `common-packages.nix`: browses the stock base16 schemes in the
terminal, which is handy for picking a fixed `stylix.base16Scheme` instead of
generating one from the wallpaper.

---

## Sources

- [Base16 Styling Guidelines](https://github.com/chriskempson/base16/blob/main/styling.md) — original spec
- [tinted-theming/base16-schemes](https://github.com/tinted-theming/base16-schemes) — maintained scheme collection
- [Base16 Colorscheme Previews](https://tinted-theming.github.io/tinted-gallery/) — visual gallery
