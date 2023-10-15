defmodule HealthWeb.PatientConfirmationLiveTest do
  use HealthWeb.ConnCase

  import Phoenix.LiveViewTest
  import Health.AccountsFixtures

  alias Health.Accounts
  alias Health.Repo

  setup do
    %{patient: patient_fixture()}
  end

  describe "Confirm patient" do
    test "renders confirmation page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/patients/confirm/some-token")
      assert html =~ "Confirm Account"
    end

    test "confirms the given token once", %{conn: conn, patient: patient} do
      token =
        extract_patient_token(fn url ->
          Accounts.deliver_patient_confirmation_instructions(patient, url)
        end)

      {:ok, lv, _html} = live(conn, ~p"/patients/confirm/#{token}")

      result =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert {:ok, conn} = result

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "Patient confirmed successfully"

      assert Accounts.get_patient!(patient.id).confirmed_at
      refute get_session(conn, :patient_token)
      assert Repo.all(Accounts.PatientToken) == []

      # when not logged in
      {:ok, lv, _html} = live(conn, ~p"/patients/confirm/#{token}")

      result =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert {:ok, conn} = result

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Patient confirmation link is invalid or it has expired"

      # when logged in
      conn =
        build_conn()
        |> log_in_patient(patient)

      {:ok, lv, _html} = live(conn, ~p"/patients/confirm/#{token}")

      result =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert {:ok, conn} = result
      refute Phoenix.Flash.get(conn.assigns.flash, :error)
    end

    test "does not confirm email with invalid token", %{conn: conn, patient: patient} do
      {:ok, lv, _html} = live(conn, ~p"/patients/confirm/invalid-token")

      {:ok, conn} =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Patient confirmation link is invalid or it has expired"

      refute Accounts.get_patient!(patient.id).confirmed_at
    end
  end
end
