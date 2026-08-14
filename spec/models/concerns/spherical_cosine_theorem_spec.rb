require 'rails_helper'

RSpec.describe SphericalCosineTheorem, type: :model do
  before do
    stub_const("SphericalCosineTheoremTestClass", Class.new { include SphericalCosineTheorem })
  end

  describe '#distance' do
    subject(:instance) { SphericalCosineTheoremTestClass.new }

    it 'returns 0 when the two points are identical' do
      shrine = build(:shrine, latitude: 35.4, longitude: 135.1)

      expect(instance.distance(shrine, 35.4, 135.1)).to be_within(1e-9).of(0)
    end

    it 'does not raise even when floating point rounding pushes the cosine argument out of range' do
      # 1つ目のテストと入力（座標）は同一だが、検証観点が異なる独立したテスト:
      # cos(lat1)*cos(lat2)*cos(lng2-lng1) + sin(lat1)*sin(lat2) は同一点では
      # 理論上ちょうど1.0だが、浮動小数点の丸め誤差で1.0をわずかに超えることがある。
      # clamp(-1.0, 1.0) が無いと Math.acos が Math::DomainError を発生させるため、
      # その回帰を防ぐことを目的としたテスト。
      shrine = build(:shrine, latitude: 35.681236, longitude: 139.767125)

      expect { instance.distance(shrine, 35.681236, 139.767125) }.not_to raise_error
    end

    it 'returns approximately 111.19km for a 1 degree difference in latitude' do
      shrine = build(:shrine, latitude: 0, longitude: 0)

      expect(instance.distance(shrine, 1, 0)).to be_within(0.1).of(111.19)
    end

    it 'returns approximately 111.19km for a 1 degree difference in longitude at the equator' do
      shrine = build(:shrine, latitude: 0, longitude: 0)

      expect(instance.distance(shrine, 0, 1)).to be_within(0.1).of(111.19)
    end

    it 'returns a smaller distance for a 1 degree difference in longitude than in latitude away from the equator' do
      shrine = build(:shrine, latitude: 80, longitude: 0)

      lat_diff_distance = instance.distance(shrine, 81, 0)
      lng_diff_distance = instance.distance(shrine, 80, 1)

      expect(lng_diff_distance).to be < lat_diff_distance
    end
  end
end
