# frozen_string_literal: true

require "postgres_utility"

require "fixtures/test_model"
require "fixtures/destination_test_model"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:suite) do
    # we create a test database if it does not exist
    # I do not use database users or password for the tests, using ident authentication instead

    ActiveRecord::Base.establish_connection(
      adapter: "postgresql",
      host: "localhost",
      username: "postgres",
      password: "postgres",
      port: 5432,
      database: "pg_utility_db"
    )
    ActiveRecord::Base.connection.execute %{
        SET client_min_messages TO warning;
        DROP TABLE IF EXISTS test_models;
        DROP TABLE IF EXISTS destination_test_models;
        CREATE TABLE test_models (id serial PRIMARY KEY, data text);
        CREATE TABLE destination_test_models (id serial PRIMARY KEY, data text);
      }
  rescue StandardError => e
    puts "Exception: #{e}"
    ActiveRecord::Base.establish_connection(
      adapter: "postgresql",
      host: "localhost",
      username: "postgres",
      password: "postgres",
      port: 5432,
      database: "postgres"
    )
    ActiveRecord::Base.connection.execute "CREATE DATABASE pg_utility_db"
    retry
  end
end
