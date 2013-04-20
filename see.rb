require "sqlite3"

class Eye
  attr_accessor :debug, :db, :determiners, :exempt
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
   
    # And these words should be exempt -- as in, if any of these comes after any of the above, it's not a match                 
    @exempt = ["i","this", "that", "are", "is", "should", "of", "off", "one", "they", "them", "it", "he", "she", "those", "there", "than", "any", "do", "does", "did", "doesnt", "doesn't", "didn't", "didnt", "will", "be", "been", "has", "have", "dont"]
    
    # If our tables dont exist, lets set them up :)
    create_structure
    
  end
  
  #
  # Creates the table structure
  #
  def create_structure
    # Create the words table
    @db.execute("create table if not exists words (id INTEGER PRIMARY KEY, word varchar(50) UNIQUE NOT NULL);")
    
    # Create the wordpair table
    @db.execute("create table if not exists pairs (id INTEGER PRIMARY KEY, word_id INTEGER(8), pair_id INTEGER(8), occurance INTEGER(10), question_suffix INTEGER, comma_suffix INTEGER, dot_suffix INTEGER, exclamation_suffix INTEGER);")
    
    # Create the nouns table (for context)
    @db.execute("create table if not exists nouns (id INTEGER PRIMARY KEY, noun VARCHAR(50) UNIQUE NOT NULL);")
    
    # Create table linking nouns and pairs
    @db.execute("create table if not exists context (id INTEGER PRIMARY KEY, noun_id INTEGER, pair_identifier INTEGER);")
    
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
    word1 = word1.sub(/\W/)
    
    # Check our second word for special characters, increment our values in the database, and strip them away
    # Only check these if we know there's a special character
    # in our string!
    if word2 =~ /\W$/
    
      # First check if its a question
      if word2 =~ /.+(\?)/
        question_mark = 1
        word2 = word.sub /.+(\?)/, ''
      # if not, check if there's an exclamationmark
      elsif word =~ /.+(!)/
        exclamation_mark = 1
        word2 = word.sub /.+(!)/, ''
      # no semicolon? Check for a dot!
      elsif word =~ /.+(\.)/
        period = 1
        word2 = word.sub /.+(\.)/, ''
      # Final try, check for a comma (most common)
      elsif word =~ /.+([;|:])/
        comma = 1
        word2 = word.sub /.+([;|:])/, ''
      end
    end
    
    # The first thing we need to do is add our words if they dont exist:
    query = "INSERT OR IGNORE INTO words VALUES (NULL, ?), (NULL, ?);"
    
    puts "I have %s contexts to iterate through after adding vanilla pair" % options[:context].count
    
    begin
      
      # First thing we need to do is insert our pair if it doesnt exist, without context, and update it if it already exists (+1 on comma/questionmark/etc if one is included)
      if i < 0      
        query << "INSERT OR REPLACE INTO pairs (id, word_id, pair_id, occurance, comma_suffix, dot_suffix, question_suffix, exclamation_suffix) VALUES "
        query << "((SELECT id FROM pairs WHERE word_id = (SELECT id FROM words WHERE word = ?) AND pair_id = (SELECT id FROM words WHERE word = ?)),"
        query << "(SELECT id FROM words WHERE word = ?), (SELECT id FROM words WHERE word = ?),"
        query << "(SELECT occurance FROM pairs WHERE word_id = (SELECT id FROM words WHERE word = ?) AND pair_id = (SELECT id FROM words WHERE word = ?))+1,"
        query << "(SELECT comma_suffix FROM pairs WHERE word_id = (SELECT id FROM words WHERE word = ?) AND pair_id = (SELECT id FROM words WHERE word = ?))+?,"
        query << "(SELECT dot_suffix FROM pairs WHERE word_id = (SELECT id FROM words WHERE word = ?) AND pair_id = (SELECT id FROM words WHERE word = ?))+?,"
        query << "(SELECT question_suffix FROM pairs WHERE word_id = (SELECT id FROM words WHERE word = ?) AND pair_id = (SELECT id FROM words WHERE word = ?))+?,"
        query << "(SELECT exclamation_suffix FROM pairs WHERE word_id = (SELECT id FROM words WHERE word = ?) AND pair_id = (SELECT id FROM words WHERE word = ?))+?);"
        @db.execute(query,word1,word2,word1,word2,word1,word2,word1,word2,word1,word2,comma,word1,word2,period,word1,word2,question_mark,word1,word2,exclamation_mark)
      
      # Afterwards, we need to add each context noun to our noun table, and link it to the created pair
      else
        query = "INSERT OR IGNORE INTO nouns (id, noun) VALUES (NULL, ?);"
        query << "INSERT OR IGNORE INTO context (id,noun_id, pair_identifier) VALUES ((SELECT id FROM context WHERE noun_id = (SELECT id FROM nouns WHERE noun = ?) AND pair_id = (SELECT id FROM pairs WHERE word_id = (SELECT id FROM words WHERE word = ?) AND pair_id = (SELECT id FROM words WHERE word = ?))),"
        query << "(SELECT id FROM nouns WHERE noun = ?),(SELECT id FROM pairs WHERE word_id = (SELECT id FROM words WHERE word = ?) AND pair_id = (SELECT id FROM words WHERE word = ?)));"
        @db.execute(query,options[:context][i],options[:context][i],word1,word2,options[:context][i],word1,word2)  
      end
      
      i += 1
    end while i < options[:context].count
    
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
    
    msg = msg.sub(/\s+\W\s+/,'')
    
    nouns = get_context(message)
    
    # Split the sentence into words by splitting on non-word delimiters
    words = msg.split(/\s+/)
    
    
    # Loop through all words, with the index, to access elements properly
    words.each_with_index do |word,i|
      
      word.downcase!
      # We cant pair the first word, because it doesn't follow any word,
      # so instead we pair each word after the first to the previous word
      if i > 0
       
        pair_words(word,words[i-1],{ context: nouns })
        puts "CALL # #{i}"
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
          nouns << match.first
          puts "Added %s" % match.first
        end
      end
    end
    nouns = nouns.uniq
    return nouns
  end
  
end