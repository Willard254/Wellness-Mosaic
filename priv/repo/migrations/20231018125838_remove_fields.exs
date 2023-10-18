defmodule Health.Repo.Migrations.RemoveFields do
  use Ecto.Migration

  def change do
    alter table(:patients) do
      remove :allergies
      remove :notes
      remove :weight
      remove :height

    end
  end
end