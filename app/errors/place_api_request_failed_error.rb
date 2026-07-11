class PlaceApiRequestFailedError < StandardError
  attr_reader :status_code

  def initialize(status_code, message = "Google Places API request failed")
    @status_code = status_code
    super("#{message} (status: #{status_code})")
  end
end
