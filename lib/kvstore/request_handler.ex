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
    { ["GET", "HEAD", "OPTIONS", "POST"], req, state }
  end

  def service_available(req, state) do
    { :true, req, state }
  end

  def content_types_provided(req, state) do
    { [{ "application/json", :to_json }], req, state }
  end

  def resource_exists(req, state = %{ key: key }) do
    IO.puts("check exists: key: #{key}")
    { :true, req, state }
  end

  def to_json(req, state = %{ key: key }) do
    IO.puts("to_json: key: #{key}")
    body = "{\"rest\": \"#{key}\"}"
    { body, req, state }
  end

  def content_types_accepted(req, state) do
    { [{ "application/json", :from_json }], req, state }
  end

  def from_json(req, state = %{ key: key }) do
    IO.puts("from_json: key: #{key}")
    { true, req, state }
  end
end
