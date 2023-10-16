defmodule Health.Repo.Migrations.AddNewFieldsPatients do
  use Ecto.Migration

  def change do
    alter table(:patients) do
      add :allergies, :string
      add :notes, :string
    end
  end
end