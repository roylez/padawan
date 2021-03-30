defmodule Padawan.Adapter.Mattermost do
  use Padawan.Adapter

  @moduledoc """
  Mattermost adapter
  """

  alias Padawan.Mattermost, as: MM

  def say([str], lua) do
    { channel, _ } = Lua.get(lua, :channel)
    MM.post_create(%{ channel_id: channel.id, message: str })
    { [], lua }
  end

  def print_case(c, lua) do
    msg = "Case #{inspect c} mentioned"
    { channel, _ } = Lua.get(lua, :channel)
    MM.post_create(%{ channel_id: channel.id, message: msg })
    { [], lua }
  end

end
