defmodule Cocktailparty.SinkCatalog.Sink do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sinks" do
    field :channel, :string
    field :description, :string
    field :name, :string
    field :type, :string

    belongs_to :user, Cocktailparty.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(sink, attrs) do
    sink
    |> cast(attrs, [:name, :description, :type, :channel])
    |> validate_required([:name, :description, :type, :channel])
    |> unique_constraint(:name)
  end
end
