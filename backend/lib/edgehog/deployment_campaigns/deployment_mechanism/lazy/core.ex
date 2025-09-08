#
# This file is part of Edgehog.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Edgehog.DeploymentCampaigns.DeploymentMechanism.Lazy.Core do
  @moduledoc """
  Lazy executor core pure funcitons.
  """
  alias Edgehog.Containers
  alias Edgehog.DeploymentCampaigns
  alias Edgehog.DeploymentCampaigns.DeploymentCampaign
  alias Edgehog.DeploymentCampaigns.DeploymentTarget
  alias Edgehog.Error.AstarteAPIError
  alias Edgehog.PubSub

  @doc """
  Fetches a deployment campaign by its ID and tenant ID, raising an error if not found.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - campaign_id: The ID of the deployment campaign.

  ## Returns
    - The deployment campaign struct.
  """
  def get_deployment_campaign!(tenant_id, campaign_id) do
    DeploymentCampaigns.fetch_campaign!(campaign_id, tenant: tenant_id, load: [:release])
  end

  def get_target!(tenant_id, target_id) do
    DeploymentCampaigns.fetch_target!(target_id, tenant: tenant_id)
  end

  @doc """
  Fetches the containers associated with a given release.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - release: The release struct.

  ## Returns
    - A list of containers associated with the release.
  """
  def get_release_containers(tenant_id, release) do
    release
    |> Ash.load!(:containers, tenant: tenant_id)
    |> Map.get(:containers)
  end

  @doc """
  Fetches the networks associated with a given container.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - container: The container struct.

  ## Returns
    - A list of networks associated with the container.
  """
  def get_container_networks(tenant_id, container) do
    container
    |> Ash.load!(:networks, tenant: tenant_id)
    |> Map.get(:networks)
  end

  @doc """
  Fetches the volumes associated with a given container.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - container: The container struct.

  ## Returns
    - A list of volumes associated with the container.
  """
  def get_container_volumes(tenant_id, container) do
    container
    |> Ash.load!(:volumes, tenant: tenant_id)
    |> Map.get(:volumes)
  end

  @doc """
  Fetches the image associated with a given container.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - container: The container struct.

  ## Returns
    - The image associated with the container.
  """
  def get_container_image(tenant_id, container) do
    container
    |> Ash.load!(:image, tenant: tenant_id)
    |> Map.get(:image)
  end

  @doc """
  Fetches the total target count for a given deployment campaign.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - campaign: The deployment campaign struct.

  ## Returns
    - The total number of deployment targets associated with the campaign.
  """
  def get_target_count(tenant_id, campaign) do
    campaign
    |> Ash.load!(:total_target_count, tenant: tenant_id)
    |> Map.get(:total_target_count)
  end

  @doc """
  Marks a deployment campaign as in progress.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - campaign: The deployment campaign struct.

  ## Returns
    - The updated deployment campaign struct marked as in progress.
  """
  def mark_deployment_campaign_in_progress!(campaign) do
    DeploymentCampaigns.mark_campaign_in_progress!(campaign)
  end

  @doc """
  Marks a deployment campaign as failed.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - campaign: The deployment campaign struct.

  ## Returns
    - The updated deployment campaign struct marked as failed.
  """
  def mark_deployment_campaign_as_failed!(campaign) do
    DeploymentCampaigns.mark_campaign_failed!(campaign)
  end

  @doc """
  Marks a deployment campaign as successful.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - campaign: The deployment campaign struct.

  ## Returns
    - The updated deployment campaign struct marked as successful.
  """
  def mark_deployment_campaign_as_successful!(campaign) do
    DeploymentCampaigns.mark_campaign_successful!(campaign)
  end

  def mark_deployment_as_timed_out!(tenant_id, deployment) do
    # TODO: add timneout information on the deplyment and correctly handle this case
    Containers.mark_deployment_as_errored!(deployment, "timed out.", tenant: tenant_id)
  end

  @doc """
  Fetches the failed target count for a given deployment campaign.

  ## Parameters
    - campaign: The deployment campaign struct.

  ## Returns
    - The number of failed deployment targets associated with the campaign.
  """
  def get_failed_target_count(tenant_id, campaign_id) do
    tenant_id
    |> get_deployment_campaign!(campaign_id)
    |> Ash.load!(:failed_target_count)
    |> Map.get(:failed_target_count)
  end

  @doc """
  Fetches the in progress target count for a given deployment campaign.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - campaign: The deployment campaign struct.

  ## Returns
    - The number of in progress deployment targets associated with the campaign.
  """
  def get_in_progress_target_count(tenant_id, campaign_id) do
    tenant_id
    |> get_deployment_campaign!(campaign_id)
    |> Ash.load!(:in_progress_target_count, tenant: tenant_id)
    |> Map.get(:in_progress_target_count)
  end

  @doc """
  Fetches the available slots for a given deployment campaign.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - in_progress_count: the count of in progress targets

  ## Returns
    - The number of available slots for deployment targets.
  """
  def available_slots(mechanism, in_progress_count) do
    max(0, mechanism.max_in_progress_deployments - in_progress_count)
  end

  @doc """
  Fetches the list of targets the the campaign with `in_progress` state.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - deployment_campaign_id: the deployment campaign to check.

  ## Returns
    - A list of targets
  """
  def list_in_progress_targets(tenant_id, deployment_campaign_id) do
    DeploymentCampaigns.list_in_progress_targets!(deployment_campaign_id,
      tenant: tenant_id
    )
  end

  @doc """
  Subscribes to updates for a specific deployment.

  ## Parameters
    - deployment_id: The ID of the deployment to subscribe to.

  ## Returns
    - :ok if the subscription is successful, otherwise raises an error.
  """
  def subscribe_to_deployment_updates!(deployment_id) do
    with {:error, reason} <- PubSub.subscribe_to_events_for({:deployment, deployment_id}) do
      raise reason
    end
  end

  @doc """
  Fetches the next valid deployment target for a given deployment campaign.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - deployment_campaign_id: The ID of the deployment campaign.

  ## Returns
    - the next valid target for the campaign.
  """
  def fetch_next_valid_target(tenant_id, deployment_campaign_id) do
    DeploymentCampaigns.fetch_next_valid_target(deployment_campaign_id, tenant: tenant_id)
  end

  @doc """
  Checks whether a deployment campaign has idle targets

  ## Parameters
    - tenant_id: the ID of the Tenant
    - deployment_campaign_id: the deployment campaign to check

  ## Returns
    - `true` | `false`
  """
  def has_idle_targets?(tenant_id, deployment_campaign_id) do
    deployment_campaign =
      Ash.get!(DeploymentCampaign, deployment_campaign_id,
        tenant: tenant_id,
        load: [:idle_target_count]
      )

    deployment_campaign.idle_target_count > 0
  end

  @doc delegate_to: {DeploymentCampaigns, :mark_target_as_failed!, 2}
  def mark_target_as_failed!(target, now \\ DateTime.utc_now()) do
    DeploymentCampaigns.mark_target_as_failed!(target, %{completion_timestamp: now})
  end

  @doc delegate_to: {DeploymentCampaigns, :mark_target_as_successful!, 2}
  def mark_target_as_successful!(target, now \\ DateTime.utc_now()) do
    DeploymentCampaigns.mark_target_as_successful!(target, %{completion_timestamp: now})
  end

  @doc """
  Returns whether the deployment is ready or not.

  ## Parameters
    - deployment: the deployment to check.

  ## Returns
    - `true` if the deployment is _ready_, meaning that the device has ackd the deployment description.
    - `false` if the deployment description has not been ackd by the device.
  """
  def deployment_ready?(deployment) do
    deployment
    |> Ash.load!(:ready?)
    |> Map.get(:ready?)
  end

  @doc """
  Fetches the deployment target associated with a given deployment ID.

  ## Parameters
    - tenant_id: The ID of the tenant.
    - deployment_id: The ID of the deployment.

  ## Returns
    - The deployment target struct associated with the deployment ID.
  """
  def get_target_for_deployment!(tenant_id, deployment_id) do
    DeploymentCampaigns.fetch_target_by_deployment!(deployment_id, tenant: tenant_id)
  end

  @doc """
  Tests whether the target can be retried based on the mechanism settings.

  ## Parameters
    - target: the considered target.
    - mechanism: the mechanism settings.

  ## Returns
    - `true`: if the target has less retries then the number allowed by the
      mechanism settings.
    - `false`: otherwise.
  """
  def can_retry?(target, mechanism) do
    target.retry_count < mechanism.create_request_retries
  end

  @doc delegate_to: {DeploymentCampaigns, :increase_target_retry_count!, 1}
  def increase_retry_count!(target) do
    DeploymentCampaigns.increase_target_retry_count!(target)
  end

  @doc delegate_to: {DeploymentCampaigns, :update_target_latest_attempt!, 2}
  def update_target_latest_attempt!(target, now \\ DateTime.utc_now()) do
    DeploymentCampaigns.update_target_latest_attempt!(target, now)
  end

  @doc """
  Retries the deployment associated with the target.

  ## Parameters

  ## Returns
    - `:ok` if the retry operation is successful.
  """
  def retry_target_deployment(target) do
    target
    |> Ash.load!(:deployment)
    |> Map.get(:deployment)

    # TODO: make the `retry` action
    # |> Ash.Changeset.for_update(:retry)
    # |> Ash.update!(tenant: target.tenant_id)
    :ok
  end

  @doc """
  Deploys the release to the target using the specified deployment mechanism.

  ## Parameters
    - release: The release struct to be deployed.
    - deployment_mechanism: The deployment mechanism settings.

  ## Returns
    - `{:ok, :already_deployed}`, if the release is already deployed to the target.
    - The result of the deployment operation otherwise.
  """
  def deploy(target, release, deployment_mechanism) do
    # TODO: this crashes if called multiple times. The first time creates all
    # the necessary resources, the next time, if not completely deployed, reties
    # to send all the informations but fails as the resources are already
    # present.
    if already_deployed?(target, release) do
      {:ok, :already_deployed}
    else
      do_deploy(target, release, deployment_mechanism)
    end
  end

  defp do_deploy(target, release, _deployment_mechanism) do
    target = update_target_latest_attempt!(target)

    DeploymentCampaigns.deploy_to_target(target, release)
  end

  defp already_deployed?(target, release) do
    device =
      target
      |> Ash.load!(:device)
      |> Map.get(:device)

    case Containers.deployment_by_identity(device.id, release.id, tenant: target.tenant_id) do
      {:ok, deployment} ->
        deployment
        |> Ash.load!(:ready)
        |> Map.get(:ready)

      {:error, %Ash.Error.Query.NotFound{}} ->
        false

      {:error, other_reason} ->
        raise other_reason
    end
  end

  @doc """
  Returns the number of milliseconds that should be waited before retrying to send the request to
  the target. It returns 0 if the moment to resend the request is already passed.
  This function assumes the passed target already has a pending request in flight.
  """
  def pending_deployment_request_timeout_ms(update_target, mechanism, now \\ DateTime.utc_now()) do
    %DeploymentTarget{latest_attempt: %DateTime{} = latest_attempt} = update_target

    absolute_timeout_ms = :timer.seconds(mechanism.request_timeout_seconds)
    elapsed_from_latest_request_ms = DateTime.diff(now, latest_attempt, :millisecond)

    max(0, absolute_timeout_ms - elapsed_from_latest_request_ms)
  end

  @doc """
  Returns true if the failure threshold for the rollout has been exceeded
  """
  def failure_threshold_exceeded?(target_count, failed_count, rollout) do
    failed_count / target_count * 100 > rollout.max_failure_percentage
  end

  # TODO: improve with more specific messages
  @doc """
  Renders a more descriptive error message based on the given reason and device id.

  ## Parameters
    - reason: the error reason.
    - device_id: the device id.

  ## Returns
    - a string describing the error.
  """
  def error_message(_reason, device_id), do: "An error occurred on device #{inspect(device_id)}"

  @doc """
  Returns `true` if the error indicated by `reason` is considered temporary.
  For now we assume only failures to reach Astarte and server errors are temporary.
  """
  def temporary_error?("connection refused"), do: true
  def temporary_error?(%AstarteAPIError{status: status}) when status in 500..599, do: true
  def temporary_error?(_reason), do: false
end
