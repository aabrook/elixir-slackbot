defmodule ElixirCouchDb do
  require Logger

  def connection opts \\ %{} do
    options = Map.merge(%{
                          protocol: Application.get_env(:slackbot,:couchdb_protocol),
                          host:     Application.get_env(:slackbot,:couchdb_host),
                          hostname:     Application.get_env(:slackbot,:couchdb_host),
                          port: Application.get_env(:slackbot,:couchdb_port),
                          cache: nil,
                          timeout: 5000,
                          user: Application.get_env(:slackbot,:couchdb_username),
                          password: Application.get_env(:slackbot,:couchdb_password),
                        }, opts)

    baseUrl = "#{options[:protocol]}://#{options[:user]}:#{options[:password]}@#{options[:host]}:#{options[:port]}"
    Map.merge(options, %{baseUrl: baseUrl})
  end

  def auth do
    [:basic_auth, {
       Application.get_env(:slackbot,:couchdb_username),
       Application.get_env(:slackbot,:couchdb_password)
     }]
  end

  def default_auth do
    [
      {:basic_auth, {
        Application.get_env(:slackbot,:couchdb_username),
        Application.get_env(:slackbot,:couchdb_password)
      }}
    ]
  end

  def serverConnection opts \\ %{} do
    opts
    |> connection
    |> Map.fetch!(:baseUrl)
    |> Couchex.server_connection(default_auth)
  end

  def get options, dbname, uri, query \\ [] do
    parseResult(getRequest(options, dbname <> "/" <> uri, query))
  end

  def create options, dbname do
    parseResult(putRequest options, dbname, %{})
  end

  def drop options, dbname do
    parseResult(deleteRequest options, dbname, %{})
  end

  def insert options, dbname, data do
    parseResult(postRequest options, dbname, data)
  end

  def update options, dbname, data do
    if (!data[:_id] || !data[:_rev]) do
      {:error, %{ message: "An _id and _rev must b provided" } }
    else
      parseResult(putRequest options, dbname <> "/" <> data[:_id], data)
    end
  end

  def del options, dbname, data do
    if (!data[:_id] || !data[:_rev]) do
      {:error, %{ message: "An _id and _rev must b provided" } }
    else
      parseResult(deleteRequest options, dbname <> "/" <> data[:_id], %{rev: data[:_rev]})
    end
  end

  def listDatabases options do
    parseResult(getRequest options, "_all_dbs", %{})
  end

  defp getRequest options, target, query \\ [] do
    IO.inspect options
    IO.inspect target
    IO.inspect query
    HTTPotion.get(options.baseUrl <> "/" <> target, [auth | query])
  end

  defp postRequest options, target, query do
    HTTPotion.post options.baseUrl <> "/" <> target, [auth | query]
  end

  defp deleteRequest options, target, query do
    HTTPotion.post options.baseUrl <> "/" <> target, [auth | query]
  end

  defp putRequest options, target, query do
    HTTPotion.post options.baseUrl <> "/" <> target, [auth | query]
  end

  defp parseResult result do
    (result.status_code == 200 && successMessage result) || errorMessage result
  end

  defp errorMessage result do
    case Poison.decode(result.body) do
      %{body: m} -> {:error, Map.get(m, "reason")}
      %{"message" => message} -> {:error, message}
      x -> {:error, x}
    end
  end

  defp successMessage result do
    {:ok, Poison.decode! result.body}
  end

end
