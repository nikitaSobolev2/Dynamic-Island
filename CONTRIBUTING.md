<p align="center">
	<img src=".github/assets/atoll-logo.png" alt="Atoll logo" width="100">
</p>

# Contributing to Atoll

Thank you for your interest in contributing to Atoll! We welcome contributions from everyone—developers, designers, testers, and documentation writers. Please read the following guidelines to help us maintain a collaborative and high-quality project.

## Table of Contents
- [How to Contribute](#how-to-contribute)
- [Code of Conduct](#code-of-conduct)
- [Development Setup](#development-setup)
- [Pull Request Process](#pull-request-process)
- [Coding Guidelines](#coding-guidelines)
- [Design Contributions](#design-contributions)
- [Documentation](#documentation)
- [Releasing](#releasing)
- [Code Review process](#code-review-process)


---

## How to Contribute

1. **Fork the repository** and clone your fork locally.
2. **Create a feature branch** for your changes: `git switch -c feature/your-feature-name`
3. **Make your changes** following the guidelines below.
4. **Test your changes** to ensure they work as expected and do not break existing functionality.
5. **Commit** with clear, descriptive messages.
6. **Push** to your fork and submit a **pull request** (PR) to the `main` branch.
7. **Participate in code review** and address any feedback.

## Code of Conduct

We are committed to fostering a welcoming and inclusive environment. Please read our [Code of Conduct](CODE_OF_CONDUCT.md) before participating.

## Development Setup

- **Requirements:**
	- macOS Sonoma 14.0 or later
	- Xcode 15.0+ with Swift 5.9 toolchain
	- MacBook with a notch (for full feature testing)
- **Clone the repo:**
	```bash
	git clone https://github.com/nikitaSobolev2/Dynamic-Island.git
	cd Dynamic-Island
	open DynamicIsland.xcodeproj
	```
- **Build & Run:**
	- Select your Mac as the run destination in Xcode.
	- Build and run (Cmd+R).
	- Grant any requested permissions.

## Pull Request Process

- Ensure your branch is up to date with `main` before submitting a PR.
- Provide a clear description of your changes and the motivation behind them.
- Reference any related issues or discussions.
- Add screenshots or screen recordings for UI changes.
- Ensure the code builds without errors or warnings.
- Respond promptly to review feedback.

## Coding Guidelines

- Follow Swift API Design Guidelines.
- Use meaningful variable and function names.
- Keep functions focused and concise.
- Add inline documentation for public APIs and complex logic.
- Write unit tests for new features where practical.
- Avoid introducing unnecessary dependencies.

## Design Contributions

- Submit UI/UX improvements, mockups, or visual assets.
- Maintain consistency with macOS Human Interface Guidelines.
- Provide rationale for design decisions.

## Documentation

- Improve user guides, API docs, and troubleshooting sections.
- Translate documentation into other languages.
- Clarify setup instructions and add usage examples.

## Releasing

Push a version tag to build and publish a GitHub Release. Sparkle and Homebrew then follow that release. Builds are not notarized.

```bash
git tag v2.2.0
git push origin v2.2.0
```

The app updates from the latest GitHub Release via `https://github.com/nikitaSobolev2/Dynamic-Island/releases/latest/download/appcast.xml`. There is no beta/nightly channel.

Repository secrets:

- `SPARKLE_ED_PRIVATE_KEY` (required) — EdDSA private key matching `SUPublicEDKey` in `DynamicIsland/Info.plist`. Never commit it.
- `DEVELOPER_ID_APPLICATION_P12` (optional, base64-encoded PKCS#12) and `DEVELOPER_ID_APPLICATION_P12_PASSWORD` — sign releases with Developer ID so Accessibility and related TCC grants survive Homebrew upgrades.

Without a Developer ID, CI uses an ad-hoc signature whose designated requirement is only the bundle identifier, which still keeps TCC grants across consecutive cask upgrades. Homebrew strips Gatekeeper quarantine in the cask `postflight`.

## Code review process
- All pull requests require review from project maintainers before merging.
- Automated testing must pass via continuous integration workflows.
- Changes should not significantly decrease test coverage without justification.
- Breaking changes require major version updates following semantic versioning.

---

Thank you for helping make Atoll better!
