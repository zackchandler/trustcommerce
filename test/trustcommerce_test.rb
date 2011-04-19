require File.expand_path("../test_helper", __FILE__)

# The following special environment variables must be set up prior to running tests:
#
#     $ export TC_USERNAME=123456
#     $ export TC_PASSWORD=password
#     $ export TC_VAULT_PASSWORD=password
#
# Run tests via rake:
#
#     $ rake test
#
# Run tests via ruby:
#
#     $ ruby test/trustcommerce_test.rb
class TrustCommerceSubscriptionTest < Test::Unit::TestCase

  def setup
    if ENV['TC_USERNAME'].nil? || ENV['TC_PASSWORD'].nil?
      puts 'TC_USERNAME and TC_PASSWORD must be set.'
      puts 'Usage: TC_USERNAME=username TC_PASSWORD=password TC_VAULT_PASSWORD=password ruby test/trustcommerce_test.rb'
      exit 1
    else
      TrustCommerce.custid         = ENV['TC_USERNAME']
      TrustCommerce.password       = ENV['TC_PASSWORD']
      TrustCommerce.vault_password = ENV['TC_VAULT_PASSWORD'] if ENV['TC_VAULT_PASSWORD']
    end
  end

  def test_subscription_create
    via_tclink_and_https do
      response = TrustCommerce::Subscription.create(
        :cc       => CARDS[:visa][:cc],
        :exp      => CARDS[:visa][:exp],
        :address1 => CARDS[:visa][:address],
        :zip      => CARDS[:visa][:zip],
        :avs      => 'y',
        :name     => 'Jennifer Smith - create() test',
        :amount   => 1200,
        :cycle    => '1m',
        :demo     => 'y'
      )
      assert_equal TrustCommerce::Result, response.class
      assert_not_nil response[:billingid]
      assert response.keys.include?(:transid)
      assert_equal 'approved', response[:status]
      assert response.approved?
    end
  end

  def test_subscription_update
    via_tclink_and_https do
      billing_id = create_subscription!('update() test')
      response = TrustCommerce::Subscription.update(
        :billingid => billing_id,
        :cc        => CARDS[:mastercard][:cc],
        :exp       => CARDS[:mastercard][:exp],
        :address1  => CARDS[:mastercard][:address],
        :zip       => CARDS[:mastercard][:zip],
        :avs       => 'y'
      )
      assert_equal 'accepted', response[:status]
      assert response.accepted?
    end
  end

  def test_subscription_delete
    via_tclink_and_https do
      billing_id = create_subscription!('delete() test')
      response = TrustCommerce::Subscription.delete(
        :billingid => billing_id
      )
      assert response.keys.include?(:transid)
      assert_equal 'accepted', response[:status]
      assert response.accepted?
    end
  end

  def test_subscription_charge_and_credit
    via_tclink_and_https do
      billing_id = create_subscription!('charge and credit() test')

      # charge
      charge_response = TrustCommerce::Subscription.charge(
        :billingid  => billing_id,
        :amount     => 1995,
        :demo       => 'y'
      )
      assert charge_response.keys.include?(:transid)
      assert_equal 'approved', charge_response[:status]
      assert charge_response.approved?

      # credit
      credit_response = TrustCommerce::Subscription.credit(
        :transid  => charge_response[:transid],
        :amount   => 995,
        :demo     => 'y'
      )
      assert credit_response.keys.include?(:transid)
      assert_equal 'accepted', credit_response[:status]
      assert credit_response.accepted?
    end
  end

  def test_subscription_query
    puts "\n"
    puts "---------------------------------------------------------------------------"
    puts "IMPORTANT: This query test will likely take between 1 and 2 minutes!"
    puts "Make sure TC_VAULT_PASSWORD is set if it differs from your TCLink password."
    puts "---------------------------------------------------------------------------"

    # create subscription
    billing_id = create_subscription!('query() test')

    # query for charges
    options = { :querytype => 'transaction', :action => 'sale', :billingid => billing_id }
    while (query_response = TrustCommerce::Subscription.query(options))
      if query_response.body =~ /error/i
        fail(query_response.body)
        break
      elsif query_response.body.split("\n").size < 2
        puts 'Transaction has not yet showed up... will try again in 15 seconds.'
        sleep(15)
      else
        puts 'Transaction found.'

        # setup index hash
        field_names = query_response.body.split("\n")[0].split(',')
        date_line_1 = query_response.body.split("\n")[1].split(',')
        indexes = field_names.inject({}) {|h, field| h[field.to_sym] = field_names.index(field); h }

        # check transaction data
        assert_equal '1111',            date_line_1[indexes[:cc]]
        assert_equal '1200',            date_line_1[indexes[:amount]]
        assert_equal 'query() test',    date_line_1[indexes[:name]]
        break
      end
    end
  end

  # test private helpers
  def test_stringify_hash
    assert_equal ({ 'a' => '1', 'b' => '2' }),  TrustCommerce.stringify_hash(:a => '1', :b => '2')
    assert_equal ({ 'a' => '1', 'b' => '2' }),  TrustCommerce.stringify_hash(:a => 1, :b => 2)
    assert_equal ({ 'a' => '2' }),              TrustCommerce.stringify_hash(:a => 1, :a => 2)
  end

  def test_symbolize_hash
    assert_equal ({ :a => '1', :b => '2' }),  TrustCommerce.symbolize_hash('a' => '1', 'b' => '2')
    assert_equal ({ :a => '1', :b => '2' }),  TrustCommerce.symbolize_hash(:a => 1, 'b' => 2)
    assert_equal 1, TrustCommerce.symbolize_hash(:a => 1, 'a' => 2).size
  end

end
