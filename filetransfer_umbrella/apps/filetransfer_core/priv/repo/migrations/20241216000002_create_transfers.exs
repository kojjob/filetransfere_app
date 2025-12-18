defmodule FiletransferCore.Repo.Migrations.CreateTransfers do
  use Ecto.Migration

  def change do
    create table(:transfers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :status, :string, default: "pending", null: false # pending, uploading, processing, completed, failed, cancelled
      add :file_name, :string, null: false
      add :file_size, :bigint, null: false
      add :file_type, :string
      add :chunk_size, :integer, default: 5_242_880, null: false # 5MB default
      add :total_chunks, :integer, null: false
      add :uploaded_chunks, :integer, default: 0, null: false
      add :bytes_uploaded, :bigint, default: 0, null: false
      add :storage_path, :string
      add :storage_provider, :string, default: "s3"
      add :encryption_key, :text # Encrypted key for E2E encryption
      add :metadata, :map, default: %{}
      add :error_message, :text
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:transfers, [:user_id])
    create index(:transfers, [:status])
    create index(:transfers, [:inserted_at])
  end
end


