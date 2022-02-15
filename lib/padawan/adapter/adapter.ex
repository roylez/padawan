defmodule Padawan.Adapter do
  defmacro __using__(_) do
    quote do
      alias Padawan.{ Lua, Cache, Channel }

      def gmatch([str, pat], lua) do
        { :ok, re } = Regex.compile(pat, "i")
        res = Regex.scan(re, str, capture: :all_but_first)
        { [ res ], lua }
      end

      def set([key, value], lua) do
        channel = Lua.get(lua, :channel)
        { [ Cache.put!({channel.name, key}, value) ], lua }
      end

      def set([key, value, ttl], lua) do
        channel = Lua.get(lua, :channel)
        { [ Cache.put!({channel.name, key}, value, ttl: :timer.seconds(ttl)) ], lua }
      end

      def set_global([key, value], lua) do
        { [ Cache.put!({__MODULE__, key}, value) ], lua }
      end

      def set_global([key, value, ttl], lua) do
        { [ Cache.put!({__MODULE__, key}, value, ttl: :timer.seconds(ttl)) ], lua }
      end

      def get([key], lua) do
        channel = Lua.get(lua, :channel)
        { [ Cache.get!({channel.name, key}) ], lua }
      end

      def get_global([key], lua) do
        { [ Cache.get!({__MODULE__, key}) ], lua }
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

      def handle_hook([ "webhook" <> rest ], lua) do
        case Lua.get(lua, :channel) do
          %{ private: true } -> handle_hook([String.trim(rest)], lua )
          _ -> say(["Ask me this in a private chat"], lua)
        end
      end
      def handle_hook([""], lua) do
        channel = Lua.get(lua, :channel)
        name = channel.name
        with { [ %{ ^name => [ pattern, url ] } ], _ } <- get_global([:hook], lua) do
           say([ "#{inspect pattern} -> #{url}" ], lua)
        else
          _ -> say([ "No webhook defined. Use 'hook <regex> <url>' to set it." ], lua )
        end
      end
      def handle_hook(["reset"], lua) do
        channel = Lua.get(lua, :channel)
        name = channel.name
        with { [ %{ ^name => _ }=hooks ], _ } <- get_global([:hook], lua) do
            set_global([:hook, Map.delete(hooks, name)], lua)
            say([ "Webhook deleted." ], lua)
        else
          _ -> say([ "No webhook defined. Use 'hook <regex> <url>' to set it." ], lua )
        end
      end
      def handle_hook([hook], lua) do
        hook = String.trim(hook)
        with [[ pattern, url ]] <- Regex.scan(~r/(.+)\s+(https?:\/\/[^\s\/$.?#].[^\s]*)/i, hook, capture: :all_but_first),
             [ pattern, url ] <- OptionParser.split(hook),
             { :ok, pattern } <- Regex.compile(pattern)
        do
          channel = Lua.get(lua, :channel)
          hook = %{ channel.name => [ pattern, url ] }
          case get_global([:hook], lua) do
            { [ nil ], _ } ->       set_global([:hook, hook ], lua)
            { [ %{}=hooks ], _ } -> set_global([:hook, Map.merge(hooks, hook)], lua)
          end
          say([ "Webhook saved: #{inspect pattern} -> #{url}" ], lua)
        else
          {_, status, _, _ } ->
            say(["Server returns status #{status}, please check your URL and try again"], lua)
          {:error, _ } ->
            say(["Something is wrong. Probably your regex pattern."], lua)
          [] ->
            say(["Invalid URL"], lua)
          _ ->
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
        script = Channel.script(channel.name)
        Channel.send_message(channel.name, :reload_script)
        say([ "#{script} loaded" ], lua)
      end

      def handle_enable([ "enable" <> _ ], lua) do
        set([:enabled, true], lua)
        say([ "Okay, ready to serve." ], lua )
      end

      def handle_enable([ "disable" <> _ ], lua) do
        set([:enabled, false], lua)
        say([ "Going to sleep. Wake me up when in need." ], lua )
      end

      defoverridable handle_help: 2
    end
  end
end
