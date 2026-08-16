if Rails.env.production? && ENV["PAIZAIO_API_KEY"].blank?
  raise "環境変数 PAIZAIO_API_KEY が設定されていません。設定してからサーバーを起動してください。"
end
