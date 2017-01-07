defmodule SlackBot do
  use Application
  use DefBot

  heard "temperature", tokens do
    IO.puts Enum.at(tokens, 0)
    temperature_message ""
  end

  heard "list rooms", tokens do
    case rooms do
      x when is_list(x) -> "Rooms available: " <> Enum.join(rooms, ", ")
      x when is_bitstring(x) -> x
      _ -> "Failed to find rooms"
    end
  end

  def start do
    start_link(Application.get_env(:slackbot, :key))
  end

  defp rooms do
    ElixirCouchDb.connection
    |> then(&(ElixirCouchDb.get(&1, "stasis", "_design/locations/_view/rooms", [query: %{group: true}])))
    |> then(&(decode_room_names(&1)))
    |> return
  end

  defp temperature_message temp do
    ElixirCouchDb.connection
    |> then(&(ElixirCouchDb.get(&1, "stasis", "_design/temperatures/_view/list_all")))
    |> then(&(Map.get(&1, "rows")))
    |> then(&(decode_temperature_rows &1))
    |> then(&Enum.sort(&1, fn a, b -> compare_by_time(a, b) end))
    |> then(&Enum.group_by(&1, fn x -> Map.get(x, :r) end))
    |> IO.inspect

    "Not finished"
  end

  defp compare_by_time(a, b) do
    a.time >= b.time
  end

  defp fetch_view(db, view, opts \\ []) do
    Couchex.fetch_view(db, view, opts)
  end

  defp open_db(server, db) do
    Couchex.open_db(server, db)
  end

  defp decode_room_names(rooms) do
    Enum.reduce(Map.get(rooms, "rows"), [], fn(%{"key" => k}, acc) ->
      [IO.inspect(k) | acc]
    end)
  end

  defp decode_temperature_rows rows do
    {:ok,
      Enum.reduce(rows, [], fn %{"id" => _,
                      "key" => key,
                      "value" => %{"r" => r, "h" => h, "t" => t, "time" => time}}, acc ->
        [%{r: r, h: h, t: t, time: time} | acc]
      end)
    }
  end

  defp then(data, func) do
    try do
      case data do
        {:ok, result} -> func.(result)
        {:error, _} -> data
        _ -> func.(data)
      end
    rescue
      e -> {:error, "Nope: #{e.message}"}
    end
  end

  defp return(data) do
    case data do
      {:ok, val} -> val
      {:error, message} -> message
      _ -> data
    end
  end
end
