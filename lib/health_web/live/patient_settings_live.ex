defmodule HealthWeb.PatientSettingsLive do
  use HealthWeb, :live_view

  alias Health.Accounts

  def render(assigns) do
    ~H"""
    <.header class="text-center">
      Account Settings
      <:subtitle>
        Manage your account email address and password settings
      </:subtitle>
    </.header>

    <div class="space-y-12 divide-y">
      <div>
        <.simple_form
          for={@email_form}
          id="email_form"
          phx-submit="update_email"
          phx-change="validate_email"
        >
          <.input 
            field={@email_form[:email]} 
            type="email" 
            label="Email" 
            required 
          />
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
            <.button phx-disable-with="Changing...">
              Change Email
            </.button>
          </:actions>
        </.simple_form>
      </div>
      <div>
        <.simple_form
          for={@password_form}
          id="password_form"
          action={~p"/patients/log_in?_action=password_updated"}
          method="post"
          phx-change="validate_password"
          phx-submit="update_password"
          phx-trigger-action={@trigger_submit}
        >
          <.input
            field={@password_form[:email]}
            type="hidden"
            id="hidden_patient_email"
            value={@current_email}
          />
          <.input 
            field={@password_form[:password]} 
            type="password" 
            label="New password" 
            required 
          />
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
            <.button phx-disable-with="Changing...">
              Change Password
            </.button>
          </:actions>
        </.simple_form>
      </div>
      <div>
        <.simple_form
          for={@phone_number_form}
          id="phone_number_form"
          phx-submit="update_phone_number"
          phx-change="validate_phone_number"
        >
          <.input 
            field={@phone_number_form[:phone_number]}
            type="text" 
            label="Phone Number" 
          />
          <.input
            field={@phone_number_form[:current_password]}
            name="current_password"
            id="current_password_for_email"
            type="password"
            label="Current password"
            value={@phone_number_form_current_password}
            required
          />
          <:actions>
            <.button phx-disable-with="Changing...">
              Change Phone Number
            </.button>
          </:actions>
        </.simple_form>
      </div>
    </div>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_patient_email(socket.assigns.current_patient, token) do
        :ok ->
          put_flash(socket, :info, "Email changed successfully.")

        :error ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/patients/settings")}
  end

  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_patient_phone_number(socket.assigns.current_patient, token) do
        :ok ->
          put_flash(socket, :info, "Phone Number changed successfully.")

        :error ->
          put_flash(socket, :error, "Phone number change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/patient/profile")}
  end

  def mount(_params, _session, socket) do
    patient = socket.assigns.current_patient
    email_changeset = Accounts.change_patient_email(patient)
    password_changeset = Accounts.change_patient_password(patient)

    # new fields changesets
    phone_number_changeset = Accounts.change_patient_phone_number(patient)

    socket =
      socket
      |> assign(:current_password, nil)
      |> assign(:email_form_current_password, nil)
      |> assign(:current_email, patient.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      
      # Assign the new changesets
      |> assign(:phone_number_form_current_password, nil)
      |> assign(:current_phone_number, patient.phone_number)
      |> assign(:phone_number_form, to_form(phone_number_changeset))
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  def handle_event("validate_email", params, socket) do
    %{"current_password" => password, "patient" => patient_params} = params

    email_form =
      socket.assigns.current_patient
      |> Accounts.change_patient_email(patient_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form, email_form_current_password: password)}
  end

  def handle_event("update_email", params, socket) do
    %{"current_password" => password, "patient" => patient_params} = params
    patient = socket.assigns.current_patient

    case Accounts.apply_patient_email(patient, password, patient_params) do
      {:ok, applied_patient} ->
        Accounts.deliver_patient_update_email_instructions(
          applied_patient,
          patient.email,
          &url(~p"/patients/settings/confirm_email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info) |> assign(email_form_current_password: nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :email_form, to_form(Map.put(changeset, :action, :insert)))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"current_password" => password, "patient" => patient_params} = params

    password_form =
      socket.assigns.current_patient
      |> Accounts.change_patient_password(patient_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form, current_password: password)}
  end

  def handle_event("update_password", params, socket) do
    %{"current_password" => password, "patient" => patient_params} = params
    patient = socket.assigns.current_patient

    case Accounts.update_patient_password(patient, password, patient_params) do
      {:ok, patient} ->
        password_form =
          patient
          |> Accounts.change_patient_password(patient_params)
          |> to_form()

        {:noreply, assign(socket, trigger_submit: true, password_form: password_form)}

      {:error, changeset} ->
        {:noreply, assign(socket, password_form: to_form(changeset))}
    end
  end

  def handle_event("validate_phone_number", params, socket) do
    %{"current_password" => password, "patient" => patient_params} = params

    phone_number_form =
      socket.assigns.current_patient
      |> Accounts.change_patient_phone_number(patient_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, phone_number_form: phone_number_form, phone_number_form_current_password: password)}
  end

 def handle_event("update_phone_number", params, socket) do
    %{"current_password" => password, "patient" => patient_params} = params
    patient = socket.assigns.current_patient

    case Accounts.apply_patient_phone_number(patient, password, patient_params) do
      {:ok, applied_patient} ->
        Accounts.deliver_patient_update_phone_number_instructions(
          applied_patient,
          patient.phone_number,
          &url(~p"/patients/settings/confirm_phone_number/#{&1}")
        )

        info = "A link to confirm your phone number change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info) |> assign(phone_number_form_current_password: nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :phone_number_form, to_form(Map.put(changeset, :action, :insert)))}
    end
  end
end