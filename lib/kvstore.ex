defmodule KVstore do
  use Application

  def start(_type, _args) do
    KVstore.Supervisor.start_link(name: KVstore.Supervisor)
  end
end
