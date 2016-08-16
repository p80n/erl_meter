defmodule ErlMeter.PostHelper do

  import List

  def api_base(:couch), do: "http://#{Application.get_env(:erl_meter, :host)}:#{Application.get_env(:erl_meter, :port)}"
  def api_base(:api),   do: "#{Application.get_env(:erl_meter, :protocol)}://#{Application.get_env(:erl_meter, :host)}:#{Application.get_env(:erl_meter, :port)}"


  def post(endpoint, struct, database \\ "staging_inventory") do
    IO.write String.upcase(String.at(List.last(String.split(endpoint, "/")), 0))
    case Application.get_env(:erl_meter, :destination) do
      :api ->   base_post(endpoint, struct, "api/v1")
      :couch -> base_post(nil, struct, database)
    end
  end

  def async_post(endpoint, struct, database \\ "staging_inventory") do
    IO.write String.upcase(String.at(List.last(String.split(endpoint, "/")), 0))
    case Application.get_env(:erl_meter, :destination) do
      :api ->   Task.async( fn -> base_post(endpoint, struct, "api/v1") end )
      :couch -> Task.async( fn -> base_post(nil, struct, database) end )
    end
  end

  def base_post(endpoint, struct, root) do
    url = "#{api_base(Application.get_env(:erl_meter, :destination))}/#{root}/#{endpoint}"

    {:ok, body} = Poison.encode(struct)

    headers = [{"Accept", "application/json"}, {"Content-Type", "application/json"}]
#    options = [{:timeout, :infinity}, {:recv_timeout, :infinity},
    options = [ hackney: [ basic_auth: {"admin", "wacit"} ] ]
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
