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
    |> cast(attrs, [:name, :type, :description, :config, :connection_id, :user_id])
    |> validate_required([:name, :type, :config])
    |> unique_constraint(:name)
  end
end
