defmodule Health.Repo.Migrations.AddNewFieldsToPatientsTable do
  use Ecto.Migration

  def change do
    alter table(:patients) do
      add :first_name, :string
      add :middle_name, :string
      add :last_name, :string
      add :date_of_birth, :date
      add :gender, :string
      add :phone_number, :string, unique: true
      add :username, :string, unique: true
    end
  end
end
