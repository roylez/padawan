defmodule Padawan.Adapter.Mattermost do
  use Padawan.Adapter

  @moduledoc """
  Mattermost adapter
  """

  alias Padawan.Mattermost, as: MM

  def say([str], lua) do
    channel = Lua.get(lua, :channel)
    MM.post_create(%{ channel_id: channel.id, message: str })
    { [], lua }
  end

  def print_case(c, lua) do
    msg = "Case #{inspect c} mentioned"
    channel = Lua.get(lua, :channel)
    MM.post_create(%{ channel_id: channel.id, message: msg })
    { [], lua }
  end

  def handle_help(_, lua) do
    actions = Lua.get(lua, :actions)
    msg = ["|COMMAND|DESCRIPTION|", "|:-----|------:|"| Enum.map(actions, &"|#{escape(&1.synopsis)}|#{escape(&1.desc)}|")]
          |> Enum.join("\n")
    say([ msg ], lua)
  end

  defp escape(str) do
    Regex.replace(~r/([|*`_~])/, str, fn (_, x) -> "\\#{x}" end, [global: true]) 
  end

end
