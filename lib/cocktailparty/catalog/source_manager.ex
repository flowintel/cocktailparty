defmodule Cocktailparty.Catalog.SourceManager do
  @moduledoc """
  Manages the starting and stopping of source processes.
  """

  alias Cocktailparty.Catalog
  alias Cocktailparty.Input
  alias Cocktailparty.Catalog.SourceType

  require Logger

  @doc """
  Starts a source process based on the given source schema.
  """
  def start_source(%Catalog.Source{} = source_schema) do
    with %Input.Connection{type: connection_type} <-
           Input.get_connection!(source_schema.connection_id),
         {:ok, module} <- SourceType.get_module(connection_type, source_schema.type),
         :ok <- validate_required_fields(module, source_schema),
         pid_sds <- :global.whereis_name(Cocktailparty.SourcesDynamicSupervisor),
         {:ok, pid} <- DynamicSupervisor.start_child(pid_sds, {module, source_schema}) do
      :global.register_name({:source, source_schema.id}, pid)
      :ok
    else
      {:error, reason} ->
        Logger.error("Failed to start source #{source_schema.id}: #{inspect(reason)}")
        {:error, reason}

      :undefined ->
        msg =
          "Failed to start source #{source_schema.id}: Cocktailparty.SourcesDynamicSupervisor not found"

        Logger.error(msg)
        {:error, msg}

      error ->
        Logger.error("Failed to start source #{source_schema.id}: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Stops a source process given its ID.
  """
  def stop_source(source_id) do
    pid_sds = :global.whereis_name(Cocktailparty.SourcesDynamicSupervisor)
    pid = :global.whereis_name({:source, source_id})

    cond do
      pid_sds == :undefined ->
        :ok

      pid == :undefined ->
        :ok

      true ->
        DynamicSupervisor.terminate_child(pid_sds, pid)
    end
  end

  @doc """
  Restart a source process given a source id
  """
  def restart_source(id) do
    with src <- Cocktailparty.Catalog.get_source!(id),
         :ok <- stop_source(src.id) do
      start_source(src)
    else
      _ ->
        Logger.error("Cannot restart process for source #{id} -- not running")
    end
  end

  defp validate_required_fields(module, source_schema) do
    required_fields = module.required_fields()
    config = source_schema.config || %{}

    missing_fields =
      required_fields
      |> Enum.filter(fn field ->
        Map.get(config, Atom.to_string(field)) in [nil, ""]
      end)

    if missing_fields == [] do
      :ok
    else
      {:error, {:missing_fields, missing_fields}}
    end
  end
end
