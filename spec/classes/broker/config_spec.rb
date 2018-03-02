require "spec_helper"

describe("choria::broker::config") do
  before(:each) do
    Puppet::Parser::Functions.newfunction(:assert_private, :type => :rvalue) {|_| }
  end

  let(:facts) do
    {
      "aio_agent_version" => "1.7.0",
      "operatingsystem" => "CentOS",
      "osfamily" => "RedHat",
      "operatingsystemmajrelease" => "7",
      "networking" => {
        "domain" => "rspec.example.net",
        "fqdn" => "choria1.rspec.example.net"
      },
      "os" => {
        "family" => "RedHat"
      }
    }
  end

  let(:pre_condition) { 'class {"choria": }' }

  context("without the network broker") do
    let(:pre_condition) { 'class {"choria::broker": network_broker => false}' }

    it { should compile.with_all_deps }

    it "should enable the broker" do
      is_expected.to contain_file("/etc/choria/broker.cfg").with_content(/plugin.choria.srv_domain = rspec.example.net/)
      is_expected.to contain_file("/etc/choria/broker.cfg").with_content(/JSON information about this broker/)
      is_expected.to contain_file("/etc/choria/broker.cfg").without_content(/Embedded NATS general statistics/)
      is_expected.to contain_file("/etc/choria/broker.cfg").without_content(/plugin.choria.broker_network = true/)
      is_expected.to contain_file("/etc/choria/broker.cfg").without_content(/plugin.choria.network.peers/)
      is_expected.to contain_file("/etc/choria/broker.cfg").without_content(/plugin.choria.broker_federation/)
    end
  end

  context("standalone network broker") do
    let(:pre_condition) { 'class {"choria::broker": network_broker => true}' }

    it { should compile.with_all_deps }

    it "should enable the broker" do
      is_expected.to contain_file("/etc/choria/broker.cfg").with_content(/plugin.choria.srv_domain = rspec.example.net/)
      is_expected.to contain_file("/etc/choria/broker.cfg").with_content(/Embedded NATS general statistics/)
      is_expected.to contain_file("/etc/choria/broker.cfg").with_content(/plugin.choria.broker_network = true/)
      is_expected.to contain_file("/etc/choria/broker.cfg").with_content(/plugin.choria.network.listen_address = 0.0.0.0/)
      is_expected.to contain_file("/etc/choria/broker.cfg").with_content(/plugin.choria.network.client_port = 4222/)
      is_expected.to contain_file("/etc/choria/broker.cfg").with_content(/plugin.choria.network.peer_port = 5222/)
      is_expected.to contain_file("/etc/choria/broker.cfg").without_content(/plugin.choria.network.peers/)
    end
  end

  context("clustered network broker") do
    let(:pre_condition) { 'class {"choria::broker": network_broker => true, network_peers => ["nats://n1:5222", "nats://n2:5222"]}' }

    it { should compile.with_all_deps }

    it "should enable the broker" do
      is_expected.to contain_file("/etc/choria/broker.cfg").with_content(/plugin.choria.srv_domain = rspec.example.net/)
      is_expected.to contain_file("/etc/choria/broker.cfg").with_content(/Embedded NATS general statistics/)
      is_expected.to contain_file("/etc/choria/broker.cfg").with_content(/plugin.choria.broker_network = true/)
      is_expected.to contain_file("/etc/choria/broker.cfg").with_content(/plugin.choria.network.listen_address = 0.0.0.0/)
      is_expected.to contain_file("/etc/choria/broker.cfg").with_content(/plugin.choria.network.client_port = 4222/)
      is_expected.to contain_file("/etc/choria/broker.cfg").with_content(/plugin.choria.network.peer_port = 5222/)
      is_expected.to contain_file("/etc/choria/broker.cfg").with_content(/plugin.choria.network.peers = nats:\/\/n1:5222, nats:\/\/n2:5222/)
    end
  end

  context("federation broker") do
    let(:pre_condition) { 'class {"choria::broker": network_broker => false, federation_broker => true}' }

    it { should compile.with_all_deps }

    it "should enable the broker" do
      is_expected.to contain_file("/etc/choria/broker.cfg").with_content(/plugin.choria.broker_federation = true/)
      is_expected.to contain_file("/etc/choria/broker.cfg").with_content(/plugin.choria.federation.cluster = rp_env/)
      is_expected.to contain_file("/etc/choria/broker.cfg").with_content(/plugin.choria.federation.instance = choria1.rspec.example.net/)
    end
  end

  context("without adapters") do
    let(:pre_condition) { 'class {"choria::broker": }' }

    it "should enable the broker" do
      is_expected.to contain_file("/etc/choria/broker.cfg").without_content(/plugin.choria.adapters/)
    end
  end

  context("adapters") do
    context("natsstream") do
      let(:pre_condition) do
        <<-HEREDOC
        class{"choria::broker":
          adapters => {
            discovery => {
              stream => {
                type => "natsstream",
                servers => ["stan1:4222", "stan2:4222"],
                clusterid => "prod",
                topic => "discovery",
                workers => 10,
              },
              ingest => {
                topic => "mcollective.broadcast.agent.discovery",
                protocol => "request",
                workers => 10
              }
            }
          }
        }
        HEREDOC
      end

      it { should compile.with_all_deps }

      it "should configure the adapter" do
        expected = <<~HEREDOC
        # Adapters convert Choria messages into other formats and other protocols
        plugin.choria.adapters = discovery
        plugin.choria.adapter.discovery.stream.type = natsstream
        plugin.choria.adapter.discovery.stream.servers = stan1:4222, stan2:4222
        plugin.choria.adapter.discovery.stream.clusterid = prod
        plugin.choria.adapter.discovery.stream.topic = discovery
        plugin.choria.adapter.discovery.stream.workers = 10
        plugin.choria.adapter.discovery.ingest.topic = mcollective.broadcast.agent.discovery
        plugin.choria.adapter.discovery.ingest.protocol = request
        plugin.choria.adapter.discovery.ingest.workers = 10
        HEREDOC
        is_expected.to contain_file("/etc/choria/broker.cfg").with_content(Regexp.new(expected))
      end
    end
  end
end
