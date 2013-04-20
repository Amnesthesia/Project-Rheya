require "cinch"
require "rubygems"
require "mechanize"
require "./rheya.rb"


class RheyaIRC
  attr_accessor :rheya
  include Cinch::Plugin
  
  match /https?:\/\/[\S]+/, { method: :get_title}  
  match /.+/, { method: :learn }
  match /^!speak.*/, { method: :say }
  match /^!remember\s.+/, { method: :remember }
  match "!recall", {method: :recall }
  match /^!tweet\s.+/, { method: :tweet }
  match /^!reply\s.+/, { method: :reply }
  match /^!follow\s.+/, { method: :follow }
  match /^!mentions/, { method: :mentioned}
  match /^!read\s.+/, {method: :read }
  
  timer 600, method: :mentioned
  
  # Speak every 1h 15min
  timer 4400, method: :say
  
  def initialize(*args)
    super
    @rheya = Rheya.new
  end
  
  def get_title(m)
    urls = URI.extract(m.message)
   
    urls.each do |url|
      answer = Format(:grey, "Title: %s" % [Format(:bold, $WWW::Mechanize.new.get(url).title)] )
      answer.chomp!
      m.reply answer
    end
  end
  
  def strip_command(msg)
    return msg.sub(/(^!\w+\s*)/,'')
  end
  
  def learn(msg)
    @rheya.learn(strip_command(msg.message))
  end
  
  def say(msg)
    msg.reply @rheya.speak(strip_command(msg.message))
  end
  
  def remember(msg)
    @rheya.remember strip_command(msg.message)
    
    msg.reply "I'll remember that :)"
  end
  
  def recall(msg)
    msg.reply @rheya.recall
  end
  
  def tweet(msg)
    @rheya.tweet strip_command(msg.message)
    msg.reply "Said and done :)"
  end
  
  def reply(msg)
    @rheya.reply strip_command(msg.message)
    msg.reply "Said and done :)"
  end
  
  def follow(msg)
    @rheya.follow strip_command(msg.message)
    msg.reply "As you wish ..."
  end
  
  def read(msg)
    msg.reply @rheya.mouth.read(strip_command(msg.message))
  end
  
  def mentioned(msg)
    @rheya.last_mentions.each do |m|
      msg.reply m
    end
  end
  
end

bot = Cinch::Bot.new do
  configure do |conf|
  
    # Set up personality
    conf.nick = "Inara"
    conf.user = "Rheya"
    conf.realname = "Rheya"
    
    # Set up server
    conf.server = "irc.codetalk.io"
    conf.channels = ["#lobby","#rheya"]
    conf.port = 6697
    conf.ssl.use = true
    
    # Load some plugins
    
    conf.plugins.plugins = [RheyaIRC]
    conf.plugins.prefix = nil
    
  end
  
end


bot.start