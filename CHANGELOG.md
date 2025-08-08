# Changelog

## [0.2.1](https://github.com/rubyists/leopard/compare/v0.2.0...v0.2.1) (2025-08-08)


### Bug Fixes

* Do not leak SemanticLogger settings outside of isolation ([#30](https://github.com/rubyists/leopard/issues/30)) ([524595c](https://github.com/rubyists/leopard/commit/524595c37f114ec28f40abc841ecb3c7b6579f5a))

## [0.2.0](https://github.com/rubyists/leopard/compare/v0.1.7...v0.2.0) (2025-08-07)


### ⚠ BREAKING CHANGES

* Big move to use kwargs as the initializer for classes which include us ([#28](https://github.com/rubyists/leopard/issues/28))

### Bug Fixes

* Big move to use kwargs as the initializer for classes which include us ([#28](https://github.com/rubyists/leopard/issues/28)) ([72293b4](https://github.com/rubyists/leopard/commit/72293b434998679fe3ff2d467a6a39c11a325b5a))

## [0.1.7](https://github.com/rubyists/leopard/compare/v0.1.6...v0.1.7) (2025-08-06)


### Bug Fixes

* Allow non blocking all the way down to the instance level ([#27](https://github.com/rubyists/leopard/issues/27)) ([01748a5](https://github.com/rubyists/leopard/commit/01748a56bc927ee1dbc70d2351fd12037e5b4bef))
* Stop sending code argument to respond_with_error, it does not accept it ([#23](https://github.com/rubyists/leopard/issues/23)) ([9d87b8c](https://github.com/rubyists/leopard/commit/9d87b8c308a1fdff72769863711bb6bb942b3677))

## [0.1.6](https://github.com/rubyists/leopard/compare/v0.1.5...v0.1.6) (2025-08-03)


### Features

* Adds graceful shutdown when INT/TERM/QUIT signal is received ([#18](https://github.com/rubyists/leopard/issues/18)) ([ce03fb0](https://github.com/rubyists/leopard/commit/ce03fb00afcbbadadc413766b62df9451f7b73b8))

## [0.1.5](https://github.com/rubyists/leopard/compare/v0.1.4...v0.1.5) (2025-07-31)


### Bug Fixes

* Run in blocking mode, not just non-blocking ([#15](https://github.com/rubyists/leopard/issues/15)) ([a659145](https://github.com/rubyists/leopard/commit/a659145d8a04efe3b3932b99ab4c11ef0ba2025e))

## [0.1.4](https://github.com/rubyists/leopard/compare/v0.1.3...v0.1.4) (2025-07-31)


### Bug Fixes

* Have to build the gem before we can find it, doh ([#13](https://github.com/rubyists/leopard/issues/13)) ([62053e9](https://github.com/rubyists/leopard/commit/62053e9d2332d37d4d5697035a35adc71833eccd))

## [0.1.3](https://github.com/rubyists/leopard/compare/v0.1.2...v0.1.3) (2025-07-31)


### Bug Fixes

* Fixes the gem publisher, and adds missing .version.txt ([#11](https://github.com/rubyists/leopard/issues/11)) ([3dcbd3c](https://github.com/rubyists/leopard/commit/3dcbd3c1d687e04ce5fde85fef5c2d1c10a8a4cc))

## [0.1.2](https://github.com/rubyists/leopard/compare/v0.1.1...v0.1.2) (2025-07-31)


### Bug Fixes

* Remove sequel cruft in ci config ([#9](https://github.com/rubyists/leopard/issues/9)) ([09a43e2](https://github.com/rubyists/leopard/commit/09a43e23c309167c56095dd608af9d79ff4f9b19))

## [0.1.1](https://github.com/rubyists/leopard/compare/v0.1.0...v0.1.1) (2025-07-31)


### Features

* Adds gemspec and gemfile ([#1](https://github.com/rubyists/leopard/issues/1)) ([972dc72](https://github.com/rubyists/leopard/commit/972dc72de804ca10db5cf869d0ea996a94ac9722))
* Adds rakefile back ([#3](https://github.com/rubyists/leopard/issues/3)) ([271592c](https://github.com/rubyists/leopard/commit/271592c357e07d58de085297850533eaae60a285))
* Adds settings to module ([9ff0942](https://github.com/rubyists/leopard/commit/9ff0942dddd86bf4f97bc82626cc7bb35e4115ac))
* Basic functionality for serving apis ([#4](https://github.com/rubyists/leopard/issues/4)) ([9ff0942](https://github.com/rubyists/leopard/commit/9ff0942dddd86bf4f97bc82626cc7bb35e4115ac))
* Initial readme ([4ea9f34](https://github.com/rubyists/leopard/commit/4ea9f341c9df6096b8df3595ff6a075eb9b5c4f6))


### Bug Fixes

* Corrects gemname in publish-gem.sh ([9ff0942](https://github.com/rubyists/leopard/commit/9ff0942dddd86bf4f97bc82626cc7bb35e4115ac))
* Corrects the version ([#7](https://github.com/rubyists/leopard/issues/7)) ([a3de532](https://github.com/rubyists/leopard/commit/a3de5320a8c54e9ca6724b6e90812bb5b1b7d150))
