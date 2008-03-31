
[TrustCommerce](http://www.trustcommerce.com) is a payment gateway providing credit card
processing and recurring / subscription billing services.

This library provides a simple interface to create, edit, delete, and query subscriptions
using TrustCommerce.

== Background

TrustCommerce's recurring / subscription billing solution is implemented through a service
called [Citadel](http://www.trustcommerce.com/citadel.php).  A Citadel-enabled account is
required to use the subscription-based features implemented by this library.

=== Citadel Basics
* Citadel stores customer profiles which can include credit card information and billing frequency.
* Citadel will automatically bill customers on their respective schedules.
* Citadel identifies each customer by a Billing ID (six-character alphanumeric string).
* A customer's profile, credit card, and billing frequency can be modified using the Billing ID.

== Installation

The simple way:
  $ sudo gem install trustcommerce

Directly from repository:
  $ svn co svn://rubyforge.org/var/svn/trustcommerce/trunk trustcommerce

It is highly recommended to download and install the
[TCLink ruby extension](http://www.trustcommerce.com/tclink.php).
This extension provides failover capability and enhanced security features.
If this library is not installed, standard POST over SSL will be used.

== Configuration

When you signup for a TrustCommerce account you are issued a custid and a password.
These are your credentials when using the TrustCommerce API.

  TrustCommerce.custid   = '123456'
  TrustCommerce.password = 'topsecret'

  # optional - sets Vault password for use in query() calls
  TrustCommerce.vault_password = 'supersecure'

The password that TrustCommerce issues never changes or expires when used through the TCLink
extension.  However if you choose to use SSL over HTTP instead (the fallback option if the TCLink
library is not installed), be aware that you need to set the password to your Vault password.
Likewise, if your application uses the query() method you must set the vault_password.
The reason is that TrustCommerce currently routes these query() calls through the vault 
and therefore your password must be set accordingly.  To make matters more complicated, 
TrustCommerce currently forces you to change the Vault password every 90 days.


== Examples

=== Creating a subscription

  # Bill Jennifer $12.00 monthly
  response = TrustCommerce::Subscription.create(
    :cc     => '4111111111111111',
    :exp    => '0412',
    :name   => 'Jennifer Smith',
    :amount => 1200,
    :cycle  => '1m'
  )
  
  if response['status'] == 'approved'
    puts "Subscription created with Billing ID: #{response['billingid']}"
  else
    puts "An error occurred: #{response['error']}"
  end


=== Update a subscription

  # Update subscription to use new credit card
  response = TrustCommerce::Subscription.update(
    :billingid => 'ABC123',
    :cc        => '5411111111111115', 
    :exp       => '0412'
  )
  
  if response['status'] == 'accepted'
    puts 'Subscription updated.'
  else
    puts "An error occurred: #{response['error']}"
  end


=== Delete a subscription

  # Delete subscription
  response = TrustCommerce::Subscription.delete(
    :billingid => 'ABC123'
  )
  
  if response['status'] == 'accepted'
    puts 'Subscription removed from active use.'
  else
    puts 'An error occurred.'
  end


=== Query a subscription

  # Get all sale transactions for a subscription in CSV format
  response = TrustCommerce::Subscription.query(
    :querytype => 'transaction',
    :action    => 'sale',
    :billingid => 'ABC123'
  )


=== Process a one-time charge

  # Process one-time sale against existing subscription
  response = TrustCommerce::Subscription.charge(
    :billingid => 'ABC123',
    :amount    => 1995
  )


=== Credit a transaction

  # Process one-time credit against existing transaction
  response = TrustCommerce::Subscription.credit(
    :transid => '001-0000111101',
    :amount  => 1995
  )


== Running the tests

The following special environment variables must be set up prior to running tests:

  $ export TC_USERNAME=123456
  $ export TC_PASSWORD=password
  $ export TC_VAULT_PASSWORD=password

Run tests via rake:

  $ rake test

Run tests via ruby:

  $ ruby test/trustcommerce_test.rb

