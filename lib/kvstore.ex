defmodule KVstore do
  use Application

  def start(_type, _args) do
    dispatch = KVstore.Router.build_routes()

    :cowboy.start_http(:my_http_listener,
                       100,
                       [{ :port, 8080 }],
                       [{ :env, [{ :dispatch, dispatch }] }]
    )

    KVstore.Supervisor.start_link()
  end
end
