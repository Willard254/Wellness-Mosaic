defmodule HealthWeb.PatientAuthTest do
  use HealthWeb.ConnCase, async: true

  alias Phoenix.LiveView
  alias Health.Accounts
  alias HealthWeb.PatientAuth
  import Health.AccountsFixtures

  @remember_me_cookie "_health_web_patient_remember_me"

  setup %{conn: conn} do
    conn =
      conn
      |> Map.replace!(:secret_key_base, HealthWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})

    %{patient: patient_fixture(), conn: conn}
  end

  describe "log_in_patient/3" do
    test "stores the patient token in the session", %{conn: conn, patient: patient} do
      conn = PatientAuth.log_in_patient(conn, patient)
      assert token = get_session(conn, :patient_token)
      assert get_session(conn, :live_socket_id) == "patients_sessions:#{Base.url_encode64(token)}"
      assert redirected_to(conn) == ~p"/"
      assert Accounts.get_patient_by_session_token(token)
    end

    test "clears everything previously stored in the session", %{conn: conn, patient: patient} do
      conn = conn |> put_session(:to_be_removed, "value") |> PatientAuth.log_in_patient(patient)
      refute get_session(conn, :to_be_removed)
    end

    test "redirects to the configured path", %{conn: conn, patient: patient} do
      conn = conn |> put_session(:patient_return_to, "/hello") |> PatientAuth.log_in_patient(patient)
      assert redirected_to(conn) == "/hello"
    end

    test "writes a cookie if remember_me is configured", %{conn: conn, patient: patient} do
      conn = conn |> fetch_cookies() |> PatientAuth.log_in_patient(patient, %{"remember_me" => "true"})
      assert get_session(conn, :patient_token) == conn.cookies[@remember_me_cookie]

      assert %{value: signed_token, max_age: max_age} = conn.resp_cookies[@remember_me_cookie]
      assert signed_token != get_session(conn, :patient_token)
      assert max_age == 5_184_000
    end
  end

  describe "logout_patient/1" do
    test "erases session and cookies", %{conn: conn, patient: patient} do
      patient_token = Accounts.generate_patient_session_token(patient)

      conn =
        conn
        |> put_session(:patient_token, patient_token)
        |> put_req_cookie(@remember_me_cookie, patient_token)
        |> fetch_cookies()
        |> PatientAuth.log_out_patient()

      refute get_session(conn, :patient_token)
      refute conn.cookies[@remember_me_cookie]
      assert %{max_age: 0} = conn.resp_cookies[@remember_me_cookie]
      assert redirected_to(conn) == ~p"/"
      refute Accounts.get_patient_by_session_token(patient_token)
    end

    test "broadcasts to the given live_socket_id", %{conn: conn} do
      live_socket_id = "patients_sessions:abcdef-token"
      HealthWeb.Endpoint.subscribe(live_socket_id)

      conn
      |> put_session(:live_socket_id, live_socket_id)
      |> PatientAuth.log_out_patient()

      assert_receive %Phoenix.Socket.Broadcast{event: "disconnect", topic: ^live_socket_id}
    end

    test "works even if patient is already logged out", %{conn: conn} do
      conn = conn |> fetch_cookies() |> PatientAuth.log_out_patient()
      refute get_session(conn, :patient_token)
      assert %{max_age: 0} = conn.resp_cookies[@remember_me_cookie]
      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "fetch_current_patient/2" do
    test "authenticates patient from session", %{conn: conn, patient: patient} do
      patient_token = Accounts.generate_patient_session_token(patient)
      conn = conn |> put_session(:patient_token, patient_token) |> PatientAuth.fetch_current_patient([])
      assert conn.assigns.current_patient.id == patient.id
    end

    test "authenticates patient from cookies", %{conn: conn, patient: patient} do
      logged_in_conn =
        conn |> fetch_cookies() |> PatientAuth.log_in_patient(patient, %{"remember_me" => "true"})

      patient_token = logged_in_conn.cookies[@remember_me_cookie]
      %{value: signed_token} = logged_in_conn.resp_cookies[@remember_me_cookie]

      conn =
        conn
        |> put_req_cookie(@remember_me_cookie, signed_token)
        |> PatientAuth.fetch_current_patient([])

      assert conn.assigns.current_patient.id == patient.id
      assert get_session(conn, :patient_token) == patient_token

      assert get_session(conn, :live_socket_id) ==
               "patients_sessions:#{Base.url_encode64(patient_token)}"
    end

    test "does not authenticate if data is missing", %{conn: conn, patient: patient} do
      _ = Accounts.generate_patient_session_token(patient)
      conn = PatientAuth.fetch_current_patient(conn, [])
      refute get_session(conn, :patient_token)
      refute conn.assigns.current_patient
    end
  end

  describe "on_mount: mount_current_patient" do
    test "assigns current_patient based on a valid patient_token", %{conn: conn, patient: patient} do
      patient_token = Accounts.generate_patient_session_token(patient)
      session = conn |> put_session(:patient_token, patient_token) |> get_session()

      {:cont, updated_socket} =
        PatientAuth.on_mount(:mount_current_patient, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_patient.id == patient.id
    end

    test "assigns nil to current_patient assign if there isn't a valid patient_token", %{conn: conn} do
      patient_token = "invalid_token"
      session = conn |> put_session(:patient_token, patient_token) |> get_session()

      {:cont, updated_socket} =
        PatientAuth.on_mount(:mount_current_patient, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_patient == nil
    end

    test "assigns nil to current_patient assign if there isn't a patient_token", %{conn: conn} do
      session = conn |> get_session()

      {:cont, updated_socket} =
        PatientAuth.on_mount(:mount_current_patient, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_patient == nil
    end
  end

  describe "on_mount: ensure_authenticated" do
    test "authenticates current_patient based on a valid patient_token", %{conn: conn, patient: patient} do
      patient_token = Accounts.generate_patient_session_token(patient)
      session = conn |> put_session(:patient_token, patient_token) |> get_session()

      {:cont, updated_socket} =
        PatientAuth.on_mount(:ensure_authenticated, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_patient.id == patient.id
    end

    test "redirects to login page if there isn't a valid patient_token", %{conn: conn} do
      patient_token = "invalid_token"
      session = conn |> put_session(:patient_token, patient_token) |> get_session()

      socket = %LiveView.Socket{
        endpoint: HealthWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      {:halt, updated_socket} = PatientAuth.on_mount(:ensure_authenticated, %{}, session, socket)
      assert updated_socket.assigns.current_patient == nil
    end

    test "redirects to login page if there isn't a patient_token", %{conn: conn} do
      session = conn |> get_session()

      socket = %LiveView.Socket{
        endpoint: HealthWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      {:halt, updated_socket} = PatientAuth.on_mount(:ensure_authenticated, %{}, session, socket)
      assert updated_socket.assigns.current_patient == nil
    end
  end

  describe "on_mount: :redirect_if_patient_is_authenticated" do
    test "redirects if there is an authenticated  patient ", %{conn: conn, patient: patient} do
      patient_token = Accounts.generate_patient_session_token(patient)
      session = conn |> put_session(:patient_token, patient_token) |> get_session()

      assert {:halt, _updated_socket} =
               PatientAuth.on_mount(
                 :redirect_if_patient_is_authenticated,
                 %{},
                 session,
                 %LiveView.Socket{}
               )
    end

    test "doesn't redirect if there is no authenticated patient", %{conn: conn} do
      session = conn |> get_session()

      assert {:cont, _updated_socket} =
               PatientAuth.on_mount(
                 :redirect_if_patient_is_authenticated,
                 %{},
                 session,
                 %LiveView.Socket{}
               )
    end
  end

  describe "redirect_if_patient_is_authenticated/2" do
    test "redirects if patient is authenticated", %{conn: conn, patient: patient} do
      conn = conn |> assign(:current_patient, patient) |> PatientAuth.redirect_if_patient_is_authenticated([])
      assert conn.halted
      assert redirected_to(conn) == ~p"/"
    end

    test "does not redirect if patient is not authenticated", %{conn: conn} do
      conn = PatientAuth.redirect_if_patient_is_authenticated(conn, [])
      refute conn.halted
      refute conn.status
    end
  end

  describe "require_authenticated_patient/2" do
    test "redirects if patient is not authenticated", %{conn: conn} do
      conn = conn |> fetch_flash() |> PatientAuth.require_authenticated_patient([])
      assert conn.halted

      assert redirected_to(conn) == ~p"/patients/log_in"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "stores the path to redirect to on GET", %{conn: conn} do
      halted_conn =
        %{conn | path_info: ["foo"], query_string: ""}
        |> fetch_flash()
        |> PatientAuth.require_authenticated_patient([])

      assert halted_conn.halted
      assert get_session(halted_conn, :patient_return_to) == "/foo"

      halted_conn =
        %{conn | path_info: ["foo"], query_string: "bar=baz"}
        |> fetch_flash()
        |> PatientAuth.require_authenticated_patient([])

      assert halted_conn.halted
      assert get_session(halted_conn, :patient_return_to) == "/foo?bar=baz"

      halted_conn =
        %{conn | path_info: ["foo"], query_string: "bar", method: "POST"}
        |> fetch_flash()
        |> PatientAuth.require_authenticated_patient([])

      assert halted_conn.halted
      refute get_session(halted_conn, :patient_return_to)
    end

    test "does not redirect if patient is authenticated", %{conn: conn, patient: patient} do
      conn = conn |> assign(:current_patient, patient) |> PatientAuth.require_authenticated_patient([])
      refute conn.halted
      refute conn.status
    end
  end
end
