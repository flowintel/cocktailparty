defmodule Cocktailparty.DynamicSupervisorBoot do
  use Supervisor

  require Logger
  import Cocktailparty.Input

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def init(_init_arg) do
    children = [
      # We start the dynamic supervisor, then we use a Task
      # to start its children
      {Cocktailparty.RedisInstancesDynamicSupervisor, []},
      {Task,
       fn ->
         Logger.info("Redis Instances Dynamic Supervisor Task started")
         # When starting we check what inputs are available
         # for each instance, we start a redix connection along with a broker gen_server
         list_redisinstances()
         |> Enum.each(fn x -> Cocktailparty.RedisInstancesDynamicSupervisor.start_child(x) end)
       end}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
