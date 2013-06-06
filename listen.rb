require "sqlite3"

class Ear
  
  attr_accessor :debug, :db, :change_nsfw, :nsfw_url

  debug = true
  
  def initialize(*args)
    
    @db = SQLite3::Database.new("quotes.db")
    @db.results_as_hash = true
    @debug = true
    
    # If our tables dont exist, lets set them up :)
    create_structure
    
    
    @change_nsfw = @db.prepare("INSERT OR REPLACE INTO nsfwlink_status (id, user, nsfw) VALUES ((SELECT id FROM nsfwlink_status WHERE user = ?), ?, ?);")
  end
  
  #
  # Creates our tables if they dont exist
  # 
  # 
  def create_structure
    
    # Create quotes table
    @db.execute("create table if not exists quotes (id INTEGER PRIMARY KEY, quote TEXT);")
    
    # Remember NSFW links
    @db.execute("create table if not exists nsfwlink_status (id INTEGER PRIMARY KEY, user VARCHAR(15), nsfw TINYINT DEFAULT 0);")
    
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
    return @db.get_first_value("SELECT id FROM quotes ORDER BY id DESC LIMIT 1;")
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
  
  #
  # Fetches a specific quote from the quotes database
  # 
  # @return string
  #
  def specific_quote(id)
    quote = @db.get_first_value("SELECT quote FROM quotes WHERE id = ? LIMIT 1;",id)
    return quote
  end
  
  #
  # Keeps track of who sends NSFW links by default,
  # and allows for automatically prepending an NSFW tag
  #
  # @param string user
  # @param boolean nsfw
  #
  def nsfw_links(u, nsfw)
    u.downcase!
    puts "I will try to add " + u + " to nsfw links with status " + nsfw.to_s
    
    state = 0
    
    if nsfw > 0
      state = 1
    end
    
    @change_nsfw.execute(u,u,state)
    load_nsfw
  end
  
  def load_nsfw
    nsfw = @db.execute("SELECT user,nsfw FROM nsfwlink_status ORDER BY id DESC;")
    @nsfw_url = []
    nsfw.each do |n| 
      if n['nsfw'].to_i > 0
        @nsfw_url << n['user']
      end
    end
  end
  
end