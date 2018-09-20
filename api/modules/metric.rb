# encoding: utf-8
require "logstash/json"
require "json"
require "socket"

module LogStash
  module Api
    module Modules
      class Metric < ::LogStash::Api::Modules::Base

        before do
          @stats = factory.build(:stats)
          @host = TCPSocket.gethostbyname(Socket.gethostname)[0]
          @data_str = ""
        end

        get "/" do
          stats_metrics
          hot_threads
          respond_with(@data_str, {:as => "text"})
        end

        private

        def each_kv(data, pre, gc_key=nil)
          data.each do |k, v|
            if [:old, :young, :survivor].include?k
              gc_key = k
              pre_k = pre
            else
              pre_k = "#{pre}_#{k}"
            end

            if v.class == Hash
              each_kv(v, pre_k, gc_key)

            elsif v.class == Array
              v.each do |value|
                if value.has_key?:id
                  if value.has_key?:events
                    duration = value[:events].fetch(:duration_in_millis, 0)
                    input = value[:events].fetch(:in, 0)
                    out = value[:events].fetch(:out, 0)
                    duration = duration.to_json_data if not duration.is_a?(Numeric)
                    input = input.to_json_data if not input.is_a?(Numeric)
                    out = out.to_json_data if not out.is_a?(Numeric)
                  else
                    duration = 0
                    input = 0
                    out = 0
                  end
                  tags = "{host=\"#{@host}\", plugin_id=\"#{value[:id]}\"}"
                  @data_str += "#{pre_k}_duration_in_millis#{tags} #{duration}\n"
                  @data_str += "#{pre_k}_in#{tags} #{input}\n"
                  @data_str += "#{pre_k}_out#{tags} #{out}\n"
                elsif value.has_key?:state
                  tags = "{host=\"#{@host}\", name=\"#{value[:name]}\", state=\"#{value[:state]}\", path=\"#{value[:path]}\"}"
                  @data_str += "#{pre_k}#{tags} #{value[:percent_of_cpu_time]}\n"
                end
              end

            else
              v = 0 if v == nil
              v = v.to_json_data if not v.is_a?(Numeric)

              if gc_key != nil
                tags = "{host=\"#{@host}\", generation=\"#{gc_key}\"}"
              else
                tags = "{host=\"#{@host}\"}"
              end

              @data_str += "#{pre_k}#{tag} #{v}\n"
            end
          end
        end


        def stats_metrics
          json = {
            :jvm => @stats.jvm,
            :process => @stats.process,
            :events => @stats.events,
            :plugins => @stats.plugins
          }
          each_kv(json, "logstash")
        end

        def hot_threads
          each_kv(@stats.hot_threads.to_hash_simple, "logstash")
        end

      end
    end
  end
end
