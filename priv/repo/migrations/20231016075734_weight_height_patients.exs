defmodule Health.Repo.Migrations.WeightHeightPatients do
  use Ecto.Migration

  def change do
    alter table(:patients) do
      add :weight, :integer
      add :height, :integer
    end
  end
end
