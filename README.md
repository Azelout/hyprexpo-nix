# HyprExpo

HyprExpo is a maintained Hyprland plugin for expose-style workspace overview with keyboard selection, drag-drop window movement, labels, configurable gaps and borders, multi-monitor placement, and Lua gestures.

If you experience any bugs, you are encouraged to [open an issue](https://github.com/sandwichfarm/hyprexpo/issues/new). Information I can use to reproduce a bug is appreciated. 

[Docs (markdown)](docs/index.md) - [Docs (website)](http://hyprexpo.lol/docs) - [Announcement Post](https://www.reddit.com/r/hyprland/comments/1o30dsg/hyprexpoplus_outer_gaps_keyboard_navigation_and/)

## History

HyprExpo continues the original expose-style workspace overview plugin from the Hyprland plugins ecosystem. After [the upstream plugin was retired](https://github.com/hyprwm/hyprland-plugins/pull/507#issuecomment-4433386463) from official plugins, this fork signaled contiuation and intends to chase Hyprland releases.

Born from [a PR to the old official HyprExpo](https://github.com/hyprwm/hyprland-plugins/pull/507) and formerly known as HyperExpo+ (`hyprexpo-plus`), has become the home for practical additions that made the
overview more usable day to day: keyboard navigation, visible workspace labels, configurable gaps and borders, multi-monitor placement, and Lua gesture setup.
See the [upstream retirement context](https://github.com/hyprwm/hyprland-plugins/pull/663)
and the [original launch announcement of this plugin](https://www.reddit.com/r/hyprland/comments/1o30dsg/hyprexpoplus_outer_gaps_keyboard_navigation_and/)
for the project's well established background.

## Related

- https://github.com/colonelpanic8/hyprexpo - Another HyprExpo fork 

____

## Install

### hyprpm

```bash
hyprpm add https://github.com/sandwichfarm/hyprexpo
hyprpm enable hyprexpo
hyprpm reload
```

The repository name in `hyprpm.toml` is `hyprexpo`, and the built plugin output is `hyprexpo.so`.

### Build From Source

Install a C++23 compiler, `pkg-config`, Hyprland development headers, and these pkg-config packages:

```text
hyprland pixman-1 libdrm pangocairo libinput libudev wayland-server xkbcommon lua5.4
```

The build prefers the `lua5.4` pkg-config module and falls back to `lua` for
distributions such as Fedora where `lua-devel` exposes the generic module name.

Build with the Makefile:

```bash
git clone https://github.com/sandwichfarm/hyprexpo
cd hyprexpo
make all
```

Install the local build over the hyprpm-managed copy:

```bash
make install
hyprpm reload
```

Use `install` or `make install`, not plain `cp`, when replacing a loaded `.so`. Hyprland maps plugin files into the running process, and overwriting that file in place can corrupt the live mapping.

Other build entry points:

```bash
meson setup build
meson compile -C build
```

```bash
cmake -S . -B build
cmake --build build
```

### NixOS + home-manager

This section explains how to install and configure a Hyprland plugin declaratively using NixOS, Home Manager, and Nix flakes.

> **Prerequisites**: NixOS with flakes enabled, Home Manager set up as a NixOS module.

---

#### Overview

On NixOS, plugins are **not** installed with `hyprpm` (the standard Hyprland plugin manager). Instead, they are declared in your Nix configuration and automatically compiled and loaded when you rebuild your system. This approach is fully reproducible — no manual steps required after the initial setup.

The process has 4 steps:
1. Add the plugin's flake as an input in `flake.nix`
2. Pass it to Home Manager
3. Declare it in `home.nix`
4. Add a keybind in `hyprland.lua`

---

#### Step 1 — Add the plugin flake in `flake.nix`

A flake is a Nix file that packages software in a reproducible way. Most community Hyprland plugins are distributed as flakes on GitHub.

Open your `flake.nix` and add the plugin under `inputs`, alongside your other dependencies:

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  home-manager = {
    url = "github:nix-community/home-manager/release-26.05";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  hyprland = {
    type = "git";
    url = "https://github.com/hyprwm/Hyprland";
    submodules = true;
    inputs.nixpkgs.follows = "nixpkgs";
  };

  # ↓ Add this block for your plugin
  hyprexpo-nix = {
    url = "github:Azelout/hyprexpo-nix";
    inputs.hyprland.follows = "hyprland"; # IMPORTANT: must match your Hyprland version
  };
};
```

> **Why `inputs.hyprland.follows = "hyprland"`?**
> Hyprland plugins are compiled against a specific version of Hyprland. If the plugin uses a different version than your system, the build will fail with a cryptic header error. This line forces the plugin to use the exact same Hyprland version as the rest of your system.

Then, still in `flake.nix`, pass `hyprexpo-nix` to Home Manager via `extraSpecialArgs` so it becomes available in `home.nix`:

```nix
outputs = { nixpkgs, home-manager, hyprland, hyprexpo-nix, ... }: {
  nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      ./configuration.nix
      home-manager.nixosModules.home-manager
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;

        # ↓ This makes hyprexpo-nix available in home.nix
        home-manager.extraSpecialArgs = { inherit hyprexpo-nix; };
        home-manager.users.YOUR_USERNAME = import ./home.nix;
      }
    ];
  };
};
```

---

#### Step 2 — Declare the plugin in `home.nix`

Open your `home.nix` and make sure the function signature accepts `hyprexpo-nix` as an argument. Then add it to the `plugins` list:

```nix
# home.nix
{ pkgs, hyprexpo-nix, ... }: {  # ← hyprexpo-nix must be listed here

  wayland.windowManager.hyprland = {
    enable = true;

    # Your existing Lua config is imported from a separate file
    extraConfig = builtins.readFile ./hyprland.lua;

    # Declare the plugin here — Home Manager compiles and loads it automatically
    plugins = [
      hyprexpo-nix.packages.${pkgs.system}.hyprexpo
    ];
  };

}
```

> **How do I know the package name inside a flake?**
> Run this command to list all packages a flake exposes:
> ```bash
> nix flake show github:Azelout/hyprexpo-nix --no-write-lock-file
> ```
> Look for lines under `packages.x86_64-linux`. The name after the last dot (e.g., `hyprexpo`) is what you use.

---

#### Step 3 — Add a keybind in `hyprland.lua`

Since Hyprland 0.55, the config file is written in Lua. Add the following to your `hyprland.lua` to bind the plugin to a key:

```lua
-- Toggle the workspace overview with Super + Tab
hl.bind("SUPER", "tab", hl.dsp.custom("hyprexpo:expo", "toggle"))

-- Optional: customize the plugin's appearance
hl.config.set("plugin:hyprexpo:columns", "3")           -- number of columns in the grid
hl.config.set("plugin:hyprexpo:gap_size", "5")           -- gap between workspaces
hl.config.set("plugin:hyprexpo:bg_col", "rgb(111,111,111)") -- background color
hl.config.set("plugin:hyprexpo:workspace_method", "center current") -- center on current workspace
```

---

#### Step 4 — Apply and verify

Rebuild your system to apply the changes:

```bash
sudo nixos-rebuild switch
```

Then **fully restart your Hyprland session** — plugins are loaded when Hyprland starts, not when the config reloads. Logging out and back in (or switching to a TTY and running `loginctl terminate-session $XDG_SESSION_ID`) is required.

After restarting, verify the plugin is loaded:

```bash
hyprctl plugin list
```

You should see your plugin listed with its name, version, and handle. If the list is empty, the session was not fully restarted.

---

#### Troubleshooting

| Problem | Likely cause | Fix |
|---|---|---|
| `no plugins loaded` after rebuild | Session was not fully restarted | Log out and log back in — `hyprctl reload` is not enough |
| Build error: `No such file or directory` (e.g. `LayoutManager.hpp`) | Version mismatch between the plugin and Hyprland | Make sure `inputs.hyprland.follows = "hyprland"` is set in the plugin input |
| `Existing file would be clobbered` | A manually created `hyprland.lua` conflicts with Home Manager | Delete it first: `rm ~/.config/hypr/hyprland.lua`, then rebuild |
| `cannot write modified lock file` when running `nix flake show` | No write permission in the current directory | Add the `--no-write-lock-file` flag to the command |
| `attribute 'hyprexpo-nix' missing` in `home.nix` | The argument is not passed via `extraSpecialArgs` | Add `inherit hyprexpo-nix` to `home-manager.extraSpecialArgs` in `flake.nix` |


## Quick Config

Add the plugin block to your Hyprland config:

```ini
plugin {
    hyprexpo {
        columns = 3
        gaps_in = 5
        gaps_out = 0
        bg_col = rgb(111111)
        workspace_method = center current
        gesture_distance = 200
        cancel_key = escape
        show_cursor = 1
        show_pinned_windows = 0
    }
}
```

For `hyprland.lua`, use `hl.config()`:

```lua
hl.config({
    plugin = {
        hyprexpo = {
            columns = 3,
            gaps_in = 5,
            gaps_out = 0,
            bg_col = "rgb(111111)",
            workspace_method = "center current",
            gesture_distance = 200,
            cancel_key = "escape",
            show_cursor = 1,
        },
    },
})
```

Add a dispatcher binding:

```ini
bind = SUPER, g, hyprexpo:expo, toggle
```

Or in Lua:

```lua
hl.bind("SUPER + G", function()
    hl.plugin.hyprexpo.expo("toggle")
end)
```

Optional keyboard navigation:

```ini
plugin {
    hyprexpo {
        keynav_enable = 1
        keynav_wrap_h = 1
        keynav_wrap_v = 1
        keynav_reading_order = 0
    }
}

submap = hyprexpo
    bind = , left,   hyprexpo:kb_focus, left
    bind = , right,  hyprexpo:kb_focus, right
    bind = , up,     hyprexpo:kb_focus, up
    bind = , down,   hyprexpo:kb_focus, down
    bind = , return, hyprexpo:kb_confirm
    bind = , escape, hyprexpo:expo, cancel
    bind = , 1,      hyprexpo:kb_selecti, 1
    bind = , 2,      hyprexpo:kb_selecti, 2
    bind = , 3,      hyprexpo:kb_selecti, 3
    bind = , 4,      hyprexpo:kb_selecti, 4
    bind = , 5,      hyprexpo:kb_selecti, 5
    bind = , 6,      hyprexpo:kb_selecti, 6
    bind = , 7,      hyprexpo:kb_selecti, 7
    bind = , 8,      hyprexpo:kb_selecti, 8
    bind = , 9,      hyprexpo:kb_selecti, 9
    bind = , 0,      hyprexpo:kb_selecti, 10
submap = reset
```

For `hyprland.lua`, define the same active submap in Lua instead of adding a
`submap = hyprexpo` block to `hyprland.conf`:

```lua
hl.define_submap("hyprexpo", function()
    hl.bind("h",      function() hl.plugin.hyprexpo.kb_focus("left") end)
    hl.bind("l",      function() hl.plugin.hyprexpo.kb_focus("right") end)
    hl.bind("k",      function() hl.plugin.hyprexpo.kb_focus("up") end)
    hl.bind("j",      function() hl.plugin.hyprexpo.kb_focus("down") end)
    hl.bind("return", function() hl.plugin.hyprexpo.kb_confirm() end)
    hl.bind("escape", function() hl.plugin.hyprexpo.expo("cancel") end)
end)
```

## Next Steps

- [Installation details](https://hyprexpo.lol/docs/getting-started/installation/)
- [Quick start](https://hyprexpo.lol/docs/getting-started/quick-start/)
- [All configuration options](https://hyprexpo.lol/docs/configuration/options/)
- [Labels and borders](https://hyprexpo.lol/docs/configuration/labels-borders/)
- [Keyboard navigation](https://hyprexpo.lol/docs/configuration/keyboard/)
- [Lua gestures](https://hyprexpo.lol/docs/guides/lua-gestures/)
- [Multi-monitor placement](https://hyprexpo.lol/docs/guides/multi-monitor/)
- [Migration from old keyword config](https://hyprexpo.lol/docs/guides/migration/)
- [Runtime smoke checklist](https://hyprexpo.lol/docs/guides/runtime-smoke/)
- [Compatibility and release provenance](https://hyprexpo.lol/docs/reference/compatibility/)
- [Dispatcher reference](https://hyprexpo.lol/docs/reference/dispatchers/)
- [Troubleshooting](https://hyprexpo.lol/docs/troubleshooting/)
