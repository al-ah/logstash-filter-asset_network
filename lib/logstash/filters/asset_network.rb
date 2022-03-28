# Besme Allah

require "logstash/filters/base"

require 'logstash/util/loggable'
include LogStash::Util::Loggable

require_relative "client"
java_import "java.util.concurrent.ConcurrentHashMap"

require "ipaddr"
require 'json'

# This  filter will replace the contents of the default
# message field with whatever you specify in the configuration.
#
# It is only intended to be used as an .
class LogStash::Filters::AssetNetwork < LogStash::Filters::Base

  # Setting the config_name here is required. This is how you
  # configure this filter from your Logstash config.
  #
  # filter {
      # asset_network {
      #   hosts => [ "localhost:9200" ]
      #   user => "admin"
      #   password => "P@ssw0rd"
      #   ssl => true
      #   ca_file => "/etc/logstash/certs/http_ca.crt"
      #   index => "utility-asset-network"
      #   query_string => "*"
      #   order_by => "priority"
      #   order_type => "desc"
      #   request_timeout => 30
      #   refresh_interval => 1800
      #   ip_field => "[source][ip]"
      #   name_target =>  "[source][Ip_info][network]"
      #   geo_target =>  "[source][geo][location]"
      #   no_match_tag => "no_network_matched"
      #   no_network_tag => "no_network_exists"
      # }	
  # }
  #
  config_name "asset_network"

  # If the file is set, data will not be received from the elastic.
  config :source_file, :validate => :string

  # List of elasticsearch hosts to use for querying.
  config :hosts, :validate => :array,  :default => [ "localhost:9200" ]
  
  # Basic Auth - username
  config :user, :validate => :string

  # Basic Auth - password
  config :password, :validate => :password

  # SSL
  config :ssl, :validate => :boolean, :default => false

  # SSL Certificate Authority file
  config :ca_file, :validate => :path
  
  # Field substitution (e.g. `index-name-%{date_field}`) is available
  config :index, :validate => :string, :default => "utility-asset-network"

  # Elasticsearch query string. Read the Elasticsearch query string documentation.
  config :query_string, :validate => :string, :default => "*"

  # pairs that define the sort order
  config :order_by, :validate => :string, :default => "priority"
  config :order_type, :validate => :string, :default => "desc"

  # Elasticsearch request timeout
  config :request_timeout, :validate => :number, :default => 30

  # refresh network list every seconds
  config :refresh_interval, :validate => :number, :default => 1800

  # ip field names
  config :ip_field, :validate => :string,  :default => "[source][ip]"

  # network name field
  config :name_target, :validate => :string #, :default =>  "[source][Ip_info][network]"

  # geo location field name
  config :geo_target, :validate => :string #, :default =>  "[source][geo][location]"

  # If it does not match any network
  config :no_match_tag, :validate => :string , :default => "no_network_matched"

  # If it does not exists any network
  config :no_network_tag, :validate => :string , :default => "no_network_exists"

  
  public
  def register

    # Add instance variables
    @network_list ||= []
    @do_stop ||= false

    if @source_file.nil?
      
      @clients_pool = java.util.concurrent.ConcurrentHashMap.new
      test_connection! 
    end

    # get asset list
    makeRefreshThread()
  end # def register

  
  public
  def stop
    @do_stop = true
  end

  public
  def filter(event)
    begin      
      ip = event.get("#{@ip_field}")
      return if ip.nil?

      # the IP field must not is an array
      if ip.is_a? Enumerable
        ip = ip[0]
      end

      if !@network_list.empty? 
        matched = false
        @network_list.map{|nl|
            if nl[:net].include? ip
              matched = true
              # add net name
              event.set(@name_target, nl[:name]) if !@name_target.nil? && !nl[:name].nil?
              # add geo location
              event.set(@geo_target, nl[:location])  if !@geo_target.nil? && !nl[:location].nil?
              # add tag
              nl[:tags].map{|t|
                event.tag(t)
              }
              logger.debug("assetManager",{:message => "#{@ip_field}:#{ip}) matched by network #{nl[:network]}"}) 
              break
            end
        }

        event.tag("#{@no_match_tag}-#{@ip_field.gsub('[','').gsub(']','')}")  if !matched
      else
        event.tag(@no_network_tag)
      end
    rescue => err
      logger.error("assetManager",{:message => "error while check asset network",:error => err.message ,:backtrace => err.backtrace})         

    end

    # filter_matched should go in the last line of our successful code
    filter_matched(event)
  end # def filter

  private
  def client_options
    {
      :ssl => @ssl,
      :hosts => @hosts,
      :ca_file => @ca_file,
      :logger => @logger,
      :request_timeout => @request_timeout
    }
  end

  def newClient
    LogStash::Filters::AssetNetworkElasticsearchClient.new(@user, @password, client_options)
  end

  def getClient
    @clients_pool.computeIfAbsent(Thread.current, lambda { |x| newClient })
  end

  def test_connection!
    getClient.client.ping
  end

  def makeRefreshThread()            
    logger.info("assetManager",{:message => "making refresh thread."}) 
    @refresh_thread =
        Thread.new do 
            while !@do_stop        
                getNetworkList()
                if @network_list.length == 0 
                  logger.info("assetManager",{:message => "network list is empty,next try in 60 secconds."})
                  sleep(60)
                else
                  sleep(@refresh_interval)   
                end                     
            end              
        end
    logger.info( "assetManager",{:message => "new refresh thread is running."}) 
  end # def checkRefreshTime

  def getNetworkList
      logger.debug("assetManager",{:message => "trying to get network list..."})
    begin
      temp_list = []
        if !@source_file.nil?
            File.open(@source_file).each {|line|
              if !line.empty? && line.length > 10
                json_line = JSON.parse(line)
                
                location = nil
                if !@geo_target.empty? && !json_line["lat"].nil? && !json_line["lon"].nil?
                  location = {:lon => json_line["lon"].to_f,
                              :lat => json_line["lat"].to_f
                            }
                end
                temp_list.push( {
                    :net => IPAddr.new(json_line["network"]),
                    :network => json_line["network"],
                    :name => json_line["name"],
                    :tags => (json_line["tags"] || "network_matched").gsub(' ', '').split(','),
                    :location => location
                  })    
              end    
            }
        else
            elasticClient = getClient()
            # get network list order by priority
            res = elasticClient.client.msearch(body: [{ index: @index },
                                                    {size:10000,
                                                    _source:["*"],
                                                    sort:{"#{@order_by}":{"order": "#{@order_type}"}},
                                                    "query":{"bool":{"must":[{"query_string":{"query":"#{@query_string}"}}]}}
                                                    }
                                            ])

            if res["responses"][0]["hits"]["total"]["value"] != 0 
                res["responses"][0]["hits"]["hits"].map{|h|
                      location = nil
                      if !@geo_target.empty? && !h["_source"]["lat"].nil? && !h["_source"]["lon"].nil?
                        location = {:lon => h["_source"]["lon"].to_f,
                                    :lat => h["_source"]["lat"].to_f
                                  }
                      end
                  temp_list.push( {
                      :net => IPAddr.new(h["_source"]["network"]),
                      :network => h["_source"]["network"],
                      :name => h["_source"]["name"],
                      :tags => (h["_source"]["tags"] || "network_matched").gsub(' ', '').split(','),
                      :location => location
                    })        
                }
            end
        end
      
      @network_list = temp_list
      if @network_list.length == 0
        logger.warn("assetManager",{:message => "there is no network list."})
      else
        logger.info("assetManager",{:message => "asset network list updated,current count: #{@network_list.length}"})
      end
    rescue => err
      @network_list = []
      logger.error("assetManager",{:message => "can not get network list.",:error => err.message,:backtrace => err.backtrace})
    end

  end # def getAssetList

end # class LogStash::Filters::AssetNetwork
