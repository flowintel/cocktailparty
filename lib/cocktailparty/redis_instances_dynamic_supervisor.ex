defmodule Cocktailparty.RedisInstancesDynamicSupervisor do
  alias Cocktailparty.Input.RedisInstance
  alias Cocktailparty.Broker
  use DynamicSupervisor

  require Logger

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def start_child(rc = %RedisInstance{}) do
    Logger.info("Supervisor Starting #{rc.name} redix driver")

    spec_redix =
      {Redix,
       host: rc.hostname, port: rc.port, name: {:global, "redix_" <> Integer.to_string(rc.id)}}

    spec_broker =
      {Broker,
       redis_instance: rc, name: {:global, {:name, "broker_" <> Integer.to_string(rc.id)}}}

    # TODO check errors and propagate (we should get {:ok, pid})
    case DynamicSupervisor.start_child(__MODULE__, spec_redix) do
      {:ok, pid} ->
        Logger.info("Redix driver alive for #{rc.name} with pid #{pid_to_string(pid)}")

        case DynamicSupervisor.start_child(__MODULE__, spec_broker) do
          {:ok, pid_broker} ->
            Logger.info("Broker initialized for #{rc.name} with pid #{pid_to_string(pid_broker)}")

          {:ok, pid_broker, info} ->
            Logger.info(
              "Broker initialized for #{rc.name} with pid #{pid_to_string(pid_broker)}, info: #{info}"
            )

          {:error, :ignore} ->
            Logger.error("Broker #{rc.name} has been ignored")
            {:error, :max_children}
            Logger.error("Broker #{rc.name} not started :max_children reached")

          {:error, {:already_started, pid_broker}} ->
            Logger.error("Broker #{rc.name} is already started as #{pid_to_string(pid_broker)}")

          {:error, err} ->
            Logger.error("Broker starting error #{inspect(err)}.")
            {:error, err}
        end

      {:ok, pid, info} ->
        Logger.info(
          "Redix driver alive for #{rc.name} with pid #{pid_to_string(pid)}, info: #{info}"
        )

      {:error, :ignore} ->
        Logger.error("Redix driver #{rc.name} has been ignored")
        {:error, :max_children}
        Logger.error("Redix driver #{rc.name} not started :max_children reached")

      {:error, {:already_started, pid}} ->
        Logger.error("Redix driver #{rc.name} is already started as #{pid_to_string(pid)}")

      {:error, err} ->
        Logger.error("Redix driver #{inspect(err)}")
        {:error, err}
    end
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  defp pid_to_string(pid) do
    :erlang.pid_to_list(pid)
    |> to_string
  end
end
