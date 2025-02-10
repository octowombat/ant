defmodule Ant.Database.Adapters.MnesiaTest do
  alias Ant.Database.Adapters.Mnesia

  use ExUnit.Case
  use MnesiaTesting

  test "insert/2 inserts record" do
    assert {:ok, record} =
             Mnesia.insert(:ant_workers, %{
               worker_module: "Ant.Worker",
               status: "pending",
               args: %{a: 1},
               attempts: 0,
               errors: [],
               opts: %{}
             })

    assert record.worker_module == "Ant.Worker"
    assert record.status == "pending"
    assert record.args == %{a: 1}
    assert record.updated_at
    assert record.attempts == 0
    assert record.errors == []
    assert record.opts == %{}
  end

  test "get/2 retrieves record" do
    {:ok, inserted_record} = insert_record()

    assert {:ok, record} = Mnesia.get(:ant_workers, inserted_record.id)

    assert record.id == inserted_record.id
    assert record.worker_module == "Ant.Worker"
    assert record.status == "pending"
    assert record.args == %{b: 2}
    assert record.attempts == 0
    assert record.errors == []
    assert record.opts == %{}
  end

  test "get/2 returns not found when record does not exist" do
    assert {:error, :not_found} = Mnesia.get(:ant_workers, 999_999_999)
  end

  test "update/3 updates record" do
    {:ok, record} = insert_record()

    assert {:ok, updated_record} =
             Mnesia.update(:ant_workers, record.id, %{status: "running", attempts: 1})

    assert updated_record.id == record.id
    assert updated_record.status == "running"
    assert updated_record.attempts == 1
    assert updated_record.updated_at
  end

  test "filter/2 filters records by one or more attributes" do
    {:ok, %{id: record_id}} = insert_record(status: "cancelled", args: %{a: 1, c: 2})

    {:ok, %{id: record_2_id}} =
      insert_record(status: "running", args: %{a: 1, b: 2, d: 4}, attempts: 1)

    assert [%{id: ^record_id}] = Mnesia.filter(:ant_workers, %{status: "cancelled"})
    assert [%{id: ^record_2_id}] = Mnesia.filter(:ant_workers, %{status: "running", attempts: 1})

    assert [%{id: ^record_2_id}] = Mnesia.filter(:ant_workers, %{args: %{b: 2}}),
           "filters by partial map"

    assert Mnesia.filter(:ant_workers, %{args: %{another_attr: 2}}) == []
  end

  test "delete/2 deletes record" do
    {:ok, record} = insert_record()

    assert :ok = Mnesia.delete(:ant_workers, record.id)
    assert Mnesia.get(:ant_workers, record.id) == {:error, :not_found}
  end

  defp insert_record(opts \\ []) do
    status = Keyword.get(opts, :status, "pending")
    args = Keyword.get(opts, :args, %{b: 2})
    attempts = Keyword.get(opts, :attempts, 0)

    Mnesia.insert(:ant_workers, %{
      worker_module: "Ant.Worker",
      status: status,
      args: args,
      attempts: attempts,
      errors: [],
      opts: %{}
    })
  end
end
