defmodule Health.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Health.Repo

  alias Health.Accounts.{Patient, PatientToken, PatientNotifier}

  ## Database getters

  @doc """
  Gets a patient by email.

  ## Examples

      iex> get_patient_by_email("foo@example.com")
      %Patient{}

      iex> get_patient_by_email("unknown@example.com")
      nil

  """
  def get_patient_by_email(email) when is_binary(email) do
    Repo.get_by(Patient, email: email)
  end

  @doc """
  Gets a patient by email and password.

  ## Examples

      iex> get_patient_by_email_and_password("foo@example.com", "correct_password")
      %Patient{}

      iex> get_patient_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_patient_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    patient = Repo.get_by(Patient, email: email)
    if Patient.valid_password?(patient, password), do: patient
  end

  @doc """
  Gets a single patient.

  Raises `Ecto.NoResultsError` if the Patient does not exist.

  ## Examples

      iex> get_patient!(123)
      %Patient{}

      iex> get_patient!(456)
      ** (Ecto.NoResultsError)

  """
  def get_patient!(id), do: Repo.get!(Patient, id)

  ## Patient registration

  @doc """
  Registers a patient.

  ## Examples

      iex> register_patient(%{field: value})
      {:ok, %Patient{}}

      iex> register_patient(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_patient(attrs) do
    %Patient{}
    |> Patient.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking patient changes.

  ## Examples

      iex> change_patient_registration(patient)
      %Ecto.Changeset{data: %Patient{}}

  """
  def change_patient_registration(%Patient{} = patient, attrs \\ %{}) do
    Patient.registration_changeset(patient, attrs, hash_password: false, validate_email: false)
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the patient email.

  ## Examples

      iex> change_patient_email(patient)
      %Ecto.Changeset{data: %Patient{}}

  """
  def change_patient_email(patient, attrs \\ %{}) do
    Patient.email_changeset(patient, attrs, validate_email: false)
  end

  @doc """
  Emulates that the email will change without actually changing
  it in the database.

  ## Examples

      iex> apply_patient_email(patient, "valid password", %{email: ...})
      {:ok, %Patient{}}

      iex> apply_patient_email(patient, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  def apply_patient_email(patient, password, attrs) do
    patient
    |> Patient.email_changeset(attrs)
    |> Patient.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the patient email using the given token.

  If the token matches, the patient email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_patient_email(patient, token) do
    context = "change:#{patient.email}"

    with {:ok, query} <- PatientToken.verify_change_email_token_query(token, context),
         %PatientToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(patient_email_multi(patient, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  defp patient_email_multi(patient, email, context) do
    changeset =
      patient
      |> Patient.email_changeset(%{email: email})
      |> Patient.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:patient, changeset)
    |> Ecto.Multi.delete_all(:tokens, PatientToken.patient_and_contexts_query(patient, [context]))
  end

  @doc ~S"""
  Delivers the update email instructions to the given patient.

  ## Examples

      iex> deliver_patient_update_email_instructions(patient, current_email, &url(~p"/patients/settings/confirm_email/#{&1})")
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_patient_update_email_instructions(%Patient{} = patient, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, patient_token} = PatientToken.build_email_token(patient, "change:#{current_email}")

    Repo.insert!(patient_token)
    PatientNotifier.deliver_update_email_instructions(patient, update_email_url_fun.(encoded_token))
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the patient password.

  ## Examples

      iex> change_patient_password(patient)
      %Ecto.Changeset{data: %Patient{}}

  """
  def change_patient_password(patient, attrs \\ %{}) do
    Patient.password_changeset(patient, attrs, hash_password: false)
  end

  @doc """
  Updates the patient password.

  ## Examples

      iex> update_patient_password(patient, "valid password", %{password: ...})
      {:ok, %Patient{}}

      iex> update_patient_password(patient, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_patient_password(patient, password, attrs) do
    changeset =
      patient
      |> Patient.password_changeset(attrs)
      |> Patient.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:patient, changeset)
    |> Ecto.Multi.delete_all(:tokens, PatientToken.patient_and_contexts_query(patient, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{patient: patient}} -> {:ok, patient}
      {:error, :patient, changeset, _} -> {:error, changeset}
    end
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_patient_session_token(patient) do
    {token, patient_token} = PatientToken.build_session_token(patient)
    Repo.insert!(patient_token)
    token
  end

  @doc """
  Gets the patient with the given signed token.
  """
  def get_patient_by_session_token(token) do
    {:ok, query} = PatientToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_patient_session_token(token) do
    Repo.delete_all(PatientToken.token_and_context_query(token, "session"))
    :ok
  end

  ## Confirmation

  @doc ~S"""
  Delivers the confirmation email instructions to the given patient.

  ## Examples

      iex> deliver_patient_confirmation_instructions(patient, &url(~p"/patients/confirm/#{&1}"))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_patient_confirmation_instructions(confirmed_patient, &url(~p"/patients/confirm/#{&1}"))
      {:error, :already_confirmed}

  """
  def deliver_patient_confirmation_instructions(%Patient{} = patient, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if patient.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, patient_token} = PatientToken.build_email_token(patient, "confirm")
      Repo.insert!(patient_token)
      PatientNotifier.deliver_confirmation_instructions(patient, confirmation_url_fun.(encoded_token))
    end
  end

  @doc """
  Confirms a patient by the given token.

  If the token matches, the patient account is marked as confirmed
  and the token is deleted.
  """
  def confirm_patient(token) do
    with {:ok, query} <- PatientToken.verify_email_token_query(token, "confirm"),
         %Patient{} = patient <- Repo.one(query),
         {:ok, %{patient: patient}} <- Repo.transaction(confirm_patient_multi(patient)) do
      {:ok, patient}
    else
      _ -> :error
    end
  end

  defp confirm_patient_multi(patient) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:patient, Patient.confirm_changeset(patient))
    |> Ecto.Multi.delete_all(:tokens, PatientToken.patient_and_contexts_query(patient, ["confirm"]))
  end

  ## Reset password

  @doc ~S"""
  Delivers the reset password email to the given patient.

  ## Examples

      iex> deliver_patient_reset_password_instructions(patient, &url(~p"/patients/reset_password/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_patient_reset_password_instructions(%Patient{} = patient, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, patient_token} = PatientToken.build_email_token(patient, "reset_password")
    Repo.insert!(patient_token)
    PatientNotifier.deliver_reset_password_instructions(patient, reset_password_url_fun.(encoded_token))
  end

  @doc """
  Gets the patient by reset password token.

  ## Examples

      iex> get_patient_by_reset_password_token("validtoken")
      %Patient{}

      iex> get_patient_by_reset_password_token("invalidtoken")
      nil

  """
  def get_patient_by_reset_password_token(token) do
    with {:ok, query} <- PatientToken.verify_email_token_query(token, "reset_password"),
         %Patient{} = patient <- Repo.one(query) do
      patient
    else
      _ -> nil
    end
  end

  @doc """
  Resets the patient password.

  ## Examples

      iex> reset_patient_password(patient, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %Patient{}}

      iex> reset_patient_password(patient, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_patient_password(patient, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:patient, Patient.password_changeset(patient, attrs))
    |> Ecto.Multi.delete_all(:tokens, PatientToken.patient_and_contexts_query(patient, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{patient: patient}} -> {:ok, patient}
      {:error, :patient, changeset, _} -> {:error, changeset}
    end
  end
end
