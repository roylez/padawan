defmodule Padawan.Lua do
  alias Padawan.Cache

  @type t :: tuple()
  @type interface_types :: map | list | boolean | number | fun


  @spec init() :: t
  def init() do
    case Cache.get(:lua_root) do
      { _, nil } ->
        lua = Luerl.init()
        Cache.put(:lua_root, lua)
        lua
      { :ok, lua } -> lua
    end
  end

  @spec call( t, atom, list ) :: { any, t }
  def call(lua, func, args) do
    Luerl.call_function(lua, [func], args)
  end

  @spec get( t, atom ) :: interface_types
  def get(lua, key) when is_atom(key) do
    get(lua, [key])
  end
  def get(lua, key) do
    { res, _lua } = Luerl.get_table(lua, key)
    parse_lua_type(res)
  end

  @spec set( t, atom, interface_types ) :: t
  def set(lua, key, value) when is_atom(key) do
    set(lua, [key], value)
  end
  def set(lua, key, value) do
    Luerl.set_table(lua, key, value)
  end

  @spec load( t, charlist | binary ) :: { any, t } 
  def load(lua, file) when is_binary(file) do
    load(lua, to_charlist(file))
  end
  def load(lua, file) do
    Luerl.dofile(lua, file)
  end

  defp parse_lua_type([{1, _}|_]=table), do: Enum.map(table, fn {_, v} -> parse_lua_type(v) end)
  defp parse_lua_type([{_, _}|_]=table), do: Enum.map(table, fn {k, v} -> { String.to_atom(k), parse_lua_type(v) } end) |> Enum.into(%{})
  defp parse_lua_type(any), do: any
end
