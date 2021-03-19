require Logger

defmodule Padawan.Channel do
  use GenServer

  alias Padawan.Lua
  alias Padawan.Channel.Handler

  @script 'lua/hello.lua'
  @default_actions [
    %Handler{
      desc: "Display this help",
      func: :handle_help,
      pattern: ~r/^help/i,
      synopsis: "help"
    }
  ]

  defstruct [
    adapter: nil,
    channel: nil,
    script: nil,
    lua: nil,
    lua_root: nil,
    message_handlers: [],
    action_handlers:  @default_actions,
    bot_name: nil,
  ]

# OTP stuff {{{
  def start_link(channel) do
    GenServer.start_link(__MODULE__, channel, name: registered_name(channel), id: channel)
  end

  def init(channel) do
    Logger.metadata(channel: channel)
    Logger.notice "joining channel #{channel}"
    ad = adapter(channel)
    root = init_lua(ad)
           |> Lua.set(:channel, channel)
    { :ok,
      %__MODULE__{
        channel: channel,
        script: @script,
        lua_root: root,
        adapter: adapter(channel),
        bot_name: bot_name(channel)
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
    { res, lua } = Lua.load(state.lua_root, state.script)
    if from do
      GenServer.reply(from, res)
    end
    { :noreply, %{ state | lua: lua } }
  end

  def handle_continue(:set_lua_actions, %{ action_handlers: actions } = state) do
    lua_actions = Enum.map(actions, &("#{&1.synopsis} - #{&1.desc}"))
    lua = Lua.set(state.lua, :actions, lua_actions)
    { :noreply, %{ state | lua: lua } }
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

  def handle_cast(message, state) when is_binary(message) do
    { msg, handlers } = if String.starts_with?(message, state.bot_name) do
      { Regex.replace(~r/^#{state.bot_name}:?\s+/, message, ""), state.action_handlers }
    else
      { message, state.message_handlers }
    end
    handlers
    |> Stream.filter(&Regex.match?(&1.pattern, msg))
    |> Enum.map(&call_lua_function(state.lua, &1.func, [msg]))
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

  # }}}
  
# Private functions {{{
  defp init_lua(adapter) do
    lua = Lua.init()
    adapter.__info__(:functions)
    |> Enum.reduce(lua, fn { f, _}, acc -> Lua.set(acc, f, &(apply(adapter, f, [&1, &2]))) end)
  end

  defp call_lua_function(lua, func, args) do
    try do
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

  defp adapter("console"), do: Padawan.Console
  defp adapter(_),         do: Padawan.Mattermost
  defp bot_name(_), do: "bot"
# }}}
end
