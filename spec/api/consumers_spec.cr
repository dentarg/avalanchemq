require "../spec_helper"

describe AvalancheMQ::ConsumersController do
  describe "GET /api/consumers" do
    it "should return all consumers" do
      s = AvalancheMQ::Server.new("/tmp/spec", Logger::ERROR)
      h = AvalancheMQ::HTTPServer.new(s, 8080)
      spawn { s.try &.listen(5672) }
      spawn { h.try &.listen }
      Fiber.yield
      AMQP::Connection.start do |conn|
        ch = conn.channel
        q = ch.queue("")
        q.subscribe {}
        response = HTTP::Client.get("http://localhost:8080/api/consumers",
                                    headers: test_headers)
        response.status_code.should eq 200
        body = JSON.parse(response.body)
        body.as_a.empty?.should be_false
        keys = ["prefetch_count", "ack_required", "exclusive", "consumer_tag", "channel_details",
                "queue"]
        body.each { |v| keys.each { |k| v.as_h.keys.should contain(k) } }
      end
    ensure
      h.try &.close
      s.try &.close
    end

    it "should return empty array if no consumers" do
      s = AvalancheMQ::Server.new("/tmp/spec", Logger::ERROR)
      h = AvalancheMQ::HTTPServer.new(s, 8080)
      spawn { s.try &.listen(5672) }
      spawn { h.try &.listen }
      Fiber.yield
      response = HTTP::Client.get("http://localhost:8080/api/consumers",
                                  headers: test_headers)
      response.status_code.should eq 200
      body = JSON.parse(response.body)
      body.as_a.empty?.should be_true
    ensure
      h.try &.close
      s.try &.close
    end
  end

  describe "GET /api/consumers/vhost" do
    it "should return all consumers for a vhost" do
      s = AvalancheMQ::Server.new("/tmp/spec", Logger::ERROR)
      h = AvalancheMQ::HTTPServer.new(s, 8080)
      spawn { s.try &.listen(5672) }
      spawn { h.try &.listen }
      Fiber.yield
      AMQP::Connection.start do |conn|
        ch = conn.channel
        q = ch.queue("")
        q.subscribe {}
        response = HTTP::Client.get("http://localhost:8080/api/consumers/%2f",
                                    headers: test_headers)
        response.status_code.should eq 200
        body = JSON.parse(response.body)
        body.as_a.size.should eq 1
      end
    ensure
      h.try &.close
      s.try &.close
    end

    it "should return empty array if no consumers" do
      s = AvalancheMQ::Server.new("/tmp/spec", Logger::ERROR)
      h = AvalancheMQ::HTTPServer.new(s, 8080)
      spawn { s.try &.listen(5672) }
      spawn { h.try &.listen }
      Fiber.yield
      response = HTTP::Client.get("http://localhost:8080/api/consumers/%2f",
                                  headers: test_headers)
      response.status_code.should eq 200
      body = JSON.parse(response.body)
      body.as_a.empty?.should be_true
    ensure
      h.try &.close
      s.try &.close
    end
  end
end