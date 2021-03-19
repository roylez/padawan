defmodule Padawan.Console do
  use Padawan.AdapterHelpers

  @moduledoc """
  Console adapter
  """

  def say([str], state) do
    IO.puts to_string(str)
    { [], state }
  end

  def print_case(c, state) do
    IO.puts "Case #{inspect c} mentioned"
    { [], state }
  end
end
