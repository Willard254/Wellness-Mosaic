defmodule Health.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      HealthWeb.Telemetry,
      # Start the Ecto repository
      Health.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: Health.PubSub},
      # Start Finch
      {Finch, name: Health.Finch},
      # Start the Endpoint (http/https)
      HealthWeb.Endpoint
      # Start a worker by calling: Health.Worker.start_link(arg)
      # {Health.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Health.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    HealthWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
