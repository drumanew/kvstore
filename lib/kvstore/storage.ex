#Этот модуль должен реализовать механизмы CRUD для хранения данных. Если одного модуля будет мало, то допускается создание модулей с префиксом "Storage" в названии.

defmodule KVstore.Storage do
  use GenServer

  ## API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, [name: __MODULE__])
  end

  def available() do
    try do call(:available) catch :exit, _ -> false end
  end

  def set(key, value, ttl) do
    set(%{ key: key, value: value, ttl: ttl })
  end

  def set(data) when is_map(data) do
    set([data])
  end

  def set(data) when is_list(data) do
    if Enum.all?(data, &KVstore.Utils.valid_data/1) do
      call({ :set, data })
    else
      { :error, :badarg }
    end
  end

  def all() do
    call(:all)
  end

  def clear() do
    call(:clear)
  end

  def get(key) do
    call({ :get, key })
  end

  def delete(key) do
    call({ :delete, key })
  end

  ## Server Callbacks

  def init(:ok) do
    Process.flag(:trap_exit, true)

    open_tab = &:dets.open_file(:kvstore, [file: &1])

    { :ok, tab } =
      Application.get_env(:kvstore, :db_file)
      |> open_tab.()

    state =
      %{ tab: tab }
      |> do_delete_aged
      |> do_init_times
      |> do_init_age_timer

    { :ok, state }
  end

  def handle_call(:available, _from, state) do
    { :reply, :true, state }
  end

  def handle_call({ :set, data }, _from, state = %{ tab: tab }) do
    now = :erlang.system_time(:second)

    transform = &({ &1.key, &1.value, &1.ttl + now })
    insert = &:dets.insert(tab, &1)

    reply =
      data
      |> Enum.map(transform)
      |> insert.()

    { :reply, reply, state }
  end

  def handle_call(:all, _from, state = %{ tab: tab }) do
    import Ex2ms

    now = :erlang.system_time(:second)

    selector = fun do (item) -> item end
    filter = fn ({ _, _, time }) -> time >= now end
    transform = fn ({ key, value, _ }) -> %{ key: key, value: value } end

    reply =
      :dets.select(tab, selector)
      |> Enum.filter(filter)
      |> Enum.map(transform)

    { :reply, reply, state }
  end

  def handle_call(:clear, _from, state = %{ tab: tab }) do
    reply = :dets.delete_all_objects(tab)

    { :reply, reply, state }
  end

  def handle_call({ :get, key }, _from, state = %{ tab: tab }) do
    now = :erlang.system_time(:second)

    lookup = &:dets.lookup(tab, &1)
    filter = fn ({ _, _, time }) -> time >= now end
    transform = fn ({ key, value, _ }) -> %{ key: key, value: value } end

    reply =
      key
      |> lookup.()
      |> Enum.filter(filter)
      |> Enum.map(transform)

    { :reply, reply, state }
  end

  def handle_call({ :delete, key }, _from, state = %{ tab: tab }) do
    reply = :dets.delete(tab, key)

    { :reply, reply, state }
  end

  def handle_call(_req, _from, state) do
    { :reply, :ignored, state }
  end

  def handle_cast(_msg, state) do
    { :noreply, state }
  end

  def handle_info({ :timeout, ref, time }, state = %{ ref: ref, await: time }) do
    { :noreply, do_handle_timeout(state) }
  end

  def handle_info(_info, state) do
    { :noreply, state }
  end

  def terminate(_reason, _state = %{ tab: tab }) do
    :ok = :dets.close(tab)
  end

  ## private

  defp call(msg) do
    GenServer.call(__MODULE__, msg)
  end

  defp do_delete_aged(state = %{ tab: tab }) do
    import Ex2ms

    now = :erlang.system_time(:second)
    selector = fun do ({ _, _, time }) -> time < ^now end

    deleted = :dets.select_delete(tab, selector)

    case deleted do
      0 -> :ok;
      1 -> IO.puts "1 aged entry deleted";
      _ -> IO.puts "#{deleted} aged entries deleted"
    end

    state
  end

  defp do_init_times(state = %{ tab: tab }) do
    append_value =
      fn (key, value, tree) ->
        case :gb_trees.lookup(key, tree) do
          :none ->
            :gb_trees.insert(key, MapSet.new([value]), tree);
          {:value, oldvalue} ->
            :gb_trees.insert(key, MapSet.put(oldvalue, value), tree)
        end
      end

    reduce =
      fn ({ key, _, time }, acc) ->
        append_value.(time, key, acc)
      end

    times = :dets.foldl(reduce, :gb_trees.empty(), tab)

    state
    |> Map.put(:times, times)
    |> Map.put(:ref, :undefined)
    |> Map.put(:await, :undefined)
  end

  defp do_init_age_timer(state = %{ times: times, await: await, ref: ref }) do
    if :gb_trees.size(times) > 0 do
      { time, _keys } = :gb_trees.smallest(times)
      if time < await || await == :undefined do
        ref = update_age_timer(time, ref)
        state
        |> Map.put(:ref, ref)
        |> Map.put(:await, time)
      else
        state
      end
    else
      state
    end
  end

  defp update_age_timer(time, ref) do
    if :erlang.is_reference(ref) do
      :erlang.cancel_timer(ref)
    end
    now = :erlang.system_time(:second)
    delay = if time < now do 0 else time - now end
    :erlang.start_timer(delay*1000, :erlang.self(), time)
  end

  defp do_handle_timeout(state = %{ tab: tab, times: times, await: await }) do
    case :gb_trees.lookup(await, times) do
      { :value, keys } ->
         times = :gb_trees.delete(await, times)
         for key <- keys do
           :ok = :dets.delete(tab, key)
           IO.puts("aged item deleted, key: #{key}")
         end

         state
         |> Map.put(:times, times)
         |> Map.put(:await, :undefined)
         |> Map.put(:ref, :undefined);
      _ ->
         state
    end |> do_init_age_timer()
  end
end
