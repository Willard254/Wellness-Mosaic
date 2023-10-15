defmodule HealthWeb.PatientSessionControllerTest do
  use HealthWeb.ConnCase, async: true

  import Health.AccountsFixtures

  setup do
    %{patient: patient_fixture()}
  end

  describe "POST /patients/log_in" do
    test "logs the patient in", %{conn: conn, patient: patient} do
      conn =
        post(conn, ~p"/patients/log_in", %{
          "patient" => %{"email" => patient.email, "password" => valid_patient_password()}
        })

      assert get_session(conn, :patient_token)
      assert redirected_to(conn) == ~p"/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)
      assert response =~ patient.email
      assert response =~ ~p"/patients/settings"
      assert response =~ ~p"/patients/log_out"
    end

    test "logs the patient in with remember me", %{conn: conn, patient: patient} do
      conn =
        post(conn, ~p"/patients/log_in", %{
          "patient" => %{
            "email" => patient.email,
            "password" => valid_patient_password(),
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["_health_web_patient_remember_me"]
      assert redirected_to(conn) == ~p"/"
    end

    test "logs the patient in with return to", %{conn: conn, patient: patient} do
      conn =
        conn
        |> init_test_session(patient_return_to: "/foo/bar")
        |> post(~p"/patients/log_in", %{
          "patient" => %{
            "email" => patient.email,
            "password" => valid_patient_password()
          }
        })

      assert redirected_to(conn) == "/foo/bar"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Welcome back!"
    end

    test "login following registration", %{conn: conn, patient: patient} do
      conn =
        conn
        |> post(~p"/patients/log_in", %{
          "_action" => "registered",
          "patient" => %{
            "email" => patient.email,
            "password" => valid_patient_password()
          }
        })

      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Account created successfully"
    end

    test "login following password update", %{conn: conn, patient: patient} do
      conn =
        conn
        |> post(~p"/patients/log_in", %{
          "_action" => "password_updated",
          "patient" => %{
            "email" => patient.email,
            "password" => valid_patient_password()
          }
        })

      assert redirected_to(conn) == ~p"/patients/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Password updated successfully"
    end

    test "redirects to login page with invalid credentials", %{conn: conn} do
      conn =
        post(conn, ~p"/patients/log_in", %{
          "patient" => %{"email" => "invalid@email.com", "password" => "invalid_password"}
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
      assert redirected_to(conn) == ~p"/patients/log_in"
    end
  end

  describe "DELETE /patients/log_out" do
    test "logs the patient out", %{conn: conn, patient: patient} do
      conn = conn |> log_in_patient(patient) |> delete(~p"/patients/log_out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :patient_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end

    test "succeeds even if the patient is not logged in", %{conn: conn} do
      conn = delete(conn, ~p"/patients/log_out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :patient_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end
  end
end
