require 'json'
require "sinatra"
require 'active_support/all'
require "active_support/core_ext"
require 'sinatra/activerecord'
require 'rake'

require 'twilio-ruby'

set :database, "sqlite3:db/bab-e.db"

require_relative './models/bottle'
require_relative './models/breast'
require_relative './models/diaper'
require_relative './models/pumping'
require_relative './models/user'

# Load environment variables using Dotenv. If a .env file exists, it will
# set environment variables from that file (useful for dev environments)
configure :development do
  require 'dotenv'
  Dotenv.load
end

# enable sessions for this project

enable :sessions

# First you'll need to visit Twillio and create an account 
# you'll need to know 
# 1) your phone number 
# 2) your Account SID (on the console home page)
# 3) your Account Auth Token (on the console home page)
# then add these to the .env file 
# and use 
#   heroku config:set TWILIO_ACCOUNT_SID=XXXXX 
# for each environment variable

#client = Twilio::REST::Client.new ENV["TWILIO_ACCOUNT_SID"], ENV["TWILIO_AUTH_TOKEN"]


# Hook this up to your Webhook for SMS/MMS through the console

get '/send_sms' do
    client.account.messages.create(
  :from => ENV["TWILIO_NUMBER"],
  :to => "+14129154421",
  :body => "Hello. You can talk to me to log your baby's daily activities")
  "Message sent"
end



get '/incoming_sms' do
    
    session["last_context"] ||= nil

    sender = params[:From] || ""
    body = params[:Body] || ""
    body = body.downcase.strip
    
    #Receive "breast feeding"
    if body == "breast"
        message = "Okay, which side is she breast feeding on?"
        session["last_context"] = "breast_side"

    elsif session["last_context"] == "breast_side" 
        
        side = body
        # add some validation to check the side is left or right later
        
        #create the object
        breast = Breast.create( side: "body" ) 
        #add the current time to the start time column
        # this should be a datetime type
        breast.start = Time.now
        # save it and update the database with the change
        breast.save
        message = "Great, I started the timer. Text 'end' when she stops feeding"

        session["last_context"] = "feeding_timer"
        
    elsif session["last_context"] == "feeding_timer" and body == "end" 
        #create the object
        # search for the records in the database that match the side
        # and haven't got a stop time
        breast = Breast.where( end: nil ).first
        # you might also want to add a little more to check a time range
        # e.g. you don't want to update it if its from yesterday, etc.
        # check we have something in the database 
        # i.e. we've got an object to work with 
        unless breast.nil? 
            breast.end = Time.now
              # save it and update the database with the change
            breast.save
            duration = (breast.end - breast.start)/60
            message = "I updated that. You pumped for #{duration} minutes"
            session = ["last_context"] == "feeding_quality"
    elsif session["last_context"] == "feeding_quality"
            
        breast = Breast.where( quality: nil).first
        
        unless breast.nil?
            breast.quality =  "body"
            breast.save
            message = "Great, I logged that she fed for #{duration} minutes and the experienc was rated #{body}"          
          else
            message = "Sorry. I couldn't do that. I don't think the timer was started."
          end 
        else  
         #... 
        end
    #begin t.timer on the "breast feeding" table
    #ask back "Ok, I started the timer. Which is ___ starting on?"
    #Receive (left,right,both)
    #add (left,right,both) to the "side" column
    #return "Great, let me know when ___ stops feeding"
    
    #Receive "end"
    #update t.timer on the "breast feeding" table
    #return "Great, time is logged. How would you rate this feeding from 1 being bad to 10 being great"
    #receive (1~10)
    #add (1~10) to the "quality" column
    #return "Awesome, I've logged that ___ fed for ___ minutes starting on ___ and that it was a ___ experience"
    
    #Receive "pumping"
    #begin t.timer on the "pumping" table
    #ask "Ok, I begin the stopwatch. Which side are you starting on?"
    #Receive (left,right)
    #add (left,right) to the "side" column
    #return "Ok, you started pumping on your (left,right) side. Let me know if you stop pumping or switch sides"
    
    #receive "switch"
    #beging t.timer add (left,right) to the "side" column
    #return "Great, I noted that you switched sides"
    
    #receive "end"
    #update t.timer
    #Return "Awesome, how much did you pump?"
    #receive (___)
    #add (___) to the "quantity" column
    #return "great, I logged your last pumping at ___ on ___. You pumped ___ which is (good,great)"
    
    #Receive "diaper change"
    #beging t.timer on the "diaper" table
    #return "Ok, what did she have in the diaper?"
    #receive "(pee,poo,both)"
    #add (pee,poo,both) to the "type" column
    #return "Great, I've logged that ___ had a ___ at ___"
    
end