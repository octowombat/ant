defmodule Ant.Database.Adapters.Mnesia do
  @spec get(atom(), non_neg_integer()) ::
          {:ok, map()} | {:error, :not_found}
  def get(db_table, id) when is_atom(db_table) and is_integer(id) and id >= 0 do
    with {:atomic, %{} = record} <-
           :mnesia.transaction(fn ->
             case :mnesia.read({db_table, id}) do
               [] ->
                 {:error, :not_found}

               [row] ->
                 table_columns = get_table_columns(db_table)

                 to_map(row, table_columns)
             end
           end) do
      {:ok, record}
    else
      {:atomic, {:error, :not_found}} ->
        {:error, :not_found}

      error ->
        error
    end
  end

  @spec filter(atom(), map()) :: [map()]
  def filter(db_table, params) when is_atom(db_table) and is_map(params) do
    table_columns = get_table_columns(db_table)

    {:atomic, records} =
      :mnesia.transaction(fn ->
        attributes = Enum.map(table_columns, &Map.get(params, &1, :_))
        row = List.to_tuple([db_table | attributes])

        :mnesia.select(db_table, [
          {
            row,
            [],
            [:"$_"]
          }
        ])
      end)

    Enum.map(records, &to_map(&1, table_columns))
  end

  @spec all(atom()) :: [map()]
  def all(db_table) when is_atom(db_table) do
    table_columns = get_table_columns(db_table)

    {:atomic, records} =
      :mnesia.transaction(fn ->
        :mnesia.foldl(
          fn record, acc -> [to_map(record, table_columns) | acc] end,
          [],
          db_table
        )
      end)

    records
  end

  @spec insert(atom(), map()) :: {:ok, Ant.Worker.t()}
  def insert(db_table, params) when is_atom(db_table) and is_map(params) do
    table_columns = get_table_columns(db_table)

    attributes =
      Enum.map(
        table_columns,
        fn
          :id -> generate_id()
          :updated_at -> DateTime.utc_now()
          column -> params[column]
        end
      )

    row = List.to_tuple([db_table | attributes])

    with {:atomic, :ok} <- :mnesia.transaction(fn -> :mnesia.write(row) end) do
      {:ok, to_map(row, table_columns)}
    end
  end

  @spec update(atom(), non_neg_integer(), map()) :: {:ok, map()}
  def update(db_table, id, params)
      when is_atom(db_table) and is_integer(id) and id >= 0 and is_map(params) do
    with {:atomic, result} <-
           :mnesia.transaction(fn ->
             case :mnesia.read({db_table, id}) do
               [] ->
                 {:error, :not_found}

               [row] ->
                 table_columns = get_table_columns(db_table)

                 updated_record =
                   row
                   |> to_map(table_columns)
                   |> Map.merge(params)
                   |> Map.put(:updated_at, DateTime.utc_now())

                 attributes = Enum.map(table_columns, &Map.get(updated_record, &1))
                 updated_row = List.to_tuple([db_table | attributes])

                 with :ok <- :mnesia.write(updated_row) do
                   {:ok, to_map(updated_row, table_columns)}
                 end
             end
           end) do
      result
    end
  end

  @spec delete(atom(), non_neg_integer()) :: :ok
  def delete(db_table, id) when is_atom(db_table) and is_integer(id) and id >= 0 do
    with {:atomic, :ok} <- :mnesia.transaction(fn -> :mnesia.delete({db_table, id}) end) do
      :ok
    end
  end

  defp generate_id, do: :erlang.unique_integer([:positive])

  defp get_table_columns(db_table), do: :mnesia.table_info(db_table, :attributes)

  defp to_map(row, table_columns) do
    [_db_table | values] = Tuple.to_list(row)

    table_columns
    |> Enum.zip(values)
    |> Enum.into(%{})
  end
end
