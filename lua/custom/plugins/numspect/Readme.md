# Numspect

Number inspection plugin.
This plugin was originally developed to help convert between hex and IEC representations when 
designing memory layouts.

## Install

The plugin is entirely written in lua, it has no special dependencies.
To install using lazy

``` lua
  {
    dir = '<yourdirectory>',
    opts = {},
  }
```

## Configuration

``` lua
Default configuration
local options = {
  use_hover = true, -- If true the inspection is shown in a hovering window, otherwise only printed
  mappings = {
    ['?'] = 'trigger', -- The main (and only atm) action that shows the number inspection
  },
}
```

To edit the configuration pass a table to the `setup` function.
In lazy this can be done with the `opts` parameter.
The doesn't have to contain all parameters just the ones that you want to override.

## Usage

You can open a hovering window that displays the inspected number by pressing `?`.
The window automatically disappears when moving the cursor.
The number in the following formats:

 - as passed literally
 - as hex
 - as decimal
 - as iec size with unit (KiB, MiB etc., powers of 1024)

Eg.:
```
0x12000 becomes
 0x12000: 0x12000     73728     72.000KiB
```

By pressing `?` again you can enter the hovering window to copy parts of the inspection.
This way you can copy and paste different representations easily.
You can exit the window by pressing one of `<Esc> <CR> <leader> j k`.

By default the plugin parses the word the cursor is on.
You can also use it in visual mode `v` (but not in line visual mode `V`), and the selected text is passed to the plugin.
This way you can parse something like `1.1 MiB`, where both `.` and the space would break a word otherwise.
