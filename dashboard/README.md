# Peras parameterization dashboard

### Building

You can build via Nix:

```console
nix build .#dashboard
```

Or inside the Nix shell (enter via `nix develop` or
[nix-direnv](https://github.com/nix-community/nix-direnv)) for a more
interactive experience:

```console
pnpm install    # Installs dependencies
pnpm run serve  # Compiles and hot-reloads for development
pnpm run build  # Compiles and minifies for production
pnpm run lint   # Lints files (use lint:fix to automatically apply fixes)
```
