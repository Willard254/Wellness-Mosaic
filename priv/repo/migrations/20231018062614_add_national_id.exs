defmodule Health.Repo.Migrations.AddNationalId do
  use Ecto.Migration

  def change do
    alter table(:patients) do
      add :national_id, :integer, unique: true
    end
  end
end