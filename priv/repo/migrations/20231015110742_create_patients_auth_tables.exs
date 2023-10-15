defmodule Health.Repo.Migrations.CreatePatientsAuthTables do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    create table(:patients) do
      add :email, :citext, null: false
      add :hashed_password, :string, null: false
      add :confirmed_at, :naive_datetime
      timestamps()
    end

    create unique_index(:patients, [:email])

    create table(:patients_tokens) do
      add :patient_id, references(:patients, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      timestamps(updated_at: false)
    end

    create index(:patients_tokens, [:patient_id])
    create unique_index(:patients_tokens, [:context, :token])
  end
end
