require "sqlite3"

class Ear

  attr_accessor :debug, :db, :change_nsfw, :nsfw_url, :last_poll_id, :poll_db

  debug = true

  def initialize(*args)

    @db = SQLite3::Database.new("quotes.db")
    @db.results_as_hash = true
    @poll_db = SQLite3::Database.new("polls.db")
    @poll_db.results_as_hash = true
    @debug = true

    # If our tables dont exist, lets set them up :)
    create_structure
    @nsfw_url = []
    load_nsfw

    @change_nsfw = @db.prepare("INSERT OR REPLACE INTO nsfwlink_status (id, user, nsfw) VALUES ((SELECT id FROM nsfwlink_status WHERE user = ?), ?, ?);")
  end

  #
  # Creates our tables if they dont exist
  #
  #
  def create_structure
    # Create variables table
    @db.execute("create table if not exists variables(key varchar(255) PRIMARY KEY, value TEXT);");

    # Create quotes table
    @db.execute("create table if not exists quotes (id INTEGER PRIMARY KEY, quote TEXT);")

    # Remember NSFW links
    @db.execute("create table if not exists nsfwlink_status (id INTEGER PRIMARY KEY, user VARCHAR(15), nsfw TINYINT DEFAULT 0);")

    # Allow polls
    @poll_db.execute("create table if not exists polls (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, user VARCHAR(30), question VARCHAR(255), date TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL)")

    # Voting alternatives for polls
    @poll_db.execute("create table if not exists answers (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, poll_id INTEGER REFERENCES polls(id), number INTEGER, answer VARCHAR(255));")

    # Votes for polls
    @poll_db.execute("create table if not exists votes (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, usermask VARCHAR(255), poll_id INTEGER REFERENCES polls(id), answer_id INTEGER REFERENCES answers(id));")


    if @debug == true
      puts "Should have created tables by now"
    end
  end

  # Creates a poll
  #
  # @param string usr
  # @param string title
  def add_poll(usr, title)
    @poll_db.execute("INSERT INTO polls VALUES(NULL, ?, ?, datetime('now'))", usr, title)
    @last_poll_id = @poll_db.get_first_value("SELECT id FROM polls ORDER BY id DESC LIMIT 1")
    return @last_poll_id
  end

  # Add answers to the poll
  #
  # @param poll_id
  # @param answer
  def add_answer(poll_id, answer)
    puts "Now adding "+answer+" to poll #"+poll_id.to_s
    number = @poll_db.get_first_value("SELECT number FROM answers WHERE poll_id = ? ORDER BY number DESC LIMIT 1",poll_id)
    number = number.to_i unless number.nil?
    number ||= 0
    @poll_db.execute("INSERT INTO answers (id,poll_id, number, answer) VALUES (NULL,?, ?, ?)",poll_id,number+1,answer)
    ans = @poll_db.get_first_row("SELECT * FROM answers WHERE poll_id = ? ORDER BY id DESC LIMIT 1",poll_id)
    puts "This is the new answer:"
    puts ans
    return ans
  end

  # Vote
  #
  # @param string usrmask
  # @param integer answer_id
  # @param integer poll_id
  def vote(poll_id, answer_id, usrmask)
    # Has user answered? If so, update users answer
    answer = @poll_db.get_first_value("SELECT answer_id FROM votes WHERE usermask = ? AND poll_id = ?", usrmask, poll_id)
    if answer.nil? or !answer
      @poll_db.execute("INSERT INTO votes (usermask, poll_id, answer_id) VALUES (?, ?, (SELECT id FROM answers WHERE number = ? AND poll_id = ?))", usrmask, poll_id, answer_id, poll_id)
    else
      @poll_db.execute("UPDATE votes SET answer_id = (SELECT id FROM answers WHERE number = ? AND poll_id = ?) WHERE usermask = ? AND poll_id = ?",answer_id, poll_id, usrmask, poll_id)
    end
  end

  def get_last_poll_id
    return @poll_db.get_first_value("SELECT id FROM polls ORDER BY id DESC LIMIT 1")
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
  # Adds a variable to the variable table
  #
  # @param string msg
  #
  def set_variable(key, value)

    @db.execute("INSERT OR REPLACE INTO variables VALUES(?,?)",key,value)

    puts "I added #{key} to variable table database"
    return key
  end

  #
  # Fetches a specific variable from the variable table
  #
  # @return string
  #
  def get_variable(word)
    word = word.split(" ").first if word.split(" ").count > 1
    quote = @db.get_first_value("SELECT value FROM variables WHERE key = ? LIMIT 1;",word)
    return quote
  end

  #
  # Fetches a random quote from the quotes database
  #
  # @return string
  #
  def get_tags
    variables = @db.execute("SELECT key FROM variables ORDER BY key ASC;")
    tags = []
    variables.each do |k|
      tags << k["key"]["key"]
      puts k["key"]["key"]
    end
    return tags
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
    if nsfw == nil
      return nil
    end
    nsfw.each do |n|
      if n['nsfw'].to_i > 0
        @nsfw_url << n['user']
      end
    end
  end

end
