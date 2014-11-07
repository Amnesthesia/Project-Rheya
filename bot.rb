require "rubygems"
require "cinch"
require "rubygems"
require "mechanize"
require "./rheya.rb"


class RheyaIRC
  attr_accessor :rheya, :last_poll_id
  include Cinch::Plugin

  match /https?:\/\/[\S]+/, { method: :get_title}
  match /.+/, { method: :learn }
  match /^\w+=.+/, { method: :set_variable}
  match /^!set\s+\w+\s+\w+/, { method: :set_variable }
  match /^!get\s+\w+/, {method: :get_variable}
  match /^\w+\?/, {method: :get_variable}
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
  match /^!nsfw\s.+/, { method: :nsfw }
  match /^Rheya:\s.+/, { method: :speakback }
  match /^Rheya,\s.+/, {method: :speakback }
  match /^!poll\s*\w+/, {method: :new_poll}
  match /^!poll\s+\d/, {method: :get_poll}
  match /^!poll$/, {method: :last_poll}
  match /^!vote\s+\d/, {method: :vote}
  match /^!answer\s+\w+/, {method: :add_answer}
  match /^!8ball\s+\w+/, {method: :eightball}
  match /^!roll\s*/, {method: :dice}

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
        answer = Format(:grey, "[NSFW by default] Title: %s" % [Format(:bold, $WWW::Mechanize.new.get(url).title.chomp)] )
      else
        answer = Format(:grey, "Title: %s" % [Format(:bold, $WWW::Mechanize.new.get(url).title.chomp)] )
      end

      answer.strip!
      answer.gsub!(/[\n]+/,' ')
      m.reply answer
    end
  end


  def strip_command(msg)
    return msg.sub(/(^!\w+\s*)/,'')
  end

  def nouns(msg)
    msg.reply "I think the context of that was (reduced least important nouns if too many found): " + @rheya.brain.get_topic(strip_command(msg.message)).to_s
  end

  def get_variable(msg)
    message = msg.message.to_s
    message.gsub!(/!get\s+/) if message.match(/^!get\s+/)
    message.gsub!(/\?.*/) if message.match(/^\w+\?/)
    key = message.split(" ").shift if message.is_a? Array
    key = message if message.is_a? String

    msg.reply "#{key.capitalize} is: %s" % @rheya.ears.get_variable(key)
  end

  def set_variable(msg)
    message = msg.message.to_s
    message.gsub!(/!set\s+/) if message =~ /^!set\s+.*/
    message.gsub!(/^\w+=\s*/) if message =~ /^\w+=.*/

    if message =~ /\s/
      message = message.split(/\s/)
      key = message.shift
      message = message.join(" ")

      replies = ["Thanks for explaining what %s was :)", "Thanks for explaining %s :x", "Yay! %s! I learned something new :D", "Cool, a word. Nice.", "Nice word man, it'll echo!", "Words are like scooby snacks for me <3"]

      msg.reply replies.at(Random.rand(replies.count)).to_s % @rheya.ears.set_variable(key,message)
    end
  end



  def learn(msg)
    if msg.user.to_s == "Foxboron" or msg.user.to_s == "Fox" and msg.message =~ /\s+(to)$/
      msg.reply "Foxboron: too*"
    elsif msg.user.to_s == "Foxboron" or msg.user.to_s == "Fox" and msg.message =~ /\s+(too)\s+/
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

  def speakback(msg)
    message = msg.message.gsub(/^Rheya\W*\s*/,'')
    context = @rheya.brain.get_all_nouns(message)

    puts "Got contexts: " + context.to_s

    if context.count > 1
      word = context[Random.rand(context.count-1)]
      puts "Speaking on randomized word: " + word
      msg.reply @rheya.speak(nil,context)
    elsif context.count > 0
      puts "Speaking on word: " + context[0]
      msg.reply @rheya.speak(context[0],context)
    else
      puts "Speaking on word: %s, %s" % [message.split(/\s+/).last, message.split(/\s+/)[-2]]
      say message
    end
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

    if message =~ /\s+/
      words = message.split(/\s+/)

      if words.count > 1 and (words[0] =~ /[a-zA-Z0-9]+/ and words[1] =~ /\d/)
        user = words[0]
        state = words[1].to_i
      else
        user = msg.user.to_s
        state = words.to_i
      end
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

  def new_poll(msg)
    message = strip_command(msg.message)
    get_poll(msg) and return if message =~ /\d+/
    if message.include? ";"
      spl = message.split(";")
      pl = spl.shift
      @last_poll_id = @rheya.ears.add_poll(msg.user.to_s, pl)
      msg.reply "Poll created: "+pl
      spl.each do |answer|
        answer = @rheya.ears.add_answer(@last_poll_id, answer)
        msg.reply answer["number"].to_s + ". "+answer["answer"]
      end
    else
      @last_poll_id = @rheya.ears.add_poll(msg.user.to_s, message)
      msg.reply "Poll created: "+message+" (#"+@last_poll_id.to_s+")"
      msg.reply "You can add answers with !answer"
    end
  end

  def get_poll(msg)
    @last_poll_id ||= @rheya.ears.get_last_poll_id
    message = strip_command(msg.message)
    poll = @rheya.mouth.get_poll(message.to_i||@last_poll_id)

    @last_poll_id = poll[:id]
    msg.reply poll[:msg]
  end

  def last_poll(msg)
    @last_poll_id ||= @rheya.ears.get_last_poll_id
    message = strip_command(msg.message)
    poll = @rheya.mouth.get_poll(@last_poll_id)
    @last_poll_id = poll[:id]
    msg.reply poll[:msg]
  end

  def vote(msg)
    @last_poll_id ||= @rheya.ears.get_last_poll_id
    message = strip_command(msg.message)
    @rheya.ears.vote(@last_poll_id, message,msg.user.realname)
    msg.reply msg.user.to_s+" voted for answer #"+message
  end

  def add_answer(msg)
    message = strip_command(msg.message)
    @last_poll_id ||= @rheya.ears.get_last_poll_id
    answer = @rheya.ears.add_answer(@last_poll_id, message)
    msg.reply answer["number"].to_s + ". " + answer["answer"]
  end

  def dice(msg)
    message = strip_command(msg.message)
    if(message =~ /(\d+)+\s+(\d+)/)
      num = message.match(/(\d+)+\s+(\d+)/)
      msg.reply Random.rand(num[1].to_i..num[2].to_i).to_s
    elsif(message=~ /(\d+)/)
      num = message.match(/\d+/)
      msg.reply Random.rand(num[0].to_i).to_s
    else
      msg.reply Random.rand(1..6).to_s
    end
  end

  def eightball(msg)
    ball = []
    ball << "Signs point to yes."
    ball << "Yes."
    ball << "Reply hazy, try again."
    ball << "Without a doubt."
    ball << "My sources say no."
    ball << "As I see it, yes."
    ball << "You may rely on it."
    ball << "Concentrate and ask again."
    ball << "Outlook not so good."
    ball << "It is decidedly so."
    ball << "Better not tell you now."
    ball << "Very doubtful."
    ball << "Yes - definitely."
    ball << "It is certain."
    ball << "Cannot predict now."
    ball << "Most likely."
    ball << "Ask again later."
    ball << "My reply is no."
    ball << "Outlook good."
    ball << "Don't count on it."

    msg.reply ball[Random.rand(ball.length)]
  end

  def print_help(msg)
    msg.user.notice "I know the following commands ([] is optional, <> is required):"
    msg.user.notice "  !8ball [question] - Generic 8ball"
    msg.user.notice "  !set <variable> <value> (or just var=value)- Links the first word to what succeeds it, and allows you to fetch it again"
    msg.user.notice "  !echo <variable> - Prints the information linked to this variable"
    msg.user.notice "  !markov [word] - Default markov ramble"
    msg.user.notice "  !mentions - Gets the latest tweets meant for meeeeee :D"
    msg.user.notice "  !nsfw <[user] state> - Sets status of NSFW by default for specified user (or if no user specified, from the one who requested it)"
    msg.user.notice "  !recall <#ID>- I'll tell you a random quote or message if I remember it (if your provide a specific ID I'll pull it out for you)"
    msg.user.notice "  !remember <message> - Store a quote or message"
    msg.user.notice "  !reply <message> - Reply to the last person who tweeted me"
    msg.user.notice "  !roll [n] [[n]] - Generates a random number between 1-6. You can set a max value, or a range to roll between."
    msg.user.notice "  !tweet <message> - Tweet a message from @CodetalkIRC"
    msg.user.notice "  !poll question;answer1;answer2;answer3 - Create a poll with predefined answers"
    msg.user.notice "  !poll [question] - Create a new poll if a question is supplied, or fetches the last poll created"
    msg.user.notice "  !answer <answer> - Adds a new answer to the last viewed poll"
    msg.user.notice "  !vote <number> - Votes for an answer in the last viewed poll"
    msg.user.notice "  !speak [word] - If you give me a word or a long sentence, I'll try to stay on topic. Note: try. Otherwise I'll just ramble."
    msg.user.notice "  !stats - I'll show you who's the loudest in here"
    msg.user.notice "  !wiki <page name> - I'll try to find you the wiki page and give you a summary"
    msg.user.notice ""
  end

end

bot = Cinch::Bot.new do
  configure do |conf|

    # Set up personality
    conf.nick = "Rheya, Inara"
    conf.user = "Rheyaa"
    conf.realname = "Rheya"

    # Set up server
    conf.server = "irc.codetalk.io"
    conf.channels = ["#lobby", "#rheya"]
    conf.port = 6697
    conf.ssl.use = true

    # Load some plugins

    conf.plugins.plugins = [RheyaIRC]
    conf.plugins.prefix = nil

  end

end


bot.start
