require 'rails_helper'

RSpec.describe DeleteExpiredApiKeysJob, type: :job do
  let!(:active_key) { create(:api_key) }
  let!(:expired_key) { create(:api_key, :expired) }

  describe '#perform' do
    it '期限切れの ApiKey を削除する' do
      expect { described_class.perform_now }.to change(ApiKey, :count).by(-1)
      expect(ApiKey.exists?(expired_key.id)).to be false
    end

    it '有効期限内の ApiKey は削除しない' do
      described_class.perform_now
      expect(ApiKey.exists?(active_key.id)).to be true
    end
  end

  describe 'enqueue' do
    it 'ジョブをキューに追加できる' do
      ActiveJob::Base.queue_adapter = :test
      expect { DeleteExpiredApiKeysJob.perform_later }.to have_enqueued_job(DeleteExpiredApiKeysJob)
    end
  end
end
