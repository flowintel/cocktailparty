defmodule Cocktailparty.Input.RedisInstance do
  use Ecto.Schema
  import Ecto.Changeset
  alias Cocktailparty.Broker

  require Logger

  schema "redis_instances" do
    field :enabled, :boolean, default: false
    field :name, :string
    field :hostname, :string
    field :port, :integer
    field :sink, :boolean, default: false

    has_many :sources, Cocktailparty.Catalog.Source
    has_many :sinks, Cocktailparty.SinkCatalog.Sink

    timestamps()
  end

  @doc false
  def changeset(redis_instance, attrs) do
    redis_instance
    |> cast(attrs, [:name, :hostname, :port, :enabled, :sink])
    |> validate_required([:name, :hostname, :port, :enabled])
    |> unique_constraint(:name)
  end

  @doc """
  Starts a redix driver and a broker for a redis instance.

  TODO: better doc and error handling
  """
  def start(rc = %__MODULE__{}) do
    Logger.info("Supervisor Starting #{rc.name} redix driver")

    spec_redix =
      {Redix,
       host: rc.hostname, port: rc.port, name: {:global, "redix_" <> Integer.to_string(rc.id)}}

    # TODO remove the nested name (impacts catalog.ex)
    # {Broker, redis_instance: rc, name: {:global, {:name, "broker_" <> Integer.to_string(rc.id)}}}
    spec_broker =
      {Broker, redis_instance: rc, name: {:global, "broker_" <> Integer.to_string(rc.id)}}

    # We stay on the Dynamic Supervisor host
    sup = get_supervisor()
    supervisor_node = node(sup)

    case :rpc.call(supervisor_node, DynamicSupervisor, :start_child, [
           {:global, Cocktailparty.RedisInstancesDynamicSupervisor},
           spec_redix
         ]) do
      {:ok, pid} ->
        Logger.info("Redix driver alive for #{rc.name} with pid #{pid_to_string(pid)}")

        case :rpc.call(supervisor_node, DynamicSupervisor, :start_child, [
               {:global, Cocktailparty.RedisInstancesDynamicSupervisor},
               spec_broker
             ]) do
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

  @doc """
  Kill processes related to a redis instance

  """
  def terminate(rc = %__MODULE__{}) do
    Logger.info("Terminating processes for redis instance: " <> Integer.to_string(rc.id))
    sup = get_supervisor()

    case GenServer.whereis({:global, "broker_" <> Integer.to_string(rc.id)}) do
      {name, node} ->
        Logger.info("Broker is located at: #{node}/#{name}")

      nil ->
        nil

      pid ->
        DynamicSupervisor.terminate_child(sup, pid)
    end

    case GenServer.whereis({:global, "redix_" <> Integer.to_string(rc.id)}) do
      {name, node} ->
        Logger.info("Redix driver is located at: #{node}/#{name}")

      nil ->
        nil

      pid ->
        DynamicSupervisor.terminate_child(sup, pid)
    end
  end

  defp get_supervisor() do
    # locate the reponsible broker process
    case GenServer.whereis({:global, Cocktailparty.RedisInstancesDynamicSupervisor}) do
      {name, node} ->
        Logger.info("Supervisor is located at: #{node}/#{name}")
        {name, node}

      nil ->
        # TODO
        Logger.error(
          "It looks like the redis instances dynamic supervisor is dead, it's not looking good."
        )

        nil

      pid ->
        pid
    end
  end

  defp pid_to_string(pid) do
    :erlang.pid_to_list(pid)
    |> to_string
  end
end
