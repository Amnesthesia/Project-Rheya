class Ear
  
  attr_accessor :debug, :db

  debug = true
  
  def initialize(*args)
    
    @db = SQLite3::Database.new("quotes.db")
    @db.results_as_hash = true
    @debug = true
    
    # If our tables dont exist, lets set them up :)
    create_structure
    
  end
  
  #
  # Creates our tables if they dont exist
  # 
  # 
  def create_structure
    @db.execute("create table if not exists quotes (id INTEGER PRIMARY KEY, quote TEXT);")
    
    if @debug == true
      puts "Should have created tables by now"
    end
  end

  #
  # Adds a quote to the quote database
  #
  # @param string msg
  #
  def add_quote(msg)

    @db.execute("INSERT INTO quotes VALUES(NULL,?)",msg)
    
    puts "I added #{msg} to quotes database"
    
  end
  
  #
  # Fetches a random quote from the quotes database
  # 
  # @return string
  #
  def random_quote
    quote = @db.get_first_value("SELECT quote FROM quotes ORDER BY RANDOM() LIMIT 1;")
    return quote
  end
  
end