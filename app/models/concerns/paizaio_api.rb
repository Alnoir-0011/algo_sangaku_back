module PaizaioApi
  extend ActiveSupport::Concern

  def run_source(source, input = "", language = "ruby")
    id = create(source, language, input)
    status = "running"

    while status == "running"
      sleep(100.0 / 1000.0)
      status = get_status(id)
    end

    result = get_details(id)
    result
  end

  def create(source, language, input)
    api_url = "https://api.paiza.io/runners/create.json"
    uri = URI(api_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme === "https"

    headers = { "Content-Type" => "application/json" }
    params = {
      "api_key" => "guest",
      "source_code" => source,
      "language" => language,
      "input" => input
    }

    req = Net::HTTP::Post.new(uri.path)
    req.body = params.to_json
    req.initialize_http_header(headers)

    res = http.request(req)

    case res
    when Net::HTTPOK
      body = JSON.parse(res.body)
      if body.include?("id")
        body["id"]
      elsif body.include?("error")
        raise StandardError.new("コードが実行できませんでした")
      end
    else
      raise StandardError.new("リクエストに失敗しました")
    end
  end

  def get_status(id)
    api_url = "https://api.paiza.io:443/runners/get_status.json"
    uri = URI(api_url)
    params = {
      "api_key" => "guest",
      "id" => id
    }

    uri.query = URI.encode_www_form(params)
    res = Net::HTTP.get_response(uri)

    case res
    when Net::HTTPOK
      body = JSON.parse(res.body)
      if body.include?("status")
        body["status"]
      else
        raise StandardError.new("idが無効です")
      end
    else
      raise StandardError.new("リクエストに失敗しました")
    end
  end

  def get_details(id)
    api_url = "https://api.paiza.io:443/runners/get_details.json"
    uri = URI(api_url)
    params = {
      "api_key" => "guest",
      "id" => id
    }

    uri.query = URI.encode_www_form(params)
    res = Net::HTTP.get_response(uri)

    case res
    when Net::HTTPOK
      body = JSON.parse(res.body)
      if body.include?("stdout")
        body
      else
        raise StandardError.new("idが無効です")
      end
    else
      raise StandardError.new("リクエストに失敗しました")
    end
  end
end
