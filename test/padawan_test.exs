defmodule PadawanTest do
  use ExUnit.Case
  doctest Padawan

  test "greets the world" do
    assert Padawan.hello() == :world
  end
end
