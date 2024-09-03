defmodule Ant.Repo do
  @table_to_struct_mapping %{
    ant_workers: Ant.Worker
  }

  def get(db_table, id) do
    with {:ok, record} <- Ant.Database.Adapters.Mnesia.get(db_table, id) do
      {:ok, to_struct(db_table, record)}
    end
  end

  # def get_by(queryable, params) do
  # end

  def all(db_table) do
    db_table
    |> Ant.Database.Adapters.Mnesia.all()
    |> Enum.map(&to_struct(db_table, &1))
  end

  def filter(db_table, params) do
    db_table
    |> Ant.Database.Adapters.Mnesia.filter(params)
    |> Enum.map(&to_struct(db_table, &1))
  end

  def insert(db_table, params) do
    with {:ok, record} <- Ant.Database.Adapters.Mnesia.insert(db_table, params) do
      {:ok, to_struct(db_table, record)}
    end
  end

  def update(db_table, id, params) do
    with {:ok, record} <- Ant.Database.Adapters.Mnesia.update(db_table, id, params) do
      {:ok, to_struct(db_table, record)}
    end
  end

  # def update_all(queryable, params) do
  # end

  # defp delete(queryable, params) do
  # end

  # defp delete_all(queryable) do
  # end

  defp to_struct(db_table, record) do
    @table_to_struct_mapping
    |> Map.get(db_table)
    |> struct(record)
  end
end
