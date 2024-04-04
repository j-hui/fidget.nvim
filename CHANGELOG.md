# Changelog

## [1.4.1](https://github.com/j-hui/fidget.nvim/compare/v1.4.0...v1.4.1) (2024-03-20)


### Bug Fixes

* **doc:** require Neovim v0.9.0+ (close [#225](https://github.com/j-hui/fidget.nvim/issues/225)) ([933db45](https://github.com/j-hui/fidget.nvim/commit/933db4596e4bab1b09b6d48a10e21819e4cc458f))
* **integration:** improved avoidance of Test Explorer (xcodebuild.nvim) ([#221](https://github.com/j-hui/fidget.nvim/issues/221)) ([910104a](https://github.com/j-hui/fidget.nvim/commit/910104a2d0a831ba8ac662cd23d3f1c685401cf6))
* **logger:** create log directory on initialization (fix [#226](https://github.com/j-hui/fidget.nvim/issues/226)) ([0d4b47b](https://github.com/j-hui/fidget.nvim/commit/0d4b47b31f3ad1ad944a8a3173f0d79c2867f918))
* missing argument for function ([#219](https://github.com/j-hui/fidget.nvim/issues/219)) ([889028b](https://github.com/j-hui/fidget.nvim/commit/889028b2462d1610d245f59e2b7424bbbd192f61))
* **progress:** use INFO level for all progress notifications ([ebb8e44](https://github.com/j-hui/fidget.nvim/commit/ebb8e44d6c37337e3b4f9bce31842573fa96bf8d))

## [1.4.0](https://github.com/j-hui/fidget.nvim/compare/v1.3.0...v1.4.0) (2024-02-14)


### Features

* **integration:** improved avoidance of Test Explorer window from xcodebuild.nvim plugin ([#213](https://github.com/j-hui/fidget.nvim/issues/213)) ([7d1873a](https://github.com/j-hui/fidget.nvim/commit/7d1873ae12fb9db75edaedd298c2155b1efa96ad))
* **integration:** xcodebuild.nvim integration ([#212](https://github.com/j-hui/fidget.nvim/issues/212)) ([9eb2833](https://github.com/j-hui/fidget.nvim/commit/9eb28334191033e439b34dfa580c3bf5cd9dd5fa)), closes [#207](https://github.com/j-hui/fidget.nvim/issues/207)


### Bug Fixes

* checking for winid value before to evoke it ([#203](https://github.com/j-hui/fidget.nvim/issues/203)) ([53d5b79](https://github.com/j-hui/fidget.nvim/commit/53d5b7959163d7ce5f31893a3be6bb845ee5fd80))
* **notificationa:** don't reset x_offset when closing window ([d1b2a71](https://github.com/j-hui/fidget.nvim/commit/d1b2a7147b5e51238830d939d2fcab12f08c38fb))

## [1.3.0](https://github.com/j-hui/fidget.nvim/compare/v1.2.0...v1.3.0) (2024-02-04)


### Features

* **log:** auto-prune logs to prevent them from growing indefinitely ([e3cb72b](https://github.com/j-hui/fidget.nvim/commit/e3cb72b67924ed2f7d63fc383be2892ae830016f))
* **logger:** improve LSP progress message logging ([f03a2d6](https://github.com/j-hui/fidget.nvim/commit/f03a2d6c8cebc23c1cc646efddcaa312dbfacc06))
* **log:** log $/progress handler invocations ([8d4cd3b](https://github.com/j-hui/fidget.nvim/commit/8d4cd3beb512d347ba95958e4fa7d177ad832d44))


### Bug Fixes

* Fix a typo in the documentation ([#204](https://github.com/j-hui/fidget.nvim/issues/204)) ([7e08b10](https://github.com/j-hui/fidget.nvim/commit/7e08b105d59a325368c9d4bd0fc5e16a0518e8a8))

## [1.2.0](https://github.com/j-hui/fidget.nvim/compare/v1.1.0...v1.2.0) (2024-01-08)


### Features

* add :Fidget ex-command ([ecc187e](https://github.com/j-hui/fidget.nvim/commit/ecc187e8bba63babc731346ecaf83f83064484cf))
* add API function to remove() notification items ([df0caf2](https://github.com/j-hui/fidget.nvim/commit/df0caf2e4cf66a984325e4cca3c3e55422d67cd1))
* add update_hook option to notification group Config ([0fb9e3f](https://github.com/j-hui/fidget.nvim/commit/0fb9e3ffd3e3b8f40dbf527d59b7a7980f2e417e))
* complete group_key from active groups ([0e28434](https://github.com/j-hui/fidget.nvim/commit/0e28434907a347d265b7fcc78758ab330dca9877))
* deduplicate repeated messages (close [#162](https://github.com/j-hui/fidget.nvim/issues/162)) ([09f0c91](https://github.com/j-hui/fidget.nvim/commit/09f0c91d23c3e5939f79c80be2e7bc448d3cbc7d))
* **history:** introduce separate HistoryItem type, with group_name and group_icon ([010e4d1](https://github.com/j-hui/fidget.nvim/commit/010e4d131bb50013df791f6d94c1af67c289a57a))
* **history:** show notifications history in echo buffer ([921ee3f](https://github.com/j-hui/fidget.nvim/commit/921ee3f38985967b8654eaf4357089a634530e9a))
* integrate with nvim-tree to avoid collisions ([72be8c6](https://github.com/j-hui/fidget.nvim/commit/72be8c6b99c8b04c961a71c2a14464bfe5a63faf)), closes [#163](https://github.com/j-hui/fidget.nvim/issues/163)
* **notification:** configure skip_history from notification config ([580b4e4](https://github.com/j-hui/fidget.nvim/commit/580b4e4ceca2f474be78101b480eb523efe30406))
* **notification:** support notifications history ([93d944f](https://github.com/j-hui/fidget.nvim/commit/93d944fd77bd2b6f0a7f6d1a30c8bc0aa5803191))
* **poll:** convert timetamps to absolute UNIX timestamps ([9a8c672](https://github.com/j-hui/fidget.nvim/commit/9a8c6724c2984cb27052fa29c5937d311e59bf01))
* **progress:** omit progress messages from notifications history ([4ca2fb1](https://github.com/j-hui/fidget.nvim/commit/4ca2fb1fadea9fbf7203cc4a04d247eb00edd7bd))
* redirect notifications to alternate backends ([91eb16f](https://github.com/j-hui/fidget.nvim/commit/91eb16fe08d92c742b0aff3ef0d72a7c37e89a6d))


### Bug Fixes

* don't render hidden items ([2b44812](https://github.com/j-hui/fidget.nvim/commit/2b44812d87f991161500fb08d1206b9ea4d4bcc2))
* **history:** convert reltime to UNIX time in add_removed  (fix [#191](https://github.com/j-hui/fidget.nvim/issues/191)) ([1ba4ed7](https://github.com/j-hui/fidget.nvim/commit/1ba4ed7e4ee114df803ccda7ffedaf7ad2c26239))

## [1.1.0](https://github.com/j-hui/fidget.nvim/compare/v1.0.0...v1.1.0) (2023-12-08)


### Features

* public progress API for non-lsp use cases ([#178](https://github.com/j-hui/fidget.nvim/issues/178)) ([d81cc08](https://github.com/j-hui/fidget.nvim/commit/d81cc087da109b53b0d067203402a34503e45ccb))


### Bug Fixes

* **ci:** do not add lemmy-help binary in CI ([e1ecc2d](https://github.com/j-hui/fidget.nvim/commit/e1ecc2deb095d29eb2256bebc6c596fd486a8586))
* **doc:** generate link instead of tag in ToC ([3f5a5bb](https://github.com/j-hui/fidget.nvim/commit/3f5a5bbf57cf286f4369a273a0a44f442be79c32))
* docs badge link ([fd95ef3](https://github.com/j-hui/fidget.nvim/commit/fd95ef3799e6b9b412a6966b14a0902457d6d0d2))

## [1.0.0](https://github.com/j-hui/fidget.nvim/compare/v0.0.0...v1.0.0) (2023-12-07)


### ⚠ BREAKING CHANGES

* reorganize all documentation (fix #144)

### doc

* reorganize all documentation (fix [#144](https://github.com/j-hui/fidget.nvim/issues/144)) ([f7dde2b](https://github.com/j-hui/fidget.nvim/commit/f7dde2bd4b9ae95a5fc11c2eed7467331854e219))


### Bug Fixes

* the emoji in the README lol ([5be46c8](https://github.com/j-hui/fidget.nvim/commit/5be46c8aeb5d37e1da20cd613b286329ca2a4fca))
