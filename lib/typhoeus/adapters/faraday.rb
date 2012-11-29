require 'faraday'

module Faraday # :nodoc:
  class Adapter # :nodoc:

    # Adapter to use Faraday with Typhoeus.
    #
    # @example Use Typhoeus.
    #   require 'faraday'
    #   require 'typhoeus'
    #   require 'typhoeus/adapters/faraday'
    #
    #   conn = Faraday.new(url: "www.example.com") do |faraday|
    #     faraday.adapter :typhoeus
    #   end
    #
    #   response = conn.get("/")
    class Typhoeus < Faraday::Adapter
      self.supports_parallel = true

      # Setup Hydra with provided options.
      #
      # @example Setup Hydra.
      #   Faraday::Adapter::Typhoeus.setup_parallel_manager
      #   #=> #<Typhoeus::Hydra ... >
      #
      # @param (see Typhoeus::Hydra#initialize)
      # @option (see Typhoeus::Hydra#initialize)
      #
      # @return [ Typhoeus::Hydra ] The hydra.
      def self.setup_parallel_manager(options = {})
        ::Typhoeus::Hydra.new(options)
      end

      dependency 'typhoeus'

      # Hook into Faraday and perform the request with Typhoeus.
      #
      # @param [ Hash ] env The environment.
      #
      # @return [ void ]
      def call(env)
        super
        perform_request env
        @app.call env
      end

      private

      def perform_request(env)
        if parallel?(env)
          env[:parallel_manager].queue request(env)
        else
          request(env).run
        end
      end

      def request(env)
        read_body env

        req = ::Typhoeus::Request.new(
          env[:url].to_s,
          :method  => env[:method],
          :body    => env[:body],
          :headers => env[:request_headers]
        )

        configure_ssl     req, env
        configure_proxy   req, env
        configure_timeout req, env
        configure_socket  req, env

        req.on_complete do |resp|
          if resp.timed_out?
            if parallel?(env)
              # TODO: error callback in async mode
            else
              raise Faraday::Error::TimeoutError, "request timed out"
            end
          end

          save_response(env, resp.code, resp.body) do |response_headers|
            response_headers.parse resp.response_headers
          end
          # in async mode, :response is initialized at this point
          env[:response].finish(env) if parallel?(env)
        end

        req
      end

      def read_body(env)
        env[:body] = env[:body].read if env[:body].respond_to? :read
      end

      def configure_ssl(req, env)
        ssl = env[:ssl]

        ssl_verifyhost = (ssl && ssl.fetch(:verify, true)) ? 2 : 0
        req.options[:ssl_verifyhost] = ssl_verifyhost
        req.options[:sslversion] = ssl[:version]          if ssl[:version]
        req.options[:sslcert]    = ssl[:client_cert]      if ssl[:client_cert]
        req.options[:sslkey]     = ssl[:client_key]       if ssl[:client_key]
        req.options[:cainfo]     = ssl[:ca_file]          if ssl[:ca_file]
        req.options[:capath]     = ssl[:ca_path]          if ssl[:ca_path]
      end

      def configure_proxy(req, env)
        proxy = env[:request][:proxy]
        return unless proxy

        req.options[:proxy] = "#{proxy[:uri].host}:#{proxy[:uri].port}"

        if proxy[:username] && proxy[:password]
          req.options[:proxyuserpwd] = "#{proxy[:username]}:#{proxy[:password]}"
        end
      end

      def configure_timeout(req, env)
        env_req = env[:request]
        req.options[:timeout_ms] = (env_req[:timeout] * 1000)             if env_req[:timeout]
        req.options[:connecttimeout_ms] = (env_req[:open_timeout] * 1000) if env_req[:open_timeout]
      end

      def configure_socket(req, env)
        if bind = env[:request][:bind]
          req.options[:interface] = bind[:host]
        end
      end

      def parallel?(env)
        !!env[:parallel_manager]
      end
    end
  end
end
