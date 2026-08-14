require 'rails_helper'

RSpec.describe Shrine, type: :model do
  describe "validation" do
    it "is valid with all attributes" do
      shrine = build(:shrine)
      expect(shrine).to be_valid
      expect(shrine.errors).to be_empty
    end

    it "is invalid without name" do
      shrine = build(:shrine, name: "")
      expect(shrine).to be_invalid
      expect(shrine.errors[:name]).to eq [ 'を入力してください' ]
    end

    it "is invalid without latitude" do
      shrine = build(:shrine, latitude: "")
      expect(shrine).to be_invalid
      expect(shrine.errors[:latitude]).to eq [ 'は数値で入力してください' ]
    end

    it "is invalid without longitude" do
      shrine = build(:shrine, longitude: "")
      expect(shrine).to be_invalid
      expect(shrine.errors[:longitude]).to eq [ 'は数値で入力してください' ]
    end


    it "is invalid without address" do
      shrine = build(:shrine, address: "")
      expect(shrine).to be_invalid
      expect(shrine.errors[:address]).to eq [ 'を入力してください' ]
    end

    it "is invalid without place_id" do
      shrine = build(:shrine, place_id: "")
      expect(shrine).to be_invalid
      expect(shrine.errors[:place_id]).to eq [ 'を入力してください' ]
    end

    it "is invalid with non numeric latitude" do
      shrine = build(:shrine, latitude: "text_input")
      expect(shrine).to be_invalid
      expect(shrine.errors[:latitude]).to eq [ 'は数値で入力してください' ]
    end

    it "is invalid with non numeric longitude" do
      shrine = build(:shrine, longitude: "text_input")
      expect(shrine).to be_invalid
      expect(shrine.errors[:longitude]).to eq [ 'は数値で入力してください' ]
    end


    it "is invalid with same place_id" do
      shrine = create(:shrine)
      another_shirne = build(:shrine, place_id: shrine.place_id)
      expect(another_shirne).to be_invalid
      expect(another_shirne.errors[:place_id]).to eq [ 'はすでに存在します' ]
    end

    it "is valid with another place_id" do
      create(:shrine)
      another_shirne = build(:shrine, place_id: "another_place_id")
      expect(another_shirne).to be_valid
      expect(another_shirne.errors).to be_empty
    end
  end

  describe '.search_by_bounds' do
    it 'returns false when text search returns nil' do
      allow(Shrine).to receive(:text_search_by_location_restriction).and_return(nil)

      expect(Shrine.search_by_bounds(1, 2, 3, 4)).to eq false
    end

    it 'returns false when persist_places raises ActiveRecord::RecordInvalid' do
      allow(Shrine).to receive(:text_search_by_location_restriction).and_return([])
      allow(Shrine).to receive(:persist_places).and_raise(ActiveRecord::RecordInvalid.new(Shrine.new))

      expect(Shrine.search_by_bounds(1, 2, 3, 4)).to eq false
    end

    it 'returns false when persist_places raises ActiveRecord::RecordNotUnique' do
      allow(Shrine).to receive(:text_search_by_location_restriction).and_return([])
      allow(Shrine).to receive(:persist_places).and_raise(ActiveRecord::RecordNotUnique.new("duplicate key"))

      expect(Shrine.search_by_bounds(1, 2, 3, 4)).to eq false
    end

    it 'raises when an unexpected error occurs' do
      allow(Shrine).to receive(:text_search_by_location_restriction).and_raise(PlaceApiRequestFailedError.new("500"))

      expect { Shrine.search_by_bounds(1, 2, 3, 4) }.to raise_error(PlaceApiRequestFailedError)
    end
  end

  describe '.search_by_location' do
    it 'returns false when text search returns nil' do
      allow(Shrine).to receive(:text_search_by_location_bias).and_return(nil)

      expect(Shrine.search_by_location(1, 2)).to eq false
    end

    it 'returns false when persist_places raises ActiveRecord::RecordInvalid' do
      allow(Shrine).to receive(:text_search_by_location_bias).and_return([])
      allow(Shrine).to receive(:persist_places).and_raise(ActiveRecord::RecordInvalid.new(Shrine.new))

      expect(Shrine.search_by_location(1, 2)).to eq false
    end

    it 'returns false when persist_places raises ActiveRecord::RecordNotUnique' do
      allow(Shrine).to receive(:text_search_by_location_bias).and_return([])
      allow(Shrine).to receive(:persist_places).and_raise(ActiveRecord::RecordNotUnique.new("duplicate key"))

      expect(Shrine.search_by_location(1, 2)).to eq false
    end

    it 'raises when an unexpected error occurs' do
      allow(Shrine).to receive(:text_search_by_location_bias).and_raise(PlaceApiRequestFailedError.new("500"))

      expect { Shrine.search_by_location(1, 2) }.to raise_error(PlaceApiRequestFailedError)
    end
  end

  # eleminate_non_shrine はクラス内で private 宣言されているが、Ruby の private は
  # def self.foo 形式のクラスメソッド（特異メソッド）には効かないため実際は public で呼び出せる
  # （可視性を意図通りにする対応は issue #312 で追跡）。
  # 除外条件の組み合わせ（キーワード×「社」と「寺」の同時一致）が複雑で、
  # .search_by_bounds/.search_by_location 経由の間接テストだけでは全分岐を網羅しづらいため、直接呼び出して検証する
  describe '.eleminate_non_shrine' do
    def place_with_name(name)
      { "displayName" => { "text" => name } }
    end

    it 'returns an empty array when given no places' do
      expect(Shrine.send(:eleminate_non_shrine, [])).to eq []
    end

    it 'keeps a place whose name has no eliminate keywords' do
      places = [ place_with_name("〇〇神社") ]

      expect(Shrine.send(:eleminate_non_shrine, places)).to eq places
    end

    it 'excludes a place whose name includes 寺' do
      places = [ place_with_name("〇〇寺") ]

      expect(Shrine.send(:eleminate_non_shrine, places)).to eq []
    end

    it 'excludes a place whose name includes 手水舎' do
      places = [ place_with_name("〇〇神社 手水舎") ]

      expect(Shrine.send(:eleminate_non_shrine, places)).to eq []
    end

    it 'excludes a place whose name includes 社務所' do
      places = [ place_with_name("〇〇神社務所") ]

      expect(Shrine.send(:eleminate_non_shrine, places)).to eq []
    end

    it 'excludes a place whose name includes 授与所' do
      places = [ place_with_name("〇〇神社授与所") ]

      expect(Shrine.send(:eleminate_non_shrine, places)).to eq []
    end

    it 'excludes a place whose name includes 鳥居' do
      places = [ place_with_name("〇〇神社鳥居") ]

      expect(Shrine.send(:eleminate_non_shrine, places)).to eq []
    end

    it 'keeps a place whose name includes both 社 and 寺 despite matching the 寺 keyword' do
      places = [ place_with_name("〇〇神社(旧〇〇寺)") ]

      expect(Shrine.send(:eleminate_non_shrine, places)).to eq places
    end

    it 'filters a mixed list down to only the eligible places' do
      keep = place_with_name("〇〇神社")
      drop = place_with_name("〇〇寺")

      expect(Shrine.send(:eleminate_non_shrine, [ keep, drop ])).to eq [ keep ]
    end
  end
end
