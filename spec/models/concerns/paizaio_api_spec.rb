require 'rails_helper'
require 'webmock/rspec'

RSpec.describe PaizaioApi, type: :model do
  before do
    stub_const("PaizaioApiTestClass", Class.new { include PaizaioApi })
  end

  subject(:instance) { PaizaioApiTestClass.new }

  describe '#create_runner' do
    it 'returns the runner id when the request succeeds' do
      expect(instance.create_runner("puts 1", "ruby", "")).to eq "test_runner_id"
    end

    it 'raises when the response body contains an error key' do
      stub_request(:post, "https://api.paiza.io/runners/create.json")
        .to_return(status: 200, body: { error: "invalid" }.to_json, headers: { "Content-Type" => "application/json" })

      expect { instance.create_runner("puts 1", "ruby", "") }.to raise_error(StandardError, "コードが実行できませんでした")
    end

    it 'raises when the response status is not 200' do
      stub_request(:post, "https://api.paiza.io/runners/create.json")
        .to_return(status: 500, body: "", headers: {})

      expect { instance.create_runner("puts 1", "ruby", "") }.to raise_error(StandardError, "リクエストに失敗しました")
    end

    it 'returns nil when the response body has neither an id nor an error key (documents current behavior; see issue #312)' do
      stub_request(:post, "https://api.paiza.io/runners/create.json")
        .to_return(status: 200, body: {}.to_json, headers: { "Content-Type" => "application/json" })

      expect(instance.create_runner("puts 1", "ruby", "")).to be_nil
    end

    it 'sends the value returned by ENV.fetch("PAIZAIO_API_KEY", "guest") as the api_key parameter' do
      allow(ENV).to receive(:fetch).with("PAIZAIO_API_KEY", "guest").and_return("configured_key")

      instance.create_runner("puts 1", "ruby", "")

      expect(WebMock).to have_requested(:post, "https://api.paiza.io/runners/create.json")
        .with(body: hash_including("api_key" => "configured_key"))
    end

    it 'falls back to the guest api_key when PAIZAIO_API_KEY is not configured' do
      allow(ENV).to receive(:fetch).with("PAIZAIO_API_KEY", "guest").and_return("guest")

      instance.create_runner("puts 1", "ruby", "")

      expect(WebMock).to have_requested(:post, "https://api.paiza.io/runners/create.json")
        .with(body: hash_including("api_key" => "guest"))
    end
  end

  describe '#get_status' do
    it 'returns the status when the request succeeds' do
      expect(instance.get_status("test_runner_id")).to eq "completed"
    end

    it 'raises when the response body is missing the status key' do
      stub_request(:get, /api\.paiza\.io.*get_status/)
        .to_return(status: 200, body: {}.to_json, headers: { "Content-Type" => "application/json" })

      expect { instance.get_status("test_runner_id") }.to raise_error(StandardError, "idが無効です")
    end

    it 'raises when the response status is not 200' do
      stub_request(:get, /api\.paiza\.io.*get_status/)
        .to_return(status: 500, body: "", headers: {})

      expect { instance.get_status("test_runner_id") }.to raise_error(StandardError, "リクエストに失敗しました")
    end
  end

  describe '#get_details' do
    it 'returns the response body when the request succeeds' do
      expect(instance.get_details("test_runner_id")["stdout"]).to eq "Hello world\n"
    end

    it 'raises when the response body is missing the stdout key' do
      stub_request(:get, /api\.paiza\.io.*get_details/)
        .to_return(status: 200, body: {}.to_json, headers: { "Content-Type" => "application/json" })

      expect { instance.get_details("test_runner_id") }.to raise_error(StandardError, "idが無効です")
    end

    it 'raises when the response status is not 200' do
      stub_request(:get, /api\.paiza\.io.*get_details/)
        .to_return(status: 500, body: "", headers: {})

      expect { instance.get_details("test_runner_id") }.to raise_error(StandardError, "リクエストに失敗しました")
    end
  end

  describe '#run_source' do
    it 'polls until the status is no longer running and returns the details' do
      allow(instance).to receive(:sleep)

      result = instance.run_source("puts 1")

      expect(result["stdout"]).to eq "Hello world\n"
    end

    it 'polls multiple times before the status becomes completed' do
      allow(instance).to receive(:sleep)
      allow(instance).to receive(:get_status).and_return("running", "running", "completed")

      result = instance.run_source("puts 1")

      expect(result["stdout"]).to eq "Hello world\n"
      expect(instance).to have_received(:get_status).exactly(3).times
    end

    it 'raises a polling timeout error after exhausting the max poll attempts' do
      allow(instance).to receive(:sleep)
      allow(instance).to receive(:get_status).and_return("running")

      expect { instance.run_source("puts 1") }.to raise_error(StandardError, "PaizaIO polling timeout")
    end
  end
end
