module Middleware
  class TracePoint

    def initialize(app)
      @app = app
    end

    def call(env)
      all = ""
      stats = {}
      trace = ::TracePoint.new(:call) do |tp|

        all << "#{tp.defined_class} #{tp.method_id} #{tp.lineno} #{tp.path}\n"

        stats[tp.defined_class] ||= {}
        stats[tp.defined_class][tp.method_id] ||= 0
        stats[tp.defined_class][tp.method_id] += 1
      end

      trace.enable
      response = @app.call(env)
      trace.disable

      puts "#{stats.keys.size} classes used"
      puts "#{stats.map{|k,v| v.keys}.flatten.size} methods used"
      puts "#{stats.map{|k,v| v.values}.flatten.sum} methods dispatched"

      file_name = "/Users/simeon/Desktop/traces/#{env['PATH_INFO'].gsub('/', '_')}"

      File.open("#{file_name}_req_stats.json", "w") {|f| f << stats.to_json}

      File.open("#{file_name}_all.txt", "w") {|f| f << all }

      response
    end
  end
end
