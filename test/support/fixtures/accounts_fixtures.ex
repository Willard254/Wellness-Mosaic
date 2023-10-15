defmodule Health.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Health.Accounts` context.
  """

  def unique_patient_email, do: "patient#{System.unique_integer()}@example.com"
  def valid_patient_password, do: "hello world!"

  def valid_patient_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_patient_email(),
      password: valid_patient_password()
    })
  end

  def patient_fixture(attrs \\ %{}) do
    {:ok, patient} =
      attrs
      |> valid_patient_attributes()
      |> Health.Accounts.register_patient()

    patient
  end

  def extract_patient_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end
end
