require 'rails_helper'

RSpec.describe ApiKey, type: :model do
  include ActiveSupport::Testing::TimeHelpers

  describe 'initialization' do
    it 'access_token が自動で設定される' do
      api_key = ApiKey.new
      expect(api_key.access_token).to be_present
    end

    it 'expires_at がログインから7日後に設定される' do
      travel_to(Time.current) do
        api_key = ApiKey.new
        expect(api_key.expires_at).to eq(1.week.from_now)
      end
    end
  end

  describe '.active scope' do
    let!(:active_key) { create(:api_key) }
    let!(:expired_key) { create(:api_key, :expired) }

    it '有効期限内の ApiKey のみ返す' do
      expect(ApiKey.active).to include(active_key)
      expect(ApiKey.active).not_to include(expired_key)
    end
  end
end
