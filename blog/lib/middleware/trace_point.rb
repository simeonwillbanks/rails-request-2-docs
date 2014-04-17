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

        # Ruby EXAMPLE
        #
        # Fixnum to_s 59 /Users/simeon/.rbenv/versions/2.1.1/lib/ruby/2.1.0/securerandom.rb
        #
        # http://www.omniref.com/?q=Fixnum##to_s
        # http://www.omniref.com/ruby/2.1.1/classes/Fixnum##to_s
        # http://ruby-doc.org/core-2.1.1/Fixnum.html#method-i-to_s

        # Ruby Stdlib EXAMPLE
        # Ruby 2.1.1 sha1 1980b4d4e4cc1dfd7f04d88c03e9f0a60dd4e94e
        #
        # Mutex_m mu_synchronize 72 /Users/simeon/.rbenv/versions/2.1.1/lib/ruby/2.1.0/mutex_m.rb
        #
        # http://www.omniref.com/?q=Mutex_m##mu_synchronize
        # http://www.omniref.com/ruby/2.1.1/classes/Mutex_m##mu_synchronize
        # http://ruby-doc.org/stdlib-2.1.1/libdoc/mutex_m/rdoc/Mutex_m.html#method-i-mu_synchronize
        # https://github.com/ruby/ruby/blob/1980b4d4e4cc1dfd7f04d88c03e9f0a60dd4e94e/lib/mutex_m.rb#L72

        # Rails EXAMPLE
        # Rails 4.0.4 sha1 2abe4b032d080f7177c6f2e34c9124c468e8a293
        #
        # ActionDispatch::RequestId call 19 /Users/simeon/.rbenv/versions/2.1.1/lib/ruby/gems/2.1.0/gems/actionpack-4.0.4/lib/action_dispatch/middleware/request_id.rb
        #
        # http://www.omniref.com/?q=ActionDispatch%3A%3ARequestId##call
        # http://www.omniref.com/ruby/gems/actionpack/4.0.4/classes/ActionDispatch::RequestId##call
        # http://api.rubyonrails.org/classes/ActionDispatch/RequestId.html#method-i-call
        # https://github.com/rails/rails/blob/2abe4b032d080f7177c6f2e34c9124c468e8a293/actionpack/lib/action_dispatch/middleware/request_id.rb#L19


        # NOTES
        # - omniref search links have sidebar with other possible matches

        # QUESTIONS
        # - What to do about class methods?
        #
        # http://www.omniref.com/?q=OpenURI#.open_uri


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
