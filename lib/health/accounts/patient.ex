defmodule Health.Accounts.Patient do
  use Ecto.Schema
  import Ecto.Changeset

  schema "patients" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :first_name, :string
    field :middle_name, :string
    field :last_name, :string
    field :username, :string
    field :phone_number, :string
    field :date_of_birth, :date
    field :gender, :string, default: "male"
    field :confirmed_at, :naive_datetime

    timestamps()
  end

  @doc """
  A patient changeset for registration.

  It is important to validate the length of both email and password.
  Otherwise databases may truncate the email without warnings, which
  could lead to unpredictable or insecure behaviour. Long passwords may
  also be very expensive to hash for certain algorithms.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.

    * `:validate_email` - Validates the uniqueness of the email, in case
      you don't want to validate the uniqueness of the email (like when
      using this changeset for validations on a LiveView form before
      submitting the form), this option can be set to `false`.
      Defaults to `true`.
  """
  def registration_changeset(patient, attrs, opts \\ []) do
    patient
    |> cast(attrs, [:email, :password, :first_name, :middle_name, :last_name, :username, :phone_number, :date_of_birth, :gender])
    |> validate_email(opts)
    |> validate_password(opts)
    |> validate_first_name(opts)
    |> validate_middle_name(opts)
    |> validate_last_name(opts)
    |> validate_username(opts)
    |> validate_phone_number(opts)
    |> validate_gender(opts)
    |> validate_date_of_birth(opts)
  end

  defp validate_first_name(changeset, _opts) do
    changeset
    |> validate_required([:first_name])
  end
  
  defp validate_middle_name(changeset, _opts) do
    changeset
    |> validate_required([:middle_name])
  end

  defp validate_last_name(changeset, _opts) do
    changeset
    |> validate_required([:last_name])
  end

  defp validate_username(changeset, opts) do
    changeset
    |> validate_required([:username])
    |> maybe_validate_unique_username(opts)
  end

  defp validate_date_of_birth(changeset, _opts) do
    changeset
    |> validate_required([:date_of_birth])
  end

  defp validate_gender(changeset, _opts) do
    changeset
    |> validate_required([:gender])
    |> validate_inclusion(:gender, ["male", "female"], message: "Invalid gender")
  end

  defp validate_phone_number(changeset, opts) do
    changeset
    |> validate_required([:phone_number])
    |> validate_format(:phone_number, ~r/^07\d{8}$/, message: "must start with 07")
    |> maybe_validate_unique_phone_number(opts)
  end

  defp validate_email(changeset, opts) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> maybe_validate_unique_email(opts)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 8, max: 72)
    # Examples of additional password validation:
    # |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    # |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    # |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      # If using Bcrypt, then further validate it is at most 72 bytes long
      |> validate_length(:password, max: 72, count: :bytes)
      # Hashing could be done with `Ecto.Changeset.prepare_changes/2`, but that
      # would keep the database transaction open longer and hurt performance.
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  defp maybe_validate_unique_email(changeset, opts) do
    if Keyword.get(opts, :validate_email, true) do
      changeset
      |> unsafe_validate_unique(:email, Health.Repo)
      |> unique_constraint(:email)
    else
      changeset
    end
  end

  defp maybe_validate_unique_username(changeset, opts) do
    if Keyword.get(opts, :validate_username, true) do
      changeset
      |> unsafe_validate_unique(:username, Health.Repo)
      |> unique_constraint(:username)
    else
      changeset
    end
  end

  defp maybe_validate_unique_phone_number(changeset, opts) do
    if Keyword.get(opts, :validate_phone_number, true) do
      changeset
      |> unsafe_validate_unique(:phone_number, Health.Repo)
      |> unique_constraint(:phone_number)
    else
      changeset
    end
  end

  @doc """
  A patient changeset for changing the email.

  It requires the email to change otherwise an error is added.
  """
  def email_changeset(patient, attrs, opts \\ []) do
    patient
    |> cast(attrs, [:email])
    |> validate_email(opts)
    |> case do
      %{changes: %{email: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :email, "did not change")
    end
  end

  @doc """
  A patient changeset for changing the password.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def password_changeset(patient, attrs, opts \\ []) do
    patient
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(patient) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    change(patient, confirmed_at: now)
  end

  @doc """
  Verifies the password.

  If there is no patient or the patient doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%Health.Accounts.Patient{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end

  @doc """
  Validates the current password otherwise adds an error to the changeset.
  """
  def validate_current_password(changeset, password) do
    if valid_password?(changeset.data, password) do
      changeset
    else
      add_error(changeset, :current_password, "is not valid")
    end
  end
end
