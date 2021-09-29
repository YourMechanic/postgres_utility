# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
RSpec.describe PostgresUtility do
  before(:each) do
    ActiveRecord::Base.connection.execute %{
      TRUNCATE TABLE test_models;
      SELECT setval('test_models_id_seq', 1, false);
    }
  end

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

  describe ".vacuum_analyze" do
    let!(:samp_record) { TestModel.create(data: "good copy text") }

    it "performs vacuum and analyze" do
      expect(PostgresUtility.vacuum_analyze(TestModel).cmd_status).to eq("VACUUM")
    end
  end

  describe ".multi_dump_to_csv" do
    let!(:samp_record) { TestModel.create(data: "good copy text") }
    let(:csv_path) { "spec/fixtures/test_model.csv" }

    it "copies tables to a csv" do
      PostgresUtility.multi_dump_to_csv([{ tbl: TestModel, csv_path: csv_path }])
      expect(File.exist?(csv_path)).to eq(true)
      File.delete(csv_path)
    end
  end

  describe ".multi_dump_query_result_to_csv" do
    let!(:samp_record) { TestModel.create(data: "good copy text") }
    let(:csv_path) { "spec/fixtures/test_model.csv" }

    it "dumps query results to a csv" do
      PostgresUtility.multi_dump_query_result_to_csv("select * from test_models", csv_path)
      expect(File.exist?(csv_path)).to eq(true)
      File.delete(csv_path)
    end
  end

  describe ".fix_sequence_value" do
    let!(:samp_record) { TestModel.create(data: "good copy text") }

    it "fixes id sequence" do
      PostgresUtility.fix_sequence_value(TestModel)
      expect(TestModel.pluck(:id)).to be
    end
  end

  describe ".fix_sequence_value_with_cap" do
    let!(:samp_record) { TestModel.create(data: "good copy text") }

    it "fixes id sequence" do
      PostgresUtility.fix_sequence_value_with_cap(TestModel)
      expect(TestModel.pluck(:id)).to be
    end
  end

  describe ".get_random_record" do
    let!(:samp_record) { TestModel.create(data: "good copy text") }
    it "finds a random record" do
      expect(PostgresUtility.get_random_record(TestModel)).to be
    end
  end

  describe ".system_with_print" do
    it "executes with on command line using system" do
      expect(PostgresUtility.system_with_print("ls")).to be
    end
  end

  describe ".batch_insert" do
    xit "executes batch insert" do
      PostgresUtility.batch_insert(model: TestModel, values: [{ id: 10, data: "new_record_1" },
                                                              { id: 11, data: "new_record_2" }])
      expect(TestModel.where(data: "new_record_1")).to be
    end
  end
end

# rubocop:enable Metrics/BlockLength
