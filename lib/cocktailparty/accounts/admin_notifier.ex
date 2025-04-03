defmodule Cocktailparty.Accounts.AdminNotifier do
  use CocktailpartyWeb, :html
  import Swoosh.Email

  alias Cocktailparty.Mailer

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from(
        {Application.get_env(:cocktailparty, Cocktailparty.Accounts.AdminNotifier)[
           :instance_name
         ],
         Application.get_env(:cocktailparty, Cocktailparty.Accounts.AdminNotifier)[
           :instance_email
         ]}
      )
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to admin to confirm a user account.
  """
  def notify_new_account_creation(admin, url) do
    deliver(admin.email, "Cocktailparty: New account creation", """

    ==============================

    A new user just registered, you may confirm the user by following this link:

    #{url}

    ==============================
    """)
  end
end
