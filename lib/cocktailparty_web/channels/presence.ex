defmodule CocktailpartyWeb.Presence do
  use Phoenix.Presence,
    otp_app: :cocktailparty,
    pubsub_server: Cocktailparty.PubSub

  alias Cocktailparty.Catalog

  @doc """
  Returns the list of id of the connected users

  ## Examples

      iex> get_all_connected_users()
      ["8"]
  """
  def get_all_connected_users() do
    sources = Catalog.list_sources()

    feeds =
      Enum.reduce(sources, [], fn source, feeds ->
        ["feed:" <> Integer.to_string(source.id) | feeds]
      end)

    connected_clients =
      Enum.reduce(feeds, %{}, fn feed, connected_clients ->
        inspect(list(feed))
        Map.merge(list(feed), connected_clients)
      end)

    Map.keys(connected_clients)
  end
end
