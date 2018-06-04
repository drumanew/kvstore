defmodule KVstore do
  use Application

  def start(_type, _args) do
    dispatch = KVstore.Router.build_routes()

    port = Application.get_env(:kvstore, :port, 8080)

    :cowboy.start_http(:my_http_listener,
                       100,
                       [{ :port, port }],
                       [{ :env, [{ :dispatch, dispatch }] }]
    )

    KVstore.Supervisor.start_link()
  end
end
