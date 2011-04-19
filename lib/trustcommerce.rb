require 'net/http'
require 'net/https'
require 'uri'

# [TrustCommerce](http://www.trustcommerce.com) is a payment gateway providing credit card
# processing and recurring / subscription billing services.
#
# This library provides a simple interface to create, edit, delete, and query subscriptions
# using TrustCommerce.
#
# ## Background ##
#
# TrustCommerce's recurring / subscription billing solution is implemented through a service
# called [Citadel](http://www.trustcommerce.com/citadel.php).  A Citadel-enabled account is
# required to use the subscription-based features implemented by this library.
#
# ### Citadel Basics ###
#
# * Citadel stores customer profiles which can include credit card information and billing frequency.
# * Citadel will automatically bill customers on their respective schedules.
# * Citadel identifies each customer by a Billing ID (six-character alphanumeric string).
# * A customer's profile, credit card, and billing frequency can be modified using the Billing ID.
#
# ## Installation ##
#
# The simple way:
#
#     $ sudo gem install trustcommerce
#
# Directly from repository:
#
#     $ svn co svn://rubyforge.org/var/svn/trustcommerce/trunk trustcommerce
#
# It is highly recommended to download and install the
# [TCLink ruby extension](http://www.trustcommerce.com/tclink.php).
# This extension provides failover capability and enhanced security features.
# If this library is not installed, standard POST over SSL will be used.
#
# ## Configuration ##
#
# When you signup for a TrustCommerce account you are issued a custid and a password.
# These are your credentials when using the TrustCommerce API.
#
#     TrustCommerce.custid   = '123456'
#     TrustCommerce.password = 'topsecret'
#
#     # optional - sets Vault password for use in query() calls
#     TrustCommerce.vault_password = 'supersecure'
#
# The password that TrustCommerce issues never changes or expires when used through the TCLink
# extension.  However if you choose to use SSL over HTTP instead (the fallback option if the TCLink
# library is not installed), be aware that you need to set the password to your Vault password.
# Likewise, if your application uses the query() method you must set the vault_password.
# The reason is that TrustCommerce currently routes these query() calls through the vault
# and therefore your password must be set accordingly.  To make matters more complicated,
# TrustCommerce currently forces you to change the Vault password every 90 days.
class TrustCommerce

  class << self
    attr_accessor :custid
    attr_accessor :password
    attr_accessor :vault_password

    # Returns Vault password.
    def vault_password
      @vault_password || password
    end
  end
  self.custid   = 'TestMerchant'
  self.password = 'password'

  # Settings for standard POST over SSL
  # Only used if TCLink library is not installed
  API_SETTINGS = {
    :domain => 'vault.trustcommerce.com',
    :query_path => '/query/',
    :trans_path => '/trans/',
    :port => 443
  }

  class Subscription

    #     # Bill Jennifer $12.00 monthly
    #     response = TrustCommerce::Subscription.create(
    #       :cc     => '4111111111111111',
    #       :exp    => '0412',
    #       :name   => 'Jennifer Smith',
    #       :amount => 1200,
    #       :cycle  => '1m'
    #     )
    #
    #     if response['status'] == 'approved'
    #       puts "Subscription created with Billing ID: #{response['billingid']}"
    #     else
    #       puts "An error occurred: #{response['error']}"
    #     end
    def self.create(options)
      return TrustCommerce.send_request(options.merge(:action => 'store'))
    end

    #     # Update subscription to use new credit card
    #     response = TrustCommerce::Subscription.update(
    #       :billingid => 'ABC123',
    #       :cc        => '5411111111111115',
    #       :exp       => '0412'
    #     )
    #
    #     if response['status'] == 'accepted'
    #       puts 'Subscription updated.'
    #     else
    #       puts "An error occurred: #{response['error']}"
    #     end
    def self.update(options)
      return TrustCommerce.send_request(options.merge(:action => 'store'))
    end

    #     # Delete subscription
    #     response = TrustCommerce::Subscription.delete(
    #       :billingid => 'ABC123'
    #     )
    #
    #     if response['status'] == 'accepted'
    #       puts 'Subscription removed from active use.'
    #     else
    #       puts 'An error occurred.'
    #     end
    def self.delete(options)
      return TrustCommerce.send_request(options.merge(:action => 'unstore'))
    end

    #     # Process one-time sale against existing subscription
    #     response = TrustCommerce::Subscription.charge(
    #       :billingid => 'ABC123',
    #       :amount    => 1995
    #     )
    def self.charge(options)
      return TrustCommerce.send_request(options.merge(:action => 'sale'))
    end

    #     # Process one-time credit against existing transaction
    #     response = TrustCommerce::Subscription.credit(
    #       :transid => '001-0000111101',
    #       :amount  => 1995
    #     )
    def self.credit(options)
      return TrustCommerce.send_request(options.merge(:action => 'credit'))
    end

    #     # Get all sale transactions for a subscription in CSV format
    #     response = TrustCommerce::Subscription.query(
    #       :querytype => 'transaction',
    #       :action    => 'sale',
    #       :billingid => 'ABC123'
    #     )
    def self.query(options)
      return TrustCommerce.send_query(options)
    end

  end

  class Result < Hash

    def initialize(constructor = {})
      if constructor.is_a?(Hash)
        super()
        update(constructor)
      else
        super(constructor)
      end
    end

    %w(approved accepted decline baddata error).each do |status|
      define_method("#{status}?") do
        self[:status] == status
      end
    end

  end

  # It is highly recommended to download and install the
  # [TCLink ruby extension](http://www.trustcommerce.com/tclink.php).
  # This extension provides failover capability and enhanced security features.
  # If this library is not installed, standard POST over SSL will be used.
  def self.tclink?
    begin
      require 'tclink'
      true
    rescue LoadError
      false
    end
  end

  private

    def self.stringify_hash(hash)
      hash.inject({}) { |h,(k,v)| h[k.to_s] = v.to_s; h }
    end

    def self.symbolize_hash(hash)
      hash.inject({}) { |h,(k,v)| h[k.to_sym] = v.to_s; h }
    end

    def self.send_request(options)
      options[:custid]   = self.custid
      options[:password] = self.password
      options.update(:demo => 'y') if ENV['RAILS_ENV'] != 'production'
      parameters = stringify_hash(options)
      if tclink? # use TCLink extension if installed
        return Result.new(symbolize_hash(TCLink.send(parameters)))
      else # TCLink library not installed - use https post
        parameters[:password] = self.vault_password.to_s
        response = send_https_request(API_SETTINGS[:trans_path], parameters)

        # parse response
        results = Result.new
        response.body.split("\n").each do |line|
          k, v = line.split('=')
          results[k.to_sym] = v
        end
        results
      end
    end

    def self.send_query(options)
      options[:custid]   = self.custid
      options[:password] = self.vault_password.to_s
      response = send_https_request(API_SETTINGS[:query_path], stringify_hash(options))
    end

    def self.send_https_request(path, parameters)
      http = Net::HTTP.new(API_SETTINGS[:domain], API_SETTINGS[:port])
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE # avoid ssl cert warning
      request = Net::HTTP::Post.new(path)
      request.form_data = parameters
      http.request(request)
    end

end