#!/usr/bin/env ruby
# frozen_string_literal: true

require 'net/imap'
require 'openssl'
require 'date'
require 'colorize'

# Replace the placeholders below with your real credentials
gmail_username = "blain@reduceworkerscompensationcosts.com"
app_password   = "<write the app password here>"

# Connect to Gmail's IMAP server (port 993 with SSL)
imap = Net::IMAP.new('imap.gmail.com', port: 993, ssl: { verify_mode: OpenSSL::SSL::VERIFY_NONE })

begin
  # Log in using your Gmail address and app password
  imap.login(gmail_username, app_password)
  puts "Logged in successfully."

  # Select the [Gmail]/Sent Mail folder to retrieve sent messages
  # Depending on language settings, it might be named "Sent", "Enviados", etc.
  # but typically "[Gmail]/Sent Mail" works for English-language Gmail accounts.
  imap.select('[Gmail]/Sent Mail')

  # Search for messages that do NOT have "9AVVR28" in the subject
  # Note: "NOT SUBJECT 9AVVR28" will exclude any subject containing "9AVVR28"
  message_ids = imap.search(["NOT", "SUBJECT", "9AVVR28"]).sort.reverse

  puts "Found #{message_ids.size} email(s) without the keyword '9AVVR28' in the subject."

  # Fetch each message's envelope (contains basic header info, including subject)
  # and print out the subjects
  message_ids.each do |msg_id|
    envelope = imap.fetch(msg_id, "ENVELOPE")[0].attr["ENVELOPE"]

    recipient_emails = envelope.to.map do |recipient|
      "#{recipient.mailbox}@#{recipient.host}"
    end.join(", ")

    parsed_date = DateTime.parse(envelope.date)  # Parse the envelope.date string

    puts "UID: #{msg_id.to_s.blue} | Date: #{parsed_date.strftime('%Y-%m-%d').to_s.blue} | To: #{recipient_emails.to_s.blue} | Subject: #{envelope.subject.to_s.blue}"
  end

rescue Net::IMAP::NoResponseError => e
  puts "IMAP NoResponseError: #{e.message}"
rescue Net::IMAP::ByeResponseError => e
  puts "IMAP ByeResponseError: #{e.message}"
rescue StandardError => e
  puts "An error occurred: #{e.message}"
ensure
  # Log out and disconnect to clean up the connection
  imap.logout
  imap.disconnect
  puts "Logged out and disconnected from the server."
end
