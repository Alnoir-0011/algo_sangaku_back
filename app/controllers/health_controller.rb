class HealthController < ActionController::Base
  def show
    ActiveRecord::Base.connection.execute("SELECT 1")
    render json: { status: "ok" }, status: :ok
  rescue => e
    Rails.logger.error("Health check failed: #{e.message}")
    render json: { status: "error" }, status: :service_unavailable
  end
end
