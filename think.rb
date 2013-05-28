require "treat"
require "./sentence.rb"

class Brain
  
  def initialize(*args)
  end
  
  
  def get_topic(msg)
    score = 0
    
    nouns = get_nouns(msg)
    
    topic = []
    nouns.each do |n|
      if n[1].to_i > score
        topic << n[0]
        score = n[1].to_i
      end
    end
    
    return topic
  end
  
  def get_nouns(msg)
    s = sentence(:export_name,msg)
    nouns = []
    s.each do |m|
      nouns << m[1]
    end
    return nouns
  end
  
  def get_adjectives
  end
  
  
end