require 'chromedriver-helper'
require 'selenium-webdriver'
require 'highline'

module ElementExtensions
  def set_text(text)
    clear
    send_keys(text)
  end
end
class ::Selenium::WebDriver::Element
  prepend ElementExtensions
end

cli = HighLine.new
username = cli.ask('Enter username: ') { |q| q.default = 'rikbrown88' }
password = cli.ask('Enter password: ') { |q| q.echo = false }
payer_id = cli.ask('Enter payer ID: ') { |q| q.default = '146677665' }
payment_amount = cli.ask('Enter payment amount: ') { |q| q.validate = /^(\d+)(\.\d{1,2})?$/ }

driver = Selenium::WebDriver.for :chrome
wait = Selenium::WebDriver::Wait.new(timeout: 120) # seconds

# Login
driver.navigate.to 'https://client.schwab.com/Login/SignOn/CustomerCenterLogin.aspx?sp=19005'
driver.switch_to.frame wait.until { driver.find_element(css: '#iframeWrapper>iframe') }
driver.find_element(id: 'LoginId').set_text(username)
driver.find_element(id: 'Password').set_text(password)
driver.find_element(id: 'LoginSubmitBtn').click

# SMS me please
wait.until { driver.find_element(id: 'SmsId') }.click
driver.find_element(id: 'Submit').click

# Wait for (manual) login completion
wait.until { driver.current_url.include? 'DeviceTag/Success' }
wait.until { driver.find_element(id: 'Submit') }.click
wait.until { driver.current_url.include? 'accounts/summary' }

# Go to Billpay
driver.navigate.to 'https://client.schwab.com/Accounts/TransfersAndPayments/Paybills.aspx'
wait.until { driver.find_element(id: 'ctl00_wpm_PayBillsID_PayBills_lnkBankContinue') }.click

# Fill in the payment row
wait.until { driver.find_element(css: "input[value='#{payer_id}']").find_element(xpath: '..') }.tap do |hoa_row|
  hoa_row.find_element(class_name: 'make-payment-amount').set_text payment_amount # set payment amount
end

# Validate payment total
raise "Payment total mismatch" unless driver.find_element(css: '.running-total #dispAmount').text == payment_amount

# Submit payment
driver.find_element(id: 'makePayments').click

# Add memo
wait.until { driver.find_element(name: 'PaymentsToMake[0].Memo') }.set_text '#5'
driver.find_element(id: 'submitPaymentsButton').click

# Wait until confirm
if cli.agree('Is this OK?')
  # Log out
  wait.until { driver.find_element(id: 'paymentComplete-paymentSuccess-wrapper') }
  driver.find_element(css: '.sign-out>.internal-link.btn').click
  wait.until { driver.find_element(class_name: 'lo-main-content') }
else
  cli.say("I'll wait.")
  wait.until { false }
end

driver.quit
