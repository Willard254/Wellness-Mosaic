defmodule Health.Repo.Migrations.ModifyGender do
  use Ecto.Migration

  def change do
    alter table(:patients) do
      modify :gender, :string
    end
  end
end