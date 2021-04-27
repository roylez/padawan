defmodule Padawan do
  @moduledoc """
  Documentation for `Padawan`.
  """

  def start_channel(channel) do
    Supervisor.start_child(Padawan.ChannelSup, {Padawan.Channel, channel})
  end

  def reload_channel(channel) do
    Padawan.Channel.reload_script(channel)
  end

  def channels() do
    Supervisor.which_children(Padawan.ChannelSup)
  end

end
