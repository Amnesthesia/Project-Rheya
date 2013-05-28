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
  match /^!recall.*/, {method: :recall }
  match /^!wikiread/, {method: :wikilearn }
  match /^!tweet\s.+/, { method: :tweet }
  match /^!reply\s.+/, { method: :reply }
  match /^!follow\s.+/, { method: :follow }
  match /^!mentions/, { method: :mentioned}
  match /^!read\s.+/, {method: :read }
  match /^!wiki\s.+/, {method: :wiki }
  match /^!help.*/, { method: :print_help }
  match /^!markov.*/, {method: :markov }
  match /^!nouns.*/, {method: :nouns }
  
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
      answer.strip!
      m.reply answer
    end
  end
  
  def strip_command(msg)
    return msg.sub(/(^!\w+\s*)/,'')
  end
  
  def nouns(msg)
    msg.reply "I think the context of that was (reduced least important nouns if too many found): " + @rheya.brain.get_topic(strip_command(msg.message)).to_s  
  end
  
  def learn(msg)
    unless msg.user == "Rheya" or msg.user == "Inara" or msg.user == "River"
      unless msg.action?
        @rheya.learn(strip_command(msg.message))
      end
    end
  end
  
  def say(msg)
    msg.message.downcase!
    msg.reply @rheya.speak(strip_command(msg.message))
  end
  
  def markov(msg)
    msg.message.downcase!
    msg.reply @rheya.markov(strip_command(msg.message))
  end
  
  def remember(msg)
    id = @rheya.remember strip_command(msg.message)
    
    msg.reply "I'll remember that :) [Memory #%s] " % id
  end
  
  def recall(msg)
    msg.reply @rheya.recall(strip_command(msg.message))
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
  
  def mentioned(msg = '')
    @rheya.last_mentions.each do |m|
      msg.reply m
    end
  end
  
  def wiki(msg)
    message = strip_command(msg.message)
    
    wiki = @rheya.eyes.get_wiki message
    i = 0
    unless wiki.empty?
      p = wiki.join(" ").gsub(/(\W\d+\W)/,"").split(/\n/)
      p.each do |w|
        
        if i < 2
          msg.reply w
        end
        i += 1
      end
    end
    return ""
  end
  
  def wikilearn(msg)
    message = strip_command(msg.message)
    
    wiki = @rheya.eyes.get_wiki message
    i = 0
    unless wiki.empty?
      p = wiki.join(" ").gsub(/(\W\d+\W)/,"").split(/\n/)
      p.each do |w|
        
        if i < 2
          msg.reply w
        end
        i += 1
        msg.reply "Oooh this looks interesting ... Thanks! Reading now... :D"
        @rheya.eyes.process_message(w)
      end
    end
    return ""
  end
  
  
  def print_help(msg)
    msg.reply "I know the following commands:"
    msg.reply "  !markov [word] - Default markov ramble"
    msg.reply "  !mentions - Gets the latest tweets meant for meeeeee :D"
    msg.reply "  !recall <#ID>- I'll tell you a random quote or message if I remember it (if your provide a specific ID I'll pull it out for you)"
    msg.reply "  !remember <message> - Store a quote or message"
    msg.reply "  !reply <message> - Reply to the last person who tweeted me"
    msg.reply "  !tweet <message> - Tweet a message from @CodetalkIRC"
    msg.reply "  !speak [word] - If you give me a word or a long sentence, I'll try to stay on topic. Note: try. Otherwise I'll just ramble."
    msg.reply "  !wiki <page name> - I'll try to find you the wiki page and give you a summary"
    msg.reply ""
  end
  
end

bot = Cinch::Bot.new do
  configure do |conf|
  
    # Set up personality
    conf.nick = "Rheya"
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