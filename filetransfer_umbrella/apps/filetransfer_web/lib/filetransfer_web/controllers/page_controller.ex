defmodule FiletransferWeb.PageController do
  use FiletransferWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
