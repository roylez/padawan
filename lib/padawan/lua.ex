defmodule Padawan.Lua do
  alias Padawan.Cache

  def init() do
    with { _, nil } <- Cache.get(:lua_root) do
        lua = Luerl.init()
        Cache.put(:lua_root, lua)
        lua
    else
      { :ok, lua } -> lua
    end
  end

  def call(lua, func, args) do
    Luerl.call_function(lua, [func], args)
  end

  def get(lua, key) when is_atom(key) do
    get(lua, [key])
  end
  def get(lua, key) do
    case { res, lua } = Luerl.get_table(lua, key) do
      { [ {1, _ } |_ ], _ } ->
        { Enum.map(res, fn {_, v} -> v end), lua }
      { [ {_, _ } |_ ], _ } ->
        res = Enum.map(res, fn {k, v} -> { String.to_atom(k), v } end)
              |> Enum.into(%{})
        { res, lua }
      _ ->
        { res, lua }
    end
  end

  def set(lua, key, value) when is_atom(key) do
    set(lua, [key], value)
  end
  def set(lua, key, value) do
    Luerl.set_table(lua, key, value)
  end

  def load(lua, file) when is_binary(file) do
    load(lua, to_charlist(file))
  end
  def load(lua, file) do
    Luerl.dofile(lua, file)
  end

end
