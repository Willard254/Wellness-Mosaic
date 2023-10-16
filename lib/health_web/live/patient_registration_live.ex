defmodule HealthWeb.PatientRegistrationLive do
  use HealthWeb, :live_view

  alias Health.Accounts
  alias Health.Accounts.Patient

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        Register for an account
        <:subtitle>
          Already registered?
          <.link navigate={~p"/patients/log_in"} class="font-semibold text-brand hover:underline">
            Sign in
          </.link>
          to your account now.
        </:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="registration_form"
        phx-submit="save"
        phx-change="validate"
        phx-trigger-action={@trigger_submit}
        action={~p"/patients/log_in?_action=registered"}
        method="post"
      >
        <.error :if={@check_errors}>
          Oops, something went wrong! Please check the errors below.
        </.error>


        <.input field={@form[:first_name]} type="text" label="First Name" required />
        <.input field={@form[:middle_name]} type="text" label="Middle Name" required />
        <.input field={@form[:last_name]} type="text" label="Last Name" required />
        <.input field={@form[:username]} type="text" label="Username" required />
        <.input field={@form[:date_of_birth]} type="date" label="Date of Birth" required />
        <.input field={@form[:weight]} type="number" label="Weight(in kgs)" required />
        <.input field={@form[:height]} type="number" label="Height(in metres)" required />
        <.input field={@form[:phone_number]} type="text" label="Phone Number" required />
        <.input field={@form[:gender]} type="text" label="Gender" required />
        <.input field={@form[:allergies]} type="text" label="Allergies" required />
        <.input field={@form[:notes]} type="text" label="Notes" required />
        <.input field={@form[:email]} type="email" label="Email" required />
        <.input field={@form[:password]} type="password" label="Password" required />

        <:actions>
          <.button phx-disable-with="Creating account..." class="w-full">Create an account</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_patient_registration(%Patient{})

    socket =
      socket
      |> assign(trigger_submit: false, check_errors: false)
      |> assign_form(changeset)

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  def handle_event("save", %{"patient" => patient_params}, socket) do
    case Accounts.register_patient(patient_params) do
      {:ok, patient} ->
        {:ok, _} =
          Accounts.deliver_patient_confirmation_instructions(
            patient,
            &url(~p"/patients/confirm/#{&1}")
          )

        changeset = Accounts.change_patient_registration(patient)
        {:noreply, socket |> assign(trigger_submit: true) |> assign_form(changeset)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}
    end
  end

  def handle_event("validate", %{"patient" => patient_params}, socket) do
    changeset = Accounts.change_patient_registration(%Patient{}, patient_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "patient")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end
end
