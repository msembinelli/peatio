# encoding: UTF-8
# frozen_string_literal: true
require 'csv'

# Required fields:
# - uid with format (ID1234567890)
# - email
#
# Make sure that you create required currency
# Usage: bundle exec rake import:users['file_name.csv']

namespace :import do
  desc 'Load members from csv file.'
  task :users, [:config_load_path] => [:environment] do |_, args|
    csv_table = File.read(Rails.root.join(args[:config_load_path]))
    CSV.parse(csv_table, headers: true).map do |row|
      ActiveRecord::Base.transaction do
        uid = row['uid']
        email = row['email']
        level = row.fetch('level', 1)
        role = row.fetch('role', 'member')
        state = row.fetch('state', 'active')
        member = Member.create!(uid: uid, email: email, level: level, role: role, state: state)
        Currency.all.map do |c|
          account = member.get_account(c.id)
          next unless account

          balance = row.fetch("balance_#{c.id}", 0).to_d
          locked_balance = row.fetch("locked_balance_#{c.id}", 0).to_d
          next if balance.zero? && locked_balance.zero?

          main_code, locked_code = c.coin? ? [202, 212] : [201, 211]
          Operations::Liability.create!(code: main_code, currency_id: c.id, member_id: member.id, credit: balance) unless balance.zero?
          Operations::Liability.create!(code: locked_code, currency_id: c.id, member_id: member.id, credit: locked_balance) unless locked_balance.zero?
          account.update!(balance: balance, locked: locked_balance)
        end
      end
    end
  end
end
