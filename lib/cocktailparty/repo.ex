defmodule Cocktailparty.Repo do
  use Ecto.Repo,
    otp_app: :cocktailparty,
    adapter: Ecto.Adapters.Postgres
end
