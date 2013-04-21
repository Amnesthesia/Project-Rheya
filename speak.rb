require "twitter"
require "sqlite3"
require "arrayfields"
require "./see.rb"

    
class Mouth
  
  attr_accessor :debug, :db, :question_starters, :previously_said
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
    @previously_said = []
    
  end


  # Gets a random word based on previously seen wordpairs
  # => options:
  # =>    :direction (direction)
  # =>    :context (array of nouns)
  # @param hash options
  #
  def get_word(word, options = { direction: :forward, context: [] })
  
    word_data = nil
    puts "I got the word %s" %word
    # If we specified context, as in when replying to something, we need to add some stuff to our query
    if options[:context].count > 0
      
      if @debug == true
        puts "We have %s contexts values" % options[:context].count
      end
      
      
      # We want Context IDs for all context nouns we just got, so make them 'noun1','noun2', etc
      context_check = options[:context].join("','")
      query = "SELECT id FROM nouns WHERE noun IN ('%s')" % context_check
    
      context_ids = @db.execute(query)
      comma_separated_ids = []
    
      context_ids.each do |i|
        comma_separated_ids << i['id']
      end
      comma_separated_ids = comma_separated_ids.join(',')
      # aaaand create our query -- we can get the next or the previous word by specifying direction!
      if options[:direction] != :forward
        query = "SELECT * FROM words as next JOIN pairs as p ON (current.id = p.word_id) INNER JOIN context ON (context.pair_identifier = p.id)" 
        query << "INNER JOIN words as current ON (p.pair_id = next.id) WHERE context.noun_id IN (%s) AND current.id = (SELECT id FROM words WHERE word = ?) ORDER BY RANDOM() LIMIT 1;" % comma_separated_ids
      else
        query = "SELECT * FROM words as current JOIN pairs as p ON (current.id = p.word_id) INNER JOIN context ON (context.pair_identifier = p.id)" 
        query << "INNER JOIN words as next ON (p.pair_id = next.id) WHERE context.noun_id IN (%s) AND current.id = (SELECT id FROM words WHERE word = ?) ORDER BY RANDOM() LIMIT 1;" % comma_separated_ids
      end
      
      # Get the randomly selected row
      word_data = @db.get_first_row(query,word)
      
      # If we didnt get any results with context, perform a normal wordpair match
      if word_data == nil or word_data.empty?
        query << " ORDER BY RANDOM() LIMIT 1);"
        word_data = @db.get_first_row(query, word)
      end
    end
    
    # Normal wordpair match:
    if word_data == nil
      if options[:direction] == :forward
        query = "SELECT *, next.word as nword FROM words as current INNER JOIN pairs as p ON (p.word_id = current.id) INNER JOIN words as next ON (p.pair_id = next.id) WHERE current.id = (SELECT id FROM words WHERE word = ?)"
      else
        query = "SELECT *, next.word as nword FROM words as next INNER JOIN pairs as p ON (p.word_id = current.id) INNER JOIN words as current ON (p.pair_id = next.id) WHERE current.id = (SELECT id FROM words WHERE word = ?)"
      end
      query << " ORDER BY RANDOM() LIMIT 1;"
      word_data = @db.get_first_row(query, word)  
      #puts word_data[0]
      
    end
    
    if word_data == nil
      puts "SELECT *, word as nword FROM words WHERE id = (SELECT word_id FROM pairs WHERE pair_id = (SELECT id FROM words WHERE word = %s)" % word
      return word_data
    end
    
    question_rate = exclamation_rate = comma_ratio = dot_ratio = 0
    
    # Calculate the chance of a comma, semicolon, exclamationmark, dot or questionmark trailing this word
    
    unless word_data['occurance'].to_i == 0
      
      unless word_data['question_suffix'].to_i == 0 or word_data['occurance'].to_i == 0
        question_rate = (word_data['question_suffix'].to_i / word_data['occurance'].to_i)*100    
      end  
      
      exclamation_rate = (word_data['exclamation_suffix'].to_i / word_data['occurance'].to_i)*100 unless word_data['exclamation_suffix'] == 0
      comma_ratio = (word_data['comma_suffix'].to_i / word_data['occurance'].to_i)*100 unless word_data['comma_suffix'] == 0
      dot_ratio = (word_data['dot_suffix'].to_i / word_data['occurance'].to_i)*100 unless word_data['dot_suffix'] == 0
    end
    
    
    
   
    
    next_word = word_data['nword']
    
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
  # Regular "markov" wordfetch
  #
  # @param string word
  #  
  def markov_speak(msg)

    all_words = []
    
    if msg.split(/\s+/).count == 2
      word = msg.split(/\s+/)
      sentence = word[0] 
      prev_word = word[1]
      all_words << sentence
      all_words << prev_word
    elsif msg.split(/\s+/).count > 2
      word = msg.split(/\s+/)
      rnd = Random.rand((word.count-2))
      sentence = word.at(rnd)
      prev_word = word.at(rnd+1)
      all_words << sentence
      all_words << prev_word
    elsif msg == nil or msg.empty? or msg == "" or msg.length<1
      word = @db.get_first_value("SELECT word FROM words ORDER BY RANDOM() LIMIT 1;")
      sentence = word
      prev_word = word
      all_words << prev_word
    else
      word = msg
      sentence = msg
      prev_word = msg
      all_words << prev_word
    end
    
    i = 0
    
    
    # Loop with a 1 in 10 chance of ending to construct a randomly sized sentence
    begin  
      if i==0 and all_words.count > 1
        prev_word = @db.get_first_value("SELECT word FROM words WHERE id = (SELECT third_id FROM tripairs WHERE first_id = (SELECT id FROM words WHERE word = ?) AND second_id = (SELECT id FROM words WHERE word = ?) ORDER BY RANDOM() LIMIT 1);",all_words[0],all_words[1])
      elsif all_words.count > 1
        prev_word = @db.get_first_value("SELECT word FROM words WHERE id = (SELECT third_id FROM tripairs WHERE first_id = (SELECT id FROM words WHERE word = ?) AND second_id = (SELECT id FROM words WHERE word = ?) ORDER BY RANDOM() LIMIT 1);",all_words[i-1],all_words[i])      
      end
      
      if prev_word == nil or all_words.count < 1
        prev_word = @db.get_first_value("SELECT word FROM words WHERE id = (SELECT pair_id FROM pairs WHERE word_id = (SELECT id FROM words WHERE word = ?)) ORDER BY RANDOM() LIMIT 1;", prev_word)
      end
      
      # Append a randomly chosen word based on the previous word in the sentence
      unless prev_word == nil
        sentence << " " << prev_word
        puts " added %s" %prev_word
      end
      i += 1
    end while all_words.join(' ').length < 400 and prev_word != nil
    sentence.capitalize!
    return sentence
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
    
    e = Eye.new
    context = []
    
    # Check if we were provided with multiple words or just one
    if msg.match(/^\w+\s+\w+.+/)
      word = msg.split(/\s+/)
      
      if word.count > 2
        context = e.get_context(msg)
       
        if context.empty?
          sentence = word.last
          prev_word = sentence
        else
          sentence = context.at(Random.rand(context.count))
          prev_word = @db.get_first_value("SELECT word FROM words ORDER BY RANDOM() LIMIT 1;")     
        end
      else
        sentence = word.last  
        prev_word = word.last     
      end
    elsif msg == nil or msg.empty?
      prev_word = @db.get_first_value("SELECT word FROM words ORDER BY RANDOM() LIMIT 1;")
      sentence = prev_word
      
      
      @previously_said.each do |p|
        context.zip(e.get_context(p)).flatten!
      end unless @previously_said.empty?
      
      context.uniq
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
      sentence << " " << prev_word unless prev_word == nil
      puts " added %s" %prev_word
      i += 1
      
    end while (prev_word !~ /^\w+([\?\.!])/) and prev_word != nil
    
    # Capitalize our sentence, of course (:
    sentence.capitalize!
    if @previously_said.count > 5
      @previously_said.shift  
    end
    
    @previously_said << sentence
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