# logstash-filter-asset_network
A simple plugin written for Logstash, which complements the asset_manager plugin in Kibana

# Logstash Plugin

This is a plugin for [Logstash](https://github.com/elastic/logstash).

It is fully free and fully open source. The license is Apache 2.0, meaning you are pretty much free to use it however you want in whatever way.

## Documentation

Logstash provides infrastructure to automatically generate documentation for this plugin. We use the asciidoc format to write documentation so any comments in the source code will be first converted into asciidoc and then into html. All plugin documentation are placed under one [central location](http://www.elastic.co/guide/en/logstash/current/).

- For formatting code or config example, you can use the asciidoc `[source,ruby]` directive
- For more asciidoc formatting tips, see the excellent reference here https://github.com/elastic/docs#asciidoc-guide

## Need Help?

Need help? Try #logstash on freenode IRC or the https://discuss.elastic.co/c/logstash discussion forum.

## Developing

### 0. Create new plugin:
mkdir /logstash-dev
cd /usr/share/logstash
bin/logstash-plugin generate --type filter --name asset --path /logstash-dev

### 1. Plugin Developement and Testing

#### Code
- To get started, you'll need JRuby with the Bundler gem installed.

- Create a new plugin or clone and existing from the GitHub [logstash-plugins](https://github.com/logstash-plugins) organization. We also provide [example plugins](https://github.com/logstash-plugins?query=example).

- Install bundler
```sh
jruby -S gem install bundler
```

- Install dependencies
```sh
 cd /logstash-dev/logstash-filter-asset_network
bundle install
```

#### Test

- Update your dependencies

```sh
bundle install
```

- Run tests

```sh
bundle exec rspec
```

- Build your plugin gem
```sh
cd /logstash-dev/logstash-filter-asset_network
jruby -S gem build logstash-filter-asset_network.gemspec
```

### 2. Running your unpublished Plugin in Logstash

#### 2.1 Run in a local Logstash clone
- Install the plugin from the Logstash home
```sh
cd /usr/share/logstash
bin/logstash-plugin install --local --no-verify /logstash-dev/logstash-filter-asset_network/logstash-filter-asset_network-0.1.0.gem
```

- Start Logstash and proceed to test the plugin
```
clear
/usr/share/logstash/bin/logstash  --log.level info -w 2 -f /logstash-dev/logstash-filter-asset_network/test-asset.conf
```





### 3. Make and Run Commands in breaf
```
clear
cd /logstash-dev/logstash-filter-asset_network
jruby -S gem build logstash-filter-asset_network.gemspec
cd /usr/share/logstash
bin/logstash-plugin install --local --no-verify /logstash-dev/logstash-filter-asset_network/logstash-filter-asset_network-0.1.0.gem

/usr/share/logstash/bin/logstash  --log.level debug -w 2 -f /logstash-dev/logstash-filter-asset_network/test-asset.conf


 ```


 ### 4.sample data for test
 ```
{"client":{"ip":"192.168.3.60"}}

{"source":{"ip":"172.16.0.10"}}

{"source":{"ip":"172.16.2.30"}}

{"source":{"ip":"10.10.0.1"}}

{"destination":{"ip":"192.168.2.50"}}

{"destination":{"ip":"192.168.3.60"}}

{"destination":{"ip":"192.168.4.60"}}

{"source":{"ip":"172.16.0.10"},"destination":{"ip":"192.168.0.50"}}

{"source":{"ip":"172.16.0.10"},"destination":{"ip":"192.168.0.50"},"host":{"ip":"172.16.5.90"}}

{"source":{"ip":"192.168.0.50"},"destination":{"ip":"192.168.2.50"},"host":{"ip":"172.16.5.90"}}


 ```


 ### 5.Make Offline Pack
 ```
mkdir /logstash-dev
cd /usr/share/logstash
bin/logstash-plugin prepare-offline-pack --output /logstash-dev/logstash-filter-asset_network/logstash-filter-asset_network.zip --overwrite logstash-filter-asset_network
```

#for install plugin by offline pack
```
cd /usr/share/logstash
bin/logstash-plugin install file:///logstash-dev/logstash-filter-asset_network/logstash-filter-asset_network.zip
```

