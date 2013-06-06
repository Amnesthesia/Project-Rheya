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
  match /^!w\s+/, {method: :wikilearn }
  match /^!tweet\s.+/, { method: :tweet }
  match /^!reply\s.+/, { method: :reply }
  match /^!follow\s.+/, { method: :follow }
  match /^!mentions/, { method: :mentioned}
  match /^!read\s.+/, {method: :read }
  match /^!wiki\s.+/, {method: :wiki }
  match /^!help.*/, { method: :print_help }
  match /^!markov.*/, {method: :markov }
  match /^!nouns.*/, {method: :nouns }
  match /^!stats/, { method: :statistics }
  match /^!nsfw\s.+/ { method :nsfw }
  
  timer 600, method: :mentioned
  
  # Speak every 1h 15min
  timer 4400, method: :say
  
  def initialize(*args)
    super
    @rheya = Rheya.new
  end
  
  def get_title(m)
    if m.message =~ /(^\w+:\s+)/
      msg = m.message.gsub(/(^\w+:\s*)/,'')
    else
      msg = m.message
    end
    
    urls = URI.extract(msg)
   
    urls.each do |url|
      if @rheya.ears.nsfw_url.include? m.user.to_s.downcase 
        answer = Format(:grey, "[NSFW by default] Title: %s" % [Format(:bold, $WWW::Mechanize.new.get(url).title)] )
      else
        answer = Format(:grey, "Title: %s" % [Format(:bold, $WWW::Mechanize.new.get(url).title)] )
      end
      
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
    if msg.user.to_s == "Foxboron" and msg.message =~ /\s+(to)$/
      msg.reply "Foxboron: too*"
    elsif msg.user.to_s == "Foxboron" and msg.message =~ /\s+(too)\s+/
      msg.reply "Foxboron: to*"
    end
    
    unless msg.user.to_s == "Rheya" or msg.user.to_s == "Inara" or msg.user.to_s == "River"
      unless msg.action?
        @rheya.eyes.add_statistics(msg.user,msg.message.split(/\s+/).count)
        @rheya.learn(strip_command(msg.message))
      end
    end
    
  end
  
  def statistics(msg)
    @rheya.mouth.get_statistics.each do |stat|
      msg.reply stat
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
  
  def nsfw(msg)
    message = strip_command(msg.message)
    words = message.split(/\s+/)
    
    if words.count > 1 and (words[0] =~ /[a-zA-Z0-9]+/ and words[1] =~ /\d/)
      user = words[0]
      state = words[1].to_i
    else
      user = msg.user.to_s
      state = words.to_i
    end
    
    @rheya.ears.nsfw_links(user,state)
    if state > 0
      msg.reply "User " + user + " now sends NSFW links by default ... :D"
    else
      msg.reply "User " + user + " will now have to manually append NSFW to his/her links :/ GLHF"
    end
  end
  
  def wiki(msg)
    message = strip_command(msg.message)
    
    wiki = @rheya.eyes.get_wiki message
    p = wiki.join(" ").gsub(/(\W\d+\W)/,"")
      
    said_msg = p.slice(0,900)
    said_msg << "..."
    msg.reply said_msg

  end
  
  def wikilearn(msg)
    message = strip_command(msg.message)
    
    wiki = @rheya.eyes.get_wiki message
    p = wiki.join(" ").gsub(/(\W\d+\W)/,"")
      
    said_msg = p.slice(0,900)
    said_msg << "..."
    msg.reply said_msg
    
    unless wiki.empty?
      msg.reply "Oooh this looks interesting ... "
      @rheya.eyes.process_message(wiki)
      msg.reply "I'm done reading about %s now :) I feel so much smarter!" % message
    end
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
    msg.reply "  !stats - I'll show you who's the loudest in here"
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