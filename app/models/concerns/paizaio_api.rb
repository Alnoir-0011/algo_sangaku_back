module PaizaioApi
  extend ActiveSupport::Concern

  MAX_POLL_ATTEMPTS = 30

  def run_source(source, input = "", language = "ruby")
    id = create_runner(source, language, input)
    status = "running"
    attempts = 0

    while status == "running"
      raise StandardError, "PaizaIO polling timeout" if attempts >= MAX_POLL_ATTEMPTS

      sleep(100.0 / 1000.0)
      status = get_status(id)
      attempts += 1
    end

    get_details(id)
  end

  def create_runner(source, language, input)
    api_url = "https://api.paiza.io/runners/create.json"
    uri = URI(api_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme === "https"
    http.open_timeout = 10
    http.read_timeout = 30

    headers = { "Content-Type" => "application/json" }
    params = {
      "api_key" => ENV.fetch("PAIZAIO_API_KEY", "guest"),
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
      "api_key" => ENV.fetch("PAIZAIO_API_KEY", "guest"),
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
      "api_key" => ENV.fetch("PAIZAIO_API_KEY", "guest"),
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
