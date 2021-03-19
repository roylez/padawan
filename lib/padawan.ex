defmodule Padawan do
  @moduledoc """
  Documentation for `Padawan`.
  """

  def start_channel(channel) do
    spec = {Padawan.Channel, channel}
    DynamicSupervisor.start_child(Padawan.ChannelSup, spec)
  end

  def reload_channel(channel) do
    Padawan.Channel.reload_script(channel)
  end

end
