defmodule Dashboard.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    consumer_group_opts = [
      # setting for the ConsumerGroup
      heartbeat_interval: 1_000,
      # this setting will be forwarded to the GenConsumer
      commit_interval: 1_000
    ]

    consumer_group_name = "myconsumergroup"
    topic_names = ["scrapedpages"]

    children = [
      # Start the Telemetry supervisor
      DashboardWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Dashboard.PubSub},
      # Start the Endpoint (http/https)
      DashboardWeb.Endpoint,
      # Start a worker by calling: Dashboard.Worker.start_link(arg)
      # {Dashboard.Worker, arg}
      # Start the consumer group
      supervisor(
        KafkaEx.ConsumerGroup,
        [PageGenConsumer, consumer_group_name, topic_names, consumer_group_opts],
        id: "scrapedpages_consumer"
      )
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Dashboard.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    DashboardWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
