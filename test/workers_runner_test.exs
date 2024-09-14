defmodule Ant.WorkersRunnerTest do
  alias Ant.WorkersRunner

  use ExUnit.Case
  use Mimic

  defmodule TestWorker do
    use Ant.Worker

    def perform(_worker), do: :ok

    def calculate_delay(_worker), do: 0
  end

  setup do
    Mimic.copy(Ant.Workers)
    Mimic.copy(Ant.Worker)
    Mimic.copy(DynamicSupervisor)

    :ok
  end

  setup :set_mimic_global
  setup :verify_on_exit!

  test "runs pending workers on start" do
    expect(
      Ant.Workers,
      :list_workers,
      fn :enqueued -> {:ok, [build_worker(:enqueued)]} end
    )

    expect(
      Ant.Workers,
      :list_workers,
      fn :running -> {:ok, [build_worker(:running)]} end
    )

    expect(
      Ant.Workers,
      :list_workers,
      fn :retrying -> {:ok, [build_worker(:retrying)]} end
    )

    expect(DynamicSupervisor, :start_child, 3, fn Ant.WorkersSupervisor, child_spec ->
      assert {Ant.Worker, :start_link, [%Ant.Worker{status: status}]} = child_spec.start

      {:ok, String.to_atom("#{status}_pid")}
    end)

    test_pid = self()

    expect(Ant.Worker, :perform, fn :enqueued_pid ->
      send(test_pid, {:worker_performed, :enqueued})

      :ok
    end)

    expect(Ant.Worker, :perform, fn :running_pid ->
      send(test_pid, {:worker_performed, :running})

      :ok
    end)

    expect(Ant.Worker, :perform, fn :retrying_pid ->
      send(test_pid, {:worker_performed, :retrying})

      :ok
    end)

    {:ok, _pid} = WorkersRunner.start_link(check_interval: 10_000)

    assert_receive({:worker_performed, :enqueued})
    assert_receive({:worker_performed, :running})
    assert_receive({:worker_performed, :retrying})
  end

  test "periodically checks enqueued workers" do
    expect(
      Ant.Workers,
      :list_workers,
      fn
        :enqueued -> {:ok, [build_worker(:enqueued)]}
        _ -> {:ok, []}
      end
    )

    expect(DynamicSupervisor, :start_child, fn Ant.WorkersSupervisor, child_spec ->
      assert {Ant.Worker, :start_link, [%Ant.Worker{}]} = child_spec.start

      {:ok, :enqueued_pid}
    end)

    test_pid = self()

    expect(Ant.Worker, :perform, fn :enqueued_pid ->
      send(test_pid, {:worker_performed, :enqueued})

      :ok
    end)

    interval_in_ms = 5

    {:ok, _pid} = WorkersRunner.start_link(check_interval: interval_in_ms)

    assert_receive({:worker_performed, :enqueued})

    # testing periodic check

    expect(DynamicSupervisor, :start_child, fn Ant.WorkersSupervisor, child_spec ->
      assert {Ant.Worker, :start_link, [%Ant.Worker{}]} = child_spec.start

      {:ok, :pid_for_periodic_check}
    end)

    expect(
      Ant.Workers,
      :list_workers,
      fn :enqueued -> {:ok, [build_worker(:enqueued)]} end
    )

    expect(Ant.Worker, :perform, fn :pid_for_periodic_check ->
      send(test_pid, {:worker_performed, :periodic_check})

      :ok
    end)

    Process.sleep(interval_in_ms * 2)

    assert_receive({:worker_performed, :periodic_check})
  end

  defp build_worker(status) do
    %{initial_status: status}
    |> TestWorker.build()
    |> Map.merge(%{id: :erlang.unique_integer([:positive]), status: status})
  end
end
