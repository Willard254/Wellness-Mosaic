defmodule HealthWeb.PatientSessionController do
  use HealthWeb, :controller

  alias Health.Accounts
  alias HealthWeb.PatientAuth

  def create(conn, %{"_action" => "registered"} = params) do
    create(conn, params, "Account created successfully!")
  end

  def create(conn, %{"_action" => "password_updated"} = params) do
    conn
    |> put_session(:patient_return_to, ~p"/patients/settings")
    |> create(params, "Password updated successfully!")
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  defp create(conn, %{"patient" => patient_params}, info) do
    %{"email" => email, "password" => password} = patient_params

    if patient = Accounts.get_patient_by_email_and_password(email, password) do
      conn
      |> put_flash(:info, info)
      |> PatientAuth.log_in_patient(patient, patient_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      conn
      |> put_flash(:error, "Invalid email or password")
      |> put_flash(:email, String.slice(email, 0, 160))
      |> redirect(to: ~p"/patients/log_in")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> PatientAuth.log_out_patient()
  end
end
