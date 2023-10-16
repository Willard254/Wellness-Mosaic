defmodule Health.Repo.Migrations.ModifyFields do
  use Ecto.Migration

  def change do
    alter table(:patients) do
      modify :weight, :float
      modify :height, :float
    end
  end
end
