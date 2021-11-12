defmodule DocTest do
  use ExUnit.Case
  doctest Doc

  test "greets the world" do
    assert Doc.hello() == :world
  end
end
