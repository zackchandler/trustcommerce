#
# This agent will pull down recent transactions from the TrustCommerce vault using the
# following schema: 
#
#   create_table :subscriptions do |t|
#     t.column :account_id,                :integer,   :null => false
#     t.column :created_on,                :datetime,  :null => false
#     t.column :billing_id,                :string
#     t.column :length,                    :integer,   :null => false
#     t.column :cents,                     :integer,   :null => false
#     t.column :billing_full_name,         :string
#     t.column :billing_address,           :string
#     t.column :billing_zip_code,          :string
#     t.column :billing_country,           :string
#     t.column :billing_card_type,         :string
#     t.column :billing_credit_card,       :string
#     t.column :billing_expiration_date,   :datetime   
#   end
#   
#   add_index :subscriptions, :account_id
#   
#   create_table :subscription_transactions do |t|
#     t.column :subscription_id,          :integer,   :null => false
#     t.column :account_id,               :integer,   :null => false
#     t.column :transaction_date,         :datetime,  :null => false
#     t.column :transaction_id,           :string,    :null => false
#     t.column :transaction_type,         :string,    :null => false
#     t.column :amount,                   :decimal,   :null => false
#     t.column :card_number,              :string,    :null => false
#     t.column :card_type,                :string,    :null => false
#     t.column :cardholder_name,          :string,    :null => false     
#   end
#   
#   add_index :subscription_transactions, :subscription_id
#   add_index :subscription_transactions, :account_id
#
#   Install as cron job or test it out on the console:
#
# $ ./script/runner -e production "TrustcommerceSyncAgent.sync('3h')"
#
class TrustcommerceSyncAgent
  
  # time_ago examples: 
  #   30m => 30 minutes
  #   1h  => 1 hour
  #   3d  => 3 days
  def self.sync(time_ago = nil)
    time = case time_ago
      when /^(\d+)m$/ then Time.now.utc - $1.to_i.minute
      when /^(\d+)h$/ then Time.now.utc - $1.to_i.hour
      when /^(\d+)d$/ then Time.now.utc - $1.to_i.day
      else Time.now.utc - 1.hour
    end
    # --- [ find recently created paying subscriptions ] ---
    subscriptions = Subscription.find(:all, :conditions => ['cents > 0 AND created_on > ?', time])
    subscriptions.each do |subscription|
      sync_subscription(subscription)
    end
  end

  private  

    def self.sync_subscription(subscription)
        
      # --- [ get TC data ] ---
      tc = TrustCommerce::Subscription.query(
        :querytype  => 'transaction',
        :billingid  => subscription.billing_id
      )      
      return if !tc.kind_of? Net::HTTPOK

      # --- [ create index by CSV header ]
      field_names = tc.body.split("\n")[0].split(',')
      indexes = field_names.inject({}) {|h, field| h[field.to_sym] = field_names.index(field); h }

      # --- [ build transaction array ] ---
      transactions = tc.body.split("\n")
      transactions.shift # get rid of header

      transactions.each do |line|
        transaction = line.split(',')

        #log_transaction(indexes, transaction)
      
        subscription_transaction = subscription.transactions.find_by_transaction_id(transaction[indexes[:transid]])
        if subscription_transaction.nil?
          SubscriptionTransaction.create(
            :subscription_id    => subscription.id,
            :account_id         => subscription.account_id,
            :transaction_date   => convert_date(transaction[indexes[:trans_date]]),
            :transaction_id     => transaction[indexes[:transid]],
            :transaction_type   => transaction[indexes[:action_name]],
            :amount             => transaction[indexes[:bank_amount]],
            :card_number        => transaction[indexes[:cc]],
            :card_type          => convert_card_type(transaction[indexes[:media_name]]),
            :cardholder_name    => transaction[indexes[:name]]
          )
        end      
      end
    
    end

    # TC returns mm-dd-yyyy HH:mm:ss
    def self.convert_date(str)
      date = str.split(' ')[0].split('-')
      Time.local(date[2], date[0], date[1])
    end
  
    # TC returns VISA-D, MC-D, AMEX-D
    def self.convert_card_type(str)
      case str
        when /VISA/i  then 'Visa'
        when /MC/i    then 'MasterCard'
        when /AMEX/i  then 'American Express'
        else str
      end
    end
    
    # --- [ helpful for debugging ] ---
    def self.log_transaction(indexes, transaction)
      puts '---------- transaction --------------------'
      indexes.each{|k,v| puts "#{k} => #{transaction[indexes[k]]}" if !transaction[indexes[k]].blank? }
      puts '-------------------------------------------'
    end
    
end