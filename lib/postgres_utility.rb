# frozen_string_literal: true

require_relative "postgres_utility/version"

# rubocop:disable Layout/LineLength, Metrics/ModuleLength

require 'English'
require 'active_record'

module PostgresUtility
  extend self

  DEFAULT_BATCH_SIZE = 1000

  # Shorthand for rails environment based connection
  def rails_connection(cls = nil)
    cls ||= ActiveRecord::Base
    cls.connection
  end

  # Copied from db:migrate:status
  def pending_migration?
    db_list = rails_connection
              .select_values("SELECT version FROM
                  #{ActiveRecord::Migrator.schema_migrations_table_name}")
    db_list.map! { |version| '%.3d' % version }
    ActiveRecord::Migrator.migrations_paths.each do |path|
      Dir.foreach(Rails.root.join(path)) do |file|
        # match "20091231235959_some_name.rb" and "001_some_name.rb" pattern
        if match_data = /^(\d{3,})_(.+)\.rb$/.match(file)
          is_up = db_list.delete(match_data[1])
          return true unless is_up
        end
      end
    end
    false
  end

  def db_name
    rails_connection.current_database
  end

  def db_connection_config
    config = ActiveRecord::Base.connection_config
    config = rails_connection.config if config[:adapter].match(/makara/i)
    config
  end

  def db_adapter_name
    db_connection_config[:adapter]
  end

  def postgresql?
    !!db_adapter_name.match(/postgresql/i)
  end

  def migration_version
    ActiveRecord::Migrator.current_version
  end

  def db_version
    rails_connection.select_value('select version();')
  end

  def db_size
    rails_connection.select_value("select pg_database_size('#{db_name}');").to_i
  end

  # Returns true if created, false if already exists, raise if failed.
  def create_database
    # Stolen from activerecord-3.2.3\lib\active_record\railties\databases.rake
    raise 'Not implemented' unless postgresql?

    begin
      rails_connection.create_database(db_name)
      true
    rescue PG::Error, ActiveRecord::StatementInvalid => e
      return false if e.to_s.include? "database \"#{db_name}\" already exists"

      raise e
    end
  end

  def drop_database
    rails_connection.drop_database(db_name)
  end

  def recreate_database
    raise unless Rails.env.development? || Rails.env.test?
    return if create_database # Try create first

    Rails.logger.debug("Recreate the DB:#{db_name}\n")

    if postgresql?
      drop_database
      create_database
    else # My sql
      c = rails_connection
      c.recreate_database(db_name)
      c.execute("USE `#{db_name}`;")
    end
    nil # void function
  end

  # rubocop:disable Metrics/MethodLength

  def copy_table_query(src_table_class, dest_table_class, opts = {})
    if !src_table_class.respond_to?(:table_name)
      raise StandardError,
            "#{src_table_class} must be an ActiveRecord::Base Class"
    end
    if !dest_table_class.respond_to?(:table_name)
      raise StandardError,
            "#{dest_table_class} must be an ActiveRecord::Base Class"
    end

    conn = rails_connection(opts[:cls])
    src_table  = src_table_class.table_name
    dest_table = dest_table_class.table_name
    raise StandardError, "#{src_table} Table missing!" if !conn.tables.include?(src_table)
    raise StandardError, "#{dest_table} Table missing!" if !conn.tables.include?(dest_table)

    query = ''
    # truncate dest_table and insert into dest_table from src_table,
    # then vacuum dest_table
    query += "TRUNCATE TABLE #{dest_table};\n"
    id = dest_table_class.primary_key
    schema = 'public'
    schema = dest_table.split('.').first if dest_table.include?('.')
    tbl_without_schema_name = dest_table.split('.').last
    seq_name = "#{tbl_without_schema_name}_#{id}_seq"
    # check if sequence exists
    if dest_table_class.connection.
       select_value("SELECT sequence_name FROM information_schema.sequences WHERE sequence_name = '#{seq_name}' AND sequence_schema = '#{schema}'").present?
      query += "ALTER SEQUENCE #{schema}.#{seq_name} RESTART;\n"
      query += "UPDATE #{dest_table} SET #{id} = DEFAULT;\n"
    end
    query += "INSERT INTO #{dest_table} SELECT * FROM #{src_table};"

    if !opts[:do_not_truncate_src]
      # truncate src_table and get it primed for next time
      query += "TRUNCATE TABLE #{src_table};\n"
      id = src_table_class.primary_key
      schema = 'public'
      schema = src_table.split('.').first if src_table.include?('.')
      tbl_without_schema_name = src_table.split('.').last
      seq_name = "#{tbl_without_schema_name}_#{id}_seq"
      # check if sequence exists
      if dest_table_class.connection.
         select_value("SELECT sequence_name FROM information_schema.sequences WHERE sequence_name = '#{seq_name}' AND sequence_schema = '#{schema}'").present?
        query += "ALTER SEQUENCE #{schema}.#{seq_name} RESTART;\n"
        query += "UPDATE #{src_table} SET #{id} = DEFAULT;\n"
      end
    end
    query
  end

  # rubocop:enable Metrics/MethodLength

  def vacuum_analyze(tbl, opts = {})
    query = ''
    if tbl.respond_to?(:table_name)
      # Take care of the case where table is an ActiveRecord::Base class
      tbl = tbl.table_name
    end
    query += "VACUUM ANALYSE #{tbl};"
    rails_connection(opts[:cls]).execute(query)
  end

  def multi_dump_to_csv(tables, opts = {})
    conn = rails_connection(opts[:cls])
    pg_conn = conn.raw_connection
    tables.each do |table|
      tbl = table[:tbl]
      csv_path = table[:csv_path]
      # Take care of the case where table is an ActiveRecord::Base class
      tbl = tbl.table_name if tbl.respond_to?(:table_name)
      if opts[:column_names].present? && opts[:column_names].is_a?(Array)
        cols = opts[:column_names].join(',')
        qcopy = "COPY #{tbl}(#{cols}) TO STDOUT WITH DELIMITER ',' CSV HEADER"
      else
        qcopy = "COPY #{tbl} TO STDOUT WITH DELIMITER ',' CSV HEADER"
      end

      csv = []
      pg_conn.copy_data(qcopy.to_s) do
        while row = pg_conn.get_copy_data
          csv.push(row)
        end
      end
      File.open(csv_path, 'w') do |f|
        csv.each_slice(100000).each do |chunk|
          f.write(chunk.join('').force_encoding('UTF-8'))
        end
      end
    end
  end

  def multi_dump_query_result_to_csv(query, csv_path, opts = {})
    conn = rails_connection(opts[:cls])
    pg_conn = conn.raw_connection
    qcopy = "COPY (#{query}) TO STDOUT WITH DELIMITER ',' CSV HEADER"

    csv = []
    pg_conn.copy_data(qcopy.to_s) do
      while row = pg_conn.get_copy_data
        csv.push(row)
      end
    end
    File.open(csv_path, 'w') do |f|
      f.write(csv.join('').force_encoding('UTF-8'))
    end
  end

  # rubocop:disable Metrics/MethodLength

  def multi_truncate_reset_populate_from_csv(tables, opts = {})
    # Cant execute PGConnection#copy_data within an
    # Activerecord transaction block
    # so this whole method is not in a single transaction block unfortunately

    conn = rails_connection(opts[:cls])
    pg_conn = conn.raw_connection

    # First we loop thru all tables and create a copy of each
    # Load the csv into these copy tables and these will be used
    # to populate the original tables in a transaction
    tables.each do |table|
      tblcls = table[:tblcls]
      csv_path = table[:csv_path]
      # Take care of the case where table is not an ActiveRecord::Base class
      raise StandardError, "#{tblcls} must be an ActiveRecord::Base Class" if !tblcls.respond_to?(:table_name)

      tbl = tblcls.table_name
      tbl_copy = generate_temptable_name(tbl)
      # create a regular table and not temp table here
      # since we dont want the table to be auto dropped at the end of this
      # loop (transaction), temp tables are auto dropped at the commit of
      # transaction, we will manually need to drop this table
      pg_conn.exec("CREATE TABLE #{tbl_copy} (LIKE #{tbl} INCLUDING DEFAULTS)")
      #   pg_conn.exec("DROP TABLE IF EXISTS #{tbl_copy}")
      if opts[:column_names].present? && opts[:column_names].is_a?(Array)
        cols = opts[:column_names].join(',')
        qcopy = "COPY #{tbl_copy}(#{cols}) FROM STDIN WITH DELIMITER ',' CSV HEADER"
      else
        qcopy = "COPY #{tbl_copy} FROM STDIN WITH DELIMITER ',' CSV HEADER"
      end
      pg_conn.copy_data(qcopy.to_s) do
        File.open(csv_path, 'r').each do |line|
          pg_conn.put_copy_data(line)
        end
      end
      table[:tbl_copy] = tbl_copy
    end

    # transaction block to truncate table and reset sequence if needed
    # Populate using the copy table just created
    # drop the copy table
    query = "BEGIN;\n"
    tables.each do |table|
      tblcls = table[:tblcls]
      tbl_copy = table[:tbl_copy]
      raise StandardError, "#{tbl_copy} Table missing!" if !conn.tables.include?(tbl_copy)

      tbl = tblcls.table_name
      if !opts[:do_not_truncate]
        id = tblcls.primary_key
        schema = 'public'
        schema = tbl.split('.').first if tbl.include?('.')
        tbl_without_schema_name = tbl.split('.').last
        seq_name = "#{tbl_without_schema_name}_#{id}_seq"
        query += "TRUNCATE TABLE #{tbl};\n"
        # check if sequence exists
        if tblcls.connection.
           select_value("SELECT sequence_name FROM information_schema.sequences WHERE sequence_name = '#{seq_name}' AND sequence_schema = '#{schema}'").present?
          query += "ALTER SEQUENCE #{schema}.#{seq_name} RESTART;\n"
          query += "UPDATE #{tbl} SET #{id} = DEFAULT;\n"
        end
      end
      query += "INSERT INTO #{tbl} SELECT * FROM #{tbl_copy};"
      query += "DROP TABLE #{tbl_copy};"
    end
    query += 'COMMIT;'
    pg_conn.exec(query)

    # ensuring the sequence is reset to be > max id (postgres has a bug where sequence can sometimes can become out of sync specially when doing bulk imports)
    # refer to: https://stackoverflow.com/questions/11068800/rails-auto-assigning-id-that-already-exists
    tables.each do |table|
      tblcls = table[:tblcls]
      tblcls.connection.reset_pk_sequence!(tblcls.table_name)
    end

    tables.each { |t| vacuum_analyze(t[:tblcls], opts) } if opts[:vacuum]
  end

  # rubocop:enable Metrics/MethodLength

  def fix_sequence_value(table, key = nil, conn = nil)
    if table.respond_to?(:table_name) # Take care of the case where table is an ActiveRecord::Base class
      conn ||= table.connection
      key ||= table.primary_key
      table = table.table_name
    else
      conn ||= rails_connection
      key ||= 'id'
    end
    seqname = "#{table}_#{key}_seq"
    unless conn.select_value("SELECT sequence_name FROM information_schema.sequences WHERE sequence_name = '#{seqname}'")
      return
    end

    maxid = conn.select_value("SELECT MAX(#{key}) from \"#{table}\"").to_i
    conn.execute("SELECT setval('#{seqname}', #{maxid});") if maxid >= 1
  rescue StandardError
    Rails.logger.debug("WARNING: #{$ERROR_INFO}\n")
  end

  def fix_sequence_value_with_cap(table, cutoff_id = nil, key = nil, conn = nil)
    if table.respond_to?(:table_name) # Take care of the case where table is an ActiveRecord::Base class
      conn ||= table.connection
      key ||= table.primary_key
      table = table.table_name
    else
      conn ||= rails_connection
      key ||= 'id'
    end
    seqname = "#{table}_#{key}_seq"
    unless conn.select_value("SELECT sequence_name FROM information_schema.sequences WHERE sequence_name = '#{seqname}'")
      return
    end

    sql = "SELECT MAX(#{key}) from \"#{table}\""
    sql << " WHERE #{key} < #{cutoff_id}" if cutoff_id
    maxid = conn.select_value(sql).to_i
    conn.execute("SELECT setval('#{seqname}', #{maxid});") if maxid >= 1
  rescue StandardError
    Rails.logger.debug("WARNING: #{$ERROR_INFO}\n")
  end

  def setup_primary_key(table, key)
    rails_connection.execute "ALTER TABLE \"#{table}\" ADD PRIMARY KEY (\"#{key}\");"
  end

  def delete_primary_key(table)
    rails_connection.execute "ALTER TABLE \"#{table}\" DROP CONSTRAINT \"#{table}_pkey\";"
  end

  def pg_dump_custom(filename, dbname = nil)
    dbname ||= db_name
    system_with_print(
      "pg_dump #{host_param} -U #{username} -w --file=#{filename} -T data_parts -T data_part_applications --format=custom #{dbname}", "Dump #{dbname} to #{filename}"
    )
  end

  def pg_save_data(filename, table_name, dbname = nil)
    dbname ||= db_name
    system_with_print(
      "pg_dump #{host_param} -U #{username} -w -t #{table_name} --data-only --dbname=#{dbname} -f #{filename}", "Save #{dbname} to #{filename}"
    )
  end

  def pg_restore_data_and_schema(filename, dbname = nil)
    dbname ||= db_name
    system_with_print("pg_restore #{host_param} -U #{username} -w -d #{dbname} -j 4 #{filename}",
                      "Restore #{dbname} from #{filename}")
  end

  def pg_load(filename, dbname = nil)
    dbname ||= db_name
    bz2 = false
    if filename.to_s.ends_with?('.sql.bz2')
      filename = filename.to_s[0..-9]
      bz2 = true
    end
    if bz2
      system_with_print(
        "bzip2 -cd #{filename}.sql.bz2 | PGPASSWORD=\'#{password}\' psql #{host_param} -q -U #{username} -w #{dbname}", "Loading #{dbname} from #{filename}"
      )
    else
      system_with_print("PGPASSWORD=\'#{password}\' psql #{host_param} -q -U #{username} -w #{dbname} < #{filename}",
                        "Loading #{dbname} from #{filename}")
    end
  end

  # Much faster when it works, but does not work for foreign key enable tables
  def truncate_table(conn, tbl)
    stmt = "TRUNCATE TABLE #{tbl}"
    conn.execute(stmt)
  end

  def clear_table(conn, tbl_name, cond = nil)
    stmts = if cond
              ["DELETE FROM #{tbl_name} WHERE #{cond}"]
            else
              ["DELETE FROM #{tbl_name}"]
            end
    stmts.each { |stmt| conn.execute(stmt) }
  end

  def clear_table_reset_sequence(tblcls)
    return unless tblcls.respond_to?(:table_name)

    tbl = tblcls.table_name
    stmts = ["TRUNCATE TABLE #{tbl}"]
    id = tblcls.primary_key
    schema = 'public'
    schema = tbl.split('.').first if tbl.include?('.')
    tbl_without_schema_name = tbl.split('.').last
    seq_name = "#{tbl_without_schema_name}_#{id}_seq"
    # check if sequence exists
    if tblcls.connection.
       select_value("SELECT sequence_name FROM information_schema.sequences
        WHERE sequence_name = '#{seq_name}' AND sequence_schema = '#{schema}'").present?
      stmts += [
        "ALTER SEQUENCE #{schema}.#{seq_name} RESTART",
        "UPDATE #{tbl} SET #{id} = DEFAULT"
      ]
    end
    tblcls.transaction do
      stmts.each { |stmt| tblcls.connection.execute(stmt) }
    end
    nil
  end

  def get_random_record(klass, opt = nil)
    opt ||= {}
    c = klass.connection
    select_clause = opt[:dense] ? "MAX(\"#{klass.primary_key}\")" : 'COUNT(*)'
    cnt = c.select_value("SELECT #{select_clause} FROM \"#{klass.table_name}\"").to_i
    klass.offset(rand(cnt)).first
  end

  def system_with_print(cmd, toprint = nil)
    toprint ||= cmd
    Rails.logger.debug("EXEC:#{toprint} ... ")
    start = Time.zone.now
    ret = system(cmd)
    Rails.logger.debug((ret ? 'success' : 'failed') + " (#{Time.zone.now - start} seconds)\n")
    ret
  end

  # Accepts an array of hashes to insert in bulk into the table
  def batch_insert(model:, values:, batch_size: DEFAULT_BATCH_SIZE, include_pkey: false)
    # Nothing to do if there are no values
    return if values.blank?

    columns = model.column_names.map(&:to_sym)
    columns.delete(model.primary_key.to_sym) unless include_pkey
    columns_string = columns.map(&:to_s).join(', ').to_s
    table = model.table_name

    value_batches = Array(values.in_groups_of(batch_size).map do |batch|
      batch.compact.map { |item| "(#{columns.map { |col| process_value(item[col]) }.join(', ')})" }.join(', ')
    end)

    model.transaction do
      value_batches.each do |vb|
        rails_connection.execute("INSERT INTO #{table}(#{columns_string}) VALUES #{vb}")
      end
    end
  end

  private

  def host_param
    host = db_connection_config[:host]
    return "-h #{host}" if host.present? && host != 'localhost' && host != '127.0.0.1'

    ''
  end

  def username
    db_connection_config[:username]
  end

  def password
    db_connection_config[:password]
  end

  def generate_temptable_name(tbl_name)
    raise StandardError, 'Cant create temp table for missing original table' if tbl_name.blank?

    "temp_#{tbl_name.split('.').last}_#{(Time.now.to_f * 1000).round}_#{'%03d' % rand(1000)}"
  end

  # Convert values to database friendly format
  def process_value(value)
    if value.is_a?(Time)
      "TIMESTAMP '#{value.strftime('%Y-%m-%d %H:%M:%S')}'"
    else
      ActiveRecord::Base.sanitize(value)
    end
  end
end

# rubocop:enable Layout/LineLength, Metrics/ModuleLength
