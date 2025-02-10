defmodule Ant.Repo do
  @table_to_struct_mapping %{
    ant_workers: Ant.Worker
  }

  @spec get(atom(), non_neg_integer()) ::
          {:ok, Ant.Worker.t()} | {:error, :not_found}
  def get(db_table, id) when is_atom(db_table) and is_integer(id) and id >= 0 do
    with {:ok, record} <- Ant.Database.Adapters.Mnesia.get(db_table, id) do
      {:ok, to_struct(db_table, record)}
    end
  end

  @spec all(atom()) :: [Ant.Worker.t()]
  def all(db_table) when is_atom(db_table) do
    db_table
    |> Ant.Database.Adapters.Mnesia.all()
    |> Enum.map(&to_struct(db_table, &1))
  end

  @spec filter(atom(), map()) :: [Ant.Worker.t()]
  def filter(db_table, params) when is_atom(db_table) and is_map(params) do
    db_table
    |> Ant.Database.Adapters.Mnesia.filter(params)
    |> Enum.map(&to_struct(db_table, &1))
  end

  @spec insert(atom(), map()) :: {:ok, Ant.Worker.t()}
  def insert(db_table, params) when is_atom(db_table) and is_map(params) do
    with {:ok, record} <- Ant.Database.Adapters.Mnesia.insert(db_table, params) do
      {:ok, to_struct(db_table, record)}
    end
  end

  @spec update(atom(), non_neg_integer(), map()) :: {:ok, Ant.Worker.t()}
  def update(db_table, id, params)
      when is_atom(db_table) and is_integer(id) and id >= 0 and
             is_map(params) do
    with {:ok, record} <- Ant.Database.Adapters.Mnesia.update(db_table, id, params) do
      {:ok, to_struct(db_table, record)}
    end
  end

  @spec delete(atom(), non_neg_integer()) :: :ok
  def delete(db_table, id) when is_atom(db_table) and is_integer(id) and id >= 0 do
    Ant.Database.Adapters.Mnesia.delete(db_table, id)
  end

  defp to_struct(db_table, record) do
    @table_to_struct_mapping
    |> Map.get(db_table)
    |> struct(record)
  end
end
