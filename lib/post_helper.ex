defmodule ErlMeter.PostHelper do

  import List

  def api_base(:couch), do: "http://#{Application.get_env(:erl_meter, :host)}:#{Application.get_env(:erl_meter, :port)}"
  def api_base(:api),   do: "#{Application.get_env(:erl_meter, :protocol)}://#{Application.get_env(:erl_meter, :host)}:#{Application.get_env(:erl_meter, :port)}"

  def post(endpoint, struct, database \\ "on_prem_api_inventory") do
    IO.write String.upcase(String.at(List.last(String.split(endpoint, "/")), 0))
    destination = Application.get_env(:erl_meter, :destination)
    body = case destination do
             :api ->   base_post(endpoint, struct, "api/v1")
             :couch -> base_post(nil, struct, database)
           end
    # clean this up >.<
    item = Poison.Parser.parse!(body)
    case struct do
      %ErlMeter.Machine{} ->
        case destination do
          :api ->
            [ disk ] = item["embedded"]["disks"]
            [ lan | [wan] ] = item["embedded"]["nics"]
            %ErlMeter.Machine{ id: item["id"],
                               name: item["name"],
                               status: item["status"],
                               tags: item["tags"],
                               cpu_count: item["cpu_count"],
                               cpu_speed_hz: item["cpu_speed_hz"],
                               memory_bytes: item["memory_bytes"],
                               disks: [ %ErlMeter.Disk{ id: disk["id"] } ],
                               nics: [ %ErlMeter.Nic{ id: lan["id"] },
                                       %ErlMeter.Nic{ id: wan["id"] } ] }

          :couch ->
            %ErlMeter.Machine{ id: item["id"],
                               name: item["name"],
                               cpu_count: item["cpu_count"],
                               cpu_speed_hz: item["cpu_speed_hz"] }
        end

      # For orgs and infs, we only want the ID
      _ -> Map.put(struct, :id, item["id"])
    end
  end


  def base_post(endpoint, struct, root) do
    url = "#{api_base(Application.get_env(:erl_meter, :destination))}/#{root}/#{endpoint}"

    {:ok, body} = Poison.encode(struct)

    token = Application.get_env(:erl_meter, :token)

    headers =
      case token do
        nil -> [{"Accept", "application/json"}, {"Content-Type", "application/json"}]
        _ -> [{"Accept", "application/json"}, {"Content-Type", "application/json"}, {"Authorization", "Bearer #{token}"}]
      end

    options = [{:timeout, :infinity}, {:recv_timeout, :infinity}]

    case HTTPoison.post(url, body, headers, options) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        body
       {:ok, %HTTPoison.Response{status_code: 201, body: body}} ->
        body
       {:ok, %HTTPoison.Response{status_code: 500, body: body, headers: headers}} ->
         {_, request_id} = keyfind(headers, "X-Request-Id", 0)
         {:ok, file} = File.open "#{request_id}.log.html", [:write]
         IO.binwrite file, body
         File.close file
         IO.puts "\n500 returned for post to #{url}. Response body dumped to file: #{request_id}.log.html"
         exit("ack")
       {:ok, %HTTPoison.Response{status_code: 404}} ->
         IO.puts "\n404 returned posting to: #{url}"
         nil
         exit("ack")
       {:ok, %HTTPoison.Response{status_code: 422, body: body }} ->
         IO.puts "422: #{body}"
         nil
         exit("ack")
       {:error, %HTTPoison.Error{reason: reason}} ->
         IO.puts "ERROR: #{reason}"
         nil
         exit("ack")
       {:ok, %HTTPoison.Response{status_code: status_code, body: body }} ->
         IO.puts "Error posting to: #{url}. Status Code: #{status_code}. Response Body: #{body}"
         nil
         exit("ack")
       _ ->
         IO.puts "Unhandled response received posting to: #{url}"
         nil
         exit("ack")
     end
  end

end
