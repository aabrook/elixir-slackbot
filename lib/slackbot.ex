defmodule SlackBot do
  use Application
  use Slack

  def start do
    start_link(Application.get_env(:slackbot, :key))
  end

  def dbprops do
    %{protocol: Application.get_env(:slackbot, :couchdb_protocol), hostname: Application.get_env(:slackbot, :couchdb_host), port: Application.get_env(:slackbot, :couchdb_port)}
  end

  def thermo_db(props) do
    {:ok, Map.merge(props, %{ database: "temperatures" })}
  end

  def room_temperature room do
    {:ok, props} = thermo_db dbprops
    key = %{design: "temperatures", view: "by_room", key: room}
    Couchdb.Connector.View.document_by_key(props, key)
  end

  def handle_connect(slack) do
    IO.puts "Connected as #{slack.me.name}"
  end

  def handle_message(message = %{type: "message"}, slack) do
    send_message("I heard that!", message.channel, slack)
    hears(message, slack)
  end
  def handle_message(_,_), do: :ok

  def handle_info({:message, text, channel}, slack) do
    IO.puts "Sending your message, captain!"

    send_message(text, channel, slack)

    {:ok, slack}
  end
  def handle_info(_, _), do: :ok

  def hears(message, slack) do
    hears = [
      %{regex: ~r/.*temperature?(in)?(.*).*/, cb: fn tokens, msg, slack ->
        {:ok, result} = room_temperature Enum.at(tokens, 1)
        send_message result, message.channel, slack
      end},
      %{regex: ~r/^hello (.*)/i, cb: fn tokens, msg, slack -> send_message("Why hello " <> Enum.at(tokens, 1), message.channel, slack) end},
      %{regex: ~r/^sup$/i, cb: fn tokens, msg, slack -> send_message("Not much. Sup wit u?", message.channel, slack) end},
      %{regex: ~r/^sup (.*)/i, cb: fn tokens, msg, slack -> send_message("Not much " <> Enum.at(tokens, 1) <> ". Sup wit u", message.channel, slack) end}
    ]
  
    Enum.each(hears, fn(x) ->
      if Regex.match?(x[:regex], message[:text]) do
        x[:cb].(Regex.run(x[:regex], message[:text]), message, slack)
      end
    end)
  end
end
