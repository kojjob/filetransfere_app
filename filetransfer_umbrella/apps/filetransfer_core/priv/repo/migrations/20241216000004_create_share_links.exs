defmodule FiletransferCore.Repo.Migrations.CreateShareLinks do
  use Ecto.Migration

  def change do
    create table(:share_links, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :transfer_id, references(:transfers, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :token, :string, null: false
      add :password_hash, :string
      add :expires_at, :utc_datetime
      add :max_downloads, :integer
      add :download_count, :integer, default: 0, null: false
      add :is_active, :boolean, default: true, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:share_links, [:token])
    create index(:share_links, [:transfer_id])
    create index(:share_links, [:user_id])
    create index(:share_links, [:expires_at])
  end
end


