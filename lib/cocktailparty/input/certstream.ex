defmodule Cocktailparty.Input.CertStream do
  use GenServer

  require Logger
  @behaviour Cocktailparty.Input.ConnectionBehavior

  @default_http_options [
    timeout: 10_000,
    recv_timeout: 10_000,
    ssl: [{:versions, [:"tlsv1.2"]}],
    follow_redirect: true
  ]

  def child_spec(opts) do
    %{
      id: Cocktailparty.Input.CertstreamWatcher,
      start: {Cocktailparty.Input.CertstreamWatcher, :start_link, opts: opts},
      restart: :permanent
    }
  end

  # We just keep the watcher superviser's pid in the state
  def init(state) do
    {:ok, state}
  end

  def start_link(connection) do
    Logger.info("Supervisor Starting #{connection.name} certstream watchers")

    # "https://www.gstatic.com/ct/log_list/v3/all_logs_list.json"

    # Add new sup to the ConnectionDynamicSupervisor children
    case :global.whereis_name(Cocktailparty.ConnectionsDynamicSupervisor) do
      :undefined ->
        {:stop, {:error, "ConnectionsDynamicSupervisor not found"}}

      pid ->
        # Fetch all CT lists
        ctl_log_info =
          connection.config["uri"]
          |> HTTPoison.get!([], @default_http_options)
          |> Map.get(:body)
          |> Jason.decode!()

        # Start a sup dedicated to the watchers
        dyn_child_spec =
          {
            DynamicSupervisor,
            strategy: :one_for_one,
            name: {:global, {connection.type, connection.id}}
          }

        {:ok, watchers_sup} =
          DynamicSupervisor.start_child(
            pid,
            dyn_child_spec
          )

        ctl_log_info
        |> Map.get("operators")
        |> Enum.each(fn operator ->
          operator
          |> Map.get("logs")
          |> Enum.each(fn log ->
            log = Map.put(log, "operator_name", operator["name"])

            opts =
              [
                # name: {:global, {"Certstream operator", operator["name"]<> "-" <>log["Description"]}},
                name: {:global, {"Certstream operator", log["description"]}},
                log: log
              ]

            _ =
              DynamicSupervisor.start_child(
                watchers_sup,
                child_spec(opts)
              )
          end)
        end)

        pid
    end
  end
end
