module SphericalCosineTheorem
  extend ActiveSupport::Concern

  def distance(shrine, lat, lng)
    r = Math::PI / 180
    lat1 = shrine.latitude.to_f * r
    lng1 = shrine.longitude.to_f * r
    lat2 = lat.to_f * r
    lng2 = lng.to_f * r

    6371 *
           Math.acos(
             Math.cos(lat1) * Math.cos(lat2) * Math.cos(lng2 - lng1) +
             Math.sin(lat1) * Math.sin(lat2)
           )
  end
end
