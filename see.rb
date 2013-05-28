require "sqlite3"
require "mechanize"
require "wikipedia"
require "wikicloth"
require "rubygems"
require "json"
require "nokogiri"

class Eye
  attr_accessor :debug, :db, :determiners, :exempt, :add_words, :add_noun, :add_context, :add_pair
  debug = true
  
  def initialize(*args)
    @db = SQLite3::Database.new("dictionary.db")
    @db.results_as_hash = true
    @debug = true
    
    # We use these to find nouns in sentences
    @determiners = ["a", "about", "an", "a few", "a little", "a number of", "all", "all of", "another", 
                    "any", "any old", "dat", "each", "each and every", "both", "certain", "each", 
                    "each and every", "either", "enough", "enuff", "enuf", "eny", "every", "few", 
                    "fewer", "fewest", "fewscore", "fuck all", "hevery", "just another", "last", 
                    "least", "little", "many", "many a", "many another", "more", "more and more", 
                    "most", "much", "neither", "next", "no", "none", "not a little", "not even once", 
                    "other", "overmuch", "own", "quite a few", "said", "several", "some", "some of", 
                    "some old", "such", "sufficient", "that", "the", "these", "various", "whatever", 
                    "which", "whichever", "you", "what is", "what was", "to", "i was", "as"]
    
    @emotions = [":D", ":)", "(:", ":C", ":c", "C:", "c:", "=)", "^_^", "^^", ":3", "D:", "><", ">_<", "._.", ";__;", ":O", ":o", "o:", ":p", ":P", ":x", ":X", ":*", "o_o", "O_o", "oO", "o_O", ";)", "(;"]
   
    # And these words should be exempt -- as in, if any of these comes after any of the above, it's not a match                 
    @exempt = ["i","this", "that", "are", "is", "should", "of", "off", "one", "they", "them", "it", "he", "she", "those", "there", "than", "any", "do", "does", "did", "doesnt", "doesn't", "didn't", "didnt", "will", "be", "been", "has", "have", "dont","lot", "bunch", "load"]
    # If our tables dont exist, lets set them up :)
    create_structure
    
    # Prepare the database statements we use the most:
    @add_words = @db.prepare("INSERT OR IGNORE INTO words VALUES (NULL, ?);")
    @add_noun = @db.prepare("INSERT OR IGNORE INTO nouns (id, noun) VALUES (NULL, ?);")
    @add_context = @db.prepare("INSERT OR IGNORE INTO context (id,noun_id, pair_identifier) VALUES ((SELECT id FROM context WHERE noun_id = (SELECT id FROM nouns WHERE noun = ?) AND pair_identifier = (SELECT id FROM pairs WHERE word_id = (SELECT id FROM words WHERE word = ?) AND pair_id = (SELECT id FROM words WHERE word = ?))), (SELECT id FROM nouns WHERE noun = ?),(SELECT id FROM pairs WHERE word_id = (SELECT id FROM words WHERE word = ?) AND pair_id = (SELECT id FROM words WHERE word = ?)));")     
    @add_pair = @db.prepare("INSERT OR REPLACE INTO pairs (id, word_id, pair_id, occurance, comma_suffix, dot_suffix, question_suffix, exclamation_suffix) VALUES ((SELECT id FROM pairs WHERE word_id = (SELECT id FROM words WHERE word = ?) AND pair_id = (SELECT id FROM words WHERE word = ?)), (SELECT id FROM words WHERE word = ?), (SELECT id FROM words WHERE word = ?),?,?,?,?,?);")
    @add_tripair = @db.prepare("INSERT OR REPLACE INTO tripairs (id, first_id, second_id, third_id, occurance, comma_suffix, dot_suffix, question_suffix, exclamation_suffix) VALUES ((SELECT id FROM tripairs WHERE first_id = ? AND second_id = ? AND third_id = ?), (SELECT id FROM words WHERE word = ? ), (SELECT id FROM words WHERE word = ?), (SELECT id FROM words WHERE word = ?), ?,?,?,?,?)")
    @pair_emotion = @db.prepare("INSERT OR REPLACE INTO pair_emotions (id, pair_id, emotion_index, tripair) VALUES ((SELECT id FROM pair_emotions WHERE pair_id = (SELECT id FROM pairs ORDER BY id DESC LIMIT 1) AND emotion_index = ? AND tripair = 0), (SELECT id FROM pairs ORDER BY id DESC LIMIT 1), ?, 0);")
    @tripair_emotion = @db.prepare("INSERT OR REPLACE INTO pair_emotions (id, pair_id, emotion_index, tripair) VALUES ((SELECT id FROM pair_emotions WHERE pair_id = (SELECT id FROM tripairs ORDER BY id DESC LIMIT 1) AND emotion_index = ? AND tripair = 1), (SELECT id FROM tripairs ORDER BY id DESC LIMIT 1), ?, 1);")
  end
  
  #
  # Creates the table structure
  #
  def create_structure
    # Create the words table
    @db.execute("create table if not exists words (id INTEGER PRIMARY KEY, word varchar(50) UNIQUE NOT NULL);")
    
    # Create the wordpair table
    @db.execute("create table if not exists pairs (id INTEGER PRIMARY KEY, word_id INTEGER(8), pair_id INTEGER(8), occurance INTEGER(10) DEFAULT 1 NOT NULL, question_suffix INTEGER DEFAULT 0 NOT NULL, comma_suffix INTEGER DEFAULT 0 NOT NULL, dot_suffix INTEGER DEFAULT 0 NOT NULL, exclamation_suffix INTEGER DEFAULT 0 NOT NULL);")
    
    # Create our tripair table
    @db.execute("create table if not exists tripairs (id INTEGER PRIMARY KEY, first_id INTEGER(8), second_id INTEGER(8), third_id INTEGER(8), occurance INTEGER(10) DEFAULT 1 NOT NULL, question_suffix INTEGER DEFAULT 0 NOT NULL, comma_suffix INTEGER DEFAULT 0 NOT NULL, dot_suffix INTEGER DEFAULT 0 NOT NULL, exclamation_suffix INTEGER DEFAULT 0 NOT NULL);")

    # Create the nouns table (for context)
    @db.execute("create table if not exists nouns (id INTEGER PRIMARY KEY, noun VARCHAR(50) UNIQUE NOT NULL);")
    
    # Create table linking nouns and pairs
    @db.execute("create table if not exists context (id INTEGER PRIMARY KEY, noun_id INTEGER, pair_identifier INTEGER);")
    
    # Create emotion-table linking emotions to words
    @db.execute("create table if not exists pair_emotions (id INTEGER PRIMARY KEY, pair_id INTEGER, emotion_index INTEGER, tripair TINYINT);")
    
    if @debug == true
      puts "Should have created tables by now"
    end
    
  end  
  
  #
  # Pair two words to one another with or without context,
  # and returns an array of the pair IDs that were created.
  # If words don't exist in database, they will be added.
  # Special characters will be stripped away, and trailing
  # non-word characters on word2 will increment appropriate columns
  # in the database, to allow for calculation of chance such characters
  # will trail the wordpair in the future
  #
  #
  # Options:
  # =>  context: an array of nouns
  #
  # @param string word
  # @param string word2
  # @param hash options
  #
  def pair_words(word1, word2, options = { context: [] })
    
    # Loop through all nouns in context array (if any)
    # and add a normal pair by default as well
    i = -1
    
    # First word shouldn't have a trailing special char (remember, it's the PAIR that has a suffix, not each word!)
    word1 = word1.gsub(/([^a-zA-Z'\/\s\d-]+)/,'')
    
    question_mark = 0
    comma = 0
    period = 0
    exclamation_mark = 0
    
    # Check our second word for special characters, increment our values in the database, and strip them away
    # Only check these if we know there's a special character
    # in our string!
    if word2 =~ /\W$/
    
      # First check if its a question
      if word2 =~ /.+(\?)/
        question_mark = 1
        puts "Updated #{word2} with +1 questionmark suffix"
      # if not, check if there's an exclamationmark
      elsif word2 =~ /.+(!)/
        exclamation_mark = 1
        puts "Updated #{word2} with +1 exclamation suffix"
      # no semicolon? Check for a dot!
      elsif word2 =~ /.+(\.)/
        period = 1
        puts "Updated #{word2} with +1 period suffix"
      # Final try, check for a comma (most common)
      elsif word2 =~ /.+([;|,])/
        comma = 1
        puts "Updated #{word2} with +1 comma suffix"
      end
      if word2 !~ /https?:\/\/[\S]+/ and word2 =~ /\W/
        word2 = word2.gsub(/([^a-zA-Z'\/\s\d-]+)/,'')
      end
    end
    
    if word2 !~ /https?:\/\/[\S]+/ and word2 =~ /\W/
      word2 = word2.gsub(/([^a-zA-Z'\/\s\d-]+)/,'')
    end
 
    # The first thing we need to do is add our words if they dont exist:
    get_pair_data = "SELECT * FROM pairs WHERE word_id = (SELECT id FROM words WHERE word = ?) AND pair_id = (SELECT id FROM words WHERE word = ?) LIMIT 1;"
    
    # Add our words if they dont exist, using our prepared statement
    @add_words.execute(word1)
    @add_words.execute(word2)
    
    puts "I have %s contexts to iterate through after adding vanilla pair of #{word1} and #{word2}" % options[:context].count
    
    begin
      puts "ITERATION #{i}"
      # First thing we need to do is insert our pair if it doesnt exist, without context, and update it if it already exists (+1 on comma/questionmark/etc if one is included)
      if i < 0
        
        # Get previous data for this pair
        r = @db.get_first_row(get_pair_data,word1,word2)
        
        unless r == nil
          comma += r['comma_suffix'].to_i
          period += r['period_suffix'].to_i
          question_mark += r['question_suffix'].to_i
          exclamation_mark += r['exclamation_suffix'].to_i
        end      
       
        @add_pair.execute(word1,word2,word1,word2,comma,period,question_mark,exclamation_mark)
        
      # Afterwards, we need to add each context noun to our noun table, and link it to the created pair
      else
        @add_context.execute(options[:context][i],word1,word2,options[:context][i],word1,word2)  
      end
      
      i += 1
    end while i < options[:context].count
    
  end
  
  
  #
  # Pair three words to one another with or without context,
  # and returns an array of the pair IDs that were created.
  # If words don't exist in database, they will be added.
  # Special characters will be stripped away, and trailing
  # non-word characters on word2 will increment appropriate columns
  # in the database, to allow for calculation of chance such characters
  # will trail the wordpair in the future
  #
  #
  # Options:
  # =>  context: an array of nouns
  #
  # @param string word1
  # @param string word2
  # @param string word3
  # @param hash options
  #
  def tripair_words(word1, word2, word3, options = { context: [] })
    
    # First word shouldn't have a trailing special char (remember, it's the PAIR that has a suffix, not each word!)
    word1 = word1.gsub(/([^a-zA-Z'\/\s\d-]+)/,'')
    word2 = word2.gsub(/([^a-zA-Z'\/\s\d-]+)/,'')
    
    question_mark = 0
    comma = 0
    period = 0
    exclamation_mark = 0
    
    # Check our second word for special characters, increment our values in the database, and strip them away
    # Only check these if we know there's a special character
    # in our string!
    if word3 =~ /\W$/
    
      # First check if its a question
      if word3 =~ /.+(\?)/
        question_mark = 1
      # if not, check if there's an exclamationmark
      elsif word3 =~ /.+(!)/
        exclamation_mark = 1
      # no semicolon? Check for a dot!
      elsif word3 =~ /.+(\.)/
        period = 1
      # Final try, check for a comma (most common)
      elsif word3 =~ /.+([;|:])/
        comma = 1
      end
      if word3 !~ /https?:\/\/[\S]+/
        word3 = word3.gsub(/\W$/,'')
      end
    end
    
    if word3 !~ /https?:\/\/[\S]+/ and word3 =~ /\W/
      word3 = word2.gsub(/([^a-zA-Z'\/\s\d-]+)/,'')
    end
 
    # The first thing we need to do is add our words if they dont exist:
    get_tripair_data = "SELECT * FROM tripairs WHERE first_id = (SELECT id FROM words WHERE word = ?) AND second_id = (SELECT id FROM words WHERE word = ?) AND third_id = (SELECT id FROM words WHERE word = ?) LIMIT 1;"
    
    # Add our words if they dont exist, using our prepared statement
    @add_words.execute(word1)
    @add_words.execute(word2)
    @add_words.execute(word3)
    
        
    # Get previous data for this pair
    r = @db.get_first_row(get_tripair_data,word1,word2,word3)
        
    unless r == nil
      comma += r['comma_suffix'].to_i
      period += r['period_suffix'].to_i
      question_mark += r['question_suffix'].to_i
      exclamation_mark += r['exclamation_suffix'].to_i
      puts "Comma suffix was " + comma
    end      
       
    @add_tripair.execute(word1,word2,word3,word1,word2,word3,comma,period,question_mark,exclamation_mark)
         
    
  end
  
  
  #
  # Processes text, and learns from it by splitting it into words
  # before sorting out nouns. Nouns become context, words become
  # word pairs, [word pairs become quad-pairs] (<- maybe later), 
  # and it's all stored.
  #
  # @param string message
  #
  def process_message(message)

    # Make sure its a string (cause we can pass anything here!)
    msg = message.to_s
    words = msg.split(/\s+/)
    has_emotion = []
    
    words.each_with_index do |em,i|
      if i > 0 and @emotions.include? em
        has_emotion[i-1] = @emotions.index(em)
        words.delete_at(i)
      end
    end
    
    #msg = msg.sub(/\b*\s+\W\s+\b*/,'')
    
    nouns = get_context(message)
    
    
    
    # Loop through all words, with the index, to access elements properly
    words.each_with_index do |word,i|
      
      word.downcase!
      # We cant pair the first word, because it doesn't follow any word,
      # so instead we pair each word after the first to the previous word
      if i > 0
       
        pair_words(words[i-1],word,{ context: nouns })
        puts "CALL # #{i}"
        
        # Pairs emoticons to our newly created pair
        unless has_emotion.at(i) == nil
          @pair_emotion.execute(has_emotion.at(i))
        end
      end
      if i > 1
        tripair_words(words[i-2], words[i-1], word)
        
        unless has_emotion.at(i) == nil
          @tripair_emotion.execute(has_emotion.at(i),has_emotion.at(i))
        end
      end
    end
  end
  
  #
  # Filters out nouns from a sentence to create context
  #
  # @param string msg
  # @return array
  # 
  
  def get_context(message)
    
    nouns = []
    @determiners.each do |determiner|
      matches = message.scan(/\b#{determiner}\s+([\w-]+)\b/i)
      
      matches.each do |match|
        unless @exempt.include? match.first or @determiners.include? match.first
          nouns << match.first.downcase
          @add_noun.execute(match.first)
          puts "Added %s" % match.first.downcase
        end
      end
    end
    nouns = nouns.uniq
    return nouns
  end
  
  #
  # Searches wikipedia and gets the best match, then processes data and learns from it,
  # Returns a neat, summarized string of data from wikipedia
  #
  # @param string search
  #
  def get_wiki(search)
    
    search = search.split(/\s+/).map {|w| w.capitalize }.join(' ')
    page = Wikipedia.find(search)
    g = JSON.parse(page.json)
    content = g["query"]["pages"].first.last["revisions"].first

    
    content = content["*"]
    
    
    wiki = WikiCloth::Parser.new({ data: content })
    
    html = wiki.to_html
    
    doc = Nokogiri::HTML(html)
    doc = doc.xpath("//p").to_s
    doc = Nokogiri::HTML(doc)
    doc = doc.xpath("//text()").to_s
    
    doc = doc.split("\n")
    
    plaintext = []
    
    doc.each do |d|
      unless d.empty?
        plaintext << d
      end
    end
    
   
    return plaintext
  end
  
end