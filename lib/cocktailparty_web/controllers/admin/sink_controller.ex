defmodule CocktailpartyWeb.Admin.SinkController do
  use CocktailpartyWeb, :controller

  import Cocktailparty.Util

  alias Cocktailparty.SinkCatalog
  alias Cocktailparty.SinkCatalog.Sink
  alias Cocktailparty.Input

  def index(conn, _params) do
    sinks = SinkCatalog.list_sinks_with_user()
    render(conn, :index, sinks: sinks)
  end

  def new(conn, _params) do
    changeset = SinkCatalog.change_sink(%Sink{})
    # get list of available sink connections
    connections = Input.list_sink_connections()
    # get list of users authorized to create sinks
    users = SinkCatalog.list_authorized_users()

    # Build the map of connection IDs to sink types with required fields
    connection_sink_types = build_connection_sink_types(connections)

    case connections do
      [] ->
        conn
        |> put_flash(:error, "A receiving connection is required to create a sink.")
        |> redirect(to: ~p"/admin/connections")

      _ ->
        render(conn, :new,
          changeset: changeset,
          connections: connections,
          connection_sink_types: connection_sink_types,
          sink_types: [],
          users: users
        )
    end
  end

  def create(conn, %{"sink" => sink_params}) do
    case SinkCatalog.create_sink(sink_params) do
      {:ok, sink} ->
        conn
        |> put_flash(:info, "Sink created successfully.")
        |> redirect(to: ~p"/admin/sinks/#{sink}")

      {:error, %Ecto.Changeset{} = changeset} ->
        sink_types = get_sink_types_from_params(sink_params)

        # get list of connections
        connections = Input.list_connections()
        connection_sink_types = build_connection_sink_types(connections)

        # get list of users
        users = SinkCatalog.list_authorized_users()

        render(conn, :new,
          changeset: changeset,
          connections: connections,
          connection_sink_types: connection_sink_types,
          sink_types: sink_types,
          users: users
        )
    end
  end

  # TODO presence on sinks
  def show(conn, %{"id" => id}) do
    sink = SinkCatalog.get_sink!(id)
    sample = SinkCatalog.get_sample(id)
    render(conn, :show, sink: sink, sample: sample)
  end

  def edit(conn, %{"id" => id}) do
    sink = SinkCatalog.get_sink!(id)
    changeset = SinkCatalog.change_sink(sink)
    # get list of connections
    connections = Input.list_sink_connections()

    # Convert the config map to a YAML string and set it in the changeset
    config_yaml = map_to_yaml!(sink.config)
    changeset = Ecto.Changeset.put_change(changeset, :config_yaml, config_yaml)

    # Build the map of connection IDs to sink types with required fields
    connection_sink_types = build_connection_sink_types(connections)

    # Get source types for the current connection
    connection = Input.get_connection!(sink.connection_id)

    sink_types =
      SinkCatalog.get_available_sink_types(connection.id) |> Enum.map(&{&1.type, &1.type})

    # get list of users
    users = SinkCatalog.list_authorized_users()


    case connections do
      [] ->
        conn
        |> put_flash(:error, "A receiving connection is required to edit a sink.")
        |> redirect(to: ~p"/admin/connections")

      _ ->
        render(conn, :edit,
          sink: sink,
          changeset: changeset,
          connections: connections,
          connection_sink_types: connection_sink_types,
          source_types: sink_types,
          users: users
        )
    end
  end

  def update(conn, %{"id" => id, "sink" => sink_params}) do
    sink = SinkCatalog.get_sink!(id)
    # get list of redis instances
    connections = Input.list_sink_connections()
    connection_sink_types = build_connection_sink_types(connections)

    case SinkCatalog.update_sink(sink, sink_params) do
      {:ok, sink} ->
        conn
        |> put_flash(:info, "Sink updated successfully.")
        |> redirect(to: ~p"/admin/sinks/#{sink}")

      {:error, %Ecto.Changeset{} = changeset} ->
        # get list of users
        users = SinkCatalog.list_authorized_users()

        render(conn, :edit,
          sink: sink,
          changeset: changeset,
          connections: connections,
          connection_sink_types: connection_sink_types,
          users: users
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
    sink = SinkCatalog.get_sink!(id)

    {:ok, _sink} = SinkCatalog.delete_sink(sink)

    conn
    |> put_flash(:info, "Sink deleted successfully.")
    |> redirect(to: ~p"/admin/sinks")
  end

  defp build_connection_sink_types(connections) do
    Enum.reduce(connections, %{}, fn connection, acc ->
      sink_types = SinkCatalog.get_available_sink_types(connection.id)

      sink_type_info =
        Enum.map(sink_types, fn sink_type ->
          {:ok, required_fields} =
            SinkCatalog.SinkType.get_required_fields(connection.type, sink_type.type)

          %{
            type: sink_type.type,
            required_fields: Enum.map(required_fields, &Atom.to_string/1)
          }
        end)

      Map.put(acc, Integer.to_string(connection.id), sink_type_info)
    end)
  end

  defp get_sink_types_from_params(%{"connection_id" => connection_id})
       when connection_id != "" do
    connection = Input.get_connection!(connection_id)
    SinkCatalog.get_available_sink_types(connection.id) |> Enum.map(&{&1.type, &1.type})
  end

  defp get_sink_types_from_params(_), do: []
end
