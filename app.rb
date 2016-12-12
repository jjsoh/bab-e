require 'json'
require "sinatra"
require 'active_support/all'
require "active_support/core_ext"
require 'sinatra/activerecord'
require 'rake'
require 'active_support/core_ext/time'

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

  handler = CustomHandler.new(application_id: ENV['ALEXA_APPLICATION_ID'], logger: logger)

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
            user.fname = request.intent.slots
            user.save
            response.set_output_speech_text("Your first name is #{user.fname}. What is your last name?")
            #Add confirmation
    end
    
    on_intent("SetupLastName") do
            user = User.last
            user.lname = lname
            user.save
            response.set_output_speech_text("Your last name is #{user.lname}. What is your baby's name?")
    end
    
    on_intent("SetupBabyName") do
            user = User.last
            user.bname = bname
            user.save
            response.set_output_speech_text("Your baby's name is #{user.bname}. What is the baby's gender?")
    end

    on_intent("SetupBabyGender") do
            user = User.last
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
            user.password = password
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

end


#
#get '/incoming_sms' do
#    
#    session["last_context"] ||= nil
#    
#    puts "Session is #{session["last_context"]}"
#    
#    sender = params[:From] || ""
#    body = params[:Body] || ""
#    body = body.downcase.strip
#    
##================================== USER SETUP ===================================== 
#    if body == "setup"
#        message = "Welcome, what is your first name?"
#        session["last_context"] = "first_name"
#        
#        elsif session["last_context"] == "first_name"
#            user = User.new
#            user.fname = body
#            user.save
#            message = "Your first name is #{user.fname}. What is your last name?"
#            #Add confirmation
#            session["last_context"] = "last_name"
#        
#        elsif session["last_context"] == "last_name"
#            user = User.last
#            user.lname = body
#            user.save
#            message = "Your last name is #{user.lname}. What is your baby's name?"
#            session["last_context"] = "baby_name"
#        elsif session["last_context"] == "baby_name"
#            user = User.last
#            user.bname = body
#            user.save
#            message = "Your baby's name is #{user.bname}. What is the baby's gender?"
#            session["last_context"] = "baby_gender"
#        elsif session["last_context"] == "baby_gender"
#            user = User.last
#            if body == "girl"
#                user.gender = 1
#                user.save
#                message = "Your baby is a girl. Please set your password."
#                
#                elsif body == "boy"
#                user.gender = 2
#                user.save
#                message = "Your baby is a body. Please set your password."
#            end
#        session["last_context"] = "password"
#        
#        elsif session["last_context"] == "password"
#            user = User.last
#            user.password = body
#            user.save
#            if user.gender == 1
#                gender = "girl"
#                pronoun = "she"
#                
#                elsif user.gender == 2
#                gender = "boy"
#                pronoun = "he"
#            end
#            #add check
#            message = "Great, you are all set. Your name is #{user.fname} #{user.lname}. Your baby's name is #{user.bname} and #{pronoun} is a #{gender}."
#    end
#    
#    
##=====================================BREAST FEEDING MODULE =====================================  
#    #Receive "breast feeding"
#    if body == "breast"
#        message = "Okay, which side is she breast feeding on?"
#        session["last_context"] = "breast_side"
#
#    elsif session["last_context"] == "breast_side" and body != "right" || body != "left"
#        user = User.last
#            if user.gender == 1
#                gender = "girl"
#                pronoun = "she"
#                
#                elsif user.gender == 2
#                gender = "boy"
#                pronoun = "he"
#            end
#        side = body
#        # add some validation to check the side is left or right later
#        #create the object
#        breast = Breast.new
#        #add the current time to the start time column
#        # this should be a datetime type
#        breast.side = side
#        breast.start = Time.now.in_time_zone("Eastern Time (US & Canada)")
#        # save it and update the database with the change
#        breast.save
#
#        message = "Great, I started the timer for the #{side} side. Text 'done' when #{pronoun} stops feeding"
#
#        session["last_context"] = "feeding_timer"
#            
#    elsif session["last_context"] == "feeding_timer" and body == "done" 
#            user = User.last
#            if user.gender == 1
#                gender = "girl"
#                pronoun = "she"
#                
#                elsif user.gender == 2
#                gender = "boy"
#                pronoun = "he"
#            end
#        #create the object
#        # search for the records in the database that match the side
#        # and haven't got a stop time
#        breast = Breast.where( end: nil ).first
#        # you might also want to add a little more to check a time range
#        # e.g. you don't want to update it if its from yesterday, etc.
#        # check we have something in the database 
#        # i.e. we've got an object to work with 
#        unless breast.nil? 
#            breast.end = Time.now.in_time_zone("Eastern Time (US & Canada)")
#              # save it and update the database with the change
#            breast.save
#            minutes = (breast.end - breast.start)/60
#            duration = minutes.round
#        end 
#        message = "I updated that. #{user.bname} fed for #{duration} minutes. How would you rate the quality of the experience from 1 being bad to 10 being great?"
#        session["last_context"] = "feeding_quality"
#        
#    elsif session["last_context"] == "feeding_quality" and body.to_i > 0 
#        user = User.last
#            if user.gender == 1
#                gender = "girl"
#                pronoun = "she"
#                
#                elsif user.gender == 2
#                gender = "boy"
#                pronoun = "he"
#            end
#        
#        quality = body.to_i
#        
#        breast = Breast.where( quality: nil).first
#        
#        unless breast.nil?
#            breast.quality = quality
#            breast.save
#            side = breast.side
#            minutes = (breast.end - breast.start)/60
#            duration = minutes.round
#            message = "Great, I logged that #{pronoun} fed for #{duration} minutes on the #{side} and the experience was rated #{breast.quality}"          
#          else
#            message = "Sorry. I couldn't do that. I don't think the timer was started."
#          end 
#        else  
#         #... 
#        end
#    
#    if body == "breast list"
#         message = Breast.all.to_json
#    end    
#        
#    
##================================== BOTTLE FEEDING MODULE =====================================   
#    if body == "bottle"
#        user = User.last
#            if user.gender == 1
#                gender = "girl"
#                pronoun = "she"
#                
#                elsif user.gender == 2
#                gender = "boy"
#                pronoun = "he"
#            end
#        
#        bottle = Bottle.new
#        bottle.start = Time.now
#        bottle.save
#        
#        message = "Okay, I will begin the timer. How much is #{pronoun} being fed?"
#        
#        session["last_context"] = "bottle_quantity"
#
#    elsif session["last_context"] == "bottle_quantity" and body.to_i > 0
#        quantity = body.to_i
#        
#        user = User.last
#            if user.gender == 1
#                gender = "girl"
#                pronoun = "she"
#                
#                elsif user.gender == 2
#                gender = "boy"
#                pronoun = "he"
#            end
#        
#        bottle = Bottle.last
#        
#        unless bottle.nil?
#            bottle.amount = quantity
#            bottle.save!
#        end
#        
#        message = "Great, she's feeding #{bottle.amount}oz of milk. Say 'done' when #{pronoun} stops feeding."
#        session["last_context"] = "feeding_duration"
#
#    elsif session["last_context"] == "feeding_duration" and body == "done"
#        
#        bottle = Bottle.last
#        bottle.end = Time.now
#        bottle.save
#        
#            user = User.last
#            if user.gender == 1
#                gender = "girl"
#                pronoun = "she"
#                
#                elsif user.gender == 2
#                gender = "boy"
#                pronoun = "he"
#            end
#        
#        unless bottle.nil?
#            minutes = (bottle.end - bottle.start)/60
#            duration = minutes.round
#        
#            quantity = bottle.amount
#        
#            message = "Ok, #{pronoun} fed for #{duration} minutes. #{user.bname} drank #{quantity}oz of milk."
#        end
#    end
#
#    if body == "bottle list"
#        message = Bottle.all.to_json
#    end    
#
##===================================== FEEDING QUERY MODULE =====================================
#    if body == "last feeding"
#        breast = Breast.last
#        bottle = Bottle.last
#        
#        
#        if breast.end > bottle.end
#            time = breast.start.strftime( "%A %e at %l:%M:%P" )
#            side = breast.side
#            minutes = (breast.end - breast.start)/60
#            duration = minutes.round
#            quality = breast.quality
#            
#            user = User.last
#            if user.gender == 1
#                gender = "girl"
#                pronoun = "she"
#                
#                elsif user.gender == 2
#                gender = "boy"
#                pronoun = "he"
#            end
#        
#        message = "#{user.bname} was breast fed on #{side} side at #{time} for #{duration} minutes. The experience was rated #{quality}"  
#        
#        elsif bottle.end > breast.end
#            time = bottle.start.strftime( "%A %e at %l:%M:%P" )
#            amount = bottle.amount
#            minutes = (bottle.end - bottle.start)/60
#            duration = minutes.round
#            
#            user = User.last
#            if user.gender == 1
#                gender = "girl"
#                pronoun = "she"
#                
#                elsif user.gender == 2
#                gender = "boy"
#                pronoun = "he"
#            end
#            
#        message = "#{user.bname} was bottle fed with #{amount}oz at #{time} for #{duration} minutes."  
#            
#        end
#
#    end
#
##===================================== PUMPING MODULE =====================================
#    
#    if body == "pumping"
#        pumping = Pumping.new
#        pumping.start = Time.now
#        pumping.save
#        message = "what side are you pumping on?"
#        
#        session["last_context"] = "pumping_side"
#            
#        elsif session["last_context"] == "pumping_side"
#            pumping = Pumping.last
#            pumping.side = body
#            pumping.save
#            message = "ok, I've recorderd that you are pumping on the #{pumping.side}. Let me know when you finish by saying 'done'."
#
#        session["last_context"] = "pumping_end"
#        
#        elsif session["last_context"] == "pumping_end" and body == "done"
#            pumping = Pumping.last
#            pumping.end = Time.now
#            pumping.save
#                unless pumping.nil?
#                    minutes = (pumping.end - pumping.start)/60
#                    duration = minutes.round
#                    message = "Ok, you pumped on the #{pumping.side} for #{duration}. How much did you end up pumping?"             
#                end
#            session["last_context"] = "pumping_amount"
#        
#        elsif session["last_context"] == "pumping_amount"
#            pumping = Pumping.last
#            pumping.amount = body.to_i
#            pumping.save
#                unless pumping.nil?
#                    minutes = (pumping.end - pumping.start)/60
#                    duration = minutes.round
#                    message = "Great job, you pumped for #{duration} minutes on the #{pumping.side} side. You pumped #{pumping.amount}oz."
#                end
#    end
#    
#    if body == "last pumping"
#        pumping = Pumping.last
#            unless pumping.nil?
#                    minutes = (pumping.end - pumping.start)/60
#                    duration = minutes.round
#                    message = "You pumped for #{duration} minutes on the #{pumping.side} side. You pumped #{pumping.amount}oz."
#                end
#    end
#
#    
##===================================== DIAPER LIST =====================================
#    
#    if body == "diaper"
#        user = User.last
#            if user.gender == 1
#                gender = "girl"
#                pronoun = "she"
#                
#                elsif user.gender == 2
#                gender = "boy"
#                pronoun = "he"
#            end
#        
#        diaper = Diaper.new
#        diaper.start = Time.now
#        diaper.save
#        message = "Ok, what did #{user.bname} have in the diaper?"
#        
#        session["last_context"] = "diaper_type"
#        
#        elsif session["last_context"] == "diaper_type" and body != "poo" || body != "pee" || body != "both"
#        diaper = Diaper.last
#        time = diaper.start.strftime ( "%A %e at %l:%M:%P" )
#        diaper.save
#        
#            if body == "pee"
#                user = User.last
#                    if user.gender == 1
#                        gender = "girl"
#                        pronoun = "she"
#
#                        elsif user.gender == 2
#                        gender = "boy"
#                        pronoun = "he"
#                    end
#
#                diaper.dtype = "1"
#                diaper.save
#                message = "Great, I logged that #{pronoun} had pee diaper at #{time}."
#
#                elsif body == "poo"
#                    user = User.last
#                        if user.gender == 1
#                            gender = "girl"
#                            pronoun = "she"
#
#                            elsif user.gender == 2
#                            gender = "boy"
#                            pronoun = "he"
#                        end
#                
#                diaper.dtype = "2"
#                diaper.save
#                message = "Great, I logged that #{pronoun} had poo diaper at #{time}."
#
#                elsif body == "both"
#                    user = User.last
#                    if user.gender == 1
#                        gender = "girl"
#                        pronoun = "she"
#
#                        elsif user.gender == 2
#                        gender = "boy"
#                        pronoun = "he"
#                    end
#                    
#                diaper.dtype = "3"
#                diaper.save
#                message = "Great, I logged that #{pronoun} had diaper with both types at #{time}."
#            end
#    end
#    
#    if body == "last diaper"
#        diaper = Diaper.last
#        time = diaper.start.strftime( "%A %e at %l:%M:%P" )
#        
#        if diaper.dtype == 1
#            user = User.last
#            message = "#{user.bname} had a pee diaper at #{time}."
#            
#            elsif diaper.dtype == 2
#            user = User.last
#            message = "#{user.bname} had a poo diaper at #{time}."
#            
#            elsif diaper.dtype == 3
#            user = User.last
#            message = "#{user.bname} had a diaper with both types at #{time}."     
#        end
#    end
#    
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