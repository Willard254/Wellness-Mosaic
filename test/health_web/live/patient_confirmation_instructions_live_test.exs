defmodule HealthWeb.PatientConfirmationInstructionsLiveTest do
  use HealthWeb.ConnCase

  import Phoenix.LiveViewTest
  import Health.AccountsFixtures

  alias Health.Accounts
  alias Health.Repo

  setup do
    %{patient: patient_fixture()}
  end

  describe "Resend confirmation" do
    test "renders the resend confirmation page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/patients/confirm")
      assert html =~ "Resend confirmation instructions"
    end

    test "sends a new confirmation token", %{conn: conn, patient: patient} do
      {:ok, lv, _html} = live(conn, ~p"/patients/confirm")

      {:ok, conn} =
        lv
        |> form("#resend_confirmation_form", patient: %{email: patient.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      assert Repo.get_by!(Accounts.PatientToken, patient_id: patient.id).context == "confirm"
    end

    test "does not send confirmation token if patient is confirmed", %{conn: conn, patient: patient} do
      Repo.update!(Accounts.Patient.confirm_changeset(patient))

      {:ok, lv, _html} = live(conn, ~p"/patients/confirm")

      {:ok, conn} =
        lv
        |> form("#resend_confirmation_form", patient: %{email: patient.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      refute Repo.get_by(Accounts.PatientToken, patient_id: patient.id)
    end

    test "does not send confirmation token if email is invalid", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/patients/confirm")

      {:ok, conn} =
        lv
        |> form("#resend_confirmation_form", patient: %{email: "unknown@example.com"})
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      assert Repo.all(Accounts.PatientToken) == []
    end
  end
end
