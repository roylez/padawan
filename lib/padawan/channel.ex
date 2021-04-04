require Logger

defmodule Padawan.Channel do
  use GenServer

  alias Padawan.{ Lua, Cache }
  alias Padawan.Channel.Handler

  @script_dir "lua"
  @default_actions [
    %Handler{
      desc: "Display this help",
      func: :handle_help,
      pattern: ~r/^help/i,
      synopsis: "help"
    },
    %Handler{
      desc: "Enable/disable bot in channel",
      func: :handle_enable,
      pattern: ~r/^enable|disable/i,
      synopsis: "enable|disable"
    },
    %Handler{
      desc: "Reload channel script",
      func: :handle_reload,
      pattern: ~r/^reload/i,
      synopsis: "reload"
    },
    %Handler{
      desc: "Load channel script from a url",
      func: :handle_load,
      pattern: ~r/^load\s+https?:\/\/.*/,
      synopsis: "load <URL>"
    },
    %Handler{
      desc: "Display or setup webhook",
      func: :handle_hook,
      pattern: ~r/^hook(\s+.*)?/,
      synopsis: "hook [<REGEX> <URL>|reset]"
    }
  ]

  defstruct [
    adapter: nil,
    channel: nil,
    name: nil,
    script: nil,
    lua: nil,
    lua_root: nil,
    message_handlers: [],
    action_handlers:  @default_actions,
    bot_name: nil,
  ]

# OTP stuff {{{
  def start_link(channel) do
    GenServer.start_link(__MODULE__, channel, name: registered_name(channel.name), id: channel.name)
  end

  def init(%{ name: name }=channel) do
    Logger.metadata(channel: name)
    Logger.notice "joining channel #{name}"
    ad = adapter(name)
    root = init_lua(ad)
           |> Lua.set(:channel, channel)
    { :ok,
      %__MODULE__{
        channel: channel,
        name: name,
        lua_root: root,
        lua: root,
        adapter: ad,
        bot_name: bot_name(name)
      },
      { :continue, { :reload_script, nil } }
    }
  end
# }}}

# Callback functions {{{
  def handle_call(:state, _, state) do
    { :reply, state, state }
  end

  def handle_call(:reload_script, from, state) do
    { :noreply,
      %{ state | message_handlers: [], action_handlers: @default_actions },
      { :continue, {:reload_script, from}}
    }
  end

  def handle_continue({:reload_script, from}, state) do
    try do
      { res, lua } = Lua.load(state.lua_root, script(state.name))
      if from do
        GenServer.reply(from, res)
      end
      { :noreply, %{ state | lua: lua } }
    rescue
      _ ->
        { res, lua } = Lua.load(state.lua_root, fallback_script())
        if from do
          GenServer.reply(from, res)
        end
        { :noreply, %{ state | lua: lua } }
    end
  end

  def handle_continue(:set_lua_actions, %{ action_handlers: actions } = state) do
    lua_actions = Enum.map(actions, &(Map.take(&1, [:desc, :synopsis])))
    lua = Lua.set(state.lua, :actions, lua_actions)
    { :noreply, %{ state | lua: lua } }
  end

  def handle_cast({:save_script, body}, state) do
    { :ok, file } = File.open("#{@script_dir}/#{state.name}.lua", [:write])
    IO.write(file, body)
    File.close(file)
    { :noreply,
      %{ state | message_handlers: [], action_handlers: @default_actions },
      { :continue, { :reload_script, nil } }
    }
  end

  def handle_cast(:reload_script, state) do
    { :noreply,
      %{ state | message_handlers: [], action_handlers: @default_actions },
      { :continue, { :reload_script, nil } }
    }
  end

  def handle_cast({:message_handler, handler}, state) do
    { :noreply, %{ state | message_handlers: [ struct(Handler, handler) | state.message_handlers ] } }
  end

  def handle_cast({:action_handler, handler}, state) do
    { :noreply,
      %{ state | action_handlers: [ struct(Handler, handler) | state.action_handlers ] },
      { :continue, :set_lua_actions }
    }
  end

  def handle_cast(message, state) do
    case categorize_message(message, state.bot_name) do
      { :message, msg } ->
        Logger.debug inspect(message, pretty: true)
        send_webhooks(state.adapter, message)
        if Cache.get!({state.name, :enabled}) do
          state.message_handlers
          |> Stream.filter(&Regex.match?(&1.pattern, msg))
          |> Enum.map(&call_lua_function(state.lua, &1.func, [msg]))
        end
      { :action, msg } ->
        Logger.debug inspect(message, pretty: true)
        state.action_handlers
        |> Stream.filter(&Regex.match?(&1.pattern, msg))
        |> Enum.map(&call_lua_function(state.lua, &1.func, [msg]))
      _ ->
        nil
    end
    { :noreply, state }
  end
