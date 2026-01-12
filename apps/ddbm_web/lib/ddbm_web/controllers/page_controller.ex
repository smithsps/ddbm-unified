defmodule DdbmWeb.PageController do
  use DdbmWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
