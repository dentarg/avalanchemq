require "./spec_helper"
require "../src/avalanchemq/shovel"
require "amqp"

describe AvalancheMQ::Shovel do
  it "can shovel and stop when queue length is met" do
    s = AvalancheMQ::Server.new("/tmp/spec", Logger::ERROR)
    spawn { s.listen(5672) }
    Fiber.yield
    AMQP::Connection.start do |conn|
      ch = conn.channel
      x = ch.exchange("", "direct", passive: true)
      q1 = ch.queue("q1")
      q2 = ch.queue("q2")
      pmsg = AMQP::Message.new("shovel me")
      x.publish pmsg, "q1"

      source = AvalancheMQ::Shovel::Source.new(
        "amqp://guest:guest@localhost",
        "q1",
        delete_after: AvalancheMQ::Shovel::DeleteAfter::QueueLength
      )
      dest = AvalancheMQ::Shovel::Destination.new(
        "amqp://guest:guest@localhost",
        "q2"
      )
      shovel = AvalancheMQ::Shovel.new(source, dest)
      shovel.run
      q2.get(no_ack: true).to_s.should eq "shovel me"
    end
    s.close
  end

  it "can shovel large messages" do
    s = AvalancheMQ::Server.new("/tmp/spec", Logger::ERROR)
    spawn { s.listen(5672) }
    Fiber.yield
    AMQP::Connection.start do |conn|
      ch = conn.channel
      x = ch.exchange("", "direct", passive: true)
      q1 = ch.queue("q1")
      q2 = ch.queue("q2")
      pmsg = AMQP::Message.new("a" * 10_000)
      x.publish pmsg, "q1"

      source = AvalancheMQ::Shovel::Source.new(
        "amqp://guest:guest@localhost",
        "q1",
        delete_after: AvalancheMQ::Shovel::DeleteAfter::QueueLength
      )
      dest = AvalancheMQ::Shovel::Destination.new(
        "amqp://guest:guest@localhost",
        "q2"
      )
      shovel = AvalancheMQ::Shovel.new(source, dest)
      shovel.run
      q2.get(no_ack: true).to_s.bytesize.should eq 10_000
    end
    s.close
  end

  it "can shovel forever" do
    s = AvalancheMQ::Server.new("/tmp/spec", Logger::DEBUG)
    spawn { s.listen(5672) }
    Fiber.yield
    AMQP::Connection.start do |conn|
      ch = conn.channel
      x = ch.exchange("", "direct", passive: true)
      q1 = ch.queue("q1")
      q2 = ch.queue("q2")
      source = AvalancheMQ::Shovel::Source.new(
        "amqp://guest:guest@localhost",
        "q1",
        delete_after: AvalancheMQ::Shovel::DeleteAfter::Never
      )
      dest = AvalancheMQ::Shovel::Destination.new(
        "amqp://guest:guest@localhost",
        "q2"
      )
      shovel = AvalancheMQ::Shovel.new(source, dest)
      spawn { shovel.run }
      pmsg = AMQP::Message.new("shovel me")
      x.publish pmsg, "q1"
      rmsg = nil
      until rmsg = q2.get(no_ack: true)
        Fiber.yield
      end
      rmsg.to_s.should eq "shovel me"
      shovel.stop
      Fiber.yield
    end
    s.close
  end
end