# }}}

  # Public interface {{{
  #
  def state(channel) when is_binary(channel), do: channel |> registered_name |> state()
  def state(pid), do: GenServer.call(pid, :state)

  def reload_script(channel) when is_binary(channel), do: channel |> registered_name |> reload_script()
  def reload_script(pid), do: GenServer.call(pid, :reload_script)

  def add_handler(channel, type, handler) when is_binary(channel) do
    channel |> registered_name |> add_handler(type, handler)
  end
  def add_handler(pid, type, handler) do
    GenServer.cast(pid, {type, handler})
  end

  def send_message(channel, msg) when is_binary(channel), do: channel |> registered_name |> send_message(msg)
  def send_message(pid, msg), do: GenServer.cast(pid, msg)

  def registered_name(channel), do: :"#{__MODULE__}.#{String.upcase(channel)}"
  def process(channel), do: registered_name(channel)

  def script(channel), do: "#{@script_dir}/#{channel}.lua"
  def fallback_script, do: "#{@script_dir}/default.lua"
  # }}}
  
# Private functions {{{
  defp init_lua(adapter) do
    lua = Lua.init()
    adapter.__info__(:functions)
    |> Enum.reduce(lua, fn { f, _}, acc ->
      Lua.set(acc, f, &(apply(adapter, f, [&1, &2])))
    end)
  end

  defp call_lua_function(lua, func, args) do
    try do
      Logger.debug "[Lua] #{inspect {func, args}}"
      Lua.call(lua, func, args)
    rescue
      e in ErlangError ->
        case e do
          %ErlangError{original: {:lua_error, err, _ }} ->
            Logger.warn "Lua Error: #{inspect(err)}"
          %ArgumentError{} ->
            Logger.warn "ArgumentError: #{inspect e}"
        end
    end
  end

  defp adapter("console"),  do: Padawan.Adapter.Console
  defp adapter(_),          do: Padawan.Adapter.Mattermost

  defp bot_name("console"), do: "bot"
  defp bot_name(_),         do: Padawan.Mattermost.name()

  def message_content(str) when is_binary(str), do: str
  def message_content(%Padawan.Mattermost.EventData{}=message), do: get_in(message, [:post, :message])

  defp categorize_message(%{ sender_name: "@"<>bot_name }, bot_name), do: nil
  defp categorize_message(%{ channel_type: "D" }=event, _) do
    { :action, message_content(event) }
  end
  defp categorize_message(message, bot_name) do
    content = message_content(message)
    if Regex.match?(~r/^@?#{bot_name}:?\s+/i, content) do
      { :action, Regex.replace(~r/^@?#{bot_name}:?\s+/, content, "") }
    else
      { :message, content }
    end
  end

  defp send_webhooks(adapter, message) do
    content = message_content(message)
    hooks = Cache.fetch!({adapter, :hook}, fn(_) -> {:commit, %{}} end)
    header = [{"Content-Type", "application/json"}]
    Enum.each(hooks, fn {_chan, [pattern, url]} ->
      if Regex.match?(pattern, content) do
        Task.start( fn -> :hackney.post(url, header, Jason.encode!(data: message)) end)
      end
    end)
  end

# }}}
end
