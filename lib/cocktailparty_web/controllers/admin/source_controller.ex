defmodule CocktailpartyWeb.Admin.SourceController do
  use CocktailpartyWeb, :controller
  require Logger

  import Cocktailparty.Util

  alias Cocktailparty.UserManagement
  alias Cocktailparty.Catalog
  alias Cocktailparty.Catalog.Source
  alias CocktailpartyWeb.Tracker
  alias Cocktailparty.Input

  def index(conn, _params) do
    sources = Catalog.list_sources()
    render(conn, :index, sources: sources)
  end

  def new(conn, _params) do
    changeset = Catalog.change_source(%Source{})
    # get list of redis instances
    connections = Input.list_connections()

    # Build the map of connection IDs to source types with required fields
    connection_source_types = build_connection_source_types(connections)

    case connections do
      [] ->
        conn
        |> put_flash(:error, "A connection is required to create a source.")
        |> redirect(to: ~p"/admin/connections")

      _ ->
        render(conn, :new,
          changeset: changeset,
          connections: connections,
          connection_source_types: connection_source_types,
          source_types: []
        )
    end
  end

  def create(conn, %{"source" => source_params}) do
    # {:ok, config_str} = Map.fetch(source_params, "config")
    # config = YamlElixir.read_from_string!(config_str)

    # case Catalog.create_source(Map.put(source_params, "config", config)) do
    case Catalog.create_source(source_params) do
      {:ok, source} ->
        conn
        |> put_flash(:info, "Source created successfully.")
        |> redirect(to: ~p"/admin/sources/#{source}")

      {:error, %Ecto.Changeset{} = changeset} ->
        # txt_config = Ymlr.document!(changeset.changes.config)
        # new_changes = Map.put(changeset.changes, :config, txt_config)
        # new_changeset = Map.put(changeset, :changes, new_changes)

        # Get source types based on submitted connection_id
        source_types = get_source_types_from_params(source_params)

        # get list of connections
        connections = Input.list_connections()
        connection_source_types = build_connection_source_types(connections)

        render(conn, :new,
          changeset: changeset,
          connections: connections,
          connection_source_types: connection_source_types,
          source_types: source_types
        )
    end
  end

  def show(conn, %{"id" => id}) do
    source = Catalog.get_source_map!(id)

    # Any feed
    # connected_users = Tracker.get_all_connected_users_feeds()

    # Only this feed
    connected_users = Tracker.get_all_connected_users_to_feed(source.id)

    connected_by_public =
      UserManagement.list_users()
      |> Enum.filter(&Enum.member?(connected_users, &1.id))

    updated_users =
      Enum.reduce(source.users, [], fn user, updated_users ->
        updated_user = Map.put(user, :is_present, Enum.member?(connected_users, user.id))
        [updated_user | updated_users]
      end)

    sample = Catalog.get_sample(id)
    source = %{source | users: updated_users}

    # we add edition logic here for the subscribtion modal
    all_users = UserManagement.list_users_short()

    get_src_users =
      Enum.reduce(source.users, [], fn user, acc ->
        acc ++ [%{id: user.id, email: user.email}]
      end)

    potential_subscribers =
      Enum.reduce(all_users, [], fn user, acc ->
        if !Enum.member?(get_src_users, user) do
          acc ++ [user]
        else
          acc
        end
      end)

    changeset = Catalog.change_source(source)

    render(conn, :show,
      source: source,
      sample: sample,
      potential_subscribers: potential_subscribers,
      connected_users: connected_by_public,
      changeset: changeset
    )
  end

  def edit(conn, %{"id" => id}) do
    # source = Catalog.get_source_text!(id)
    source = Catalog.get_source!(id)
    changeset = Catalog.change_source(source)
    # get list of connections
    connections = Input.list_connections()

    # Convert the config map to a YAML string and set it in the changeset
    config_yaml = map_to_yaml!(source.config)
    changeset = Ecto.Changeset.put_change(changeset, :config_yaml, config_yaml)

    # Build the map of connection IDs to source types with required fields
    connection_source_types = build_connection_source_types(connections)

    # Get source types for the current connection
    connection = Input.get_connection!(source.connection_id)

    source_types =
      Catalog.get_available_source_types(connection.id) |> Enum.map(&{&1.type, &1.type})

    case connections do
      [] ->
        conn
        |> put_flash(:error, "At least one connection is required to edit a source.")
        |> redirect(to: ~p"/admin/connections")

      _ ->
        render(conn, :edit,
          source: source,
          changeset: changeset,
          connections: connections,
          connection_source_types: connection_source_types,
          source_types: source_types
        )
    end
  end

  def update(conn, %{"id" => id, "source" => source_params}) do
    # source = Catalog.get_source_text!(id)
    source = Catalog.get_source!(id)
    # get list of redis instances
    connections = Input.list_connections()
    connection_source_types = build_connection_source_types(connections)

    # yaml_config = source_params["config"]

    # case YamlElixir.read_from_string(yaml_config) do
    # case YamlElixir.read_from_string(yaml_config) do
    # {:ok, config_map} ->
    # source_params = Map.put(source_params, "config", config_map)

    case Catalog.update_source(source, source_params) do
      {:ok, source} ->
        conn
        |> put_flash(:info, "Source updated successfully.")
        |> redirect(to: ~p"/admin/sources/#{source}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit,
          source: source,
          changeset: changeset,
          connections: connections,
          connection_source_types: connection_source_types
        )
    end

    # {:error, reason = %YamlElixir.ParsingError{}} ->
    #   conn
    #   |> put_flash(:error, "Failed to parse YAML: #{reason.message}")
    #   |> render("edit.html",
    #     source: source,
    #     changeset: Source.changeset(source, source_params),
    #     connections: connections
    #   )
    # end
  end

  def delete(conn, %{"id" => id}) do
    source = Catalog.get_source_text!(id)
    {:ok, _source} = Catalog.delete_source(source)

    conn
    |> put_flash(:info, "Source deleted successfully.")
    |> redirect(to: ~p"/admin/sources")
  end

  def subscribe(conn, %{"source" => %{"user_id" => user_id}, "source_id" => source_id}) do
    Logger.debug("Subscribing user #{user_id} to source #{source_id}")

    case Catalog.subscribe(source_id, user_id) do
      {:ok, _source} ->
        conn
        |> put_flash(:info, "User subscribed")
        |> redirect(to: ~p"/admin/sources/#{source_id}")

      {:error, changeset} ->
        conn
        |> put_flash(:error, changeset)
        |> redirect(to: ~p"/admin/sources")
    end
  end

  def mass_subscribe(conn, %{"source_id" => source_id}) do
    Logger.debug("Subscribing all potential users to source #{source_id}")

    case Catalog.mass_subscribe(source_id) do
      {:ok, _source} ->
        conn
        |> put_flash(:info, "Users subscribed")
        |> redirect(to: ~p"/admin/sources/#{source_id}")

      {:error, _} ->
        conn
        |> put_flash(:error, "Users not subscribed")
        |> redirect(to: ~p"/admin/sources/#{source_id}")
    end
  end

  @spec unsubscribe(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def unsubscribe(conn, %{"user_id" => user_id, "source_id" => source_id}) do
    Logger.debug("Unsubscribing user #{user_id} from source #{source_id}")

    case Catalog.unsubscribe(
           String.to_integer(source_id),
           String.to_integer(user_id)
         ) do
      {1, _deleted} ->
        conn
        |> put_flash(:info, "User unsubscribed")
        |> redirect(to: ~p"/admin/sources/#{source_id}")

      {0, _deleted} ->
        conn
        |> put_flash(:error, "Unsubscribing user failed")
        |> redirect(to: ~p"/admin/sources/#{source_id}")
    end
  end

  def mass_unsubscribe(conn, %{"source_id" => source_id}) do
    Logger.debug("Unsubscribing all users from source #{source_id}")

    case Catalog.mass_unsubscribe(source_id) do
      {number, nil} ->
        conn
        |> put_flash(:info, "#{number} Users unsubscribed")
        |> redirect(to: ~p"/admin/sources/#{source_id}")

      {:error, _} ->
        conn
        |> put_flash(:error, "Users not unsubscribed")
        |> redirect(to: ~p"/admin/sources/#{source_id}")
    end
  end

  defp build_connection_source_types(connections) do
    Enum.reduce(connections, %{}, fn connection, acc ->
      source_types = Catalog.get_available_source_types(connection.id)

      source_type_info =
        Enum.map(source_types, fn source_type ->
          {:ok, required_fields} =
            Catalog.SourceType.get_required_fields(connection.type, source_type.type)

          %{
            type: source_type.type,
            required_fields: Enum.map(required_fields, &Atom.to_string/1)
          }
        end)

      Map.put(acc, Integer.to_string(connection.id), source_type_info)
    end)
  end

  defp get_source_types_from_params(%{"connection_id" => connection_id})
       when connection_id != "" do
    connection = Input.get_connection!(connection_id)
    Catalog.get_available_source_types(connection.id) |> Enum.map(&{&1.type, &1.type})
  end

  defp get_source_types_from_params(_), do: []
end
