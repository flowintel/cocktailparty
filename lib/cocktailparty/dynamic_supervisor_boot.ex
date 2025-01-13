defmodule Cocktailparty.DynamicSupervisorBoot do
  alias Cocktailparty.Input.ConnectionManager
  alias Cocktailparty.Catalog.SourceManager
  alias Cocktailparty.SinkCatalog.SinkManager
  use Supervisor

  require Logger

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def init(_init_arg) do
    children = [
      # We start the dynamic supervisor, then we use a Task
      # to start its children
      {Cocktailparty.ConnectionsDynamicSupervisor,
       name: {:global, Cocktailparty.ConnectionsDynamicSupervisor}},
      {Cocktailparty.SourcesDynamicSupervisor,
       name: {:global, Cocktailparty.SourcesDynamicSupervisor}},
      {Cocktailparty.SinksDynamicSupervisor,
       name: {:global, Cocktailparty.SinksDynamicSupervisor}},
      {Task,
       fn ->
         Logger.info("Starting Connections")
         Cocktailparty.Input.list_enabled_connections()
         |> Enum.each(fn x -> ConnectionManager.start_connection(x) end)

         Logger.info("Starting Sources")
         Cocktailparty.Catalog.list_sources()
         |> Enum.each(fn x -> SourceManager.start_source(x) end)

         Logger.info("Starting Sinks")
         Cocktailparty.SinkCatalog.list_sinks()
         |> Enum.each(fn x -> SinkManager.start_sink(x) end)
       end}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
