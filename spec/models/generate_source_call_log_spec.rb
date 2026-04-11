require 'rails_helper'

RSpec.describe GenerateSourceCallLog, type: :model do
  describe "associations" do
    it "belongs to user" do
      log = build(:generate_source_call_log)
      expect(log.user).to be_a(User)
    end
  end

  describe "validations" do
    it "is invalid without called_at" do
      log = build(:generate_source_call_log, called_at: nil)
      expect(log).to be_invalid
      expect(log.errors[:called_at]).to be_present
    end
  end

  describe ".current_day_range" do
    context "when JST time is 2:59:59 (before boundary)" do
      it "returns range from previous day 3:00 to current day 3:00" do
        now = ActiveSupport::TimeZone["Asia/Tokyo"].local(2026, 4, 10, 2, 59, 59) # JST 2:59:59

        range = described_class.current_day_range(now)

        expect(range.begin).to eq ActiveSupport::TimeZone["Asia/Tokyo"].local(2026, 4, 9, 3, 0, 0)
        expect(range.end).to eq ActiveSupport::TimeZone["Asia/Tokyo"].local(2026, 4, 10, 3, 0, 0)
      end
    end

    context "when JST time is exactly 3:00:00 (at boundary)" do
      it "returns range from current day 3:00 to next day 3:00" do
        now = ActiveSupport::TimeZone["Asia/Tokyo"].local(2026, 4, 10, 3, 0, 0) # JST 3:00:00

        range = described_class.current_day_range(now)

        expect(range.begin).to eq ActiveSupport::TimeZone["Asia/Tokyo"].local(2026, 4, 10, 3, 0, 0)
        expect(range.end).to eq ActiveSupport::TimeZone["Asia/Tokyo"].local(2026, 4, 11, 3, 0, 0)
      end
    end

    context "when JST time is 10:00 (well after boundary)" do
      it "returns range from current day 3:00 to next day 3:00" do
        now = ActiveSupport::TimeZone["Asia/Tokyo"].local(2026, 4, 10, 10, 0, 0) # JST 10:00

        range = described_class.current_day_range(now)

        expect(range.begin).to eq ActiveSupport::TimeZone["Asia/Tokyo"].local(2026, 4, 10, 3, 0, 0)
        expect(range.end).to eq ActiveSupport::TimeZone["Asia/Tokyo"].local(2026, 4, 11, 3, 0, 0)
      end
    end

    context "end is exclusive" do
      it "does not include a log at exactly the end boundary (next day 3:00:00)" do
        now = ActiveSupport::TimeZone["Asia/Tokyo"].local(2026, 4, 10, 10, 0, 0)
        range = described_class.current_day_range(now)

        expect(range).not_to cover(ActiveSupport::TimeZone["Asia/Tokyo"].local(2026, 4, 11, 3, 0, 0))
      end

      it "includes a log 1 second before the end boundary" do
        now = ActiveSupport::TimeZone["Asia/Tokyo"].local(2026, 4, 10, 10, 0, 0)
        range = described_class.current_day_range(now)

        expect(range).to cover(ActiveSupport::TimeZone["Asia/Tokyo"].local(2026, 4, 11, 2, 59, 59))
      end
    end
  end
end
