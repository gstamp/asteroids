# Asteroids

Asteroids clone built with Zig 0.15.1 and `raylib-zig`.

## Features

- Fullscreen desktop play on Windows
- `Escape` exits immediately
- Vector-style line rendering with fullscreen bloom/glow
- Custom stroke font rendered from line segments
- Procedural particle effects for thrust, impacts, and explosions
- Procedurally synthesized arcade-style sound effects
- Periodic gravity rifts that bend trajectories and consume anything pulled into their core
- Classic-style Asteroids rules:
  - inertia and thrust-based ship movement
  - asteroid splitting
  - saucer spawns and hostile fire
  - hyperspace
  - score, lives, waves, and extra lives

## Controls

- `Left` / `A`: Rotate left
- `Right` / `D`: Rotate right
- `Up` / `W`: Thrust
- `Space`: Fire
- `Left Shift` / `Right Shift`: Hyperspace
- `Enter`: Start / restart
- `Escape`: Exit

## Requirements

- Zig `0.15.1`

The current machine was bootstrapped with:

```bat
winget install --id zig.zig --version 0.15.1 --accept-package-agreements --accept-source-agreements
```

## Run

```bat
zig build run
```

## Test

```bat
zig build test
```

## Release Build

Build a portable executable folder:

```bat
zig build -Doptimize=ReleaseFast
```

The executable is written to:

```text
zig-out/bin/asteroids.exe
```

That output is self-contained for normal desktop sharing.
