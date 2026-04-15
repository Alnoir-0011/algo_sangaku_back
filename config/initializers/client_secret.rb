if Rails.env.production? && ENV["CLIENT_SECRET"].blank?
  raise "環境変数 CLIENT_SECRET が設定されていません。設定してからサーバーを起動してください。"
end
