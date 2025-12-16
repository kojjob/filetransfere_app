defmodule FiletransferCore.Repo.Migrations.CreateUsageStats do
  use Ecto.Migration

  def change do
    create table(:usage_stats, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :month, :integer, null: false
      add :year, :integer, null: false
      add :bytes_transferred, :bigint, default: 0, null: false
      add :files_transferred, :integer, default: 0, null: false
      add :api_calls, :integer, default: 0, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:usage_stats, [:user_id, :year, :month])
    create index(:usage_stats, [:user_id])
  end
end
