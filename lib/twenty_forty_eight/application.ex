defmodule TwentyFortyEight.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TwentyFortyEightWeb.Telemetry,
      TwentyFortyEight.Repo,
      {DNSCluster,
       query: Application.get_env(:twenty_forty_eight, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: TwentyFortyEight.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: TwentyFortyEight.Finch},
      {Registry, keys: :unique, name: TwentyFortyEight.Game.Registry},
      {DynamicSupervisor, name: TwentyFortyEight.Game.Supervisor, strategy: :one_for_one},
      # Start to serve requests, typically the last entry
      TwentyFortyEightWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TwentyFortyEight.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TwentyFortyEightWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
