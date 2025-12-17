defmodule FiletransferCore.WaitlistTest do
  use FiletransferCore.DataCase, async: true

  alias FiletransferCore.Waitlist
  alias FiletransferCore.Waitlist.WaitlistEntry

  describe "basic CRUD operations" do
    test "create_waitlist_entry/1 with valid data creates a waitlist entry" do
      attrs = %{email: "test@example.com", name: "Test User", use_case: "Video production"}

      assert {:ok, %WaitlistEntry{} = entry} = Waitlist.create_waitlist_entry(attrs)
      assert entry.email == "test@example.com"
      assert entry.name == "Test User"
      assert entry.use_case == "Video production"
    end

    test "create_waitlist_entry/1 with invalid email returns error" do
      attrs = %{email: "invalid-email", name: "Test User"}

      assert {:error, changeset} = Waitlist.create_waitlist_entry(attrs)
      assert "must be a valid email address" in errors_on(changeset).email
    end

    test "create_waitlist_entry/1 with duplicate email returns error" do
      attrs = %{email: "test@example.com", name: "Test User"}
      {:ok, _entry} = Waitlist.create_waitlist_entry(attrs)

      assert {:error, changeset} = Waitlist.create_waitlist_entry(attrs)
      assert "has already been taken" in errors_on(changeset).email
    end

    test "list_waitlist_entries/0 returns all entries ordered by newest first" do
      now = DateTime.utc_now()
      older_time = DateTime.add(now, -60, :second)

      {:ok, _entry1} = create_entry_at("first@example.com", older_time)
      {:ok, entry2} = create_entry_at("second@example.com", now)

      entries = Waitlist.list_waitlist_entries()
      assert length(entries) == 2
      # Newest first
      assert hd(entries).id == entry2.id
    end

    test "delete_waitlist_entry/1 removes the entry" do
      {:ok, entry} = Waitlist.create_waitlist_entry(%{email: "delete@example.com"})
      assert {:ok, _deleted} = Waitlist.delete_waitlist_entry(entry)
      assert Waitlist.count_waitlist_entries() == 0
    end
  end

  describe "status management" do
    test "mark_as_notified/1 sets notified_at timestamp" do
      {:ok, entry} = Waitlist.create_waitlist_entry(%{email: "notify@example.com"})
      assert is_nil(entry.notified_at)

      {:ok, updated} = Waitlist.mark_as_notified(entry)
      assert not is_nil(updated.notified_at)
    end

    test "mark_as_converted/1 sets converted_at timestamp" do
      {:ok, entry} = Waitlist.create_waitlist_entry(%{email: "convert@example.com"})
      assert is_nil(entry.converted_at)

      {:ok, updated} = Waitlist.mark_as_converted(entry)
      assert not is_nil(updated.converted_at)
    end
  end

  describe "count_entries_in_range/2 for growth rate calculation" do
    setup do
      now = DateTime.utc_now()

      # Create entries at different times
      # Today
      {:ok, today1} = create_entry_at("today1@example.com", now)
      {:ok, today2} = create_entry_at("today2@example.com", DateTime.add(now, -1, :hour))

      # 3 days ago
      {:ok, recent} = create_entry_at("recent@example.com", DateTime.add(now, -3, :day))

      # 10 days ago (previous week)
      {:ok, prev_week1} = create_entry_at("prev1@example.com", DateTime.add(now, -10, :day))
      {:ok, prev_week2} = create_entry_at("prev2@example.com", DateTime.add(now, -12, :day))
      {:ok, prev_week3} = create_entry_at("prev3@example.com", DateTime.add(now, -13, :day))

      # 20 days ago (older)
      {:ok, old} = create_entry_at("old@example.com", DateTime.add(now, -20, :day))

      %{
        now: now,
        today_entries: [today1, today2],
        recent_entry: recent,
        prev_week_entries: [prev_week1, prev_week2, prev_week3],
        old_entry: old
      }
    end

    test "counts entries within a date range", %{now: now} do
      week_ago = DateTime.add(now, -7, :day)
      count = Waitlist.count_entries_in_range(week_ago, now)
      # today1, today2, recent = 3 entries in last week
      assert count == 3
    end

    test "counts entries for previous week", %{now: now} do
      two_weeks_ago = DateTime.add(now, -14, :day)
      week_ago = DateTime.add(now, -7, :day)
      count = Waitlist.count_entries_in_range(two_weeks_ago, week_ago)
      # prev1, prev2, prev3 = 3 entries in previous week
      assert count == 3
    end

    test "returns 0 for empty range", %{now: now} do
      # Far future range
      start_time = DateTime.add(now, 100, :day)
      end_time = DateTime.add(now, 107, :day)
      count = Waitlist.count_entries_in_range(start_time, end_time)
      assert count == 0
    end
  end

  describe "search_entries/1 for search functionality" do
    setup do
      {:ok, _e1} =
        Waitlist.create_waitlist_entry(%{
          email: "john.doe@example.com",
          name: "John Doe",
          use_case: "Video production"
        })

      {:ok, _e2} =
        Waitlist.create_waitlist_entry(%{
          email: "jane.smith@company.org",
          name: "Jane Smith",
          use_case: "Team collaboration"
        })

      {:ok, _e3} =
        Waitlist.create_waitlist_entry(%{
          email: "bob@startup.io",
          name: "Bob Builder",
          use_case: "Software development"
        })

      :ok
    end

    test "searches by email substring" do
      results = Waitlist.search_entries("company")
      assert length(results) == 1
      assert hd(results).email == "jane.smith@company.org"
    end

    test "searches by name substring (case insensitive)" do
      results = Waitlist.search_entries("john")
      assert length(results) == 1
      assert hd(results).name == "John Doe"
    end

    test "searches by use case substring" do
      results = Waitlist.search_entries("software")
      assert length(results) == 1
      assert hd(results).name == "Bob Builder"
    end

    test "returns empty list when no matches" do
      results = Waitlist.search_entries("nonexistent")
      assert results == []
    end

    test "returns all entries when search is empty" do
      results = Waitlist.search_entries("")
      assert length(results) == 3
    end

    test "returns all entries when search is nil" do
      results = Waitlist.search_entries(nil)
      assert length(results) == 3
    end
  end

  describe "filter_by_status/1 for status filtering" do
    setup do
      {:ok, pending} = Waitlist.create_waitlist_entry(%{email: "pending@example.com"})

      {:ok, notified} = Waitlist.create_waitlist_entry(%{email: "notified@example.com"})
      {:ok, notified} = Waitlist.mark_as_notified(notified)

      {:ok, converted} = Waitlist.create_waitlist_entry(%{email: "converted@example.com"})
      {:ok, converted} = Waitlist.mark_as_notified(converted)
      {:ok, converted} = Waitlist.mark_as_converted(converted)

      %{pending: pending, notified: notified, converted: converted}
    end

    test "filters pending entries (not notified, not converted)" do
      results = Waitlist.filter_by_status("pending")
      assert length(results) == 1
      assert hd(results).email == "pending@example.com"
    end

    test "filters notified entries (notified but not converted)" do
      results = Waitlist.filter_by_status("notified")
      assert length(results) == 1
      assert hd(results).email == "notified@example.com"
    end

    test "filters converted entries" do
      results = Waitlist.filter_by_status("converted")
      assert length(results) == 1
      assert hd(results).email == "converted@example.com"
    end

    test "returns all entries when status is 'all' or nil" do
      assert length(Waitlist.filter_by_status("all")) == 3
      assert length(Waitlist.filter_by_status(nil)) == 3
    end
  end

  describe "daily_signups/1 for trend chart" do
    setup do
      now = DateTime.utc_now()
      today = DateTime.to_date(now)

      # Create entries on different days
      Enum.each(0..6, fn days_ago ->
        date = Date.add(today, -days_ago)
        # Create 1-3 entries per day (more recent = more entries for testing)
        entries_count = max(1, 4 - days_ago)

        Enum.each(1..entries_count, fn i ->
          datetime = DateTime.new!(date, ~T[12:00:00], "Etc/UTC")
          create_entry_at("day#{days_ago}_#{i}@example.com", datetime)
        end)
      end)

      %{today: today}
    end

    test "returns daily signup counts for last N days" do
      results = Waitlist.daily_signups(7)
      assert length(results) == 7
      # Each result should have date and count
      Enum.each(results, fn {date, count} ->
        assert %Date{} = date
        assert is_integer(count)
        assert count >= 0
      end)
    end

    test "returns data ordered by date ascending" do
      results = Waitlist.daily_signups(7)
      dates = Enum.map(results, fn {date, _count} -> date end)
      assert dates == Enum.sort(dates, Date)
    end

    test "includes days with zero signups" do
      # Create entry 30 days ago, should have gaps
      now = DateTime.utc_now()
      create_entry_at("old@example.com", DateTime.add(now, -30, :day))

      results = Waitlist.daily_signups(14)
      assert length(results) == 14
    end
  end

  describe "status_breakdown/0 for status distribution" do
    setup do
      # Create 3 pending
      Enum.each(1..3, fn i ->
        Waitlist.create_waitlist_entry(%{email: "pending#{i}@example.com"})
      end)

      # Create 2 notified
      Enum.each(1..2, fn i ->
        {:ok, entry} = Waitlist.create_waitlist_entry(%{email: "notified#{i}@example.com"})
        Waitlist.mark_as_notified(entry)
      end)

      # Create 1 converted
      {:ok, entry} = Waitlist.create_waitlist_entry(%{email: "converted@example.com"})
      {:ok, entry} = Waitlist.mark_as_notified(entry)
      Waitlist.mark_as_converted(entry)

      :ok
    end

    test "returns counts for each status" do
      breakdown = Waitlist.status_breakdown()

      assert breakdown.pending == 3
      assert breakdown.notified == 2
      assert breakdown.converted == 1
      assert breakdown.total == 6
    end
  end

  describe "growth_rate/0 for growth indicators" do
    setup do
      now = DateTime.utc_now()

      # This week: 5 entries
      Enum.each(1..5, fn i ->
        datetime = DateTime.add(now, -i, :day)
        create_entry_at("thisweek#{i}@example.com", datetime)
      end)

      # Previous week: 2 entries
      Enum.each(1..2, fn i ->
        datetime = DateTime.add(now, -(7 + i), :day)
        create_entry_at("lastweek#{i}@example.com", datetime)
      end)

      :ok
    end

    test "calculates week over week growth rate" do
      rate = Waitlist.growth_rate()
      # This week: 5, Last week: 2
      # Growth = ((5 - 2) / 2) * 100 = 150%
      assert rate == 150.0
    end

    test "returns 100.0 when previous week had zero entries" do
      # Clear all entries and create only this week
      FiletransferCore.Repo.delete_all(WaitlistEntry)

      now = DateTime.utc_now()
      create_entry_at("only@example.com", now)

      rate = Waitlist.growth_rate()
      assert rate == 100.0
    end
  end

  # Helper to create entries with specific timestamps
  defp create_entry_at(email, datetime) do
    %WaitlistEntry{}
    |> WaitlistEntry.changeset(%{email: email})
    |> Ecto.Changeset.put_change(:inserted_at, DateTime.truncate(datetime, :second))
    |> FiletransferCore.Repo.insert()
  end
end
