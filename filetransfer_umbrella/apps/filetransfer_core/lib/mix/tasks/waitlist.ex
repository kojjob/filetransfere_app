defmodule Mix.Tasks.Waitlist do
  @moduledoc """
  Mix tasks for managing waitlist data.

  ## Export waitlist to CSV

      mix waitlist.export [--output path/to/file.csv]

  ## Show waitlist stats

      mix waitlist.stats
  """

  use Mix.Task

  @shortdoc "Manage waitlist entries"

  @impl Mix.Task
  def run(args) do
    case args do
      ["export" | rest] -> export(rest)
      ["stats" | _] -> stats()
      _ -> help()
    end
  end

  defp export(args) do
    Mix.Task.run("app.start")

    output_file = parse_output(args, "waitlist_export_#{Date.to_iso8601(Date.utc_today())}.csv")

    entries = FiletransferCore.Waitlist.list_waitlist_entries()

    csv_content =
      [
        "email,name,use_case,source,signed_up_at"
        | Enum.map(entries, fn e ->
            [
              escape_csv(e.email),
              escape_csv(e.name),
              escape_csv(e.use_case),
              escape_csv(e.source),
              DateTime.to_iso8601(e.inserted_at)
            ]
            |> Enum.join(",")
          end)
      ]
      |> Enum.join("\n")

    File.write!(output_file, csv_content)

    Mix.shell().info("✅ Exported #{length(entries)} entries to #{output_file}")
  end

  defp stats do
    Mix.Task.run("app.start")

    alias FiletransferCore.Repo
    alias FiletransferCore.Waitlist.WaitlistEntry
    import Ecto.Query

    total = FiletransferCore.Waitlist.count_waitlist_entries()

    # Use cases breakdown
    use_cases =
      Repo.all(
        from(w in WaitlistEntry,
          group_by: w.use_case,
          select: {w.use_case, count(w.id)}
        )
      )

    # Sources breakdown
    sources =
      Repo.all(
        from(w in WaitlistEntry,
          group_by: w.source,
          select: {w.source, count(w.id)}
        )
      )

    # Recent signups (last 7 days)
    week_ago = DateTime.add(DateTime.utc_now(), -7, :day)

    recent =
      Repo.aggregate(
        from(w in WaitlistEntry, where: w.inserted_at > ^week_ago),
        :count,
        :id
      )

    Mix.shell().info("""

    📊 Waitlist Statistics
    ═══════════════════════════════════════

    Total entries: #{total}
    Last 7 days:   #{recent}

    📋 By Use Case:
    #{format_breakdown(use_cases)}

    🔗 By Source:
    #{format_breakdown(sources)}
    """)
  end

  defp help do
    Mix.shell().info("""
    Waitlist management tasks:

      mix waitlist export [--output file.csv]   Export all entries to CSV
      mix waitlist stats                        Show waitlist statistics
    """)
  end

  defp parse_output(args, default) do
    case args do
      ["--output", path | _] -> path
      ["-o", path | _] -> path
      _ -> default
    end
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

  defp format_breakdown(items) do
    items
    |> Enum.map(fn {key, count} ->
      "   #{key || "(not specified)"}: #{count}"
    end)
    |> Enum.join("\n")
  end
end
