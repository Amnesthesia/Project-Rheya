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
    @db.execute("create table if not exists words (id INTEGER PRIMARY KEY, word varchar(50) UNIQUE NOT NULL, occurance INTEGER(10), question_suffix INTEGER, comma_suffix INTEGER, dot_suffix INTEGER, exclamation_suffix INTEGER);")
    
    # Create the wordpair table
    @db.execute("create table if not exists pairs (id INTEGER PRIMARY KEY, word_id INTEGER(8), pair_id INTEGER(8), occurance INTEGER(10), context INTEGER);")
    
    
    # Create the nouns table (for context)
    @db.execute("create table if not exists nouns (id INTEGER PRIMARY KEY, noun VARCHAR(50) UNIQUE NOT NULL);")
    
    if @debug == true
      puts "Should have created tables by now"
    end
    
  end
  
  # 
  # Adds a new word to the database if it doesn't already exist
  # Checks every word for periods, questionmarks, exclamation marks,
  # commas, and semicolons and removes it.
  # Returns the ID of the newly added word 
  # 
  # @param string word
  # @return string
  #
  def add_word(word)
    
    question_mark = 0
    exclamation_mark = 0
    period = 0
    comma = 0
    
    # Only check these if we know there's a special character
    # in our string!
    
    if word =~ /\W$/
    
      # First check if its a question
      if word =~ /.+(\?)/
        question_mark = 1
        word = word.sub /.+(\?)/, ''
      # if not, check if there's an exclamationmark
      elsif word =~ /.+(!)/
        exclamation_mark = 1
        word = word.sub /.+(!)/, ''
      # no semicolon? Check for a dot!
      elsif word =~ /.+(\.)/
        period = 1
        word = word.sub /.+(\.)/, ''
      # Final try, check for a comma (most common)
      elsif word =~ /.+([;|:])/
        comma = 1
        word = word.sub /.+([;|:])/, ''
      end
    end
    
   
    
    id = @db.get_first_value("SELECT id FROM words WHERE word = ?",word)
    
    if id == nil or id <= 0
      @db.execute("INSERT OR IGNORE INTO words VALUES (NULL, ?, 1, ?, ?, ?, ?)", word, question_mark, comma, period, exclamation_mark)
      id = @db.get_first_value("SELECT id FROM words WHERE word = ?",word)
      
      if @debug == true
        puts "I added #{word} to our dictionary with id #{id}"
      end
    else
      @db.execute("UPDATE words SET occurance = occurance+1, question_suffix = question_suffix + ?, comma_suffix = comma_suffix + ?, dot_suffix = dot_suffix + ?, exclamation_suffix = exclamation_suffix + ? WHERE id = ?",question_mark, comma, period, exclamation_mark,id)  
      
      if @debug == true
        puts "I incremented comma (#{comma}), exclamation (#{exclamation_mark}), question (#{question_mark}) and dot (#{period}) for #{word} with id #{id}"
      end
    end
    
    return id 
  end
  
  
  #
  # Pair two words to one another with or without context,
  # and returns an array of the pair IDs that were created.
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
    pairs = []
    word1_id = add_word(word1)
    word2_id = add_word(word2)
    
    word1 = word1.sub(/\W/,'')
    word2 = word2.sub(/\W/,'')
    
    puts "I have %s contexts to iterate through after adding vanilla pair" % options[:context].count
    
    begin
      
      if i < 0      
        count = @db.get_first_value("SELECT count(*) as c FROM pairs WHERE word_id = ? AND pair_id = ? AND context = 0", word1, word2)
      else
        count = @db.get_first_value("SELECT count(*) as c FROM pairs WHERE word_id = ? AND pair_id = ? AND context = (SELECT id FROM nouns WHERE noun = ?);",word1_id, word2_id, options[:context][i])
      end
      
      # If nothing is in there, add it
      if count == nil or count <= 0
        
        # Do the actual adding (depending on whether we're at contexts or regular)
        if i < 0
          @db.execute("INSERT INTO pairs VALUES (NULL,?,?,1,0)", word1_id, word2_id)
        
          # Get the ID for the pair we created and throw it onto our pairs array
          tmpid = @db.get_first_value("SELECT id FROM pairs WHERE word_id = ? AND pair_id = ?", word1_id, word2_id)
          
          unless tmpid == nil or tmpid == ""
            pairs << tmpid
          end
          
          if @debug == true
            puts "I've just paired #{word1} to #{word2} :D"
          end
          
        # Add with context:
        else
          @db.execute("INSERT INTO pairs VALUES (NULL,?,?,1,(SELECT id FROM nouns WHERE id = ?))", word1_id, word2_id, options[:context][i])
        
          # Get the ID for the pair we created and throw it onto our pairs array
          tmpid = @db.get_first_value("SELECT id FROM pairs WHERE word_id = ? AND pair_id = ? AND context = (SELECT id FROM nouns WHERE id = ?)", word1_id, word2_id, options[:context][i])
          
          unless tmpid == nil or tmpid.empty?
            pairs << tmpid
          end
          
          if @debug == true
            puts "I've just paired #{word1} to #{word2} with context %s" % options[:context][i]
          end
        end
    
      # If something is there, update occurance by 1  
      else
        
        # Update occurance for wordpair without context
        if i < 0
          @db.execute("UPDATE pairs SET occurance = occurance+1 WHERE word_id = ? AND pair_id = ?", word1_id, word2_id)
          
          # Get the ID for the pair we created and throw it onto our pairs array
          tmpid = @db.get_first_value("SELECT id FROM pairs WHERE word_id = ? AND pair_id = ?", word1_id, word2_id)
          
          unless tmpid == nil or tmpid.empty?
            pairs << tmpid
          end
          
          # Output some debug information if debug is enabled
          if @debug == true
            occurance = @db.get_first_value("SELECT occurance FROM pairs WHERE word_id = ? AND pair_id = ?", word1_id, word2_id)
            puts "I updated the occurance of #{word1} to #{word2} , which is now: #{occurance}"
          end
        else
          @db.execute("UPDATE pairs SET occurance = occurance+1 WHERE word_id = ? AND pair_id = ? AND context = (SELECT id FROM nouns WHERE noun = ?)", word1_id, word2_id, options[:context][i])
          
          # Get the ID for the pair we created and throw it onto our pairs array
          tmpid =  @db.get_first_value("SELECT id FROM pairs WHERE word_id = ? AND pair_id = ? AND context = (SELECT id FROM nouns WHERE id = ?)", word1_id, word2_id, options[:context][i])
          
          unless tmpid == nil or tmpid.empty?
            pairs += [tmpid]
          end
           
          if @debug == true
            occurance = @db.get_first_value("SELECT occurance FROM pairs WHERE word_id = ? AND pair_id = ? AND context = (SELECT id FROM nouns WHERE noun = ?)", word1_id, word2_id, options[:context][i])
            puts "I updated the occurance of #{word1} to #{word2} , which is now: #{occurance}"
          end
          
        end
      end
      i += 1
    end while i < options[:context].count
    
    return pairs
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
          @db.execute("INSERT OR IGNORE INTO nouns VALUES (NULL, ?)",match)  
          nouns << match.first
          puts "Added %s" % match.first
        end
      end
    end
    nouns = nouns.uniq
    return nouns
  end
  
end