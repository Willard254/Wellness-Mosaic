defmodule HealthWeb.PatientForgotPasswordLiveTest do
  use HealthWeb.ConnCase

  import Phoenix.LiveViewTest
  import Health.AccountsFixtures

  alias Health.Accounts
  alias Health.Repo

  describe "Forgot password page" do
    test "renders email page", %{conn: conn} do
      {:ok, lv, html} = live(conn, ~p"/patients/reset_password")

      assert html =~ "Forgot your password?"
      assert has_element?(lv, ~s|a[href="#{~p"/patients/register"}"]|, "Register")
      assert has_element?(lv, ~s|a[href="#{~p"/patients/log_in"}"]|, "Log in")
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_patient(patient_fixture())
        |> live(~p"/patients/reset_password")
        |> follow_redirect(conn, ~p"/")

      assert {:ok, _conn} = result
    end
  end

  describe "Reset link" do
    setup do
      %{patient: patient_fixture()}
    end

    test "sends a new reset password token", %{conn: conn, patient: patient} do
      {:ok, lv, _html} = live(conn, ~p"/patients/reset_password")

      {:ok, conn} =
        lv
        |> form("#reset_password_form", patient: %{"email" => patient.email})
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "If your email is in our system"

      assert Repo.get_by!(Accounts.PatientToken, patient_id: patient.id).context ==
               "reset_password"
    end

    test "does not send reset password token if email is invalid", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/patients/reset_password")

      {:ok, conn} =
        lv
        |> form("#reset_password_form", patient: %{"email" => "unknown@example.com"})
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "If your email is in our system"
      assert Repo.all(Accounts.PatientToken) == []
    end
  end
end
