/*
  This file is part of Edgehog.

  Copyright 2022 SECO Mind Srl

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
*/

type OTAOperationStatus = "Pending" | "InProgress" | "Error" | "Done";

type OTAOperationStatusCode =
  | "NetworkError"
  | "NVSError"
  | "AlreadyInProgress"
  | "Failed"
  | "DeployError"
  | "WrongPartition";

type OTAOperation = {
  status: OTAOperationStatus | null;
  statusCode: OTAOperationStatusCode | null;
  baseImageUrl: string;
  createdAt: Date;
  updatedAt: Date;
};

export type { OTAOperation, OTAOperationStatus, OTAOperationStatusCode };
