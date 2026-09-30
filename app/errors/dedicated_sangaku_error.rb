class DedicatedSangakuError < StandardError
  def initialize(msg = "この算額は奉納済みのため操作できません")
    super
  end
end
