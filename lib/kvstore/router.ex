#Для веб сервера нужен маршрутизатор, место ему именно тут.

defmodule KVstore.Router do
  def build_routes do
    api_endpoint = Application.get_env(:kvstore, :api_endpoint)

    :cowboy_router.compile([
      # match on all hostnames
      { :'_',

        # The following list specifies all the routes for hosts matching the
        # previous specification.  The list takes the form of tuples, each one
        # being { PathMatch, Handler, Options }
        [

          # When a request is sent to this endpoint, pass the request to
          # handler defined in module KVstore.RequestHandler
          { "#{api_endpoint}/[:key]/", KVstore.RequestHandler, [] }
        ]
      }
    ])
  end
end
