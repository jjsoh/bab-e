require 'json'
require "sinatra"
require 'active_support/all'
require "active_support/core_ext"
require 'sinatra/activerecord'
require 'rake'
require 'active_support/core_ext/time'
require 'time'

require 'twilio-ruby'

require 'alexa_skills_ruby'
require 'httparty'
require 'haml'
require 'iso8601'

# set :database, "sqlite3:db/bab-e.db"

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

get '/' do
  @status = StatusUpdate.order( created_at: 'DESC' ).first
  haml :index
end

post '/' do
  content_type :json

  handler = CustomHandler.new(application_id: ENV['APPLICATION_ID'], logger: logger)

  begin
    handler.handle(request.body.read)
  rescue AlexaSkillsRuby::InvalidApplicationId => e
    logger.error e.to_s
    403
  end

end

class CustomHandler < AlexaSkillsRuby::Handler

    on_intent("Setup") do
        response.set_output_speech_text("Welcome, what is your first name?")
    end
            
    on_intent("SetupFirstName") do
            user = User.new
            user.fname = request.intent.slots["fname"]
            user.save
            response.set_output_speech_text("Your first name is #{user.fname}. What is your last name?")
            #Add confirmation
    end
    
    on_intent("SetupLastName") do
            user = User.last
            user.lname = request.intent.slots["lname"]
            user.save
            response.set_output_speech_text("Your last name is #{user.lname}. What is your baby's name?")
    end
    
    on_intent("SetupBabyName") do
            user = User.last
            user.bname = request.intent.slots["bname"]
            user.save
            response.set_output_speech_text("Your baby's name is #{user.bname}. What is the baby's gender?")
    end

    on_intent("SetupBabyGender") do
            user = User.last
            gender = request.intent.slots["gender"]
            if gender == "girl"
                user.gender = 1
                user.save
                response.set_output_speech_text("Your baby is a girl. Please set your password.")
                
                elsif gender == "boy"
                user.gender = 2
                user.save
                response.set_output_speech_text("Your baby is a boy. Please set your password.")
            end
    end
       
    on_intent("SetupPassword") do
            user = User.last
            user.password = request.intent.slots["password"]
            user.save
            if user.gender == 1
                gender = "girl"
                pronoun = "she"
                
                elsif user.gender == 2
                gender = "boy"
                pronoun = "he"
            end
            #add check
            response.set_output_speech_text("Great, you are all set. Your name is #{user.fname} #{user.lname}. Your baby's name is #{user.bname} and #{pronoun} is a #{gender}.")
    end

#=====================================BREAST FEEDING MODULE =====================================  
    
    on_intent("BeginBreastFeeding") do
        response.set_output_speech_text("Okay, which side is she breast feeding on?")
    end
    
    on_intent("SetBreastSide") do
        user = User.last
            if user.gender == 1
                gender = "girl"
                pronoun = "she"
                
                elsif user.gender == 2
                gender = "boy"
                pronoun = "he"
            end
        side = request.intent.slots["side"]
        # add some validation to check the side is left or right later
        #create the object
        breast = Breast.new
        #add the current time to the start time column
        # this should be a datetime type
        breast.side = side
        t = Time.now
        breast.start = t + Time.zone_offset('EST')
        # save it and update the database with the change
        breast.save

        response.set_output_speech_text("Great, I started the timer for the #{side} side. Text 'done' when #{pronoun} stops feeding")
    end
    
    on_intent("EndBreastFeeding") do
        user = User.last
            if user.gender == 1
                gender = "girl"
                pronoun = "she"
                
                elsif user.gender == 2
                gender = "boy"
                pronoun = "he"
            end
        #create the object
        # search for the records in the database that match the side
        # and haven't got a stop time
        breast = Breast.where( end: nil ).first
        # you might also want to add a little more to check a time range
        # e.g. you don't want to update it if its from yesterday, etc.
        # check we have something in the database 
        # i.e. we've got an object to work with 
        unless breast.nil? 
            t = Time.now
            breast.end = t + Time.zone_offset('EST')
              # save it and update the database with the change
            breast.save
            minutes = (breast.end - breast.start)/60
            duration = minutes.round
        end 
        response.set_output_speech_text("I updated that. #{user.bname} fed for #{duration} minutes. How would you rate the quality of the experience from 1 being bad to 10 being great?")
    end
    
    on_intent("BreastFeedingQuality") do
        user = User.last
            if user.gender == 1
                gender = "girl"
                pronoun = "she"
                
                elsif user.gender == 2
                gender = "boy"
                pronoun = "he"
            end
        
        quality = request.intent.slots["rating"]
        
        breast = Breast.where( quality: nil).first
        
        unless breast.nil?
            breast.quality = quality
            breast.save
            side = breast.side
            minutes = (breast.end - breast.start)/60
            duration = minutes.round
            response.set_output_speech_text("Great, I logged that #{pronoun} fed for #{duration} minutes on the #{side} and the experience was rated #{breast.quality}")
        end
    end

    
