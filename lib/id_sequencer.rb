module IdSequencer
  def self.next_id(table_name)
    # CURRENT IMPLEMENTATION: Postgres Sequence
    # Scalability: Easy to swap later for a Redis-backed Range Allocator across distributed DBs
    ActiveRecord::Base.connection.select_value(
      "SELECT nextval('#{ActiveRecord::Base.connection.default_sequence_name(table_name, 'id')}')"
    ).to_i
  end
end
