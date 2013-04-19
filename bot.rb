require "cinch"
require "rubygems"
require "mechanize"
require "rheya.rb"

rheya = Rheya.new

class RheyaIRC
  include Cinch::Plugin
  
  match /https?:\/\/[\S]+/, { method: :GetTitle}  
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

  
  def GetTitle(m)
    urls = URI.extract(m.message)
   
    urls.each do |url|
      answer = Format(:grey, "Title: %s" % [Format(:bold, $WWW::Mechanize.new.get(url).title)] )
      m.reply answer
    end
  end
  
  ############################################################
  ############################################################
  ## CONTINUE ADDING THE IRC METHODS TO RESPOND TO COMMANDS ##
  ############################################################
  ############################################################
end

bot = Cinch::Bot.new do
  configure do |conf|
  
    # Set up personality
    conf.nick = "Rheya"
    conf.user = "Rheya"
    conf.realname = "Rheya"
    
    # Set up server
    conf.server = "irc.codetalk.io"
    conf.channels = ["#lobby"]
    conf.port = 6697
    conf.ssl.use = true
    
    # Load some plugins
    
    conf.plugins.plugins = [RheyaIRC]
    conf.plugins.prefix = nil
    
  end
  
end


bot.start