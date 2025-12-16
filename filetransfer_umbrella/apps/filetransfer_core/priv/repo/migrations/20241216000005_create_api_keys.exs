defmodule FiletransferCore.Repo.Migrations.CreateApiKeys do
  use Ecto.Migration

  def change do
    create table(:api_keys, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :key_hash, :string, null: false
      add :key_prefix, :string, null: false # First 8 chars for display
      add :name, :string
      add :last_used_at, :utc_datetime
      add :is_active, :boolean, default: true, null: false
      add :rate_limit, :integer, default: 1000, null: false # Requests per hour

      timestamps(type: :utc_datetime)
    end

    create unique_index(:api_keys, [:key_hash])
    create index(:api_keys, [:user_id])
    create index(:api_keys, [:is_active])
  end
end
