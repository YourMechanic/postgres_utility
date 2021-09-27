# frozen_string_literal: true

RSpec.describe PostgresUtility do
  # before(:each) do
  #   ActiveRecord::Base.connection.execute %{
  #     TRUNCATE TABLE test_models;
  #     SELECT setval('test_models_id_seq', 1, false);
  #   }
  #   TestModel.create(data: 'test data 1')
  # end

  it "has a version number" do
    expect(PostgresUtility::VERSION).not_to be nil
  end

  describe ".db_name" do
    it "returns the db name" do
      expect(PostgresUtility.db_name).to eq("pg_utility_db")
    end
  end

  describe ".rails_connection" do
    it "returns the db connection" do
      expect(PostgresUtility.rails_connection).to be
    end
  end

  describe ".db_adapter_name" do
    it "returns the db adapter name" do
      expect(PostgresUtility.db_adapter_name).to eq("postgresql")
    end
  end

  describe ".postgresql?" do
    it "returns true if adapter is postgresql" do
      expect(PostgresUtility.postgresql?).to be_truthy
    end
  end

  describe ".db_version" do
    it "gives the database version" do
      expect(PostgresUtility.db_version).to be
    end
  end

  describe ".db_size" do
    it "gives the database size" do
      expect(PostgresUtility.db_size).to be
    end
  end

  describe ".create_database" do
    it "returns false if db already exists" do
      expect(PostgresUtility.create_database).to eq(false)
    end
  end

  describe ".recreate_database" do
    xit "false if db already exists" do
      expect(PostgresUtility.recreate_database).to eq(false)
    end
  end

  describe ".copy_table_query" do
    let!(:samp_record) { TestModel.create(data: "good copy text") }

    it "returns query that copies records from source to destination table" do
      expect(PostgresUtility.copy_table_query(TestModel, DestinationTestModel)).to be
    end
  end
end
