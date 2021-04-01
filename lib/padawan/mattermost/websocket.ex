require Logger

defmodule Padawan.Mattermost.Websocket do
  use WebSockex

  def start_link(_) do
    endpoint = Application.get_env(:padawan, :mattermost)[:api_url]
    header = [ {"authorization", "Bearer #{Application.get_env(:padawan, :mattermost)[:token]}" } ]
    WebSockex.start_link(
      endpoint <> "/websocket",
      __MODULE__,
      0,
      name: __MODULE__,
      extra_headers: header
    )
  end

  def handle_frame({:text, msg}, state) do
    case Jason.decode(msg, keys: :atoms) do
      {:ok, %{ event: _ }=event } ->
        event
        |> parse_event()
        |> handle_event(state)
      { :ok, %{ seq_reply: _ } } -> { :ok, state }
      { :ok, msg } ->
        Logger.warn "MESSAGE: #{inspect msg}"
        { :ok, state }
      {:error, _     } -> throw("Unable to decode message: #{msg}")
    end
  end

  def handle_disconnect(status, state) do
    Logger.warn "Disconnected, status: #{inspect status}"
    { :reconnect, state }
  end

  def handle_event(%{ event: "hello", seq: seq }, _state) do
    reply = Jason.encode!(%{ seq: seq+1 , action: "get_statuses"})
    { :reply, {:text, reply}, seq+1 }
  end

  def handle_event(%{ event: "typing", seq: seq }, _state) do
    { :ok, seq }
  end

  def handle_event(%{ event: "posted", seq: seq }=event, _state) do
    chan = event.data.channel_display_name |> Padawan.Channel.registered_name
    with nil <- Process.whereis(chan) do
        Padawan.start_channel( %{
          name: event.data.channel_display_name,
          id: event.data.post.channel_id,
          private: event.data.channel_type == "D" })
      :timer.sleep(1000)
    end
    Padawan.Channel.send_message(chan, event.data)
    { :ok, seq }
  end

  def handle_event(%{ event: e, seq: seq }, _state)
  when e in ~w(emoji_added user_updated license_changed)
  do
    { :ok, seq }
  end

  def handle_event(event, _state) do
    Logger.warn("Event received: #{inspect event}")
    { :ok, event.seq }
  end

  def handle_cast(frame, state) do
    { :reply, frame, state }
  end

  def terminate(reason, _state) do
    Logger.critical("Socket Terminating: #{inspect reason}")
    exit(:normal)
  end

  defp parse_event(event) do
    e =event
       |> update_in(~w(data mentions)a, &( if &1 do Jason.decode!(&1, keys: :atoms) else nil end))
       |> update_in(~w(data post)a, &( if &1 do Jason.decode!(&1, keys: :atoms) else nil end))
       |> update_in(~w(data)a, &(struct(Padawan.Mattermost.EventData, &1)))
    struct(Padawan.Mattermost.Event, e)
  end

end
