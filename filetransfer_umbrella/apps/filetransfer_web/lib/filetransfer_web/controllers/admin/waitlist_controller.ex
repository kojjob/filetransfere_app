defmodule FiletransferWeb.Admin.WaitlistController do
  use FiletransferWeb, :controller

  alias FiletransferCore.Waitlist

  @doc """
  List all waitlist entries as JSON.
  """
  def index(conn, _params) do
    entries = Waitlist.list_waitlist_entries()

    json(conn, %{
      status: "success",
      count: length(entries),
      entries: Enum.map(entries, &serialize_entry/1)
    })
  end

  @doc """
  Get waitlist statistics.
  """
  def stats(conn, _params) do
    alias FiletransferCore.Repo
    alias FiletransferCore.Waitlist.WaitlistEntry
    import Ecto.Query

    total = Waitlist.count_waitlist_entries()

    use_cases =
      Repo.all(
        from(w in WaitlistEntry,
          group_by: w.use_case,
          select: {w.use_case, count(w.id)}
        )
      )
      |> Map.new()

    sources =
      Repo.all(
        from(w in WaitlistEntry,
          group_by: w.source,
          select: {w.source, count(w.id)}
        )
      )
      |> Map.new()

    week_ago = DateTime.add(DateTime.utc_now(), -7, :day)

    recent =
      Repo.aggregate(
        from(w in WaitlistEntry, where: w.inserted_at > ^week_ago),
        :count,
        :id
      )

    json(conn, %{
      status: "success",
      stats: %{
        total: total,
        last_7_days: recent,
        by_use_case: use_cases,
        by_source: sources
      }
    })
  end

  @doc """
  Export waitlist as CSV download.
  """
  def export(conn, _params) do
    entries = Waitlist.list_waitlist_entries()

    csv_content =
      [
        "email,name,use_case,source,ip_address,signed_up_at"
        | Enum.map(entries, fn e ->
            [
              escape_csv(e.email),
              escape_csv(e.name),
              escape_csv(e.use_case),
              escape_csv(e.source),
              escape_csv(e.ip_address),
              DateTime.to_iso8601(e.inserted_at)
            ]
            |> Enum.join(",")
          end)
      ]
      |> Enum.join("\n")

    filename = "waitlist_export_#{Date.to_iso8601(Date.utc_today())}.csv"

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
    |> send_resp(200, csv_content)
  end

  defp serialize_entry(entry) do
    %{
      id: entry.id,
      email: entry.email,
      name: entry.name,
      use_case: entry.use_case,
      source: entry.source,
      signed_up_at: entry.inserted_at,
      notified_at: entry.notified_at,
      converted_at: entry.converted_at
    }
  end

  defp escape_csv(nil), do: ""

  defp escape_csv(value) do
    str = to_string(value)

    if String.contains?(str, [",", "\"", "\n"]) do
      "\"#{String.replace(str, "\"", "\"\"")}\""
    else
      str
    end
  end
end
