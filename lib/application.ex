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
      Padawan.Mattermost.Websocket,
      Padawan.Mattermost,
      { Padawan.CacheSaver, Application.get_env(:padawan, :save_file) },
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Padawan]
    res = Supervisor.start_link(children, opts)

    _join_channels()

    res
  end

  defp _join_channels do
    Padawan.start_channel(%{ name: "console", private: true })
    Application.get_env(:padawan, :channels)
    |> String.split()
    |> Enum.map(fn c ->
      case Padawan.Mattermost.channel(c) do
        {:ok, 200, %{ type: "D" }} ->
          Padawan.start_channel(%{ name: c, private: true })
        {:ok, 200, _ } ->
          Padawan.start_channel(%{ name: c, private: false })
        _ -> nil
      end
    end)
  end
end
