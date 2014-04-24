require "cgi"

module Middleware
  class TracePoint

    def initialize(app)
      @app = app
    end

    def call(env)
      # TODO
      # Move procedural logic into objects

      request_uri = env["REQUEST_URI"]

      json = []
      stats = {}
      csv = "Defined Class,Method ID,Line Number,Path\n"
      markdown = "### #{request_uri}\n"
      html_body = ""
      html = <<-HTML
<!DOCTYPE html>
<html>
  <head>
    <meta http-equiv="content-type" content="text/html; charset=utf-8" />
    <title>#{request_uri}</title>
    <style type="text/css">
      pre { margin: 0 }
    </style>
  </head>
  <body>
    <h1>#{request_uri}</h1>
    <ol>
      %s
    </ol>
  </body>
</html>
HTML

      trace = ::TracePoint.new(:call) do |tp|

        csv << "#{tp.defined_class},#{tp.method_id},#{tp.lineno},#{tp.path}\n"

        path = tp.path.sub("#{File.expand_path("~/.rbenv/versions")}/", "")

        class_method = tp.defined_class.to_s =~ /\A#<Class:/

        method_type = class_method ? "." : "#"

        class_name = if class_method
                       tp.defined_class.to_s.sub("#<Class:", "").sub(">", "")
                     else
                       tp.defined_class.to_s
                     end

        source = case path
                 when %r{/ruby/2.1.0/}
                   :stdlib
                 when /actionmailer|actionpack|actionview|activemodel|activerecord|activesupport|railties/
                   :rails
                 when %r{/ruby/gems/2.1.0/}
                   :gem
                 when /blog/
                   :blog
                 end

        basename = File.basename(path)

        gem_info = %r{/2.1.0/gems/(?<name>\S+)-(?<version>\d+.{1}\d+.{1}\d+)/}.match(path)

        omniref_path = case source
                       when :stdlib
                         "2.1.1/classes/#{class_name}##{method_type}#{tp.method_id}"
                       when :rails, :gem
                         "gems/#{gem_info[:name]}/#{gem_info[:version]}/classes/#{class_name}##{method_type}#{tp.method_id}"
                       end

        github_path = case source
                      when :stdlib
                        "ruby/ruby/blob/1980b4d4e4cc1dfd7f04d88c03e9f0a60dd4e94e/lib/#{basename}#L#{tp.lineno}"
                      when :rails
                        "rails/rails/blob/2abe4b032d080f7177c6f2e34c9124c468e8a293#{path.sub("2.1.1/lib/ruby/gems/2.1.0/gems", "").sub("-4.0.4", "")}#L#{tp.lineno}"
                      when :blog
                        "simeonwillbanks/rails-request-2-docs/blob/master/#{path.split("rails-request-2-docs/")[1]}#L#{tp.lineno}"
                      end

        display_path = case source
                       when :stdlib
                         path.sub("2.1.1/lib/ruby/2.1.0", "lib")
                       when :rails, :gem
                         path.sub("2.1.1/lib/ruby/gems/2.1.0/gems/", "")
                       when :blog
                         path.split("rails-request-2-docs/")[1]
                       end

        json_entry = {}

        title = "#{class_name}#{method_type}#{tp.method_id}"
        markdown << "1. **#{title}**\n"
        json_entry[:title] = title
        html_body << %q{<li style="margin-bottom: 1em">}
        html_body << "<strong>#{title}</strong>\n"

        source = "#{display_path}:#{tp.lineno}"
        markdown << "  - `#{source}`\n"
        json_entry[:source] = source
        html_body << "<ul>\n<li><pre>#{source}</pre></li>\n"

        markdown_links = []
        html_links = []

        if omniref_path
          json_entry[:omniref] = {}

          omniref_docs = "http://www.omniref.com/ruby/#{omniref_path}"
          markdown_links << "[omniref Docs](#{omniref_docs})"
          html_links << %Q{<a href="#{omniref_docs}">omniref Docs</a>}
          json_entry[:omniref][:docs] = omniref_docs

          omniref_search = "http://www.omniref.com/?q=#{CGI::escape(class_name)}##{method_type}#{tp.method_id}"
          markdown_links << "[omniref Search](#{omniref_search}"
          html_links << %Q{<a href="#{omniref_search}">omniref Search</a>}
          json_entry[:omniref][:search] = omniref_search
        end

        if github_path
          github_url = "https://github.com/#{github_path}"
          markdown_links << "[GitHub](#{github_url})"
          html_links << %Q{<a href="#{github_url}">GitHub</a>}
          json_entry[:github] = {url: github_url}
        end

        markdown << " - #{markdown_links.join(" | ")}\n"

        unless html_links.empty?
          html_body << "<li>#{html_links.join("</li>\n<li>")}</li>\n"
        end

        html_body << "</ul>\n</li>"

        json << json_entry

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

      path_info = env["PATH_INFO"][1..-1].gsub("/", "_")

      path_info = "index" if path_info.empty?

      path_info << "_#{env['REQUEST_METHOD']}"

      full_path = File.join(Rails.root, "..", "traces", path_info)

      File.open("#{full_path}_stats.json", "w") {|f| f << stats.to_json}

      File.open("#{full_path}_raw.csv", "w") {|f| f << csv}

      File.open("#{full_path}_docs.md", "w") {|f| f << markdown}

      File.open("#{full_path}_docs.json", "w") {|f| f << json.to_json}

      File.open("#{full_path}_docs.html", "w") {|f| f << sprintf(html, html_body)}

      response
    end
  end
end
