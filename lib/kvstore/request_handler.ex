defmodule KVstore.RequestHandler do
  def init({ :tcp, :http }, req, opts) do
    { :upgrade, :protocol, :cowboy_rest, req, opts }
  end

  def rest_init(req, _opts) do
    { key, req2 } = :cowboy_req.binding(:key, req)

    { :ok, req2, %{ key: key } }
  end

  def rest_terminate(_req, _state) do
    :ok
  end

  def allowed_methods(req, state) do
    { ["GET", "HEAD", "OPTIONS", "POST", "DELETE"], req, state }
  end

  def service_available(req, state) do
    { KVstore.Storage.available, req, state }
  end

  def content_types_provided(req, state) do
    { [{ "application/json", :to_json }], req, state }
  end

  def resource_exists(req, state = %{ key: :undefined }) do
    { true, req, state }
  end

  def resource_exists(req, state = %{ key: key }) do
    data =
      key
      |> KVstore.Storage.get

    body =
      data
      |> KVstore.Utils.to_json

    exists = data != []

    { exists, req, Map.put(state, :reply, body) }
  end

  def to_json(req, state = %{ key: :undefined }) do
    body =
      KVstore.Storage.all
      |> KVstore.Utils.to_json

    { body, req, state }
  end

  def to_json(req, state = %{ reply: body }) do
    { body, req, state }
  end

  def content_types_accepted(req, state) do
    { [{ "application/json", :from_json }], req, state }
  end

  def from_json(req, state) do
    { :ok, body, req2 } = :cowboy_req.body(req)

    result = :ok ==
      body
      |> KVstore.Utils.from_json
      |> KVstore.Storage.set

    { result, req2, state }
  end

  def delete_resource(req, state = %{ key: :undefined }) do
    { KVstore.Storage.clear(), req, state }
  end

  def delete_resource(req, state = %{ key: key }) do
    result = :ok == KVstore.Storage.delete(key)
    { result, req, state }
  end
end
