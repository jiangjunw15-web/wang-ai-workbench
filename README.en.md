# Wang AI Workbench

An open-source kit that turns the **AutoGPT Platform** into a personal/team AI
workbench: a native Windows desktop client, local LLM-gateway integration,
owner consoles, and one-command deployment scripts.

It is **not a fork of AutoGPT**. The official single-container image is left
untouched; every customization is layered on top as build-artifact patches,
side services, and a desktop shell, so you can follow upstream upgrades.

## Features

- **Desktop client** (WPF + WebView2): borderless native window, custom title
  bar, system tray, back/forward/reload, auto-start, one-click service launch.
- **LLM gateway integration**: register any OpenAI-compatible gateway (Magpie,
  one-api, new-api, ...) as an AutoGPT provider; its models appear in every AI
  block's model picker.
- **Owner consoles** the platform doesn't ship:
  - `AI ordering` – reorder model priority and assign models per team role;
  - `Gateway status` – connectivity, model inventory, per-model live probe.
- **UI customization**: Chinese UI, custom logo/wordmark, theme colors,
  removal of paywall/telemetry surfaces.
- **AI team workflow**: one instruction fans out across roles
  (PM → planner → writer → editor) to produce a finished deliverable.

## Layout

```
desktop/   Windows desktop client + installer + port relay (relay.js)
console/   Owner consoles (dependency-free Python HTTP service)
platform/  AutoGPT bootstrap + LLM-gateway patch + nginx routing
brand/     Brand assets + front-end customization patches
docs/      Install / architecture / customize / security notes
```

## Quick start

Requirements: Windows 10/11 x64, WSL2 enabled, Docker, Microsoft Edge WebView2
Runtime, Node.js (only for the port relay).

1. Deploy the platform (runs the AutoGPT single container in WSL and wires it
   to your gateway): `bash platform/bootstrap.sh`
2. Optional front-end customization: see `docs/CUSTOMIZE.md`.
3. Install the desktop client: see `docs/INSTALL.md`.
4. Open the desktop app or visit `http://localhost:3000`.

## Configuration

All site-specific values come from environment variables or side-car config
files; no machine paths are hardcoded. See the Chinese README for the table.

## License

MIT — see [LICENSE](LICENSE). AutoGPT itself remains under its own license;
this project does not redistribute or modify its source.
