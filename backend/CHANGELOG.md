# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

<!-- NOTICE -->
<!-- Starting from v0.11 changelogs are separated per-project. The changes below
refer to both the frontend *and* the backend of edgehog -->

## [0.13.0](https://github.com/edgehog-device-manager/edgehog/compare/v0.12.3...v0.13.0) (2026-04-09)


### ⚠ BREAKING CHANGES

* **backend:** remove authentication bypass configuration
* events are treated as events ([#953](https://github.com/edgehog-device-manager/edgehog/issues/953))
* enforce key-value structure for `Container.env`
* aggregate readiness
* This change is only breaking if you have already applied the original migration. If you haven't applied it yet, you should not experience any problems. If you have already applied the original migration, you will need to manually reconcile your database state before applying this updated version.

### Features

* add `delete` operation support to deployment campaigns ([#1031](https://github.com/edgehog-device-manager/edgehog/issues/1031)) ([4d535d8](https://github.com/edgehog-device-manager/edgehog/commit/4d535d892d14278e5b9d5bef6a25ee54275638da))
* Add `Pause` and `Resume` functionality for campaigns ([#1204](https://github.com/edgehog-device-manager/edgehog/issues/1204)) ([35a9aab](https://github.com/edgehog-device-manager/edgehog/commit/35a9aab42a458358bf87a60e37453b26a7ac0228)), closes [#277](https://github.com/edgehog-device-manager/edgehog/issues/277)
* add Ash GraphQL subscriptions ([#1028](https://github.com/edgehog-device-manager/edgehog/issues/1028)) ([faefc93](https://github.com/edgehog-device-manager/edgehog/commit/faefc9380e1c5d4416618260c6100fecd481622a))
* add azure support ([ed8f2f7](https://github.com/edgehog-device-manager/edgehog/commit/ed8f2f75dcbdc53f01633d70396ac929ff4d4b0e))
* add calculation to expose Base Image name ([d3affa5](https://github.com/edgehog-device-manager/edgehog/commit/d3affa57af400440a26bccc6c29b3fb9c3534b23))
* Add container binds ([#1008](https://github.com/edgehog-device-manager/edgehog/issues/1008)) ([5e8d5e1](https://github.com/edgehog-device-manager/edgehog/commit/5e8d5e1bde6c2c11ed642a305318793df9209b92))
* add deployment details ([#1060](https://github.com/edgehog-device-manager/edgehog/issues/1060)) ([51b9503](https://github.com/edgehog-device-manager/edgehog/commit/51b9503eacb60d33eb874537f71839033e0d6de9))
* add device group subscription ([#1198](https://github.com/edgehog-device-manager/edgehog/issues/1198)) ([adb91f4](https://github.com/edgehog-device-manager/edgehog/commit/adb91f4e5f7011cdf424b77371ebf4f8858f66d1))
* Add filtering for deployment targets with deployed applications ([#1002](https://github.com/edgehog-device-manager/edgehog/issues/1002)) ([c847e77](https://github.com/edgehog-device-manager/edgehog/commit/c847e77ecad9c35d5618b91687635682d7805475))
* add GraphQL subscriptions for containers ([#1224](https://github.com/edgehog-device-manager/edgehog/issues/1224)) ([6c36e6d](https://github.com/edgehog-device-manager/edgehog/commit/6c36e6d0e632251f64a6ffef4a2a304f658f55ad))
* add GraphQL subscriptions for OTA operations ([#1220](https://github.com/edgehog-device-manager/edgehog/issues/1220)) ([db679ce](https://github.com/edgehog-device-manager/edgehog/commit/db679ceebe687909871ed3fee9e59303b4397aa0))
* Add operation_type and target_release to deployment campaigns ([#999](https://github.com/edgehog-device-manager/edgehog/issues/999)) ([8d8b34e](https://github.com/edgehog-device-manager/edgehog/commit/8d8b34e2a74937e7ed1ac97fefd6dfc7f857921f))
* add start operation support to deployment campaigns ([#1017](https://github.com/edgehog-device-manager/edgehog/issues/1017)) ([1fe5bd1](https://github.com/edgehog-device-manager/edgehog/commit/1fe5bd1734109a1e5a49e8a48706ba9a762cf911))
* add stop operation support to deployment campaigns ([#1027](https://github.com/edgehog-device-manager/edgehog/issues/1027)) ([13a639a](https://github.com/edgehog-device-manager/edgehog/commit/13a639acbc7c6bbea1e60015f96f363790c07e6e))
* Add subscriptions for HT and SMPN ([#1225](https://github.com/edgehog-device-manager/edgehog/issues/1225)) ([7d46654](https://github.com/edgehog-device-manager/edgehog/commit/7d466541e3b77f87d84884332046a677d102b441))
* Add support for regex and glob pattern matching in device selector DSL ([#835](https://github.com/edgehog-device-manager/edgehog/issues/835)) ([479eb81](https://github.com/edgehog-device-manager/edgehog/commit/479eb8100af62d72ffc21825f2cf743a27ac376a))
* Add trigger delivery policies support to tenant reconciler ([#838](https://github.com/edgehog-device-manager/edgehog/issues/838)) ([8892e0f](https://github.com/edgehog-device-manager/edgehog/commit/8892e0f1bd60b123cd933af39436f86f5e148785))
* add upgrade operation support to deployment campaigns ([#1029](https://github.com/edgehog-device-manager/edgehog/issues/1029)) ([2eb965e](https://github.com/edgehog-device-manager/edgehog/commit/2eb965e354b67b1659c24dfcf296208f64f16ed6))
* add validation for deployment campaign operation type requirements ([#1004](https://github.com/edgehog-device-manager/edgehog/issues/1004)) ([396d995](https://github.com/edgehog-device-manager/edgehog/commit/396d9953347072117965d8eac07a87851e815cca))
* Additional information on deployment events ([ba27473](https://github.com/edgehog-device-manager/edgehog/commit/ba2747342f3b048a695f81deab856ce943aa39ab))
* allow administrators to delete tenants ([#1037](https://github.com/edgehog-device-manager/edgehog/issues/1037)) ([64300c3](https://github.com/edgehog-device-manager/edgehog/commit/64300c354e38d0c0c4661a778b3fcbcbc36929cb))
* allow users to re-send deployment messages ([#1041](https://github.com/edgehog-device-manager/edgehog/issues/1041)) ([64a5dd9](https://github.com/edgehog-device-manager/edgehog/commit/64a5dd939dfef35dca69ba8e91489e295a3566ee))
* application management ([#934](https://github.com/edgehog-device-manager/edgehog/issues/934)) ([c1f8421](https://github.com/edgehog-device-manager/edgehog/commit/c1f84219e056da81ee82f0171cc0ffdb0191f6c1))
* azure support ([6d3e198](https://github.com/edgehog-device-manager/edgehog/commit/6d3e19821df639bb05adcf2c582f31d372b015ed))
* **backend:** add subscriptions to campaigns domain ([2bda866](https://github.com/edgehog-device-manager/edgehog/commit/2bda8661d064a4eb45ade539058930e1b54ddefb))
* **backend:** allow deletion of BaseImage used in completed campaign ([46f7aa3](https://github.com/edgehog-device-manager/edgehog/commit/46f7aa34f585aabf2a37f4baef10a8ac4a5ea33d)), closes [#598](https://github.com/edgehog-device-manager/edgehog/issues/598)
* **backend:** base_images subscriptions ([bf28b85](https://github.com/edgehog-device-manager/edgehog/commit/bf28b85f909e6cfa1a2d8faf0979a4904073df67))
* **backend:** manual OTA with base image from collection ([1af4b8d](https://github.com/edgehog-device-manager/edgehog/commit/1af4b8d8b9f10ca480a2aacf6073e8c2f2297b1c))
* **backend:** run tenant reconciliation at creation ([f806909](https://github.com/edgehog-device-manager/edgehog/commit/f806909c1159ffd6f9171885f8ccee96f2a6f582))
* block actions until deployment is ready ([#988](https://github.com/edgehog-device-manager/edgehog/issues/988)) ([ea12c0b](https://github.com/edgehog-device-manager/edgehog/commit/ea12c0b03be3b6c2359dd76a3d51d25de71cc184))
* create device upon registration in astarte ([#1007](https://github.com/edgehog-device-manager/edgehog/issues/1007)) ([05e8e16](https://github.com/edgehog-device-manager/edgehog/commit/05e8e16d3042a1c878d04ef8166d6c7cb25df688))
* Expose deployment campaigns in deployments ([#979](https://github.com/edgehog-device-manager/edgehog/issues/979)) ([65217e4](https://github.com/edgehog-device-manager/edgehog/commit/65217e425a03a5515b4b655c9780c37aefd697cd))
* expose is_ready field of deployment via GraphQL ([4b5064c](https://github.com/edgehog-device-manager/edgehog/commit/4b5064c7d05e5ba76795b2a66884bef5292fa8a0))
* expose underlying deployments ([73f21a6](https://github.com/edgehog-device-manager/edgehog/commit/73f21a69f8c93c0f9217ebf050a84bbbdf6b059d))
* expose underlying resources to the user ([a50e4fa](https://github.com/edgehog-device-manager/edgehog/commit/a50e4fa39dea68afe9e604ec5688a6ce005d87c8))
* filter deployment targets by operation type ([#1015](https://github.com/edgehog-device-manager/edgehog/issues/1015)) ([11541e2](https://github.com/edgehog-device-manager/edgehog/commit/11541e2c19160242180a557c0fe35fd74af05d66))
* GraphQL subscription for device updates in table ([#1118](https://github.com/edgehog-device-manager/edgehog/issues/1118)) ([be6a629](https://github.com/edgehog-device-manager/edgehog/commit/be6a6295f2767cf3ae766984aedbc29833a95a06))
* implement GraphQL subscriptions for device events ([32badc9](https://github.com/edgehog-device-manager/edgehog/commit/32badc94a5705f3003ce66c1837430863a0217e3))
* implement retry logic for all deployment campaign operation types ([#1032](https://github.com/edgehog-device-manager/edgehog/issues/1032)) ([a1c6a81](https://github.com/edgehog-device-manager/edgehog/commit/a1c6a81de28019c9edadd90a70db5865b336856c))
* log outcome for successful or failed OTA operations ([#943](https://github.com/edgehog-device-manager/edgehog/issues/943)) ([#944](https://github.com/edgehog-device-manager/edgehog/issues/944)) ([fb0a7ba](https://github.com/edgehog-device-manager/edgehog/commit/fb0a7ba3410806f1a578a78c91cd9147353b127d))
* OTA updates can be canceled ([1daed60](https://github.com/edgehog-device-manager/edgehog/commit/1daed60e4fa6af858208f4b3fe3c3863006168c3)), closes [#266](https://github.com/edgehog-device-manager/edgehog/issues/266)
* **ota:** exposing optional update target of OTA ([2d4403e](https://github.com/edgehog-device-manager/edgehog/commit/2d4403eab9e9ff3daf7e9b809a8791deb1bd21ca))
* **ota:** exposing optional update target of OTA ([8acace2](https://github.com/edgehog-device-manager/edgehog/commit/8acace251d36bc6ba1c8f69ae7772739e253a0cf)), closes [#356](https://github.com/edgehog-device-manager/edgehog/issues/356)
* Prevent deployment actions during conflicting campaigns ([#1058](https://github.com/edgehog-device-manager/edgehog/issues/1058)) ([71ccb38](https://github.com/edgehog-device-manager/edgehog/commit/71ccb38c4e98ee7b3f03228c5d822063d1ba54bc))
* **reconciler:** implement partial map comparison ([#980](https://github.com/edgehog-device-manager/edgehog/issues/980)) ([d43824f](https://github.com/edgehog-device-manager/edgehog/commit/d43824ff0a2f145808375cda4d32f9432c2707b7))
* remove device upon deletion finished in astarte ([6879933](https://github.com/edgehog-device-manager/edgehog/commit/687993393d51bdc15cd743da8041a8bd0187945b))
* server side pagination ([#888](https://github.com/edgehog-device-manager/edgehog/issues/888)) ([946571b](https://github.com/edgehog-device-manager/edgehog/commit/946571b19bc0c5ff7f3ace00c8e0d8d3b043d597))
* show `partNumber` and `serialNumber` in `Device` page if available ([#1123](https://github.com/edgehog-device-manager/edgehog/issues/1123)) ([c2261bb](https://github.com/edgehog-device-manager/edgehog/commit/c2261bb7397c4ca956013d245dc16a537e308267)), closes [#226](https://github.com/edgehog-device-manager/edgehog/issues/226)


### Bug Fixes

* add image_credentials_id to image identity ([#996](https://github.com/edgehog-device-manager/edgehog/issues/996)) ([de1b8dc](https://github.com/edgehog-device-manager/edgehog/commit/de1b8dcb9c85eb739e09314d3ecea07893e75576))
* avoid 422 in tenant deletion ([#1103](https://github.com/edgehog-device-manager/edgehog/issues/1103)) ([de8c0d9](https://github.com/edgehog-device-manager/edgehog/commit/de8c0d9a6f5a61c19ec222463046643b3154b9dc))
* avoid re-sending update messages ([#1081](https://github.com/edgehog-device-manager/edgehog/issues/1081)) ([a718c95](https://github.com/edgehog-device-manager/edgehog/commit/a718c95dc56ed291c6516e08245477bacc8b8637))
* **backend:** DeploymentEvent interface not working ([fd8e9c5](https://github.com/edgehog-device-manager/edgehog/commit/fd8e9c5f537ad3184ac6b365b9ff7f378aaf4938))
* **backend:** log errors instead of crashing ([899f431](https://github.com/edgehog-device-manager/edgehog/commit/899f4315f01e67331057dcd11c4dbf0bee11c734))
* **bucket_storage:** image deletion ([5517c6e](https://github.com/edgehog-device-manager/edgehog/commit/5517c6ebd51b6a844bf13cf56ad54f9caddbec7c))
* **bucket_storage:** image deletion ([178a825](https://github.com/edgehog-device-manager/edgehog/commit/178a825f94ef3323a6e601faf29eeec76de0bbaa))
* **config:** Azure and edgehog config clash ([fa032dc](https://github.com/edgehog-device-manager/edgehog/commit/fa032dc4fca80063f872bf759d17af40df6f2b1d))
* **config:** Azure and edgehog config clash ([9c42aa6](https://github.com/edgehog-device-manager/edgehog/commit/9c42aa6acf39c68026824be83d48b24647b31db3))
* **containers:** Add validation for unique volume targets ([b1e65f7](https://github.com/edgehog-device-manager/edgehog/commit/b1e65f73c0a9207d59bdb041fd6c3186640fe048))
* **containers:** Add validation for unique volume targets ([288246a](https://github.com/edgehog-device-manager/edgehog/commit/288246adfef250b621352f3d39492e64b0fac338))
* **containers:** remove usage of non-existing status_code deployment key ([#946](https://github.com/edgehog-device-manager/edgehog/issues/946)) ([8988cee](https://github.com/edgehog-device-manager/edgehog/commit/8988ceebe6c51201ad6ca4ad96355574a1380d41))
* correct load of realm management client ([397ebf5](https://github.com/edgehog-device-manager/edgehog/commit/397ebf5e5f94456f10b0cb77a2a446ef2b189e56))
* correctly deploy resources only if not already deployed ([a6e4b78](https://github.com/edgehog-device-manager/edgehog/commit/a6e4b78573ad95d6f43e97824b2178450c094dc7))
* correctly relate image and container deployments ([b21ee6e](https://github.com/edgehog-device-manager/edgehog/commit/b21ee6e3ae2dd3ac10d7b025adcb2cb5428fd23e))
* device reconciliation not working ([ba1b025](https://github.com/edgehog-device-manager/edgehog/commit/ba1b02530283f69de9cafa5ce4a19cdb117de285))
* device registration triggers are available from `1.3.0-rc.0` ([#1096](https://github.com/edgehog-device-manager/edgehog/issues/1096)) ([dea4d3c](https://github.com/edgehog-device-manager/edgehog/commit/dea4d3cde31c1988d36f8029c8d9e0ed0b0b87cb))
* do not crash on available networks ([ee4111d](https://github.com/edgehog-device-manager/edgehog/commit/ee4111defbea75bc4bb0bc40fce17d2da79766b0))
* do not crash on available networks ([41fa223](https://github.com/edgehog-device-manager/edgehog/commit/41fa2233de37199300143b42b53920b1e61d02d8))
* do not erease device names ([#1285](https://github.com/edgehog-device-manager/edgehog/issues/1285)) ([930d292](https://github.com/edgehog-device-manager/edgehog/commit/930d2925e5efe4b68cda867d69d0978c28be09d6))
* double free of campaign slots ([664788b](https://github.com/edgehog-device-manager/edgehog/commit/664788baed26db6ded426f7dbb06b6d6f88e753e))
* double free of slots ([4884ad8](https://github.com/edgehog-device-manager/edgehog/commit/4884ad8e4fde1ee807d52dea3ec583d772e52c9c))
* ensure migrations can be successfully rolled back ([#949](https://github.com/edgehog-device-manager/edgehog/issues/949)) ([2981b1c](https://github.com/edgehog-device-manager/edgehog/commit/2981b1ccba3d3e674af1f1038625b1ecdf666270))
* **frontend:** fix Campaigns create subscription data ([898ad56](https://github.com/edgehog-device-manager/edgehog/commit/898ad56e5c2bac7413e1fdf031b5c9c6243cad6a))
* Handle reconciler task replies ([bec0758](https://github.com/edgehog-device-manager/edgehog/commit/bec075870002b9e7c9213e7d9d0eeb2fd763d890))
* ignore prefetch_count in comparison of delivery policies ([#961](https://github.com/edgehog-device-manager/edgehog/issues/961)) ([f78f597](https://github.com/edgehog-device-manager/edgehog/commit/f78f597e24688b306759981d15b6314be8f4f340))
* include tenant in socket options ([d3c8921](https://github.com/edgehog-device-manager/edgehog/commit/d3c89212ca7c4fb25cab293985da144eac3f9188))
* Migrate old deployment states ([#1113](https://github.com/edgehog-device-manager/edgehog/issues/1113)) ([c7389e4](https://github.com/edgehog-device-manager/edgehog/commit/c7389e416987a0dcb67ad9a9396600b4cd60f330)), closes [#1086](https://github.com/edgehog-device-manager/edgehog/issues/1086)
* null `env` in `Container`s ([#1000](https://github.com/edgehog-device-manager/edgehog/issues/1000)) ([38bbb13](https://github.com/edgehog-device-manager/edgehog/commit/38bbb13c6e63b35b3739a556441a65e9c8157440))
* only reconcile when really needed ([#1072](https://github.com/edgehog-device-manager/edgehog/issues/1072)) ([49cca31](https://github.com/edgehog-device-manager/edgehog/commit/49cca31b81e4c2ccc5de34db258b58d2535f358f))
* Preserve existing data when migrating update_channels to channels ([6169fc0](https://github.com/edgehog-device-manager/edgehog/commit/6169fc0eb2953818bf6d956dbaf30dd2fb135c85))
* Prevent duplicate success in campaigns ([#1110](https://github.com/edgehog-device-manager/edgehog/issues/1110)) ([c39b387](https://github.com/edgehog-device-manager/edgehog/commit/c39b387667dd0cedeb2871938e7faf666fa7937d))
* reconcile backend snapshots ([#993](https://github.com/edgehog-device-manager/edgehog/issues/993)) ([2fd8d14](https://github.com/edgehog-device-manager/edgehog/commit/2fd8d149e19fba297692044d1fdcabe63536eee2))
* Remove Dockerfile Warnings for Casing and ENV Format ([1c6b09e](https://github.com/edgehog-device-manager/edgehog/commit/1c6b09ea4678318ef290d8b63779bb1c62c971b7))
* Remove Dockerfile Warnings for Casing and ENV Format ([112e369](https://github.com/edgehog-device-manager/edgehog/commit/112e369eae9795898c32e65879c0fc6fcedc3ffc))
* revert reconciliation condition ([#1079](https://github.com/edgehog-device-manager/edgehog/issues/1079)) ([cbf9a0f](https://github.com/edgehog-device-manager/edgehog/commit/cbf9a0f5297e6edf6e9bd15da605ddbc235bdcf4))
* run reconciliation after provisioning is complete ([a61dff8](https://github.com/edgehog-device-manager/edgehog/commit/a61dff80819b83f7f2e56411c7d8b0522ae7f655))
* unify device creation and update subscriptions ([c09e7de](https://github.com/edgehog-device-manager/edgehog/commit/c09e7de8d5570cd15f158ade835e9a332c602597))
* update a deployment state to `:sent` only when necessary ([6e4371a](https://github.com/edgehog-device-manager/edgehog/commit/6e4371ad59fc5b4be48ebe250b3eaed12b151c74))
* updating is not deleting ([ed33f33](https://github.com/edgehog-device-manager/edgehog/commit/ed33f331583d6fcae926fb545913056f4bcddec5))
* updating is not deleting ([ad209c7](https://github.com/edgehog-device-manager/edgehog/commit/ad209c7a91a2b037b293c487f982bff07003816b))
* use correct default for `read_only_rootfs` ([24a7c72](https://github.com/edgehog-device-manager/edgehog/commit/24a7c7208d0f99c5e135c143c74727c2d55c994e))
* use correct default for `read_only_rootfs` ([2b08567](https://github.com/edgehog-device-manager/edgehog/commit/2b0856792e0745df9eda636026646a63905f5fd5))


### Miscellaneous Chores

* aggregate readiness ([b2ed432](https://github.com/edgehog-device-manager/edgehog/commit/b2ed432d5e39a973fc99013ace97f3dae376381c))
* **backend:** remove authentication bypass configuration ([fb5585c](https://github.com/edgehog-device-manager/edgehog/commit/fb5585ccddc547a7bb5cb084265788d29472fec4))


### Code Refactoring

* enforce key-value structure for `Container.env` ([510217b](https://github.com/edgehog-device-manager/edgehog/commit/510217b1ab0c7a77040788931f7dffbf1fd90bb5))
* events are treated as events ([#953](https://github.com/edgehog-device-manager/edgehog/issues/953)) ([7753a77](https://github.com/edgehog-device-manager/edgehog/commit/7753a773a1da97c22f161c379b76cf784c1d2d79))

## [0.12.3](https://github.com/edgehog-device-manager/edgehog/compare/v0.12.2...v0.12.3) (2026-04-09)


### Bug Fixes

* run reconciliation after provisioning is complete ([a61dff8](https://github.com/edgehog-device-manager/edgehog/commit/a61dff80819b83f7f2e56411c7d8b0522ae7f655))

## [0.12.2](https://github.com/edgehog-device-manager/edgehog/compare/v0.12.1...v0.12.2) (2026-03-12)


### Bug Fixes

* **backend:** Do not erase device names ([930d2925](https://github.com/edgehog-device-manager/edgehog/commit/930d2925))

## [0.12.1](https://github.com/edgehog-device-manager/edgehog/compare/v0.12.0...v0.12.1) (2026-02-27)


### Bug Fixes

* **backend:** DeploymentEvent interface not working ([fd8e9c5](https://github.com/edgehog-device-manager/edgehog/commit/fd8e9c5f537ad3184ac6b365b9ff7f378aaf4938))

## [0.12.0](https://github.com/edgehog-device-manager/edgehog/compare/v0.11.0...v0.12.0) (2026-02-18)


### ⚠ BREAKING CHANGES

* **backend:** remove authentication bypass configuration

### Features

* Add `Pause` and `Resume` functionality for campaigns ([#1204](https://github.com/edgehog-device-manager/edgehog/issues/1204)) ([35a9aab](https://github.com/edgehog-device-manager/edgehog/commit/35a9aab42a458358bf87a60e37453b26a7ac0228)), closes [#277](https://github.com/edgehog-device-manager/edgehog/issues/277)
* add GraphQL subscriptions for containers ([#1224](https://github.com/edgehog-device-manager/edgehog/issues/1224)) ([6c36e6d](https://github.com/edgehog-device-manager/edgehog/commit/6c36e6d0e632251f64a6ffef4a2a304f658f55ad))
* add GraphQL subscriptions for OTA operations ([#1220](https://github.com/edgehog-device-manager/edgehog/issues/1220)) ([db679ce](https://github.com/edgehog-device-manager/edgehog/commit/db679ceebe687909871ed3fee9e59303b4397aa0))
* Add subscriptions for HT and SMPN ([#1225](https://github.com/edgehog-device-manager/edgehog/issues/1225)) ([7d46654](https://github.com/edgehog-device-manager/edgehog/commit/7d466541e3b77f87d84884332046a677d102b441))
* **backend:** add subscriptions to campaigns domain ([2bda866](https://github.com/edgehog-device-manager/edgehog/commit/2bda8661d064a4eb45ade539058930e1b54ddefb))
* **backend:** allow deletion of BaseImage used in completed campaign ([46f7aa3](https://github.com/edgehog-device-manager/edgehog/commit/46f7aa34f585aabf2a37f4baef10a8ac4a5ea33d)), closes [#598](https://github.com/edgehog-device-manager/edgehog/issues/598)


### Miscellaneous Chores

* **backend:** remove authentication bypass configuration ([fb5585c](https://github.com/edgehog-device-manager/edgehog/commit/fb5585ccddc547a7bb5cb084265788d29472fec4))

## [0.11.0](https://github.com/edgehog-device-manager/edgehog/compare/v0.10.0...v0.11.0) (2026-02-03)


### Features

* add calculation to expose Base Image name ([d3affa5](https://github.com/edgehog-device-manager/edgehog/commit/d3affa57af400440a26bccc6c29b3fb9c3534b23))
* add device group subscription ([#1198](https://github.com/edgehog-device-manager/edgehog/issues/1198)) ([adb91f4](https://github.com/edgehog-device-manager/edgehog/commit/adb91f4e5f7011cdf424b77371ebf4f8858f66d1))
* Additional information on deployment events ([ba27473](https://github.com/edgehog-device-manager/edgehog/commit/ba2747342f3b048a695f81deab856ce943aa39ab))
* **backend:** base_images subscriptions ([bf28b85](https://github.com/edgehog-device-manager/edgehog/commit/bf28b85f909e6cfa1a2d8faf0979a4904073df67))
* **backend:** manual OTA with base image from collection ([1af4b8d](https://github.com/edgehog-device-manager/edgehog/commit/1af4b8d8b9f10ca480a2aacf6073e8c2f2297b1c))
* **backend:** run tenant reconciliation at creation ([f806909](https://github.com/edgehog-device-manager/edgehog/commit/f806909c1159ffd6f9171885f8ccee96f2a6f582))
* GraphQL subscription for device updates in table ([#1118](https://github.com/edgehog-device-manager/edgehog/issues/1118)) ([be6a629](https://github.com/edgehog-device-manager/edgehog/commit/be6a6295f2767cf3ae766984aedbc29833a95a06))
* implement GraphQL subscriptions for device events ([32badc9](https://github.com/edgehog-device-manager/edgehog/commit/32badc94a5705f3003ce66c1837430863a0217e3))
* OTA updates can be canceled ([1daed60](https://github.com/edgehog-device-manager/edgehog/commit/1daed60e4fa6af858208f4b3fe3c3863006168c3)), closes [#266](https://github.com/edgehog-device-manager/edgehog/issues/266)
* show `partNumber` and `serialNumber` in `Device` page if available ([#1123](https://github.com/edgehog-device-manager/edgehog/issues/1123)) ([c2261bb](https://github.com/edgehog-device-manager/edgehog/commit/c2261bb7397c4ca956013d245dc16a537e308267)), closes [#226](https://github.com/edgehog-device-manager/edgehog/issues/226)


### Bug Fixes

* **backend:** log errors instead of crashing ([899f431](https://github.com/edgehog-device-manager/edgehog/commit/899f4315f01e67331057dcd11c4dbf0bee11c734))
* device reconciliation not working ([ba1b025](https://github.com/edgehog-device-manager/edgehog/commit/ba1b02530283f69de9cafa5ce4a19cdb117de285))
* Handle reconciler task replies ([bec0758](https://github.com/edgehog-device-manager/edgehog/commit/bec075870002b9e7c9213e7d9d0eeb2fd763d890))
* include tenant in socket options ([d3c8921](https://github.com/edgehog-device-manager/edgehog/commit/d3c89212ca7c4fb25cab293985da144eac3f9188))
* unify device creation and update subscriptions ([c09e7de](https://github.com/edgehog-device-manager/edgehog/commit/c09e7de8d5570cd15f158ade835e9a332c602597))

## [0.10.0] - 2025-12-09

### Fixed

- Migrations now account for the change in constraints in deployment states.
- Delete campaigns now correctly display the state of targets, without duplicate reports of a success.

## [0.10.0-alpha.9] - 2025-12-03

### Added

- Initial draft of the documentation for the container management system.

### Changed

- Astarte `1.3.0-rc.0` is now the first version allowed for device registration
  and deletion triggers.

### Fixed

- `422` answer when trying to delete a tenant. The API now correctly handles the
  `tenant_id`.

## [0.10.0-alpha.8] - 2025-10-28

### Added

- Support for stop campaigns: a deployment campaign can send a `stop` operation on a target release on all devices in a channel.
- Support for start campaigns: a deployment campaign can send a `start` operation on a target release on all devices in a channel.
- Support for upgrade campaigns: a deployment campaign can `update` a container to a newer version on all devices in a channel.
- Support for delete campaigns: a deployment campaign can send a `delete` message on a target release on all devices in a channel.
- Reconciliation logic: container information gets reconciled with astarte if some messages get lost. The polling system acts on time windows to avoid traffic spikes in astarte.
- Retry mechanism: users can manually retry to send necessary messages to a device to deploy a container.

### Changed

- The deployment state does no longer incorporate events, instead events are available in the `events` field of deployments. Users can access them in a _log_ fashion.
- Removed `last_message` field in deployment.
- With Astarte versions >= 1.3, devices are available in Edgehog upon registration, without waiting for their first connection.

### Fixed

- Type error on network and volume options prevented users from using advanced driver options both on volumes and networks.
- Update messages were sent each time a deployment with some ready actions was stopped. This prevented updated releases from actually being stopped.

## [0.10.0-alpha.7] - 2025-10-28

### Changed

- Added a default image for devices that don’t have an associated system model image, replacing the plain grey placeholder
- Containers now allow to specify binds.
- Frontend validation for port bindings support the full docker specification: [docker documentation](https://docs.docker.com/reference/compose-file/services/#ports).
- Adds garbage collection utilities for container resources

## [0.10.0-alpha.6] - 2025-10-16

### Added

- The backend now allows to define different images with the same reference but different image credentials associated.

### Changed

- CPU Period and CPU Quota get validated on the fronted.
- Updated the postgres version in dev, test still run on all versions.
- Added validation for unique volume targets
- Deployment readiness is now a single field
- Deployments now report in the UI the state of each single container. Showing whether the container is running, exited or encountered some error.
- Key-value structure for container environment variables is enforced on backend level.

### Fixed

- Reconciler wrongful map comparison.
- Properly update relay connections to avoid out-of sync errors.

## [0.10.0-alpha.5] - 2025-10-06

### Changed

- When no device group exist, on the Channel List page prompt the user to create at least one group before creating a Channel ([#972](https://github.com/edgehog-device-manager/edgehog/issues/972)).
- Improved how Network and Volumes options can be displayed and edited in the Applications section ([#963](https://github.com/edgehog-device-manager/edgehog/issues/963)).

### Fixed

- Remove application displayed in the application list after deleting it ([#967](https://github.com/edgehog-device-manager/edgehog/issues/967)).
- On the device page, propose only options compatible with the device when users want to upgrade an app's release ([#970](https://github.com/edgehog-device-manager/edgehog/issues/970)).
- Use uniform and readable labels for displaying Restart Policy values of containers ([#971](https://github.com/edgehog-device-manager/edgehog/issues/971)).
- Add logic to resume app campaigns when Edgehog starts up ([#969](https://github.com/edgehog-device-manager/edgehog/issues/969)).

## [0.10.0-alpha.4] - 2025-09-29

### Fixed

- Correctly use Docker's default `false` value for container's readonly root filesystem option.

## [0.10.0-alpha.3] - 2025-09-26

### Fixed

- Astarte reconciler not correctly comparing trigger delivery policies, thus continuously reinstalling them.

## [0.10.0-alpha.2] - 2025-09-26

### Changed

- Improved the web page to create new app releases, with UI adjustments to help users better understand and operate the page.

### Fixed

- Deletion of existing app deployments, not working due to incorrect handling of database constraints.

## [0.10.0-alpha.1] - 2025-09-25

### Fixed

- Failures in handling device events regarding container deployments.
- Incorrect `cGroupPermissions` option not delivered when deploying containers.

## [0.10.0-alpha.0] - 2025-09-24

### Added

- Managed OTA operations expose the update target that created them in graphql ([#356](https://github.com/edgehog-device-manager/edgehog/issues/356)).
- Expose the associated UpdateCampaign (if any) from an OTA Operation on the Software Updates tab ([#356](https://github.com/edgehog-device-manager/edgehog/issues/356)).
- Support for using Azure Storage as the persistence layer for asset uploads ([#233](https://github.com/edgehog-device-manager/edgehog/issues/233)).
- Ecto SSL configuration is exposed through `DATABASE_*` environment variables (see [.env](./.env))
- Adds support for trigger delivery policies in the tenant reconciler, allowing Edgehog to automatically provision and manage trigger delivery policies on Astarte realms that support them (v1.1.1+).
- Added Applications tab to Device page ([#662](https://github.com/edgehog-device-manager/edgehog/issues/662))
- Implemented a application management feature, enabling users to view and navigate through applications and their release details ([#704](https://github.com/edgehog-device-manager/edgehog/issues/704))
  - **Applications page**: Displays a list of all existing applications, with navigation to individual Application pages.
  - **Application page**: Shows the details of a selected application, including its name, description and a list of releases, with navigation to individual Release pages.
  - **Release page**: Provides details of a specific release, including a list of containers and configurations, such as image reference, image credentials (label, username), networks, and port bindings.
- Added `ApplicationCreate` page to enable users to create a new application with fields for application name and description.
- Added `ReleaseCreate` page to enable users to create a new release for an application with fields for release Version and a list of Containers.
- Add upgrade deployment functionality with version selection ([#703](https://github.com/edgehog-device-manager/edgehog/issues/703))
- **Volumes management feature**:
  - **Volumes page** – lists all existing volumes and allows navigation to individual volume pages.
  - **Volume page** – displays details of a selected volume, including its label, driver, and options.
  - **VolumeCreate page** – enables creating a new volume with fields for label, driver, and options.
- Added delete action for release in the releases table of an application
- Added delete action for application in the applications table
- Implemented networks management feature, enabling users to view and create networks.
  - **Networks page** – lists all existing networks and allows navigation to individual network pages.
  - **Network page** – displays details of a selected network, including its label, driver, internal, enableIpv6, and options.
  - **NetworkCreate page** – enables creating a new network with fields for label, driver, internal, enableIpv6, and options.
- Implemented deployments overview with **Deployments page** - lists all deployments and enables filtering by app, release, device.

### Changed

- BREAKING: GraphQL API that return unbounded lists now use Relay/keyset pagination. Edgehog's dashboard now relies on server-side pagination for queries and filtering, and uses tables with infinite scrolling instead of client-side paginated tables.

## [0.9.3] - 2025-05-22

### Fixed

- Base Image deletion in S3 storage
- Update Campaign executor crashing when handling events because of `device` relationship not loaded ([#828](https://github.com/edgehog-device-manager/edgehog/pull/828)).

## [0.9.2] - 2024-12-09

### Added

- Add pattern matching support to device selector DSL with new `~=` and `!~=` operators

### Changed

- Update the docker-compose configuration to allow both physical and virtual devices
  to connect to Edgehog, provided that the devices and the host are on the same LAN.

## [0.9.1] - 2024-10-28

### Fixed

- Allow receiving `trigger_name` key in trigger payload, which is sent by Astarte >= 1.2.0.

## [0.9.0] - 2024-10-25

### Fixed

- Correctly support automatic login attempts on the frontend regardless of existing auth sessions ([#596](https://github.com/edgehog-device-manager/edgehog/pull/596)).
- Fix file upload for creating base images that was failing due to a regression that left out the `version` parameter, needed for uploading the file ([#600](https://github.com/edgehog-device-manager/edgehog/pull/600)).

### Added

- Check whether `URL_HOST` is a valid host and not a url ([#595](https://github.com/edgehog-device-manager/edgehog/issues/595)).

## [0.9.0-rc.2] - 2024-09-11

### Fixed

- Correctly scope Base Image uploads to their Base Image Collection bucket.
- Show a better error when trying to delete a Base Image or Update Channel connected to an existing
  Update Campaign.

### Added

- Support redirection to a specific page after successful authentication

## [0.9.0-rc.1] - 2024-07-10

### Fixed

- Wrong input params used in GraphQL mutation when creating a base image, leading to a rejected operation ([#574](https://github.com/edgehog-device-manager/edgehog/pull/574)).
- Fix docker-compose local build.
- Fix OTA operation events not being handled, leading to a successful OTA operation while the device was still pending.

## [0.9.0-rc.0] - 2024-07-08

### Added

- Allow generating admin JWT using `gen-edgehog-jwt`.

### Changed

- Change logo and brand images with the latest brand revision.
- BREAKING: The Admin API is now JSON-API compliant, which implies a slightly different format,
  check out the newly added OpenAPI document.
- BREAKING: This release includes some breaking changes in the GraphQL API, make sure to check out
  the GraphQL schema if you were using the APIs directly. Note that we _could_ add more breaking
  changes before the final release.

## [0.8.0] - 2024-03-29

### Changed

- Configure cookie attribute based on protocol.
- Normalize triggers when comparing them for reconciliation to avoid useless reconciliations.

## [0.8.0-rc.1] - 2024-03-22

### Fixed

- Fix query limits on Astarte datastream interfaces, leading to parsing failures on some interfaces.

## [0.8.0-rc.0] - 2024-03-21

### Added

- Add support for an instance of [Edgehog Device Forwarder](https://github.com/edgehog-device-manager/edgehog_device_forwarder). When configured,
  forwarding functionalities are enabled for devices that support forwarding connections to their
  internal services, allowing features such as remote terminal sessions
  ([#447](https://github.com/edgehog-device-manager/edgehog/pull/447)).

## [0.7.1] - 2024-02-01

### Added

- Add Admin API to [create](https://github.com/edgehog-device-manager/edgehog/pull/400) and
  to [delete](https://github.com/edgehog-device-manager/edgehog/pull/416) tenants.
- Add a reconciler that takes care of installing Astarte resources (interfaces and triggers) for a
  tenant ([#403](https://github.com/edgehog-device-manager/edgehog/pull/403)).
- BREAKING: Add mandatory `URL_HOST` env variable. It must point to the host where the Edgehog
  backend is exposed.

### Fixed

- Fix seeds not working when used outside docker.
- Fix seeds's default values not working correctly.

## [0.7.0] - 2023-10-06

### Fixed

- Don't crash the OTA campaign if a misconfigured device doesn't send its base image version.
- Correctly return stats even for OTA campaigns with no targets.
- Handle empty string when translating legacy OTAResponse messages.
- Deduplicate tags in list of existing device tags.

## [0.7.0-alpha.1] - 2023-09-12

### Added

- Expose OTA Campaigns stats.

### Fixed

- Fix DevicesTable component for devices without SystemModel.

### Changed

- Enhance the OTA Campaigns frontend, using the exposed stats.

## [0.7.0-alpha.0] - 2023-07-28

### Added

- Add support for device tags ([#191](https://github.com/edgehog-device-manager/edgehog/pull/191), [#212](https://github.com/edgehog-device-manager/edgehog/pull/212)).
- Add support for device custom attributes
  ([#205](https://github.com/edgehog-device-manager/edgehog/pull/205)).
- Add `MAX_UPLOAD_SIZE_BYTES` env variable to define the maximum dimension for uploads (particularly
  relevant for OTA updates). Defaults to 4 GB.
- Allow creating and managing groups based on selectors.
- Add support for device's `network_interfaces` ([#231](https://github.com/edgehog-device-manager/edgehog/pull/231), [#232](https://github.com/edgehog-device-manager/edgehog/pull/232)).
- Add support for base image collections ([#229](https://github.com/edgehog-device-manager/edgehog/pull/229), [#230](https://github.com/edgehog-device-manager/edgehog/pull/230)).
- Add support for base images ([#240](https://github.com/edgehog-device-manager/edgehog/pull/240), [#244](https://github.com/edgehog-device-manager/edgehog/pull/244)).
- Add support for update channels
  ([#243](https://github.com/edgehog-device-manager/edgehog/pull/243), [#245](https://github.com/edgehog-device-manager/edgehog/pull/245)).
- Add support for
  [`io.edgehog.devicemanager.OTAEvent`](https://github.com/edgehog-device-manager/edgehog-astarte-interfaces/pull/58).
- Add support for
  [`io.edgehog.devicemanager.OTARequest`
  v1.0](https://github.com/edgehog-device-manager/edgehog-astarte-interfaces/pull/57).
- Add OTA Campaigns execution support.

### Changed

- Handle Device part numbers for nonexistent system models.
- BREAKING: The `Description` field in the `SystemModel` object is now a `String` instead of a
  `LocalizedText`.

### Deprecated

- Support for `io.edgehog.devicemanager.OTAResponse` is deprecated and will be removed in future
  releases. Switch to `io.edgehog.devicemanager.OTAEvent` instead.
- Support for `io.edgehog.devicemanager.OTARequest` with major version `0` is deprecated and will be
  removed in future releases. Switch to `io.edgehog.devicemanager.OTARequest` major version `1`
  instead.

## [0.5.2] - 2022-06-22

### Added

- Expose Prometheus metrics and a /health API endpoint.

### Changed

- Start using logfmt as logging format.

### Fixed

- Use the tenant's default locale when managing translated descriptions if the user's locale is not
  available.

## [0.5.1] - 2022-06-01

### Added

- Add `connected` field to wifi scan result and highlight the latest connected network
  ([#193](https://github.com/edgehog-device-manager/edgehog/pull/193)).

### Changed

- Change Geo IP provider from FreeGeoIP to IPBase
  ([#190](https://github.com/edgehog-device-manager/edgehog/pull/190)). This is a breaking change,
  make sure to update the `FREEGEOIP_API_KEY` env to `IPBASE_API_KEY`.

### Fixed

- Add a workaround to correctly parse Astarte datastreams even if AppEngine API shows them with a
  inconsistent format ([#194](https://github.com/edgehog-device-manager/edgehog/pull/194)).

## [0.5.0] - 2022-03-22

### Added

- Initial Edgehog release.
