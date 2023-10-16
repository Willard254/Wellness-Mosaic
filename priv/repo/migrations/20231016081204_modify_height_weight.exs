defmodule Health.Repo.Migrations.ModifyHeightWeight do
  use Ecto.Migration

  def change do
    alter table(:patients) do
      modify :weight, :decimal, precision: 5, scale: 2
      modify :height, :decimal, precision: 5, scale: 2
    end
  end
end
