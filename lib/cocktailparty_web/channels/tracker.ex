defmodule CocktailpartyWeb.Tracker do
  @behaviour Phoenix.Tracker
  require Logger
  alias Cocktailparty.Catalog
  alias Cocktailparty.SinkCatalog

  def child_spec(opts) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, [opts]}, type: :supervisor}
  end

  def start_link(opts) do
    opts =
      opts
      |> Keyword.put(:name, __MODULE__)
      |> Keyword.put(:pubsub_server, Cocktailparty.PubSub)

    Phoenix.Tracker.start_link(__MODULE__, opts, opts)
  end

  def init(opts) do
    server = Keyword.fetch!(opts, :pubsub_server)
    {:ok, %{pubsub_server: server}}
  end

  def handle_diff(_, state) do
    {:ok, state}
  end

  def track(%{
        channel_pid: pid,
        topic: topic,
        assigns: %{remote_ip: remote_ip, current_user: current_user}
      }) do
    metadata = %{online_at: DateTime.utc_now(), current_user: current_user, remote_ip: remote_ip}
    Phoenix.Tracker.track(__MODULE__, pid, topic, current_user, metadata)
  end

  def list(topic \\ "tracked") do
    Phoenix.Tracker.list(__MODULE__, topic)
  end

  @doc """
  Returns the list of id of the users connected to feeds

  ## Examples

      iex> get_all_connected_users_feeds()
      ["8"]
  """
  def get_all_connected_users_feeds() do
    sources = Catalog.list_sources()

    feeds =
      Enum.reduce(sources, [], fn source, feeds ->
        ["feed:" <> Integer.to_string(source.id) | feeds]
      end)

    connected_clients =
      Enum.reduce(feeds, [], fn feed, accs ->
        feed_users = list(feed)

        feedu =
          Enum.reduce(feed_users, [], fn user, acc ->
            %{current_user: u} = elem(user, 1)
            [u | acc]
          end)

        feedu ++ accs
      end)

    Enum.dedup(connected_clients)
  end

  @doc """
  Returns the list of id of the users connected to sinks

  ## Examples

      iex> get_all_connected_users_sinks()
      ["8"]
  """
  def get_all_connected_users_sinks() do
    sinks = SinkCatalog.list_sinks()

    sink_chans =
      Enum.reduce(sinks, [], fn sink, sinks ->
        ["sink:" <> Integer.to_string(sink.id) | sinks]
      end)

    connected_clients =
      Enum.reduce(sink_chans, [], fn sink, accs ->
        sink_users = list(sink)

        sinku =
          Enum.reduce(sink_users, [], fn user, acc ->
            %{current_user: u} = elem(user, 1)
            [u | acc]
          end)

        sinku ++ accs
      end)

    Enum.dedup(connected_clients)
  end
end