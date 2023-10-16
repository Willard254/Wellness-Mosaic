defmodule HealthWeb.PatientController do
    use HealthWeb, :controller

    def profile(conn, _params) do
        render(conn, :profile)
    end
end