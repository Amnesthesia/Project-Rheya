require "see.rb"
require "listen.rb"
require "speak.rb"

#
# This whole class is just a wrapper class linking 
# all the other classes together and routing information
# to the appropriate parts of Rheya
#

class Rheya
  
  attr_accessor :debug, :ears, :eyes, :mouth
  
  def initialize(*args)
    @debug = true
    @ears = Ear.new
    @mouth = Mouth.new
    @eyes = Eye.new
  end
  
  # 
  # Reads messages and learns about the content
  #
  # @param string message
  #
  def learn(message)
    @eyes.process_message(message)
  end
  
  #
  # Says something (either in a reply to a message, or makes it up)
  #
  # @param string message (optional)
  #
  def speak(message)
    return @mouth.construct_sentence(message)
  end
  
  #
  # Remembers something and lets it be randomized by recall
  # 
  # @param string message
  #
  def remember(message)
    return @ears.add_quote(message)
  end
  
  #
  # Pulls a random string out of Rheya's memory
  #
  # @param string message
  #
  def recall
    return @ears.random_quote
  end
  
  #
  # Fetches last mentions from Twitter
  # and returns an array of strings
  #
  # @return array
  #
  def last_mentions
    return @mouth.last_mentioned
  end
  
  #
  # Follows users on Twitter
  #
  # @param string user
  # 
  def follow_user(user)
    return @mouth.follow(user)
  end
  
  #
  # Replies to the last mention on Twitter
  #
  # @param string message
  #
  def reply(message)
    return @mouth.reply(message)
  end
  
  #
  # Tweets a message
  #
  # @param string message
  #
  def tweet(message)
    return @mouth.tweet(message)
  end
end