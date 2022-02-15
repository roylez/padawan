defmodule Padawan.CacheSaver do
  use GenServer
  require Logger

  alias Padawan.Cache
  
  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end
  
  def init(file) do
    { :ok, file, {:continue, :load} }
  end

  def handle_continue(:load, file) do
    case File.regular?(file) do
      true ->
        Logger.info "Loading saved state from #{file}"
        Cache.load(file)
      false -> File.touch(file)
    end
    Process.send_after(self(), :dump, 30000)
    {:noreply, file}
  end

  def handle_info(:dump, file) do
    Cache.dump(file)
    {:noreply, file}
  end

end
