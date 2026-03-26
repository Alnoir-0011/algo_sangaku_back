class DeleteExpiredApiKeysJob < ApplicationJob
  queue_as :default

  def perform
    ApiKey.where("expires_at < ?", Time.current).delete_all
  end
end
