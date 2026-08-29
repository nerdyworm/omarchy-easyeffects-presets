# EasyEffects Presets for Omarchy

A small Omarchy bar widget for switching between your EasyEffects output presets.

The widget reads presets from EasyEffects, shows the active preset in the bar, and verifies changes against the running EasyEffects process so the displayed state stays accurate.

![EasyEffects Presets widget open in the Omarchy bar](assets/easyeffects-presets.png)

## Features

- Left-click to open a searchable-style preset panel
- Right-click to cycle through presets
- Keyboard navigation inside the panel
- Live active-preset detection
- Friendly labels derived from preset filenames
- Protection against EasyEffects autoload rules immediately reverting a manual selection

## Requirements

- [Omarchy](https://omarchy.org/) with shell plugin support
- [EasyEffects](https://github.com/wwmm/easyeffects)
- At least one saved EasyEffects output preset
- `jq` (included with Omarchy)

## Install

```bash
omarchy plugin add https://github.com/nerdyworm/omarchy-easyeffects-presets.git --enable
```

If the widget does not appear immediately, restart the shell:

```bash
omarchy restart shell
```

## Usage

- Left-click the bar widget to open the preset list.
- Right-click the widget to switch to the next preset.
- Use the arrow keys and Enter in the panel to select a preset.
- Press `R` in the panel to refresh the preset list.

The widget discovers output presets in:

```text
~/.local/share/easyeffects/output
```

## EasyEffects autoload rules

An EasyEffects autoload rule can immediately restore a different preset after a manual switch. When this widget finds an autoload rule for the current output device, it moves that rule to:

```text
~/.local/state/omarchy/easyeffects-presets/autoload-disabled
```

The rule is preserved rather than deleted. To restore it, move the JSON file back to:

```text
~/.local/share/easyeffects/autoload/output
```

## Development

Validate the plugin with:

```bash
omarchy plugin validate .
qmllint -I /usr/share/omarchy/shell BarWidget.qml
```

## License

[MIT](LICENSE)
