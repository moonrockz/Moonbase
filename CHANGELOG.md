# Changelog

All notable changes to `moonrockz/mission-control` are listed here, newest first.
Versions follow [Semantic Versioning](https://semver.org); while the version
is 0.x, a minor release can contain breaking changes.

<!-- git-cliff: end of header -->

## [0.0.2] - 2026-10-22

<!-- Highlights: replace this comment with a few sentences on what this release brings. -->

### 🚜 Refactoring

- Rename Moonbase to Mission Control ([#6](https://github.com/moonrockz/mission-control/pull/6)) by @DamianReeves

### 🏗️ Build and CI

- Remove the notebooks module, which moon-lander publishes ([#7](https://github.com/moonrockz/mission-control/pull/7)) by @DamianReeves

**Full changelog**: https://github.com/moonrockz/mission-control/compare/v0.0.1...v0.0.2

## [0.0.1] - 2026-10-19

Moonbase's first release publishes immutable Markdown documents and EARS
requirements alongside the shared contracts, CLI, web UI and desktop shell.
The independent `moonrockz/notebooks` module adds Jupyter and .NET Interactive
DIB models, format-specific inspection, and shared cursors, traversal and
immutable metadata. Jupyter support covers notebook schema 4.0 through 4.5,
including the format used by Python nbformat 5.11. Checked usage guides and
public API comments accompany the notebook packages.

### 🚀 Features

- Scaffold the Moonbase monorepo by @DamianReeves
- *(mdc)* Add immutable Markdown documents ([#1](https://github.com/moonrockz/Moonbase/pull/1)) by @DamianReeves
- *(mdc)* Add cursors and bottom-up reduction ([#2](https://github.com/moonrockz/Moonbase/pull/2)) by @DamianReeves
- *(ears)* Parse text and Markdown specifications ([#3](https://github.com/moonrockz/Moonbase/pull/3)) by @DamianReeves
- *(notebooks)* Add Jupyter and DIB notebook APIs ([#4](https://github.com/moonrockz/Moonbase/pull/4)) by @DamianReeves
