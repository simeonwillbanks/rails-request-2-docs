module Middleware
  class TracePoint

    def initialize(app)
      @app = app
    end

    def call(env)
      stats = ""
      trace = ::TracePoint.new(:call) do |tp|
        #p [tp.lineno, tp.defined_class, tp.method_id, tp.event]
        stats << "#{tp.defined_class} #{tp.method_id}\n"
      end

      trace.enable
      response = @app.call(env)
      trace.disable

      File.open("/Users/simeon/Desktop/trace.txt", "w") do |f|
        f.write stats
      end

      response
    end
  end
end
