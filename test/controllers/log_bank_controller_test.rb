require 'test_helper'
require 'db_helper'

class LogBankControllerTest < ActionController::TestCase
  include DBHelper

  def setup
    super

    stub_authentication
  end


  test "should get status" do
    get :status
    assert_response :success
  end

  test "get_simulation_stdout_size should return correct file size" do
    file_record = SimulationOutputRecord.new(
        experiment_id: '7563304ae13823b1dfa3c7ce',
        simulation_idx: '1',
        file_size: 12345,
        type: 'stdout'
    )

    file_record.save

    assert_not_nil SimulationOutputRecord.where(experiment_id: '7563304ae13823b1dfa3c7ce', simulation_idx: '1', type: 'stdout').first

    get :get_simulation_stdout_size, experiment_id: "7563304ae13823b1dfa3c7ce", simulation_id: "1"

    assert_response :success

    resp = JSON.parse(response.body)
    assert_equal 12345, resp['size']
  end


  test "put_simulation_stdout should store a file in db" do
    LogBankController.any_instance.stubs(:authorize_put)

    uploaded_file = ActionDispatch::Http::UploadedFile.new({tempfile: File.new(Rails.root.join("test/db_helper.rb"))})

    post :put_simulation_stdout, experiment_id: "7563304ae13823b1dfa3c7ce", simulation_id: "1", file: uploaded_file
    assert_response :success

    file_record = SimulationOutputRecord.where(experiment_id:  "7563304ae13823b1dfa3c7ce", simulation_idx: "1", type: 'stdout').first

    assert_not_nil file_record
    assert_equal uploaded_file.tempfile.size, file_record.file_size
    assert_equal uploaded_file.tempfile.size, file_record.file_object.size
  end


end
