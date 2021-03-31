defmodule Padawan.Adapter do
  defmacro __using__(_) do
    quote do
      alias Padawan.{ Lua, Cache, Channel }

      def gmatch([str, pat], lua) do
        { :ok, re } = Regex.compile(pat, "i")
        res = Regex.scan(re, str, capture: :all_but_first)
        { [ res ], lua }
      end

      def set([str, value], lua) do
        channel = Lua.get(lua, :channel)
        { [ Cache.put!({channel.name, str}, value) ], lua }
      end

      def set([str, value, ttl], lua) do
        channel = Lua.get(lua, :channel)
        { [ Cache.put!({channel.name, str}, value, ttl: :timer.seconds(ttl)) ], lua }
      end

      def set_global([str, value], lua) do
        { [ Cache.put!({__MODULE__, str}, value) ], lua }
      end

      def set_global([str, value, ttl], lua) do
        { [ Cache.put!({__MODULE__, str}, value, ttl: :timer.seconds(ttl)) ], lua }
      end

      def get([str], lua) do
        channel = Lua.get(lua, :channel)
        { [ Cache.get!({channel.name, str}) ], lua }
      end

      def get_global([str], lua) do
        { [ Cache.get!({__MODULE__, str}) ], lua }
      end

      # Write handler mapping to Elixir Channel state
      def add_message_handler([pat, func], lua) do
        { :ok, re } = Regex.compile(pat, "i")
        channel = Lua.get(lua, :channel)
        Channel.add_handler(
          channel.name,
          :message_handler,
          %{ pattern: re, func: String.to_atom(func) } 
        )
        { [], lua }
      end

      # Write action mapping to Elixir Channel state
      def add_action_handler(["^" <> _=pat, func, synopsis, desc], lua) do
        { :ok, re } = Regex.compile(pat, "i")
        channel = Lua.get(lua, :channel)
        Channel.add_handler(
          channel.name,
          :action_handler,
          %{ pattern: re, func: String.to_atom(func), desc: desc, synopsis: synopsis }
        )
        { [], lua }
      end
      def add_action_handler([ pat, func, synopsis, desc ], lua) do
        add_action_handler(["^"<>pat, func, synopsis, desc], lua)
      end

      def handle_help(_, lua) do
        actions = Lua.get(lua, :actions)
        msg = actions
              |> Enum.map(&"#{&1.synopsis} - #{&1.desc}")
              |> Enum.join("\n")
        say([ msg ], lua)
      end

      def handle_hook([ "hook" ], lua) do
        case get([ "hook" ], lua) do
          { [ nil ], _ } ->
            say( [ "No webhook defined. Use 'hook <regex> <url>' to set it." ], lua )
          { [ [ pattern, url ] ], _ } ->
            say([ "/#{pattern}/i -> #{url}" ], lua)
        end
      end
      def handle_hook([ "hook reset" ], lua) do
        set(["hook", nil], lua)
        say([ "Webhook deleted." ], lua)
      end
      def handle_hook([ hook ], lua) do
        with [[ pattern, url ]] <- Regex.scan(~r/hook\s+(.+)\s+(https?:\/\/(?:www\.)?[-a-zA-Z0-9@:%._\+~#=]{2,256}\.[a-z]{2,6}\b(?:[-a-zA-Z0-9@:%_\+.~#?&\/\/=]*))/i, hook, capture: :all_but_first),
             [ _, pattern, url ] <- OptionParser.split(hook)
        do
          say([ "/#{pattern}/i -> #{url}" ], lua)
          set([ "hook", [pattern, url] ], lua)
        else
          e ->
            say([ "Invalid command" ], lua)
        end
      end

      def handle_load([ msg ], lua) do
        channel = Lua.get(lua, :channel)
        with [[ url ]] when is_binary(url) <- Regex.scan(~r/^load\s+(https?:\/\/(?:www\.)?(?:[0-9A-Za-z-\.@:%_\+~#=]+)+(?:(?:\.[a-zA-Z]{2,3})+)(?:\/.*)?(?:\?.*)?)/i, msg, capture: :all_but_first),
             { :ok, _, header, ref } <- :hackney.get(url),
             %{ "Content-Type" => "text/plain" <> _ } <- Enum.into(header, %{}),
             { :ok, body } <- :hackney.body(ref)
        do
          Channel.send_message(channel, {:save_script, body})
          say( ["Script saved as #{channel}.lua" ], lua )
        else
          _ ->
            say( ["Invalid url supplied. URL must point to a text/plain lua file."], lua )
        end
      end

      def handle_reload(_, lua) do
        channel = Lua.get(lua, :channel)
        script = Channel.script(channel)
        Channel.send_message(channel, :reload_script)
        say([ "#{script} loaded" ], lua)
      end

      defoverridable handle_help: 2
    end
  end
end
