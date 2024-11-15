#
# This file is part of Edgehog.
#
# Copyright 2023-2024 SECO Mind Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0
#

{
  description = "Open Source software focused on the management of the whole life-cycle of IoT devices";
  inputs = {
    nixpkgs.url = "nixpkgs/nixpkgs-unstable";
    elixir-utils = {
      url = "github:noaccOS/elixir-utils";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };
  outputs =
    {
      self,
      elixir-utils,
      flake-parts,
      ...
    }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      flake.overlays.tools = elixir-utils.lib.asdfOverlay {
        toolVersions = ../.tool-versions ;
        wxSupport = false;
      };

      systems = elixir-utils.lib.defaultSystems;

      perSystem =
        { pkgs, system, ... }:
        {
          _module.args.pkgs = import self.inputs.nixpkgs {
            inherit system;
            overlays = [ self.overlays.tools ];
          };

          devShells.default = pkgs.elixirDevShell;
          formatter = pkgs.nixfmt-rfc-style;
        };
    };
}
