# PostgresUtility

This awesome gem provides an api to execute multiple useful operations on ActiveRecord table having postgres as database.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'postgres_utility'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install postgres_utility

## Usage

Following are use cases

### To get the current db name
```ruby
PostgresUtility.db_name
```

### To get a db connection object
```ruby
PostgresUtility.rails_connection
```

### Boolean method to check if a migration is pending
```ruby
PostgresUtility.pending_migration?
```

### To get the db connection config object
```ruby
PostgresUtility.db_connection_config
```

### To get the db_adapter_name
```ruby
PostgresUtility.db_adapter_name
```

### To find if current adapter is postgresql
```ruby
PostgresUtility.postgresql?
```

### To find the current migration version
```ruby
PostgresUtility.migration_version
```

### To find the current db_version
```ruby
PostgresUtility.db_version
```

### To find the database size
```ruby
PostgresUtility.db_size
```

### To create database
```ruby
PostgresUtility.create_database
```

### To drop database
```ruby
PostgresUtility.drop_database
```

### To recreate database
```ruby
PostgresUtility.recreate_database
```

### To form query that copies records from source to destination table
```ruby
PostgresUtility.copy_table_query(TestModel, DestinationTestModel)
```

### To perform vacuum and analyze on a table
```ruby
PostgresUtility.vacuum_analyze(TestModel)
```

### To dump multiple tables to a csv
```ruby
PostgresUtility.multi_dump_to_csv([{ tbl: TestModel, csv_path: csv_path }])
```

### To dump query results to a csv
```ruby
PostgresUtility.multi_dump_query_result_to_csv("select * from test_models", csv_path)
```

### To fix table sequence
```ruby
PostgresUtility.fix_sequence_value(TestModel)
```

### To fix table sequence with a cap value
```ruby
PostgresUtility.fix_sequence_value_with_cap(TestModel)
```

### To a random record from table
```ruby
PostgresUtility.get_random_record(TestModel)
```

### To execute a command with system with print
```ruby
PostgresUtility.system_with_print("ls")
```

### To batch_insert of records
```ruby
PostgresUtility.batch_insert(model: TestModel, values: [{ id: 10, data: "new_record_1" },
                                                              { id: 11, data: "new_record_2" }])
```

### To save data of a given table to a given file
```ruby
PostgresUtility.pg_save_data(file_path, 'test_models')
```

### truncates a given table
```ruby
PostgresUtility.truncate_table(PostgresUtility.rails_connection, "test_models")
```

### truncates table and populates from a csv
```ruby
PostgresUtility.multi_truncate_reset_populate_from_csv([{ tblcls: TestModel, csv_path: csv_path }])
```

### To fix sequence value of a table
```ruby
PostgresUtility.fix_sequence_value(TestModel)
```

### To fix sequence value of a table with cap
```ruby
PostgresUtility.fix_sequence_value_with_cap(TestModel)
```

### To set up primary key of a table
```ruby
PostgresUtility.setup_primary_key(TestModel, 'user_id')
```

### To delete primary key of a table
```ruby
PostgresUtility.delete_primary_key(TestModel)
```

### To dump db to a file
```ruby
PostgresUtility.pg_dump_custom('Test_Model.sql')
```

### To restore data and schema from a file
```ruby
PostgresUtility.pg_restore_data_and_schema('db_Test_Model.sql')
```

### To load db
```ruby
PostgresUtility.pg_load('db_Test_Model.sql')
```

### To truncate a table
```ruby
PostgresUtility.truncate_table(conn, 'test_models')
```

### To delete records from a table
```ruby
PostgresUtility.clear_table(conn, 'test_models')
```

### To truncate table and reset sequence
```ruby
PostgresUtility.clear_table_reset_sequence(TestModel)
```



## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/postgres_utility. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/postgres_utility/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the PostgresUtility project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/postgres_utility/blob/master/CODE_OF_CONDUCT.md).
