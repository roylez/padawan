defmodule Padawan.Adapter do
  defmacro __using__(_) do
    quote do
      alias Padawan.{ Lua, Cache }

      def gmatch([str, pat], lua) do
        { :ok, re } = Regex.compile(pat, "i")
        res = Regex.scan(re, str, capture: :all_but_first)
        { [ res ], lua }
      end

      def handle_help(_, lua) do
        { actions, _ } = Lua.get(lua, :actions)
        msg = actions
              |> Stream.map(fn {_, h} -> h end)
              |> Enum.join("\n")
        say([ msg ], lua)
      end

      def set([str, value], lua) do
        { channel, _ } = Lua.get(lua, :channel)
        { [ Cache.put!({channel, str}, value) ], lua }
      end

      def set([str, value, ttl], lua) do
        { channel, _ } = Lua.get(lua, :channel)
        { [ Cache.put!({channel, str}, value, ttl: :timer.seconds(ttl)) ], lua }
      end

      def get([str], lua) do
        { channel, _ } = Lua.get(lua, :channel)
        { [ Cache.get!({channel, str}) ], lua }
      end

      # Write handler mapping to Elixir Channel state
      def add_message_handler([pat, func], lua) do
        { :ok, re } = Regex.compile(pat, "i")
        { channel, _ } = Lua.get(lua, :channel)
        Padawan.Channel.add_handler(
          channel,
          :message_handler,
          %{ pattern: re, func: String.to_atom(func) } 
        )
        { [], lua }
      end

      # Write action mapping to Elixir Channel state
      def add_action_handler(["^" <> _=pat, func, synopsis, desc], lua) do
        { :ok, re } = Regex.compile(pat, "i")
        { channel, _ } = Lua.get(lua, :channel)
        Padawan.Channel.add_handler(
          channel, 
          :action_handler,
          %{ pattern: re, func: String.to_atom(func), desc: desc, synopsis: synopsis }
        )
        { [], lua }
      end
      def add_action_handler([ pat, func, synopsis, desc ], lua) do
        add_action_handler(["^"<>pat, func, synopsis, desc], lua)
      end

    end
  end
end
