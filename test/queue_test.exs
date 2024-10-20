defmodule Ant.QueueTest do
  alias Ant.Queue

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
      fn %{status: :running, queue_name: "default"} -> {:ok, [build_worker(:running)]} end
    )

    expect(
      Ant.Workers,
      :list_retrying_workers,
      fn %{queue_name: "default"}, _date_time -> {:ok, [build_worker(:retrying)]} end
    )

    expect(DynamicSupervisor, :start_child, 2, fn Ant.WorkersSupervisor, child_spec ->
      assert {Ant.Worker, :start_link, [%Ant.Worker{status: status}]} = child_spec.start

      {:ok, String.to_atom("#{status}_pid")}
    end)

    test_pid = self()

    expect(Ant.Worker, :perform, fn :running_pid ->
      send(test_pid, {:worker_performed, :running})

      :ok
    end)

    expect(Ant.Worker, :perform, fn :retrying_pid ->
      send(test_pid, {:worker_performed, :retrying})

      :ok
    end)

    {:ok, _pid} = Queue.start_link(queue: "default", config: [check_interval: 10])

    assert_receive({:worker_performed, :running})
    assert_receive({:worker_performed, :retrying})
  end

  describe "periodically checks workers" do
    test "processes only stuck workers when their count exceeds concurrency limit" do
      test_pid = self()

      expect(
        Ant.Workers,
        :list_workers,
        fn %{queue_name: "default", status: :running} ->
          {
            :ok,
            [build_worker(1, :running), build_worker(2, :running), build_worker(3, :running)]
          }
        end
      )

      expect(
        Ant.Workers,
        :list_retrying_workers,
        fn %{queue_name: "default"}, _date_time ->
          {
            :ok,
            [build_worker(4, :retrying), build_worker(5, :retrying), build_worker(6, :retrying)]
          }
        end
      )

      interval_in_ms = 5

      {:ok, _pid} =
        Queue.start_link(
          queue: "default",
          config: [check_interval: interval_in_ms, concurrency: 2]
        )

      expect(DynamicSupervisor, :start_child, 4, fn Ant.WorkersSupervisor, child_spec ->
        assert {Ant.Worker, :start_link, [%Ant.Worker{status: status, id: id}]} = child_spec.start

        {:ok, String.to_atom("#{status}_pid_for_periodic_check_#{id}")}
      end)

      expect(Ant.Worker, :perform, 4, fn worker_pid ->
        send(test_pid, {String.to_atom("#{worker_pid}_performed"), :periodic_check})

        :ok
      end)

      reject(Ant.Workers, :list_workers, 1)

      assert_receive({:running_pid_for_periodic_check_1_performed, :periodic_check})
      assert_receive({:running_pid_for_periodic_check_2_performed, :periodic_check})

      # On the next recurring check

      Process.sleep(interval_in_ms * 2)

      assert_receive({:running_pid_for_periodic_check_3_performed, :periodic_check})
      assert_receive({:retrying_pid_for_periodic_check_4_performed, :periodic_check})
    end

    test "runs enqueued and scheduled workers if there is no stuck workers" do
      test_pid = self()

      expect(Ant.Workers, :list_scheduled_workers, fn %{queue_name: "default"}, _date_time ->
        {:ok, [build_worker(:scheduled)]}
      end)

      interval_in_ms = 5

      {:ok, _pid} = Queue.start_link(queue: "default", config: [check_interval: interval_in_ms])

      expect(DynamicSupervisor, :start_child, 2, fn Ant.WorkersSupervisor, child_spec ->
        assert {Ant.Worker, :start_link, [%Ant.Worker{status: status}]} = child_spec.start

        {:ok, String.to_atom("#{status}_pid_for_periodic_check")}
      end)

      expect(
        Ant.Workers,
        :list_workers,
        fn %{queue_name: "default", status: :enqueued} -> {:ok, [build_worker(:enqueued)]} end
      )

      expect(Ant.Worker, :perform, 2, fn pid ->
        status =
          case pid do
            :enqueued_pid_for_periodic_check -> :enqueued
            :scheduled_pid_for_periodic_check -> :scheduled
          end

        send(test_pid, {:"#{status}_worker_performed", :periodic_check})

        :ok
      end)

      # testing periodic check

      Process.sleep(interval_in_ms * 2)

      assert_receive({:enqueued_worker_performed, :periodic_check})
      assert_receive({:scheduled_worker_performed, :periodic_check})
    end
  end

  defp build_worker(id, status) do
    status
    |> build_worker()
    |> Map.put(:id, id)
  end

  defp build_worker(status) do
    %{initial_status: status}
    |> TestWorker.build()
    |> Map.merge(%{id: :erlang.unique_integer([:positive]), status: status})
  end
end
