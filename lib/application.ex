defmodule Padawan.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      { Cachex, name: :padawan },
      Padawan.ChannelSup,
      Padawan.MattermostWebsocket,
      Padawan.Mattermost,
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Padawan]
    res = Supervisor.start_link(children, opts)

    Padawan.start_channel(%{ name: "console" })

    res
  end
end
