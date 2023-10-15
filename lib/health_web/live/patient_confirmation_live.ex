defmodule HealthWeb.PatientConfirmationLive do
  use HealthWeb, :live_view

  alias Health.Accounts

  def render(%{live_action: :edit} = assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">Confirm Account</.header>

      <.simple_form for={@form} id="confirmation_form" phx-submit="confirm_account">
        <.input field={@form[:token]} type="hidden" />
        <:actions>
          <.button phx-disable-with="Confirming..." class="w-full">Confirm my account</.button>
        </:actions>
      </.simple_form>

      <p class="text-center mt-4">
        <.link href={~p"/patients/register"}>Register</.link>
        | <.link href={~p"/patients/log_in"}>Log in</.link>
      </p>
    </div>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    form = to_form(%{"token" => token}, as: "patient")
    {:ok, assign(socket, form: form), temporary_assigns: [form: nil]}
  end

  # Do not log in the patient after confirmation to avoid a
  # leaked token giving the patient access to the account.
  def handle_event("confirm_account", %{"patient" => %{"token" => token}}, socket) do
    case Accounts.confirm_patient(token) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Patient confirmed successfully.")
         |> redirect(to: ~p"/")}

      :error ->
        # If there is a current patient and the account was already confirmed,
        # then odds are that the confirmation link was already visited, either
        # by some automation or by the patient themselves, so we redirect without
        # a warning message.
        case socket.assigns do
          %{current_patient: %{confirmed_at: confirmed_at}} when not is_nil(confirmed_at) ->
            {:noreply, redirect(socket, to: ~p"/")}

          %{} ->
            {:noreply,
             socket
             |> put_flash(:error, "Patient confirmation link is invalid or it has expired.")
             |> redirect(to: ~p"/")}
        end
    end
  end
end
