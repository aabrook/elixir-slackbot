defmodule SlackBot do
  use Application
  use DefBot

  heard "temperature (.*)", tokens do
    IO.puts Enum.at(tokens, 0)
    result = room_temperature Enum.at(tokens, 1)

    if(Enum.empty? result) do
      "Not found"
    else
      temperature_message Enum.at(result, 0)
    end
  end

  heard "list rooms", tokens do
    "Rooms available: " <> Enum.join(rooms, ", ")
  end

  def start do
    start_link(Application.get_env(:slackbot, :key))
  end

  def dbprops do
    ElixirCouchDb.connection %{protocol: Application.get_env(:slackbot, :couchdb_protocol), host: Application.get_env(:slackbot, :couchdb_host), port: Application.get_env(:slackbot, :couchdb_port)}
  end

  def room_temperature room do
    {:ok, result} = ElixirCouchDb.get dbprops, "temperatures", "_design/temperatures/_view/by_room", %{group: true}
    Enum.filter(result["rows"], fn row -> row["key"] == room end)
  end

  def rooms do
    {:ok, result} = ElixirCouchDb.get dbprops, "temperatures", "_design/temperatures/_view/by_room", %{group: true}
    Enum.reduce(result["rows"], [], fn row, acc -> acc ++ [row["key"]] end)
  end

  def temperature_message temp do
    "The #{temp["value"]["room"]} temperature is #{temp["value"]["t"]}C with humidity of #{temp["value"]["h"]}%"
  end
end
