#Этот модуль должен реализовать механизмы CRUD для хранения данных. Если одного модуля будет мало, то допускается создание модулей с префиксом "Storage" в названии.
defmodule KVstore.Storage do
  use GenServer

  ## API

  def start_link(opts) do
    if opts != [] do
      IO.puts("called KVstore.Storage.start_link(#{inspect opts})")
    end
    GenServer.start_link(__MODULE__, :ok, [name: KVstore.Storage])
  end

  ## Server Callbacks

  def init(:ok) do
    IO.puts("init")
    { :ok, %{} }
  end

  def handle_call(_req, _from, state) do
    IO.puts("handle_call")
    { :reply, :ignored, state }
  end

  def handle_cast(_msg, state) do
    IO.puts("handle_cast")
    { :noreply, state }
  end

  def handle_info(_info, state) do
    IO.puts("handle_info")
    { :noreply, state }
  end

  def terminate(_reason, _state) do
    IO.puts("terminate")
    :ok
  end
end
