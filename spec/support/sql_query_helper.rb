module SqlQueryHelper
  def capture_executed_sql
    queries = []
    callback = ->(*args) { queries << args.last[:sql] }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      yield
    end
    queries
  end
end
