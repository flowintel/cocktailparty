defmodule Cocktailparty.Input.WebsocketClient do
  use Fresh

  # TODO
  # we keep track of
  [sources: []]

  def handle_connect(status, headers, state) do
    IO.puts("Upgrade request headers:#{inspect(status)} - #{inspect(headers)}")
    {:ok, state}
  end

  def handle_in({:text, content}, state) do
    IO.puts("Received state: #{inspect(content)}")

    {:ok, state}
  end

  def handle_in({:binary, content}, state) do
    IO.puts("Received binary: #{inspect(content)}")
    {:ok, state}
  end

  def handle_in({_, _}, state) do
    {:ok, state}
  end

  def handle_control({:ping, message}, state) do
    IO.puts("Received ping with content: #{message}!")
    {:ok, state}
  end

  def handle_control({:pong, message}, state) do
    IO.puts("Received pong with content: #{message}!")
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
