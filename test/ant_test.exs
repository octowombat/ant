defmodule AntTest do
  use ExUnit.Case
  doctest Ant

  test "greets the world" do
    assert Ant.hello() == :world
  end
end
