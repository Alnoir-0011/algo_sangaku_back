require 'rails_helper'

RSpec.describe FixedInput, type: :model do
  describe 'validation' do
    it 'is valid with all attribute' do
      input = build(:fixed_input)
      expect(input).to be_valid
      expect(input.errors).to be_empty
    end

    it 'is invalid without content' do
      input = build(:fixed_input, content: '')
      expect(input).to be_invalid
      expect(input.errors[:content]).to eq [ 'を入力してください' ]
    end

    it 'is invalid with same content for same sangaku' do
      sangaku = create(:sangaku)
      input = create(:fixed_input, sangaku: sangaku)
      another_input = build(:fixed_input, content: input.content, sangaku: sangaku)
      expect(another_input).to be_invalid
      expect(another_input.errors[:content]).to eq [ 'はすでに存在します' ]
    end
  end

  describe 'callbacks' do
    it 'enqueues GenerateExpectedOutputJob after create' do
      ActiveJob::Base.queue_adapter = :test
      expect { create(:fixed_input) }.to have_enqueued_job(GenerateExpectedOutputJob)
    end

    it 'enqueues GenerateExpectedOutputJob after update' do
      input = create(:fixed_input)
      ActiveJob::Base.queue_adapter = :test
      expect { input.update(content: 'updated_content') }.to have_enqueued_job(GenerateExpectedOutputJob)
    end
  end
end
