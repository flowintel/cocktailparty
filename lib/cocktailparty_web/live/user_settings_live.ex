defmodule CocktailpartyWeb.UserSettingsLive do
  use CocktailpartyWeb, :live_view

  alias Cocktailparty.Accounts

  def render(assigns) do
    ~H"""
    <.header class="text-center">
      Account Settings
      <:subtitle>Manage your account email address and password settings</:subtitle>
    </.header>

    <div class="space-y-12 divide-y">
      <div>
        <.simple_form
          for={@email_form}
          id="email_form"
          phx-submit="update_email"
          phx-change="validate_email"
        >
          <.input field={@email_form[:email]} type="email" label="Email" required />
          <.input
            field={@email_form[:current_password]}
            name="current_password"
            id="current_password_for_email"
            type="password"
            label="Current password"
            value={@email_form_current_password}
            required
          />
          <:actions>
            <.button phx-disable-with="Changing...">Change Email</.button>
          </:actions>
        </.simple_form>
      </div>
      <div>
        <.simple_form
          for={@password_form}
          id="password_form"
          action={~p"/users/log_in?_action=password_updated"}
          method="post"
          phx-change="validate_password"
          phx-submit="update_password"
          phx-trigger-action={@trigger_submit}
        >
          <.input
            field={@password_form[:email]}
            type="hidden"
            id="hidden_user_email"
            value={@current_email}
          />
          <.input field={@password_form[:password]} type="password" label="New password" required />
          <.input
            field={@password_form[:password_confirmation]}
            type="password"
            label="Confirm new password"
          />
          <.input
            field={@password_form[:current_password]}
            name="current_password"
            type="password"
            label="Current password"
            id="current_password_for_password"
            value={@current_password}
            required
          />
          <:actions>
            <.button phx-disable-with="Changing...">Change Password</.button>
          </:actions>
        </.simple_form>
      </div>

      <div class="space-y-8 divide-y mt-10">
        <div class="space-y-4 mt-10">
          <h2 class="text-lg font-semibold text-zinc-800">API Keys</h2>
          <p class="block text-sm leading-6 text-zinc-800">You can generate and manage your API keys here.
            Each token can be used for API authentication and can only be seen once. So store
            it somewhere and keep it safe.</p>
          <!-- Button to create a new token -->
          <.button phx-click="create_api_token" class="my-4">Generate New API Key</.button>
          <!-- If we just created a token, show it once -->
          <%= if @new_api_token do %>
            <div class="p-2 bg-gray-100 rounded mt-2 text-zinc-800">
              <p><strong>Your new API key (copy it now):</strong></p>
              <p><code><%= @new_api_token %></code></p>
            </div>
          <% end %>
          <!-- List existing tokens -->
          <table class="min-w-full divide-y divide-gray-200">
            <thead>
              <tr>
                <th scope="col" class="text-left text-zinc-800">Token ID</th>
                <th scope="col" class="text-left text-zinc-800">Inserted at</th>
                <th scope="col" class="text-left text-zinc-800">Last seen</th>
                <th scope="col" class="text-left text-zinc-800">Actions</th>
              </tr>
            </thead>
            <tbody>
              <%= for token <- @api_tokens do %>
                <tr class="min-w-full ">
                  <!-- Just an example. You can show partial token or other info. -->
                  <td class="text-left text-sm text-zinc-800">
                    <%= token.id %>
                  </td>
                  <td class="text-left text-sm text-zinc-800">
                    <%= token.inserted_at %>
                  </td>
                  <td class="text-left text-sm text-zinc-800">
                    <%= token.last_seen %>
                  </td>
                  <td class="text-left text-sm">
                    <.button
                      phx-click="delete_api_token"
                      phx-value-id={token.id}
                      data-confirm="Are you sure you want to revoke this token?"
                    >
                      Revoke
                    </.button>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_user, token) do
        :ok ->
          put_flash(socket, :info, "Email changed successfully.")

        :error ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    email_changeset = Accounts.change_user_email(user)
    password_changeset = Accounts.change_user_password(user)
    api_tokens = Accounts.list_user_api_tokens(user)

    socket =
      socket
      |> assign(:current_password, nil)
      |> assign(:email_form_current_password, nil)
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)
      |> assign(:api_tokens, api_tokens)
      |> assign(:new_api_token, nil)

    {:ok, socket}
  end

  def handle_event("validate_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    email_form =
      socket.assigns.current_user
      |> Accounts.change_user_email(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form, email_form_current_password: password)}
  end

  def handle_event("update_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case Accounts.apply_user_email(user, password, user_params) do
      {:ok, applied_user} ->
        Accounts.deliver_user_update_email_instructions(
          applied_user,
          user.email,
          &url(~p"/users/settings/confirm_email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info) |> assign(email_form_current_password: nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :email_form, to_form(Map.put(changeset, :action, :insert)))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    password_form =
      socket.assigns.current_user
      |> Accounts.change_user_password(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form, current_password: password)}
  end

  def handle_event("update_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case Accounts.update_user_password(user, password, user_params) do
      {:ok, user} ->
        password_form =
          user
          |> Accounts.change_user_password(user_params)
          |> to_form()

        {:noreply, assign(socket, trigger_submit: true, password_form: password_form)}

      {:error, changeset} ->
        {:noreply, assign(socket, password_form: to_form(changeset))}
    end
  end

  def handle_event("create_api_token", _params, socket) do
    user = socket.assigns.current_user

    token_string = Accounts.create_user_api_token(user)

    api_tokens = Accounts.list_user_api_tokens(user)

    socket =
      socket
      |> assign(:new_api_token, token_string)
      |> assign(:api_tokens, api_tokens)

    {:noreply, put_flash(socket, :info, "Token created")}
  end

  def handle_event("delete_api_token", %{"id" => token_id}, socket) do
    user = socket.assigns.current_user

    # first, find the token in user’s tokens or via Repo.get_by
    case Accounts.delete_user_api_token_by_id(user, token_id) do
      {:ok, _} ->
        api_tokens = Accounts.list_user_api_tokens(user)
        {:noreply, assign(socket, :api_tokens, api_tokens)}

      _ ->
        {:noreply, put_flash(socket, :error, "Token not found.")}
    end
  end
end
