defmodule HealthWeb.PatientSettingsLiveTest do
  use HealthWeb.ConnCase

  alias Health.Accounts
  import Phoenix.LiveViewTest
  import Health.AccountsFixtures

  describe "Settings page" do
    test "renders settings page", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_patient(patient_fixture())
        |> live(~p"/patients/settings")

      assert html =~ "Change Email"
      assert html =~ "Change Password"
    end

    test "redirects if patient is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/patients/settings")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/patients/log_in"
      assert %{"error" => "You must log in to access this page."} = flash
    end
  end

  describe "update email form" do
    setup %{conn: conn} do
      password = valid_patient_password()
      patient = patient_fixture(%{password: password})
      %{conn: log_in_patient(conn, patient), patient: patient, password: password}
    end

    test "updates the patient email", %{conn: conn, password: password, patient: patient} do
      new_email = unique_patient_email()

      {:ok, lv, _html} = live(conn, ~p"/patients/settings")

      result =
        lv
        |> form("#email_form", %{
          "current_password" => password,
          "patient" => %{"email" => new_email}
        })
        |> render_submit()

      assert result =~ "A link to confirm your email"
      assert Accounts.get_patient_by_email(patient.email)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/patients/settings")

      result =
        lv
        |> element("#email_form")
        |> render_change(%{
          "action" => "update_email",
          "current_password" => "invalid",
          "patient" => %{"email" => "with spaces"}
        })

      assert result =~ "Change Email"
      assert result =~ "must have the @ sign and no spaces"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn, patient: patient} do
      {:ok, lv, _html} = live(conn, ~p"/patients/settings")

      result =
        lv
        |> form("#email_form", %{
          "current_password" => "invalid",
          "patient" => %{"email" => patient.email}
        })
        |> render_submit()

      assert result =~ "Change Email"
      assert result =~ "did not change"
      assert result =~ "is not valid"
    end
  end

  describe "update password form" do
    setup %{conn: conn} do
      password = valid_patient_password()
      patient = patient_fixture(%{password: password})
      %{conn: log_in_patient(conn, patient), patient: patient, password: password}
    end

    test "updates the patient password", %{conn: conn, patient: patient, password: password} do
      new_password = valid_patient_password()

      {:ok, lv, _html} = live(conn, ~p"/patients/settings")

      form =
        form(lv, "#password_form", %{
          "current_password" => password,
          "patient" => %{
            "email" => patient.email,
            "password" => new_password,
            "password_confirmation" => new_password
          }
        })

      render_submit(form)

      new_password_conn = follow_trigger_action(form, conn)

      assert redirected_to(new_password_conn) == ~p"/patients/settings"

      assert get_session(new_password_conn, :patient_token) != get_session(conn, :patient_token)

      assert Phoenix.Flash.get(new_password_conn.assigns.flash, :info) =~
               "Password updated successfully"

      assert Accounts.get_patient_by_email_and_password(patient.email, new_password)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/patients/settings")

      result =
        lv
        |> element("#password_form")
        |> render_change(%{
          "current_password" => "invalid",
          "patient" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })

      assert result =~ "Change Password"
      assert result =~ "should be at least 12 character(s)"
      assert result =~ "does not match password"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/patients/settings")

      result =
        lv
        |> form("#password_form", %{
          "current_password" => "invalid",
          "patient" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })
        |> render_submit()

      assert result =~ "Change Password"
      assert result =~ "should be at least 12 character(s)"
      assert result =~ "does not match password"
      assert result =~ "is not valid"
    end
  end

  describe "confirm email" do
    setup %{conn: conn} do
      patient = patient_fixture()
      email = unique_patient_email()

      token =
        extract_patient_token(fn url ->
          Accounts.deliver_patient_update_email_instructions(%{patient | email: email}, patient.email, url)
        end)

      %{conn: log_in_patient(conn, patient), token: token, email: email, patient: patient}
    end

    test "updates the patient email once", %{conn: conn, patient: patient, token: token, email: email} do
      {:error, redirect} = live(conn, ~p"/patients/settings/confirm_email/#{token}")

      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/patients/settings"
      assert %{"info" => message} = flash
      assert message == "Email changed successfully."
      refute Accounts.get_patient_by_email(patient.email)
      assert Accounts.get_patient_by_email(email)

      # use confirm token again
      {:error, redirect} = live(conn, ~p"/patients/settings/confirm_email/#{token}")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/patients/settings"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
    end

    test "does not update email with invalid token", %{conn: conn, patient: patient} do
      {:error, redirect} = live(conn, ~p"/patients/settings/confirm_email/oops")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/patients/settings"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
      assert Accounts.get_patient_by_email(patient.email)
    end

    test "redirects if patient is not logged in", %{token: token} do
      conn = build_conn()
      {:error, redirect} = live(conn, ~p"/patients/settings/confirm_email/#{token}")
      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/patients/log_in"
      assert %{"error" => message} = flash
      assert message == "You must log in to access this page."
    end
  end
end
