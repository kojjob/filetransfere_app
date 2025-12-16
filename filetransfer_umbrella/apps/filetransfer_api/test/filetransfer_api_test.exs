defmodule FiletransferApiTest do
  use ExUnit.Case
  doctest FiletransferApi

  test "greets the world" do
    assert FiletransferApi.hello() == :world
  end
end