#================================== BOTTLE FEEDING MODULE =====================================    
    on_intent("BeginBottleFeeding") do
        user = User.last
            if user.gender == 1
                gender = "girl"
                pronoun = "she"
                
                elsif user.gender == 2
                gender = "boy"
                pronoun = "he"
            end
        
        bottle = Bottle.new
        t = Time.now
        bottle.start = t + Time.zone_offset('EST')
        bottle.save
        
        response.set_output_speech_text("Okay, I will begin the timer. How much is #{pronoun} being fed?")
    end
    
    on_intent("BottleAmount") do
        user = User.last
            if user.gender == 1
                gender = "girl"
                pronoun = "she"
                
                elsif user.gender == 2
                gender = "boy"
                pronoun = "he"
            end
        
        bottle = Bottle.last
        
        unless bottle.nil?
            bottle.amount = request.intent.slots["amount"]
            bottle.save!
        end
        
        response.set_output_speech_text("Great, she's feeding #{bottle.amount}oz of milk. Say 'done' when #{pronoun} stops feeding.")
    end
    
    on_intent("EndBottleFeeding") do
        bottle = Bottle.last
        t = Time.now
        bottle.end = t + Time.zone_offset('EST')
        bottle.save
        
            user = User.last
            if user.gender == 1
                gender = "girl"
                pronoun = "she"
                
                elsif user.gender == 2
                gender = "boy"
                pronoun = "he"
            end
        
        unless bottle.nil?
            minutes = (bottle.end - bottle.start)/60
            duration = minutes.round
        
            quantity = bottle.amount
        
            response.set_output_speech_text("Ok, #{pronoun} fed for #{duration} minutes. #{user.bname} drank #{quantity}ounce of milk.")
        end
    end
    
#================================== FEEDING QUERY =====================================    
    
    on_intent("LastFeeding") do
        breast = Breast.last
        bottle = Bottle.last
        
        if breast.end > bottle.end
            time = breast.start.strftime( "%A %e at %l:%M:%P" )
            side = breast.side
            minutes = (breast.end - breast.start)/60
            duration = minutes.round
            quality = breast.quality
            
            user = User.last
            if user.gender == 1
                gender = "girl"
                pronoun = "she"
                
                elsif user.gender == 2
                gender = "boy"
                pronoun = "he"
            end
        
        response.set_output_speech_text("#{user.bname} was breast fed on #{side} side at #{time} for #{duration} minutes. The experience was rated #{quality}")  
        
        elsif bottle.end > breast.end
            time = bottle.start.strftime( "%A %e at %l:%M:%P" )
            amount = bottle.amount
            minutes = (bottle.end - bottle.start)/60
            duration = minutes.round
            
            user = User.last
            if user.gender == 1
                gender = "girl"
                pronoun = "she"
                
                elsif user.gender == 2
                gender = "boy"
                pronoun = "he"
            end
            
        response.set_output_speech_text("#{user.bname} was bottle fed with #{amount}oz at #{time} for #{duration} minutes." )        
        end
    end

