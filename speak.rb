require "twitter"
require "sqlite3"
require "arrayfields"
require "see.rb"

    
class Mouth
  
  attr_accessor :debug, :db, :question_starters
  debug = true
 
  
  def initialize(*args)
    @db = SQLite3::Database.new("dictionary.db")
    @db.results_as_hash = true
    @debug = true
    @question_starters = ["what", "who", "where", "when", "which", "how","wherefore", "whatever", "whom", "whose", "whither", "why", "whence", "do", "did", "does", "will", "can", "is", "are"]
    
    @twit = Twitter::Client.new(
      :consumer_key => "9x9TByi4BjzXs9N1Oyv3gA",
      :consumer_secret => "3NfBK7yhwHZLz4ZOAyLZ6aN6amaB55nNCNph48PGs",
      :oauth_token => "1363095884-N9tj5FR3iFb2Sokhxi59WLxwRoF1AOWPVZ4uydr",
      :oauth_token_secret => "360KsViDUl7P7ajTmxBYqzNxkW2BnWKAl30Y2Umy4"
    )
    @last_mention = nil
    
  end


  # Gets a random word based on previously seen wordpairs
  # => options:
  # =>    :direction (direction)
  # =>    :context (array of nouns)
  # @param hash options
  #
  def get_word(word, options = { direction: :forward, context: [] })
   
    # If we're looking for the next word rather than the previous, find it by pair_id, else by word_id
    if options[:direction] == :forward
      query = "SELECT * FROM words WHERE id = (SELECT word_id FROM pairs WHERE pair_id = (SELECT id FROM words WHERE word = ?)"
    else
      query = "SELECT * FROM words WHERE id = (SELECT pair_id FROM pairs WHERE word_id = (SELECT id FROM words WHERE word = ?)"
    end
    
    
    # If we specified context, as in when replying to something, we need to add some stuff to our query
    if options[:context].count > 0
      
      # We want Context IDs for all context nouns we just got, so make them 'noun1','noun2', etc
      appendage = options[:context].join("','")
      q = "SELECT id FROM nouns WHERE noun IN ('%s')" % appendage
      rows = @db.execute(q)
      
      # Populate this one with all our context IDs we just fetched
      context_ids = []
      
      rows.each do |r|
        context_ids += r['id']   
      end
      
      # and append to our query that we only want wordpairs that's in this kind of context...
      context_query = query + " AND context IN (%s)" % ids.join(",")
      context_query += " ORDER BY RANDOM() LIMIT 1)"
      
      # Get the randomly selected row
      word_data = @db.get_first_row(context_query)
      
      # If we didnt get any results with context, perform a normal wordpair match
      if word_data == nil or word_data.empty?
        query += " ORDER BY RANDOM() LIMIT 1)"
        word_data = @db.get_first_row(query, word)
      end
    # Normal wordpair match:
    else
      query += " ORDER BY RANDOM() LIMIT 1)"
      word_data = @db.get_first_row(query, word)  
    end
    
    # Calculate the chance of a comma, semicolon, exclamationmark, dot or questionmark trailing this word
    question_rate = (word_data['question_suffix'].to_i / word_data['occurance'].to_i)*100
    exclamation_rate = (word_data['exclamation_suffix'].to_i / word_data['occurance'].to_i)*100
    comma_ratio = (word_data['comma_suffix'].to_i / word_data['occurance'].to_i)*100
    dot_ratio = (word_data['dot_suffix'].to_i / word_data['occurance'].to_i)*100
    
    if Random.rand(100) < question_rate
      next_word << "?"
    elsif Random.rand(100) < exclamation_rate
      next_word << "!"
    elsif Random.rand(100) < comma_ratio
      next_word << ","
    elsif Random.rand(100) < dot_ratio
      next_word << "."
    end
    
    return next_word
  end
  
  
  # 
  # Constructs a sentence based on either:
  #
  # => A previous textblock (context)
  # => A single word (markov)
  # => A random word
  # 
  # @param string msg
  # @return string
  #
  def construct_sentence(msg)

    context = []
    
    # Check if we were provided with multiple words or just one
    if msg.match(/^\w+\s+\w+.+/)
      word = msg.split(/\s+/)
      
      if word.count > 2
        context = Eye::get_context(msg)
       
        if context.empty?
          sentence = word.last
          prev_word = sentence
        else
          sentence = context.at(Random.rand(context.count))
          prev_word = sentence         
        end
      else
        sentence = word.last  
        prev_word = word.last     
      end
    elsif msg == nil or msg.empty?
      prev_word = @db.get_first_value("SELECT word FROM words ORDER BY RANDOM() LIMIT 1;")
      sentence = prev_word
    else
      sentence = msg
      prev_word = msg
    end
    
    first_word = sentence
    i = 0
    
    # Loop with a 1 in 25 chance of ending to construct a randomly sized sentence
    begin  
      prev_word = get_word(prev_word, { context: context })
      
      if first_word == nil or first_word.empty?
        first_word = prev_word
      end
      
      # If this word came with a trailing question mark ...
      if prev_word =~ /^\w+([\?])/
        
        # and the start of the sentence wasnt a question word ...
        unless @question_starters.include? first_word
          
          # get rid of that question mark!
          prev_word.slice! "?"
        end
      end
      
      # Append a randomly chosen word based to our semi-constructed sentence
      sentence << " " << prev_word
      puts " added %s" %prev_word
      i += 1
      
    end while (prev_word !~ /^\w+([\?\.!])/)
    
    # Capitalize our sentence, of course (:
    sentence.capitalize!
    
    return sentence
  end
  
  # 
  # Sends a tweet to Twitter 
  #
  # @param string msg
  #
  def tweet(msg)
    @twit.update(msg) unless msg.empty?  
  end
  
  #
  # Checks for the last mention in the mention_timeline
  # on Twitter, and returns it as a string array
  #
  # @return array
  #
  def last_mentioned
    
    if @last_mentioned != nil
      tweets = @twit.mentions_timeline({ since_id: @last_mentioned.id })
    else
      tweets = @twit.mentions_timeline
    end
    
    if tweets.empty? or tweets.count < 1
      return "Nobody's talking to me .. Everybody hates me :("
    else
      @last_mentioned = tweets.first
    end
    answer = ""
    
    tweets.map do |t|
      from = t.from_user.capitalize
      answer << from + " said: " + t.text + "||"
    end
    
    return answer.split("||").to_a
  end
  
  # 
  # Follows a user or several users on Twitter
  #
  # @param string msg
  #
  def follow(msg)
    
    # Remove @ from usernames
    if msg =~ /@/
      msg.slice! "@"
    end
    
    if msg =~ /\s/
      msg = msg.split(/\s+/)
      msg.each do |m|
        puts "Attempting to follow %s" % m
        @twit.follow(m)
      end
    else
      puts "Attempting to follow %s" % msg
      @twit.follow(msg)
    end
    
  end
  
  #
  # Replies to the user posting the last mention
  # 
  # @param string msg
  #
  def reply(msg)    
    mess = "@" + @last_mentioned.from_user + " " + msg 
    @twit.update(mess)
  end
  
  #
  # Returns the first text in a specified users timeline
  #
  # @param string user
  
  def read(user)
    
    tweet = @twit.user_timeline(user)
    
    return tweet.first.text
  end
  
end