# Besme Allah

require "elasticsearch"
require "base64"
require "elasticsearch/transport/transport/http/manticore"

module LogStash
  module Filters
    class AssetNetworkElasticsearchClient

      attr_reader :client

      def initialize(user, password, options={})
        ssl     = options.fetch(:ssl, false)
        hosts   = options[:hosts]
        request_timeout = options[:request_timeout]
        @logger = options[:logger]

        transport_options = {}
        if user && password
          token = ::Base64.strict_encode64("#{user}:#{password.value}")
          transport_options[:headers] = { Authorization: "Basic #{token}" }
        end

        #hosts.map! {|h| { host: h, scheme: 'https' } } if ssl
        hosts = setup_hosts(hosts, ssl)
        # set ca_file even if ssl isn't on, since the host can be an https url
        ssl_options = { ssl: true, ca_file: options[:ca_file] } if options[:ca_file]
        ssl_options ||= {}

        @logger.info("New ElasticSearch filter client", :hosts => hosts)
        @client = ::Elasticsearch::Client.new(
          hosts: hosts, 
          transport_options: transport_options, 
          transport_class: ::Elasticsearch::Transport::Transport::HTTP::Manticore, 
          :ssl => ssl_options,
          request_timeout: request_timeout,
        )
      end

      private
      def setup_hosts(hosts, ssl)
        hosts.map do |h|
          if h.start_with?('http:/', 'https:/')
            h
          else
            host, port = h.split(':')
            { host: host, port: port, scheme: (ssl ? 'https' : 'http') }
          end
        end
      end
    end
  end
end
