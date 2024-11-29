defmodule Cocktailparty.SinkCatalog.Sink do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sinks" do
    field :name, :string
    field :type, :string
    field :config, :map
    field :config_yaml, :string, virtual: true
    field :description, :string

    belongs_to :user, Cocktailparty.Accounts.User
    belongs_to :connection, Cocktailparty.Input.Connection

    timestamps()
  end

  @doc false
  def changeset(sink, attrs) do
    sink
    |> cast(attrs, [:name, :type, :description, :config_yaml, :connection_id, :user_id])
    |> validate_required([:name, :type])
    |> validate_required_config_yaml(attrs)
    |> unique_constraint(:name)
    |> parse_yaml()
    |> validate_config_fields()
  end

  defp validate_required_config_yaml(changeset, attrs) do
    # Only validate presence of config_yaml if it's provided in attrs
    if Map.has_key?(attrs, "config_yaml") do
      validate_required(changeset, [:config_yaml])
    else
      changeset
    end
  end

  defp parse_yaml(changeset) do
    config_yaml = get_field(changeset, :config_yaml) || ""

    case YamlElixir.read_from_string(config_yaml) do
      {:ok, config_map} when is_map(config_map) ->
        put_change(changeset, :config, config_map)

      {:ok, _} ->
        add_error(changeset, :config_yaml, "must be a valid YAML mapping")

      {:error, reason} ->
        add_error(changeset, :config_yaml, "invalid YAML format: #{inspect(reason)}")
    end
  end

  defp validate_config_fields(changeset) do
    if changeset.valid? do
      connection_id = get_field(changeset, :connection_id)
      sink_type = get_field(changeset, :type)
      config = get_field(changeset, :config) || %{}

      connection = Cocktailparty.Input.get_connection!(connection_id)
      with {:ok, required_fields} <- Cocktailparty.SinkCatalog.SinkType.get_required_fields(connection.type, sink_type) do
        missing_fields =
          required_fields
          |> Enum.filter(fn field -> Map.get(config, to_string(field)) in [nil, ""] end)

        if missing_fields == [] do
          changeset
        else
          Enum.reduce(missing_fields, changeset, fn field, acc ->
            add_error(acc, :config_yaml, "missing required field: #{field}")
          end)
        end
      else
        _ -> add_error(changeset, :type, "is invalid")
      end
    else
      changeset
    end
  end


end
