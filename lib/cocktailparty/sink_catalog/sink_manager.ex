defmodule Cocktailparty.SinkCatalog.SinkManager do
  @moduledoc """
  Manages the starting and stopping of sink processes.
  """

  alias Cocktailparty.SinkCatalog
  alias Cocktailparty.Input
  alias Cocktailparty.SinkCatalog.SinkType

  require Logger

  @doc """
  Starts a sink process based on the given sink schema.
  """
  def start_sink(%SinkCatalog.Sink{} = sink_schema) do
    with %Input.Connection{type: connection_type} <-
           Input.get_connection!(sink_schema.connection_id),
         {:ok, module} <- SinkType.get_module(connection_type, sink_schema.type),
         :ok <- validate_required_fields(module, sink_schema),
         pid_sds <- :global.whereis_name(Cocktailparty.SinksDynamicSupervisor),
         {:ok, pid} <- DynamicSupervisor.start_child(pid_sds, {module, sink_schema}) do
      :global.register_name({:sink, sink_schema.id}, pid)
      :ok
    else
      {:error, reason} ->
        Logger.error("Failed to start sink #{sink_schema.id}: #{inspect(reason)}")
        {:error, reason}

      :undefined ->
        msg =
          "Failed to start sink #{sink_schema.id}: Cocktailparty.SinksDynamicSupervisor not found"

        Logger.error(msg)
        {:error, msg}

      error ->
        Logger.error("Failed to start sink #{sink_schema.id}: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Stops a sink process given its ID.
  """
  def stop_sink(sink_id) do
    pid_sds = :global.whereis_name(Cocktailparty.SinksDynamicSupervisor)
    pid = :global.whereis_name({:sink, sink_id})

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
  Restart a sink process given a sink id
  """
  def restart_sink(id) do
    with src <- Cocktailparty.SinkCatalog.get_sink!(id),
         :ok <- stop_sink(src.id) do
      start_sink(src)
    else
      _ ->
        Logger.error("Cannot restart process for sink #{id} -- not running")
    end
  end

  defp validate_required_fields(module, sink_schema) do
    required_fields = module.required_fields()
    config = sink_schema.config || %{}

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
