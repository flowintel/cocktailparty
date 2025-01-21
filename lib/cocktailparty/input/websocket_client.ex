defmodule Cocktailparty.Input.WebsocketClient do
  require Logger
  use Fresh

  # TODO binary data etc.
  defstruct [:subscribed, :input_datatype]

  def handle_info({:subscribe, source = %{name: {:source, _}}}, state) do
    Logger.error("Received SUB")
    # with pid <- :global.whereis_name(source.name) do
    # Logger.info("Received SUB from #{:erlang.pid_to_list(pid) |> to_string}")
    {:ok,
     Map.put(
       state,
       :subscribed,
       MapSet.put(state.subscribed, source) |> Map.put(:input_datatype, state.input_datatype)
     )}

    # end
  end

  def handle_info({:unsubscribe, source = %{name: {:source, _}}}, state) do
    with pid <- :global.whereis_name(source.name) do
      Logger.info("Received UNSUB from #{:erlang.pid_to_list(pid) |> to_string}")
      {:ok, Map.put(state, :subscribed, MapSet.delete(state.subscribed, source))}
    end
  end

  def handle_connect(status, headers, state) do
    IO.puts("Upgrade request headers:#{inspect(status)} - #{inspect(headers)}")
    {:ok, state}
  end

  def handle_in({datatype, content}, state) do
    if state.input_datatype == datatype do
      if state.subscribed != MapSet.new() do
        Enum.each(state.subscribed, fn source ->
          case :global.whereis_name(source.name) do
            :undefined ->
              {:source, n} = source.name
              Process.exit(self(), "Cannot find process \#{:source, #{n}\}")

            pid ->
              case datatype do
                :text ->
                  send(pid, {:new_text_message, content})

                :binary ->
                  send(pid, {:new_binary_message, content})

                _ ->
                  {:ok, state}
              end
          end
        end)
      end
    end

    {:ok, state}
  end

  def handle_control({:ping, _message}, state) do
    # IO.puts("Received ping with content: #{message}!")
    {:ok, state}
  end

  def handle_control({:pong, _message}, state) do
    # IO.puts("Received pong with content: #{message}!")
    {:ok, state}
  end

  def handle_disconnect(1002, _reason, _state), do: :reconnect
  def handle_disconnect(_code, _reason, _state), do: :close

  def handle_error({error, _reason}, state)
      when error in [:encoding_failed, :casting_failed],
      do: {:ignore, state}

  def handle_error(_error, _state), do: :reconnect

  def handle_terminate(reason, _state) do
    IO.puts("Process is terminating with reason: #{inspect(reason)}")
  end
end
