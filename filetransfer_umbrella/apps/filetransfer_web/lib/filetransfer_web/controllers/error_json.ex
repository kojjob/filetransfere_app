defmodule FiletransferWeb.ErrorJSON do
  @moduledoc """
  JSON error responses.
  """

  def render("error.json", %{message: message}), do: %{status: "error", message: message}

  def render("changeset_error.json", %{changeset: changeset}) do
    %{status: "error", message: "Validation failed", errors: Ecto.Changeset.traverse_errors(changeset, &translate_error/1)}
  end

  def render("404.json", _), do: %{status: "error", message: "Not found"}
  def render("401.json", _), do: %{status: "error", message: "Unauthorized"}
  def render("403.json", _), do: %{status: "error", message: "Forbidden"}
  def render("500.json", _), do: %{status: "error", message: "Internal server error"}

  def render(template, _assigns) do
    %{status: "error", message: Phoenix.Controller.status_message_from_template(template)}
  end

  defp translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end
end
