module Typhoeus
  module Requests

    # This module handles the blocked connection request mode on
    # the request side, where only stubbed requests
    # are allowed.
    # Connection blocking needs to be turned on:
    #   Typhoeus.configure do |config|
    #     config.block_connection = true
    #   end
    #
    # When trying to do real requests a NoStub error
    # is raised.
    module BlockConnection

      # Overrides run in order to check before if block connection
      # is turned on. If thats the case a NoStub error is
      # raised.
      #
      # @example Run request.
      #   request.run
      def run
        if Typhoeus::Config.block_connection
          raise Typhoeus::Errors::NoStub.new(self)
        else
          super
        end
      end
    end
  end
end
