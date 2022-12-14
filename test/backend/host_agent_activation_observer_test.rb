# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class HostAgentActivationObserverTest < Minitest::Test
  def setup
    @socket_proc = ->(_c) { OpenStruct.new(fileno: 0) }
  end

  def test_standard_discovery
    stub_request(:put, "http://10.10.10.10:9292/com.instana.plugin.ruby.discovery")
      .and_timeout
      .and_return(status: 500, body: '{"ok": false}')
      .and_return(status: 200, body: '[{"pid": 1234}]')
      .and_return(status: 200, body: '{"pid": 1234}')

    stub_request(:head, "http://10.10.10.10:9292/com.instana.plugin.ruby.1234")
      .and_return(status: 500, body: '{"ok": false}')
      .and_return(status: 200, body: '{"ok": true}')

    client = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
    discovery = Concurrent::Atom.new(nil)

    subject = Instana::Backend::HostAgentActivationObserver.new(client, discovery, wait_time: 0, logger: Logger.new('/dev/null'), max_wait_tries: 1, socket_proc: @socket_proc)

    subject.update(nil, nil, nil)
    assert_equal({'pid' => 1234}, discovery.value)
  end

  def test_linux_discovery
    stub_request(:put, "http://10.10.10.10:9292/com.instana.plugin.ruby.discovery")
      .and_return(status: 200, body: '{"pid": 1234}')

    stub_request(:head, "http://10.10.10.10:9292/com.instana.plugin.ruby.1234")
      .and_return(status: 200, body: '{"ok": true}')

    client = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
    discovery = Concurrent::Atom.new(nil)

    subject = Instana::Backend::HostAgentActivationObserver.new(client, discovery, wait_time: 0, logger: Logger.new('/dev/null'), max_wait_tries: 1, socket_proc: @socket_proc)

    FakeFS.with_fresh do
      FakeFS::FileSystem.clone('test/support/proc', '/proc')
      FakeFS::FileSystem.clone('test/support/proc/0', "/proc/#{Process.pid}")
      Dir.mkdir('/proc/self/fd')
      File.symlink('/proc/self/sched', "/proc/self/fd/0")

      subject.update(nil, nil, nil)
    end

    assert_equal({'pid' => 1234}, discovery.value)
  end

  def test_discovery_standard_error
    client = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
    discovery = Concurrent::Atom.new(nil)

    subject = Instana::Backend::HostAgentActivationObserver.new(client, discovery, wait_time: 0, logger: Logger.new('/dev/null'), proc_table: nil, socket_proc: @socket_proc)

    subject.update(nil, nil, nil)
    assert_nil discovery.value
  end

  def test_value_present
    client = Instana::Backend::RequestClient.new('10.10.10.10', 9292)
    discovery = Concurrent::Atom.new(nil)

    subject = Instana::Backend::HostAgentActivationObserver.new(client, discovery, socket_proc: @socket_proc)
    assert_nil subject.update(nil, nil, true)
    assert_nil discovery.value
  end
end