#===================================== PUMPING MODULE =====================================    
    on_intent("BeginPumping") do
        pumping = Pumping.new
        t = Time.now
        pumping.start = t + Time.zone_offset('EST')
        pumping.save
        response.set_output_speech_text("Great, what side are you starting the pump on?")
    end
    
    on_intent("PumpingSide") do
            pumping = Pumping.last
            pumping.side = request.intent.slots["side"]
            pumping.save
            response.set_output_speech_text("ok, I've recorderd that you are pumping on the #{pumping.side}. Let me know when you finish by saying 'done'.")        
    end
    
    on_intent("EndPumping") do
            pumping = Pumping.last
            t = Time.now
            pumping.end = t + Time.zone_offset('EST')
            pumping.save
                unless pumping.nil?
                    minutes = (pumping.end - pumping.start)/60
                    duration = minutes.round
                    response.set_output_speech_text("Ok, you pumped on the #{pumping.side} for #{duration}. How much did you end up pumping?")             
                end
    end
    
    on_intent("PumpingAmount") do
        pumping = Pumping.last
            pumping.amount = request.intent.slots["amount"]
            pumping.save
                unless pumping.nil?
                    minutes = (pumping.end - pumping.start)/60
                    duration = minutes.round
                    response.set_output_speech_text("Great job, you pumped for #{duration} minutes on the #{pumping.side} side. You pumped #{pumping.amount}ounces.")
                end
    end
    
    on_intent("LastPumping") do
        pumping = Pumping.last
            unless pumping.nil?
                    minutes = (pumping.end - pumping.start)/60
                    duration = minutes.round
                    response.set_output_speech_text("You pumped for #{duration} minutes on the #{pumping.side} side. You pumped #{pumping.amount}oz.")
            end
    end

#===================================== DIAPER LIST =====================================    
    on_intent("DiaperChange") do
        user = User.last
        
        diaper = Diaper.new
        t = Time.now
        diaper.start = t + Time.zone_offset('EST')
        diaper.save
        response.set_output_speech_text("Ok, what did #{user.bname} have in the diaper?")
    end
    
    on_intent("DiaperType") do
        diaper = Diaper.last
        time = diaper.start.strftime ( "%A %e at %l:%M:%P" )
        diaper.save
        body = request.intent.slots["type"]
        
            if body == "pee"
                user = User.last
                    if user.gender == 1
                        gender = "girl"
                        pronoun = "she"

                        elsif user.gender == 2
                        gender = "boy"
                        pronoun = "he"
                    end

                diaper.dtype = "1"
                diaper.save
                response.set_output_speech_text("Great, I logged that #{pronoun} had pee diaper at #{time}.")

                elsif body == "poo"
                    user = User.last
                        if user.gender == 1
                            gender = "girl"
                            pronoun = "she"

                            elsif user.gender == 2
                            gender = "boy"
                            pronoun = "he"
                        end
                
                diaper.dtype = "2"
                diaper.save
                response.set_output_speech_text("Great, I logged that #{pronoun} had poo diaper at #{time}.")

                elsif body == "both"
                    user = User.last
                    if user.gender == 1
                        gender = "girl"
                        pronoun = "she"

                        elsif user.gender == 2
                        gender = "boy"
                        pronoun = "he"
                    end
                    
                diaper.dtype = "3"
                diaper.save
                response.set_output_speech_text("Great, I logged that #{pronoun} had diaper with both types at #{time}.")
            end
    end
    
    on_intent("LastDiaper") do
       diaper = Diaper.last
        user = User.last
        time = diaper.start.strftime ( "%A %e at %l:%M:%P" )
        
        if diaper.dtype == 1
            response.set_output_speech_text("#{user.bname} had a pee diaper at #{time}.")
            
            elsif diaper.dtype == 2
            response.set_output_speech_text("#{user.bname} had a poo diaper at #{time}.")
            
            elsif diaper.dtype == 3
            response.set_output_speech_text("#{user.bname} had a with both at #{time}.")
        end
    end
    
end

##=====================================BREAST FEEDING MODULE =====================================  
#    if body == "breast list"
#         message = Breast.all.to_json
#    end    
#        
#    
##================================== BOTTLE FEEDING MODULE ===================================== 
#    if body == "bottle list"
#        message = Bottle.all.to_json
#    end    
#
##===================================== PUMPING MODULE =====================================

##===================================== DIAPER LIST =====================================
#    if body == "diaper list"
#        message = Diaper.all.to_json
#    end
#    
#    
##===================================== DETELE ALL =====================================
#    if body == "delete all"
#        message = "Are you sure you want to delete all record? This is not reversible"
#        
#        elsif body == "yes"
#            Bottle.delete_all
#            Breast.delete_all
#            message = "Ok, I've reset all database"
#        
#        elsif body == "no"
#            message = "Ok, nothing has been changed"
#    end
#
##===================================== TWILIO APP SETUP =====================================  
#  twiml = Twilio::TwiML::Response.new do |resp|
#    resp.Message message
#  end
#    
#  return twiml.text
#end