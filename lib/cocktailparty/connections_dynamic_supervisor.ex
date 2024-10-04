defmodule Cocktailparty.ConnectionsDynamicSupervisor do
  use DynamicSupervisor
  import Cocktailparty.Util

  require Logger

  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @impl true
  def init(_init_arg) do
    {:ok, sup} = DynamicSupervisor.init(strategy: :one_for_one)
    Logger.info("Connection Dynamic Supervisor alive  with pid #{pid_to_string(self())}")
    {:ok, sup}
  end
end
