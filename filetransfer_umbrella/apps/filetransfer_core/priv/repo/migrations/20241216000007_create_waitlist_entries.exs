defmodule FiletransferCore.Repo.Migrations.CreateWaitlistEntries do
  use Ecto.Migration

  def change do
    create table(:waitlist_entries, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :string, null: false
      add :name, :string
      add :use_case, :string
      add :source, :string, default: "landing_page"
      add :ip_address, :string
      add :user_agent, :text
      add :notified_at, :utc_datetime
      add :converted_at, :utc_datetime # When they sign up as a user

      timestamps(type: :utc_datetime)
    end

    create unique_index(:waitlist_entries, [:email])
    create index(:waitlist_entries, [:inserted_at])
    create index(:waitlist_entries, [:notified_at])
  end
end


