defmodule Health.Accounts.PatientToken do
  use Ecto.Schema
  import Ecto.Query
  alias Health.Accounts.PatientToken

  @hash_algorithm :sha256
  @rand_size 32

  # It is very important to keep the reset password token expiry short,
  # since someone with access to the email may take over the account.
  @reset_password_validity_in_days 1
  @confirm_validity_in_days 7
  @change_email_validity_in_days 7
  @session_validity_in_days 60
  @change_phone_number_validity_in_days 7

  schema "patients_tokens" do
    field :token, :binary
    field :context, :string
    field :sent_to, :string
    belongs_to :patient, Health.Accounts.Patient

    timestamps(updated_at: false)
  end

  def build_session_token(patient) do
    token = :crypto.strong_rand_bytes(@rand_size)
    {token, %PatientToken{token: token, context: "session", patient_id: patient.id}}
  end

  def verify_session_token_query(token) do
    query =
      from token in token_and_context_query(token, "session"),
        join: patient in assoc(token, :patient),
        where: token.inserted_at > ago(@session_validity_in_days, "day"),
        select: patient

    {:ok, query}
  end

  def build_email_token(patient, context) do
    build_hashed_token(patient, context, patient.email)
  end

  def build_phone_number_token(patient, context) do
    build_hashed_token(patient, context, patient.phone_number)
  end

  defp build_hashed_token(patient, context, sent_to) do
    token = :crypto.strong_rand_bytes(@rand_size)
    hashed_token = :crypto.hash(@hash_algorithm, token)

    {Base.url_encode64(token, padding: false),
     %PatientToken{
       token: hashed_token,
       context: context,
       sent_to: sent_to,
       patient_id: patient.id
     }}
  end

  def verify_email_token_query(token, context) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = :crypto.hash(@hash_algorithm, decoded_token)
        days = days_for_context(context)

        query =
          from token in token_and_context_query(hashed_token, context),
            join: patient in assoc(token, :patient),
            where: token.inserted_at > ago(^days, "day") and token.sent_to == patient.email,
            select: patient

        {:ok, query}

      :error ->
        :error
    end
  end

  def verify_phone_number_token_query(token, context) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = :crypto.hash(@hash_algorithm, decoded_token)
        days = days_for_context(context)

        query =
          from token in token_and_context_query(hashed_token, context),
            join: patient in assoc(token, :patient),
            where: token.inserted_at > ago(^days, "day") and token.sent_to == patient.phone_number,
            select: patient

        {:ok, query}

      :error ->
        :error
    end
  end

  defp days_for_context("confirm"), do: @confirm_validity_in_days
  defp days_for_context("reset_password"), do: @reset_password_validity_in_days

  def verify_change_email_token_query(token, "change:" <> _ = context) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = :crypto.hash(@hash_algorithm, decoded_token)

        query =
          from token in token_and_context_query(hashed_token, context),
            where: token.inserted_at > ago(@change_email_validity_in_days, "day")

        {:ok, query}

      :error ->
        :error
    end
  end

  def verify_change_phone_number_token_query(token, "change:" <> _ = context) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = :crypto.hash(@hash_algorithm, decoded_token)

        query =
          from token in token_and_context_query(hashed_token, context),
            where: token.inserted_at > ago(@change_phone_number_validity_in_days, "day")

        {:ok, query}

      :error ->
        :error
    end
  end

  def token_and_context_query(token, context) do
    from PatientToken, where: [token: ^token, context: ^context]
  end

  def patient_and_contexts_query(patient, :all) do
    from t in PatientToken, where: t.patient_id == ^patient.id
  end

  def patient_and_contexts_query(patient, [_ | _] = contexts) do
    from t in PatientToken, where: t.patient_id == ^patient.id and t.context in ^contexts
  end
end
