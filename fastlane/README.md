fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

Capture screenshots for App Store

### ios screenshots_all

```sh
[bundle exec] fastlane ios screenshots_all
```

Capture screenshots for all device sizes

### ios screenshots_quick

```sh
[bundle exec] fastlane ios screenshots_quick
```

Quick screenshot test (single device)

### ios test

```sh
[bundle exec] fastlane ios test
```

Run all unit tests

### ios test_ui

```sh
[bundle exec] fastlane ios test_ui
```

Run UI tests only

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Push a new beta build to TestFlight

### ios release

```sh
[bundle exec] fastlane ios release
```

Deploy a new version to the App Store

### ios bump_version

```sh
[bundle exec] fastlane ios bump_version
```

Increment version number

### ios bump_build

```sh
[bundle exec] fastlane ios bump_build
```

Set the build number on the shipping targets (app, widget, clip)

Usage: fastlane bump_build number:13

### ios sync_certs

```sh
[bundle exec] fastlane ios sync_certs
```

Sync certificates and provisioning profiles

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
