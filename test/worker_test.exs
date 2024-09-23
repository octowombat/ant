defmodule Ant.WorkerTest do
  alias Ant.Worker

  use ExUnit.Case
  use MnesiaTesting

  defmodule MyTestWorker do
    use Ant.Worker

    def perform(_worker), do: :ok

    def calculate_delay(_worker), do: 0
  end

  defmodule FailWorker do
    use Ant.Worker

    def perform(_worker), do: :error

    def calculate_delay(_worker), do: 0
  end

  defmodule ExceptionWorker do
    use Ant.Worker

    def perform(_worker), do: raise("Custom exception!")

    def calculate_delay(_worker), do: 0
  end

  describe "start_link/1" do
    test "accepts worker struct on start" do
      assert {:ok, _pid} = Worker.start_link(%Worker{})
    end
  end

  describe "perform_async/2" do
    test "creates a worker" do
      assert {:ok, worker} = MyTestWorker.perform_async(%{email: "test@mail.com", username: "test"})
      assert worker.worker_module == MyTestWorker
      assert worker.args == %{email: "test@mail.com", username: "test"}
      assert worker.status == :enqueued
      assert worker.attempts == 0
      assert worker.errors == []
      assert worker.opts == []
    end
  end

  describe "perform/1" do
    test "runs perform function for the worker and terminates process" do
      {:ok, worker} =
        %{a: 1}
        |> MyTestWorker.build()
        |> Ant.Workers.create_worker()

      {:ok, pid} = Worker.start_link(worker)

      assert Worker.perform(pid) == :ok

      ref = Process.monitor(pid)

      # Wait for the process to finish its work
      receive do
        {:DOWN, ^ref, :process, ^pid, _reason} ->
          {:ok, updated_worker} = Ant.Repo.get(:ant_workers, worker.id)

          assert updated_worker.status == :completed
          assert updated_worker.attempts == 1
          assert updated_worker.errors == []
      end
    end

    test "retries if worker fails" do
      defmodule FailOnceWorker do
        use Ant.Worker

        def perform(%{attempts: 1}), do: :error
        def perform(_worker), do: :ok

        def calculate_delay(_worker), do: 0
      end

      {:ok, worker} =
        %{a: 1}
        |> FailOnceWorker.build()
        |> Ant.Workers.create_worker()

      {:ok, pid} = Worker.start_link(worker)

      assert Worker.perform(pid) == :ok

      ref = Process.monitor(pid)

      receive do
        {:DOWN, ^ref, :process, ^pid, _reason} ->
          {:ok, updated_worker} = Ant.Repo.get(:ant_workers, worker.id)

          assert updated_worker.status == :completed
          assert updated_worker.attempts == 2

          assert [error] = updated_worker.errors
          assert error.error == "Expected :ok or {:ok, _result}, but got :error"
          assert error.attempt == 1
          refute error.stack_trace
      end
    end

    test "stops retrying after reaching max attempts" do
      {:ok, worker} =
        %{a: 1}
        |> FailWorker.build()
        |> Ant.Workers.create_worker()

      {:ok, pid} = Worker.start_link(worker)

      assert Worker.perform(pid) == :ok

      ref = Process.monitor(pid)

      receive do
        {:DOWN, ^ref, :process, ^pid, _reason} ->
          {:ok, updated_worker} = Ant.Repo.get(:ant_workers, worker.id)

          assert length(updated_worker.errors) == 3
          assert updated_worker.status == :failed
          assert updated_worker.attempts == 3
      end
    end

    test "handles exceptions gracefully and updates worker" do
      {:ok, worker} =
        %{a: 1}
        |> ExceptionWorker.build()
        |> Ant.Workers.create_worker()

      {:ok, pid} = Worker.start_link(worker)

      assert Worker.perform(pid) == :ok

      ref = Process.monitor(pid)

      receive do
        {:DOWN, ^ref, :process, ^pid, _reason} ->
          {:ok, updated_worker} = Ant.Repo.get(:ant_workers, worker.id)

          assert updated_worker.status == :failed
          assert updated_worker.attempts == 3

          errors = updated_worker.errors

          assert Enum.all?(errors, &(&1.error == "Custom exception!"))

          assert Enum.all?(
                   errors,
                   &(&1.stack_trace =~ "Ant.WorkerTest.ExceptionWorker.perform/1")
                 )

          assert errors |> Enum.map(& &1.attempt) |> Enum.sort() == [1, 2, 3]
      end
    end
  end
end
