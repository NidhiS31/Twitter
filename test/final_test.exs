defmodule FinalTest do
  use ExUnit.Case
  doctest Final

  test "Register Users" do
    assert Final.main(["10", "5"]) == "hello"
  end
end
