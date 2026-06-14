module PaizaioStubs
  def stub_paizaio_api(stdout: "Hello world\n")
    stub_request(:post, "https://api.paiza.io/runners/create.json")
      .to_return(
        status: 200,
        body: { id: "test_runner_id" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    stub_request(:get, /api\.paiza\.io.*get_status/)
      .to_return(
        status: 200,
        body: { status: "completed" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    stub_request(:get, /api\.paiza\.io.*get_details/)
      .to_return(
        status: 200,
        body: { stdout: stdout, stderror: "" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end
end
