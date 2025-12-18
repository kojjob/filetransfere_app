defmodule FiletransferWeb.ErrorJSONTest do
  use FiletransferWeb.ConnCase, async: true

  test "renders 404" do
    assert FiletransferWeb.ErrorJSON.render("404.json", %{}) == %{
             status: "error",
             message: "Not found"
           }
  end

  test "renders 500" do
    assert FiletransferWeb.ErrorJSON.render("500.json", %{}) == %{
             status: "error",
             message: "Internal server error"
           }
  end

  test "renders error with message" do
    assert FiletransferWeb.ErrorJSON.render("error.json", %{message: "Test error"}) == %{
             status: "error",
             message: "Test error"
           }
  end
end
