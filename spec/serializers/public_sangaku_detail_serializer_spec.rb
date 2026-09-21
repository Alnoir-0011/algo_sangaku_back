require 'rails_helper'

# 正解順（correct_position）を見せてよい相手かどうかの判断は、このシリアライザに閉じている。
# 呼び出し側が current_user を渡し忘れた・誤った型を渡した場合の振る舞いを固定する（issue #92）
RSpec.describe PublicSangakuDetailSerializer do
  let(:sangaku) { create(:sangaku, :reorder, user: create(:user)) }

  def code_blocks(params)
    described_class.new(sangaku, params:).serializable_hash[:data][:attributes][:code_blocks]
  end

  it "hides correct_position when params are not given at all" do
    blocks = described_class.new(sangaku).serializable_hash[:data][:attributes][:code_blocks]

    expect(blocks).to be_present
    expect(blocks.map(&:keys).uniq).to eq [ %i[id content] ]
  end

  it "hides correct_position when current_user is nil" do
    blocks = code_blocks({ current_user: nil })

    expect(blocks).to be_present
    expect(blocks.map(&:keys).uniq).to eq [ %i[id content] ]
  end

  it "raises when current_user is not a User" do
    expect { code_blocks({ current_user: sangaku }) }.to raise_error(ArgumentError)
  end

  it "reveals correct_position to the author" do
    blocks = code_blocks({ current_user: sangaku.user })

    expect(blocks.map { |block| block[:correct_position] }).to eq [ 1, 2 ]
  end

  it "hides correct_position from another user who has not answered it" do
    blocks = code_blocks({ current_user: create(:user) })

    expect(blocks.map(&:keys).uniq).to eq [ %i[id content] ]
  end
end
