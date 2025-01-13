defmodule Cocktailparty.SinksDynamicSupervisor do
  use DynamicSupervisor

  require Logger

  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @impl true
  def init(_init_arg) do
    {:ok, sup} = DynamicSupervisor.init(strategy: :one_for_one)
    Logger.info("Sinks Dynamic Supervisor alive  with pid #{pid_to_string(self())}")
    {:ok, sup}
  end

  defp pid_to_string(pid) do
    :erlang.pid_to_list(pid)
    |> to_string
  end
end
