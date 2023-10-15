defmodule HealthWeb.Router do
  use HealthWeb, :router

  import HealthWeb.PatientAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {HealthWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_patient
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", HealthWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Other scopes may use custom stacks.
  # scope "/api", HealthWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:health, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: HealthWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", HealthWeb do
    pipe_through [:browser, :redirect_if_patient_is_authenticated]

    live_session :redirect_if_patient_is_authenticated,
      on_mount: [{HealthWeb.PatientAuth, :redirect_if_patient_is_authenticated}] do
      live "/patients/register", PatientRegistrationLive, :new
      live "/patients/log_in", PatientLoginLive, :new
      live "/patients/reset_password", PatientForgotPasswordLive, :new
      live "/patients/reset_password/:token", PatientResetPasswordLive, :edit
    end

    post "/patients/log_in", PatientSessionController, :create
  end

  scope "/", HealthWeb do
    pipe_through [:browser, :require_authenticated_patient]

    live_session :require_authenticated_patient,
      on_mount: [{HealthWeb.PatientAuth, :ensure_authenticated}] do
      live "/patients/settings", PatientSettingsLive, :edit
      live "/patients/settings/confirm_email/:token", PatientSettingsLive, :confirm_email
    end
  end

  scope "/", HealthWeb do
    pipe_through [:browser]

    delete "/patients/log_out", PatientSessionController, :delete

    live_session :current_patient,
      on_mount: [{HealthWeb.PatientAuth, :mount_current_patient}] do
      live "/patients/confirm/:token", PatientConfirmationLive, :edit
      live "/patients/confirm", PatientConfirmationInstructionsLive, :new
    end
  end
end
