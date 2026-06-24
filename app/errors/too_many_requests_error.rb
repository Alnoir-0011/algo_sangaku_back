class TooManyRequestsError < StandardError
  def initialize(reset_at:)
    @reset_at = reset_at
    super("本日の利用回数上限に達しました")
  end

  def reset_at
    @reset_at
  end
end
