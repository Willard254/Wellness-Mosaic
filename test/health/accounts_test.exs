defmodule Health.AccountsTest do
  use Health.DataCase

  alias Health.Accounts

  import Health.AccountsFixtures
  alias Health.Accounts.{Patient, PatientToken}

  describe "get_patient_by_email/1" do
    test "does not return the patient if the email does not exist" do
      refute Accounts.get_patient_by_email("unknown@example.com")
    end

    test "returns the patient if the email exists" do
      %{id: id} = patient = patient_fixture()
      assert %Patient{id: ^id} = Accounts.get_patient_by_email(patient.email)
    end
  end

  describe "get_patient_by_email_and_password/2" do
    test "does not return the patient if the email does not exist" do
      refute Accounts.get_patient_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the patient if the password is not valid" do
      patient = patient_fixture()
      refute Accounts.get_patient_by_email_and_password(patient.email, "invalid")
    end

    test "returns the patient if the email and password are valid" do
      %{id: id} = patient = patient_fixture()

      assert %Patient{id: ^id} =
               Accounts.get_patient_by_email_and_password(patient.email, valid_patient_password())
    end
  end

  describe "get_patient!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_patient!(-1)
      end
    end

    test "returns the patient with the given id" do
      %{id: id} = patient = patient_fixture()
      assert %Patient{id: ^id} = Accounts.get_patient!(patient.id)
    end
  end

  describe "register_patient/1" do
    test "requires email and password to be set" do
      {:error, changeset} = Accounts.register_patient(%{})

      assert %{
               password: ["can't be blank"],
               email: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "validates email and password when given" do
      {:error, changeset} = Accounts.register_patient(%{email: "not valid", password: "not valid"})

      assert %{
               email: ["must have the @ sign and no spaces"],
               password: ["should be at least 12 character(s)"]
             } = errors_on(changeset)
    end

    test "validates maximum values for email and password for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.register_patient(%{email: too_long, password: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates email uniqueness" do
      %{email: email} = patient_fixture()
      {:error, changeset} = Accounts.register_patient(%{email: email})
      assert "has already been taken" in errors_on(changeset).email

      # Now try with the upper cased email too, to check that email case is ignored.
      {:error, changeset} = Accounts.register_patient(%{email: String.upcase(email)})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "registers patients with a hashed password" do
      email = unique_patient_email()
      {:ok, patient} = Accounts.register_patient(valid_patient_attributes(email: email))
      assert patient.email == email
      assert is_binary(patient.hashed_password)
      assert is_nil(patient.confirmed_at)
      assert is_nil(patient.password)
    end
  end

  describe "change_patient_registration/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_patient_registration(%Patient{})
      assert changeset.required == [:password, :email]
    end

    test "allows fields to be set" do
      email = unique_patient_email()
      password = valid_patient_password()

      changeset =
        Accounts.change_patient_registration(
          %Patient{},
          valid_patient_attributes(email: email, password: password)
        )

      assert changeset.valid?
      assert get_change(changeset, :email) == email
      assert get_change(changeset, :password) == password
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "change_patient_email/2" do
    test "returns a patient changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_patient_email(%Patient{})
      assert changeset.required == [:email]
    end
  end

  describe "apply_patient_email/3" do
    setup do
      %{patient: patient_fixture()}
    end

    test "requires email to change", %{patient: patient} do
      {:error, changeset} = Accounts.apply_patient_email(patient, valid_patient_password(), %{})
      assert %{email: ["did not change"]} = errors_on(changeset)
    end

    test "validates email", %{patient: patient} do
      {:error, changeset} =
        Accounts.apply_patient_email(patient, valid_patient_password(), %{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum value for email for security", %{patient: patient} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.apply_patient_email(patient, valid_patient_password(), %{email: too_long})

      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness", %{patient: patient} do
      %{email: email} = patient_fixture()
      password = valid_patient_password()

      {:error, changeset} = Accounts.apply_patient_email(patient, password, %{email: email})

      assert "has already been taken" in errors_on(changeset).email
    end

    test "validates current password", %{patient: patient} do
      {:error, changeset} =
        Accounts.apply_patient_email(patient, "invalid", %{email: unique_patient_email()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "applies the email without persisting it", %{patient: patient} do
      email = unique_patient_email()
      {:ok, patient} = Accounts.apply_patient_email(patient, valid_patient_password(), %{email: email})
      assert patient.email == email
      assert Accounts.get_patient!(patient.id).email != email
    end
  end

  describe "deliver_patient_update_email_instructions/3" do
    setup do
      %{patient: patient_fixture()}
    end

    test "sends token through notification", %{patient: patient} do
      token =
        extract_patient_token(fn url ->
          Accounts.deliver_patient_update_email_instructions(patient, "current@example.com", url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert patient_token = Repo.get_by(PatientToken, token: :crypto.hash(:sha256, token))
      assert patient_token.patient_id == patient.id
      assert patient_token.sent_to == patient.email
      assert patient_token.context == "change:current@example.com"
    end
  end

  describe "update_patient_email/2" do
    setup do
      patient = patient_fixture()
      email = unique_patient_email()

      token =
        extract_patient_token(fn url ->
          Accounts.deliver_patient_update_email_instructions(%{patient | email: email}, patient.email, url)
        end)

      %{patient: patient, token: token, email: email}
    end

    test "updates the email with a valid token", %{patient: patient, token: token, email: email} do
      assert Accounts.update_patient_email(patient, token) == :ok
      changed_patient = Repo.get!(Patient, patient.id)
      assert changed_patient.email != patient.email
      assert changed_patient.email == email
      assert changed_patient.confirmed_at
      assert changed_patient.confirmed_at != patient.confirmed_at
      refute Repo.get_by(PatientToken, patient_id: patient.id)
    end

    test "does not update email with invalid token", %{patient: patient} do
      assert Accounts.update_patient_email(patient, "oops") == :error
      assert Repo.get!(Patient, patient.id).email == patient.email
      assert Repo.get_by(PatientToken, patient_id: patient.id)
    end

    test "does not update email if patient email changed", %{patient: patient, token: token} do
      assert Accounts.update_patient_email(%{patient | email: "current@example.com"}, token) == :error
      assert Repo.get!(Patient, patient.id).email == patient.email
      assert Repo.get_by(PatientToken, patient_id: patient.id)
    end

    test "does not update email if token expired", %{patient: patient, token: token} do
      {1, nil} = Repo.update_all(PatientToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Accounts.update_patient_email(patient, token) == :error
      assert Repo.get!(Patient, patient.id).email == patient.email
      assert Repo.get_by(PatientToken, patient_id: patient.id)
    end
  end

  describe "change_patient_password/2" do
    test "returns a patient changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_patient_password(%Patient{})
      assert changeset.required == [:password]
    end

    test "allows fields to be set" do
      changeset =
        Accounts.change_patient_password(%Patient{}, %{
          "password" => "new valid password"
        })

      assert changeset.valid?
      assert get_change(changeset, :password) == "new valid password"
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "update_patient_password/3" do
    setup do
      %{patient: patient_fixture()}
    end

    test "validates password", %{patient: patient} do
      {:error, changeset} =
        Accounts.update_patient_password(patient, valid_patient_password(), %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{patient: patient} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.update_patient_password(patient, valid_patient_password(), %{password: too_long})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates current password", %{patient: patient} do
      {:error, changeset} =
        Accounts.update_patient_password(patient, "invalid", %{password: valid_patient_password()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "updates the password", %{patient: patient} do
      {:ok, patient} =
        Accounts.update_patient_password(patient, valid_patient_password(), %{
          password: "new valid password"
        })

      assert is_nil(patient.password)
      assert Accounts.get_patient_by_email_and_password(patient.email, "new valid password")
    end

    test "deletes all tokens for the given patient", %{patient: patient} do
      _ = Accounts.generate_patient_session_token(patient)

      {:ok, _} =
        Accounts.update_patient_password(patient, valid_patient_password(), %{
          password: "new valid password"
        })

      refute Repo.get_by(PatientToken, patient_id: patient.id)
    end
  end

  describe "generate_patient_session_token/1" do
    setup do
      %{patient: patient_fixture()}
    end

    test "generates a token", %{patient: patient} do
      token = Accounts.generate_patient_session_token(patient)
      assert patient_token = Repo.get_by(PatientToken, token: token)
      assert patient_token.context == "session"

      # Creating the same token for another patient should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%PatientToken{
          token: patient_token.token,
          patient_id: patient_fixture().id,
          context: "session"
        })
      end
    end
  end

  describe "get_patient_by_session_token/1" do
    setup do
      patient = patient_fixture()
      token = Accounts.generate_patient_session_token(patient)
      %{patient: patient, token: token}
    end

    test "returns patient by token", %{patient: patient, token: token} do
      assert session_patient = Accounts.get_patient_by_session_token(token)
      assert session_patient.id == patient.id
    end

    test "does not return patient for invalid token" do
      refute Accounts.get_patient_by_session_token("oops")
    end

    test "does not return patient for expired token", %{token: token} do
      {1, nil} = Repo.update_all(PatientToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_patient_by_session_token(token)
    end
  end

  describe "delete_patient_session_token/1" do
    test "deletes the token" do
      patient = patient_fixture()
      token = Accounts.generate_patient_session_token(patient)
      assert Accounts.delete_patient_session_token(token) == :ok
      refute Accounts.get_patient_by_session_token(token)
    end
  end

  describe "deliver_patient_confirmation_instructions/2" do
    setup do
      %{patient: patient_fixture()}
    end

    test "sends token through notification", %{patient: patient} do
      token =
        extract_patient_token(fn url ->
          Accounts.deliver_patient_confirmation_instructions(patient, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert patient_token = Repo.get_by(PatientToken, token: :crypto.hash(:sha256, token))
      assert patient_token.patient_id == patient.id
      assert patient_token.sent_to == patient.email
      assert patient_token.context == "confirm"
    end
  end

  describe "confirm_patient/1" do
    setup do
      patient = patient_fixture()

      token =
        extract_patient_token(fn url ->
          Accounts.deliver_patient_confirmation_instructions(patient, url)
        end)

      %{patient: patient, token: token}
    end

    test "confirms the email with a valid token", %{patient: patient, token: token} do
      assert {:ok, confirmed_patient} = Accounts.confirm_patient(token)
      assert confirmed_patient.confirmed_at
      assert confirmed_patient.confirmed_at != patient.confirmed_at
      assert Repo.get!(Patient, patient.id).confirmed_at
      refute Repo.get_by(PatientToken, patient_id: patient.id)
    end

    test "does not confirm with invalid token", %{patient: patient} do
      assert Accounts.confirm_patient("oops") == :error
      refute Repo.get!(Patient, patient.id).confirmed_at
      assert Repo.get_by(PatientToken, patient_id: patient.id)
    end

    test "does not confirm email if token expired", %{patient: patient, token: token} do
      {1, nil} = Repo.update_all(PatientToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Accounts.confirm_patient(token) == :error
      refute Repo.get!(Patient, patient.id).confirmed_at
      assert Repo.get_by(PatientToken, patient_id: patient.id)
    end
  end

  describe "deliver_patient_reset_password_instructions/2" do
    setup do
      %{patient: patient_fixture()}
    end

    test "sends token through notification", %{patient: patient} do
      token =
        extract_patient_token(fn url ->
          Accounts.deliver_patient_reset_password_instructions(patient, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert patient_token = Repo.get_by(PatientToken, token: :crypto.hash(:sha256, token))
      assert patient_token.patient_id == patient.id
      assert patient_token.sent_to == patient.email
      assert patient_token.context == "reset_password"
    end
  end

  describe "get_patient_by_reset_password_token/1" do
    setup do
      patient = patient_fixture()

      token =
        extract_patient_token(fn url ->
          Accounts.deliver_patient_reset_password_instructions(patient, url)
        end)

      %{patient: patient, token: token}
    end

    test "returns the patient with valid token", %{patient: %{id: id}, token: token} do
      assert %Patient{id: ^id} = Accounts.get_patient_by_reset_password_token(token)
      assert Repo.get_by(PatientToken, patient_id: id)
    end

    test "does not return the patient with invalid token", %{patient: patient} do
      refute Accounts.get_patient_by_reset_password_token("oops")
      assert Repo.get_by(PatientToken, patient_id: patient.id)
    end

    test "does not return the patient if token expired", %{patient: patient, token: token} do
      {1, nil} = Repo.update_all(PatientToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_patient_by_reset_password_token(token)
      assert Repo.get_by(PatientToken, patient_id: patient.id)
    end
  end

  describe "reset_patient_password/2" do
    setup do
      %{patient: patient_fixture()}
    end

    test "validates password", %{patient: patient} do
      {:error, changeset} =
        Accounts.reset_patient_password(patient, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{patient: patient} do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.reset_patient_password(patient, %{password: too_long})
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{patient: patient} do
      {:ok, updated_patient} = Accounts.reset_patient_password(patient, %{password: "new valid password"})
      assert is_nil(updated_patient.password)
      assert Accounts.get_patient_by_email_and_password(patient.email, "new valid password")
    end

    test "deletes all tokens for the given patient", %{patient: patient} do
      _ = Accounts.generate_patient_session_token(patient)
      {:ok, _} = Accounts.reset_patient_password(patient, %{password: "new valid password"})
      refute Repo.get_by(PatientToken, patient_id: patient.id)
    end
  end

  describe "inspect/2 for the Patient module" do
    test "does not include password" do
      refute inspect(%Patient{password: "123456"}) =~ "password: \"123456\""
    end
  end
end
