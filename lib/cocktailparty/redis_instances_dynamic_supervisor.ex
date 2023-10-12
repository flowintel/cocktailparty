defmodule Cocktailparty.RedisInstancesDynamicSupervisor do
  alias Cocktailparty.Input.RedisInstance
  # Automatically defines child_spec/1
  use DynamicSupervisor

  require Logger

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def start_child(rc = %RedisInstance{}) do
    # If MyWorker is not using the new child specs, we need to pass a map:
    # spec = %{id: MyWorker, start: {MyWorker, :start_link, [foo, bar, baz]}}
    Logger.info("Supervisor Starting #{rc.name}")
    spec = {Redix, host: rc.hostname, port: rc.port, name: {:global, rc.name}}
    # TODO check errors and propagate (we should get {:ok, pid})
    case DynamicSupervisor.start_child(__MODULE__, spec) do
      {:ok, pid} ->
        Logger.info("Redix driver alive for #{rc.name} with pid #{pid_to_string(pid)}")

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
        Logger.error("Redix driver error.")
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
