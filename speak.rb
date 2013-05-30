require "twitter"
require "sqlite3"
require "arrayfields"
require "pickup"
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
    
    puts "Occurance of word " + word_data['nword'].to_s + " is " + word_data['occurance'].to_s
    unless word_data['occurance'].to_i == 0
      
      unless word_data['question_suffix'].to_i == 0 or word_data['occurance'].to_i == 0
        question_rate = (word_data['question_suffix'].to_i / word_data['occurance'].to_i)*100    
      end  
      
      exclamation_rate = (word_data['exclamation_suffix'].to_i / word_data['occurance'].to_i)*100 unless word_data['exclamation_suffix'] == 0
      puts "Exclamation rate 0" if word_data['exclamation_suffix'] == 0
      comma_ratio = (word_data['comma_suffix'].to_i / word_data['occurance'].to_i)*100 unless word_data['comma_suffix'] == 0
      puts "Comma rate 0" if word_data['comma_suffix'] == 0
      dot_ratio = (word_data['dot_suffix'].to_i / word_data['occurance'].to_i)*100 unless word_data['dot_suffix'] == 0
      puts "Dot ratio 0" if word_data['dot_suffix'] == 0
    end
    
    
    
   
    
    next_word = word_data['nword']
    punctuation = ''
    emo = false
    
    if Random.rand(100) < question_rate
      punctuation = "?"
    elsif Random.rand(100) < exclamation_rate
      punctuation = "!"
    elsif Random.rand(100) < comma_ratio
      punctuation = ","
    elsif Random.rand(100) < dot_ratio
      punctuation = "."
    elsif Random.rand(100) < 7
      emo = true
    end
    
    word_info = { emoticon: emo, punctuation: punctuation, word: next_word }
    
    return word_info
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
      sentence << word[1]
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
      backup_word = prev_word
      
      if i==0 and all_words.count > 1 #and Random.rand(10) > 6
        prev_word = @db.get_first_row("SELECT third_id as wid, occurance, (RANDOM()*100*(occurance*1.0/(SELECT SUM(occurance) FROM tripairs WHERE first_id = (SELECT id FROM words WHERE word = ?) AND second_id = (SELECT id FROM words WHERE word = ?) LIMIT 1))) as probability FROM tripairs WHERE first_id = (SELECT id FROM words WHERE word = ?) AND second_id = (SELECT id FROM words WHERE word = ?) ORDER BY probability DESC LIMIT 1;",all_words[0],all_words[1],all_words[0],all_words[1])
      elsif all_words.count > 1 #and Random.rand(10) > 7
        prev_word = @db.get_first_row("SELECT third_id as wid, occurance, (RANDOM()*100*(occurance*1.0/(SELECT SUM(occurance) FROM tripairs WHERE first_id = (SELECT id FROM words WHERE word = ?) AND second_id = (SELECT id FROM words WHERE word = ?) LIMIT 1))) as probability FROM tripairs WHERE first_id = (SELECT id FROM words WHERE word = ?) AND second_id = (SELECT id FROM words WHERE word = ?) ORDER BY probability DESC LIMIT 1;",all_words[i-1],all_words[i],all_words[i-1],all_words[i])      
      else
         prev_word = @db.get_first_row("SELECT pair_id as wid, occurance, (RANDOM()*100*(occurance*1.0/(SELECT SUM(occurance) FROM pairs WHERE word_id=(SELECT id FROM words WHERE word = ?) LIMIT 1))) as probability FROM pairs WHERE word_id = (SELECT id FROM words WHERE word = ? LIMIT 1) ORDER BY probability DESC LIMIT 1;", prev_word,prev_word)
      end
      
      prev_word = @db.get_first_value("SELECT word FROM words WHERE id = ?",prev_word['wid']) unless prev_word == nil
      
      if prev_word == nil or all_words.count < 2 or prev_word.empty?
        prev_word = @db.get_first_row("SELECT pair_id as wid,occurance, (RANDOM()*100*(occurance*1.0/(SELECT SUM(occurance) FROM pairs WHERE word_id=(SELECT id FROM words WHERE word = ?) LIMIT 1))) as probability FROM pairs WHERE word_id = (SELECT id FROM words WHERE word = ?) ORDER BY probability DESC LIMIT 1;", backup_word,backup_word)
        prev_word = @db.get_first_value("SELECT word FROM words WHERE id = ?",prev_word['wid'])
      end
      if prev_word == backup_word
        prev_word = nil
      end
      puts "Got word id " + prev_word.to_s
      
      #word_ids = {}
      #prev_words.each do |w|
        #word_ids[w['wid'].to_s.to_sym] = w['probability']
        #puts "I added " + w['wid'].to_s + " with probability " + w['probability'].to_s
      #end
      #p = Pickup.new(word_ids)
      #chosen_id = p.pick(1)
      
      
      
      
      # Append a randomly chosen word based on the previous word in the sentence
      unless prev_word == nil
        sentence << " " << prev_word
        puts " added %s" %prev_word
        all_words << prev_word
      end
      i += 1
    end while all_words.join(' ').length < 200 and prev_word != nil
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
    prev_word = { word: '', emoticon: false, punctuation: '' }
    
    @previously_said.each do |p|
      context.zip(e.get_context(p)).flatten!
    end unless @previously_said.empty?
      
    context.uniq
    
    # Check if we were provided with multiple words or just one
    if msg.match(/^\w+\s+\w+.+/)
      word = msg.split(/\s+/)
      
      if word.count > 2
        context = e.get_context(msg)
       
        if context.empty?
          sentence = msg
          prev_word[:word] = msg.gsub(/[^a-zA-Z0-9\s]/,'')
          
        else
          sentence = context.at(Random.rand(context.count))
          prev_word[:word] = @db.get_first_value("SELECT word FROM words ORDER BY RANDOM() LIMIT 1;")     
        end
      else
        sentence = word.at(word.count-2)
        prev_word[:word] = word.last  
      end
    elsif msg == nil or msg.empty?
      prev_word[:word] = @db.get_first_value("SELECT word FROM words ORDER BY RANDOM() LIMIT 1;")
      sentence = ''
      
    else
      sentence = ''
      prev_word[:word] = msg
    end
    
    first_word = sentence
    i = 0
    remember_previous_word = nil
    
    # Loop with a 1 in 25 chance of ending to construct a randomly sized sentence
    begin  
      
      
      # If this word came with a trailing question mark ...
      if prev_word[:word] =~ /^\w+([\?])/
        
        # and the start of the sentence wasnt a question word ...
        unless @question_starters.include? first_word
          
          # get rid of that question mark!
          prev_word[:word].slice! "?"
        end
      end
      
      if prev_word[:emoticon] == true and remember_previous_word != nil
        prev_word[:punctuation] = " " + @db.get_first_value("SELECT emotion_index FROM pair_emotions WHERE pair_id = (SELECT id FROM pairs WHERE word_id = ? AND pair_id = ? LIMIT 1) ORDER BY RANDOM() LIMIT 1",remember_previous_word[:word],prev_word["word"])
      end
      
      # Append a randomly chosen word based to our semi-constructed sentence
      sentence << prev_word[:word] << prev_word[:punctuation] << " " unless prev_word == nil
      puts " added %s" %prev_word[:word]
      i += 1
      
      # Remember the word for one more iteration
      remember_previous_word = prev_word
      prev_word = get_word(remember_previous[:word], { context: context })
      
      if remember_previous_word[:punctuation] == "." or remember_previous_word[:punctuation] == "!" or remember_previous_word[:punctuation] == "." or prev_word[:word] == 'i'
        prev_word["word"].capitalize! unless prev_word["word"] == nil or prev_word["word"].empty?
      end
      
    end while prev_word != nil and (prev_word[:punctuation] != "?" and prev_word[:punctuation] != "!") and sentence.length < 400
    
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
  # Returns statistics in an array
  # of speakable lines
  #
  # @return array
  #
  def get_statistics(arg = '')
    data = @db.execute("SELECT * FROM statistics ORDER BY lines DESC;")
    
    arr = []
    i = 1
    data.each do |d|
      line = i.to_s + ". " + d['user']
      line << " with "
      line << d['lines'].to_s
      line << " lines and "
      line << d['words'].to_s
      line << " words"
      arr << line
      i += 1
    end
    
    return arr
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